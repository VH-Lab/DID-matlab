function tests = testFromV1Database
%TESTFROMV1DATABASE End-to-end tests for did2.convert.fromV1Database.
%
%   Builds synthetic v1 databases (both flavours) on the fly, runs them
%   through fromV1Database, and verifies that the resulting v2
%   did2.database.sqlitedb contains every migrated document. Also
%   covers the quarantine sidecar and the Overwrite policy.
%
%   All tests run with Validate=false so the test runner does not need
%   a checked-out did-schema directory next to it. The fixtures are v1
%   `projectvar` documents (labelled demo_alpha, demo_beta, demo_gamma),
%   which have no migrator and are carried whole as v1, 1 -> 1
%   (did2.convert.noMigratorCarryRows; a class with no migrator and no
%   recorded decision quarantines, [early migration pieces fixed] (1)): these
%   tests are about the database round trip, not about any class's migration. The mksqlite gate
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
b1 = jsonencode(makeV1Body('demo_alpha', 'alpha'));
b2 = jsonencode(makeV1Body('demo_beta', 'beta'));
b3 = jsonencode(makeV1Body('demo_gamma', 'gamma'));
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
% the 3 migrated documents, the run's `migration` document and its report
% ([migration record writer], Jess Haley, 2026-11-01: a DID-only run writes
% its own record)
verifyEqual(testCase, db.count(), 3 + 2);
end

% ---- dumbjsondb -> v2 ----

function testFromDumbJsonRoundTripsAllDocs(testCase)
b1 = jsonencode(makeV1Body('demo_alpha', 'alpha'));
b2 = jsonencode(makeV1Body('demo_beta', 'beta'));
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
verifyEqual(testCase, db.count(), 2 + 2);   % + the migration record
end

% ---- the migration record ----

function testTheRunWritesOneMigrationRecordWithItsReport(testCase)
% [migration record], [migration report is an attached file], [migration
% method is conversion], [migration record points at the dataset] and
% [migration record writer] (Decided by Jess Haley, 2026-11-01, did-schema
% did_v2_go_forward_class_audit.md): one `migration` document per run, its
% method the conversion with the tool and its commit, its report a JSON file
% attached as an opaque_body; with no dataset in the run, it points at the
% session.
b1 = jsonencode(makeV1Body('demo_alpha', 'alpha'));
b2 = jsonencode(makeV1Body('demo_beta', 'beta'));
buildV1Sqlite(testCase.TestData.srcSqlite, {b1, b2});
result = did2.convert.fromV1Database(testCase.TestData.srcSqlite, ...
    testCase.TestData.dstPath, 'Validate', false);
rec = result.migration_record;
verifyNotEmpty(testCase, rec.migration_id);
verifyEqual(testCase, rec.report.counts.documents, 2);
verifyEqual(testCase, rec.report.counts.source_documents, 2);
verifyEqual(testCase, rec.report.counts.quarantined, 0);
db = did2.database.sqlitedb(testCase.TestData.dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
m = db.get(rec.migration_id);
verifyEqual(testCase, m.className(), 'migration');
method = m.get('migration.method');
verifyEqual(testCase, char(method.term.node), 'EDAM:operation_3434');
names = arrayfun(@(p) char(p.variable.name), method.parameters, 'UniformOutput', false);
% (the stored list reads back as a column)
verifyEqual(testCase, reshape(names, 1, []), ...
    {'software', 'version number', 'source format', 'target format'});
verifyEqual(testCase, char(method.parameters(1).text), 'DID-matlab');
verifyEqual(testCase, char(method.parameters(3).text), 'did_v1');
verifyEqual(testCase, char(method.parameters(4).text), 'did_v2');
ms = m.toStruct();
sid = ms.depends_on(strcmp({ms.depends_on.name}, 'session_id')).document_id;
verifyEqual(testCase, char(sid), 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'no dataset in the run: the record points at the session');
body = db.get(rec.report_id);
verifyEqual(testCase, body.className(), 'opaque_body');
verifyEqual(testCase, char(body.get('data_body.format').node), 'EDAM:format_3464');
report = jsondecode(fileread(db.filePath(rec.report_id, 'body_data_0')));
verifyTrue(testCase, all(isfield(report, {'gaps', 'carried_as_v1', 'counts'})));
verifyEqual(testCase, report.counts.documents, 2);
end

function testTwoSessionsWriteOneMigrationRecordEach(testCase)
% [one migration document per dataset] (Decided by Jess Haley, 2026-11-03,
% did-schema did_v2_go_forward_class_audit.md): "a run with two or more
% sessions and no dataset writes one per session", each pointing at its
% session with its own attached report. It stopped with
% did2:convert:migrationAnchor until then.
b1 = makeV1Body('demo_alpha', 'alpha');
b2 = makeV1Body('demo_beta', 'beta');
b3 = makeV1Body('demo_gamma', 'gamma');
b3.base.session_id = 'aabb1122ccdd3344_7700aabbccddeeff';
buildV1Sqlite(testCase.TestData.srcSqlite, {jsonencode(b1), jsonencode(b2), jsonencode(b3)});
result = did2.convert.fromV1Database(testCase.TestData.srcSqlite, ...
    testCase.TestData.dstPath, 'Validate', false);
rec = result.migration_record;
verifyNumElements(testCase, rec.migration_ids, 2);
verifyNumElements(testCase, rec.report_ids, 2);
verifyNumElements(testCase, rec.report, 2);
db = did2.database.sqlitedb(testCase.TestData.dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
verifyEqual(testCase, db.count(), 3 + 2 * 2, 'three documents, two records and two reports');
anchors = cell(1, 2);
docs = zeros(1, 2);
for k = 1:2
    m = db.get(rec.migration_ids{k});
    verifyEqual(testCase, m.className(), 'migration');
    ms = m.toStruct();
    anchors{k} = char(ms.depends_on(strcmp({ms.depends_on.name}, 'session_id')).document_id);
    bs = db.get(rec.report_ids{k}).toStruct();
    verifyEqual(testCase, char(bs.depends_on(strcmp({bs.depends_on.name}, 'owner_id')).document_id), ...
        rec.migration_ids{k}, 'each report is attached to its own record');
    report = jsondecode(fileread(db.filePath(rec.report_ids{k}, 'body_data_0')));
    verifyEqual(testCase, report.anchor, anchors{k});
    verifyEqual(testCase, report.counts.run.source_documents, 3, 'the run''s counts');
    docs(k) = report.counts.documents;
end
verifyEqual(testCase, sort(anchors), sort({'aabb1122ccdd3344_9900aabbccddeeff', ...
    'aabb1122ccdd3344_7700aabbccddeeff'}));
verifyEqual(testCase, sort(docs), [1 2], 'each report counts its own session''s documents');
end

function testTwoDatasetsWriteOneMigrationRecordEach(testCase) %#ok<INUSD>
% [one migration document per dataset]: two datasets, each with one session
% `included_in` it and a document of that session: one record per dataset,
% pointing at it, each report holding its own dataset's documents. A document
% naming a dataset directly belongs to it too.
ds = {'ds00000000000001_0000000000000001', 'ds00000000000002_0000000000000002'};
ss = {'se00000000000001_0000000000000001', 'se00000000000002_0000000000000002'};
docs = {};
for k = 1:2
    docs{end+1} = entityDoc(ds{k}, 'dataset', ds{k}); %#ok<AGROW>
    docs{end+1} = entityDoc(ss{k}, 'session', ss{k}); %#ok<AGROW>
    docs{end+1} = includedIn(sprintf('rel%014d_0000000000000000', k), ss{k}, ds{k}); %#ok<AGROW>
    docs{end+1} = entityDoc(sprintf('ob%014d_0000000000000000', k), 'organism', ss{k}); %#ok<AGROW>
end
docs{end+1} = entityDoc('ob00000000000009_0000000000000000', 'organism', ds{2});
[records, report] = did2.convert.migrationRecord(docs, 'Validate', false, ...
    'Version', 'test', 'Counts', struct('source_documents', 9));
verifyNumElements(testCase, records, 4);
verifyNumElements(testCase, report, 2);
verifyEqual(testCase, {report.anchor}, ds);
verifyEqual(testCase, [report(1).counts.documents, report(2).counts.documents], [4 5]);
for k = 1:2
    m = records{2 * k - 1}.toStruct();
    verifyEqual(testCase, m.document_class.class_name, 'migration');
    verifyEqual(testCase, char(m.depends_on(strcmp({m.depends_on.name}, 'session_id')).document_id), ds{k});
    verifyEqual(testCase, report(k).counts.run.source_documents, 9);
end
verifyNotEqual(testCase, records{1}.get('base.id'), records{3}.get('base.id'));
% a document belonging to neither dataset: not decided
docs{end+1} = entityDoc('ob00000000000010_0000000000000000', 'organism', 'elsewhere0000000_0000000000000000');
verifyError(testCase, @() did2.convert.migrationRecord(docs, 'Validate', false, ...
    'Version', 'test'), 'did2:convert:migrationAnchor');
end

% ---- quarantine ----

function testQuarantineFileWrittenForMalformedDoc(testCase)
goodBody = jsonencode(makeV1Body('demo_alpha', 'alpha'));
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
goodBody = jsonencode(makeV1Body('demo_alpha', 'alpha'));
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
goodBody = jsonencode(makeV1Body('demo_alpha', 'alpha'));
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
verifyEqual(testCase, db.count(), 1 + 2);   % + the migration record
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

function body = makeV1Body(label, name)
% a v1 `projectvar` (carried whole as v1, carry-162); LABEL names the fixture
body = struct();
body.document_class = struct( ...
    'class_name',    'projectvar', ...
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
body.projectvar = struct('marker', label);
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

function d = entityDoc(id, kind, sessionId)
% an `entity` of KIND (an entity_type handle) whose session_id edge names SESSIONID
d = struct();
d.document_class = struct('class_name', 'entity', 'class_version', '1.0.0', ...
    'schema_version', 'did_v2');
d.depends_on = struct('name', {'session_id'}, 'document_id', {sessionId});
d.base = struct('id', id, 'datestamp', '2024-06-01T12:00:00.000Z');
d.entity = struct('type', struct('node', did2.build.vocabulary('entity_type', kind), 'name', kind));
end

function d = includedIn(id, sessionId, datasetId)
% a session `included_in` its dataset
d = struct();
d.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'schema_version', 'did_v2');
d.depends_on = struct('name', {'session_id', 'child_id', 'parent_id'}, ...
    'document_id', {sessionId, sessionId, datasetId});
d.base = struct('id', id, 'datestamp', '2024-06-01T12:00:00.000Z');
d.directed_relation = struct('relation', struct('node', did2.build.vocabulary('relation', 'included_in'), ...
    'name', 'included in'));
end
