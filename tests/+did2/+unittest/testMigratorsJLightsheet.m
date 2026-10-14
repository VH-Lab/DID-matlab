function tests = testMigratorsJLightsheet
%TESTMIGRATORSJLIGHTSHEET The lightsheet migrators, 'lightsheet_zarr_pyramid'
%   and 'lightsheet_zarr_level', through did2.convert.v1_to_v2 (TargetVersion
%   'V_eta', validated against the schema DID_SCHEMA_PATH names).
%
%   THE DESIGN THEY IMPLEMENT IS NOT SIGNED: DID-schema review/73/OPEN_ITEMS.md,
%   "Lightsheet OME-Zarr", L1-L4, walked 2026-09-25 and agreed with no
%   TEAM-SIGN-OFF line. These tests pin the most literal reading of it, so a
%   team decision the other way shows up as a named failing test.
%
%   THE FIXTURES ARE THE WRITER'S, NOT A SCHEMA'S. Every v1 document below is
%   shaped as NDI's one writer builds it, NDI-matlab origin/main
%   src/ndi/+ndi/+fun/+doc/+lightsheet/makePyramid.m:
%     pyramid  session.newdocument('lightsheetZarrPyramid', ...) with label,
%              pyramid_name, pyramid_type, axes_order (names joined),
%              axes_units (joined with ','), channel_names, n_channels,
%              shape_level0, voxel_size_level0, voxel_size_units
%              'micrometer', translation_level0, dtype, pipeline_version,
%              byte_order 'little'; depends_on subject_id, element_id,
%              source_file_id
%     level    makeOneLevel: level, reduction_function, axes_order, shape,
%              chunks, chunk_grid, n_chunks_stored (0 unless materialized),
%              chunk_index_origin 1, chunk_order 'C', dtype, fill_value 0,
%              byte_order 'little', codec 'raw' | 'blosc-zstd', codec_params,
%              voxel_size, voxel_size_units, translation; depends_on
%              lightsheetZarrPyramid_id, subject_id, source_file_id; bytes
%              (only when materialized) as the file series `chunk.bin`
%   The OME-Zarr path's dtype is the store's `.zarray` typestring ('<u2',
%   TestFromOMEZarr.m:145); the SmartSPIM path's is a MATLAB class name
%   ('uint16', fromSPIM.m), with axes_units ',,micrometer,micrometer,micrometer'.
%
%   L4 -- "the DID-matlab migrator test must decompress a real NDI chunk with
%   no parameters" -- is testARealNdiBloscChunkDecodesWithNoParameters. NO REAL
%   NDI BLOSC CHUNK EXISTS IN ANY REPOSITORY this was written against
%   (DID-matlab, did-schema, NDI-matlab, NDR-matlab were searched), so that
%   test SKIPS, saying so, unless DID_LIGHTSHEET_BLOSC_CHUNK names one. It is
%   never faked with a chunk this test makes itself.
%
%   STATUS: NEVER RUN LOCALLY. There is no MATLAB in the authoring container;
%   CI is the first execution.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJLightsheet');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the lightsheet migrator tests');
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the pyramid =========================================

function testPyramidBecomesAnIntensityObservationWithItsIdPreserved(testCase)
assumeCompositionSchema(testCase);
v1 = pyramidV1();
out = runJ(v1);
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
obs = pickById(out, v1.base.id);
verifyNotEmpty(testCase, obs, 'the observation must keep the pyramid''s id');
verifyEqual(testCase, obs.document_class.class_name, 'observation');
supers = superNames(obs);
verifyTrue(testCase, any(strcmp(supers, 'intensity')), ...
    sprintf('the value kind must be intensity; superclasses: %s', strjoin(supers, ', ')));
end

function testPyramidEdges(testCase)
assumeCompositionSchema(testCase);
v1 = pyramidV1();
out = runJ(v1);
obs = pickById(out, v1.base.id);
verifyEqual(testCase, edge(obs, 'entity_id'), 'subj_ls_1');
verifyEqual(testCase, edge(obs, 'instrument_id'), 'elem_scope_1');
sw = pickByClass(out, 'entity');
verifyEqual(testCase, numel(sw), 1);
verifyEqual(testCase, edge(obs, 'software_id'), sw{1}.base.id);
verifyEqual(testCase, sw{1}.entity.name, 'lightsheet-pipeline 0.3.1');
verifyEqual(testCase, sw{1}.entity.type.name, 'software');
% The pyramid carries no time; nothing may claim one (migrator header).
verifyEqual(testCase, edge(obs, 'time_reference_id'), '');
% The edges every member of the batch names resolve inside it, given the two
% entities the pyramid points at from outside (subject and microscope).
ref = did2.validate.references(out.migrated, 'KnownIds', {'subj_ls_1', 'elem_scope_1'});
verifyEqual(testCase, ref.orphan_count, 0);
end

function testPyramidDtypeBecomesDataTypeWithTheSourceSpelling(testCase)
assumeCompositionSchema(testCase);
v1 = pyramidV1();
out = runJ(v1);
obs = pickById(out, v1.base.id);
verifyEqual(testCase, obs.value.data_type, 'uint16');
verifyEqual(testCase, obs.value.source_data_type, '<u2');
verifyTrue(testCase, isequal(obs.value.data_body, true));
end

function testTheStoreBecomesAnUnheldOpaqueBodyWithFullResolutionKeys(testCase)
assumeCompositionSchema(testCase);
v1 = pyramidV1();
out = runJ(v1);
bodies = pickByClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 1);
b = bodies{1};
verifyEqual(testCase, edge(b, 'owner_id'), v1.base.id);
verifyEqual(testCase, b.data_body.format, 'application/x-ome-zarr');
verifyFalse(testCase, isfield(b, 'files') && ~isempty(b.files), ...
    'the store is UNHELD: its body must claim no member');
verifyFalse(testCase, isfield(b.data_body, 'content_hash'), ...
    'the .zattrs MD5 is not a payload hash (L3(e))');
keys = keyList(b.data.keys);
verifyEqual(testCase, cellfun(@(k) k.variable.name, keys, 'UniformOutput', false), ...
    {'time', 'channel', 'z', 'y', 'x'});
verifyEqual(testCase, cellfun(@(k) double(k.n), keys), [1 2 400 2048 2048]);
z = keys{3};
verifyEqual(testCase, z.unit.name, 'meter');
verifyEqual(testCase, z.source_unit, 'micrometer');
verifyEqual(testCase, double(z.spacing.value), 2e-6, 'AbsTol', 1e-15);
verifyEqual(testCase, double(z.spacing.source_value), 2);
verifyEqual(testCase, double(z.origin.value), 10e-6, 'AbsTol', 1e-15);
t = keys{1};
verifyEqual(testCase, t.unit.name, 'second');
c = keys{2};
verifyEqual(testCase, labelNames(c.labels), {'GCaMP6s', 'tdTomato'});
for k = 1:numel(keys)
    verifyFalse(testCase, isfield(keys{k}, 'chunk') && ~isempty(keys{k}.chunk), ...
        'chunk is used ONLY on a sampled_body''s keys');
end
end

function testASmartSpimPyramidHasNoStoreBody(testCase)
% fromSPIM's source is a directory of TIFF slices, not an OME-Zarr store, and
% its dtype is a MATLAB class name: no opaque_body may call it OME-Zarr.
assumeCompositionSchema(testCase);
v1 = pyramidV1();
v1.lightsheetZarrPyramid.dtype = 'uint16';
v1.lightsheetZarrPyramid.axes_units = ',,micrometer,micrometer,micrometer';
out = runJ(v1);
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
verifyEqual(testCase, numel(pickByClass(out, 'opaque_body')), 0);
obs = pickById(out, v1.base.id);
verifyEqual(testCase, obs.value.data_type, 'uint16');
verifyFalse(testCase, isfield(obs.value, 'source_data_type') ...
    && ~isempty(obs.value.source_data_type), 'uint16 is canonical: no source spelling');
end

function testNoPipelineVersionMeansNoSoftwareEntity(testCase)
assumeCompositionSchema(testCase);
v1 = pyramidV1();
v1.lightsheetZarrPyramid.pipeline_version = '';
v1.depends_on = v1.depends_on(~strcmp({v1.depends_on.name}, 'element_id'));
out = runJ(v1);
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
verifyEqual(testCase, numel(pickByClass(out, 'entity')), 0);
obs = pickById(out, v1.base.id);
verifyEqual(testCase, edge(obs, 'software_id'), '');
verifyEqual(testCase, edge(obs, 'instrument_id'), '');
end

function testAPyramidWithNoSubjectQuarantines(testCase)
% subject_id is required by NDI's own schema and by the statement; a pyramid
% without one must fail loudly, never become an observation of nobody.
assumeCompositionSchema(testCase);
v1 = pyramidV1();
v1.depends_on(strcmp({v1.depends_on.name}, 'subject_id')).value = '';
out = runJ(v1);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, numel(out.migrated), 0);
end

% ===================== the levels ==========================================

function testAMetadataOnlyLevelFoldsToNothingAndIsCounted(testCase)
% materializeChunks defaults to FALSE, so this is what most levels look like.
assumeCompositionSchema(testCase);
out = runJ(levelV1(0, 'none', 'raw', 0, 'none'));
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
verifyEqual(testCase, numel(out.migrated), 0);
verifyEqual(testCase, out.summary.emitted_nothing_count, 1);
verifyEqual(testCase, out.summary.emitted_nothing_by_class.lightsheet_zarr_level, 1);
verifyEqual(testCase, out.summary.unconverted_count, 0);
end

function testALevelCountingChunksItDoesNotCarryQuarantines(testCase)
assumeCompositionSchema(testCase);
out = runJ(levelV1(0, 'none', 'raw', 4, 'none'));
verifyEqual(testCase, numel(out.migrated), 0);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).identifier, ...
    'did2:migrators_j:lightsheet:chunksDeclaredButAbsent');
end

function testLevelZeroBecomesTheMeasurementBody(testCase)
assumeCompositionSchema(testCase);
v1 = levelV1(0, 'none', 'raw', 4, 'manifest');
out = runJ(v1);
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
b = onlyBody(testCase, out);
verifyEqual(testCase, edge(b, 'owner_id'), 'pyr_ls_1');
verifyEqual(testCase, b.sampled_body.datum_order, 'C');
verifyEqual(testCase, b.sampled_body.byte_order, 'little');
verifyEqual(testCase, b.sampled_body.fill_value, '0');
verifyTrue(testCase, isequal(b.data.complete, true));
verifyFalse(testCase, isfield(b.data_body, 'compression') && ~isempty(b.data_body.compression), ...
    'codec raw means no compression');
verifyFalse(testCase, isfield(b.data_body, 'redundant') && isequal(b.data_body.redundant, true), ...
    'level 0 is the measurement, not redundant');
verifyFalse(testCase, isfield(b.data_body, 'conditions') && ~isempty(b.data_body.conditions));
keys = keyList(b.data.keys);
verifyEqual(testCase, cellfun(@(k) double(k.chunk), keys), [1 1 64 256 256]);
verifyEqual(testCase, cellfun(@(k) double(k.n), keys), [1 2 400 2048 2048]);
end

function testTheChunkSeriesIsRenamedAndItsLocationsKept(testCase)
assumeCompositionSchema(testCase);
v1 = levelV1(0, 'none', 'raw', 4, 'manifest');
out = runJ(v1);
b = onlyBody(testCase, out);
verifyEqual(testCase, cellstr(b.files.file_list), {'body_data'});
verifyEqual(testCase, b.files.file_info(1).name, 'body_data');
verifyEqual(testCase, b.files.file_info(1).locations, v1.files.file_info(1).locations);
verifyEqual(testCase, b.files.series_info(1).name, 'body_data');
verifyEqual(testCase, double(b.files.series_info(1).count), 4);
end

function testNamedChunkMembersShiftToZeroBased(testCase)
% chunk.bin_k -> body_data_{k-1}: V_eta numbers body_data members from 0
% (item 17); the v1 series from 1 (chunk_index_origin).
assumeCompositionSchema(testCase);
v1 = levelV1(0, 'none', 'raw', 2, 'members');
out = runJ(v1);
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
b = onlyBody(testCase, out);
verifyEqual(testCase, {b.files.file_info.name}, {'body_data_0', 'body_data_1'});
rep = did2.validate.fileList(out.migrated);
verifyEqual(testCase, rep.present_undeclared_count, 0, ...
    'body_data_0/1 are members of the declared series body_data');
end

function testAReducedLevelIsRedundantWithItsSummaryStatistic(testCase)
assumeCompositionSchema(testCase);
out = runJ(levelV1(2, 'max', 'blosc-zstd', 4, 'manifest'));
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
b = onlyBody(testCase, out);
verifyTrue(testCase, isequal(b.data_body.redundant, true));
verifyEqual(testCase, b.data_body.compression, 'blosc');
cond = b.data_body.conditions;
if iscell(cond); cond = cond{1}; end
verifyEqual(testCase, numel(cond), 1);
verifyEqual(testCase, cond(1).variable.name, 'summary statistic');
verifyEqual(testCase, termName(cond(1).term.value), 'maximum');

out = runJ(levelV1(1, 'mean', 'blosc-zstd', 4, 'manifest'));
b = onlyBody(testCase, out);
cond = b.data_body.conditions;
if iscell(cond); cond = cond{1}; end
verifyEqual(testCase, termName(cond(1).term.value), 'mean');
end

function testLevelZeroOfASingleReductionStoreIsStillTheMeasurement(testCase)
% makePyramid.m stamps 'none' only on a level SHARED by several reductions; a
% store ingested with one reduction has level 0 stamped 'mean'. It is still
% the full-resolution measurement.
assumeCompositionSchema(testCase);
out = runJ(levelV1(0, 'mean', 'raw', 4, 'manifest'));
b = onlyBody(testCase, out);
verifyFalse(testCase, isfield(b.data_body, 'redundant') && isequal(b.data_body.redundant, true));
verifyFalse(testCase, isfield(b.data_body, 'conditions') && ~isempty(b.data_body.conditions));
end

function testPyramidAndLevelsTogetherResolve(testCase)
assumeCompositionSchema(testCase);
batch = {pyramidV1(), levelV1(0, 'none', 'raw', 4, 'manifest'), ...
    levelV1(1, 'mean', 'blosc-zstd', 4, 'manifest'), levelV1(1, 'max', 'raw', 0, 'none')};
out = did2.convert.v1_to_v2(batch, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, numel(out.quarantine), 0, reasonsOf(out));
verifyEqual(testCase, numel(pickByClass(out, 'sampled_body')), 2);
verifyEqual(testCase, out.summary.emitted_nothing_count, 1);
ref = did2.validate.references(out.migrated, 'KnownIds', {'subj_ls_1', 'elem_scope_1'});
verifyEqual(testCase, ref.orphan_count, 0, ...
    'every body''s owner_id must name the pyramid''s preserved id');
end

% ===================== L4: a real NDI Blosc chunk ===========================

function testARealNdiBloscChunkDecodesWithNoParameters(testCase)
%   #73 L4 dropped `codec_params` on the claim that a Blosc chunk is
%   self-describing: its 16-byte header records shuffle and typesize, so it
%   decodes with no parameters. That was checked with python-blosc on bytes
%   compressed the way the writer compresses -- NOT on a chunk NDI wrote. This
%   test is the check on a real one. It needs:
%     DID_LIGHTSHEET_BLOSC_CHUNK  a chunk.bin_k file written by
%                                 ndi.fun.doc.lightsheet.makePyramid with codec
%                                 'blosc-zstd', and beside it <file>.json
%                                 {"dtype": "<u2"|"uint16"|..., "chunks": [..]}
%                                 copied from its lightsheetZarrLevel document
%     ndr.format.blosc.decode     on the path (NDR-matlab)
%   Without either it SKIPS. It does not make a chunk itself: a chunk this test
%   wrote would prove only that the test's encoder agrees with the decoder.
chunkPath = getenv('DID_LIGHTSHEET_BLOSC_CHUNK');
assumeFalse(testCase, isempty(chunkPath), ...
    ['L4 NOT CHECKED: no real NDI blosc-zstd chunk is available. None is ' ...
     'committed to DID-matlab, did-schema, NDI-matlab or NDR-matlab; set ' ...
     'DID_LIGHTSHEET_BLOSC_CHUNK to a chunk.bin_k file NDI''s makePyramid ' ...
     'wrote (with its level''s dtype and chunks in <file>.json) to run it.']);
assumeTrue(testCase, isfile(chunkPath), ...
    sprintf('L4 NOT CHECKED: DID_LIGHTSHEET_BLOSC_CHUNK names no file (%s).', chunkPath));
assumeTrue(testCase, isfile([chunkPath '.json']), ...
    sprintf('L4 NOT CHECKED: %s.json (the level''s dtype and chunks) is missing.', chunkPath));
assumeFalse(testCase, isempty(which('ndr.format.blosc.decode')), ...
    'L4 NOT CHECKED: ndr.format.blosc.decode (NDR-matlab) is not on the path.');

meta = jsondecode(fileread([chunkPath '.json']));
fid = fopen(chunkPath, 'r');
raw = fread(fid, Inf, '*uint8');
fclose(fid);
verifyGreaterThanOrEqual(testCase, numel(raw), 16, 'a Blosc chunk has a 16-byte header');
% Blosc v1 header: version, versionlz, flags, typesize, nbytes (uint32 LE), ...
flags = raw(3);
typesize = double(raw(4));
nbytes = double(typecast(raw(5:8), 'uint32'));
verifyEqual(testCase, bitand(flags, uint8(1)), uint8(1), ...
    'the writer compresses with shuffle 1 (makePyramid.m padEncodeAndWrite)');
expectedTypesize = elementBytes(char(meta.dtype));
verifyEqual(testCase, typesize, expectedTypesize, ...
    'the header must record the element size, or codec_params could not be dropped');
expected = prod(double(meta.chunks)) * expectedTypesize;
verifyEqual(testCase, nbytes, expected);

out = ndr.format.blosc.decode(raw);   % NO parameters: the whole point of L4
verifyEqual(testCase, numel(out), expected, ...
    'decoding with no parameters must give the full padded chunk');
end

% ===================== harness =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'V_eta');
end

function assumeCompositionSchema(testCase)
%ASSUMECOMPOSITIONSCHEMA Skip unless the schema has what these targets need:
%   statements by composition (an `observation` that takes a value kind, and
%   `intensity`), the two body classes, and the lightsheet v1 tombstones.
try
    cache = did2.schema.cache.shared();
    need = {'observation', 'intensity', 'sampled_body', 'opaque_body', ...
        'entity', 'lightsheet_zarr_pyramid', 'lightsheet_zarr_level'};
    missing = need(~cellfun(@(c) cache.hasClass(c), need));
    hasKind = cache.hasClass('observation') && ~isempty(cache.valueKindRule('observation'));
catch err
    assumeFail(testCase, ['the schema cache did not load: ' err.message]);
    return;
end
assumeEmpty(testCase, missing, sprintf( ...
    'DID_SCHEMA_PATH lacks %s: not a did-schema with the lightsheet targets.', ...
    strjoin(missing, ', ')));
assumeTrue(testCase, hasKind, ...
    'DID_SCHEMA_PATH predates statements by composition (observation takes no value kind).');
end

function msg = reasonsOf(out)
if isempty(out.quarantine)
    msg = 'no quarantined documents';
    return;
end
msg = '';
for k = 1:numel(out.quarantine)
    msg = [msg sprintf('[%s] %s\n', out.quarantine(k).class_name, ...
        out.quarantine(k).reason)]; %#ok<AGROW>
end
end

function s = pickById(out, id)
s = [];
for k = 1:numel(out.migrated)
    d = out.migrated{k}.toStruct();
    if strcmp(d.base.id, id)
        s = d;
        return;
    end
end
end

function c = pickByClass(out, className)
c = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k}.toStruct();
    if strcmp(d.document_class.class_name, className)
        c{end+1} = d; %#ok<AGROW>
    end
end
end

function b = onlyBody(testCase, out)
c = pickByClass(out, 'sampled_body');
assertEqual(testCase, numel(c), 1, reasonsOf(out));
b = c{1};
end

function names = superNames(d)
sc = d.document_class.superclasses;
if isstruct(sc); sc = num2cell(sc); end
names = cellfun(@(s) char(s.class_name), sc, 'UniformOutput', false);
end

function v = edge(d, name)
v = '';
if ~isfield(d, 'depends_on') || isempty(d.depends_on); return; end
deps = d.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    if strcmp(deps{k}.name, name)
        if isfield(deps{k}, 'document_id'); v = char(deps{k}.document_id);
        else; v = char(deps{k}.value); end
        return;
    end
end
end

function keys = keyList(k)
if isstruct(k); keys = num2cell(k); else; keys = k; end
keys = reshape(keys, 1, []);
end

function names = labelNames(labels)
if isstruct(labels); labels = num2cell(labels); end
names = cellfun(@(l) char(l.name), labels, 'UniformOutput', false);
names = reshape(names, 1, []);
end

function n = termName(v)
if iscell(v); v = v{1}; end
if isstruct(v); n = char(v(1).name); else; n = char(v); end
end

function b = elementBytes(dtype)
tok = regexp(dtype, '^[<>|][uifcb](\d+)$', 'tokens', 'once');
if ~isempty(tok)
    b = str2double(tok{1});
    return;
end
switch dtype
    case {'uint8', 'int8', 'logical'};          b = 1;
    case {'uint16', 'int16'};                   b = 2;
    case {'uint32', 'int32', 'single'};         b = 4;
    case {'uint64', 'int64', 'double'};         b = 8;
    otherwise;                                  b = NaN;
end
end

% ===================== fixtures, built from the writer ======================

function v1 = pyramidV1()
%PYRAMIDV1 A lightsheetZarrPyramid as makePyramid writes one from an OME-Zarr
%   store (fromOMEZarr): dtype from `.zarray`, two channels, a t axis.
v1 = struct();
v1.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/data/lightsheetZarrPyramid.json', ...
    'validation', '$NDISCHEMAPATH/data/lightsheetZarrPyramid_schema.json', ...
    'class_name', 'lightsheetZarrPyramid', ...
    'property_list_name', 'lightsheetZarrPyramid', ...
    'class_version', 1, ...
    'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {'subject_id', 'element_id', 'source_file_id'}, ...
    'value', {'subj_ls_1', 'elem_scope_1', 'fref_store_1'});
v1.base = struct('id', 'pyr_ls_1', 'session_id', 'sess_ls_1', 'name', '', ...
    'datestamp', '2026-10-01T12:00:00.000Z');
v1.lightsheetZarrPyramid = struct( ...
    'label', 'brain 7 cleared', ...
    'pyramid_name', 'mean', ...
    'pyramid_type', 'mean', ...
    'axes_order', 'tczyx', ...
    'axes_units', 'second,,micrometer,micrometer,micrometer', ...
    'channel_names', 'GCaMP6s,tdTomato', ...
    'n_channels', 2, ...
    'shape_level0', [1 2 400 2048 2048], ...
    'voxel_size_level0', [1 1 2 0.5 0.5], ...
    'voxel_size_units', 'micrometer', ...
    'translation_level0', [0 0 10 0 0], ...
    'dtype', '<u2', ...
    'pipeline_version', 'lightsheet-pipeline 0.3.1', ...
    'byte_order', 'little');
end

function v1 = levelV1(level, reduction, codec, nStored, fileShape)
%LEVELV1 A lightsheetZarrLevel as makeOneLevel writes one. FILESHAPE:
%   'none'      no bytes attached (materializeChunks false, the default)
%   'manifest'  the series attached by did.document/addFileSeries: the
%               manifest under the bare name chunk.bin (file_info) plus its
%               series_info record (ingest_locations stripped, as stored)
%   'members'   members listed by name, chunk.bin_1 .. chunk.bin_NSTORED
f = 2 ^ level;
shape = [1 2 ceil(400 / f) ceil(2048 / f) ceil(2048 / f)];
chunks = [1 1 64 256 256];
v1 = struct();
v1.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/data/lightsheetZarrLevel.json', ...
    'validation', '$NDISCHEMAPATH/data/lightsheetZarrLevel_schema.json', ...
    'class_name', 'lightsheetZarrLevel', ...
    'property_list_name', 'lightsheetZarrLevel', ...
    'class_version', 1, ...
    'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {'lightsheetZarrPyramid_id', 'subject_id', 'source_file_id'}, ...
    'value', {'pyr_ls_1', 'subj_ls_1', 'fref_store_1'});
v1.base = struct('id', sprintf('lvl_ls_%d_%s', level, reduction), ...
    'session_id', 'sess_ls_1', 'name', '', 'datestamp', '2026-10-01T12:00:00.000Z');
codecParams = '{}';
if strcmp(codec, 'blosc-zstd')
    codecParams = '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}';
end
v1.lightsheetZarrLevel = struct( ...
    'label', sprintf('mean level %d (%s)', level, reduction), ...
    'level', level, ...
    'reduction_function', reduction, ...
    'axes_order', 'tczyx', ...
    'shape', shape, ...
    'chunks', chunks, ...
    'chunk_grid', ceil(shape ./ chunks), ...
    'n_chunks_stored', nStored, ...
    'chunk_index_origin', 1, ...
    'chunk_order', 'C', ...
    'dtype', '<u2', ...
    'fill_value', 0, ...
    'byte_order', 'little', ...
    'codec', codec, ...
    'codec_params', codecParams, ...
    'voxel_size', [1 1 2 * f 0.5 * f 0.5 * f], ...
    'voxel_size_units', 'micrometer', ...
    'translation', [0 0 10 0 0]);
loc = @(uid) struct('delete_original', 0, 'uid', uid, ...
    'location', ['/data/ingest/' uid], 'parameters', '', ...
    'location_type', 'file', 'ingest', 1);
switch fileShape
    case 'none'
        v1.files = struct('file_list', {{'chunk.bin'}}, ...
            'file_series', {{'chunk.bin'}}, ...
            'file_info', struct('name', {}, 'locations', {}));
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
end
