function tests = testSqliteDbHasAnyElement
% testSqliteDbHasAnyElement - `hasanyelement` through did2.database.sqlitedb.
%
%   The correlated "same element" operator (see did2.query) round-tripped
%   through a real SQLite file: every search is compared with the
%   in-memory evaluator over the same documents (the SQL may over-
%   approximate, the recheck makes it exact, and a true match the SQL
%   DROPPED would show up here as a missing hit), and where the compiled
%   SQL is meant to be exact the raw SQL row set is checked too, so the
%   false match is excluded by the SQL itself and not only by the recheck.
%
%   demoArray.axes is an entry list whose `unit` (TEXT) and `size`
%   (INTEGER) are in the queryable_array_elem sidecar and whose `name` is
%   not, so the sidecar-prefiltered and plain json_each paths both run.
%
%   The whole file is filtered out if mksqlite is not on the MATLAB path.
%
%   Run with:
%       results = runtests('did2.unittest.testSqliteDbHasAnyElement');

tests = functiontests(localfunctions);
end

% ---- fixture setup / teardown ----

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping the v2 SQLite tests.');
end
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
did2.schema.cache.setSchemaPath(fixtureDir);
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.tmpFile = [tempname() '.sqlite'];
db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
% name / unit / size: the entry's "variable", a text and a number.
docs = { ...
    makeDemoArray('falseMatch', {'orientation', 'deg', 90; 'contrast', 'pct', 45}), ...
    makeDemoArray('single',     {'orientation', 'deg', 45}), ...
    makeDemoArray('second',     {'contrast', 'pct', 10; 'orientation', 'deg', 45}), ...
    makeDemoArray('direction',  {'direction', 'deg', 45; 'contrast', 'pct', 90}), ...
    makeDemoArray('empty',      cell(0, 3)), ...
    makeMissing('missing')};
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

function doc = makeDemoArray(name, rows)
doc = did2.document.blank('demoArray');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
if isempty(rows)
    axes = struct('name', {}, 'unit', {}, 'size', {});
else
    axes = struct('name', rows(:, 1)', 'unit', rows(:, 2)', 'size', rows(:, 3)');
end
doc = doc.set('demoArray.axes', axes);
end

function doc = makeMissing(name)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', 'v');
end

function names = searchNames(testCase, q)
% Names the database returns, checked against the in-memory evaluator.
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

function names = sqlNames(testCase, q)
% Names the compiled SQL ALONE returns, before the in-memory recheck.
db = testCase.TestData.db;
r = db.testHookExplain(q);
rows = mksqlite(db.testHookDbId(), r.sql, r.params{:});
names = {};
for k = 1:numel(rows)
    body = jsondecode(rows(k).body);
    names{end+1} = body.base.name; %#ok<AGROW>
end
names = sort(names);
end

function q = axisIs(name, size)
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', 'exact_string', name), ...
    did2.query('size', 'exact_number', size)));
end

% ---- the false match ----

function testIndependentStarsStillMatchAcrossEntries(testCase)
% Current behaviour, kept: and() of two [*] predicates matches the
% document whose 45 belongs to the contrast entry.
q = and(did2.query('demoArray.axes[*].name', 'exact_string', 'orientation'), ...
    did2.query('demoArray.axes[*].size', 'exact_number', 45));
names = searchNames(testCase, q);
verifyTrue(testCase, any(strcmp(names, 'falseMatch')));
end

function testHasAnyElementExcludesTheFalseMatch(testCase)
names = searchNames(testCase, axisIs('orientation', 45));
verifyEqual(testCase, names, sort({'second', 'single'}));
% excluded by the SQL itself, not only by the recheck
verifyEqual(testCase, sqlNames(testCase, axisIs('orientation', 45)), sort({'second', 'single'}));
end

function testOneEntryStoredAsAnObjectIsOneElement(testCase)
% jsonencode writes a 1x1 struct array as an object, not a one-entry
% array; the SQL must still see it as one element.
names = searchNames(testCase, did2.query('demoArray.axes', 'hasanyelement', ...
    did2.query('name', 'exact_string', 'orientation')));
verifyEqual(testCase, names, sort({'falseMatch', 'second', 'single'}));
verifyTrue(testCase, any(strcmp(sqlNames(testCase, axisIs('orientation', 45)), 'single')));
end

% ---- comparisons, string operators, and/or ----

function testNumericComparisons(testCase)
mk = @(op, v) did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', 'exact_string', 'orientation'), did2.query('size', op, v)));
verifyEqual(testCase, searchNames(testCase, mk('greaterthan', 50)), {'falseMatch'});
verifyEqual(testCase, searchNames(testCase, mk('lessthan', 50)), sort({'second', 'single'}));
verifyEqual(testCase, searchNames(testCase, mk('lessthaneq', 90)), sort({'falseMatch', 'second', 'single'}));
verifyEmpty(testCase, searchNames(testCase, mk('greaterthaneq', 91)));
end

function testStringOperatorsInTheSubquery(testCase)
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', 'contains_string', 'trast'), ...
    did2.query('size', 'exact_number', 45)));
verifyEqual(testCase, searchNames(testCase, q), {'falseMatch'});
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', 'regexp', '^dir'), ...
    did2.query('unit', 'exact_string', 'deg')));
verifyEqual(testCase, searchNames(testCase, q), {'direction'});
end

function testNestedAndOrInTheSubquery(testCase)
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    or(did2.query('name', 'exact_string', 'direction'), ...
       did2.query('name', 'exact_string', 'orientation')), ...
    and(did2.query('unit', 'exact_string', 'deg'), ...
        did2.query('size', 'greaterthan', 50))));
verifyEqual(testCase, searchNames(testCase, q), {'falseMatch'});
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    or(did2.query('name', 'exact_string', 'direction'), ...
       did2.query('name', 'exact_string', 'contrast')), ...
    did2.query('size', 'exact_number', 90)));
verifyEqual(testCase, searchNames(testCase, q), {'direction'});
end

function testNegatedLeavesInTheSubquery(testCase)
% exact (compiled) and inexact (left to the recheck) negated leaves
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', '~exact_string', 'orientation'), ...
    did2.query('size', 'exact_number', 45)));
verifyEqual(testCase, searchNames(testCase, q), sort({'direction', 'falseMatch'}));
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', '~regexp', '^or'), ...
    did2.query('size', 'exact_number', 45)));
verifyEqual(testCase, searchNames(testCase, q), sort({'direction', 'falseMatch'}));
end

% ---- negation, empty and missing arrays ----

function testNegationMeansNoElementMatches(testCase)
% Exact sub-query: NOT EXISTS in SQL.
q = did2.query('demoArray.axes', '~hasanyelement', ...
    did2.query('name', 'exact_string', 'contrast'));
expected = sort({'single', 'empty', 'missing'});
verifyEqual(testCase, searchNames(testCase, q), expected);
verifyEqual(testCase, sqlNames(testCase, q), expected);
% Inexact sub-query: the SQL is permissive, the recheck decides.
q = did2.query('demoArray.axes', '~hasanyelement', and( ...
    did2.query('name', 'exact_string', 'orientation'), ...
    did2.query('size', 'exact_number', 45)));
verifyEqual(testCase, searchNames(testCase, q), sort({'direction', 'empty', 'falseMatch', 'missing'}));
end

function testEmptyAndMissingArrays(testCase)
anyAxis = did2.query('demoArray.axes', 'hasanyelement', did2.query());
verifyEqual(testCase, searchNames(testCase, anyAxis), ...
    sort({'direction', 'falseMatch', 'second', 'single'}));
verifyEqual(testCase, sqlNames(testCase, anyAxis), ...
    sort({'direction', 'falseMatch', 'second', 'single'}));
end

% ---- the sidecar ----

function testSidecarPrefilterIsUsedAndCorrelationKept(testCase)
db = testCase.TestData.db;
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('unit', 'exact_string', 'pct'), ...
    did2.query('size', 'exact_number', 90)));
r = db.testHookExplain(q);
verifyTrue(testCase, contains(r.sql, 'queryable_array_elem'), ...
    'a sidecar path in the sub-query should prefilter through the sidecar');
% pct/45 is in falseMatch, pct/90 in direction; only direction has them
% on ONE axis.
verifyEqual(testCase, searchNames(testCase, q), {'direction'});
verifyEqual(testCase, sqlNames(testCase, q), {'direction'});
end
