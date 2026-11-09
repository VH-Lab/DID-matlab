function tests = testDerivedRows
% testDerivedRows - the derived-row store (did2.database.sqlitedb/derivedPut).
%
%   Jess Haley, 2026-11-09: "Build the derived index"; [1 yes, 2 a, 3 yes].
%   A row records the ids it was derived from; every add or remove of a
%   document D drops, in the same transaction, every row recording D or a
%   document D's edges point at (session_id edges excepted). These tests
%   check the store (put, get, schema version, recorded ids, clear, count,
%   reopen) and each invalidation case, including one that must NOT drop a
%   row and a failed add that must leave it.
%
%   Filtered out if mksqlite is not on the MATLAB path.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, 'mksqlite is not on the MATLAB path; skipping the v2 SQLite tests.');
end
thisDir = fileparts(mfilename('fullpath'));
did2.schema.cache.setSchemaPath(fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal'));
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.tmpFile = [tempname() '.sqlite'];
db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
a1 = demoA('a1', 'sessA', 'alpha');
a2 = demoA('a2', 'sessA', 'beta');
a3 = demoA('a3', 'sessA', 'gamma');
db.add({a1, a2, a3});
c1 = demoC('c1', 'sessA', {'item1', a1.get('base.id')});
db.add({c1}, 'Validate', false);
testCase.TestData.ids = struct('a1', a1.get('base.id'), 'a2', a2.get('base.id'), ...
    'a3', a3.get('base.id'), 'c1', c1.get('base.id'));
% one row derived from a1 and c1
db.derivedPut('ns', 'sys1', 'k', '{"x":1}', 'v1', {a1.get('base.id'), c1.get('base.id')});
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

function testPutGetVersionDeps(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
verifyTrue(testCase, did2.database.sqlitedb.derivedRowsAvailable());
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":1}');
verifyEmpty(testCase, db.derivedGet('ns', 'sys1', 'k', 'v2'), 'another schema version reads as none');
verifyEmpty(testCase, db.derivedGet('ns', 'sys2', 'k', 'v1'), 'another scope reads as none');
verifyEqual(testCase, db.derivedDeps('ns', 'sys1', 'k'), sort({ids.a1, ids.c1}));
db.derivedPut('ns', 'sys1', 'k', '{"x":2}', 'v1', {ids.a2});   % replaces
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":2}');
verifyEqual(testCase, db.derivedDeps('ns', 'sys1', 'k'), {ids.a2});
verifyEqual(testCase, db.derivedCount('ns'), 1);
end

function testAddPointingAtARecordedIdDropsTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
db.add({demoC('c2', 'sessA', {'item1', ids.a1})}, 'Validate', false);
verifyEmpty(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'));
verifyEqual(testCase, db.derivedCount(), 0, 'its recorded ids go with it');
end

function testUnrelatedAddKeepsTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
db.add({demoA('a9', 'sessA', 'delta')});
db.add({demoC('c3', 'sessA', {'item1', ids.a3})}, 'Validate', false);
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":1}');
end

function testSessionEdgeDoesNotDropTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
d = demoC('c4', 'sessA', {'session_id', ids.a1});   % only a session_id edge onto a recorded id
db.add({d}, 'Validate', false);
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":1}');
end

function testRemovingARecordedDocumentDropsTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
db.remove(ids.a1);
verifyEmpty(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'));
end

function testRemovingADocumentPointingAtOneDropsTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
db.derivedPut('ns', 'sys1', 'k', '{"x":1}', 'v1', {ids.a1});   % c1 not recorded, but points at a1
db.remove(ids.c1);
verifyEmpty(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'));
end

function testRemovingAnUnrelatedDocumentKeepsTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
db.remove(ids.a3);
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":1}');
end

function testAFailedAddLeavesTheRow(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
dup = db.get(ids.c1);    % adding the same id again fails, after its edges were seen
verifyError(testCase, @() db.add({dup}, 'Validate', false), ?MException);
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":1}', ...
    'the add rolled back, and the drop with it');
end

function testManyRowsAtOnce(testCase)
db = testCase.TestData.db; ids = testCase.TestData.ids;
db.derivedPutMany('many', 'sc', {'k1', 'k2', 'k3'}, {'v1', 'v2', 'v3'}, 'v1', ...
    {{ids.a1}, {ids.a2}, {}});
r = db.derivedGetMany('many', 'sc', {'k3', 'nope', 'k1', 'k2'}, 'v1');
verifyEqual(testCase, {r.key}, {'k3', 'k1', 'k2'}, 'in the order asked, missing keys left out');
verifyEqual(testCase, {r.value}, {'v3', 'v1', 'v2'});
verifyEmpty(testCase, db.derivedGetMany('many', 'sc', {'k1'}, 'v2'), 'another version reads as none');
db.remove(ids.a2);   % drops k2 only
r = db.derivedGetMany('many', 'sc', {'k1', 'k2', 'k3'}, 'v1');
verifyEqual(testCase, {r.key}, {'k1', 'k3'});
verifyError(testCase, @() db.derivedPutMany('many', 'sc', {'a', 'b'}, {'x'}, 'v1', {{}, {}}), ...
    'did2:sqlitedb:derivedPutMany');
end

function testClearAndReopen(testCase)
db = testCase.TestData.db;
db.derivedPut('other', 's', 'k', 'v', 'v1', {});
verifyEqual(testCase, db.derivedCount(), 2);
db.close();
db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
verifyEqual(testCase, db.derivedGet('ns', 'sys1', 'k', 'v1'), '{"x":1}', 'kept in the file');
db.derivedClear('ns');
verifyEqual(testCase, db.derivedCount(), 1);
db.derivedClear();
verifyEqual(testCase, db.derivedCount(), 0);
end

function doc = demoA(name, sess, value)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sess);
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', value);
end

function doc = demoC(name, sess, edges)
doc = did2.document.blank('demoC');
doc = doc.set('base.session_id', sess);
doc = doc.set('base.name', name);
doc = doc.set('demoC.value', name);
doc = doc.set('depends_on', struct('name', edges(:, 1)', 'document_id', edges(:, 2)'));
end
