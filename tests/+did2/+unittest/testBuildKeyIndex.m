function tests = testBuildKeyIndex
%TESTBUILDKEYINDEX A `key` covariate's `index` (Jess Haley, 2026-11-01, "2. Ok",
%   did-schema did_v2_go_forward_class_audit.md [key covariate index]): one
%   0-based entry number per position of the key's dimension; position k is
%   entry index(k) of the keyed document's value. Without `index`, position k
%   is entry k, as before.
%
%   Siblings first: DID-matlab accepts `index` before did-schema declares it.
%   When the loaded schema does not declare the covariate's `index` yet, these
%   tests build against a temporary copy of it whose data.json adds the field
%   (the same definition did-schema adds), and one test checks that the
%   unpatched schema refuses it (did2:build:unknownField). When the loaded
%   schema declares it, the copy is not made and every test runs on the
%   loaded schema.
%
%   Run with:  results = runtests('did2.unittest.testBuildKeyIndex');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping key covariate index tests');
% made-up terms ('gene', 'row'): the registry check is tested elsewhere
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
testCase.TestData.sid = did.ido.unique_id();
cache = did2.schema.cache.shared();
testCase.TestData.loadedPath = cache.schemaPath;
testCase.TestData.loadedDeclaresIndex = declaresIndex(cache);
if ~testCase.TestData.loadedDeclaresIndex
    testCase.TestData.patchedPath = patchedSchemaCopy(testCase, cache.schemaPath);
end
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function setup(testCase)
% each test starts on the schema that declares `index`
if testCase.TestData.loadedDeclaresIndex
    did2.schema.cache.setSchemaPath(testCase.TestData.loadedPath);
else
    did2.schema.cache.setSchemaPath(testCase.TestData.patchedPath);
end
end

function teardown(testCase)
did2.schema.cache.setSchemaPath(testCase.TestData.loadedPath);
end

function id = newId()
id = did.ido.unique_id();
end

function doc = mapping(testCase, covs, n)
% a value with one `row` dimension of N positions and the given covariates,
% keyed to two documents (the two gene lists of a gene-list mapping)
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, n)), ...
    'Dimensions', did2.build.dimension('row', n), ...
    'Covariates', covs, 'KeyIds', {newId(), newId()}, ...
    'TimeReferenceIds', {newId()}, 'SessionId', testCase.TestData.sid, ...
    'ValueKind', 'voltage');
end

function verifyRule(testCase, fn, ruleName)
try
    fn();
    verifyFail(testCase, sprintf('no error; wanted did2:build:ruleViolated for %s', ruleName));
catch err
    verifyEqual(testCase, err.identifier, 'did2:build:ruleViolated');
    verifySubstring(testCase, err.message, ruleName);
end
end

% ===================== the builder ==========================================

function testIndexIsWrittenOnAKeyCovariate(testCase)
c = did2.build.covariate('gene', 0, 'Key', 0, 'Index', [5 5 9]);
verifyEqual(testCase, c.key, 0);
verifyEqual(testCase, c.index, [5 5 9]);
% without 'Index' no `index` is written: position k is entry k
c = did2.build.covariate('gene', 0, 'Key', 1);
verifyFalse(testCase, isfield(c, 'index') && ~isempty(c.index));
end

function testIndexGoesOnlyWithKey(testCase)
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Count', [1 2 3], 'Index', [0 1 2]), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Term', {'a', 'b'}, 'Index', [0 1]), ...
    'did2:build:ruleViolated');
end

function testIndexHoldsZeroBasedEntryNumbers(testCase)
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Key', 0, 'Index', [0 -1 2]), ...
    'did2:build:typeMismatch');
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Key', 0, 'Index', [0 1.5]), ...
    'did2:build:typeMismatch');
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Key', 0, 'Index', [0 NaN]), ...
    'did2:build:typeMismatch');
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Key', 0, 'Index', {0, 1}), ...
    'did2:build:typeMismatch');
% 0 is a real entry
c = did2.build.covariate('gene', 0, 'Key', 0, 'Index', [0 0 0]);
verifyEqual(testCase, c.index, [0 0 0]);
end

% ===================== the document: covariate_shape ========================

function testTheTwoGeneColumnsOfAMapping(testCase)
% the sketch Jess Haley approved: {variable: Gene, along: [0], key: 0,
% index: [5, 5, 9]} and {..., key: 1, index: [12, 30, 4]}
covs = did2.build.list( ...
    did2.build.covariate('gene', 0, 'Key', 0, 'Index', [5 5 9]), ...
    did2.build.covariate('gene', 0, 'Key', 1, 'Index', [12 30 4]));
doc = mapping(testCase, covs, 3);
verifyEqual(testCase, doc.data.covariates(1).index, [5 5 9]);
verifyEqual(testCase, doc.data.covariates(2).index, [12 30 4]);
verifyEqual(testCase, [doc.data.covariates.key], [0 1]);
end

function testIndexHasOneEntryPerPosition(testCase)
verifyRule(testCase, @() mapping(testCase, ...
    did2.build.covariate('gene', 0, 'Key', 0, 'Index', [5 5]), 3), 'covariate_shape');
verifyRule(testCase, @() mapping(testCase, ...
    did2.build.covariate('gene', 0, 'Key', 0, 'Index', [5 5 9 1]), 3), 'covariate_shape');
end

function testAKeyWithoutIndexStillBuilds(testCase)
doc = mapping(testCase, did2.build.covariate('gene', 0, 'Key', 0), 3);
verifyEqual(testCase, doc.data.covariates.key, 0);
verifyTrue(testCase, ~isfield(doc.data.covariates, 'index') || isempty(doc.data.covariates.index));
end

function testCheckRulesRefusesAnIndexBesideAnotherForm(testCase)
% a hand-made entry (not through did2.build.covariate): `index` beside a
% `count` is refused by the document check, under covariate_one_value_form
c = did2.build.composite('data', 'covariates', ...
    struct('variable', 'trial number', 'along', 0, 'count', [1 2 3], 'index', [0 1 2]));
verifyRule(testCase, @() mapping(testCase, c, 3), 'covariate_one_value_form');
% and a negative entry, under covariate_shape
c = did2.build.composite('data', 'covariates', ...
    struct('variable', 'gene', 'along', 0, 'key', 0, 'index', [0 -1 2]));
verifyRule(testCase, @() mapping(testCase, c, 3), 'covariate_shape');
end

% ===================== a schema without `index` =============================

function testASchemaWithoutIndexRefusesIt(testCase)
if testCase.TestData.loadedDeclaresIndex
    return;   % the loaded schema declares it: nothing to refuse
end
did2.schema.cache.setSchemaPath(testCase.TestData.loadedPath);
verifyError(testCase, @() did2.build.covariate('gene', 0, 'Key', 0, 'Index', [5 5 9]), ...
    'did2:build:unknownField');
% a key covariate without it builds as before
c = did2.build.covariate('gene', 0, 'Key', 0);
verifyEqual(testCase, c.key, 0);
end

% ===================== helpers ==============================================

function tf = declaresIndex(cache)
% whether the loaded data.json declares covariates.index
tf = false;
files = did2.schema.cache.classFilesIn(cache.schemaPath);
if ~isKey(files, 'data')
    return;
end
data = jsondecode(fileread(files('data')));
fields = data.data;
if ~iscell(fields); fields = num2cell(fields); end
for k = 1:numel(fields)
    if strcmp(char(fields{k}.name), 'covariates')
        sub = fields{k}.subfields;
        if ~iscell(sub); sub = num2cell(sub); end
        tf = any(cellfun(@(s) strcmp(char(s.name), 'index'), sub));
        return;
    end
end
end

function p = patchedSchemaCopy(testCase, schemaPath)
% A temporary copy of the loaded schema set whose data.json declares the
% covariate's `index` after `key`, as did-schema declares it.
root = did2.schema.cache.registrySearchRoot(schemaPath);
here = dir(root);
rootAbs = here(1).folder;
here = dir(schemaPath);
schemaAbs = here(1).folder;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
dest = fullfile(tmp, 'schemas');
copyfile(rootAbs, dest);
rel = schemaAbs(numel(rootAbs)+1:end);
p = [dest rel];
files = did2.schema.cache.classFilesIn(p);
f = files('data');
txt = fileread(f);
k = strfind(txt, '"name": "key"');
assert(isscalar(k), 'testBuildKeyIndex: data.json declares %d `key` fields; expected 1.', numel(k));
c = strfind(txt(k:end), '"constraints"');
assert(~isempty(c), 'testBuildKeyIndex: the `key` field has no constraints entry.');
pos = k + c(1) - 1;
brace = find(txt(pos:end) == '}', 2);   % the constraints object, then the field
assert(numel(brace) == 2, 'testBuildKeyIndex: cannot find the end of the `key` field.');
at = pos + brace(2) - 1;
indexDef = ['{"name": "index", "type": "integer", "blank_value": [], "default_value": [], ' ...
    '"mustBeNonEmpty": false, "mustBeScalar": false, "mustNotHaveNaN": false, ' ...
    '"queryable": true, "ontology": null, ' ...
    '"documentation": "testBuildKeyIndex copy: [key covariate index].", "constraints": {}}'];
txt = [txt(1:at) ', ' indexDef txt(at+1:end)];
fid = fopen(f, 'w');
fwrite(fid, txt);
fclose(fid);
end
