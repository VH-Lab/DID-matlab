function bodies = vmspikesummary(preBody)
%VMSPIKESUMMARY Brainstorm-J migrator: did_v1 vmspikesummary -> a set of inline
%   scalar data-type observations (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   vmspikesummary is a bundle of per-recording scalar spike statistics tied to a
%   subject via element_id. #9 analysis-tier fold: the "scalar decomposition"
%   pattern -- each summary scalar becomes its OWN inline quantity observation
%   (storage_mode 'inline', value carried inline), classed by its physical quantity:
%
%       mean_vm            -> voltage_observation   (membrane potential, mV)
%       mean_firing_rate   -> frequency_observation (Hz)
%       num_spikes         -> count_observation      (dimensionless count)
%       recording_duration -> duration_observation   (s)
%
%   1 -> (N + 1): one observation per present scalar, plus the shared 'during'
%   session anchor. Absent/empty scalars are skipped.

arguments
    preBody (1,1) struct
end

blk = getBlock(preBody, 'vmspikesummary');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));

anchorId = did.ido.unique_id();
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'});
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', anchorId, ...
    'session_id', baseField(preBody, 'session_id', ''), ...
    'name', 'migrated_session_anchor', ...
    'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% (field, leaf class, quantity mixin, variable name, unit)
spec = {
    'mean_vm',            'voltage_observation',   'voltage',   'mean membrane potential', 'mV'
    'mean_firing_rate',   'frequency_observation', 'frequency', 'mean firing rate',        'Hz'
    'num_spikes',         'count_observation',     'count',     'spike count',             ''
    'recording_duration', 'duration_observation',  'duration',  'recording duration',      's'
    };

bodies = {};
for k = 1:size(spec, 1)
    v = getField(blk, spec{k, 1});
    if isempty(v) || ~isnumeric(v) || ~isscalar(v)
        continue;   % absent/non-scalar -> skip
    end
    bodies{end+1} = scalarObs(preBody, subjectId, anchorId, ...
        spec{k, 2}, spec{k, 3}, spec{k, 4}, double(v), spec{k, 5}); %#ok<AGROW>
end
if ~isempty(bodies)
    bodies{end+1} = anchor;
else
    bodies = {preBody};   % nothing recognised -> carry unchanged (discovery fallback)
end
end

% ===================== builders / helpers ==================================

function body = scalarObs(preBody, subjectId, anchorId, leafClass, mixin, varName, num, unit)
body = struct();
body.document_class = classBlock(leafClass, {'subject_observation', mixin});
body.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
body.base = struct('id', did.ido.unique_id(), ...
    'session_id', baseField(preBody, 'session_id', ''), ...
    'name', 'migrated_spike_summary', ...
    'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
body.subject_statement = struct('variable', struct('node', '', 'name', varName), ...
    'storage_mode', 'inline');
body.subject_interaction = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
body.subject_observation = struct();
body.(mixin) = struct('value', struct('source_unit', unit, ...
    'source_value', double(num), 'approximate', false));
end

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(block, name)
v = [];
if isfield(block, name); v = block.(name); end
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
