function tests = testSqliteDbFiles
% testSqliteDbFiles - did2.database.sqlitedb's file store (ingestion).
%
%   A document's `files.file_info` locations with `ingest` true are copied
%   into <database folder>/files/<uid> on add and found again by
%   hasFile / filePath; a location with `ingest` false is recorded and read
%   where it is. Refusals leave the database untouched, removal deletes the
%   bytes a document ingested (unless another document records the same
%   uid), and a database written before the file store existed gains it on
%   open.
%
%   The whole file is filtered out if mksqlite is not on the MATLAB path.

tests = functiontests(localfunctions);
end

% ---- fixture setup / teardown ----

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping the v2 SQLite file-store tests.');
end
thisDir = fileparts(mfilename('fullpath'));
did2.schema.cache.setSchemaPath(fullfile(fileparts(thisDir), 'fixtures', 'V_delta'));
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.dir = tempname();
mkdir(testCase.TestData.dir);
testCase.TestData.src = fullfile(testCase.TestData.dir, 'sources');
mkdir(testCase.TestData.src);
testCase.TestData.dbFile = fullfile(testCase.TestData.dir, 'db.sqlite');
testCase.TestData.db = did2.database.sqlitedb(testCase.TestData.dbFile);
end

function teardown(testCase)
try testCase.TestData.db.close(); catch, end
if isfolder(testCase.TestData.dir)
    rmdir(testCase.TestData.dir, 's');
end
end

% ---- ingestion ----

function testAnIngestedFileIsCopiedAndFound(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'a.bin', uint8(1:10));
doc = docWithFile('alice', 'data', loc(src, 'uid_a', true));
db.add(doc);
p = db.filePath(doc.get('base.id'), 'data');
verifyEqual(testCase, p, fullfile(db.fileDir, 'uid_a'));
verifyEqual(testCase, readBytes(p), uint8(1:10));
verifyTrue(testCase, isfile(src), 'delete_original false: the source stays');
verifyEqual(testCase, db.fileNames(doc.get('base.id')), {'data'});
end

function testDeleteOriginalRemovesTheSourceAfterTheAdd(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'b.bin', uint8(5:9));
db.add(docWithFile('bob', 'data', loc(src, 'uid_b', true, true)));
verifyFalse(testCase, isfile(src));
verifyEqual(testCase, readBytes(fullfile(db.fileDir, 'uid_b')), uint8(5:9));
end

function testAFileRecordedByLocationIsReadWhereItIs(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'c.bin', uint8(3));
doc = docWithFile('carol', 'raw', loc(src, 'uid_c', false));
db.add(doc);
[tf, p] = db.hasFile(doc.get('base.id'), 'raw');
verifyTrue(testCase, tf);
verifyEqual(testCase, p, src);
verifyFalse(testCase, isfile(fullfile(db.fileDir, 'uid_c')), 'not ingested: not copied');
end

function testFilesSurviveReopening(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'd.bin', uint8(42));
doc = docWithFile('dave', 'data', loc(src, 'uid_d', true, true));
db.add(doc);
db.close();
db2 = did2.database.sqlitedb(testCase.TestData.dbFile);
testCase.TestData.db = db2;
verifyEqual(testCase, readBytes(db2.filePath(doc.get('base.id'), 'data')), uint8(42));
end

% ---- refusals leave nothing behind ----

function testAMissingSourceIsRefusedAndNothingIsWritten(testCase)
db = testCase.TestData.db;
good = writeSource(testCase, 'e.bin', uint8(1));
d1 = docWithFile('erin', 'data', loc(good, 'uid_e', true));
d2 = docWithFile('frank', 'data', loc(fullfile(testCase.TestData.src, 'nope.bin'), 'uid_f', true));
verifyError(testCase, @() db.add({d1, d2}), 'did2:database:ingestSourceMissing');
verifyEqual(testCase, db.count(), 0);
verifyFalse(testCase, isfile(fullfile(db.fileDir, 'uid_e')), 'checked before anything is copied');
end

function testAnUnsafeUidIsRefused(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'g.bin', uint8(1));
verifyError(testCase, @() db.add(docWithFile('gina', 'data', loc(src, '../escape', true))), ...
    'did2:database:unsafeFileUid');
verifyEqual(testCase, db.count(), 0);
end

function testOnlyAFileLocationIsIngested(testCase)
db = testCase.TestData.db;
L = loc('https://example.org/x.bin', 'uid_h', true);
L.location_type = 'url';
verifyError(testCase, @() db.add(docWithFile('hank', 'data', L)), ...
    'did2:database:ingestUnsupportedLocation');
end

function testAFailedBatchDeletesTheFilesItCopied(testCase)
db = testCase.TestData.db;
d1 = docWithFile('ivy', 'data', loc(writeSource(testCase, 'i.bin', uint8(1)), 'uid_i', true));
db.add(d1);
d2 = docWithFile('jack', 'data', loc(writeSource(testCase, 'j.bin', uint8(2)), 'uid_j', true));
% d1 again: its id is already stored, so the batch fails after the copy
failed = false;
try
    db.add({d2, d1});
catch
    failed = true;
end
verifyTrue(testCase, failed, 'adding a stored id again must fail');
verifyFalse(testCase, db.has(d2.get('base.id')));
verifyFalse(testCase, isfile(fullfile(db.fileDir, 'uid_j')), 'the copy is undone');
verifyTrue(testCase, isfile(fullfile(db.fileDir, 'uid_i')), 'what was already stored stays');
end

function testAUidStoredWithOtherBytesIsRefused(testCase)
db = testCase.TestData.db;
db.add(docWithFile('kim', 'data', loc(writeSource(testCase, 'k1.bin', uint8(1)), 'uid_k', true)));
verifyError(testCase, @() db.add(docWithFile('lee', 'data', ...
    loc(writeSource(testCase, 'k2.bin', uint8(2)), 'uid_k', true))), ...
    'did2:database:ingestUidCollision');
verifyEqual(testCase, readBytes(fullfile(db.fileDir, 'uid_k')), uint8(1));
end

% ---- removal ----

function testRemovingADocumentDeletesItsBytes(testCase)
db = testCase.TestData.db;
doc = docWithFile('mia', 'data', loc(writeSource(testCase, 'm.bin', uint8(7)), 'uid_m', true));
db.add(doc);
db.remove(doc.get('base.id'));
verifyFalse(testCase, isfile(fullfile(db.fileDir, 'uid_m')));
end

function testASharedUidOutlivesTheFirstRemoval(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'n.bin', uint8(8));
d1 = docWithFile('nia', 'data', loc(src, 'uid_n', true));
d2 = docWithFile('ned', 'data', loc(src, 'uid_n', true));
db.add({d1, d2});
db.remove(d1.get('base.id'));
verifyTrue(testCase, isfile(fullfile(db.fileDir, 'uid_n')), 'd2 still records it');
db.remove(d2.get('base.id'));
verifyFalse(testCase, isfile(fullfile(db.fileDir, 'uid_n')));
end

% ---- lookup errors name the gap ----

function testFilePathNamesWhatIsMissing(testCase)
db = testCase.TestData.db;
src = writeSource(testCase, 'o.bin', uint8(9));
doc = docWithFile('olga', 'raw', loc(src, 'uid_o', false));
db.add(doc);
id = doc.get('base.id');
verifyError(testCase, @() db.filePath(id, 'other'), 'did2:database:noSuchFile');
delete(src);
verifyError(testCase, @() db.filePath(id, 'raw'), 'did2:database:fileNotHere');
verifyError(testCase, @() db.filePath('no-such-id', 'raw'), 'did2:database:missingDocument');
verifyFalse(testCase, db.hasFile(id, 'raw'));
end

% ---- a database from before the file store ----

function testAnOldDatabaseGainsTheFileStoreOnOpen(testCase)
db = testCase.TestData.db;
mksqlite(db.testHookDbId(), 'DROP TABLE files');
db.close();
db2 = did2.database.sqlitedb(testCase.TestData.dbFile);
testCase.TestData.db = db2;
src = writeSource(testCase, 'p.bin', uint8(4));
doc = docWithFile('pat', 'data', loc(src, 'uid_p', true));
db2.add(doc);
verifyEqual(testCase, readBytes(db2.filePath(doc.get('base.id'), 'data')), uint8(4));
end

% ---- the document is validated with its files block ----

function testADocumentWithFilesValidates(testCase)
db = testCase.TestData.db;
doc = docWithFile('quinn', 'data', loc(writeSource(testCase, 'q.bin', uint8(1)), 'uid_q', true));
db.add(doc, 'Validate', true);
verifyTrue(testCase, db.has(doc.get('base.id')));
end

% ---- helpers ----

function L = loc(location, uid, ingest, deleteOriginal)
if nargin < 4, deleteOriginal = false; end
L = struct('delete_original', double(deleteOriginal), 'uid', uid, ...
    'location', location, 'parameters', '', 'location_type', 'file', ...
    'ingest', double(ingest));
end

function doc = docWithFile(name, fileName, location)
base = did2.document.blank('demoA');
base = base.set('base.session_id', sprintf('session-%s', name));
base = base.set('base.name', name);
base = base.set('demoA.value', name);
s = base.toStruct();
s.files = struct('file_list', {{fileName}}, ...
    'file_info', struct('name', fileName, 'locations', location));
doc = did2.document(s);
end

function p = writeSource(testCase, name, bytes)
p = fullfile(testCase.TestData.src, name);
fid = fopen(p, 'w');
fwrite(fid, bytes, 'uint8');
fclose(fid);
end

function b = readBytes(p)
fid = fopen(p, 'r');
b = reshape(fread(fid, Inf, '*uint8'), 1, []);
fclose(fid);
end
