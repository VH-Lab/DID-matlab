function bodies = stimulus_response_scalar(preBody)
%STIMULUS_RESPONSE_SCALAR Brainstorm-J migrator: did_v1 stimulus_response_scalar
%   -> a `calculation` whose value kind is `harmonic_component` (id PRESERVED),
%   + its time anchor + the calculator's software entity. Routed from
%   did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THE TARGET (did-schema #88). The 2026-08-08 sign-off (V_eta_stimulus_
%   response_model_plan.md, TEAM-SIGN-OFF [stimulus response], with its three
%   revisions) named a calculation leaf for this; issue #67 decision 10 deleted
%   it and #73 review item 37 restored it (V_eta_spatial_transcriptomics_plan.md).
%   On #88 a statement is its DIRECTION class plus ONE value-kind mixin
%   (V_eta_entity_composition_plan.md sec. 1), so the emitted document is class
%   `calculation` with `harmonic_component` in its superclasses
%   (did2.build.statement's 'ValueKind'). There is no leaf class to name.
%
%   GROUND TRUTH -- the WRITER. NDI-matlab `+ndi/+app/+stimulus/tuning_response.m`
%   (`compute_stimulus_response_scalar`, origin/main):
%     - five edges, set unconditionally: stimulus_response_scalar_parameters_id,
%       element_id, stimulus_presentation_id, stimulus_control_id, stimulator_id;
%     - `responses` = struct('stimid', ..., 'response_real', ...,
%       'response_imaginary', ..., 'control_response_real', ...,
%       'control_response_imaginary', ...), parallel per-reading row vectors;
%     - response_type = 'mean' when freq_response == 0, else ['F' int2str(n)],
%       so the harmonic number is a total function of `response_type`;
%     - `stimulus_response.element_epochid` / `.stimulator_epochid`.
%
%   MAPPING (the signed mapping, with its three revisions, in #88's names)
%     element_id                     -> entity_id (element.m keeps ids)
%     stimulator_id                  -> instrument_id
%     stimulus_presentation_id       -> input_id, the ONLY input
%     stimulus_control_id            -> NOT CARRIED: the control record
%                                       (v1 control_stimulus_ids) becomes no
%                                       V2 document; its content is the
%                                       presentation's `control condition`
%                                       covariate, folded by NDI's second pass
%                                       ([control as covariate], Jess Haley,
%                                       2026-10-22, superseding [control input
%                                       told apart by its document])
%     stimulus_response_scalar_parameters_id
%                                    -> method_id (see THE PARAMETERS below)
%     response_type                  -> value.harmonic ('mean' 0, 'F<n>' n)
%     responses.response_real        -> value.real
%     responses.response_imaginary   -> value.imaginary
%     responses.control_response_real      -> value.control.real
%     responses.control_response_imaginary -> value.control.imaginary
%                                       (item 69: the control nests like
%                                       tuning's). Both parts of both pairs are
%                                       kept: migration is lossless for complex
%                                       responses (Jess Haley, 2026-10-21).
%     responses.stimid               -> dimension 0: term 'stimulus' (a label),
%                                       n readings; the stimid values a
%                                       `stimulus` covariate along it (revision
%                                       1: an axis, not a condition; data_body
%                                       AMENDMENT 6, a key before)
%     stimulus_response.element_epochid -> the time anchor (revision 2): a
%                                       relative_time_reference onto the epoch
%                                       document when one exists
%     stimulus_response.stimulator_epochid -> DROPPED by the plan (a copy of the
%                                       presentation's own epoch), REPORTED
%   `variable` is the label 'stimulus response': the quantity measured (rate,
%   voltage) is recorded on no document in this family (the plan's OPEN 1/2).
%   `value.response_unit` is not written: the response document records none.
%
%   THE PARAMETERS. The v1 parameters edge becomes `method_id`, and the
%   response carries NO inline method beside it (#88: the inline `method` OR
%   `method_id`, never both). The batch pass did2.convert.resolveResponseParameters
%   replaces each parameters document with ONE standalone `method` document
%   (id PRESERVED, term RESPONSE_METHOD, the knobs as parameters) shared by
%   every response that names it, so the edge keeps resolving (Decided by Jess
%   Haley, 2026-10-21, "b"). A response with no parameters edge carries the
%   inline method term at once.
%
%   SOFTWARE. The class has no `app` block, so, as jCalculation does, the
%   calculator is a software entity named RESPONSE_METHOD
%   (resolveSoftwareDedup merges the copies); no operating_system_id (optional
%   on #88, Jess Haley 2026-10-21 [calculation-os-optional]).
%
%   THE GUARDS, each returning the document UNCHANGED:
%     1. no `element_id` -> no subject (#88 requires `entity_id`).
%     2. `response_type` not 'mean' | 'F<n>' -> the harmonic is unknown.
%     3. `responses.response_real` absent or empty -> no value.
%     4. an `element_epochid` string with no `epoch` document (jEpochDocId '')
%        -> folding would drop the string. This is the live branch on every
%        did_v1 document until did2.convert.epochMint stamps `epoch_id`
%        (epochMint arms this family and re-calls this migrator).
%     5. `stimid` present with a length other than the readings' -> the
%        dimension would misdescribe the value.
%   With no epoch string at all, the fold runs on the 'during' session anchor.
%
%   1 -> 3 (calculation + anchor + software entity).

arguments
    preBody (1,1) struct
end

RESPONSE_METHOD = 'ndi.app.stimulus.tuning_response';

blk  = subBlock(preBody, 'stimulus_response_scalar');
resp = subBlock(blk, 'responses');

subjectId = jSubjectOf(preBody, {'element_id'});
harmonic  = harmonicFromResponseType(charAny(blk, {'response_type', 'responseType'}));
realPart  = numAny(resp, {'response_real', 'responseReal'});
if isempty(subjectId) || isempty(harmonic) || isempty(realPart)
    bodies = {preBody};
    return;
end

% GUARD 4 -- the epoch gate, read through the same reader epochMint mints from.
epochString = epochStringOf(preBody, 'stimulus_response.element_epochid');
epochDocId  = jEpochDocId(preBody);
if ~isempty(epochString) && isempty(epochDocId)
    bodies = {preBody};
    return;
end

% GUARD 5 -- the reading dimension must describe the value it indexes.
stimid = numAny(resp, {'stimid'});
if ~isempty(stimid) && numel(stimid) ~= numel(realPart)
    bodies = {preBody};
    return;
end

% The value. Built by assignment so a cell-valued field cannot turn it into a
% struct array.
value = struct();
value.harmonic  = harmonic;
value.real      = realPart;
value.imaginary = numAny(resp, {'response_imaginary', 'responseImaginary'});
control = struct();
cr = numAny(resp, {'control_response_real', 'controlResponseReal'});
ci = numAny(resp, {'control_response_imaginary', 'controlResponseImaginary'});
if ~isempty(cr); control.real = cr; end
if ~isempty(ci); control.imaginary = ci; end
if ~isempty(fieldnames(control)); value.control = control; end
if isempty(value.imaginary); value = rmfield(value, 'imaginary'); end

% one `stimulus` dimension over the readings, the stimid values a covariate
% along it (data_body AMENDMENT 6; the former `stimulus` key)
dims = [];
covs = [];
if ~isempty(stimid)
    dims = did2.build.dimension(jLabel('stimulus'), numel(stimid));
    covs = did2.build.covariate(jLabel('stimulus'), 0, 'Value', double(stimid(:))');
end

% The time anchor: the epoch (revision 2) when its document exists, else the
% session ('during').
if ~isempty(epochDocId)
    anchor = did2.build.relativeTimeReference(epochDocId, ...
        'Clock', 'dev_local_time', 'Relation', 'intervalDuring', ...
        'SessionId', jSid(preBody), 'CreationTimestamp', jStamp(preBody), ...
        'Validate', false);
else
    anchor = jSessionAnchor(preBody, 'during');
end

[software, swId, execEnv] = jSoftwareFromApp(preBody);
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
if isempty(swId)
    [software, swId] = jSoftware(RESPONSE_METHOD, '', '', jSid(preBody), jStamp(preBody));
end

% The presentation ONLY. Decided by Jess Haley, 2026-10-22 [control as
% covariate] (did-schema V_eta_stimulus_response_model_plan.md): a v1
% control_stimulus_ids document becomes no V2 document -- NDI's second pass
% folds it into the presentation's `control condition` covariate -- and
% "responses point at the presentation only". The v1 `stimulus_control_id`
% edge is therefore not carried (it named the control record, which is gone).
inputs = {};
v = jDependency(preBody, 'stimulus_presentation_id');
if ~isempty(v); inputs{end+1} = v; end

methodId = jDependency(preBody, 'stimulus_response_scalar_parameters_id');
methodOpt = {};
if isempty(methodId)
    methodOpt = {'Method', jLabel(RESPONSE_METHOD)};   % method.term
else
    methodOpt = {'MethodId', methodId};
end

calc = jStatement(preBody, 'calculation', subjectId, ...
    jLabel('stimulus response'), value, ...
    'ValueKind', 'harmonic_component', ...
    'Dimensions', dims, 'Covariates', covs, ...
    'TimeReferenceIds', {anchor.base.id}, ...
    'InstrumentId', jDependency(preBody, 'stimulator_id'), ...
    'InputIds', inputs, ...
    'SoftwareId', swId, ...
    'OperatingSystemId', osId, ...
    'InterpreterId', interpreterId, ...
    methodOpt{:}, ...
    'Id', char(preBody.base.id));   % id preserved -> inbound references resolve

bodies = [{calc, anchor}, software, runDocs];

% stimulator_epochid is dropped by the signed plan: reported, never silent.
sr = subBlock(preBody, 'stimulus_response');
if ~isempty(charAny(sr, {'stimulator_epochid', 'stimulatorEpochid'}))
    did2.convert.reportNote('field_dropped', 'stimulus_response_scalar', ...
        char(preBody.base.id), 'stimulus_response.stimulator_epochid');
end

% The v1 `stimulus_control_id` edge is not carried ([control as covariate],
% above). Counted, with its denominator, as Jess Haley 2026-10-22 decided
% ([covariate rules named], answer "A" to 6.4: "migration reports count the
% v1 `stimulus_control_id` edges dropped"): ONE note per response document
% this migrator converts, its DETAIL 'dropped' (the edge named a document) or
% 'none' (the edge was empty), so the note count is the denominator and
% v1_to_v2's report prints both.
controlEdge = 'none';
if ~isempty(jDependency(preBody, 'stimulus_control_id'))
    controlEdge = 'dropped';
end
did2.convert.reportNote('stimulus_control_id', 'stimulus_response_scalar', ...
    char(preBody.base.id), controlEdge);
end

% ===================== helpers =============================================

function v = epochStringOf(preBody, wantedSource)
%EPOCHSTRINGOF One NAMED source's epoch string, via the shared reader.
v = '';
hits = did2.validate.epochStrings(preBody);
for k = 1:numel(hits)
    if strcmp(hits(k).source, wantedSource)
        v = hits(k).value;
        return;
    end
end
end

function h = harmonicFromResponseType(rt)
%HARMONICFROMRESPONSETYPE 'mean' -> 0, 'F1' -> 1, 'F2' -> 2; [] when unparseable.
%   The inverse of the writer's derivation; anything else is not guessed.
h = [];
if isempty(rt)
    return;
end
rt = strtrim(lower(char(rt)));
if strcmp(rt, 'mean')
    h = 0;
    return;
end
if numel(rt) >= 2 && rt(1) == 'f'
    tail = rt(2:end);
    if all(isstrprop(tail, 'digit'))
        h = str2double(tail);
    end
end
end

function b = subBlock(bodyStruct, name)
b = struct();
if isstruct(bodyStruct) && isscalar(bodyStruct) && isfield(bodyStruct, name) ...
        && isstruct(bodyStruct.(name)) && isscalar(bodyStruct.(name))
    b = bodyStruct.(name);
end
end

function s = charAny(block, names)
%CHARANY First present name, as char (snake + camelCase: universalRenames
%   does not rename the sub-fields of a nested structure).
s = '';
for k = 1:numel(names)
    if isfield(block, names{k})
        v = block.(names{k});
        if ischar(v)
            s = v; return;
        elseif isstring(v) && isscalar(v)
            s = char(v); return;
        end
    end
end
end

function v = numAny(block, names)
%NUMANY First present name, value as-is ([] when absent).
v = [];
for k = 1:numel(names)
    if isfield(block, names{k})
        v = block.(names{k});
        return;
    end
end
end
