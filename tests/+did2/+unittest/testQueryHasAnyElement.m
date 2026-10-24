function tests = testQueryHasAnyElement
% testQueryHasAnyElement - the correlated `hasanyelement` operator.
%
%   Two `[*]` predicates AND-ed together do not have to hold for the SAME
%   array element (see did2.query), so on an entry list such as a
%   statement's method parameters a document matches when the value
%   belongs to a DIFFERENT entry than the name. `hasanyelement` takes a
%   sub-query whose paths are read relative to one element; the document
%   matches when one element satisfies the whole sub-query.
%
%   This file covers the in-memory evaluator (did2.query) and the SQL the
%   compiler emits (did2.database.compileQuery, as strings). The round
%   trip through a live SQLite database is in
%   did2.unittest.testSqliteDbHasAnyElement.
%
%   Run with:
%       results = runtests('did2.unittest.testQueryHasAnyElement');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal');
did2.schema.cache.setSchemaPath(fixtureDir);
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

% ---- helpers ----

function doc = docWithParameters(names, values)
% A demoA document carrying an ad-hoc entry list demoA.parameters, each
% entry {variable.name, quantity.value} (the evaluator is schema-agnostic
% over its dot-paths).
doc = did2.document.blank('demoA');
doc = doc.set('base.name', 'p');
entries = struct('variable', {}, 'quantity', {});
for k = 1:numel(names)
    entries(k).variable = struct('name', names{k});
    entries(k).quantity = struct('value', values(k));
end
doc = doc.set('demoA.parameters', entries);
end

function q = paramIs(name, value)
q = did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('variable.name', 'exact_string', name), ...
    did2.query('quantity.value', 'exact_number', value)));
end

function verifySubstring(testCase, haystack, needle)
testCase.verifyTrue(contains(haystack, needle), ...
    sprintf('Expected "%s" to contain "%s".', haystack, needle));
end

% ---- the false match ----

function testIndependentStarsMatchAcrossEntries(testCase)
% Current behaviour, kept: two [*] predicates may be satisfied by
% different entries, so {orientation, 90} + {contrast, 45} matches.
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
q = and( ...
    did2.query('demoA.parameters[*].variable.name', 'exact_string', 'orientation'), ...
    did2.query('demoA.parameters[*].quantity.value', 'exact_number', 45));
verifyTrue(testCase, q.matches(doc));
end

function testHasAnyElementRequiresTheSameEntry(testCase)
falseMatch = docWithParameters({'orientation', 'contrast'}, [90 45]);
verifyFalse(testCase, paramIs('orientation', 45).matches(falseMatch));
trueMatch = docWithParameters({'contrast', 'orientation'}, [10 45]);
verifyTrue(testCase, paramIs('orientation', 45).matches(trueMatch));
single = docWithParameters({'orientation'}, 45);
verifyTrue(testCase, paramIs('orientation', 45).matches(single));
end

function testTrailingStarOnTheArrayPathIsIgnored(testCase)
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
q = did2.query('demoA.parameters[*]', 'hasanyelement', ...
    did2.query('quantity.value', 'exact_number', 90));
verifyTrue(testCase, q.matches(doc));
end

% ---- operators inside the sub-query ----

function testNumericComparisonsInTheSubquery(testCase)
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
name = did2.query('variable.name', 'exact_string', 'orientation');
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    and(name, did2.query('quantity.value', 'greaterthan', 50))).matches(doc));
verifyFalse(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    and(name, did2.query('quantity.value', 'lessthan', 50))).matches(doc));
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    and(name, did2.query('quantity.value', 'lessthaneq', 90))).matches(doc));
verifyFalse(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    and(name, did2.query('quantity.value', 'greaterthaneq', 91))).matches(doc));
end

function testStringOperatorsAndHasfieldInTheSubquery(testCase)
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('variable.name', 'contains_string', 'trast'), ...
    did2.query('quantity.value', 'exact_number', 45))).matches(doc));
verifyFalse(testCase, did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('variable.name', 'regexp', '^orient'), ...
    did2.query('quantity.value', 'exact_number', 45))).matches(doc));
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    did2.query('quantity.value', 'hasfield')).matches(doc));
verifyFalse(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    did2.query('quantity.unit', 'hasfield')).matches(doc));
end

function testNestedAndOrInTheSubquery(testCase)
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
sub = and( ...
    or(did2.query('variable.name', 'exact_string', 'direction'), ...
       did2.query('variable.name', 'exact_string', 'contrast')), ...
    did2.query('quantity.value', 'exact_number', 45));
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', sub).matches(doc));
sub = and( ...
    or(did2.query('variable.name', 'exact_string', 'direction'), ...
       did2.query('variable.name', 'exact_string', 'orientation')), ...
    did2.query('quantity.value', 'exact_number', 45));
verifyFalse(testCase, did2.query('demoA.parameters', 'hasanyelement', sub).matches(doc));
end

function testNegatedLeafInTheSubquery(testCase)
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
% an entry that is not orientation, with 45: the contrast entry
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('variable.name', '~exact_string', 'orientation'), ...
    did2.query('quantity.value', 'exact_number', 45))).matches(doc));
verifyFalse(testCase, did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('variable.name', '~exact_string', 'contrast'), ...
    did2.query('quantity.value', 'exact_number', 45))).matches(doc));
end

function testNestedHasAnyElement(testCase)
% An array inside each element.
doc = did2.document.blank('demoA');
doc = doc.set('demoA.groups', struct( ...
    'label', {'a', 'b'}, ...
    'items', {struct('k', {'x', 'y'}, 'v', {1, 2}), struct('k', {'x'}, 'v', {3})}));
inner = @(k, v) did2.query('items', 'hasanyelement', and( ...
    did2.query('k', 'exact_string', k), did2.query('v', 'exact_number', v)));
verifyTrue(testCase, did2.query('demoA.groups', 'hasanyelement', ...
    and(did2.query('label', 'exact_string', 'b'), inner('x', 3))).matches(doc));
verifyFalse(testCase, did2.query('demoA.groups', 'hasanyelement', ...
    and(did2.query('label', 'exact_string', 'b'), inner('y', 2))).matches(doc));
end

% ---- negation, empty and missing arrays ----

function testNegationMeansNoElementMatches(testCase)
doc = docWithParameters({'orientation', 'contrast'}, [90 45]);
neg = @(name, value) did2.query('demoA.parameters', '~hasanyelement', and( ...
    did2.query('variable.name', 'exact_string', name), ...
    did2.query('quantity.value', 'exact_number', value)));
verifyTrue(testCase, neg('orientation', 45).matches(doc));
verifyFalse(testCase, neg('orientation', 90).matches(doc));
end

function testEmptyAndMissingArrays(testCase)
missing = did2.document.blank('demoA');
empty = did2.document.blank('demoA');
empty = empty.set('demoA.parameters', struct('variable', {}, 'quantity', {}));
anyEntry = did2.query('demoA.parameters', 'hasanyelement', did2.query());
for d = {missing, empty}
    verifyFalse(testCase, paramIs('orientation', 45).matches(d{1}));
    verifyFalse(testCase, anyEntry.matches(d{1}));
    verifyTrue(testCase, did2.query('demoA.parameters', '~hasanyelement', ...
        did2.query('quantity.value', 'exact_number', 45)).matches(d{1}));
end
verifyTrue(testCase, anyEntry.matches(docWithParameters({'a'}, 1)));
end

function testFlatListElementIsTheEmptyPath(testCase)
% A sub-query field of '' is the element itself.
doc = did2.document.blank('demoA');
doc = doc.set('demoA.values', [3 8 12]);
verifyTrue(testCase, did2.query('demoA.values', 'hasanyelement', and( ...
    did2.query('', 'greaterthan', 5), did2.query('', 'lessthan', 10))).matches(doc));
verifyFalse(testCase, did2.query('demoA.values', 'hasanyelement', and( ...
    did2.query('', 'greaterthan', 8), did2.query('', 'lessthan', 12))).matches(doc));
end

function testSearchStructSubqueryAndBadSubquery(testCase)
doc = docWithParameters({'orientation'}, 45);
sub = and(did2.query('variable.name', 'exact_string', 'orientation'), ...
    did2.query('quantity.value', 'exact_number', 45));
verifyTrue(testCase, did2.query('demoA.parameters', 'hasanyelement', ...
    sub.searchstructure).matches(doc));
verifyError(testCase, @() did2.query('demoA.parameters', 'hasanyelement', 'orientation'), ...
    'did2:query:badSubquery');
end

% ---- the SQL it compiles to ----

function testCompilesToOneCorrelatedExists(testCase)
[sql, params] = did2.database.compileQuery(paramIs('orientation', 45));
verifySubstring(testCase, sql, 'EXISTS (SELECT 1 FROM json_each(');
verifySubstring(testCase, sql, '''$.demoA.parameters''');
verifySubstring(testCase, sql, ') hae1 WHERE ');
verifySubstring(testCase, sql, 'json_extract((CASE WHEN hae1.type = ''object'' THEN hae1.value END), ''$.variable.name'') = ?');
verifySubstring(testCase, sql, 'json_extract((CASE WHEN hae1.type = ''object'' THEN hae1.value END), ''$.quantity.value'')');
verifyEqual(testCase, params, {'orientation', 45});
verifyEqual(testCase, numel(strfind(sql, 'EXISTS')), 1, 'ONE EXISTS: both predicates on one element');
end

function testNegationCompilesToNotExistsOnlyWhenExact(testCase)
exact = did2.query('demoA.parameters', '~hasanyelement', ...
    did2.query('variable.name', 'exact_string', 'orientation'));
[sql, params] = did2.database.compileQuery(exact);
verifySubstring(testCase, sql, '(NOT EXISTS (SELECT 1 FROM json_each(');
verifyEqual(testCase, params, {'orientation'});
% exact_number is an over-approximation in SQL (CAST), so NOT of it would
% drop true matches: the negated form is left to the recheck.
inexact = did2.query('demoA.parameters', '~hasanyelement', ...
    did2.query('quantity.value', 'exact_number', 45));
[sql, params] = did2.database.compileQuery(inexact);
verifyEqual(testCase, sql, '1=1');
verifyEqual(testCase, params, {});
end

function testInexactNegatedLeafInsideIsPermissive(testCase)
q = did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('variable.name', '~regexp', '^o'), ...
    did2.query('quantity.value', 'exact_number', 45)));
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, '(1=1) AND (CAST(');
verifyEqual(testCase, params, {45});
end

function testSidecarPathAddsAnIndexedPrefilter(testCase)
q = did2.query('demoArray.axes', 'hasanyelement', and( ...
    did2.query('name', 'exact_string', 'x'), ...
    did2.query('size', 'greaterthan', 10)));
arrayPaths = struct('path', {'demoArray.axes[*].unit', 'demoArray.axes[*].size'}, ...
    'affinity', {'TEXT', 'INTEGER'});
[sql, params] = did2.database.compileQuery(q, 'QueryableArrayPaths', arrayPaths);
verifySubstring(testCase, sql, ['documents.id IN (SELECT qae.doc_id FROM queryable_array_elem qae ' ...
    'WHERE qae.path = ? AND CAST(qae.value_num AS REAL) > ?)']);
verifySubstring(testCase, sql, ' AND EXISTS (SELECT 1 FROM json_each(');
verifyEqual(testCase, params, {'demoArray.axes[*].size', 10, 'x', 10});
% no sidecar path among the leaves: no prefilter
[sql, ~] = did2.database.compileQuery(did2.query('demoArray.axes', 'hasanyelement', ...
    did2.query('name', 'exact_string', 'x')), 'QueryableArrayPaths', arrayPaths);
verifyFalse(testCase, contains(sql, 'queryable_array_elem'));
end

function testDocumentLevelOperatorsInsideArePermissive(testCase)
q = did2.query('demoA.parameters', 'hasanyelement', and( ...
    did2.query('', 'isa', 'demoA'), ...
    did2.query('variable.name', 'exact_string', 'orientation')));
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'WHERE (1=1) AND (');
verifyFalse(testCase, contains(sql, 'superclasses'));
verifyEqual(testCase, params, {'orientation'});
end
