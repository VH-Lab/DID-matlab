function bodies = lightsheet_zarr_level(preBody)
%LIGHTSHEET_ZARR_LEVEL Brainstorm-J migrator: did_v1 lightsheetZarrLevel -> a
%   `sampled_body` of the pyramid's observation; a FILE-LESS one when the level
%   holds no bytes ([compression block and empty levels], Jess Haley,
%   2026-10-26), where it emitted NOTHING before.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THE DESIGN IS NOT SIGNED. It is the #73 lightsheet walkthrough L1-L4
%   (DID-schema review/73/OPEN_ITEMS.md, walked 2026-09-25, agreed by jess, NO
%   `TEAM-SIGN-OFF` line), recorded as this class's `decided_targets` in
%   DID-schema schemas/V_eta_migration_targets.json. See OPEN POINTS below for
%   where it is silent.
%
%   ---------------------------------------------------------------------
%   WHAT THE WRITER PUTS ON THE DOCUMENT
%   ---------------------------------------------------------------------
%   NDI origin/main src/ndi/+ndi/+fun/+doc/+lightsheet/makePyramid.m,
%   makeOneLevel -- the ONE construction site:
%     level (0-based), reduction_function ('none' for the level shared by
%     every reduction, else the single reduction naming it: 'mean' / 'max'),
%     axes_order, shape, chunks (a PLANNED re-tiling, not the store's own),
%     chunk_grid, n_chunks_stored (prod(chunk_grid) when materialized, else
%     0), chunk_index_origin 1, chunk_order 'C', dtype, fill_value 0,
%     byte_order 'little', codec ('raw' | 'blosc-zstd'), codec_params (JSON),
%     voxel_size, voxel_size_units 'micrometer' (hard-coded), translation
%     depends_on lightsheetZarrPyramid_id, subject_id, source_file_id
%   Chunk bytes are attached ONLY when `materializeChunks` is true, and it
%   DEFAULTS TO FALSE (makePyramid.m arguments block). They are attached as the
%   file series `chunk.bin` through did.document/addFileSeries, so a stored
%   document carries the series' MANIFEST under the bare name `chunk.bin`
%   (files.file_info + files.series_info) and its members chunk.bin_1..N are
%   resolved through the manifest (DID-matlab docs/notes/file_series_manifest.md).
%   A document may also list members by name (`chunk.bin_k`); both shapes are
%   read here.
%
%   ---------------------------------------------------------------------
%   WHAT IT BECOMES
%   ---------------------------------------------------------------------
%   A level holding bytes -> ONE sampled_body (#73 L1, L2, L3(d), L4):
%     owner_id       <- lightsheetZarrPyramid_id (the pyramid's id, which
%                       lightsheet_zarr_pyramid.m PRESERVES on its
%                       observation)
%     dimensions     one per axis of axes_order, each with its `chunk`,
%     covariates     and one covariate along each holding its positions
%                       (jLightsheetAxes; `keys` until data_body AMENDMENT 6);
%                       the level's own shape, voxel size and translation
%     datum_order    chunk_order ('C': the chunk bytes are C-order,
%                       makePyramid.m readStoredChunk / padPermuteBytes)
%     byte_order     the level's byte_order -- or the dtype typestring's own
%                       ('<' / '>') where they disagree, which is reported by
%                       an error rather than chosen; '' for one-byte types
%     fill_value     the level's fill_value, as the literal the owner's
%                       data_type reads (a dense grid; `complete` was
%                       removed by AMENDMENT 6)
%     compression    absent for 'raw'. Otherwise, in the form the loaded
%                       schema declares (did2.build.compression):
%                       - the `{term, parameters}` block, once did-schema
%                         declares it ([compression block and empty levels]
%                         (1), Jess Haley, 2026-10-26; did-schema #137): the
%                         codec as a term ('blosc-zstd' -> Blosc) and EVERY
%                         codec_params key as a parameter, in order (cname ->
%                         'inner compressor', clevel -> 'compression level',
%                         shuffle, blocksize -> 'block size'). The block is
%                         written only when did2.build.compressionCodec reads
%                         it back as the level's codec and codec_params
%                         exactly; otherwise the level is carried whole as v1
%                         (carry-010).
%                       - a char, while did-schema still types it so: the
%                         codec name VERBATIM ('blosc-zstd' stays
%                         'blosc-zstd'; it was written 'blosc', which lost the
%                         inner compressor -- [lossless means round trip],
%                         Jess Haley, 2026-10-26). A level whose codec_params
%                         hold settings beyond the codec name is then CARRIED
%                         WHOLE AS V1 (carry-010; they were dropped under #73
%                         L4 as write-time settings).
%     redundant      true for every level but level 0, the measurement (L1)
%     conditions     reduced levels (level > 0) only: `summary statistic` =
%                       'mean' | 'maximum' from reduction_function (L1 option
%                       C: a body condition)
%     files          chunk.bin -> body_data (the series manifest), and
%                       chunk.bin_k -> body_data_{k-1} for a member named
%                       outright; file_info / series_info renamed to match,
%                       locations untouched
%     base.id        the v1 level document's own id, KEPT (lightsheet point
%                       11, Jess 2026-10-14, option A): the body IS the level,
%                       so it keeps the level's identity, as the pyramid's
%                       observation keeps the pyramid's. Any edge a dataset
%                       carries to the level resolves to its body.
%   A level holding NO bytes -> a FILE-LESS sampled_body, built as above (the
%   level's id, dimensions, covariates and the rest), its description (when
%   the level has no label) saying no bytes are stored and its `files` removed, as lightsheet_zarr_pyramid's
%   sourcelessStoreBody does ([compression block and empty levels] (2), Jess
%   Haley, 2026-10-26, as [no-source pyramid gets a file-less store body]).
%   This replaces #73 L3(c) ("a level holding NO bytes -> nothing"), which left
%   an edge to the level orphaned. One that names no pyramid has no owner and
%   is carried whole as v1.
%
%   ---------------------------------------------------------------------
%   OPEN POINTS -- RECORDED, NOT RESOLVED
%   ---------------------------------------------------------------------
%   * MEMBER NUMBERING -- DECIDED (Jess 2026-10-14: keep DID-schema #73 item
%     17). V_eta numbers body_data members from 0 and v1 file series from 1,
%     both against the same zero-based manifest: chunk.bin_k and
%     body_data_{k-1} are both slot k-1, so the rename above keeps every
%     slot where it is. did.document/seriesMemberBase reads the base off the
%     document's vintage, so seriesMemberOf resolves body_data_0 on this
%     (V_eta) document to the bytes chunk.bin_1 named on the v1 one.
%   * THE t UNIT AND THE CHANNEL NAMES -- DECIDED (Jess 2026-10-14, lightsheet
%     point 8). The level document carries only `voxel_size_units`
%     (hard-coded 'micrometer'), so this migrator still writes the `t`
%     covariate with no unit and the `c` covariate with index positions. The pyramid has the
%     per-axis `axes_units` and the `channel_names`; lightsheet_zarr_pyramid
%     carries them on its observation (as its full-resolution dimensions and
%     covariates, transient) and did2.convert.foldGenericFiles copies them
%     onto the covariates of EVERY
%     sampled_body this level's owner_id names: `t` gets its unit, `c`'s
%     positions are named by channel, and z/y/x units are CHECKED against the
%     pyramid's -- a disagreement is counted (`level_unit_disagreements`), not
%     overwritten. A level whose pyramid is not in the batch keeps its own and
%     is counted (`level_bodies_without_pyramid`).
%   * label, level (the index), chunk_grid, n_chunks_stored,
%     chunk_index_origin are not carried: each is derivable (from the dimensions and
%     the series) or was a write-time aid. subject_id and source_file_id are
%     not carried either -- the owner observation names the subject.
%
%   ---------------------------------------------------------------------
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess
%   Haley, 2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md)
%   ---------------------------------------------------------------------
%   v1_to_v2 hands this migrator the document exactly as v1 wrote it
%   (`lightsheetZarrLevel`, data/lightsheetZarrLevel.json at the locked
%   NDI-matlab `main` 3cb19a8, as makePyramid.m makeOneLevel writes it). The
%   block is read in either spelling (`lightsheetZarrLevel`, else the renamed
%   `lightsheet_zarr_level`); its fields, edges and `files` are spelled the same
%   on both paths, so the conversion is unchanged. The fields listed as not
%   carried above (and `dtype`, which only checks byte_order here: the
%   pyramid's observation states the data type; and an empty `codec_params`)
%   are the round trip's known findings
%   (did2.convert.roundtrip.lightsheetZarrLevel; testRawV1RoundTripLightsheet).
%   What the renamed path would have discarded is carried, carry-100; a field,
%   block or edge outside the template carries the document whole as v1
%   (private/jRawAccount, jRawCarry; [fields outside the template are
%   malformed], carry-100). Every carry returns the untouched v1 source.
%
%   STATUS: NEVER RUN LOCALLY. There is no MATLAB in the authoring container;
%   tests/+did2/+unittest/testMigratorsJLightsheet.m is the evidence, in CI.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above). SRC is the untouched source: every
% carry returns it.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'lightsheetZarrLevel', {{'label', 'level', 'reduction_function', 'axes_order', ...
        'shape', 'chunks', 'chunk_grid', 'n_chunks_stored', 'chunk_index_origin', ...
        'chunk_order', 'dtype', 'fill_value', 'byte_order', 'codec', ...
        'codec_params', 'voxel_size', 'voxel_size_units', 'translation'}}, ...
    'files', {{'file_list', 'file_series', 'file_info', 'series_info'}}), ...
    {'^lightsheetZarrPyramid_id$', '^subject_id$', '^source_file_id$'});
if jRawCarry('lightsheet_zarr_level', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

blk = block(preBody, 'lightsheetZarrLevel');
if isempty(fieldnames(blk))
    blk = block(preBody, 'lightsheet_zarr_level');   % the renamed spelling
end
[files, nHeld] = mapChunkFiles(preBody);
nStored = double(field(blk, 'n_chunks_stored', 0));

if nHeld == 0
    if nStored > 0
        % The writer sets n_chunks_stored only when it attached the series, so
        % a count with no file is a document that LOST its bytes. Folding it to
        % nothing would hide that; quarantining it says so.
        error('did2:migrators_j:lightsheet:chunksDeclaredButAbsent', ...
            ['lightsheetZarrLevel %s says n_chunks_stored = %d but carries no ' ...
             'chunk.bin file: its bytes are missing, not absent by design.'], ...
            baseId(preBody), nStored);
    end
end

% [compression block and empty levels] (1) (Jess Haley, 2026-10-26): the
% codec's settings go in the `{term, parameters}` compression block once the
% loaded schema declares it (did2.build.compressionBlockDeclared). Until then,
% or when the block would not read back as the level's codec and codec_params,
% a level whose settings go beyond the codec name is carried whole as v1.
codec = strtrim(char(field(blk, 'codec', 'raw')));
codecParams = field(blk, 'codec_params', '');
extraSettings = codecSettingsBeyondName(codec, codecParams);
spelling = compressionOf(codec);   % '' for 'raw'
compression = spelling;
why = '';
if ~isempty(spelling) && did2.build.compressionBlockDeclared()
    [compression, why] = compressionBlock(codec, codecParams);
elseif ~isempty(extraSettings)
    compression = [];
    why = 'the loaded schema types data_body.compression as char (the codec name only)';
end
if isempty(compression) && (~isempty(spelling) || ~isempty(extraSettings))
    if isempty(extraSettings); extraSettings = {'codec'}; end
    % carry-register: carry-010
    did2.convert.reportNote('carried_as_v1', 'lightsheet_zarr_level', baseId(preBody), ...
        ['[carry-010] unplaced: lightsheet_zarr_level.codec_params (' ...
         strjoin(extraSettings, ', ') '): ' why]);
    bodies = {src};   % the untouched source
    return;
end

% [light-sheet level label is a note] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): the v1 `label` (makePyramid.m
% makeOneLevel builds it as "<entry name> level <N> (<reduction>)") is written
% UNCHANGED to the level body's `notes` ([one free-text field: notes]) as
% display text V2 code does not read; no
% level-number field is added; the round trip takes the level number from the
% label. A level whose label does not follow that pattern (or states another
% level or reduction than the document) is carried whole as v1, malformed. An
% empty label states nothing only for level 0, the measurement, whose number
% `redundant` already gives. Supersedes [light-sheet level fields rebuild from
% the pyramid]. The register row(s): carry-115.
levelLabel = char(field(blk, 'label', ''));
labelWhy = levelLabelMismatch(levelLabel, double(field(blk, 'level', 0)), ...
    char(field(blk, 'reduction_function', '')));
if ~isempty(labelWhy)
    % carry-register: carry-115
    did2.convert.reportNote('carried_as_v1', 'lightsheet_zarr_level', baseId(preBody), ...
        sprintf('[carry-115] malformed: lightsheet_zarr_level.label %s ([light-sheet level label is a note])', ...
        labelWhy));
    bodies = {src};   % the untouched source
    return;
end

[~, sessionId, created] = baseOf(preBody);
ownerId = depValue(preBody, 'lightsheetZarrPyramid_id');
if isempty(ownerId) && nHeld == 0
    % no bytes and no pyramid: no observation to own a file-less body either
    % carry-register: carry-037
    did2.convert.reportNote('carried_as_v1', 'lightsheet_zarr_level', baseId(preBody), ...
        '[carry-037] unplaced: a level holding no bytes that names no lightsheetZarrPyramid_id');
    bodies = {src};   % the untouched source
    return;
end
if isempty(ownerId)
    error('did2:migrators_j:lightsheet:noPyramid', ...
        ['lightsheetZarrLevel %s holds bytes but names no pyramid ' ...
         '(lightsheetZarrPyramid_id): there is no observation to own them.'], ...
        baseId(preBody));
end

rawDtype = char(field(blk, 'dtype', ''));
[dataType, ~, typeOrder] = jDatumType(rawDtype);
byteOrder = char(field(blk, 'byte_order', ''));
if ~isempty(typeOrder) && ~isempty(byteOrder) && ~strcmpi(typeOrder, byteOrder)
    error('did2:migrators_j:lightsheet:byteOrderConflict', ...
        'lightsheetZarrLevel %s: dtype "%s" says %s-endian, byte_order says "%s".', ...
        baseId(preBody), rawDtype, typeOrder, byteOrder);
end
if isempty(byteOrder); byteOrder = typeOrder; end
if any(strcmp(dataType, {'uint8', 'int8', 'bool'}))
    byteOrder = '';   % meaningless for one-byte data (sampled_body.byte_order)
end

axesOrder = char(field(blk, 'axes_order', ''));
units = repmat({''}, 1, numel(axesOrder));
for k = 1:numel(axesOrder)
    if any(axesOrder(k) == 'zyx')
        units{k} = char(field(blk, 'voxel_size_units', ''));
    end
end
[dims, covs] = jLightsheetAxes(axesOrder, field(blk, 'shape', []), ...
    field(blk, 'voxel_size', []), field(blk, 'translation', []), ...
    units, {}, field(blk, 'chunks', []));

% Level 0 is the measurement and every other level is `redundant` (#73 L1).
% Read off `level`, NOT off reduction_function: the writer stamps 'none' only on
% a level SHARED by several reductions (makePyramid.m: `numel(rlist) > 1`), so a
% store ingested with one reduction gets its level 0 stamped 'mean' or 'max'.
reduction = lower(strtrim(char(field(blk, 'reduction_function', 'none'))));
isMeasurement = double(field(blk, 'level', 0)) == 0;

opts = {'DatumOrder', char(field(blk, 'chunk_order', 'C')), ...
        'FillValue', fillLiteral(field(blk, 'fill_value', [])), ...
        'SessionId', sessionId, 'CreationTimestamp', created, ...
        'Id', baseId(preBody), ...   % the level's own id (point 11)
        'Validate', false};
if ~isempty(byteOrder)
    opts = [opts, {'ByteOrder', byteOrder}];
end
if ~isempty(compression)
    % a spelling (char schema) or the block (did2.build.compression either way)
    opts = [opts, {'Compression', compression}];
end
if ~isMeasurement
    opts = [opts, {'Fields', struct('redundant', true)}];
    if ~strcmp(reduction, 'none')
        opts = [opts, {'Conditions', did2.build.condition('summary statistic', ...
            'Term', statisticName(reduction))}];
    end
end

if ~isempty(levelLabel)
    % [light-sheet level label is a note]: the label, unchanged
    opts = [opts, {'Notes', levelLabel}];
elseif nHeld == 0
    % a level holding no bytes (materializeChunks off, the writer's default)
    % and no label: did2.convert.roundtrip.lightsheetZarrLevel reads this
    % sentence as no label
    opts = [opts, {'Notes', ['a pyramid level holding no bytes: no ' ...
        'chunk data is stored for it']}];
end
body = did2.build.sampledBody(ownerId, dims, 'Covariates', covs, opts{:});
if nHeld == 0
    % NO FILE: the builder defaults to one member; this body has none
    % (lightsheet_zarr_pyramid.m sourcelessStoreBody)
    if isfield(body, 'files'); body = rmfield(body, 'files'); end
else
    body.files = files;      % the level's own files, renamed (see header)
end
bodies = {body};
end

function why = levelLabelMismatch(label, level, reduction)
%LEVELLABELMISMATCH '' when LABEL is what makePyramid.m makeOneLevel writes for
%   LEVEL and REDUCTION ("<entry name> level <N> (<reduction>)"), else why not.
%   An empty label is '' only for level 0 (the measurement: the round trip
%   reads its number from `redundant`).
why = '';
if isempty(strtrim(label))
    if level ~= 0
        why = sprintf('is empty, so the level number %g is stated nowhere else', level);
    end
    return;
end
tok = regexp(label, '^.* level (\d+) \(([^()]*)\)$', 'tokens', 'once');
if isempty(tok)
    why = sprintf('"%s" does not follow "<entry name> level <N> (<reduction>)"', label);
elseif str2double(tok{1}) ~= level
    why = sprintf('"%s" names level %s, the document level %g', label, tok{1}, level);
elseif ~isempty(reduction) && ~strcmp(tok{2}, reduction)
    why = sprintf('"%s" names reduction "%s", the document "%s"', label, tok{2}, reduction);
end
end

function keys = codecSettingsBeyondName(codec, params)
%CODECSETTINGSBEYONDNAME The codec_params keys that say more than the codec's
%   name ({} when none). The writer stamps '{}' for 'raw' and, for
%   'blosc-zstd', '{"cname":"zstd","clevel":<n>,"shuffle":1,"blocksize":0}'
%   (NDI makePyramid.m codecParamsJSON). `cname` restates the codec only when
%   the codec names it ('blosc-zstd' and "zstd"); every other key with a value
%   is a write-time setting. Text that is not a JSON object is itself unplaced.
keys = {};
if isempty(params)
    return;
end
p = params;
if ischar(p) || isstring(p)
    p = strtrim(char(p));
    if isempty(p); return; end
    try
        p = jsondecode(p);
    catch
        keys = {'(not JSON)'};
        return;
    end
end
if isempty(p)
    return;
end
if ~isstruct(p) || ~isscalar(p)
    keys = {'(not one JSON object)'};
    return;
end
fns = fieldnames(p);
named = lower(strtrim(codec));
for k = 1:numel(fns)
    v = p.(fns{k});
    if isempty(v); continue; end
    if strcmp(fns{k}, 'cname') && (ischar(v) || isstring(v)) ...
            && endsWith(named, ['-' lower(char(v))])
        continue;   % the inner compressor the codec's own name states
    end
    keys{end+1} = fns{k}; %#ok<AGROW>
end
end

% ===================== helpers =============================================

function t = statisticName(reduction)
% The writer's reduction labels -> the `summary statistic` condition's term
% (L1: "summary statistic: mean|maximum"), with its NCIT node (point 10, Jess
% 2026-10-14, checked on OLS): max -> NCIT:C25564 'Maximum', mean ->
% NCIT:C53319 'Arithmetic Mean'. Any other label stays NAME-ONLY, as given,
% rather than guessed at. The variable 'summary statistic' itself is a name
% with no node (term worksheet).
arguments
    reduction {mustBeText}
end

switch reduction
    case 'max';  t = struct('node', 'NCIT:C25564', 'name', 'Maximum');
    case 'mean'; t = struct('node', 'NCIT:C53319', 'name', 'Arithmetic Mean');
    case 'min';  t = struct('node', '', 'name', 'minimum');
    otherwise;   t = struct('node', '', 'name', reduction);
end
end

function [c, why] = compressionBlock(codec, params)
%COMPRESSIONBLOCK The `{term, parameters}` compression block of a level whose
%   codec is CODEC and codec_params PARAMS (JSON text), or [] with WHY when it
%   cannot be written losslessly: did2.build.compressionCodec must read it back
%   as CODEC and the same settings, in the same order ([lossless means round
%   trip]; [compression block and empty levels] (1), Jess Haley, 2026-10-26).
arguments
    codec {mustBeText}
    params % the v1 codec_params: JSON text, or empty
end

c = [];
why = '';
try
    settings = struct();
    if ~isempty(params)
        p = params;
        if ischar(p) || isstring(p)
            p = strtrim(char(p));
            if ~isempty(p); p = jsondecode(p); end
        end
        if ~isempty(p)
            if ~isstruct(p) || ~isscalar(p)
                why = 'codec_params is not one JSON object';
                return;
            end
            settings = p;
        end
    end
    block = did2.build.compression(codec, 'Settings', settings);
    [back, backSettings] = did2.build.compressionCodec(block);
    if ~strcmp(back, codec) || ~isequal(fieldnames(backSettings), fieldnames(settings)) ...
            || ~isequaln(backSettings, settings)
        why = sprintf(['the compression block reads back as codec "%s" with settings ' ...
            '%s, not "%s" %s'], back, jsonencode(backSettings), codec, jsonencode(settings));
        return;
    end
    c = block;
catch ME
    c = [];
    why = sprintf('the compression block could not be built (%s: %s)', ME.identifier, ME.message);
end
end

function c = compressionOf(codec)
arguments
    codec {mustBeText}
end

% the codec name verbatim ([lossless means round trip]: 'blosc-zstd' written
% as 'blosc' could not be read back); 'raw' is no compression
if any(strcmpi(strtrim(codec), {'', 'raw'}))
    c = '';
else
    c = strtrim(char(codec));
end
end

function s = fillLiteral(v)
% sampled_body.fill_value is "ONE value, written as a literal read according
% to the owner's data_type". The writer stores a number (always 0).
arguments
    v % the v1 fill_value: empty, text or a number
end

s = '';
if isempty(v); return; end
if ischar(v) || isstring(v)
    s = char(v);
elseif isnan(v)
    s = 'NaN';
else
    s = num2str(double(v), 17);
end
end

function [files, nHeld] = mapChunkFiles(body)
%MAPCHUNKFILES chunk.bin -> body_data, chunk.bin_k -> body_data_{k-1}.
%   NHELD counts the file entries that carry bytes or a manifest of them:
%   file_info entries named chunk.bin / chunk.bin_k, plus series_info entries
%   for chunk.bin. The declared `file_list` / `file_series` are the CLASS's
%   list (the template carries 'chunk.bin' whether or not anything was
%   attached), so they are renamed but never counted.
arguments
    body (1,1) struct
end

files = struct();
nHeld = 0;
if ~isfield(body, 'files') || ~isstruct(body.files) || ~isscalar(body.files)
    return;
end
files = body.files;
if isfield(files, 'file_info') && isstruct(files.file_info)
    for k = 1:numel(files.file_info)
        if ~isfield(files.file_info(k), 'name'); continue; end
        [newName, isChunk] = renameChunk(files.file_info(k).name);
        if isChunk
            files.file_info(k).name = newName;
            nHeld = nHeld + 1;
        end
    end
end
if isfield(files, 'series_info') && isstruct(files.series_info)
    for k = 1:numel(files.series_info)
        if ~isfield(files.series_info(k), 'name'); continue; end
        [newName, isChunk] = renameChunk(files.series_info(k).name);
        if isChunk
            files.series_info(k).name = newName;
            nHeld = nHeld + 1;
            % A not-yet-stripped ingest record names members by NUMBER
            % (NAME_<index>): v1 counts from 1, V_eta from 0, same slots.
            if isfield(files.series_info(k), 'ingest_locations') ...
                    && isstruct(files.series_info(k).ingest_locations) ...
                    && isfield(files.series_info(k).ingest_locations, 'index')
                for j = 1:numel(files.series_info(k).ingest_locations)
                    files.series_info(k).ingest_locations(j).index = ...
                        double(files.series_info(k).ingest_locations(j).index) - 1;
                end
            end
        end
    end
end
for f = {'file_list', 'file_series'}
    if ~isfield(files, f{1}); continue; end
    list = files.(f{1});
    if ischar(list); list = {list}; end
    if ~iscell(list); continue; end
    for k = 1:numel(list)
        list{k} = renameChunk(list{k});
    end
    files.(f{1}) = list;
end
end

function [out, isChunk] = renameChunk(name)
arguments
    name % a file name as the v1 document stores it; char() below
end

name = char(name);
out = name;
isChunk = false;
if strcmp(name, 'chunk.bin')
    out = 'body_data';
    isChunk = true;
    return;
end
tok = regexp(name, '^chunk\.bin_(\d+)$', 'tokens', 'once');
if ~isempty(tok)
    k = str2double(tok{1});
    if k < 1
        error('did2:migrators_j:lightsheet:badMember', ...
            'chunk.bin members are numbered from 1 (chunk_index_origin); got "%s".', name);
    end
    out = sprintf('body_data_%d', k - 1);
    isChunk = true;
end
end

function b = block(body, name)
arguments
    body (1,1) struct
    name {mustBeText}
end

b = struct();
if isfield(body, name) && isstruct(body.(name)) && isscalar(body.(name))
    b = body.(name);
end
end

function v = field(s, name, default)
arguments
    s (1,1) struct
    name {mustBeText}
    default
end

v = default;
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end

function id = baseId(body)
arguments
    body (1,1) struct
end

id = '';
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, 'id')
    id = char(body.base.id);
end
end

function [id, sessionId, created] = baseOf(body)
arguments
    body (1,1) struct
end

id = ''; sessionId = ''; created = '';
if isfield(body, 'base') && isstruct(body.base)
    b = body.base;
    if isfield(b, 'id'); id = char(b.id); end
    if isfield(b, 'session_id'); sessionId = char(b.session_id); end
    if isfield(b, 'creation_timestamp') && ~isempty(b.creation_timestamp)
        created = char(b.creation_timestamp);
    elseif isfield(b, 'datestamp') && ~isempty(b.datestamp)
        created = char(b.datestamp);
    end
end
end

function v = depValue(body, name)
arguments
    body (1,1) struct
    name {mustBeText}
end

v = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on); return; end
for k = 1:numel(body.depends_on)
    e = body.depends_on(k);
    if ~isfield(e, 'name') || ~strcmp(e.name, name); continue; end
    if isfield(e, 'document_id') && ~isempty(e.document_id)
        v = char(e.document_id);
    elseif isfield(e, 'value') && ~isempty(e.value)
        v = char(e.value);
    end
    return;
end
end
