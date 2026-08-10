function bodies = pyraview(preBody)
%PYRAVIEW Brainstorm-J migrator: did_v1 pyraview -> a body-backed
%   dataseries_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   pyraview is a multi-resolution PYRAMID view of a sampled signal (level1..10.bin
%   decimation levels + native_rate/channels/data_type), tied to a subject via
%   element_id. In J it dissolves into the data_body model (2.D), exactly like the
%   image_stack fold:
%
%       dataseries_observation  the discoverable spine handle: subject_id, a shared
%                           time anchor, a placeholder subject_statement.variable
%                           (the signal `label`), and storage_mode 'body' (the
%                           cadence lives in the body, D1).
%       sampled_body        the NATIVE-resolution signal: datum (kind/dtype/shape)
%                           + sample_time (t0 = native_start_time, dt = 1/native_rate)
%                           + the carried bytes; statement -> the observation.
%       session_relative_reference   the ordinal 'during' anchor (a pyraview has no
%                           DAQ epoch -- the honest fallback the treatment/image
%                           folds use).
%
%   1 -> (2 + N): the observation, ONE sampled_body per stored resolution level
%   (all sharing the statement -- the multi-body stream sampled_body was designed
%   for; levels told apart by sample_time.dt), and the anchor. Each level keeps its
%   own bytes (a pyramid is a precomputed performance cache, not a disposable
%   thumbnail), so nothing is dropped.
%
%   ---------------------------------------------------------------------
%   + THE `filter` BLOCK, WHICH THIS FOLD USED TO DISCARD ENTIRELY
%   ---------------------------------------------------------------------
%   `pyraview` declares `data/filter.json` as a superclass, and it is the ONLY
%   class in NDI that does (git grep for the definition path on origin/main
%   returns filter.json itself and pyraview.json, nothing else). Until now this
%   migrator built every output body from scratch and never read that block, so
%   the filter specification was dropped on the floor -- silently, because a
%   dropped superclass block is invisible to every Phase-1 counter.
%
%   It is NOT incidental metadata. The real PRED document is a 4th-order
%   Chebyshev-I high-pass at 300 Hz: 300-Hz-high-passed voltage is a DIFFERENT
%   QUANTITY from raw voltage, so the filter is part of what the stored numbers
%   mean (V_eta_frequency_filter_model_plan.md, signed 2026-07-30).
%
%   So the fold now also emits ONE `frequency_filter` document and points every
%   level body at it via `sampled_body.filter_id` (declared optional there,
%   must_refer_to_document_class frequency_filter). The filter rides on the
%   BODIES rather than the observation because that is where the schema puts the
%   edge, and because it describes the samples. When the block names no
%   representable filter -- an all-pass, or a vocabulary v1 has never used --
%   `jFrequencyFilter` returns nothing and no `filter_id` is written, so the
%   output is exactly what it was before.
%
%   NOTE: dataseries_observation and the *_body classes are `draft` in V_eta. This
%   is the pattern-setter for the #9 analysis-tier folds (mint observation + attach
%   sampled_body). pyraview stays in the schema until this is corpus-proven.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'pyraview');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
obsId     = baseField(preBody, 'id', did.ido.unique_id());

label    = getCharField(blk, 'label');
dataType = getCharField(blk, 'data_type');
channels = getField(blk, 'channels');
t0       = numScalar(getField(blk, 'native_start_time'), 0.0);
nativeRt = numScalar(getField(blk, 'native_rate'), 0.0);
dt       = 0.0;
if nativeRt > 0; dt = 1.0 / nativeRt; end

anchorId = did.ido.unique_id();

% ---- the frequency_filter split off the inherited `filter` block ------------
% [] when the block is absent, describes an all-pass ('none'), or uses a
% vocabulary this model cannot represent. In that case no document is emitted
% and no filter_id edge is written -- never a guessed design.
filterDoc = jFrequencyFilter(preBody);
filterId = '';
if ~isempty(filterDoc)
    filterId = filterDoc.base.id;
end

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});   % session rides on base
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable, body-backed voltage_observation ----------------------
% A pyraview is a decimated view of a continuous recorded signal -> default to the
% voltage_observation quantity leaf (the abstract/collapsed dataseries_observation
% branch is not a valid concrete class). NOTE: the physical quantity is not carried
% on the doc; voltage is the dominant NDI case (ephys), but a non-voltage pyraview
% would need per-signal quantity typing (a discovery/second-pass refinement).
obs = struct();
obs.document_class = classBlock('voltage_observation', {'subject_observation', 'voltage'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', obsId, 'session_id', sessionId, ...
    'name', 'migrated_signal', 'datestamp', datestamp);
% storage_mode: body -> the value is in the sampled_body; the statement carries no
% sample_time (the body owns the cadence). variable = the signal label.
obs.subject_statement = struct( ...
    'variable', struct('node', '', 'name', firstNonEmpty(label, 'signal')), ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
obs.voltage = struct();   % value is body-backed

% ---- one sampled_body per stored resolution level ---------------------------
% Each pyramid level is its own sampled_body, all sharing the statement (the
% observation) -- the multi-body-per-statement stream sampled_body was designed
% for ("append more bodies without rewriting the anchor"). Levels are told apart
% by sample_time.dt (the per-level sampling rate); level 1 is native. Each body
% owns one level_k.bin (files.file_list re-keys the bytes to the minting doc, as
% the image_stack fold does for its single body).
fileList = {};
if isfield(preBody, 'files') && isstruct(preBody.files) ...
        && isfield(preBody.files, 'file_list')
    fileList = preBody.files.file_list;
    if ~iscell(fileList); fileList = {fileList}; end
end
if isempty(fileList); fileList = {''}; end   % at least the native body

rates  = numVec(getField(blk, 'decimation_sampling_rates'));
starts = numVec(getField(blk, 'decimation_start_times'));

bodies = {obs};
for k = 1:numel(fileList)
    rate_k = nativeRt;
    if k <= numel(rates) && rates(k) > 0; rate_k = rates(k); end
    dt_k = 0.0;
    if rate_k > 0; dt_k = 1.0 / rate_k; end
    t0_k = t0;
    if k <= numel(starts); t0_k = starts(k); end

    b = jSampledBody(obsId, sessionId, datestamp, 'migrated_signal_body', ...
        struct('kind', 'array', 'dtype', dataType, 'unit', '', 'shape', channels), ...
        struct('regular', true, ...
            't0', durationComposite(t0_k), 'dt', durationComposite(dt_k), 'n', 0));
    % this body owns exactly its level's file
    b.files = struct('file_list', {fileList(k)});
    % every level was produced by the SAME filter (filterData is called once per
    % document, makePyraviewDoc.m:58/:108, and the decimation happens after it),
    % so all the level bodies share one frequency_filter document. The edge is
    % appended only when there is a filter to point at -- never an empty edge.
    if ~isempty(filterId)
        b.depends_on(end+1) = struct('name', 'filter_id', 'value', filterId);
    end
    bodies{end+1} = b; %#ok<AGROW>
end
bodies{end+1} = anchor;
if ~isempty(filterDoc)
    bodies{end+1} = filterDoc;
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

function v = getField(block, name)
v = [];
if isfield(block, name); v = block.(name); end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v = numScalar(x, default)
v = default;
if ~isempty(x) && isnumeric(x) && isscalar(x); v = double(x); end
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
