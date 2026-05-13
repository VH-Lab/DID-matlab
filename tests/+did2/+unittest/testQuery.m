function tests = testQuery
% testQuery - exercises did2.query against V_delta documents.
%
%   Run with:
%       results = runtests('did2.unittest.testQuery');
%
%   Covers: search-struct construction, AND/OR composition, every
%   operator named in did-schema/schemas/did_query_model.md, the `~`
%   negation prefix, dot-paths with `[*]` array-iteration segments, and
%   the independent (uncorrelated) array-predicate semantics.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
did2.schema.cache.setSchemaPath(fixtureDir);
testCase.TestData.fixtureDir = fixtureDir;
testCase.TestData.cache = did2.schema.cache.shared();
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

% ---- helpers ----

function doc = makeDemoB(testCase, name, valueA, valueB)
doc = did2.document.blank('demoB');
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', valueA);
doc = doc.set('demoB.value_b', valueB);
testCase.assertEqual(doc.className(), 'demoB');
end

function doc = makeDemoA(testCase, name, valueA)
doc = did2.document.blank('demoA');
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', valueA);
testCase.assertEqual(doc.className(), 'demoA');
end

% ---- construction & shape ----

function testEmptyQueryMatchesAnything(testCase)
q = did2.query();
doc = makeDemoA(testCase, 'alice', 'a1');
verifyTrue(testCase, q.matches(doc));
end

function testSearchstructShape(testCase)
q = did2.query('base.name', 'exact_string', 'alice');
verifyTrue(testCase, isscalar(q.searchstructure));
verifyEqual(testCase, q.searchstructure.field, 'base.name');
verifyEqual(testCase, q.searchstructure.operation, 'exact_string');
verifyEqual(testCase, q.searchstructure.param1, 'alice');
verifyEqual(testCase, q.searchstructure.param2, '');
end

function testRejectsUnknownOperator(testCase)
verifyError(testCase, ...
    @() did2.query('base.id', 'not_a_real_op', ''), ...
    'did2:query:badOperator');
end

% ---- scalar operators ----

function testExactString(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyTrue(testCase, did2.query('base.name', 'exact_string', 'alice').matches(doc));
verifyFalse(testCase, did2.query('base.name', 'exact_string', 'bob').matches(doc));
end

function testExactStringNegation(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyFalse(testCase, did2.query('base.name', '~exact_string', 'alice').matches(doc));
verifyTrue(testCase, did2.query('base.name', '~exact_string', 'bob').matches(doc));
end

function testContainsString(testCase)
doc = makeDemoA(testCase, 'alice in chains', 'a1');
verifyTrue(testCase, did2.query('base.name', 'contains_string', 'in chains').matches(doc));
verifyFalse(testCase, did2.query('base.name', 'contains_string', 'zzz').matches(doc));
end

function testRegexp(testCase)
doc = makeDemoA(testCase, 'subject_007', 'a1');
verifyTrue(testCase, did2.query('base.name', 'regexp', '^subject_\d+$').matches(doc));
verifyFalse(testCase, did2.query('base.name', 'regexp', '^foo').matches(doc));
end

function testExactStringAnycase(testCase)
doc = makeDemoA(testCase, 'Alice', 'a1');
verifyTrue(testCase, did2.query('base.name', 'exact_string_anycase', 'alice').matches(doc));
verifyFalse(testCase, did2.query('base.name', 'exact_string', 'alice').matches(doc));
end

function testHasfield(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyTrue(testCase, did2.query('base.name', 'hasfield', '').matches(doc));
verifyFalse(testCase, did2.query('base.missing', 'hasfield', '').matches(doc));
verifyTrue(testCase, did2.query('base.missing', '~hasfield', '').matches(doc));
end

function testNumericComparisons(testCase)
doc = did2.document.blank('demoA');
doc = doc.set('demoA.value', 5);
verifyTrue(testCase, did2.query('demoA.value', 'exact_number', 5).matches(doc));
verifyTrue(testCase, did2.query('demoA.value', 'lessthan', 6).matches(doc));
verifyTrue(testCase, did2.query('demoA.value', 'lessthaneq', 5).matches(doc));
verifyTrue(testCase, did2.query('demoA.value', 'greaterthan', 4).matches(doc));
verifyTrue(testCase, did2.query('demoA.value', 'greaterthaneq', 5).matches(doc));
verifyFalse(testCase, did2.query('demoA.value', 'lessthan', 5).matches(doc));
verifyFalse(testCase, did2.query('demoA.value', 'exact_number', 6).matches(doc));
end

function testMissingFieldDoesNotMatchScalar(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyFalse(testCase, did2.query('base.does_not_exist', 'exact_string', 'x').matches(doc));
verifyTrue(testCase, did2.query('base.does_not_exist', '~exact_string', 'x').matches(doc));
end

% ---- isa ----

function testIsaMatchesOwnClass(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyTrue(testCase, did2.query('', 'isa', 'demoA').matches(doc));
end

function testIsaMatchesSuperclass(testCase)
doc = makeDemoB(testCase, 'alice', 'a1', 'b1');
verifyTrue(testCase, did2.query('', 'isa', 'demoB').matches(doc));
verifyTrue(testCase, did2.query('', 'isa', 'demoA').matches(doc));
verifyTrue(testCase, did2.query('', 'isa', 'base').matches(doc));
end

function testIsaRejectsUnrelated(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyFalse(testCase, did2.query('', 'isa', 'demoC').matches(doc));
verifyTrue(testCase, did2.query('', '~isa', 'demoC').matches(doc));
end

function testQueryAllMatches(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyTrue(testCase, did2.query.all().matches(doc));
end

function testQueryNoneRejects(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyFalse(testCase, did2.query.none().matches(doc));
end

% ---- depends_on ----

function testDependsOnMatchesExactEntry(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
doc = doc.set('depends_on', struct('name', {'parent','sibling'}, ...
    'value', {'id-1','id-2'}));
verifyTrue(testCase, did2.query('', 'depends_on', 'parent', 'id-1').matches(doc));
verifyTrue(testCase, did2.query('', 'depends_on', 'sibling', 'id-2').matches(doc));
verifyFalse(testCase, did2.query('', 'depends_on', 'parent', 'id-2').matches(doc));
verifyFalse(testCase, did2.query('', 'depends_on', 'unknown', 'id-1').matches(doc));
end

function testDependsOnWildcardName(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
doc = doc.set('depends_on', struct('name', {'parent'}, 'value', {'id-9'}));
verifyTrue(testCase, did2.query('', 'depends_on', '*', 'id-9').matches(doc));
verifyFalse(testCase, did2.query('', 'depends_on', '*', 'id-X').matches(doc));
end

function testDependsOnEmpty(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
verifyFalse(testCase, did2.query('', 'depends_on', 'parent', 'id-1').matches(doc));
end

% ---- array iteration ----

function testArrayStarExistential(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
% Inject an ad-hoc array-of-structure field (not in V_delta schema, but
% the evaluator is schema-agnostic over its dot-paths).
axes = struct('name', {'x','y','z'}, 'unit', {'micrometer','micrometer','degrees'});
doc = doc.set('demoA.axes', axes);
verifyTrue(testCase, did2.query('demoA.axes[*].name', 'exact_string', 'z').matches(doc));
verifyTrue(testCase, did2.query('demoA.axes[*].unit', 'exact_string', 'micrometer').matches(doc));
verifyTrue(testCase, did2.query('demoA.axes[*].unit', 'exact_string', 'degrees').matches(doc));
verifyFalse(testCase, did2.query('demoA.axes[*].unit', 'exact_string', 'parsec').matches(doc));
end

function testArrayStarIndependentSemantics(testCase)
% The query model spec: two [*] predicates over the same array combined
% with AND do NOT need to be satisfied by the same element.
doc = makeDemoA(testCase, 'alice', 'a1');
axes = struct('name', {'x','y'}, 'unit', {'micrometer','degrees'});
doc = doc.set('demoA.axes', axes);
q = and( ...
    did2.query('demoA.axes[*].name', 'exact_string', 'x'), ...
    did2.query('demoA.axes[*].unit', 'exact_string', 'degrees'));
verifyTrue(testCase, q.matches(doc));  % satisfied by different elements.
end

function testArrayStarNestedPath(testCase)
% Two levels of [*] iteration.
doc = makeDemoA(testCase, 'alice', 'a1');
ms = struct('datasets', { ...
    struct('path', {'0/img','0/lbl'}), ...
    struct('path', {'1/img','1/lbl'})});
doc = doc.set('demoA.multiscales', ms);
verifyTrue(testCase, ...
    did2.query('demoA.multiscales[*].datasets[*].path', 'regexp', '^0/').matches(doc));
verifyFalse(testCase, ...
    did2.query('demoA.multiscales[*].datasets[*].path', 'regexp', '^2/').matches(doc));
end

function testHasanysubfieldContainsString(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
items = struct('name', {'apple','banana'}, 'note', {'tasty','also tasty'});
doc = doc.set('demoA.items', items);
verifyTrue(testCase, did2.query('demoA.items', ...
    'hasanysubfield_contains_string', 'note', 'tasty').matches(doc));
verifyFalse(testCase, did2.query('demoA.items', ...
    'hasanysubfield_contains_string', 'note', 'sour').matches(doc));
end

function testHasmember(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
doc = doc.set('demoA.tags', {'red','green','blue'});
verifyTrue(testCase, did2.query('demoA.tags', 'hasmember', 'green').matches(doc));
verifyFalse(testCase, did2.query('demoA.tags', 'hasmember', 'yellow').matches(doc));
end

% ---- composition ----

function testAndComposition(testCase)
doc = makeDemoB(testCase, 'alice', 'a1', 'b1');
q = and( ...
    did2.query('base.name', 'exact_string', 'alice'), ...
    did2.query('demoB.value_b', 'exact_string', 'b1'));
verifyTrue(testCase, q.matches(doc));

q2 = and( ...
    did2.query('base.name', 'exact_string', 'alice'), ...
    did2.query('demoB.value_b', 'exact_string', 'wrong'));
verifyFalse(testCase, q2.matches(doc));
end

function testOrComposition(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
q = or( ...
    did2.query('base.name', 'exact_string', 'nobody'), ...
    did2.query('base.name', 'exact_string', 'alice'));
verifyTrue(testCase, q.matches(doc));

q2 = or( ...
    did2.query('base.name', 'exact_string', 'nobody'), ...
    did2.query('base.name', 'exact_string', 'somebody'));
verifyFalse(testCase, q2.matches(doc));
end

function testOrCannotBeNegated(testCase)
verifyError(testCase, ...
    @() did2.query('', '~or', struct(), struct()), ...
    'did2:query:badOperator');
end

% ---- filter() over a list ----

function testFilterReturnsSubset(testCase)
d1 = makeDemoA(testCase, 'alice', 'a1');
d2 = makeDemoA(testCase, 'bob', 'a2');
d3 = makeDemoA(testCase, 'carol', 'a3');
docs = {d1, d2, d3};
q = did2.query('base.name', 'regexp', '^[ab]');
hits = q.filter(docs);
verifyEqual(testCase, numel(hits), 2);
verifyEqual(testCase, hits{1}.get('base.name'), 'alice');
verifyEqual(testCase, hits{2}.get('base.name'), 'bob');

mask = q.filter(docs, 'AsMask', true);
verifyEqual(testCase, mask, [true true false]);
end

% ---- working over a plain struct (no did2.document wrapper) ----

function testMatchesAcceptsStruct(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
s = doc.toStruct();
verifyTrue(testCase, did2.query('base.name', 'exact_string', 'alice').matches(s));
end

function testMatchesRejectsBadInput(testCase)
verifyError(testCase, ...
    @() did2.query('base.name', 'exact_string', 'x').matches(42), ...
    'did2:query:badDoc');
end

% ---- low-level helpers ----

function testResolvePathScalar(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
v = did2.query.resolvePath(doc.toStruct(), 'base.name');
verifyEqual(testCase, v, {'alice'});
end

function testResolvePathArrayStar(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
axes = struct('name', {'x','y','z'});
doc = doc.set('demoA.axes', axes);
v = did2.query.resolvePath(doc.toStruct(), 'demoA.axes[*].name');
verifyEqual(testCase, v, {'x','y','z'});
end

function testResolvePathMissingReturnsEmpty(testCase)
doc = makeDemoA(testCase, 'alice', 'a1');
v = did2.query.resolvePath(doc.toStruct(), 'demoA.no_such_field');
verifyEqual(testCase, v, {});
end
