function [v1, spec] = lightsheetZarrLevel(bodies)
%LIGHTSHEETZARRLEVEL Rebuild a v1 `lightsheetZarrLevel` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.lightsheetZarrLevel(BODIES). V1 is the
%   document in NDI's v1 shape (data/lightsheetZarrLevel.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+fun/+doc/+lightsheet/makePyramid.m
%   makeOneLevel writes it). BODIES is the one `sampled_body` pass 1
%   (did2.convert.migrators_j.lightsheet_zarr_level) emitted for it, its id
%   the level's:
%
%     base.id, session_id, datestamp     the body (rebuildBase)
%     depends_on lightsheetZarrPyramid_id  its owner_id
%     axes_order, shape, chunks,         its dimensions and covariates
%     voxel_size, translation,           (private/lightsheetFrame; the channel
%     voxel_size_units                   axis's voxel size 1 and translation 0
%                                        are NGFF's defaults, which
%                                        jLightsheetAxes did not write)
%     chunk_grid                         restated: ceil(shape ./ chunks)
%     level                              0 for the measurement (not
%                                        `redundant`); a reduced level's index
%                                        is not kept (a known finding)
%     reduction_function                 the `summary statistic` condition
%                                        (Maximum -> max, Arithmetic Mean ->
%                                        mean), 'none' without one
%     chunk_order                        datum_order
%     fill_value                         fill_value, the literal read back
%     byte_order                         byte_order
%     codec                              compression, 'raw' without one
%     codec_params                       '{}' with no compression (the writer's
%                                        empty settings; a level with settings
%                                        beyond the codec name is carried)
%     n_chunks_stored                    the members the body holds (the series
%                                        manifest's count, else the named
%                                        members), 0 for a file-less body
%     chunk_index_origin                 1: v1 numbers members from 1, and the
%                                        migrator renamed chunk.bin_k to
%                                        body_data_{k-1}
%     files                              body_data -> chunk.bin and
%                                        body_data_k -> chunk.bin_{k+1}, the
%                                        series' ingest_locations back to
%                                        1-based; a file-less body: the
%                                        template's file_list / file_series
%                                        `chunk.bin`
%   NOT REBUILT (known findings, the migrator's header): label, a reduced
%   level's index, dtype (the pyramid's observation states it), and the
%   subject_id and source_file_id edges (the owner observation names the
%   subject; the pyramid names the store).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.lightsheet_zarr_level.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
if ~isscalar(bodies) || ~strcmp(classNameOf(bodies{1}), 'sampled_body')
    spec.unplaced{end+1} = sprintf(['%d emitted document(s); pass 1 makes one ' ...
        'sampled_body of a lightsheet level'], numel(bodies));
    return;
end
b = bodies{1};
base = rebuildBase(b);

f = lightsheetFrame(findField(b, 'dimensions'), findField(b, 'covariates'));
spec.unplaced = [spec.unplaced, f.bad];

blk = struct();
redundant = findField(b, 'redundant');
isMeasurement = isempty(redundant) || ~logical(firstOf(redundant));
if isMeasurement
    blk.level = 0;
end
blk.reduction_function = reductionOf(findField(b, 'conditions'));
blk.axes_order = f.axes_order;
blk.shape = f.shape;
blk.chunks = f.chunks;
if ~isempty(f.chunks)
    blk.chunk_grid = ceil(f.shape ./ f.chunks);
end
[files, nStored] = v1Files(b);
blk.n_chunks_stored = nStored;
blk.chunk_index_origin = 1;
blk.chunk_order = textOf(findField(b, 'datum_order'));
blk.fill_value = fillOf(findField(b, 'fill_value'));
blk.byte_order = textOf(findField(b, 'byte_order'));
codec = textOf(findField(b, 'compression'));
if isempty(codec)
    blk.codec = 'raw';
    blk.codec_params = '{}';
else
    blk.codec = codec;
end
blk.voxel_size = f.scale;
space = find(ismember(f.axes_order, 'zyx'), 1);
if ~isempty(space)
    blk.voxel_size_units = f.units{space};
end
blk.translation = f.translation;

v1.document_class = struct('class_name', 'lightsheetZarrLevel');
v1.depends_on = struct('name', {'lightsheetZarrPyramid_id', 'subject_id', 'source_file_id'}, ...
    'value', {oneId(edgeIds(b, 'owner_id')), '', ''});
v1.base = base;
v1.files = files;
v1.lightsheetZarrLevel = blk;
end

% ===================== helpers =============================================

function [files, nStored] = v1Files(b)
% the level's v1 `files`, the migrator's renaming undone (mapChunkFiles)
nStored = 0;
if ~isfield(b, 'files') || ~isstruct(b.files) || ~isscalar(b.files)
    files = struct('file_list', {{'chunk.bin'}}, 'file_series', {{'chunk.bin'}});
    return;
end
files = b.files;
named = 0;
manifestCount = [];
if isfield(files, 'file_info') && isstruct(files.file_info)
    for k = 1:numel(files.file_info)
        if ~isfield(files.file_info(k), 'name'); continue; end
        [files.file_info(k).name, isMember] = undoName(files.file_info(k).name);
        named = named + double(isMember);
    end
end
if isfield(files, 'series_info') && isstruct(files.series_info)
    for k = 1:numel(files.series_info)
        if ~isfield(files.series_info(k), 'name'); continue; end
        files.series_info(k).name = undoName(files.series_info(k).name);
        if isfield(files.series_info(k), 'count') && ~isempty(files.series_info(k).count)
            manifestCount = double(files.series_info(k).count);
        end
        if isfield(files.series_info(k), 'ingest_locations') ...
                && isstruct(files.series_info(k).ingest_locations) ...
                && isfield(files.series_info(k).ingest_locations, 'index')
            for j = 1:numel(files.series_info(k).ingest_locations)
                files.series_info(k).ingest_locations(j).index = ...
                    double(files.series_info(k).ingest_locations(j).index) + 1;
            end
        end
    end
end
for fl = {'file_list', 'file_series'}
    if ~isfield(files, fl{1}); continue; end
    list = files.(fl{1});
    if ischar(list); list = {list}; end
    if iscell(list)
        for k = 1:numel(list)
            list{k} = undoName(list{k});
        end
        files.(fl{1}) = list;
    end
end
if ~isempty(manifestCount)
    nStored = manifestCount;
else
    nStored = named;
end
end

function [out, isMember] = undoName(name)
name = char(name);
out = name;
isMember = false;
if strcmp(name, 'body_data')
    out = 'chunk.bin';
    return;   % the manifest: its members are counted by the series record
end
tok = regexp(name, '^body_data_(\d+)$', 'tokens', 'once');
if ~isempty(tok)
    out = sprintf('chunk.bin_%d', str2double(tok{1}) + 1);
    isMember = true;
end
end

function r = reductionOf(conditions)
r = 'none';
list = asCell(conditions);
for i = 1:numel(list)
    c = list{i};
    [~, vname] = termParts(getIn(c, 'variable'));
    if ~strcmpi(vname, 'summary statistic'); continue; end
    [node, name] = termParts(getIn(c, 'term'));
    switch node
        case 'NCIT:C25564'; r = 'max';
        case 'NCIT:C53319'; r = 'mean';
        otherwise
            switch lower(name)
                case 'maximum';         r = 'max';
                case 'arithmetic mean'; r = 'mean';
                case '';                r = 'none';
                otherwise;              r = lower(name);
            end
    end
    return;
end
end

function v = fillOf(x)
v = [];
x = firstOf(x);
if ischar(x) || (isstring(x) && isscalar(x))
    v = str2double(x);
elseif isnumeric(x) && ~isempty(x)
    v = double(x(1));
end
end

function s = oneId(ids)
s = '';
if ~isempty(ids); s = ids{1}; end
end

function s = textOf(x)
s = '';
x = firstOf(x);
if ischar(x) || (isstring(x) && isscalar(x))
    s = char(x);
end
end
