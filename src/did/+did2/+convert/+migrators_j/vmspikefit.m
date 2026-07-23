function bodies = vmspikefit(preBody)
%VMSPIKEFIT Brainstorm-J migrator: did_v1 vmspikefit -> a goodness-of-fit
%   score_observation (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   vmspikefit is a Vm spike-shape fit (fit_function + fit_parameters + r_squared),
%   tied to a subject via element_id. #9 analysis-tier fold (scalar pattern,
%   pragmatic, same shape as fitcurve): r_squared becomes a score_observation of
%   the subject, with the fit FUNCTION as the observation's method. 1 -> 2.
%
%   DEFERRED (flagged): the fit_parameters structure and the vmspikefit_file (the
%   fit result bytes) are NOT re-expressed -- a fit's parameters fold to a `method`
%   / D10 parameters (+ possibly an opaque_body for the file), a per-class decision.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'vmspikefit');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
goodness = getField(blk, 'r_squared');
fitFn = getCharField(blk, 'fit_function');

anchor = jAnchor(preBody);
bodies = {anchor};
if isnumeric(goodness) && isscalar(goodness)
    obs = struct();
    obs.document_class = classBlock('score_observation', {'subject_observation', 'score'});
    obs.depends_on = [ ...
        struct('name', 'subject_id',       'value', subjectId), ...
        struct('name', 'time_reference_1', 'value', anchor.base.id)];
    obs.base = struct('id', did.ido.unique_id(), ...
        'session_id', baseField(preBody, 'session_id', ''), ...
        'name', 'migrated_vmspikefit', ...
        'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
    obs.subject_statement = struct('variable', otTerm('', 'goodness of fit'), ...
        'storage_mode', 'inline');
    obs.subject_interaction = struct('method', otTerm('', firstNonEmpty(fitFn, '')), ...
        'sample_time', struct('kind', 'point'));
    obs.subject_observation = struct();
    obs.score = struct('value', struct('value', double(goodness), ...
        'scale', otTerm('', ''), 'scale_min', 0.0, 'scale_max', 1.0, 'approximate', false));
    bodies = {obs, anchor};
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
