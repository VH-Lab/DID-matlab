function bodies = lightsheet_zarr_level(preBody)
%LIGHTSHEET_ZARR_LEVEL Brainstorm-J migrator: did_v1 lightsheetZarrLevel -> a
%   `sampled_body` of the pyramid's observation when the level HOLDS bytes, or
%   NOTHING (an empty cell) when it does not.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. An
%   empty return is counted there, per class, as `emitted_nothing_by_class`:
%   "consumed, nothing emitted" is a fact the run reports, never a silence.
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
%     keys           one per axis of axes_order, each with its `chunk`
%                       (jLightsheetKeys); the level's own shape, voxel size
%                       and translation
%     datum_order    chunk_order ('C': the chunk bytes are C-order,
%                       makePyramid.m readStoredChunk / padPermuteBytes)
%     byte_order     the level's byte_order -- or the dtype typestring's own
%                       ('<' / '>') where they disagree, which is reported by
%                       an error rather than chosen; '' for one-byte types
%     fill_value     the level's fill_value, as the literal the owner's
%                       data_type reads; complete true (a dense grid)
%     compression    'blosc' for codec 'blosc' / 'blosc-zstd'; absent for
%                       'raw'; codec_params DROPPED (L4: write-time settings;
%                       a Blosc chunk header records shuffle and typesize)
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
%   A level holding NO bytes -> nothing (L3(c)). Its id names no document after
%   migration, so an edge a dataset carries to it is an ORPHAN in the batch
%   reference check, which gates.
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
%     (hard-coded 'micrometer'), so this migrator still writes the `t` key
%     with no unit and the `c` key with index positions. The pyramid has the
%     per-axis `axes_units` and the `channel_names`; lightsheet_zarr_pyramid
%     carries them on its observation (as its full-resolution keys, transient)
%     and did2.convert.foldGenericFiles copies them onto the keys of EVERY
%     sampled_body this level's owner_id names: `t` gets its unit, `c`'s
%     positions are named by channel, and z/y/x units are CHECKED against the
%     pyramid's -- a disagreement is counted (`level_unit_disagreements`), not
%     overwritten. A level whose pyramid is not in the batch keeps its keys and
%     is counted (`level_bodies_without_pyramid`).
%   * label, level (the index), chunk_grid, n_chunks_stored,
%     chunk_index_origin are not carried: each is derivable (from the keys and
%     the series) or was a write-time aid. subject_id and source_file_id are
%     not carried either -- the owner observation names the subject.
%
%   STATUS: NEVER RUN LOCALLY. There is no MATLAB in the authoring container;
%   tests/+did2/+unittest/testMigratorsJLightsheet.m is the evidence, in CI.

arguments
    preBody (1,1) struct
end

blk = block(preBody, 'lightsheet_zarr_level');
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
    bodies = {};      % metadata only -- folds to nothing (#73 L3(c))
    return;
end

[~, sessionId, created] = baseOf(preBody);
ownerId = depValue(preBody, 'lightsheetZarrPyramid_id');
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
keys = jLightsheetKeys(axesOrder, field(blk, 'shape', []), ...
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
        'Complete', true, ...
        'SessionId', sessionId, 'CreationTimestamp', created, ...
        'Id', baseId(preBody), ...   % the level's own id (point 11)
        'Validate', false};
if ~isempty(byteOrder)
    opts = [opts, {'ByteOrder', byteOrder}];
end
compression = compressionOf(char(field(blk, 'codec', 'raw')), baseId(preBody));
if ~isempty(compression)
    opts = [opts, {'Compression', compression}];
end
if ~isMeasurement
    opts = [opts, {'Fields', struct('redundant', true)}];
    if ~strcmp(reduction, 'none')
        opts = [opts, {'Conditions', did2.build.condition('summary statistic', ...
            'Term', statisticName(reduction))}];
    end
end

body = did2.build.sampledBody(ownerId, keys, opts{:});
body.files = files;      % the level's own files, renamed (see header)
bodies = {body};
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

function c = compressionOf(codec, id)
arguments
    codec {mustBeText}
    id {mustBeText}
end

switch lower(strtrim(codec))
    case {'', 'raw'}
        c = '';
    case {'blosc', 'blosc-zstd'}
        c = 'blosc';
    case 'zstd'
        c = 'zstd';
    otherwise
        error('did2:migrators_j:lightsheet:unknownCodec', ...
            'lightsheetZarrLevel %s: codec "%s" has no compression mapping.', id, codec);
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
