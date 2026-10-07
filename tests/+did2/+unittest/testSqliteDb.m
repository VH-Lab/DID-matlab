function tests = testSqliteDb
% testSqliteDb - did2.database.sqlitedb integration tests.
%
%   Round-trips V_delta documents through a real SQLite file via
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
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
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
    'document_id', {'id-1','id-2'}));
db.add(d1, 'Validate', false);
d2 = makeDemoA('b', 'y'); db.add(d2);
hits = db.search(did2.query('', 'depends_on', 'parent', 'id-1'));
verifyEqual(testCase, numel(hits), 1);
hits = db.search(did2.query('', 'depends_on', '*', 'id-2'));
verifyEqual(testCase, numel(hits), 1);
verifyEmpty(testCase, db.search(did2.query('', 'depends_on', 'parent', 'no-such-id')));
end

function testSearchDependsOnCombinations(testCase)
% A named depends_on compiles to `documents.id IN (...)` (so SQLite can
% start from the edge index); the answers must be the ones the correlated
% EXISTS gave, alone, negated, ANDed with isa and inside an or.
db = testCase.TestData.db;
withEdge = @(d, id) d.set('depends_on', struct('name', {'parent'}, 'document_id', {id}));
d1 = withEdge(makeDemoA('a1', 'x'), 'id-1');      db.add(d1, 'Validate', false);
d2 = withEdge(makeDemoB('b1', 'y', 'q'), 'id-1'); db.add(d2, 'Validate', false);
d3 = withEdge(makeDemoA('a2', 'z'), 'id-2');      db.add(d3, 'Validate', false);
d4 = makeDemoA('a3', 'w');                        db.add(d4);
names = @(q) sort(cellfun(@(h) char(h.get('base.name')), db.search(q), 'UniformOutput', false));
edge1 = did2.query('', 'depends_on', 'parent', 'id-1');
verifyEqual(testCase, names(edge1), {'a1', 'b1'});
verifyEqual(testCase, names(did2.query('', 'isa', 'demoB') & edge1), {'b1'});
verifyEqual(testCase, names(did2.query('', '~depends_on', 'parent', 'id-1')), {'a2', 'a3'});
verifyEqual(testCase, names(did2.query('', 'depends_on', 'parent', 'id-2') | ...
    did2.query('', 'isa', 'demoB')), {'a2', 'b1'});
verifyEqual(testCase, names(edge1 & did2.query('base.name', 'exact_string', 'a1')), {'a1'});
verifyEqual(testCase, names(did2.query('', 'depends_on', '*', 'id-2')), {'a2'});

% and the plan starts from the edge: documents is not scanned
r = db.testHookExplain(did2.query('', 'isa', 'demoA') & edge1);
details = {r.plan.detail};
verifyFalse(testCase, any(~cellfun(@isempty, regexp(details, '^SCAN (TABLE )?documents\>', 'once'))), ...
    sprintf('plan: %s', strjoin(details, ' | ')));
verifyTrue(testCase, any(contains(details, 'depends_on_name_document_id')), ...
    sprintf('plan: %s', strjoin(details, ' | ')));
end

function testSearchDependsOnAQueryOrAList(testCase)
% A depends_on whose target is a query: "formulations with peptone as an
% ingredient" without first looking peptone's id up by hand. The target
% may itself nest (plates poured from such a formulation), sit in an or,
% be negated, or be the wildcard edge; a list of ids means any of them.
db = testCase.TestData.db;
idOf = @(d) char(d.get('base.id'));
edges = @(d, name, ids) d.set('depends_on', struct('name', repmat({name}, 1, numel(ids)), ...
    'document_id', ids));
pep = makeDemoA('peptone', 'x'); db.add(pep);
agar = makeDemoA('agar', 'y');   db.add(agar);
salt = makeDemoA('salt', 'z');   db.add(salt);
ngm = edges(makeDemoB('ngm', 'f', 'q'), 'ingredient', {idOf(agar), idOf(pep), idOf(salt)});
db.add(ngm, 'Validate', false);
nop = edges(makeDemoB('ngm_np', 'f', 'q'), 'ingredient', {idOf(agar), idOf(salt)});
db.add(nop, 'Validate', false);
lb = edges(makeDemoB('lb', 'f', 'q'), 'ingredient', {idOf(salt)});
db.add(lb, 'Validate', false);
p1 = edges(makeDemoA('plate1', 'p'), 'formulation', {idOf(ngm)}); db.add(p1, 'Validate', false);
p2 = edges(makeDemoA('plate2', 'p'), 'formulation', {idOf(nop)}); db.add(p2, 'Validate', false);

names = @(q) sort(cellfun(@(h) char(h.get('base.name')), db.search(q), 'UniformOutput', false));
named = @(n) did2.query('base.name', 'exact_string', n);
withPep = did2.query('', 'depends_on', 'ingredient', named('peptone'));
isB = did2.query('', 'isa', 'demoB');

verifyTrue(testCase, withPep.hasNested());
verifyEqual(testCase, names(withPep), {'ngm'});
verifyEqual(testCase, names(isB & did2.query('', '~depends_on', 'ingredient', named('peptone'))), ...
    {'lb', 'ngm_np'});
verifyEqual(testCase, names(did2.query('', 'depends_on', 'formulation', withPep)), {'plate1'}, ...
    'two levels: plates poured from a formulation with peptone');
verifyEqual(testCase, names(did2.query('', 'depends_on', '*', named('peptone'))), {'ngm'});
verifyEqual(testCase, names(withPep | named('lb')), {'lb', 'ngm'});
verifyEqual(testCase, names(isB & did2.query('', 'depends_on', 'ingredient', ...
    named('agar') | named('peptone'))), {'ngm', 'ngm_np'}, 'an or inside the target');
verifyEmpty(testCase, db.search(did2.query('', 'depends_on', 'ingredient', named('nothing'))));
verifyEqual(testCase, names(isB & did2.query('', '~depends_on', 'ingredient', named('nothing'))), ...
    {'lb', 'ngm', 'ngm_np'});

% a list of ids: any of them
verifyEqual(testCase, names(did2.query('', 'depends_on', 'ingredient', {idOf(agar), idOf(pep)})), ...
    {'ngm', 'ngm_np'});
verifyEqual(testCase, names(did2.query('', 'depends_on', 'ingredient', {idOf(pep)})), {'ngm'});
verifyEmpty(testCase, db.search(did2.query('', 'depends_on', 'ingredient', {})));
verifyEqual(testCase, names(isB & did2.query('', '~depends_on', 'ingredient', {idOf(pep), 'x'})), ...
    {'lb', 'ngm_np'});

% one document alone cannot answer a nested target; a database can
verifyError(testCase, @() withPep.matches(ngm), 'did2:query:nestedNeedsDatabase');
r = db.testHookExplain(withPep);
verifySubstring(testCase, r.sql, 'json_each');
end

function testARepeatedEdgeNameIsStored(testCase)
% A V2 edge declared `multiple` (e.g. time_reference_id) repeats ONE name;
% the depends_on key used to be (doc_id, name) and refused the second row.
db = testCase.TestData.db;
d = makeDemoA('a', 'x');
d = d.set('depends_on', struct('name', {'time_reference_id', 'time_reference_id'}, ...
    'document_id', {'ref-1', 'ref-2'}));
db.add(d, 'Validate', false);
verifyEqual(testCase, numel(db.search(did2.query('', 'depends_on', 'time_reference_id', 'ref-1'))), 1);
verifyEqual(testCase, numel(db.search(did2.query('', 'depends_on', 'time_reference_id', 'ref-2'))), 1);
end

function testAnOldDatabaseIsRekeyedOnOpen(testCase)
% A database written before the key was widened: rebuild depends_on with the
% old (doc_id, name) key, reopen, and the repeated edge now goes in.
db = testCase.TestData.db;
d1 = makeDemoA('a', 'x');
d1 = d1.set('depends_on', struct('name', 'parent', 'document_id', 'id-1'));
db.add(d1, 'Validate', false);
db.close();
id = mksqlite(0, 'open', testCase.TestData.tmpFile);
mksqlite(id, 'ALTER TABLE depends_on RENAME TO t');
mksqlite(id, 'DROP INDEX IF EXISTS depends_on_name_document_id');
mksqlite(id, ['CREATE TABLE depends_on (doc_id TEXT NOT NULL REFERENCES documents(id) ' ...
    'ON DELETE CASCADE, name TEXT NOT NULL, document_id TEXT NOT NULL, ' ...
    'PRIMARY KEY (doc_id, name))']);
mksqlite(id, 'INSERT INTO depends_on SELECT doc_id, name, document_id FROM t');
mksqlite(id, 'DROP TABLE t');
mksqlite(id, 'close');

db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
verifyEqual(testCase, numel(db.search(did2.query('', 'depends_on', 'parent', 'id-1'))), 1, ...
    'the old rows survive the rebuild');
d2 = makeDemoA('b', 'y');
d2 = d2.set('depends_on', struct('name', {'parent', 'parent'}, 'document_id', {'id-1', 'id-2'}));
db.add(d2, 'Validate', false);
verifyEqual(testCase, numel(db.search(did2.query('', 'depends_on', 'parent', 'id-2'))), 1);
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

% ---- the creation timestamp, BOTH VINTAGES ------------------------------
%
% REGRESSION TEST, and the regression is the reason this block exists rather
% than a hypothetical. V_eta renamed `base.datestamp` ->
% `base.creation_timestamp` (signed 2026-08-13) and the outbound rename in
% v1_to_v2 strips the old key from every migrated body. `addOne` still
% required `base.datestamp`, so it threw did2:database:missingField on EVERY
% migrated document and ndi.migrate.local could not write one.
%
% IT WAS INVISIBLE FOR A DAY, AND THE REASON IS STRUCTURAL: every DID-side
% corpus test validates IN MEMORY and never opens a database. Only
% ndi.migrate.local writes. So testCorpusPRED stayed green across the whole
% window while the real migration path was broken end to end, and it was the
% FIRST RUN of the NDI-side PRED end-to-end test that surfaced it.
%
% Both directions are pinned. `blank()` fills whichever name the loaded
% schema declares, so each test SETS its key explicitly and REMOVES the other
% -- a document carrying both would pass under any implementation and prove
% nothing.

function testAddAcceptsTheVEtaCreationTimestamp(testCase)
db = testCase.TestData.db;
doc = withOnlyTimeKey(makeDemoA('eta', 'v'), 'creation_timestamp');
db.add(doc, 'Validate', false);
verifyEqual(testCase, db.count(), 1, ...
    'a V_eta document (base.creation_timestamp) was refused by the database');
end

function testAddStillAcceptsTheDidV1Datestamp(testCase)
% The old spelling must keep working: a database may hold pre-migration
% documents, and a one-way rename here would refuse them.
db = testCase.TestData.db;
doc = withOnlyTimeKey(makeDemoA('v1', 'v'), 'datestamp');
db.add(doc, 'Validate', false);
verifyEqual(testCase, db.count(), 1, ...
    'a did_v1 document (base.datestamp) was refused by the database');
end

function testADocumentWithNeitherTimeKeyIsRefusedNamingBoth(testCase)
% Carrying neither is a REAL fault and must still throw -- accepting it would
% put a NULL into a NOT NULL column. The message names both spellings so the
% next reader is not sent looking for the wrong field.
db = testCase.TestData.db;
doc = withOnlyTimeKey(makeDemoA('none', 'v'), '');
err = '';
try
    db.add(doc, 'Validate', false);
catch thrown
    err = thrown.identifier;
    msg = thrown.message;
end
verifyEqual(testCase, err, 'did2:database:missingField', ...
    'a document with no creation time was accepted');
verifySubstring(testCase, msg, 'base.creation_timestamp');
verifySubstring(testCase, msg, 'base.datestamp');
end

function verifySubstring(testCase, haystack, needle)
verifyTrue(testCase, contains(haystack, needle), sprintf( ...
    'the error message does not name %s: %s', needle, haystack));
end

function doc = withOnlyTimeKey(doc, keep)
%WITHONLYTIMEKEY Leave exactly one of the two creation-time keys populated.
%   `keep` is 'creation_timestamp', 'datestamp', or '' for neither.
s = doc.toStruct();
for name = {'creation_timestamp', 'datestamp'}
    f = name{1};
    if isfield(s.base, f)
        s.base = rmfield(s.base, f);
    end
end
if ~isempty(keep)
    s.base.(keep) = '2024-06-01T12:00:00.000Z';
end
doc = did2.document(s);
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

% ---- step 4: queryable scalar values in queryable_scalar_elem ----
%
% Until 2026-10-06 each queryable scalar path was a q_<flat> STORED
% generated column on `documents`, with its own index: 675 of them for the
% V_eta schema, which every insert had to maintain. The values now live in
% queryable_scalar_elem, one row per value a document has. These tests
% replace the generated-column ones.

function testScalarSidecarAtCreateAndNoGeneratedColumns(testCase)
db = testCase.TestData.db;
paths = db.testHookQueryableScalarPaths();
verifyTrue(testCase, all(ismember({'base.name', 'base.id', 'demoA.value'}, paths)));
n = mksqlite(db.testHookDbId(), ['SELECT COUNT(*) AS n FROM pragma_table_xinfo(''documents'') ' ...
    'WHERE name LIKE ''q\_%'' ESCAPE ''\''']);
verifyEqual(testCase, double(n.n), 0, 'no generated columns on documents');
mksqlite(db.testHookDbId(), 'SELECT doc_id, path, value_text, value_num, value_raw FROM queryable_scalar_elem LIMIT 0');
end

function testIndexedScalarMatchesFallback(testCase)
% Searching by base.name goes through the side table and returns the
% same documents as the in-memory evaluator.
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoA('bob',   'a2'); db.add(d2);
hits = db.search(did2.query('base.name', 'exact_string', 'alice'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d1.get('base.id'));
hits = db.search(did2.query('base.name', '~exact_string', 'alice'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d2.get('base.id'));
r = db.testHookExplain(did2.query('base.name', 'exact_string', 'alice'));
verifyTrue(testCase, any(contains({r.plan.detail}, 'qse_path_text')), ...
    sprintf('plan: %s', strjoin({r.plan.detail}, ' | ')));
end

function testScalarValuesStoredAtInsert(testCase)
db = testCase.TestData.db;
doc = makeDemoA('carol', 'cv');
db.add(doc);
rows = mksqlite(db.testHookDbId(), ...
    'SELECT path, value_text FROM queryable_scalar_elem WHERE doc_id = ? ORDER BY path', ...
    doc.get('base.id'));
got = containers.Map({rows.path}, cellfun(@char, {rows.value_text}, 'UniformOutput', false));
verifyEqual(testCase, got('base.name'), 'carol');
verifyEqual(testCase, got('demoA.value'), 'cv');
db.remove(doc.get('base.id'));
n = mksqlite(db.testHookDbId(), 'SELECT COUNT(*) AS n FROM queryable_scalar_elem WHERE doc_id = ?', ...
    doc.get('base.id'));
verifyEqual(testCase, double(n.n), 0, 'removed with the document');
end

function testAnOldLayoutDatabaseIsConvertedOnOpen(testCase)
% A database written before queryable_scalar_elem: a q_ generated column
% with its documents_q_ index, and no side-table rows. Opening it drops
% the column and the index, fills the side table from the bodies, and
% keeps every document.
db = testCase.TestData.db;
d1 = makeDemoA('alice', 'a1'); db.add(d1);
d2 = makeDemoB('bob', 'a2', 'b2'); db.add(d2);
id = db.testHookDbId();
mksqlite(id, ['ALTER TABLE documents ADD COLUMN q_base_name TEXT ' ...
    'GENERATED ALWAYS AS (json_extract(body, ''$.base.name'')) VIRTUAL']);
mksqlite(id, 'CREATE INDEX documents_q_base_name ON documents(q_base_name)');
mksqlite(id, 'DELETE FROM queryable_scalar_elem');
mksqlite(id, 'DELETE FROM meta WHERE key = ?', 'queryable_scalar_paths');
db.close();

db2 = did2.database.sqlitedb(testCase.TestData.tmpFile);
cleanup = onCleanup(@() db2.close()); %#ok<NASGU>
id2 = db2.testHookDbId();
n = mksqlite(id2, ['SELECT COUNT(*) AS n FROM pragma_table_xinfo(''documents'') ' ...
    'WHERE name LIKE ''q\_%'' ESCAPE ''\''']);
verifyEqual(testCase, double(n.n), 0, 'the generated column is gone');
n = mksqlite(id2, 'SELECT COUNT(*) AS n FROM sqlite_master WHERE name = ''documents_q_base_name''');
verifyEqual(testCase, double(n.n), 0, 'and its index');
verifyEqual(testCase, db2.count(), 2);
hits = db2.search(did2.query('base.name', 'exact_string', 'bob'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits{1}.get('base.id'), d2.get('base.id'));
n = mksqlite(id2, 'SELECT COUNT(*) AS n FROM queryable_scalar_elem WHERE path = ''base.name''');
verifyEqual(testCase, double(n.n), 2, 'the side table is filled from the bodies');
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

function testManyRowsCrossTheStatementChunks(testCase)
% Rows are written several to a statement, chunked under SQLite's
% bound-variable limit (999: 199 sidecar rows, 333 links per statement).
% A document with more than that must store every row, in order.
db = testCase.TestData.db;
n = 450;
axes = struct('name', repmat({'a'}, 1, n), 'unit', arrayfun(@(k) sprintf('u%d', k), 1:n, ...
    'UniformOutput', false), 'size', num2cell(1:n));
doc = makeDemoArray('many', axes);
db.add(doc);
id = doc.get('base.id');
rows = mksqlite(db.testHookDbId(), ['SELECT elem_index, value_num FROM queryable_array_elem ' ...
    'WHERE doc_id = ? AND path = ? ORDER BY rowid'], id, 'demoArray.axes[*].size');
verifyEqual(testCase, [rows.elem_index], 1:n, 'every element, in order');
verifyEqual(testCase, [rows.value_num], 1:n);
rows = mksqlite(db.testHookDbId(), ['SELECT value_text FROM queryable_array_elem ' ...
    'WHERE doc_id = ? AND path = ? ORDER BY rowid'], id, 'demoArray.axes[*].unit');
verifyEqual(testCase, cellfun(@char, {rows.value_text}, 'UniformOutput', false), ...
    arrayfun(@(k) sprintf('u%d', k), 1:n, 'UniformOutput', false));

m = 700;
d = makeDemoA('links', 'x');
d = d.set('depends_on', struct('name', repmat({'parent'}, 1, m), ...
    'document_id', arrayfun(@(k) sprintf('id-%d', k), 1:m, 'UniformOutput', false)));
db.add(d, 'Validate', false);
links = mksqlite(db.testHookDbId(), ...
    'SELECT document_id FROM depends_on WHERE doc_id = ? ORDER BY rowid', d.get('base.id'));
verifyEqual(testCase, cellfun(@char, {links.document_id}, 'UniformOutput', false), ...
    arrayfun(@(k) sprintf('id-%d', k), 1:m, 'UniformOutput', false));
sc = mksqlite(db.testHookDbId(), ...
    'SELECT classname FROM superclasses WHERE doc_id = ? ORDER BY rowid', d.get('base.id'));
verifyEqual(testCase, sort(cellfun(@char, {sc.classname}, 'UniformOutput', false)), sort({'base', 'demoA'}));
end

function testADocumentWithoutArrayBlocksWritesNoSidecarRows(testCase)
db = testCase.TestData.db;
d = makeDemoA('plain', 'x');
db.add(d);
n = mksqlite(db.testHookDbId(), ...
    'SELECT COUNT(*) AS n FROM queryable_array_elem WHERE doc_id = ?', d.get('base.id'));
verifyEqual(testCase, double(n.n), 0);
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
