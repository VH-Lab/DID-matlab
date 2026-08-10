function tests = testCorpusPRED
%TESTCORPUSPRED End-to-end converter run against the public PRED corpus.
%
%   Pulls the PRED zip from the public S3 fixture (set up under the
%   step-6d RFC), unwraps it, and runs every contained v1 document
%   through did2.convert.v1_to_v2 with Validate=true. Asserts that
%   the full corpus migrates with zero quarantine entries. This is
%   the corpus-coverage gate referenced in PLAN.md §9.6 sub-step 6d.
%
%   The corpus URL:
%       https://ndi-programming-development.s3.us-east-1.amazonaws.com/PRED.zip
%   The zip contains a top-level PRED/ directory of v1-shaped NDI
%   document JSONs (plus __MACOSX/ sidecars that are skipped).
%
%   Validation requires V_delta schemas to be reachable. The test
%   probes, in order:
%       1. DID_SCHEMA_PATH env var
%       2. did2.schema.cache default (sibling did-schema checkout)
%   and skips via assumeFail if neither resolves. The CI workflow is
%   expected to set DID_SCHEMA_PATH explicitly so this gate is real.
%
%   Network IO: one HTTPS GET to the S3 URL above. The download is
%   cached in tempdir across runs so re-runs in the same session
%   skip the fetch.
%
%   STATUS of the 2026-08-10 batch-post-pass wiring edit: WRITTEN WITHOUT
%   MATLAB. The guarded epochMint call, the new resolveSessionAnchors call and
%   the post-pass failure assertions have NOT been executed here.
%
%   Run with:
%       results = runtests('did2.unittest.testCorpusPRED');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Capture the inbound DID_SCHEMA_PATH *before* anything that could
% throw or filter the suite, so teardownOnce always has it to
% restore.
testCase.TestData.previousSchemaPath = getenv('DID_SCHEMA_PATH');
testCase.TestData.didOverrideSchemaPath = false;
testCase.TestData.predDir = '';

schemaPath = resolveSchemaPath();
if isempty(schemaPath)
    assumeFail(testCase, ...
        ['V_delta schemas not found. Set DID_SCHEMA_PATH or check out ', ...
         'did-schema as a sibling of DID-matlab; skipping PRED corpus test.']);
end
setenv('DID_SCHEMA_PATH', schemaPath);
testCase.TestData.didOverrideSchemaPath = true;
did2.schema.cache.resetSingleton();

testCase.TestData.predDir = ensurePREDCorpus();
end

function teardownOnce(testCase)
% Restore the original DID_SCHEMA_PATH so we don't leak the test
% override into subsequent test files. Both fields are seeded at
% the top of setupOnce so this teardown is safe even if setupOnce
% filtered the suite via assumeFail.
if isfield(testCase.TestData, 'didOverrideSchemaPath') ...
        && testCase.TestData.didOverrideSchemaPath
    setenv('DID_SCHEMA_PATH', testCase.TestData.previousSchemaPath);
    did2.schema.cache.resetSingleton();
end
end

function testPREDCorpusMigratesCleanly(testCase)
predDir = testCase.TestData.predDir;
files = dir(fullfile(predDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
verifyGreaterThan(testCase, numel(files), 0, ...
    sprintf('No JSON files found under %s', predDir));

bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end

% Migrate to V_eta (the branch's target and the schema DID_SCHEMA_PATH points
% at), then run the same DID-side post-passes as the other corpus tests
% (runCorpusDiscovery): resolve deferred stimulus_baths and finalize the dataset
% entity layer. Previously this called v1_to_v2 with no TargetVersion, defaulting
% to V_delta -- but validation is against the V_eta schema, so a V_delta-shaped
% output (e.g. pyraview still carrying the retired epochclocktimes block) fails
% with an "undeclared block" error. Targeting V_eta runs the strict-J migrators
% (migrators_j) so the corpus migrates cleanly under the schema it is checked
% against.
result = did2.convert.v1_to_v2(bodies, 'Validate', true, 'TargetVersion', 'V_eta');
result = did2.convert.resolveDeferredBaths(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');
result = did2.convert.resolveDatasetEntities(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');
% #60: mint the `epoch` entities, keyed on the (base.session_id, epoch-id
% string) PAIR. Kept in step with runCorpusDiscovery deliberately -- this file
% exists to run the same post-passes on a HARD gate, and a post-pass that runs
% only on the discovery corpora is a post-pass nothing gates.
%
% GUARDED (2026-08-10), same rule as runCorpusDiscovery: the report write is
% ~20 lines below, and PRED has been invisible to the census once already (run
% #3's upload found no files). A throw here would make it invisible again, and
% this time silently, because the failure would look like an ordinary red test.
% The guard keeps the artifact; the assertion added AFTER the report write
% keeps the gate red.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.epochMint', 'epoch_mint', ...
    @(r) did2.convert.epochMint(r, 'Validate', true, 'TargetVersion', 'V_eta'));

% #65: fold session_relative_reference + session_bounded_reference into
% `relative_reference`, base.id PRESERVED. Runs AFTER epochMint, matching
% runCorpusDiscovery and ndi.migrate.local exactly. The two passes commute on
% today's code (neither writes what the other reads, and no post-pass removes a
% `session` document); the order is fixed so the three call sites cannot
% diverge, NOT because a dependency forces it. See runCorpusDiscovery.m for the
% full ordering note.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveSessionAnchors', 'session_anchor_fold', ...
    @(r) did2.convert.resolveSessionAnchors(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));

% WRITE THE CENSUS REPORT, before the assertions so a red gate still reports.
%
% PRED is a HARD gate (zero quarantine), not a discovery run, so it does not
% go through runCorpusDiscovery -- and as a side effect it has been invisible
% to the census that four open items depend on. Run #3 (31315510527) is the
% evidence: six corpus jobs ran, five artifacts were produced, and PRED's
% upload step said
%
%   ##[warning]No files were found with the provided path: corpus-reports/
%   tests/corpus-reports/. No artifacts will be uploaded.
%
% A corpus we gate on but never measure is a denominator missing from every
% census number we quote. The assertions below are unchanged; this only stops
% the corpus being uncounted.
try
    result.source_census = did2.validate.sourceCensus(bodies);
catch censusErr
    result.source_census = struct('audit_failed', censusErr.message);
end
reasons = did2.unittest.helpers.topQuarantineReasons(result.quarantine);
did2.unittest.helpers.writeCorpusReport('PRED', result, reasons);

% THE REPORT IS ON DISK -- now make a guarded post-pass failure FATAL. PRED is
% the hard gate, so this is where a batch pass that threw must turn the build
% red. Doing it here rather than letting the pass throw above is the whole
% point of the guard: the artifact lands AND the gate fires, instead of one at
% the cost of the other.
for passField = {'epoch_mint', 'session_anchor_fold'}
    failMsg = did2.unittest.helpers.batchPassFailure(result, passField{1});
    verifyEmpty(testCase, failMsg, sprintf( ...
        ['PRED: batch post-pass `%s` FAILED; its documents are in pass-1 ' ...
         'form and the corpus report records this under %s.pass_failed: %s'], ...
        passField{1}, passField{1}, failMsg));
end

% Build a readable diagnostic so a failure tells us *which* doc and *why*.
if result.summary.quarantine_count > 0
    lines = cell(1, numel(result.quarantine));
    for k = 1:numel(result.quarantine)
        lines{k} = sprintf('  [%s] %s', ...
            result.quarantine(k).class_name, ...
            result.quarantine(k).reason);
    end
    diag = sprintf('PRED quarantined %d/%d:\n%s', ...
        result.summary.quarantine_count, ...
        result.summary.total, ...
        strjoin(lines, sprintf('\n')));
else
    diag = '';
end

% The gate is zero quarantine: every source document migrates cleanly under the
% V_eta schema. (The old migrated_count == total check assumed 1 -> 1 migration;
% under V_eta the strict-J migrators fan out 1 -> N, so migrated_count > total.)
verifyEqual(testCase, result.summary.quarantine_count, 0, diag);
verifyGreaterThanOrEqual(testCase, result.summary.migrated_count, ...
    result.summary.total, diag);
end

% --- helpers ---

function p = resolveSchemaPath()
% Return a directory that holds V_delta `*.json` schema files, or '' if
% none can be found. Probe order matches the docstring above.
candidates = {};
envPath = getenv('DID_SCHEMA_PATH');
if ~isempty(envPath)
    candidates{end+1} = envPath; %#ok<AGROW>
end
% Same fallback shape as did2.schema.cache.defaultSchemaPath: assume
% did-schema is a sibling of the DID-matlab checkout.
toolboxDir = did.toolboxdir();
candidates{end+1} = fullfile(toolboxDir, '..', '..', '..', ...
    'did-schema', 'schemas', 'V_delta', 'stable'); %#ok<AGROW>

p = '';
for k = 1:numel(candidates)
    candidate = candidates{k};
    if isfolder(candidate) && ~isempty(dir(fullfile(candidate, '*.json')))
        p = candidate;
        return;
    end
end
end

function predDir = ensurePREDCorpus()
% Download (if necessary) and extract PRED.zip. The unzip target is
% cached under tempdir so repeated test runs reuse the same files.
corpusURL = 'https://ndi-programming-development.s3.us-east-1.amazonaws.com/PRED.zip';
cacheRoot = fullfile(tempdir(), 'did2-corpus-PRED');
predDir   = fullfile(cacheRoot, 'PRED');
if isfolder(predDir) && ~isempty(dir(fullfile(predDir, '*.json')))
    return;
end
if ~exist(cacheRoot, 'dir')
    mkdir(cacheRoot);
end
zipPath = fullfile(cacheRoot, 'PRED.zip');
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
end
