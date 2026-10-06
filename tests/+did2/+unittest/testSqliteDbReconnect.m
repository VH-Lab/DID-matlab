function tests = testSqliteDbReconnect
% testSqliteDbReconnect - did2.database.sqlitedb when its connection is
% closed by someone else.
%
%   mksqlite numbers its connections, and code outside a database object
%   closes them by number: ndi.dataset runs mksqlite('close') (dbid 1)
%   after opening a session, and ndi.session.dir runs mksqlite(0, 'close')
%   (all of them) before deleting one. The legacy backend reopens on next
%   use; did2.database.sqlitedb did not, so a V2 session opened from an
%   ndi.dataset failed every search with "database not open". And a closed
%   number is REUSED by the next open, so a database still holding it could
%   have queried another database's file without an error. These tests pin
%   both: reopen on next use, and never use or close a reused number.
%
%   Run with:
%       results = runtests('did2.unittest.testSqliteDbReconnect');

tests = functiontests(localfunctions);
end

% ---- fixture setup / teardown ----

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping the v2 SQLite tests.');
end
thisDir = fileparts(mfilename('fullpath'));
did2.schema.cache.setSchemaPath(fullfile(fileparts(thisDir), 'fixtures', 'V_delta'));
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.files = {};
end

function teardown(testCase)
for k = 1:numel(testCase.TestData.files)
    if isfile(testCase.TestData.files{k})
        try delete(testCase.TestData.files{k}); catch, end
    end
end
end

% ---- tests ----

function testReopensAfterEveryConnectionIsClosed(testCase)
% ndi.session.dir's delete path: mksqlite(0, 'close') closes them all
db = newDb(testCase);
db.add(makeDemoA('alice', 'a1'));
mksqlite(0, 'close');
verifyEqual(testCase, db.count(), 1, 'the next operation reopens the file');
verifyEqual(testCase, db.testHookReconnects(), 1);
verifyTrue(testCase, db.isOpen());
hits = db.search(did2.query('base.name', 'exact_string', 'alice'));
verifyNumElements(testCase, hits, 1);
verifyEqual(testCase, db.testHookReconnects(), 1, 'reopened once, then used');
end

function testReopensAfterItsOwnNumberIsClosed(testCase)
% ndi.dataset's open_session: mksqlite('close') closes one number
db = newDb(testCase);
db.add(makeDemoA('alice', 'a1'));
mksqlite(db.testHookDbId(), 'close');
ids = db.allIds();
verifyTrue(testCase, db.has(ids{1}));
verifyEqual(testCase, db.testHookReconnects(), 1);
end

function testAReusedNumberIsNotQueried(testCase)
% A's number is closed and then taken by B: A must reopen its OWN file
% rather than read B's, and B must be left as it was
a = newDb(testCase);
a.add(makeDemoA('alice', 'a1'));
id = a.testHookDbId();
mksqlite(id, 'close');
b = newDb(testCase);
verifyEqual(testCase, b.testHookDbId(), id, ...
    'precondition: mksqlite reuses the lowest free number');
b.add(makeDemoA('bob', 'b1'));
verifyEqual(testCase, a.count(), 1);
verifyNotEmpty(testCase, a.search(did2.query('base.name', 'exact_string', 'alice')), ...
    'A reads its own file');
verifyEmpty(testCase, a.search(did2.query('base.name', 'exact_string', 'bob')), ...
    'not B''s');
verifyEqual(testCase, a.testHookReconnects(), 1);
verifyEqual(testCase, b.count(), 1);
verifyEqual(testCase, b.testHookReconnects(), 0, 'B''s connection was not touched');
end

function testCloseLeavesAReusedNumberAlone(testCase)
% A's number is closed and taken by B before A is used again; A.close()
% (or A being deleted) must not close B's connection
a = newDb(testCase);
id = a.testHookDbId();
mksqlite(id, 'close');
b = newDb(testCase);
verifyEqual(testCase, b.testHookDbId(), id, ...
    'precondition: mksqlite reuses the lowest free number');
a.close();
verifyEqual(testCase, b.count(), 0);
verifyEqual(testCase, b.testHookReconnects(), 0, 'B''s connection is still open');
end

function testCloseByTheOwnerStaysClosed(testCase)
db = newDb(testCase);
db.close();
verifyFalse(testCase, db.isOpen());
verifyError(testCase, @() db.count(), 'did2:database:closed');
db.close();     % idempotent
end

function testExplainReportsAPlanAndWritesNothing(testCase)
db = newDb(testCase);
db.add(makeDemoA('alice', 'a1'));
r = db.testHookExplain(did2.query('base.name', 'exact_string', 'alice'));
verifySubstring(testCase, r.sql, 'SELECT id, body FROM documents WHERE');
verifyNotEmpty(testCase, r.plan);
verifyTrue(testCase, isfield(r.plan, 'detail'));
verifyEqual(testCase, db.count(), 1);
end

% ---- helpers ----

function db = newDb(testCase)
f = [tempname() '.sqlite'];
testCase.TestData.files{end+1} = f;
db = did2.database.sqlitedb(f);
testCase.addTeardown(@() db.close());
end

function doc = makeDemoA(name, value)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', value);
end
