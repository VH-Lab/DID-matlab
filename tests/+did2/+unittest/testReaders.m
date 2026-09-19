function tests = testReaders
%TESTREADERS Unit tests for did2.convert.readers.{sqliteV1, dumbJsonV1}.
%
%   Synthesises tiny v1 databases on the fly (a sqlite file built via
%   mksqlite, and a dumbjsondb-style directory of Object_id_*.json
%   files) and verifies that the two pure-read readers return the
%   exact bodies that were written. The sqlite tests are gated by an
%   assumeFail when mksqlite is missing, matching testSqliteDb.m.
%
%   Run with:
%       results = runtests('did2.unittest.testReaders');

tests = functiontests(localfunctions);
end

% ---- shared helpers ----

function body = makeV1Body(className, name)
body = struct();
body.document_class = struct( ...
    'class_name',    className, ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'document_id', {});
body.base = struct( ...
    'id',         ['aabb1122ccdd3344_' pad16(name)], ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       name, ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
body.(className) = struct('marker', name);
end

function s = pad16(name)
% pad/truncate to 16 hex chars; only used to fabricate unique-looking ids.
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end

function gateMksqlite(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping v1 sqlite reader tests.');
end
end

% ---- sqliteV1: happy path ----

function testSqliteV1ReturnsAllBodies(testCase)
gateMksqlite(testCase);
tmpFile = [tempname() '.sqlite'];
cleanup = onCleanup(@() safeDelete(tmpFile)); %#ok<NASGU>
b1 = jsonencode(makeV1Body('treatment', 'alpha'));
b2 = jsonencode(makeV1Body('ontology_image', 'beta'));
b3 = jsonencode(makeV1Body('probe_location', 'gamma'));
buildV1Sqlite(tmpFile, {b1, b2, b3});

bodies = did2.convert.readers.sqliteV1(tmpFile);
verifyEqual(testCase, numel(bodies), 3);
verifyEqual(testCase, sort(bodies(:)'), sort({b1, b2, b3}));
end

function testSqliteV1EmptyDocsTable(testCase)
gateMksqlite(testCase);
tmpFile = [tempname() '.sqlite'];
cleanup = onCleanup(@() safeDelete(tmpFile)); %#ok<NASGU>
buildV1Sqlite(tmpFile, {});

bodies = did2.convert.readers.sqliteV1(tmpFile);
verifyTrue(testCase, iscell(bodies));
verifyEmpty(testCase, bodies);
end

function testSqliteV1MissingFileErrors(testCase)
gateMksqlite(testCase);
verifyError(testCase, ...
    @() did2.convert.readers.sqliteV1([tempname() '.sqlite']), ...
    'did2:convert:readerFailed');
end

function testSqliteV1WrongSchemaErrors(testCase)
gateMksqlite(testCase);
tmpFile = [tempname() '.sqlite'];
cleanup = onCleanup(@() safeDelete(tmpFile)); %#ok<NASGU>
dbid = mksqlite(0, 'open', tmpFile);
mksqlite(dbid, 'CREATE TABLE other(x INTEGER)');
mksqlite(dbid, 'close');
verifyError(testCase, ...
    @() did2.convert.readers.sqliteV1(tmpFile), ...
    'did2:convert:readerFailed');
end

% ---- dumbJsonV1: happy path ----

function testDumbJsonV1ReturnsAllBodies(testCase)
tmpDir = makeTempDir();
cleanup = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>
b1 = jsonencode(makeV1Body('treatment', 'alpha'));
b2 = jsonencode(makeV1Body('ontology_image', 'beta'));
b3 = jsonencode(makeV1Body('probe_location', 'gamma'));
writeDumbJsonDoc(tmpDir, 'id_alpha', 0, b1);
writeDumbJsonDoc(tmpDir, 'id_beta',  0, b2);
writeDumbJsonDoc(tmpDir, 'id_gamma', 0, b3);

bodies = did2.convert.readers.dumbJsonV1(tmpDir);
verifyEqual(testCase, numel(bodies), 3);
verifyEqual(testCase, sort(bodies(:)'), sort({b1, b2, b3}));
end

function testDumbJsonV1ReturnsLatestVersion(testCase)
tmpDir = makeTempDir();
cleanup = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>
oldBody = jsonencode(makeV1Body('treatment', 'old'));
newBody = jsonencode(makeV1Body('treatment', 'new'));
writeDumbJsonDoc(tmpDir, 'id_versioned', 0, oldBody);
writeDumbJsonDoc(tmpDir, 'id_versioned', 5, newBody);

bodies = did2.convert.readers.dumbJsonV1(tmpDir);
verifyEqual(testCase, numel(bodies), 1);
verifyEqual(testCase, bodies{1}, newBody);
end

function testDumbJsonV1FindsNestedDirname(testCase)
tmpDir = makeTempDir();
cleanup = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>
inner = fullfile(tmpDir, '.dumbjsondb');
mkdir(inner);
body = jsonencode(makeV1Body('treatment', 'nested'));
writeDumbJsonDoc(inner, 'id_nested', 0, body);

bodies = did2.convert.readers.dumbJsonV1(tmpDir);
verifyEqual(testCase, numel(bodies), 1);
verifyEqual(testCase, bodies{1}, body);
end

function testDumbJsonV1EmptyDirectory(testCase)
tmpDir = makeTempDir();
cleanup = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>
bodies = did2.convert.readers.dumbJsonV1(tmpDir);
verifyTrue(testCase, iscell(bodies));
verifyEmpty(testCase, bodies);
end

function testDumbJsonV1MissingDirectoryErrors(testCase)
verifyError(testCase, ...
    @() did2.convert.readers.dumbJsonV1(fullfile(tempdir(), 'no-such-dir-xyz')), ...
    'did2:convert:readerFailed');
end

function testDumbJsonV1MalformedFileIsRawBytes(testCase)
% A malformed (non-JSON) file should still be returned verbatim; the
% reader is pure-read and does not parse. Downstream v1_to_v2 routes
% the parse failure into quarantine.
tmpDir = makeTempDir();
cleanup = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>
malformed = 'not json {';
writeDumbJsonDoc(tmpDir, 'id_bad', 0, malformed);

bodies = did2.convert.readers.dumbJsonV1(tmpDir);
verifyEqual(testCase, numel(bodies), 1);
verifyEqual(testCase, bodies{1}, malformed);
end

% ---- low-level fixture builders ----

function buildV1Sqlite(tmpFile, bodies)
% Replicate the minimal subset of did.implementations.sqlitedb's
% create_db_tables() that the v1 reader cares about.
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
for k = 1:numel(bodies)
    docId = sprintf('id_%04d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
end

function writeDumbJsonDoc(dir, docId, version, body)
filename = sprintf('Object_id_%s_v%s.json', docId, dec2hex(version, 5));
fullPath = fullfile(dir, filename);
fid = fopen(fullPath, 'w');
fwrite(fid, body, 'char');
fclose(fid);
% Ensure readable just like did.file.dumbjsondb expects.
try fileattrib(fullPath, '+r'); catch, end
end

function d = makeTempDir()
d = tempname();
mkdir(d);
end

function safeDelete(p)
try
    if isfile(p), delete(p); end
catch
end
end

function safeRmdir(p)
try
    if isfolder(p), rmdir(p, 's'); end
catch
end
end
