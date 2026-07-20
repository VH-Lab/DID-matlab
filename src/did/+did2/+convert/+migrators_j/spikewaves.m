function bodies = spikewaves(preBody)
%SPIKEWAVES Brainstorm-J migrator: did_v1 spikewaves -> a body-backed
%   dataseries_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   spikewaves is extracted spike waveforms (num_spikes snippets of
%   samples_per_spike samples each; files spikewaves.vsw + spiketimes.bin), tied
%   to a subject via element_id. #9 analysis-tier fold, same shape as the pyraview
%   / image_stack folds:
%
%       dataseries_observation  the discoverable spine handle: subject_id, a shared
%                           time anchor, subject_statement.variable = the extraction
%                           name (or 'spike waveforms'), storage_mode 'body'.
%       sampled_body        the waveform snippets: datum kind 'array'
%                           (shape = [samples_per_spike], one waveform per datum) +
%                           sample_time (irregular; n = num_spikes -- one entry per
%                           spike event) + the carried bytes (.vsw + .bin);
%                           statement -> the observation.
%       session_relative_reference   the ordinal 'during' anchor.
%
%   1 -> 3. The extraction-provenance link (spike_extraction_parameters_id) is left
%   for the follow-up that folds spike_extraction_parameters -> a `method` (D10) +
%   a derived_from relation; it is not re-expressed here.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'spikewaves');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
obsId     = baseField(preBody, 'id', did.ido.unique_id());

extraction     = getCharField(blk, 'extraction_name');
numSpikes      = numScalar(getField(blk, 'num_spikes'), 0);
samplesPerSpike = numScalar(getField(blk, 'samples_per_spike'), 0);

anchorId = did.ido.unique_id();

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable, body-backed dataseries_observation -------------------
% spike waveforms are a voltage measurement -> the quantity-typed leaf
% voltage_observation (the dataseries/timeseries/imageseries_observation branch is
% abstract/collapsed; the go-forward observation is the data-type leaf, as
% image_stack uses image_observation). The voltage value lives in the body.
obs = struct();
obs.document_class = classBlock('voltage_observation', {'subject_observation', 'voltage'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', obsId, 'session_id', sessionId, ...
    'name', 'migrated_spikewaves', 'datestamp', datestamp);
obs.subject_statement = struct( ...
    'variable', struct('node', '', 'name', firstNonEmpty(extraction, 'spike waveforms')), ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
obs.voltage = struct();   % value is body-backed

% ---- the sampled_body holding the waveform snippets -------------------------
% One datum per spike (shape = [samples_per_spike]); the timeline is the (irregular)
% spike events, n = num_spikes.
body = jSampledBody(obsId, sessionId, datestamp, 'migrated_spikewaves_body', ...
    struct('kind', 'array', 'dtype', '', 'unit', '', 'shape', samplesPerSpike), ...
    struct('regular', false, ...
        't0', durationComposite(0), 'dt', durationComposite(0), 'n', numSpikes));
% carry the waveform + spiketime bytes over verbatim (this doc owns them now).
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end

bodies = {obs, body, anchor};
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
