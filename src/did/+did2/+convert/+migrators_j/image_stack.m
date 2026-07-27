function bodies = image_stack(preBody)
%IMAGE_STACK Brainstorm-J migrator: did_v1 image_stack -> a body-backed
%   image_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   image_stack / image_stack_parameters are a pre-Brainstorm-I standalone image
%   document (a file-backed pixel blob + geometry bundle tied to a subject). It
%   is the main did_v1 class exercising J's new storage model (§C.4; 7,007 docs
%   in the JH corpus). Strict J has NO imageseries_observation class (§A.9): the
%   discoverable subject-side view is a plain `subject_observation` data-type
%   leaf whose value is body-backed --
%
%       image_observation   the spine handle: subject_id, a shared time anchor, a
%                           placeholder `subject_statement.variable` (the observed
%                           quantity is the linked ontology label, set by a
%                           second-pass join -- see V_eta_discovery_notes.md; NOT
%                           the file format), the inline image geometry on the
%                           `image` mixin, and `storage_mode: body` (so the
%                           statement carries no sample_time -- the cadence lives
%                           in the body, D1/§A.7). The prose `label` and the
%                           `format_ontology` file-type are dropped as derivable.
%       sampled_body        the DIGITAL frames: datum (kind/dtype/unit/shape) +
%                           sample_time (t0/dt/n) + the carried pixel bytes;
%                           `statement` -> the image_observation it belongs to.
%       session_relative_reference   the ordinal 'during' anchor (a v1 image
%                           stack carries a bare timestamp+clocktype, not a DAQ
%                           epoch -- the same honest fallback the treatment fold
%                           uses).
%
%   1 -> 3. The V_zeta `_i` fold also minted an element / element_epoch /
%   daqreader / ingested-frames quartet; in J the element_epoch + ingested pair
%   collapses into the one `sampled_body`, and the NDI-side imaging element /
%   daqreader infrastructure is left to the NDI second pass (D2: pass-1 migrators
%   populate no individuated element referent). The legacy `document_id`
%   dependency (a corpus reference-integrity orphan) is dropped.
%
%   NOTE: image_observation and the *_body classes are `draft` in V_eta -- the
%   broader imageseries/dataseries/timeseries_observation branch this supersedes
%   is retired with the NDI-side ingest work, not here.

arguments
    preBody (1,1) struct
end

TV = 'V_eta';
params = getBlock(preBody, 'image_stack_parameters');

subjectId = dependencyValue(preBody, 'subject_id');
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
stackId   = baseField(preBody, 'id', did.ido.unique_id());

% format_ontology is the FILE TYPE (an NCIT file-format CURIE like TIFF / MP4).
% It is NOT the observed quantity, and it is NOT stored: a file's container format
% is derivable from the bytes themselves (and the short form already rides on
% image.image_format), so an ontology term for it would be a redundant projection.
dataType = getCharField(params, 'data_type');
dimOrder = firstNonEmpty(getCharField(params, 'dimension_order'), 'YXCZT');
dimSize  = numVec(getField(params, 'dimension_size'));
[clockName, t0] = clockFromParams(params);
numFrames = frameCount(dimOrder, dimSize);

anchorId = did.ido.unique_id();

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});   % session rides on base
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable, body-backed image_observation ------------------------
obs = struct();
obs.document_class = classBlock('image_observation', {'subject_observation', 'image'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
% The source `label` is NOT carried: it is a templated prose *definition* of the
% image type (e.g. "A video recording capturing the behavior of C. elegans...")
% -- i.e. the definition of the modality ontology term that already rides on
% subject_statement.variable (from format_ontology). Storing it per-document
% would duplicate the ontology term's definition; it is reconstructable as a
% projection. base.name is a short generic name.
obs.base = struct('id', stackId, 'session_id', sessionId, ...
    'name', 'migrated_image', 'datestamp', datestamp);
% storage_mode: body -> the value is in the sampled_body; the statement carries
% no sample_time (the body owns the cadence).
% variable is the OBSERVED QUANTITY. On the source that is the linked ontology
% label (via the image's document_id), not the file format -- resolving it is a
% second-pass cross-document join (discovery; see V_eta_discovery_notes.md). A
% non-empty placeholder is emitted here so the statement validates; the second
% pass replaces it with the label's ontology term.
obs.subject_statement = struct('variable', struct('node', '', 'name', 'image'), ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
% The raster CELL: one `value` slot holding the pixels plus the descriptors needed to
% interpret them (image now matches the single-`value` convention every other data_type
% follows -- the descriptors ride inside the cell, as `source_unit` does beside
% `source_value` in a dimensioned cell). R6 decision 4 is unchanged: dtype is NOT
% recoverable from an inline matrix, so it is always explicit -- just one level in.
% dtype from the v1 data_type; axes from dimension_order/size/scale (recovers the N-D
% calibration the old x/y_resolution lost); pixels empty (they live in the sampled_body,
% storage_mode:body).
% NOTE: wrap the axes struct-array in a 1x1 cell so struct() ASSIGNS it as a field (a
% non-scalar struct value would otherwise distribute the cell into an array), and assign
% the cell onto obs.image in its own statement for the same reason.
imageCell = struct( ...
    'pixels', [], ...
    'dtype', firstNonEmpty(dataType, 'uint16'), ...
    'axes', {imageAxes(dimOrder, dimSize, params)}, ...
    'color_model', otTerm(''), ...
    'channels', {{}});
obs.image = struct();
obs.image.value = imageCell;

% ---- the sampled_body holding the digital frames ----------------------------
body = jSampledBody(stackId, sessionId, datestamp, 'migrated_image_frames', ...
    struct('kind', 'array', 'dtype', dataType, 'unit', '', 'shape', dimSize), ...
    struct('regular', true, ...
        't0', durationComposite(t0), 'dt', durationComposite(frameDt(clockName)), ...
        'n', numFrames));
% carry the pixel bytes over verbatim as the body's frames (universal renames
% leave file/files untouched; this doc owns the digital bytes now).
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end

bodies = {obs, body, anchor};
end

% ===================== geometry / clock builders ===========================

function r = axisResolution(params, axisChar)
%AXISRESOLUTION The scale (spacing) of the named spatial axis, 0 if absent.
r = 0.0;
order = getCharField(params, 'dimension_order');
scale = numVec(getField(params, 'dimension_scale'));
idx = strfind(upper(order), upper(axisChar));
if ~isempty(idx) && idx(1) <= numel(scale)
    r = scale(idx(1));
end
end

function [clockName, t0] = clockFromParams(params)
clockName = getCharField(params, 'clocktype');
if isempty(clockName); clockName = 'no_time'; end
t0 = 0.0;
ts = getField(params, 'timestamp');
if ~isempty(ts) && isnumeric(ts) && isscalar(ts); t0 = double(ts); end
end

function dt = frameDt(clockName)
%FRAMEDT A unit frame spacing for a clocked stack; 0 for a clockless still.
if strcmp(clockName, 'no_time'); dt = 0.0; else; dt = 1.0; end
end

function n = frameCount(dimOrder, dimSize)
n = 1;
for i = 1:min(numel(dimOrder), numel(dimSize))
    c = upper(dimOrder(i));
    if (c == 'T' || c == 'Z') && dimSize(i) > 0
        n = n * dimSize(i);
    end
end
end

% ===================== small helpers =======================================

function dc = classBlock(name, supers, tv)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', tv);
end

function c = durationComposite(seconds)
c = struct('source_unit', 's', 'source_value', double(seconds), 'approximate', false);
end

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(bodyStruct, name)
v = [];
if isfield(bodyStruct, name); v = bodyStruct.(name); end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v = numVec(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); return; end
if ischar(x) || (isstring(x) && isscalar(x))
    parts = strsplit(char(x), {',', ' '});
    for k = 1:numel(parts)
        nn = str2double(parts{k});
        if ~isnan(nn); v(end+1) = nn; end %#ok<AGROW>
    end
end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            elseif isfield(d, 'id') && ~isempty(d.id)
                v = char(d.id);
            end
            return;
        end
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

function ax = imageAxes(dimOrder, dimSize, params)
% Build the per-axis descriptor array {name, length, spacing, unit} from the v1
% dimension_order/dimension_size/dimension_scale — the N-D calibration (image model
% decision 4). Defensive: missing pieces yield empty/zero slots (declared, valid).
ax = struct('name', {}, 'length', {}, 'spacing', {}, 'unit', {});
unit = firstNonEmpty(getCharField(params, 'dimension_scale_units'), '');
n = numel(dimOrder);
for k = 1:n
    nm = dimOrder(k);
    len = 0;
    if k <= numel(dimSize); len = dimSize(k); end
    sp = axisResolution(params, nm);
    ax(end+1) = struct('name', nm, 'length', len, ...
        'spacing', sp, 'unit', unit); %#ok<AGROW>
end
end
