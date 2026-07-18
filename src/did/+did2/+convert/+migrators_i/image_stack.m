function bodies = image_stack(preBody)
%IMAGE_STACK Brainstorm-I migrator: did_v1 image_stack -> the ingested imageseries.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_zeta'.
%   image_stack / image_stack_parameters are a pre-Brainstorm-I *standalone*
%   image document (a file-backed pixel blob + geometry bundle, tied to a
%   subject but living off the spine). V_zeta retires them (deprecated tier)
%   and folds imaging onto NDI's imaging stack: an ndi.element.image whose
%   frames, once ingested, are DIGITAL data resident in the database -- a
%   `daqreader_image_epochdata_ingested` document (frames.bin + YXCZT header),
%   exactly what ndi.daq.reader.image.ingest_epochfiles writes. The subject
%   view is the discoverable `imageseries_observation` on the spine.
%
%   The 1 -> N fold emits (all orphan-free within the batch):
%     * imageseries_observation           -- discoverable spine handle:
%           subject_id (present on the v1 doc), a shaped time_reference,
%           variable/kind = the format/modality, the caption as `label`,
%           element_id -> the element. Preserves the source base.id.
%     * element (ndi.element.image)        -- the imaging element the
%           observation is about (a v1 image_stack names no element).
%     * element_epoch                      -- the epoch document the ingested
%           data's `epochid` edge resolves to; carries the geometry (axes) and
%           the clock.
%     * daqreader_image_epochdata_ingested -- the DIGITAL ingested frames:
%           frames.bin (carried from the v1 image file) + header
%           (dimension_order/size, data_type, num_frames, frametimes,
%           clocktype). daqreader_id -> the daqreader, epochid -> element_epoch.
%     * daqreader (ndi.daq.reader.image)   -- minimal reader the ingested epoch
%           data depends on.
%     * session_relative_reference         -- the ordinal 'during' time anchor
%           (a v1 image stack carries a bare timestamp+clocktype, not a DAQ
%           epoch; same honest fallback the treatment / bath folds use).
%
%   The legacy `document_id` dependency (the corpus reference-integrity orphan)
%   is dropped: an unresolved generic edge with no role in the new model.
%
%   See also: did2.convert.v1_to_v2, ndi.daq.reader.image (ingest_epochfiles),
%   did-schema V_zeta daqreader_image_epochdata_ingested / imageseries_observation.

arguments
    preBody (1,1) struct
end

TV = 'V_zeta';
stk    = getBlock(preBody, 'image_stack');
params = getBlock(preBody, 'image_stack_parameters');

subjectId = dependencyValue(preBody, 'subject_id');
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
stackId   = baseField(preBody, 'id', did.ido.unique_id());

modality = ontologyTermFromCurie(firstNonEmpty( ...
    getCharField(stk, 'format_ontology'), getCharField(stk, 'formatOntology')));
caption  = getCharField(stk, 'label');
axes     = axesFromParams(params);
dataType = getCharField(params, 'data_type');
dimOrder = firstNonEmpty(getCharField(params, 'dimension_order'), 'YXCZT');
dimSize  = numVec(getField(params, 'dimension_size'));
[clockName, t0] = clockFromParams(params);
numFrames = frameCount(dimOrder, dimSize);

% ---- ids (minted up front so the depends_on edges all resolve in-batch) -----
elementId   = did.ido.unique_id();
epochDocId  = did.ido.unique_id();
daqreaderId = did.ido.unique_id();
anchorId    = did.ido.unique_id();
epochName   = 'migrated_image_epoch_1';

% ---- the imaging element (ndi.element.image) --------------------------------
element = struct();
element.document_class = classBlock('element', {'base'}, TV);
element.depends_on = struct('name', {'subject_id'}, 'value', {subjectId});
element.base = struct('id', elementId, 'session_id', sessionId, ...
    'name', 'migrated_image', 'datestamp', datestamp);
element.element = struct('ndi_element_class', 'ndi.element.image', ...
    'name', 'migrated_image', 'reference', 1, 'type', 'image', 'direct', 0);

% ---- the epoch document (target of the ingested data's epochid edge) ---------
epoch = struct();
epoch.document_class = classBlock('element_epoch', {'base', 'epochid'}, TV);
epoch.depends_on = struct('name', {'element_id'}, 'value', {elementId});
epoch.base = struct('id', epochDocId, 'session_id', sessionId, ...
    'name', epochName, 'datestamp', datestamp);
epoch.epochid = struct('epochid', epochName);
epoch.element_epoch = struct( ...
    'clocks', struct('name', clockName, 't0', t0, 't1', t0), ...
    'axes', axes, ...
    'channels', pixelChannel(), ...
    'storage', struct('format', '', 'chunk_shape', [], 'codec', '', ...
        'data_type', dataType, 'data_limits', []));

% ---- the DAQ reader the ingested epoch data depends on ----------------------
daqreader = struct();
daqreader.document_class = classBlock('daqreader', {'base'}, TV);
daqreader.depends_on = struct('name', {}, 'value', {});
daqreader.base = struct('id', daqreaderId, 'session_id', sessionId, ...
    'name', 'migrated_image_daqreader', 'datestamp', datestamp);
daqreader.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.image');

% ---- the DIGITAL ingested frames (frames.bin + header) ----------------------
ingId = did.ido.unique_id();
ing = struct();
% dep-only (V_eta chunk b): the ingested cache no longer re-mixes the `epochid`
% superclass -- its epoch identity is the required `epochid` DEP below (-> the
% element_epoch doc, which carries the epoch name). No inline epochid block.
ing.document_class = classBlock('daqreader_image_epochdata_ingested', ...
    {'base', 'daqreader_epochdata_ingested'}, TV);
ing.depends_on = [ ...
    struct('name', 'daqreader_id', 'value', daqreaderId), ...
    struct('name', 'epochid',      'value', epochDocId)];
ing.base = struct('id', ingId, 'session_id', sessionId, ...
    'name', 'migrated_image_frames', 'datestamp', datestamp);
ing.daqreader_epochdata_ingested = struct('epochtable', struct( ...
    'epochclock', {{clockName}}, 't0_t1', [t0, t0]));
ing.daqreader_image_epochdata_ingested = struct( ...
    'dimension_order', dimOrder, ...
    'dimension_size', dimSize, ...
    'data_type', dataType, ...
    'num_frames', numFrames, ...
    'frametimes', frameTimes(clockName, numFrames, t0), ...
    'clocktype', clockName);
% carry the pixel bytes over verbatim as the ingested frames.bin (universal
% renames leave file/files untouched; this doc owns the digital bytes now).
if isfield(preBody, 'files'); ing.files = preBody.files; end
if isfield(preBody, 'file');  ing.file  = preBody.file;  end

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});   % session rides on base
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable spine handle ------------------------------------------
obs = struct();
obs.document_class = classBlock('imageseries_observation', ...
    {'dataseries_observation'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId), ...
    struct('name', 'element_id',       'value', elementId)];
obs.base = struct('id', stackId, 'session_id', sessionId, ...
    'name', 'migrated_imageseries', 'datestamp', datestamp);
obs.subject_interaction = struct( ...
    'method', struct('node', '', 'name', ''), ...
    'variable', modality, ...
    'target_structure', {struct('node', {}, 'name', {})});
obs.observation = struct();
obs.dataseries_observation = struct('axes', axes, 'channels', pixelChannel(), ...
    'label', caption);
obs.imageseries_observation = struct('kind', modality, 'acquisition_type', 'derived');

bodies = {obs, element, epoch, ing, daqreader, anchor};
end

% ===================== geometry / clock builders ===========================

function axes = axesFromParams(params)
%AXESFROMPARAMS dimension_order (e.g. 'YX'/'ZYX'/'TZYX') -> dataseries axes[].
axes = struct('name', {}, 'kind', {}, 'length', {}, 'regularity', {}, ...
    'spacing', {}, 'unit', {}, 'sample_rate', {});
order = getCharField(params, 'dimension_order');
sizes = numVec(getField(params, 'dimension_size'));
scale = numVec(getField(params, 'dimension_scale'));
units = splitCsv(getCharField(params, 'dimension_scale_units'));
for i = 1:numel(order)
    [nm, kindTerm, isTime] = axisKind(upper(order(i)));
    len = 0; if i <= numel(sizes); len = sizes(i); end
    sp = 0;  if i <= numel(scale); sp = scale(i); end
    un = ''; if i <= numel(units); un = strtrim(units{i}); end
    a = struct('name', nm, 'kind', kindTerm, 'length', len, ...
        'regularity', 'regular', 'spacing', sp, ...
        'unit', struct('node', '', 'name', un), 'sample_rate', blankFrequency());
    if isTime && sp > 0
        a.sample_rate = struct('source_value', 1/sp, 'source_unit', 'Hz', ...
            'approximate', false);
    end
    axes(end+1) = a; %#ok<AGROW>
end
end

function [nm, term, isTime] = axisKind(c)
switch c
    case 'Y', nm = 'y';       term = otTerm('space_y'); isTime = false;
    case 'X', nm = 'x';       term = otTerm('space_x'); isTime = false;
    case 'Z', nm = 'z';       term = otTerm('space_z'); isTime = false;
    case 'T', nm = 'time';    term = otTerm('time');    isTime = true;
    case 'C', nm = 'channel'; term = otTerm('index');   isTime = false;
    otherwise, nm = lower(c); term = otTerm('index');   isTime = false;
end
end

function [clockName, t0] = clockFromParams(params)
%CLOCKFROMPARAMS timestamp + clocktype -> a clock name + start time. A clockless
%   image_stack (no clocktype) maps to the 'no_time' clock ndi.probe.image
%   reports for still stacks.
clockName = getCharField(params, 'clocktype');
if isempty(clockName); clockName = 'no_time'; end
t0 = 0.0;
ts = getField(params, 'timestamp');
if ~isempty(ts) && isnumeric(ts) && isscalar(ts); t0 = double(ts); end
end

function n = frameCount(dimOrder, dimSize)
%FRAMECOUNT frames along the ordering axes (T, and Z when present).
n = 1;
for i = 1:min(numel(dimOrder), numel(dimSize))
    c = upper(dimOrder(i));
    if c == 'T' || c == 'Z'
        if dimSize(i) > 0; n = n * dimSize(i); end
    end
end
end

function ft = frameTimes(clockName, n, t0)
%FRAMETIMES 1xN row; NaN for a clockless epoch (matches ingest_epochfiles).
n = max(n, 1);
if strcmp(clockName, 'no_time')
    ft = nan(1, n);
else
    ft = t0 + (0:n-1);
end
end

function ch = pixelChannel()
ch = struct('name', 'pixel', 'native_unit', otTerm('digital_count'), ...
    'gain', 1.0, 'offset', 0.0);
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

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function t = ontologyTermFromCurie(curie)
if isempty(curie)
    t = struct('node', '', 'name', 'image');
else
    t = struct('node', curie, 'name', '');
end
end

function f = blankFrequency()
f = struct('source_value', 0.0, 'source_unit', '', 'approximate', false);
end

function b = getBlock(body, name)
b = struct();
if isfield(body, name) && isstruct(body.(name)); b = body.(name); end
end

function v = getField(body, name)
v = [];
if isfield(body, name); v = body.(name); end
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

function c = splitCsv(s)
c = {};
if ~isempty(s); c = strtrim(strsplit(s, ',')); end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(body, name)
v = '';
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    for k = 1:numel(body.depends_on)
        d = body.depends_on(k);
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

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name) ...
        && ~isempty(body.base.(name))
    v = body.base.(name);
end
end
