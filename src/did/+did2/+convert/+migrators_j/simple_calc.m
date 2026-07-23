function bodies = simple_calc(preBody)
%SIMPLE_CALC Brainstorm-J migrator: did_v1 simple_calc -> a single inline scalar
%   observation, typed by its units (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   simple_calc is a generic scalar calculation result (result_value +
%   result_units), tied to a subject via element_id. #9 analysis-tier fold (scalar
%   pattern): the result becomes one inline quantity observation, the quantity leaf
%   chosen from the units (Hz -> frequency, V/mV -> voltage, s -> duration, ...);
%   an unrecognised/dimensionless unit falls back to score_observation. 1 -> 2.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'simple_calc');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
val  = getField(blk, 'result_value');
unit = getCharField(blk, 'result_units');
[leaf, mixin, isScore] = quantityForUnit(unit);

anchor = jAnchor(preBody);
bodies = {anchor};
if isnumeric(val) && isscalar(val)
    obs = struct();
    obs.document_class = classBlock(leaf, {'subject_observation', mixin});
    obs.depends_on = [ ...
        struct('name', 'subject_id',       'value', subjectId), ...
        struct('name', 'time_reference_1', 'value', anchor.base.id)];
    obs.base = struct('id', did.ido.unique_id(), ...
        'session_id', baseField(preBody, 'session_id', ''), ...
        'name', 'migrated_simple_calc', ...
        'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
    obs.subject_statement = struct('variable', otTerm('', 'calculated value'), ...
        'storage_mode', 'inline');
    obs.subject_interaction = struct('method', otTerm('', ''), ...
        'sample_time', struct('kind', 'point'));
    obs.subject_observation = struct();
    if isScore
        obs.(mixin) = struct('value', struct('value', double(val), ...
            'scale', otTerm('', ''), 'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false));
    else
        obs.(mixin) = struct('value', struct('source_unit', unit, ...
            'source_value', double(val), 'approximate', false));
    end
    bodies = {obs, anchor};
end
end

function [leaf, mixin, isScore] = quantityForUnit(unit)
isScore = false;
u = lower(strtrim(unit));
switch u
    case {'hz', 'spikes/s', '1/s'};        leaf = 'frequency_observation'; mixin = 'frequency';
    case {'v', 'mv', 'uv', 'microvolt', 'volt'}; leaf = 'voltage_observation'; mixin = 'voltage';
    case {'s', 'sec', 'seconds', 'ms'};    leaf = 'duration_observation';  mixin = 'duration';
    case {'a', 'pa', 'na', 'ua', 'amp'};   leaf = 'current_observation';   mixin = 'current';
    case {'deg', 'degree', 'degrees', 'rad', 'radian'}; leaf = 'angle_observation'; mixin = 'angle';
    otherwise
        leaf = 'score_observation'; mixin = 'score'; isScore = true;
end
end

% ===================== small helpers =======================================

function anchor = jAnchor(preBody)
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'});
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', did.ido.unique_id(), ...
    'session_id', baseField(preBody, 'session_id', ''), ...
    'name', 'migrated_session_anchor', ...
    'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');
end

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function t = otTerm(node, name)
t = struct('node', char(node), 'name', char(name));
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
