function bodies = vmneuralresponseresiduals(preBody)
%VMNEURALRESPONSERESIDUALS Brainstorm-J migrator: did_v1 vmneuralresponseresiduals
%   -> a voltage_observation (mean residual) + a derived_from relation + anchor.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   The residuals of a Vm spike fit (mean_residual scalar), tied to a subject via
%   element_id and derived from a vmspikefit. #9 analysis-tier fold (scalar +
%   provenance): mean_residual -> an inline voltage_observation of the subject, and
%   a derived_from relation (this <- the vmspikefit).
%
%       voltage_observation  variable = 'mean fit residual', value = mean_residual
%                            (mV), inline.
%       directed_relation    derived_from: the residual obs (child) <- the
%                            vmspikefit (parent), when vmspikefit_id is present.
%       session_relative_reference   the 'during' anchor.
%
%   1 -> 2/3. DEFERRED: the full residual trace file (-> a body) is a follow-up.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'vmneuralresponseresiduals');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
fitId = dependencyValue(preBody, 'vmspikefit_id');
meanResidual = getField(blk, 'mean_residual');

anchor = jAnchor(preBody);
bodies = {anchor};
if isnumeric(meanResidual) && isscalar(meanResidual)
    obsId = did.ido.unique_id();
    obs = struct();
    obs.document_class = classBlock('voltage_observation', {'subject_observation', 'voltage'});
    obs.depends_on = [ ...
        struct('name', 'subject_id',       'value', subjectId), ...
        struct('name', 'time_reference_1', 'value', anchor.base.id)];
    obs.base = struct('id', obsId, 'session_id', baseField(preBody, 'session_id', ''), ...
        'name', 'migrated_fit_residual', ...
        'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
    obs.subject_statement = struct('variable', otTerm('', 'mean fit residual'), ...
        'storage_mode', 'inline');
    obs.subject_interaction = struct('method', otTerm('', ''), ...
        'sample_time', struct('kind', 'point'));
    obs.subject_observation = struct();
    obs.voltage = struct('value', struct('source_unit', 'mV', ...
        'source_value', double(meanResidual), 'approximate', false));
    bodies = {obs, anchor};
    if ~isempty(fitId)
        rel = struct();
        rel.document_class = classBlock('directed_relation', {'relation'});
        rel.depends_on = [ ...
            struct('name', 'child',  'value', obsId), ...
            struct('name', 'parent', 'value', fitId)];
        rel.base = struct('id', did.ido.unique_id(), ...
            'session_id', baseField(preBody, 'session_id', ''), ...
            'name', 'derived_from', ...
            'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
        rel.directed_relation = struct('relation', otTerm('ro:0001000', 'derived_from'));
        bodies{end+1} = rel;
    end
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
