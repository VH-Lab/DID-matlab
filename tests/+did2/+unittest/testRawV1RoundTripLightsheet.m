function tests = testRawV1RoundTripLightsheet
%TESTRAWV1ROUNDTRIPLIGHTSHEET fileReference, lightsheetZarrPyramid and
%   lightsheetZarrLevel read as raw v1, and their round trip (migrators
%   file_reference, lightsheet_zarr_pyramid, lightsheet_zarr_level, joined by
%   did2.convert.rawV1Classes' table).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE TEMPLATES are NDI-matlab's at the locked `main` (3cb19a8), copied
%   verbatim to tests/+did2/fixtures/ndi_templates (data/fileReference.json,
%   data/lightsheetZarrPyramid.json, data/lightsheetZarrLevel.json). THE v1
%   DOCUMENTS ARE THE WRITERS': +ndi/+fun/+doc/+lightsheet/makeSourceFile.m
%   (an OME-Zarr store, a directory: fileSize 0, the checksum of `.zattrs`) and
%   +ndi/+fun/+doc/+gene/makeSourceFile.m (a plain file with its size and a
%   documentID), both with attachFile false; +lightsheet/makePyramid.m for the
%   pyramid (from fromOMEZarr: an NGFF dtype; from fromSPIM: a MATLAB class
%   name and unitless t and c) and makeOneLevel for its levels. No corpus of
%   the four zips holds any of the three (Test code run 40503720102: 0
%   file_reference documents and 0 lightsheet carriers over 193416 documents).
%
%   WHAT THE SWITCH CHANGES. fileReference passes through pass 1 under its v1
%   class name, where the renamed path passed `file_reference` through;
%   did2.convert.foldGenericFiles reads both (did2.convert.isFileReferenceClass)
%   and folds both to the same store body. The pyramid and level conversions
%   are unchanged (testTheSwitchChangesNoOutcome).
%
%   KNOWN FINDINGS, listed exactly (today's behaviour is kept; the migrators'
%   headers record them): the pyramid's byte_order (its levels carry it); a
%   level's dtype (the pyramid's observation states it), subject_id and
%   source_file_id edges. A level's label and its index are no longer lost:
%   the label is the body's description and the index is read from it
%   ([light-sheet level label is a note], Jess Haley, 2026-10-27).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the lightsheet raw-v1 round trips');
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the switch ======================================

function testTheSwitchListsTheThreeClasses(testCase)
names = did2.convert.rawV1Classes();
pairs = {'fileReference', 'file_reference'; ...
    'lightsheetZarrPyramid', 'lightsheet_zarr_pyramid'; ...
    'lightsheetZarrLevel', 'lightsheet_zarr_level'};
for k = 1:size(pairs, 1)
    verifyTrue(testCase, any(strcmp(names, pairs{k, 1})), pairs{k, 1});
    verifyEqual(testCase, did2.convert.rawV1Classes(pairs{k, 1}), pairs{k, 2}, pairs{k, 1});
end
r = runRaw([fileReferences(), {omeZarrPyramid()}, levels()]);
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, 2 + 1 + 3);
end

function testTheFoldReadsBothSpellings(testCase)
verifyTrue(testCase, did2.convert.isFileReferenceClass('fileReference'));
verifyTrue(testCase, did2.convert.isFileReferenceClass('file_reference'));
verifyTrue(testCase, did2.convert.isFileReferenceClass("fileReference"));
verifyFalse(testCase, did2.convert.isFileReferenceClass('generic_file'));
verifyFalse(testCase, did2.convert.isFileReferenceClass(''));
verifyFalse(testCase, did2.convert.isFileReferenceClass(42));
end

% ===================== round trips =====================================

function testFileReferencesRoundTripAsPassthroughs(testCase)
f = fileReferences();
for k = 1:numel(f)
    v1 = f{k};
    label = sprintf('fileReference %d', k);
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
    verifyEqual(testCase, char(out.migrated{1}.get('document_class.class_name')), ...
        'fileReference', [label ': the raw passthrough keeps the v1 class name']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testPyramidsRoundTrip(testCase)
P = {'OME-Zarr', omeZarrPyramid(); 'SmartSPIM', smartSpimPyramid(); ...
    'no source file', noSourcePyramid()};
for k = 1:size(P, 1)
    [label, v1] = P{k, :};
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, ...
        {'lightsheetZarrPyramid.byte_order'});
end
end

function testLevelsRoundTrip(testCase)
L = levels();
lost = {'lightsheetZarrLevel.dtype', 'depends_on(2).value', 'depends_on(3).value'};
for k = 1:numel(L)
    v1 = L{k};
    label = char(v1.base.id);
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, lost);
    verifyTrue(testCase, any(strcmp('lightsheetZarrLevel.label', r.matched)), label);
    verifyTrue(testCase, any(strcmp('lightsheetZarrLevel.level', r.matched)), label);
    % the label is the body's description, unchanged
    b = out.migrated{1}.toStruct();
    verifyEqual(testCase, did2.unittest.helpers.notesOf(b.data_body), v1.lightsheetZarrLevel.label, label);
end
end

function testALevelWhoseLabelDoesNotFollowTheWriterIsCarried(testCase)
% [light-sheet level label is a note] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): "a level whose label does not
% follow that pattern is carried whole as v1, kind `malformed`" (carry-115)
L = levels();
v1 = L{2};   % level 1, max
bad = {'a level of my own', 'mean level 2 (max)', 'mean level 1 (mean)'};
for k = 1:numel(bad)
    x = v1;
    x.lightsheetZarrLevel.label = bad{k};
    verifyCarried(testCase, x, '[carry-115] malformed');
end
% an empty label states nothing only for level 0
x = v1;
x.lightsheetZarrLevel.label = '';
verifyCarried(testCase, x, '[carry-115] malformed');
x = L{1};
x.lightsheetZarrLevel.label = '';
out = runRaw({x});
verifyEmpty(testCase, out.passthrough, 'level 0 with no label converts');
r = did2.convert.roundtrip.check(x, out.migrated);
verifyFalse(testCase, any(strcmp({r.lost.path}, 'lightsheetZarrLevel.level')));
verifyFalse(testCase, any(strcmp({r.lost.path}, 'lightsheetZarrLevel.label')));
end

function testADifferentSourceIsReportedLost(testCase)
v1 = omeZarrPyramid();
out = runRaw({v1});
v1.lightsheetZarrPyramid.label = 'another label';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, any(strcmp({r.lost.path}, 'lightsheetZarrPyramid.label')));

v1 = fileReferences();
v1 = v1{1};
out = runRaw({v1});
v1.fileReference.originalPath = '/elsewhere';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'fileReference.originalPath'});
end

% ===================== the switch changes no outcome =====================

function testTheSwitchChangesNoOutcome(testCase)
% the pyramid and level conversions are the same on both paths, document for
% document (pass 1)
for b = [{omeZarrPyramid(), smartSpimPyramid(), noSourcePyramid()}, levels()]
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(b);
    verifyEmpty(testCase, problems, sprintf('%s: %s', char(b{1}.base.id), ...
        strjoin(problems, '; ')));
end
end

function testTheFoldIsTheSameOnBothPaths(testCase)
% a pyramid, its store record and its levels, through pass 1 AND the batch
% pass: the same documents and the same fold counters on both paths
batch = [{omeZarrPyramid()}, fileReferences(), levels()];
[raw, rawRep] = withFold(batch, {});
[old, oldRep] = withFold(batch, {'RawV1Classes', {}});
verifyEmpty(testCase, raw.quarantine, 'raw');
verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine));
verifyEqual(testCase, rawRep.stores_folded, 1, 'the store record folds');
verifyEqual(testCase, rawRep.store_records_seen, 2, 'both records are seen');
verifyEqual(testCase, rawRep.store_records_left_passthrough, 1, ...
    'the gene source no pyramid names stays a passthrough');
for f = reshape(fieldnames(oldRep), 1, [])
    if isnumeric(oldRep.(f{1})) && isfield(rawRep, f{1})
        verifyEqual(testCase, rawRep.(f{1}), oldRep.(f{1}), ['fold counter ' f{1}]);
    end
end
a = byId(raw.migrated);
b = byId(old.migrated);
verifyEqual(testCase, fieldnames(a), fieldnames(b), 'the same document ids');
passId = matlab.lang.makeValidName('fref_gene_1');
for k = reshape(fieldnames(a), 1, [])
    if ~isfield(b, k{1}); continue; end
    if strcmp(k{1}, passId)
        % the one difference: the unfolded record's class name and block
        verifyEqual(testCase, a.(k{1}).document_class.class_name, 'fileReference');
        verifyEqual(testCase, b.(k{1}).document_class.class_name, 'file_reference');
        continue;
    end
    verifyTrue(testCase, isequaln(a.(k{1}), b.(k{1})), ...
        sprintf('%s differs: raw %s; renamed %s', k{1}, jsonencode(a.(k{1})), ...
        jsonencode(b.(k{1}))));
end
end

function testACarriedFileReferenceIsNotFolded(testCase)
% Decided by Jess Haley, 2026-10-27 [carried file references are not folded]:
% the store fold skips a fileReference pass 1 carried as v1 (stamped 'did_v1');
% it stays the untouched v1 document, and the pyramid's observation keeps its
% source_file_id link to it
f = fileReferences();
rec = f{1};
rec.fileReference.mimeType = 'application/zarr';   % outside the template: carry-100
% Pass 1 in ONE call carries the pyramid and its levels too ([dependents of a
% carried document carry], carry-064), so no converted carrier would name the
% record. The fold meets a carried record named by a converted pyramid when the
% two came out of separate pass-1 calls, as here: the batches are joined, then
% folded.
first = did2.convert.v1_to_v2([{omeZarrPyramid()}, levels()], 'Validate', true, ...
    'TargetVersion', 'V_eta');
second = did2.convert.v1_to_v2({rec, f{2}}, 'Validate', true, 'TargetVersion', 'V_eta');
out = first;
out.migrated = [first.migrated, second.migrated];
out.quarantine = [first.quarantine, second.quarantine];
[out, rep] = did2.convert.foldGenericFiles(out, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, rep.store_records_seen, 2);
verifyEqual(testCase, rep.store_records_carried_as_v1, 1, 'the carried record is seen as carried');
verifyEqual(testCase, rep.store_skipped_carried_as_v1, 1, 'its carrier is skipped');
verifyEqual(testCase, rep.stores_folded, 0, 'a carried record was folded');
verifyEqual(testCase, rep.store_carriers_stripped, 0, 'the carrier lost its link');
m = byId(out.migrated);
assertTrue(testCase, isfield(m, 'fref_store_1'), 'the carried record left the batch');
r = m.fref_store_1;
verifyEqual(testCase, r.document_class.class_name, 'fileReference');
verifyEqual(testCase, r.document_class.schema_version, 'did_v1');
verifyEqual(testCase, r.fileReference.mimeType, 'application/zarr');
chk = did2.convert.roundtrip.check(rec, {r});
verifyTrue(testCase, chk.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, chk, 'carried fileReference', {});
assertTrue(testCase, isfield(m, 'pyr_ls_1'));
obs = m.pyr_ls_1;
verifyEqual(testCase, edgeValue(obs, 'source_file_id'), 'fref_store_1', ...
    'the pyramid lost its link to the carried record');
% the levels are still completed from the pyramid's carried axes
verifyEqual(testCase, rep.level_bodies_seen, 3);
end

function v = edgeValue(b, name)
v = '';
if ~isfield(b, 'depends_on'); return; end
d = b.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    if isfield(d{k}, 'name') && strcmp(d{k}.name, name)
        if isfield(d{k}, 'value'); v = char(d{k}.value);
        elseif isfield(d{k}, 'document_id'); v = char(d{k}.document_id); end
        return;
    end
end
end

% ===================== carries ===========================================

function testTheCarriesNameTheirReason(testCase)
f = fileReferences();
v1 = f{1};
v1.fileReference.mimeType = 'application/zarr';
verifyCarried(testCase, v1, ...
    '[carry-100] malformed: outside the NDI template, unplaced: fileReference.mimeType');
v1 = omeZarrPyramid();
v1.lightsheetZarrPyramid.objective = '4x';
verifyCarried(testCase, v1, 'lightsheetZarrPyramid.objective');
L = levels();
v1 = did2.unittest.helpers.setDependency(L{1}, 'element_id', 'elem_scope_1');
verifyCarried(testCase, v1, 'depends_on(element_id)');
end

% ===================== fixtures =========================================

function f = fileReferences()
% +lightsheet/makeSourceFile.m on an OME-Zarr store (a directory), and
% +gene/makeSourceFile.m on a plain file with a documentID
a = did2.unittest.helpers.ndiDocument('fileReference', 'Id', 'fref_store_1', ...
    'SessionId', 'sess_ls_1', 'Datestamp', '2026-10-01T12:00:00.000Z');
a.fileReference = struct('filename', 'brain7.ome.zarr', ...
    'originalPath', '/data/stores/brain7.ome.zarr', 'formatOntology', '', ...
    'dateCreated', 739253.12783564813, 'dateUpdated', 739254.12783564813, ...
    'fileSize', 0, 'checksum', '0123456789abcdef0123456789abcdef', ...
    'checksumAlgorithm', 'MD5');
a = jsondecode(jsonencode(a));
b = did2.unittest.helpers.ndiDocument('fileReference', 'Id', 'fref_gene_1', ...
    'SessionId', 'sess_ls_1', 'Datestamp', '2026-10-01T12:00:00.000Z');
b.fileReference = struct('filename', 'Opossum.tissue.gef', ...
    'originalPath', '/data/stereoseq/Opossum.tissue.gef', ...
    'formatOntology', 'EDAM:format_3590', ...
    'dateCreated', 739200.5, 'dateUpdated', 739201.5, ...
    'fileSize', 12345678, 'checksum', 'fedcba9876543210fedcba9876543210', ...
    'checksumAlgorithm', 'MD5');
b = did2.unittest.helpers.setDependency(b, 'document_id', 'genelist_1');
b = jsondecode(jsonencode(b));
f = {a, b};
end

function v1 = omeZarrPyramid()
% makePyramid from fromOMEZarr: dtype from `.zarray`, two channels, a t axis
v1 = did2.unittest.helpers.ndiDocument('lightsheetZarrPyramid', 'Id', 'pyr_ls_1', ...
    'SessionId', 'sess_ls_1', 'Datestamp', '2026-10-01T12:00:00.000Z');
v1.lightsheetZarrPyramid = struct('label', 'brain 7 cleared', ...
    'pyramid_name', 'mean', 'pyramid_type', 'mean', 'axes_order', 'tczyx', ...
    'axes_units', 'second,,micrometer,micrometer,micrometer', ...
    'channel_names', 'GCaMP6s,tdTomato', 'n_channels', 2, ...
    'shape_level0', [1 2 400 2048 2048], 'voxel_size_level0', [1 1 2 0.5 0.5], ...
    'voxel_size_units', 'micrometer', 'translation_level0', [0 0 10 0 0], ...
    'dtype', '<u2', 'pipeline_version', 'lightsheet-pipeline 0.3.1', ...
    'byte_order', 'little');
v1 = did2.unittest.helpers.setDependency(v1, 'subject_id', 'subj_ls_1');
v1 = did2.unittest.helpers.setDependency(v1, 'element_id', 'elem_scope_1');
v1 = did2.unittest.helpers.setDependency(v1, 'source_file_id', 'fref_store_1');
v1 = jsondecode(jsonencode(v1));
end

function v1 = smartSpimPyramid()
% makePyramid from fromSPIM: dtype a MATLAB class name, t and c unitless, no
% element, no channel names
v1 = did2.unittest.helpers.ndiDocument('lightsheetZarrPyramid', 'Id', 'pyr_spim_1', ...
    'SessionId', 'sess_ls_1', 'Datestamp', '2026-10-01T12:00:00.000Z');
v1.lightsheetZarrPyramid = struct('label', 'brain 9', ...
    'pyramid_name', 'brain9', 'pyramid_type', 'mean', 'axes_order', 'tczyx', ...
    'axes_units', ',,micrometer,micrometer,micrometer', ...
    'channel_names', '', 'n_channels', 1, ...
    'shape_level0', [1 1 300 1024 1024], 'voxel_size_level0', [1 1 4 1.8 1.8], ...
    'voxel_size_units', 'micrometer', 'translation_level0', [0 0 0 0 0], ...
    'dtype', 'uint16', 'pipeline_version', '', 'byte_order', 'little');
v1 = did2.unittest.helpers.setDependency(v1, 'subject_id', 'subj_ls_2');
v1 = did2.unittest.helpers.setDependency(v1, 'source_file_id', 'fref_spim_1');
v1 = jsondecode(jsonencode(v1));
end

function v1 = noSourcePyramid()
% makePyramid with no sourceFileID: the migrator mints a file-less store body
v1 = omeZarrPyramid();
v1.base.id = 'pyr_nosrc_1';
v1 = did2.unittest.helpers.setDependency(v1, 'source_file_id', '');
end

function L = levels()
% makeOneLevel for the OME-Zarr pyramid: level 0 with its series manifest,
% level 1 (max) with two members named outright, level 1 (mean) with no bytes
L = {level(0, 'none', 4, 'manifest'), level(1, 'max', 2, 'members'), ...
    level(1, 'mean', 0, 'none')};
end

function v1 = level(n, reduction, nStored, fileShape)
f = 2 ^ n;
shape = [1 2 ceil(400 / f) ceil(2048 / f) ceil(2048 / f)];
chunks = [1 1 64 256 256];
v1 = did2.unittest.helpers.ndiDocument('lightsheetZarrLevel', ...
    'Id', sprintf('lvl_ls_%d_%s', n, reduction), ...
    'SessionId', 'sess_ls_1', 'Datestamp', '2026-10-01T12:00:00.000Z');
v1.lightsheetZarrLevel = struct( ...
    'label', sprintf('mean level %d (%s)', n, reduction), 'level', n, ...
    'reduction_function', reduction, 'axes_order', 'tczyx', 'shape', shape, ...
    'chunks', chunks, 'chunk_grid', ceil(shape ./ chunks), ...
    'n_chunks_stored', nStored, 'chunk_index_origin', 1, 'chunk_order', 'C', ...
    'dtype', '<u2', 'fill_value', 0, 'byte_order', 'little', 'codec', 'raw', ...
    'codec_params', '{}', 'voxel_size', [1 1 2 * f 0.5 * f 0.5 * f], ...
    'voxel_size_units', 'micrometer', 'translation', [0 0 10 0 0]);
v1 = did2.unittest.helpers.setDependency(v1, 'lightsheetZarrPyramid_id', 'pyr_ls_1');
v1 = did2.unittest.helpers.setDependency(v1, 'subject_id', 'subj_ls_1');
v1 = did2.unittest.helpers.setDependency(v1, 'source_file_id', 'fref_store_1');
loc = @(uid) struct('delete_original', 0, 'uid', uid, ...
    'location', ['/data/ingest/' uid], 'parameters', '', ...
    'location_type', 'file', 'ingest', 1);
switch fileShape
    case 'none'
        % the template's files block, nothing attached (materializeChunks false)
    case 'manifest'
        v1.files = struct('file_list', {{'chunk.bin'}}, ...
            'file_series', {{'chunk.bin'}}, ...
            'file_info', struct('name', 'chunk.bin', 'locations', loc('manifest_uid_1')), ...
            'series_info', struct('name', 'chunk.bin', 'count', nStored, ...
                'n_present', nStored, 'source_root', ''));
    case 'members'
        names = arrayfun(@(k) sprintf('chunk.bin_%d', k), 1:nStored, 'UniformOutput', false);
        info = struct('name', names, 'locations', ...
            arrayfun(@(k) loc(sprintf('member_uid_%d', k)), 1:nStored, 'UniformOutput', false));
        v1.files = struct('file_list', {names}, 'file_series', {{'chunk.bin'}}, ...
            'file_info', info);
end
v1 = jsondecode(jsonencode(v1));
end

% ===================== helpers =========================================

function out = runRaw(batch)
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
end

function [out, rep] = withFold(batch, extra)
out = did2.convert.v1_to_v2(batch, 'Validate', true, 'TargetVersion', 'V_eta', extra{:});
[out, rep] = did2.convert.foldGenericFiles(out, 'Validate', true, 'TargetVersion', 'V_eta');
end

function m = byId(docs)
m = struct();
for k = 1:numel(docs)
    s = docs{k}.toStruct();
    m.(matlab.lang.makeValidName(char(s.base.id))) = s;
end
m = orderfields(m);
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
