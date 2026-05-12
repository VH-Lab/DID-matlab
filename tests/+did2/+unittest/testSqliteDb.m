function tests = testSqliteDb
% testSqliteDb - did2.database.sqlitedb integration tests.
%
%   Round-trips V_gamma documents through a real SQLite file via
%   mksqlite, and verifies that the JSON1 query compiler + post-filter
%   returns the same hits as the in-memory reference evaluator
%   (did2.query.matches).
%
%   The whole file is filtered out if mksqlite is not on the MATLAB
%   path; nothing here exercises pure-MATLAB code paths.
%
%   Run with:
%       results = runtests('did2.unittest.testSqliteDb');

tests = functiontests(localfunctions);
end

% ---- fixture setup / teardown ----

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping the v2 SQLite tests.');
end
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_gamma');
did2.schema.cache.setSchemaPath(fixtureDir);
testCase.TestData.fixtureDir = fixtureDir;
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.tmpFile = [tempname() '.sqlite'];
testCase.TestData.db = did2.database.sqlitedb(testCase.TestData.tmpFile);
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

% ---- bootstrap ----

function testCreateOpensConnection(testCase)
db = testCase.TestData.db;
verifyTrue(testCase, db.isOpen());
verifyEqual(testCase, db.count(), 0);
end

function testReopenExistingDatabase(testCase)
% Add a doc, close, reopen, verify it's still there.
db = testCase.TestData.db;
doc = makeDemoA('alice', 'a1');
db.add(doc);
db.close();
db2 = did2.database.sqlitedb(testCase.TestData.tmpFile);
cleanup = onCleanup(@() db2.close()); %#ok<NASGU>
verifyEqual(testCase, db2.count(), 1);
verifyTrue(testCase, db2.has(doc.get('base.id')));
end

function testRejectsForeignSchemaFile(testCase)
% A file that exists but is not a v2 DB should fail validation.
db = testCase.TestData.db;
db.close();
delete(testCase.TestData.tmpFile);
% Write a sqlite file without the v2 meta table.
dbid = mksqlite(0, 'open', testCase.TestData.tmpFile);
mksqlite(dbid, 'CREATE TABLE other(x INTEGER)');
mksqlite(dbid, 'close');
verifyError(testCase, ...
    @() did2.database.sqlitedb(testCase.TestData.tmpFile), ...
    'did2:database:notV2Database');
end

% ---- add / get / remove ----

function testAddSingleDocument(testCase)
db = testCase.TestData.db;
doc = makeDemoA('alice', 'a1');
db.add(doc);
verifyEqual(testCase, db.count(), 1);
fetched = db.get(doc.get('base.id'));
verifyEqual(testCase, fetched.className(), 'demoA');
verifyEqual(testCase, fetched.get('base.name'), 'alice');
verifyEqual(testCase, fetched.get('demoA.value'), 'a1');
end

function testAddListOfDocuments(testCase)
db = testCase.TestData.db;
docs = {makeDemoA('a', 'x'), makeDemoA('b', 'y'), makeDemoA('c', 'z')};
db.add(docs);
verifyEqual(testCase, db.count(), 3);
end

function testRemoveDeletesDocumentAndSidecars(testCase)
db = testCase.TestData.db;
doc = makeDemoB('alice', 'a1', 'b1');
db.add(doc);
db.remove(doc.get('base.id'));
verifyEqual(testCase, db.count(), 0);
verifyFalse(testCase, db.has(doc.get('base.id')));
end

function testAllIdsRespectsInsertionOrder(testCase)
db = testCase.TestData.db;
d1 = makeDemoA('a', 'x'); db.add(d1);
d2 = makeDemoA('b', 'y'); db.add(d2);
d3 = makeDemoA('c', 'z'); db.add(d3);
ids = db.allIds();
verifyEqual(testCase, ids, ...
    {d1.get('base.id'), d2.get('base.id'), d3.get('base.id')});
end

function testValidateFalseSkipsSchemaCheck(testCase)
% A document missing a required field should still be insertable when
% Validate=false (the bulk-load escape hatch documented in PLAN.md §1).
db = testCase.TestData.db;
doc = makeDemoA('alice', 'a1');
% Wipe the session_id (mustBeNonEmpty in base.json) and prove that the
% default Validate=true path rejects it, then accept with Validate=false.
doc = doc.set('base.session_id', '');
verifyError(testCase, @() db.add(doc), 'did2:validation:emptyField');
db.add(doc, 'Validate', false);
verifyEqual(testCase, db.count(), 1);
end

% ---- search: body predicates ----

function testSearchExactString(testCase)
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoA('bob',   'a2'); db.add(d2);
hits = db.search(did2.query('base.name', 'exact_string', 'alice'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d1.get('base.id'));
end

function testSearchRegexpPostFilters(testCase)
% The compiler emits 1=1 for regexp; the post-filter must still reduce
% the result set correctly.
db = testCase.TestData.db;
d1 = makeDemoA('subject_001', 'x'); db.add(d1);
d2 = makeDemoA('control_001', 'y'); db.add(d2);
d3 = makeDemoA('subject_007', 'z'); db.add(d3);
hits = db.search(did2.query('base.name', 'regexp', '^subject_\d+$'));
ids = cellfun(@(d) d.get('base.id'), hits, 'UniformOutput', false);
verifyEqual(testCase, sort(ids), ...
    sort({d1.get('base.id'), d3.get('base.id')}));
end

function testSearchNegation(testCase)
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoA('bob',   'a2'); db.add(d2);
hits = db.search(did2.query('base.name', '~exact_string', 'alice'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.name'), 'bob');
end

function testSearchNegationOnMissingField(testCase)
% A missing-field negation should match (per the in-memory spec, the
% empty resolved-paths list flips to true under ~).
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
hits = db.search(did2.query('base.does_not_exist', '~exact_string', 'x'));
verifyEqual(testCase, numel(hits), 1);
end

function testSearchHasfield(testCase)
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
verifyTrue(testCase, ~isempty(db.search(did2.query('demoA.value', 'hasfield', ''))));
verifyEmpty(testCase, db.search(did2.query('demoA.missing', 'hasfield', '')));
end

% ---- search: array iteration ----

function testSearchArrayStar(testCase)
db = testCase.TestData.db;
doc = makeDemoA('alice', 'a1');
axes = struct('name', {'x','y','z'}, 'unit', {'um','um','deg'});
doc = doc.set('demoA.axes', axes);
db.add(doc);
verifyEqual(testCase, ...
    numel(db.search(did2.query('demoA.axes[*].unit', 'exact_string', 'deg'))), 1);
verifyEmpty(testCase, ...
    db.search(did2.query('demoA.axes[*].unit', 'exact_string', 'parsec')));
end

function testSearchNestedArrayStar(testCase)
db = testCase.TestData.db;
doc = makeDemoA('alice', 'a1');
ms = struct('datasets', { ...
    struct('path', {'0/img','0/lbl'}), ...
    struct('path', {'1/img','1/lbl'})});
doc = doc.set('demoA.multiscales', ms);
db.add(doc);
hits = db.search(did2.query('demoA.multiscales[*].datasets[*].path', ...
    'regexp', '^1/'));
verifyEqual(testCase, numel(hits), 1);
end

function testSearchHasmember(testCase)
db = testCase.TestData.db;
doc = makeDemoA('alice', 'a1');
doc = doc.set('demoA.tags', {'red','green','blue'});
db.add(doc);
verifyEqual(testCase, ...
    numel(db.search(did2.query('demoA.tags', 'hasmember', 'green'))), 1);
verifyEmpty(testCase, ...
    db.search(did2.query('demoA.tags', 'hasmember', 'yellow')));
end

% ---- search: isa & depends_on (sidecar tables) ----

function testSearchIsa(testCase)
db = testCase.TestData.db;
da = makeDemoA('a', 'x'); db.add(da);
dbb = makeDemoB('b', 'y', 'q'); db.add(dbb);
% demoB documents are isa demoB, demoA, base.
verifyEqual(testCase, numel(db.search(did2.query('', 'isa', 'demoB'))), 1);
verifyEqual(testCase, numel(db.search(did2.query('', 'isa', 'demoA'))), 2);
verifyEqual(testCase, numel(db.search(did2.query('', 'isa', 'base'))),  2);
verifyEmpty(testCase, db.search(did2.query('', 'isa', 'demoC')));
end

function testSearchDependsOn(testCase)
db = testCase.TestData.db;
d1 = makeDemoA('a', 'x');
d1 = d1.set('depends_on', struct('name', {'parent','sibling'}, ...
    'value', {'id-1','id-2'}));
db.add(d1, 'Validate', false);
d2 = makeDemoA('b', 'y'); db.add(d2);
hits = db.search(did2.query('', 'depends_on', 'parent', 'id-1'));
verifyEqual(testCase, numel(hits), 1);
hits = db.search(did2.query('', 'depends_on', '*', 'id-2'));
verifyEqual(testCase, numel(hits), 1);
verifyEmpty(testCase, db.search(did2.query('', 'depends_on', 'parent', 'no-such-id')));
end

% ---- composition ----

function testSearchAnd(testCase)
db = testCase.TestData.db;
d1 = makeDemoB('alice', 'a1', 'b1'); db.add(d1);
d2 = makeDemoB('alice', 'a1', 'b2'); db.add(d2);
d3 = makeDemoB('bob',   'a1', 'b1'); db.add(d3);
q = and( ...
    did2.query('base.name', 'exact_string', 'alice'), ...
    did2.query('demoB.value_b', 'exact_string', 'b1'));
hits = db.search(q);
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d1.get('base.id'));
end

function testSearchOr(testCase)
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoA('bob',   'a2'); db.add(d2);
d3 = makeDemoA('carol', 'a3'); db.add(d3);
q = or( ...
    did2.query('base.name', 'exact_string', 'alice'), ...
    did2.query('base.name', 'exact_string', 'carol'));
hits = db.search(q);
verifyEqual(testCase, numel(hits), 2);
end

function testSearchAllAndNone(testCase)
db = testCase.TestData.db;
db.add(makeDemoA('a', 'x'));
db.add(makeDemoA('b', 'y'));
verifyEqual(testCase, numel(db.search(did2.query.all())), 2);
verifyEmpty(testCase, db.search(did2.query.none()));
end

% ---- helpers ----

function doc = makeDemoA(name, value)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', value);
end

function doc = makeDemoB(name, valueA, valueB)
doc = did2.document.blank('demoB');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', valueA);
doc = doc.set('demoB.value_b', valueB);
end

function doc = makeDemoArray(name, axes)
doc = did2.document.blank('demoArray');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoArray.axes', axes);
end

% ---- step 4: generated columns + rebuild-on-mismatch ----

function testGeneratedColumnsExistAtCreate(testCase)
% A freshly-created DB should already have the q_* columns and their
% indexes derived from the loaded schemas.
db = testCase.TestData.db;
cols = generatedColumns(db, 'documents');
verifyTrue(testCase, ismember('q_base_name', cols));
verifyTrue(testCase, ismember('q_base_id', cols));
verifyTrue(testCase, ismember('q_demoa_value', cols));
end

function testIndexedScalarMatchesFallback(testCase)
% Searching by base.name should hit the generated column and return
% the same docs as the JSON1 fallback would.
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoA('bob',   'a2'); db.add(d2);
hits = db.search(did2.query('base.name', 'exact_string', 'alice'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d1.get('base.id'));
end

function testGeneratedColumnPopulatesFromBody(testCase)
% Direct query against the generated column should reflect the
% just-inserted body — confirms the STORED column expression fires.
db = testCase.TestData.db;
doc = makeDemoA('carol', 'cv');
db.add(doc);
rows = mksqlite(db.testHookDbId(), ...
    'SELECT q_base_name, q_demoa_value FROM documents WHERE id = ?', ...
    doc.get('base.id'));
verifyEqual(testCase, char(rows(1).q_base_name), 'carol');
verifyEqual(testCase, char(rows(1).q_demoa_value), 'cv');
end

function testRebuildPreservesDataOnSchemaMismatch(testCase)
% Manually drop a generated column from the table (simulating an
% older queryable-paths set), then reopen. The constructor should
% rebuild the table to match the current schema while preserving
% every body verbatim.
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoB('bob', 'a2', 'b2'); db.add(d2);

% SQLite 3.35+ supports DROP COLUMN. The CI MATLAB ships with mksqlite
% bound to a >=3.35 sqlite, but skip the test gracefully on older.
ok = tryDropColumn(db.testHookDbId(), 'documents', 'q_demoa_value');
if ~ok
    assumeFail(testCase, 'sqlite DROP COLUMN unavailable on this build');
end
db.close();

db2 = did2.database.sqlitedb(testCase.TestData.tmpFile);
cleanup = onCleanup(@() db2.close()); %#ok<NASGU>
cols = generatedColumns(db2, 'documents');
verifyTrue(testCase, ismember('q_demoa_value', cols), ...
    'rebuild should restore the missing generated column');
verifyEqual(testCase, db2.count(), 2);
verifyTrue(testCase, db2.has(d1.get('base.id')));
verifyTrue(testCase, db2.has(d2.get('base.id')));
end

% ---- helpers (step 4) ----

function cols = generatedColumns(db, tableName)
% Probe each generated column the sqlitedb instance expects to find on
% the table with a zero-row SELECT, and return the subset that
% succeeds. We previously walked `pragma_table_info`, but on the CI's
% mksqlite + sqlite combination the .name field of those rows didn't
% round-trip through ismember the way the test assumed even when the
% column itself was healthy. Probing each candidate directly avoids
% that path entirely.
candidates = db.testHookQueryableColumns();
cols = {};
for k = 1:numel(candidates)
    sql = sprintf('SELECT %s FROM %s LIMIT 0', candidates{k}, tableName);
    try
        mksqlite(db.testHookDbId(), sql);
        cols{end+1} = candidates{k}; %#ok<AGROW>
    catch
        % column does not exist on this table.
    end
end
end

% ---- step 5: queryable_array_elem sidecar ----

function testSidecarPopulatedAtInsert(testCase)
% A demoArray document with three axes should yield three sidecar rows
% for each queryable sub-field path.
db = testCase.TestData.db;
axes = struct('name', {'x','y','z'}, 'unit', {'um','um','deg'}, ...
    'size', {10, 20, 5});
doc = makeDemoArray('layered', axes);
db.add(doc);
rows = mksqlite(db.testHookDbId(), ...
    'SELECT path, elem_index, value_text, value_num FROM queryable_array_elem ORDER BY path, elem_index');
verifyEqual(testCase, numel(rows), 6);
% mksqlite returns N x 1 struct arrays; flatten via comma-list packing so
% shape mismatches don't trip the equality checks below.
unitMask = strcmp({rows.path}, 'demoArray.axes[*].unit');
unitRows = rows(unitMask);
unitValues = cellfun(@char, {unitRows.value_text}, 'UniformOutput', false);
verifyEqual(testCase, unitValues, {'um','um','deg'});
sizeMask = strcmp({rows.path}, 'demoArray.axes[*].size');
sizeRows = rows(sizeMask);
sizeValues = [sizeRows.value_num];
verifyEqual(testCase, sizeValues(:)', [10 20 5]);
end

function testSidecarRoutesIndexedStarSearch(testCase)
% A search on the indexed array path should hit the sidecar and return
% the same docs as the in-memory evaluator.
db = testCase.TestData.db;
ax1 = struct('name', {'x','y'}, 'unit', {'um','um'}, 'size', {1, 2});
ax2 = struct('name', {'x'},     'unit', {'deg'},     'size', {3});
d1 = makeDemoArray('d1', ax1); db.add(d1);
d2 = makeDemoArray('d2', ax2); db.add(d2);
hits = db.search(did2.query('demoArray.axes[*].unit', 'exact_string', 'deg'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d2.get('base.id'));
end

function testSidecarNumericComparisonRoutes(testCase)
% lessthan against the INTEGER-affinity `size` sub-field should land
% on value_num via the sidecar and select the right doc.
db = testCase.TestData.db;
big = struct('name', {'x'}, 'unit', {'um'}, 'size', {1000});
small = struct('name', {'x'}, 'unit', {'um'}, 'size', {5});
d1 = makeDemoArray('big',   big);   db.add(d1);
d2 = makeDemoArray('small', small); db.add(d2);
hits = db.search(did2.query('demoArray.axes[*].size', 'lessthan', 10));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.name'), 'small');
end

function testSidecarRemovedOnDocDelete(testCase)
% Deleting the document should cascade to queryable_array_elem.
db = testCase.TestData.db;
axes = struct('name', {'x'}, 'unit', {'um'}, 'size', {7});
doc = makeDemoArray('delme', axes);
db.add(doc);
docId = doc.get('base.id');
preRows = mksqlite(db.testHookDbId(), ...
    'SELECT COUNT(*) AS n FROM queryable_array_elem WHERE doc_id = ?', docId);
verifyEqual(testCase, double(preRows(1).n), 2);
db.remove(docId);
postRows = mksqlite(db.testHookDbId(), ...
    'SELECT COUNT(*) AS n FROM queryable_array_elem WHERE doc_id = ?', docId);
verifyEqual(testCase, double(postRows(1).n), 0);
end

function testSidecarMetaTracksPathSet(testCase)
% The configured array-paths set should be recorded in the meta table
% so the next open can detect a mismatch.
db = testCase.TestData.db;
row = mksqlite(db.testHookDbId(), ...
    'SELECT value FROM meta WHERE key = ?', 'queryable_array_paths');
verifyEqual(testCase, numel(row), 1);
parts = strsplit(char(row(1).value), char(10));
expected = {'demoArray.axes[*].size', 'demoArray.axes[*].unit'};
verifyEqual(testCase, sort(parts), expected);
end

function testSidecarReconcileRepopulates(testCase)
% Manually clobber the sidecar's path set in `meta` and wipe its rows
% to simulate a previous schema generation. Reopening should rebuild
% the sidecar from the stored bodies under the current path set.
db = testCase.TestData.db;
axes = struct('name', {'x','y'}, 'unit', {'um','deg'}, 'size', {1, 2});
doc = makeDemoArray('reb', axes);
db.add(doc);
docId = doc.get('base.id');
mksqlite(db.testHookDbId(), 'DELETE FROM queryable_array_elem');
mksqlite(db.testHookDbId(), ...
    'INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)', ...
    'queryable_array_paths', 'stale.other[*].field');
db.close();

db2 = did2.database.sqlitedb(testCase.TestData.tmpFile);
cleanup = onCleanup(@() db2.close()); %#ok<NASGU>
rows = mksqlite(db2.testHookDbId(), ...
    'SELECT COUNT(*) AS n FROM queryable_array_elem WHERE doc_id = ?', docId);
verifyEqual(testCase, double(rows(1).n), 4);
% A search on the indexed path now goes through the rebuilt sidecar.
hits = db2.search(did2.query('demoArray.axes[*].unit', 'exact_string', 'deg'));
verifyEqual(testCase, numel(hits), 1);
end

function ok = tryDropColumn(dbid, table, column)
% SQLite refuses ALTER TABLE DROP COLUMN if the column has a dependent
% index, so drop the matching `<table>_<column>` index first. Returns
% false on any SQL failure (older mksqlite without DROP COLUMN support).
try
    mksqlite(dbid, sprintf('DROP INDEX IF EXISTS %s_%s', table, column));
    mksqlite(dbid, sprintf('ALTER TABLE %s DROP COLUMN %s', table, column));
    ok = true;
catch
    ok = false;
end
end
