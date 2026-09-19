function tests = testFromV1Database
%TESTFROMV1DATABASE End-to-end tests for did2.convert.fromV1Database.
%
%   Builds synthetic v1 databases (both flavours) on the fly, runs them
%   through fromV1Database, and verifies that the resulting v2
%   did2.database.sqlitedb contains every migrated document. Also
%   covers the quarantine sidecar and the Overwrite policy.
%
%   All tests run with Validate=false so the test runner does not need
%   a checked-out did-schema directory next to it. The mksqlite gate
%   lives in setupOnce; if mksqlite is missing the whole file is
%   skipped, matching testSqliteDb.m.
%
%   Run with:
%       results = runtests('did2.unittest.testFromV1Database');

tests = functiontests(localfunctions);
end

function setupOnce(testCase) %#ok<INUSD>
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping fromV1Database tests.');
end
end

function setup(testCase)
testCase.TestData.tmpDir = makeTempDir();
testCase.TestData.dstPath = [tempname() '.sqlite'];
testCase.TestData.srcSqlite = [tempname() '.sqlite'];
end

function teardown(testCase)
safeDelete(testCase.TestData.dstPath);
safeDelete([testCase.TestData.dstPath '.quarantine.json']);
safeDelete(testCase.TestData.srcSqlite);
safeRmdir(testCase.TestData.tmpDir);
end

% ---- sqlite -> v2 ----

function testFromSqliteRoundTripsAllDocs(testCase)
b1 = jsonencode(makeV1Body('treatment', 'alpha'));
b2 = jsonencode(makeV1Body('ontology_image', 'beta'));
b3 = jsonencode(makeV1Body('probe_location', 'gamma'));
buildV1Sqlite(testCase.TestData.srcSqlite, {b1, b2, b3});

result = did2.convert.fromV1Database( ...
    testCase.TestData.srcSqlite, ...
    testCase.TestData.dstPath, ...
    'Validate', false);

verifyEqual(testCase, result.summary.total, 3);
verifyEqual(testCase, result.summary.migrated_count, 3);
verifyEqual(testCase, result.summary.quarantine_count, 0);
verifyTrue(testCase, isfile(testCase.TestData.dstPath));
verifyFalse(testCase, isfile([testCase.TestData.dstPath '.quarantine.json']));

db = did2.database.sqlitedb(testCase.TestData.dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
verifyEqual(testCase, db.count(), 3);
end

% ---- dumbjsondb -> v2 ----

function testFromDumbJsonRoundTripsAllDocs(testCase)
b1 = jsonencode(makeV1Body('treatment', 'alpha'));
b2 = jsonencode(makeV1Body('ontology_image', 'beta'));
writeDumbJsonDoc(testCase.TestData.tmpDir, 'id_alpha', 0, b1);
writeDumbJsonDoc(testCase.TestData.tmpDir, 'id_beta',  0, b2);

result = did2.convert.fromV1Database( ...
    testCase.TestData.tmpDir, ...
    testCase.TestData.dstPath, ...
    'Validate', false);

verifyEqual(testCase, result.summary.total, 2);
verifyEqual(testCase, result.summary.migrated_count, 2);
verifyEqual(testCase, result.summary.quarantine_count, 0);

db = did2.database.sqlitedb(testCase.TestData.dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
verifyEqual(testCase, db.count(), 2);
end

% ---- quarantine ----

function testQuarantineFileWrittenForMalformedDoc(testCase)
goodBody = jsonencode(makeV1Body('treatment', 'alpha'));
malformed = 'not json {';
buildV1Sqlite(testCase.TestData.srcSqlite, {goodBody, malformed});

result = did2.convert.fromV1Database( ...
    testCase.TestData.srcSqlite, ...
    testCase.TestData.dstPath, ...
    'Validate', false);

verifyEqual(testCase, result.summary.total, 2);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.quarantine_count, 1);

qfile = [testCase.TestData.dstPath '.quarantine.json'];
verifyTrue(testCase, isfile(qfile));
text = fileread(qfile);
decoded = jsondecode(text);
verifyTrue(testCase, isstruct(decoded));
% jsondecode of a one-element array collapses to a scalar struct;
% either way the original_body should round-trip through the field.
verifyTrue(testCase, isfield(decoded, 'original_body'));
end

% ---- overwrite policy ----

function testOverwriteFalseRefusesExistingDst(testCase)
goodBody = jsonencode(makeV1Body('treatment', 'alpha'));
buildV1Sqlite(testCase.TestData.srcSqlite, {goodBody});

% Touch the destination so it exists before the call.
fid = fopen(testCase.TestData.dstPath, 'w'); fclose(fid);

verifyError(testCase, @() did2.convert.fromV1Database( ...
    testCase.TestData.srcSqlite, ...
    testCase.TestData.dstPath, ...
    'Validate', false), ...
    'did2:convert:overwriteRefused');
end

function testOverwriteTrueReplacesExistingDst(testCase)
goodBody = jsonencode(makeV1Body('treatment', 'alpha'));
buildV1Sqlite(testCase.TestData.srcSqlite, {goodBody});

fid = fopen(testCase.TestData.dstPath, 'w');
fwrite(fid, 'placeholder', 'char');
fclose(fid);

result = did2.convert.fromV1Database( ...
    testCase.TestData.srcSqlite, ...
    testCase.TestData.dstPath, ...
    'Validate', false, ...
    'Overwrite', true);

verifyEqual(testCase, result.summary.migrated_count, 1);

db = did2.database.sqlitedb(testCase.TestData.dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
verifyEqual(testCase, db.count(), 1);
end

% ---- bad source ----

function testBadSourcePathErrors(testCase)
verifyError(testCase, @() did2.convert.fromV1Database( ...
    fullfile(tempdir(), 'no-such-path-zzz'), ...
    testCase.TestData.dstPath, ...
    'Validate', false), ...
    'did2:convert:badSourcePath');
end

% ---- helpers ----

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
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end

function buildV1Sqlite(tmpFile, bodies)
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
