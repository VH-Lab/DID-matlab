function bodies = jTuningFold(preBody, className, axisName, axisUnit, axisField, axisValuesOverride)
%JTUNINGFOLD Shared #9 tuning fold for the did_v1 <x>_tuning family.
%   A tuning curve is a small paired-array measurement (a response vs a stimulus
%   parameter), so it lives DIRECTLY on the statement inline -- NOT a sampled_body
%   (which is file-backed only). One did_v1 <x>_tuning document ->
%
%     <response>_observation  the MEASUREMENT-shaped quantity leaf chosen from
%                        properties.response_units (spikes/s|Hz -> frequency,
%                        mV|V -> voltage, else the dimensionless a.u. home
%                        intensity, J §7). storage_mode 'inline'; the response
%                        curve (tuning_curve.mean) is the leaf's length-N `value`
%                        (an array of measurement composites, one per reading).
%                        The stimulus parameter is a D10 `parameters` qualifier
%                        (parameters.quantity.value, one level per reading -- the
%                        "axis" case, plan A.9).
%     directed_relation  derived_from (ro:0001000): the tuning obs (child) <- the
%                        raw stimulus_tuningcurve (parent), when present.
%     session_relative_reference   the 'during' anchor.
%
%   1 -> 2/3. Every response branch is measurement-shaped, so the length-N value
%   is one array shape regardless of dimension (score/count carry a DIFFERENT
%   value composite and are never a tuning-response home).
%
%   className   the source class; de-underscored it is the spine variable.
%   axisName    ontology_term name for the axis qualifier (e.g. 'contrast').
%   axisUnit    source_unit for the axis measurements (e.g. 'deg', 'cyc/deg').
%   axisField   tuning_curve field holding the independent variable; ignored when
%               axisValuesOverride is supplied (the derived-axis case, e.g. speed).
%   axisValuesOverride  optional precomputed axis vector (e.g. speed = TF ./ SF).
%
%   Shared helper for the Brainstorm-J (+migrators_j) *_tuning migrators.
blk   = subBlock(preBody, className);
curve = subBlock(blk, 'tuning_curve');
props = subBlock(blk, 'properties');
response = numRow(subField(curve, 'mean'));
if nargin >= 6 && ~isempty(axisValuesOverride)
    indep = numRow(axisValuesOverride);
else
    indep = numRow(subField(curve, axisField));
end
respUnits = charField(props, 'response_units');

anchor = jSessionAnchor(preBody, 'during');
if isempty(response)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end
[leaf, mixin] = tuningLeaf(respUnits);

obs = jStartInteraction(preBody, leaf, 'subject_observation', {mixin}, ...
    jOntologyTerm('', strrep(className, '_', ' ')), {'element_id', 'subject_id'}, true);
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.subject_statement.conditions = struct( ...
    'variable', jOntologyTerm('', axisName), ...
    'quantity', struct('value', jMeasureArray(indep, axisUnit)));
obs.(mixin) = struct('value', jMeasureArray(response, respUnits));   % length-N inline value

bodies = {obs, anchor};
tcId = subDep(preBody, 'stimulus_tuningcurve_id');
if ~isempty(tcId)
    bodies{end+1} = derivedFromRelation(preBody, obs.base.id, tcId);
end
end

% ===================== builders ============================================

function rel = derivedFromRelation(preBody, childId, parentId)
% the tuning obs (child) <- the raw stimulus_tuningcurve (parent), ro:0001000.
sid = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sid = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [struct('name', 'child', 'value', childId), ...
                  struct('name', 'parent', 'value', parentId)];
rel.base = struct('id', did.ido.unique_id(), 'session_id', sid, ...
    'name', 'derived_from', 'datestamp', ds);
rel.directed_relation = struct('relation', jOntologyTerm('ro:0001000', 'derived_from'));
end

function [leaf, mixin] = tuningLeaf(unit)
u = lower(strtrim(char(unit)));
switch u
    case {'hz', 'spikes/s', 'sp/s', '1/s', 'spikes/sec', 'spikes per second'}
        leaf = 'frequency_observation'; mixin = 'frequency';
    case {'mv', 'v', 'uv'}
        leaf = 'voltage_observation';   mixin = 'voltage';
    otherwise
        leaf = 'intensity_observation'; mixin = 'intensity';
end
end

% ===================== small helpers =======================================

function b = subBlock(s, name)
b = struct();
if isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end

function v = subField(s, name)
v = [];
if isfield(s, name); v = s.(name); end
end

function s = charField(blk, name)
s = '';
if isfield(blk, name)
    v = blk.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v = numRow(x)
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

function v = subDep(s, name)
v = '';
if isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        d = s.depends_on(k);
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
