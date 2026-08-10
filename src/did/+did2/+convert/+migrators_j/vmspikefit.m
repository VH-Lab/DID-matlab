function bodies = vmspikefit(preBody)
%VMSPIKEFIT Brainstorm-J migrator: did_v1 vmspikefit -> a fit-residual
%   score_observation (+ the shared session anchor).
%
%   ---------------------------------------------------------------------
%   FIELD NAMES CORRECTED -- AND THE QUANTITY IS NOT WHAT IT CLAIMED
%   ---------------------------------------------------------------------
%   This migrator used to read `fit_function` and `r_squared`. NEITHER NAME HAS
%   EVER EXISTED on the NDI template: across NDI's entire history the vmspikefit
%   template has carried fit_equation, fit_sse, fit_sse_perpoint, fit_name,
%   fit_parameters, fit_parameter_names and fit_constraints -- 0 commits mention
%   fit_function or r_squared, against 7 for fit_equation and fit_sse. The names
%   came from DID-schema's own V_alpha snapshot (V_eta_ground_truth_plan.md), so
%   both reads returned nothing on every real document and the fold emitted only
%   a bare session anchor.
%
%   `fit_function` -> `fit_equation` is a plain rename. THE OTHER HALF IS NOT.
%   The old code wrote r_squared into a `score` with scale_min 0, scale_max 1,
%   labelled "goodness of fit" -- and r^2 genuinely IS that: bounded, higher is
%   better. What the template actually has is `fit_sse`, a SUM OF SQUARED
%   ERRORS: unbounded, in the fitted variable's units squared, and LOWER IS
%   BETTER. Substituting one for the other would have inverted the polarity of
%   every downstream comparison while looking like a tidy rename. So the value
%   is reported as what it is, and the false 0..1 scale is dropped.
%
%   r^2 is NOT recoverable here: it needs the total sum of squares, and this
%   template ships no data field at all. (fitcurve does ship `fit_data`, so it
%   could be derived there -- deliberately not done, because deriving it on one
%   side only would leave two classes emitting the same variable name for
%   different quantities.)
%
%   `fit_sse_perpoint` is also available and is the figure that compares across
%   fits of different lengths. Carrying it as a second observation is a
%   modelling choice, not part of this repair -- left as a follow-up.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   vmspikefit is a Vm spike-shape fit, tied to a subject via element_id. #9
%   analysis-tier fold (scalar pattern, pragmatic, same shape as fitcurve):
%   fit_sse becomes a score_observation of the subject, with the fit EQUATION as
%   the observation's method. 1 -> 2.
%
%   DEFERRED (flagged): the fit_parameters structure and the vmspikefit_file (the
%   fit result bytes) are NOT re-expressed -- a fit's parameters fold to a `method`
%   / D10 parameters (+ possibly an opaque_body for the file), a per-class decision.
%
%   ---------------------------------------------------------------------
%   THE `app` BLOCK WAS BEING DROPPED ON THE FLOOR (partially repaired here)
%   ---------------------------------------------------------------------
%   STATUS OF THIS REPAIR: NOT RUN. There is no MATLAB in the environment it was
%   written in. The gate is tests/+did2/+unittest/testMigratorsJAppFold.m, unrun.
%
%   `vmspikefit` declares the `app` superclass on NDI origin/main -- read from
%   the template:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/vhlab_voltage2firingrate/vmspikefit.json
%         superclasses: [ base.json, epochid.json, app.json ]
%
%   This migrator builds new bodies, so the block had no successor and the
%   fitting program was discarded on every document. It matters more here than
%   elsewhere: this class's own field-name repair (above) turned on WHICH
%   program wrote the fit, and the answer was thrown away with the block.
%
%   R1 (TEAM-SIGN-OFF [software], V_eta_tenet_audit.md): a `software` ENTITY +
%   `software_id` + `execution_environment`. `score_observation` reaches both
%   through subject_observation -> subject_interaction (checked in
%   did-schema/schemas/V_eta/stable/subject_interaction.json), and the
%   session_relative_reference anchor reaches neither.
%
%   THE OBSERVATION IS CONDITIONAL -- it exists only when `fit_sse` is a numeric
%   scalar. A vmspikefit with no fit_sse emits only a bare anchor, and there is
%   nowhere typed to hang its software. No slot is invented for it; the residual
%   is REPORTED rather than closed by inventing an edge.
%
%   RequireSession is TRUE: base.session_id is mustBeNonEmpty and v1_to_v2
%   quarantines the SOURCE when a body it produced fails. It removes nothing --
%   the observation and the anchor take the same session_id.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'vmspikefit');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sse = getField(blk, 'fit_sse');
fitEq = getCharField(blk, 'fit_equation');

anchor = jAnchor(preBody);
bodies = {anchor};

% The v1 `app` block -> a software entity + the edge. jSoftwareFromApp reads
% BOTH spellings of name/version (universalRenames rewrites app.name ->
% app.app_name before any migrator runs). Emitted only alongside the
% score_observation that can reference it: the anchor declares no software_id,
% and an unreferenced entity would name the program without naming its output.
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);

if isnumeric(sse) && isscalar(sse)
    obs = struct();
    obs.document_class = classBlock('score_observation', {'subject_observation', 'score'});
    obs.depends_on = [ ...
        struct('name', 'subject_id',       'value', subjectId), ...
        struct('name', 'time_reference_1', 'value', anchor.base.id)];
    obs.base = struct('id', did.ido.unique_id(), ...
        'session_id', baseField(preBody, 'session_id', ''), ...
        'name', 'migrated_vmspikefit', ...
        'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
    obs.subject_statement = struct('variable', otTerm('', 'residual sum of squares'), ...
        'storage_mode', 'inline');
    obs.subject_interaction = struct('method', otTerm('', firstNonEmpty(fitEq, '')), ...
        'sample_time', struct('kind', 'point'));
    obs.subject_observation = struct();
    % scale_min/scale_max deliberately OMITTED (both optional): SSE is unbounded,
    % so declaring 0..1 would be false. `scale` names a rubric; SSE has none.
    obs.score = struct('value', struct('value', double(sse), ...
        'scale', otTerm('', ''), 'approximate', false));
    if ~isempty(swId)
        obs.depends_on(end+1) = struct('name', 'software_id', 'value', swId);
    end
    if ~isempty(fieldnames(execEnv))
        obs.subject_interaction.execution_environment = execEnv;
    end
    bodies = {obs, anchor};
    if ~isempty(software)
        bodies{end+1} = software;
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
