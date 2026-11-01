function [v1, spec] = lightsheetZarrPyramid(bodies)
%LIGHTSHEETZARRPYRAMID Rebuild a v1 `lightsheetZarrPyramid` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.lightsheetZarrPyramid(BODIES). V1 is
%   the document in NDI's v1 shape (data/lightsheetZarrPyramid.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+fun/+doc/+lightsheet/
%   makePyramid.m writes it). BODIES is what pass 1
%   (did2.convert.migrators_j.lightsheet_zarr_pyramid) emitted for it, before
%   the batch pass: the `observation` (id preserved), the `software` entity,
%   the version assertion about it (when pipeline_version is set), and, for a
%   pyramid that names no source file, its file-less store `opaque_body`:
%
%     base.id, session_id, datestamp     the observation (rebuildBase)
%     depends_on subject_id              the observation's entity_id
%     depends_on element_id              its instrument_id
%     depends_on source_file_id          its transient source_file_id edge
%     label                              its notes, before the store-body
%                                        separator
%     pyramid_name, pyramid_type         'NGFF multiscales name "..."' / 'type'
%                                        in the notes tail, or in the file-less
%                                        store body's notes
%     axes_order, shape_level0,          its full-resolution dimensions and
%     voxel_size_level0,                 covariates (private/lightsheetFrame;
%     translation_level0, axes_units,    the channel axis's voxel size 1 and
%     channel_names                      translation 0 are NGFF's defaults,
%                                        which jLightsheetAxes did not write)
%     n_channels                         the channel dimension's size
%     voxel_size_units                   the unit of the first space axis
%     dtype                              value.source_data_type, else
%                                        value.data_type
%     pipeline_version                   the version assertion's text
%     byte_order                         NOT REBUILT: the pyramid's documents do
%                                        not state it (the levels' sampled
%                                        bodies do); a known finding
%
%   Anything emitted that is not one of the documents above is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.lightsheet_zarr_pyramid.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
n = numel(bodies);
used = false(1, n);
obs = [];
for k = 1:n
    if strcmp(classNameOf(bodies{k}), 'observation')
        obs = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(obs)
    spec.unplaced{end+1} = 'no observation was emitted';
    return;
end
base = rebuildBase(obs);
obsId = base.id;

% ---- the software entity and its version ------------------------------------
pipelineVersion = '';
sw = edgeIds(obs, 'software_id');
if numel(sw) ~= 1
    spec.unplaced{end+1} = sprintf('the observation names %d software entities, not one', numel(sw));
else
    for k = 1:n
        if ~used(k) && strcmp(char(getIn(bodies{k}, 'base', 'id')), sw{1})
            used(k) = true;
        end
    end
    for k = 1:n
        if ~used(k) && strcmp(classNameOf(bodies{k}), 'assertion') ...
                && isequal(edgeIds(bodies{k}, 'entity_id'), sw)
            [~, value] = statementValue(bodies{k});
            pipelineVersion = firstText(value);
            used(k) = true;
        end
    end
end

% ---- the notes: the label, then the store body's text ---------------------
notes = textOf(findField(obs, 'notes'));
label = notes;
tail = '';
SEPARATOR = sprintf('\n-- store body: ');
at = strfind(notes, SEPARATOR);
if ~isempty(at)
    label = notes(1:at(end) - 1);
    tail = notes(at(end) + numel(SEPARATOR):end);
end
% a pyramid with no source file: its own file-less store body carries the text
for k = 1:n
    if ~used(k) && strcmp(classNameOf(bodies{k}), 'opaque_body') ...
            && isequal(edgeIds(bodies{k}, 'owner_id'), {obsId})
        used(k) = true;
        tail = [tail '; ' textOf(findField(bodies{k}, 'notes'))]; %#ok<AGROW>
    end
end

% ---- the axes ---------------------------------------------------------------
f = lightsheetFrame(findField(obs, 'dimensions'), findField(obs, 'covariates'));
spec.unplaced = [spec.unplaced, f.bad];

blk = struct();
blk.label = label;
blk.pyramid_name = quoted(tail, 'NGFF multiscales name');
blk.pyramid_type = quoted(tail, 'NGFF multiscales type');
blk.axes_order = f.axes_order;
blk.axes_units = strjoin(f.units, ',');
blk.channel_names = f.channel_names;
c = find(f.axes_order == 'c', 1);
if ~isempty(c)
    blk.n_channels = f.shape(c);
end
blk.shape_level0 = f.shape;
blk.voxel_size_level0 = f.scale;
space = find(ismember(f.axes_order, 'zyx'), 1);
if ~isempty(space)
    blk.voxel_size_units = f.units{space};
end
blk.translation_level0 = f.translation;
dtype = textOf(findField(obs, 'source_data_type'));
if isempty(dtype)
    dtype = textOf(findField(obs, 'data_type'));
end
blk.dtype = dtype;
blk.pipeline_version = pipelineVersion;

v1.document_class = struct('class_name', 'lightsheetZarrPyramid');
v1.depends_on = struct('name', {'subject_id', 'element_id', 'source_file_id'}, ...
    'value', {oneId(edgeIds(obs, 'entity_id')), oneId(edgeIds(obs, 'instrument_id')), ...
        oneId(edgeIds(obs, 'source_file_id'))});
v1.base = base;
v1.lightsheetZarrPyramid = blk;

for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a lightsheet pyramid', ...
        k, classNameOf(bodies{k}));
end
end

% ===================== helpers =============================================

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

function s = firstText(x)
% the first text anywhere in a statement's value (a text value's one entry)
s = '';
if ischar(x) || (isstring(x) && isscalar(x))
    s = char(x);
elseif iscell(x)
    for k = 1:numel(x)
        s = firstText(x{k});
        if ~isempty(s); return; end
    end
elseif isstruct(x)
    for k = 1:numel(x)
        fns = fieldnames(x(k));
        for j = 1:numel(fns)
            s = firstText(x(k).(fns{j}));
            if ~isempty(s); return; end
        end
    end
end
end

function s = quoted(text, label)
s = '';
tok = regexp(text, [regexptranslate('escape', label) ' "([^"]*)"'], 'tokens', 'once');
if ~isempty(tok)
    s = tok{1};
end
end
