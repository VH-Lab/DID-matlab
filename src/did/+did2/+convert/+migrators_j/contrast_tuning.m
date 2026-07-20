function bodies = contrast_tuning(preBody)
%CONTRAST_TUNING Brainstorm-J migrator: did_v1 contrast_tuning -> an inline
%   tuning observation + a derived_from relation (+ the session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   A tuning curve is a small paired-array measurement (response vs a stimulus
%   parameter), so it lives DIRECTLY ON THE STATEMENT inline (not a sampled_body,
%   which is only for large body-backed data). #9 analysis-tier fold:
%
%       <response>_observation  the quantity leaf chosen from properties.response_units
%                          (Hz / spikes/s -> frequency_observation; mV/V -> voltage;
%                          else the dimensionless a.u. home -> intensity, J §7 --
%                          every branch is a MEASUREMENT-shaped composite so the
%                          length-N `value` is one array shape).
%                          storage_mode 'inline'; the response curve is the leaf's
%                          length-N `value` (an array of measurements, one per
%                          reading -- value is mustBeScalar:false). The stimulus
%                          parameter is a D10 `parameters` qualifier (one level per
%                          reading -- the "axis" case, plan A.9/§655).
%       directed_relation  derived_from: the tuning obs (child) <- the raw
%                          stimulus_tuningcurve (parent).
%       session_relative_reference   the 'during' anchor.
%
%   1 -> 2/3. This is the first D10-qualifier-populating migrator; the exact
%   parameters.quantity shape is corpus-validated on this class before the other
%   *_tuning classes reuse the pattern. DEFERRED: significance (-> score_obs) and
%   the fit blocks (-> method / parameters).

arguments
    preBody (1,1) struct
end
blk    = getBlock(preBody, 'contrast_tuning');
curve  = getBlock(blk, 'tuning_curve');
props  = getBlock(blk, 'properties');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
tcId = dependencyValue(preBody, 'stimulus_tuningcurve_id');

response = numVec(getField(curve, 'mean'));           % the response curve (per reading)
indep    = numVec(getField(curve, 'contrast'));       % the stimulus parameter (per reading)
respUnits = getCharField(props, 'response_units');
[leaf, mixin] = quantityForUnit(respUnits);

anchor = jAnchor(preBody);
bodies = {anchor};
if isempty(response)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

obsId = did.ido.unique_id();
obs = struct();
obs.document_class = classBlock(leaf, {'subject_observation', mixin});
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchor.base.id)];
obs.base = struct('id', obsId, 'session_id', baseField(preBody, 'session_id', ''), ...
    'name', 'migrated_contrast_tuning', ...
    'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
obs.subject_statement = struct( ...
    'variable', otTerm('', 'contrast tuning'), ...
    'storage_mode', 'inline', ...
    'parameters', axisQualifier('contrast', indep));
obs.subject_interaction = struct('method', otTerm('', ''), ...
    'sample_time', struct('kind', 'point'));
obs.subject_observation = struct();
obs.(mixin) = struct('value', measArray(response, respUnits));   % length-N inline value

bodies = {obs, anchor};
if ~isempty(tcId)
    rel = struct();
    rel.document_class = classBlock('directed_relation', {'relation'});
    rel.depends_on = [struct('name', 'child', 'value', obsId), ...
                      struct('name', 'parent', 'value', tcId)];
    rel.base = struct('id', did.ido.unique_id(), ...
        'session_id', baseField(preBody, 'session_id', ''), 'name', 'derived_from', ...
        'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
    rel.directed_relation = struct('relation', otTerm('ro:0001000', 'derived_from'));
    bodies{end+1} = rel;
end
end

% ===================== builders ============================================

function m = measArray(vals, unit)
% a length-N inline value: an array of measurement composites (one per reading).
m = struct('source_unit', {}, 'source_value', {}, 'approximate', {});
for k = 1:numel(vals)
    m(k) = struct('source_unit', char(unit), 'source_value', double(vals(k)), ...
        'approximate', false);
end
end

function q = axisQualifier(name, vals)
% a D10 `parameters` qualifier carrying the stimulus axis (one level per reading).
q = struct('variable', otTerm('', name), 'quantity', ...
    struct('value', measArray(vals, '')));
end

function [leaf, mixin] = quantityForUnit(unit)
% Every branch is a MEASUREMENT-shaped composite ({source_unit,source_value,
% approximate}), so the length-N inline `value` is one array shape regardless of
% dimension. Dimensionless a.u. (dF/F, ratios, blank units) is the intensity home
% (J §7), NOT score -- score/count carry a DIFFERENT value composite shape.
u = lower(strtrim(char(unit)));
switch u
    case {'hz', 'spikes/s', 'sp/s', '1/s'}; leaf = 'frequency_observation'; mixin = 'frequency';
    case {'mv', 'v', 'uv'};                 leaf = 'voltage_observation';   mixin = 'voltage';
    otherwise;                               leaf = 'intensity_observation'; mixin = 'intensity';
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

function v = numVec(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); return; end
if ischar(x) || (isstring(x) && isscalar(x))
    for tok = strsplit(char(x), {',', ' '})
        nn = str2double(tok{1});
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
