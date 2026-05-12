function tests = testCompileQuery
% testCompileQuery - did2.database.compileQuery unit tests.
%
%   String-based smoke tests over the SQL output of the JSON1 query
%   compiler. These tests do not require mksqlite; the full integration
%   coverage (round-trip through a live SQLite database) lives in
%   did2.unittest.testSqliteDb.
%
%   Run with:
%       results = runtests('did2.unittest.testCompileQuery');

tests = functiontests(localfunctions);
end

% ---- scalar leaf operators ----

function testEmptyQueryCompilesToTrue(testCase)
[sql, params] = did2.database.compileQuery(did2.query());
verifyEqual(testCase, sql, '1=1');
verifyEqual(testCase, params, {});
end

function testExactStringUsesJsonExtract(testCase)
q = did2.query('base.name', 'exact_string', 'alice');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_extract(body, ''$.base.name'')');
verifySubstring(testCase, sql, '= ?');
verifyEqual(testCase, params, {'alice'});
end

function testExactStringAnycaseLowers(testCase)
q = did2.query('base.name', 'exact_string_anycase', 'Alice');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'LOWER(json_extract(body, ''$.base.name'')) = LOWER(?)');
verifyEqual(testCase, params, {'Alice'});
end

function testContainsStringEmitsLike(testCase)
q = did2.query('base.name', 'contains_string', 'lic');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_extract(body, ''$.base.name'') LIKE ?');
verifyEqual(testCase, params, {'%lic%'});
end

function testRegexpEmitsPermissivePrefilter(testCase)
% SQLite REGEXP is a UDF that mksqlite does not register; the compiler
% emits 1=1 and relies on the in-memory post-filter for correctness.
q = did2.query('base.name', 'regexp', '^abc');
[sql, params] = did2.database.compileQuery(q);
verifyEqual(testCase, sql, '1=1');
verifyEqual(testCase, params, {});
end

function testNumericComparisonCastsToReal(testCase)
q = did2.query('demoA.value', 'lessthan', 10);
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'CAST(json_extract(body, ''$.demoA.value'') AS REAL) < ?');
verifyEqual(testCase, params, {10});
end

function testExactNumberScalar(testCase)
q = did2.query('demoA.value', 'exact_number', 42);
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'CAST(json_extract(body, ''$.demoA.value'') AS REAL) = ?');
verifyEqual(testCase, params, {42});
end

function testNegationOnScalarHandlesMissingPath(testCase)
% Missing path -> ~op should be true. With json_extract returning NULL on
% missing paths, the negation guard must allow NULL through.
q = did2.query('base.missing', '~exact_string', 'x');
[sql, ~] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_extract(body, ''$.base.missing'') IS NULL');
verifySubstring(testCase, sql, 'NOT (');
end

% ---- hasfield ----

function testHasfieldUsesJsonType(testCase)
q = did2.query('base.name', 'hasfield', '');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_type(body, ''$.base.name'') IS NOT NULL');
verifyEqual(testCase, params, {});
end

function testHasfieldNegated(testCase)
q = did2.query('base.missing', '~hasfield', '');
[sql, ~] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_type(body, ''$.base.missing'') IS NULL');
end

% ---- array-iteration paths ----

function testStarPathExpandsToJsonEach(testCase)
q = did2.query('demoA.axes[*].name', 'exact_string', 'x');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_each(json_extract(body, ''$.demoA.axes''))');
verifySubstring(testCase, sql, 'json_extract(je1.value, ''$.name'') = ?');
verifySubstring(testCase, sql, 'EXISTS (');
verifyEqual(testCase, params, {'x'});
end

function testNestedStarPaths(testCase)
q = did2.query('demoA.multiscales[*].datasets[*].path', 'regexp', '^0/');
[sql, ~] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_each(json_extract(body, ''$.demoA.multiscales'')) je1');
verifySubstring(testCase, sql, 'json_each(json_extract(je1.value, ''$.datasets'')) je2');
end

function testNegatedStarPath(testCase)
q = did2.query('demoA.axes[*].name', '~exact_string', 'x');
[sql, ~] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, '(NOT EXISTS (');
end

% ---- isa & depends_on ----

function testIsaUsesSuperclassesTable(testCase)
q = did2.query('', 'isa', 'demoA');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'FROM superclasses sc');
verifySubstring(testCase, sql, 'sc.classname = ?');
verifyEqual(testCase, params, {'demoA'});
end

function testIsaNegated(testCase)
q = did2.query('', '~isa', 'demoA');
[sql, ~] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, '(NOT EXISTS');
end

function testDependsOnUsesSidecar(testCase)
q = did2.query('', 'depends_on', 'parent', 'id-1');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'FROM depends_on d');
verifySubstring(testCase, sql, 'd.name = ?');
verifySubstring(testCase, sql, 'd.value = ?');
verifyEqual(testCase, params, {'parent', 'id-1'});
end

function testDependsOnWildcard(testCase)
q = did2.query('', 'depends_on', '*', 'id-1');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'd.value = ?');
% No `d.name = ?` clause when the wildcard is in effect.
verifyEmpty(testCase, regexp(sql, 'd\.name\s*=\s*\?', 'once'));
verifyEqual(testCase, params, {'id-1'});
end

% ---- hasmember & friends ----

function testHasmemberUsesJsonEach(testCase)
q = did2.query('demoA.tags', 'hasmember', 'green');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_each(json_extract(body, ''$.demoA.tags'')) je');
verifySubstring(testCase, sql, 'je.value = ?');
verifyEqual(testCase, params, {'green'});
end

function testHasanysubfieldContainsStringRewritesToStarPath(testCase)
q = did2.query('demoA.items', 'hasanysubfield_contains_string', 'note', 'tasty');
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, 'json_each(json_extract(body, ''$.demoA.items''))');
verifySubstring(testCase, sql, 'json_extract(je1.value, ''$.note'') LIKE ?');
verifyEqual(testCase, params, {'%tasty%'});
end

% ---- composition ----

function testAndConcatenatesWithAND(testCase)
q = and( ...
    did2.query('base.name', 'exact_string', 'alice'), ...
    did2.query('', 'isa', 'demoA'));
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, ') AND (');
verifyEqual(testCase, params, {'alice', 'demoA'});
end

function testOrEmitsTwoBranches(testCase)
q = or( ...
    did2.query('base.name', 'exact_string', 'alice'), ...
    did2.query('base.name', 'exact_string', 'bob'));
[sql, params] = did2.database.compileQuery(q);
verifySubstring(testCase, sql, ') OR (');
verifyEqual(testCase, params, {'alice', 'bob'});
end

% ---- helpers ----

function verifySubstring(testCase, haystack, needle)
testCase.verifyTrue(contains(haystack, needle), ...
    sprintf('Expected "%s" to contain "%s".', haystack, needle));
end
