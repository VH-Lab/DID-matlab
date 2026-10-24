function tests = testSqliteDbQueryShapes
% testSqliteDbQueryShapes - value shapes and negations through did2.database.sqlitedb.
%
%   Regression tests for three defects of did2.database.compileQuery found
%   while building `hasanyelement` (2026-10-21). Every search is compared
%   with the in-memory evaluator over the same documents: the SQL may
%   over-approximate (the recheck makes it exact), so a true match the SQL
%   DROPPED shows up here as a missing hit, and a SQL error as an error.
%
%   1. An ordinary `[*]` path not in the queryable_array_elem sidecar ran
%      json_each over the array. jsonencode writes a one-entry array of
%      structures as an OBJECT, so json_each stepped through its fields and
%      handed a text field to json_extract: SQLite raised "malformed JSON".
%   2. `hasmember` handed a text value to json_each (the same error), and
%      `hasanysubfield_exact_string` had the one-entry-object defect of 1.
%   3. A negated term compiled as NOT of an over-approximation: ~regexp and
%      ~exact_number of an array became `(v IS NULL OR NOT (1=1))`, and
%      ~contains_string became NOT LIKE (which ignores case), so documents
%      the evaluator matches were dropped before the recheck could see them.
%
%   demoA.axes and demoA.multiscales are open-shape (no sidecar); demoA.tags
%   is a string list; demoArray.axes[*].unit / .size are in the sidecar,
%   which keeps no row for an empty leaf (arrayBlank's second unit).
%
%   The whole file is filtered out if mksqlite is not on the MATLAB path.
%
%   Run with:
%       results = runtests('did2.unittest.testSqliteDbQueryShapes');

tests = functiontests(localfunctions);
end

% ---- fixture setup / teardown ----

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping the v2 SQLite tests.');
end
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal');
did2.schema.cache.setSchemaPath(fixtureDir);
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.tmpFile = [tempname() '.sqlite'];
db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
oneDataset = struct('datasets', struct('path', '0/img'));
docs = { ...
    makeDemoA('oneAxis', 'Alpha', ...
        struct('name', 'x', 'unit', 'deg'), 'green', oneDataset), ...
    makeDemoA('twoAxes', 'beta', ...
        struct('name', {'y', 'x'}, 'unit', {'um', 'um'}), {'red', 'green'}, []), ...
    makeDemoA('oneTag', 'alpha', [], {'green'}, ...
        struct('datasets', {struct('path', {'1/img', '1/lbl'}), struct('path', '2/img')})), ...
    makeDemoA('otherTag', 'gamma', struct('name', 'z', 'unit', 'deg'), 'blue', []), ...
    makeDemoA('bare', 'delta', [], [], []), ...
    makeDemoArray('arrayOne', struct('name', 'o', 'unit', 'pct', 'size', 45)), ...
    makeDemoArray('arrayTwo', struct('name', {'p', 'q'}, 'unit', {'deg', 'pct'}, 'size', {10, 90})), ...
    makeDemoArray('arrayBlank', struct('name', {'r', 's'}, 'unit', {'deg', ''}, 'size', {10, 90}))};
db.add(docs);
testCase.TestData.docs = docs;
end

function teardown(testCase)
try
    testCase.TestData.db.close();
catch
end
if isfile(testCase.TestData.tmpFile)
    delete(testCase.TestData.tmpFile);
end
end

% ---- helpers ----

function doc = makeDemoA(name, value, axes, tags, multiscales)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', value);
if ~isempty(axes)
    doc = doc.set('demoA.axes', axes);
end
if ~isempty(tags)
    doc = doc.set('demoA.tags', tags);
end
if ~isempty(multiscales)
    doc = doc.set('demoA.multiscales', multiscales);
end
end

function doc = makeDemoArray(name, axes)
doc = did2.document.blank('demoArray');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoArray.axes', axes);
end

function names = searchNames(testCase, q)
% Names the database returns, checked against the in-memory evaluator
% over the same documents.
hits = testCase.TestData.db.search(q);
names = sort(cellfun(@(d) d.get('base.name'), hits, 'UniformOutput', false));
docs = testCase.TestData.docs;
expected = {};
for k = 1:numel(docs)
    if q.matches(docs{k})
        expected{end+1} = docs{k}.get('base.name'); %#ok<AGROW>
    end
end
testCase.verifyEqual(names, sort(expected), ...
    'the database and the in-memory evaluator must agree');
end

% ---- 1. a [*] path over a one-entry array (an object in the JSON) ----

function testStarPathOverAOneEntryArray(testCase)
q = did2.query('demoA.axes[*].name', 'exact_string', 'x');
verifyEqual(testCase, searchNames(testCase, q), sort({'oneAxis', 'twoAxes'}));
q = did2.query('demoA.axes[*].unit', 'contains_string', 'de');
verifyEqual(testCase, searchNames(testCase, q), sort({'oneAxis', 'otherTag'}));
q = did2.query('demoA.axes', 'hasanysubfield_contains_string', 'name', 'z');
verifyEqual(testCase, searchNames(testCase, q), {'otherTag'});
end

function testNegatedStarPathOverAOneEntryArray(testCase)
q = did2.query('demoA.axes[*].name', '~exact_string', 'x');
names = searchNames(testCase, q);
verifyFalse(testCase, any(strcmp(names, 'oneAxis')));
verifyTrue(testCase, any(strcmp(names, 'otherTag')));
end

function testStarHasfieldOverAOneEntryArray(testCase)
q = did2.query('demoA.axes[*].unit', 'hasfield');
verifyEqual(testCase, searchNames(testCase, q), sort({'oneAxis', 'otherTag', 'twoAxes'}));
searchNames(testCase, did2.query('demoA.axes[*].unit', '~hasfield'));
searchNames(testCase, did2.query('demoA.axes[*]', 'hasfield'));
searchNames(testCase, did2.query('demoA.axes[*]', '~hasfield'));
end

function testNestedStarPathsOverOneEntryArrays(testCase)
q = did2.query('demoA.multiscales[*].datasets[*].path', 'exact_string', '0/img');
verifyEqual(testCase, searchNames(testCase, q), {'oneAxis'});
q = did2.query('demoA.multiscales[*].datasets[*].path', 'exact_string', '2/img');
verifyEqual(testCase, searchNames(testCase, q), {'oneTag'});
searchNames(testCase, did2.query('demoA.multiscales[*].datasets[*].path', '~exact_string', '0/img'));
end

function testTheSidecarRouteAgrees(testCase)
% unit and size are in the sidecar, name is not; the one-entry document
% must be found by both routes
verifyEqual(testCase, searchNames(testCase, ...
    did2.query('demoArray.axes[*].unit', 'exact_string', 'pct')), sort({'arrayOne', 'arrayTwo'}));
verifyEqual(testCase, searchNames(testCase, ...
    did2.query('demoArray.axes[*].name', 'exact_string', 'o')), {'arrayOne'});
searchNames(testCase, did2.query('demoArray.axes[*].size', '~exact_number', 45));
% the sidecar has no row for an empty leaf, so these read the body
verifyEqual(testCase, searchNames(testCase, ...
    did2.query('demoArray.axes[*].unit', 'exact_string', '')), {'arrayBlank'});
searchNames(testCase, did2.query('demoArray.axes[*].unit', 'regexp', '^$'));
% a REAL column's affinity turns '45' into 45; the evaluator never equates them
searchNames(testCase, did2.query('demoArray.axes[*].size', '~exact_string', '45'));
end

% ---- 2. hasmember and hasanysubfield_exact_string ----

function testHasmemberOnATextValueAndOneEntryList(testCase)
% 'green' is stored as a JSON string on oneAxis, a one-entry array on
% oneTag and an entry of a longer array on twoAxes
q = did2.query('demoA.tags', 'hasmember', 'green');
verifyEqual(testCase, searchNames(testCase, q), sort({'oneAxis', 'oneTag', 'twoAxes'}));
q = did2.query('demoA.tags', '~hasmember', 'green');
verifyEqual(testCase, searchNames(testCase, q), ...
    sort({'arrayBlank', 'arrayOne', 'arrayTwo', 'bare', 'otherTag'}));
verifyEmpty(testCase, searchNames(testCase, did2.query('demoA.tags', 'hasmember', 'yellow')));
searchNames(testCase, did2.query('demoA.tags', 'hasmember', 5));
searchNames(testCase, did2.query('demoA.tags', '~hasmember', 5));
end

function testHasmemberUnderAStar(testCase)
searchNames(testCase, did2.query('demoA.axes[*].name', 'hasmember', 'x'));
searchNames(testCase, did2.query('demoA.axes[*].name', '~hasmember', 'x'));
end

function testHasanysubfieldExactOverAOneEntryArray(testCase)
q = did2.query('demoA.axes', 'hasanysubfield_exact_string', {'name', 'unit'}, {'x', 'deg'});
verifyEqual(testCase, searchNames(testCase, q), {'oneAxis'});
q = did2.query('demoA.axes', 'hasanysubfield_exact_string', {'name', 'unit'}, {'x', 'um'});
verifyEqual(testCase, searchNames(testCase, q), {'twoAxes'});
q = did2.query('demoA.axes', '~hasanysubfield_exact_string', {'name', 'unit'}, {'x', 'deg'});
names = searchNames(testCase, q);
verifyFalse(testCase, any(strcmp(names, 'oneAxis')));
verifyTrue(testCase, any(strcmp(names, 'twoAxes')));
end

% ---- 3. negation never drops a true match ----

function testNegatedRegexpAtTopLevel(testCase)
% was (v IS NULL OR NOT (1=1)): only documents WITHOUT the field
q = did2.query('demoA.value', '~regexp', '^a');
names = searchNames(testCase, q);
verifyTrue(testCase, any(strcmp(names, 'twoAxes')), 'beta does not match ^a');
verifyTrue(testCase, any(strcmp(names, 'oneAxis')), 'Alpha does not match ^a');
verifyFalse(testCase, any(strcmp(names, 'oneTag')));
end

function testNegatedArrayExactNumberAtTopLevel(testCase)
% no text value equals an array: every document matches the negation
q = did2.query('demoA.value', '~exact_number', [1 2]);
verifyEqual(testCase, numel(searchNames(testCase, q)), numel(testCase.TestData.docs));
end

function testNegatedContainsStringIsCaseSensitive(testCase)
% NOT LIKE '%alp%' dropped 'Alpha', which the evaluator keeps
q = did2.query('demoA.value', '~contains_string', 'alp');
names = searchNames(testCase, q);
verifyTrue(testCase, any(strcmp(names, 'oneAxis')));
verifyFalse(testCase, any(strcmp(names, 'oneTag')));
end

function testNegatedUnexpressibleOnTheOtherRoutes(testCase)
% the json_each, sidecar and session-column routes
searchNames(testCase, did2.query('demoA.axes[*].name', '~regexp', '^x'));
searchNames(testCase, did2.query('demoArray.axes[*].unit', '~regexp', '^p'));
searchNames(testCase, did2.query('demoArray.axes[*].size', '~exact_number', [1 2]));
searchNames(testCase, did2.query('base.session_id', '~regexp', 'one'));
searchNames(testCase, did2.query('base.name', '~wildcard', '*AXIS'));
searchNames(testCase, did2.query('demoA.value', '~exact_string_anycase', 'ALPHA'));
searchNames(testCase, did2.query('demoA.value', '~lessthan', 10));
end
