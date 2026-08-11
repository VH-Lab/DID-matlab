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
% GUARDED 2026-08-11, in step with runCorpusDiscovery. This pass runs FIRST and
% moves documents from `quarantine` into `migrated`; its per-bath failures were
% swallowed by a bare `catch` with a two-line comment for a body until it
% acquired the `deferred_bath_resolution` report, so "resolved every deferred
% bath" and "resolved none" were the same reading of every corpus run. It runs
% before writeCorpusReport, and PRED has been invisible to the census once
% already. In the FATAL list below: the guard saves the artifact, the assertion
% keeps the gate red.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveDeferredBaths', 'deferred_bath_resolution', ...
    @(r) did2.convert.resolveDeferredBaths(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));
% TEAM DECISION 2026-08-11 ("Do B"): assemble the openMINDS dataset CITATION
% graph into the entity tier -- the same six classes metadata_editor emits,
% from the independent openMINDS store. ADDITIVE: neither store dominates and
% 0 of 6 corpora carry both, so this does not replace or weaken that path.
%
% ORDER: BEFORE resolveDatasetEntities, which keeps the RICHEST `dataset`
% entity per id. The entity minted here is keyed on the same dataset id as the
% bare stubs and carries the real names, so it wins that ranking -- but only if
% it exists when the ranking runs.
%
% GUARDED, same rule as epochMint below: this file writes a corpus report ~20
% lines further on, and PRED has been invisible to the census once already. A
% throw here would make it invisible again. The guard keeps the artifact; the
% assertion after the report write keeps the gate red.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveOpenmindsCitations', 'openminds_citations', ...
    @(r) did2.convert.resolveOpenmindsCitations(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));
% GUARDED 2026-08-11: THIS PASS DELETES DOCUMENTS -- the poorer of duplicate
% `dataset` entities, and every `migrated_session_membership` edge whose child
% is absent from the batch -- and counted neither until it acquired the
% `dataset_entity_resolution` report. The two reasons are kept apart there,
% because a dedup loses nothing and a discarded membership edge loses a
% statement. In the FATAL list below.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveDatasetEntities', 'dataset_entity_resolution', ...
    @(r) did2.convert.resolveDatasetEntities(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));
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

% #61, the RESOLVER half of the signed stimulus-response fold: the five run
% knobs move from `stimulus_response_scalar_parameters_basic` INLINE onto the
% `harmonic_component_calculation` leaf and the `method_parameters_id` edge goes
% (the schema's rule is the inline field OR the edge, never both). Kept in step
% with runCorpusDiscovery and testFixtureCorpus, in the SAME ORDER, for the same
% reason as the two passes above: a post-pass wired into some call sites and not
% others makes the corpus green while another path does something else.
%
% WHAT THIS PASS WILL REPORT ON PRED IS NOT PREDICTED HERE. PRED's document
% count is small (31 in the last cross-corpus rollup, run 31415147934), and it
% would be easy to write "so every counter will be 0" -- but whether PRED holds
% any stimulus-response document has not been measured, and a guess in a comment
% becomes a fact the next reader quotes. The pass prints its own denominator;
% read that. Wired here regardless: a hard gate that skips a pass is a pass one
% hard gate does not cover.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveResponseParameters', 'response_parameters_fold', ...
    @(r) did2.convert.resolveResponseParameters(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));

% TEAM DECISION 2026-08-11: the E. coli lawns and plates are subjects in two
% tiers joined by `member_of`, minted only where a tier has measurements, and a
% patch subject's `local_identifier` is the (experiment, plate, patch) triple.
% Kept in step with runCorpusDiscovery and testFixtureCorpus, in the SAME ORDER,
% for the same reason as the three passes above: a post-pass wired into some
% call sites and not others makes the corpus green while another path does
% something else.
%
% WHAT IT WILL REPORT ON PRED IS NOT PREDICTED HERE. Whether PRED holds any
% ontologyTableRow at all has not been measured, and a guess written in a
% comment becomes a fact the next reader quotes. The pass prints its own
% denominator; read that. It is wired here regardless -- a hard gate that skips
% a pass is a pass one hard gate does not cover -- and it can only APPEND, so on
% a corpus with no such tables it cannot move PRED's zero-quarantine gate.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveLawnPlateSubjects', 'lawn_plate_subjects', ...
    @(r) did2.convert.resolveLawnPlateSubjects(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));

% TEAM DECISION 2026-08-11: the `generic_file` -> opaque_body + statement fold.
% WHAT IT WILL REPORT ON PRED IS NOT PREDICTED HERE beyond one measured fact:
% run 31327383671 found ZERO `generic_file` documents in any of the six
% corpora, PRED included, so the expected line is `generic_files_seen 0` and
% that is a statement about the SAMPLE, not about the fold. It is wired here
% regardless -- a hard gate that skips a pass is a pass no hard gate covers --
% and on a corpus with no such documents it cannot move PRED's zero-quarantine
% gate, because with nothing to fold it returns before minting anything.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.foldGenericFiles', 'generic_file_fold', ...
    @(r) did2.convert.foldGenericFiles(r, 'Validate', true, ...
        'TargetVersion', 'V_eta'));

% TEAM DECISION 2026-08-11: `valid_interval` becomes a boolean-valued
% `subject_statement`. Wired here for the same reason as the four above, in the
% SAME ORDER -- a post-pass wired into some call sites and not others makes one
% path green while another does something else.
%
% ORDER: after epochMint, and that dependence is REAL rather than conventional
% -- it anchors to the `epoch` documents epochMint appends, and run before them
% it would refuse every interval and change nothing.
%
% WHAT IT WILL REPORT ON PRED, with the one measured fact and no guess beyond
% it: run 31327383671 found ZERO `valid_interval` documents in any of the six
% corpora, PRED included, so the expected line is `sources_seen 0` -- a
% statement about the SAMPLE, not about the decompose. It cannot move PRED's
% zero-quarantine gate on such a corpus: with nothing to decompose it returns
% before minting anything, and it never removes a document in any case.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveValidIntervals', 'valid_interval_decompose', ...
    @(r) did2.convert.resolveValidIntervals(r, 'Validate', true, ...
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
% Epoch-string retention, for the reason the paragraph above gives: a corpus we
% gate on but never measure is a denominator missing from every figure we quote,
% and PRED is the corpus that had to be told twice. Sited AFTER every batch
% post-pass above, exactly as in runCorpusDiscovery -- `retained_as_epoch_document`
% only means anything once `epochMint` has run, and a pass-1 reading would be
% structurally 0 (the silentLoss tautology, v1_to_v2.m:382 / 203c1f7).
%
% REPORT-ONLY. PRED is a HARD 0-quarantine gate and this instrument is
% deliberately not part of it: nothing has measured the drop yet, so there is no
% number to gate on. PRED is also 31-37 documents, so expect
% `v1_pairs` to be small or 0 -- and 0 there is "this corpus carried no epoch
% string", NOT "nothing was dropped".
try
    result.epoch_string_retention = did2.validate.epochStringRetention( ...
        bodies, result.migrated);
catch retentionErr
    result.epoch_string_retention = struct('audit_failed', retentionErr.message);
end
reasons = did2.unittest.helpers.topQuarantineReasons(result.quarantine);
did2.unittest.helpers.writeCorpusReport('PRED', result, reasons);

% THE REPORT IS ON DISK -- now make a guarded post-pass failure FATAL. PRED is
% the hard gate, so this is where a batch pass that threw must turn the build
% red. Doing it here rather than letting the pass throw above is the whole
% point of the guard: the artifact lands AND the gate fires, instead of one at
% the cost of the other.
% NOTE, not a change: `response_parameters_fold`, `lawn_plate_subjects` and
% `openminds_citations` are wired above but are NOT in this list, so a throw in
% any of them is recorded in the report and does not turn PRED red. That is
% someone else's call to make; it is written down here rather than silently
% fixed, because a hard gate that covers three of six passes reads exactly like
% one that covers six. `openminds_citations` is here for the same reason as the
% other two -- it has never been executed, and red-gating everyone on an
% unexecuted pass's first run is the judgement resolveSessionAnchors's author
% made and was right about.
% `deferred_bath_resolution` and `dataset_entity_resolution` ARE in the list,
% for the opposite reason to the three above: both ran BARE here for months,
% where a throw was already fatal. Guarding them 2026-08-11 protects the
% artifact; omitting them from this list would have silently downgraded two
% hard failures to log lines.
for passField = {'deferred_bath_resolution', 'dataset_entity_resolution', ...
                 'epoch_mint', 'session_anchor_fold', 'generic_file_fold'}
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
