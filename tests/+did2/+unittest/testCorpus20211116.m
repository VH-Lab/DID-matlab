function tests = testCorpus20211116
%TESTCORPUS20211116 Discovery-mode end-to-end run against the 20211116 corpus.
%
%   Pulls the 20211116.zip fixture from the public S3 prefix
%   (~11MB compressed, ~36MB unzipped, ~1220 v1 documents across
%   ~21 classes), runs every contained body through
%   did2.convert.v1_to_v2 with Validate=true, and writes a per-run
%   summary JSON to corpus-reports/20211116-summary.json. The
%   workflow's upload-artifact step picks the file up as a CI
%   artifact.
%
%   Unlike testCorpusPRED, this is **discovery mode**: the test does
%   not assert zero quarantine. Its job is to surface coverage
%   signal (which classes / required fields are not yet migratable)
%   without blocking unrelated PRs on migrator work. The single hard
%   assertion is that the corpus contained at least one JSON file,
%   to catch a broken fixture URL.
%
%   The corpus URL:
%       https://ndi-programming-development.s3.us-east-1.amazonaws.com/20211116.zip
%   The zip contains a top-level 20211116/ directory of v1 NDI
%   document JSONs (plus __MACOSX/ sidecars that are skipped).
%
%   Schema-path resolution mirrors testCorpusPRED: DID_SCHEMA_PATH
%   first, then the did2.schema.cache sibling-checkout default;
%   skips via assumeFail if neither resolves so local devs without a
%   did-schema checkout get a clean skip.
%
%   Run with:
%       results = runtests('did2.unittest.testCorpus20211116');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Seed teardown-safe fields first so teardown is a no-op when
% setupOnce filters via assumeFail before any override happens.
testCase.TestData.previousSchemaPath = getenv('DID_SCHEMA_PATH');
testCase.TestData.didOverrideSchemaPath = false;
testCase.TestData.corpusDir = '';

schemaPath = resolveSchemaPath();
if isempty(schemaPath)
    assumeFail(testCase, ...
        ['V_delta schemas not found. Set DID_SCHEMA_PATH or check out ', ...
         'did-schema as a sibling of DID-matlab; skipping 20211116 corpus test.']);
end
setenv('DID_SCHEMA_PATH', schemaPath);
testCase.TestData.didOverrideSchemaPath = true;
did2.schema.cache.resetSingleton();

testCase.TestData.corpusDir = ensureCorpus( ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/20211116.zip', ...
    'did2-corpus-20211116', '20211116');
end

function teardownOnce(testCase)
if isfield(testCase.TestData, 'didOverrideSchemaPath') ...
        && testCase.TestData.didOverrideSchemaPath
    setenv('DID_SCHEMA_PATH', testCase.TestData.previousSchemaPath);
    did2.schema.cache.resetSingleton();
end
end

function test20211116CorpusDiscoveryReport(testCase)
corpusDir = testCase.TestData.corpusDir;
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
verifyGreaterThan(testCase, numel(files), 0, ...
    sprintf('No JSON files found under %s', corpusDir));

bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end

result = did2.convert.v1_to_v2(bodies, 'Validate', true);

reasons = topQuarantineReasons(result.quarantine);
reportPath = writeReport('20211116', result, reasons);

fprintf('\n=== Corpus 20211116 discovery summary ===\n');
fprintf('total:            %d\n', result.summary.total);
fprintf('migrated_count:   %d\n', result.summary.migrated_count);
fprintf('quarantine_count: %d\n', result.summary.quarantine_count);
fprintf('report:           %s\n', reportPath);
fprintf('top quarantine reasons:\n');
for k = 1:min(numel(reasons), 15)
    fprintf('  %5d  [%s] %s\n', reasons(k).count, ...
        reasons(k).class_name, reasons(k).reason);
end
end

% --- helpers ---

function reasons = topQuarantineReasons(quarantine)
% Aggregate quarantine entries by (class_name, reason) and return a
% struct array sorted by descending count.
if isempty(quarantine)
    reasons = struct('class_name', {}, 'reason', {}, 'count', {});
    return;
end
keys = cell(1, numel(quarantine));
for k = 1:numel(quarantine)
    keys{k} = sprintf('%s|||%s', quarantine(k).class_name, ...
        quarantine(k).reason);
end
[uniqKeys, ~, idx] = unique(keys);
counts = accumarray(idx, 1);
reasons = struct('class_name', {}, 'reason', {}, 'count', {});
for k = 1:numel(uniqKeys)
    parts = strsplit(uniqKeys{k}, '|||');
    reasons(k).class_name = parts{1};
    reasons(k).reason     = parts{2};
    reasons(k).count      = counts(k);
end
[~, order] = sort(-[reasons.count]);
reasons = reasons(order);
end

function reportPath = writeReport(corpusName, result, reasons)
% Write a JSON discovery summary into <pwd>/corpus-reports/. The CI
% workflow's upload-artifact step picks up everything under that
% directory.
reportDir = fullfile(pwd, 'corpus-reports');
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end
reportPath = fullfile(reportDir, [corpusName '-summary.json']);

report = struct( ...
    'corpus',           corpusName, ...
    'generated_at',     char(datetime('now', 'TimeZone', 'UTC', ...
                          'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'total',            result.summary.total, ...
    'migrated_count',   result.summary.migrated_count, ...
    'quarantine_count', result.summary.quarantine_count, ...
    'by_class',         result.summary.by_class, ...
    'quarantine_reasons', reasons);

fid = fopen(reportPath, 'w');
if fid < 0
    error('did2:test:reportWriteFailed', ...
        'Could not open %s for writing.', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(report, 'PrettyPrint', true));
end

function p = resolveSchemaPath()
% Return a directory that holds V_delta `*.json` schema files, or ''
% if none can be found. Probe order: DID_SCHEMA_PATH env, then the
% sibling-checkout default (matches did2.schema.cache).
candidates = {};
envPath = getenv('DID_SCHEMA_PATH');
if ~isempty(envPath)
    candidates{end+1} = envPath; %#ok<AGROW>
end
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

function corpusDir = ensureCorpus(corpusURL, cacheName, innerDir)
% Download (if necessary) and extract a corpus zip. The unzip target
% is cached under tempdir so repeated runs in the same MATLAB
% session reuse the same files.
cacheRoot = fullfile(tempdir(), cacheName);
corpusDir = fullfile(cacheRoot, innerDir);
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~exist(cacheRoot, 'dir')
    mkdir(cacheRoot);
end
zipPath = fullfile(cacheRoot, [innerDir '.zip']);
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
end
