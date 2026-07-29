function bodies = fitcurve(preBody)
%FITCURVE Brainstorm-J migrator: did_v1 fitcurve -> a fit-residual
%   score_observation (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   fitcurve is a generic curve fit, tied to a subject via element_id. #9
%   analysis-tier fold (scalar pattern, pragmatic): the fit residual becomes a
%   score_observation of the subject, with the fit EQUATION carried as the
%   observation's method:
%
%       score_observation  variable = 'residual sum of squares', value =
%                          fit_sse, method = the fit_equation term. inline.
%       session_relative_reference   the 'during' anchor.
%
%   ---------------------------------------------------------------------
%   FIELD NAMES CORRECTED -- AND THE QUANTITY IS NOT WHAT IT CLAIMED
%   ---------------------------------------------------------------------
%   This migrator used to read `fit_function` and `goodness_of_fit`. NEITHER
%   NAME HAS EVER EXISTED on the NDI template: across NDI's entire history the
%   fitcurve template has carried fit_equation, fit_sse, fit_name, fit_data,
%   fit_parameters, fit_parameter_names, fit_constraints and the independent /
%   dependent variable-name lists -- 0 commits mention fit_function or
%   goodness_of_fit, against 7 for fit_equation and fit_sse. The names came from
%   DID-schema's own V_alpha snapshot (see V_eta_ground_truth_plan.md), so both
%   reads returned nothing on every real document and the fold emitted only a
%   bare session anchor.
%
%   `fit_function` -> `fit_equation` is a plain rename. THE OTHER HALF IS NOT.
%   The old code wrote its value into a `score` with scale_min 0, scale_max 1,
%   labelled "goodness of fit" -- i.e. a bounded score where HIGHER IS BETTER.
%   What the template actually has is `fit_sse`, a SUM OF SQUARED ERRORS:
%   unbounded, in the dependent variable's units squared, and LOWER IS BETTER.
%   Mapping one onto the other would have inverted the polarity of every
%   downstream comparison while looking like a tidy rename. So the value is
%   reported as what it is -- a residual -- and the false 0..1 scale is dropped
%   rather than left asserting a range SSE cannot honour.
%
%   r^2 is NOT recoverable here as a substitute: it needs the total sum of
%   squares. fitcurve does ship `fit_data`, so it could in principle be derived
%   for THIS class -- but vmspikefit has no data field at all, and deriving it
%   on one side only would leave two classes emitting the same variable name
%   for different quantities. Deliberately not done.
%
%   1 -> 2. DEFERRED (flagged): the fit_parameters structure itself is NOT yet
%   re-expressed -- per the plan a fit's parameters fold to a `method` / D10
%   parameters, a per-class decision. This captures the residual + which
%   equation; the parameter vector is a follow-up.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'fitcurve');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sse = getField(blk, 'fit_sse');
fitEq = getCharField(blk, 'fit_equation');
bodies = residualFold(preBody, subjectId, sse, fitEq, 'migrated_fitcurve');
end

function bodies = residualFold(preBody, subjectId, sse, fitEq, name)
% shared body of the fit -> residual score_observation fold.
anchor = jAnchor(preBody);
bodies = {anchor};
if isnumeric(sse) && isscalar(sse)
    obs = struct();
    obs.document_class = classBlock('score_observation', {'subject_observation', 'score'});
    obs.depends_on = [ ...
        struct('name', 'subject_id',       'value', subjectId), ...
        struct('name', 'time_reference_1', 'value', anchor.base.id)];
    obs.base = struct('id', did.ido.unique_id(), ...
        'session_id', baseField(preBody, 'session_id', ''), ...
        'name', name, 'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
    obs.subject_statement = struct('variable', otTerm('', 'residual sum of squares'), ...
        'storage_mode', 'inline');
    % the fit EQUATION is the method that produced the fit.
    obs.subject_interaction = struct('method', otTerm('', firstNonEmpty(fitEq, '')), ...
        'sample_time', struct('kind', 'point'));
    obs.subject_observation = struct();
    % scale_min/scale_max are deliberately OMITTED (both are optional): SSE is
    % unbounded, so declaring 0..1 would be false. `scale` names a scoring
    % rubric and SSE has none.
    obs.score = struct('value', struct('value', double(sse), ...
        'scale', otTerm('', ''), 'approximate', false));
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
