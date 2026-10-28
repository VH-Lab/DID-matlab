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
%   THE GUARDS, each returning the document UNCHANGED (1, 2, 3 and 5 carried,
%   kind malformed, carry-100; 1b carry-050; 4 handed on):
%     1. no `element_id` -> no subject (#88 requires `entity_id`).
%     1b. a `stimulus_response.stimulator_epochid` that differs from the
%        response's `element_epochid` (one equal to it is rebuilt), or input
%        edges whose names do not rebuild from their classes (carry-100); see
%        THE 2026-10-27 DECISIONS below.
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
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (NDI stimulus_response_scalar.json + stimulus_response.json
%   + base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   ndi.app.stimulus.tuning_response/compute_stimulus_response_scalar writes
%   it): no universalRenames, no superclass migrators (there are none for
%   `stimulus_response` or `base`). Edges are read by name in either v1 key
%   (`value`, the older `id`; jDependency); identity through jRawBody for a
%   legacy-only `ndi_document`; a carry or a passthrough is the untouched v1
%   source. What universalRenames would have discarded (a depends_on
%   `version` or a second, different id; an `ndi_document` beside `base`; an
%   `app` name conflict; a camelCase twin of a field read here) is carried,
%   carry-049, as the renamed path carried it. Every v1 field and where it
%   goes is the MAPPING above; did2.convert.roundtrip.stimulus_response_scalar
%   rebuilds the v1 document and testRawV1RoundTripStimulusResponse compares.
%
%   THE 2026-10-27 DECISIONS (Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md), which supersede the MAPPING rows above
%   for the two edges and the guards:
%     [response links: epoch rebuilt, control as input] ("29 yes"): the
%       stimulator epoch is not written: it equals the response's epoch on its
%       time anchor (`element_epochid`), and the round trip rebuilds it from
%       that; a response whose `stimulator_epochid` differs from its
%       `element_epochid` is carried (carry-050). The control
%       (`stimulus_control_id`) is an `input_id` of the calculation, after the
%       presentation (NDI's second pass turns the control record into the
%       pairing `calculation`, id preserved, [control pairing is a
%       calculation], so the edge keeps resolving). Its v1 names are rebuilt
%       from the classes of the documents they point at ([input names rebuild
%       from the input class]; did2.convert.inputEdgeNames): a response whose
%       input names do not rebuild (e.g. a control and no presentation) is
%       carried, kind malformed (carry-100).
%     [unreadable responses are malformed] ("5 yes"): a response the migrator
%       cannot read (guards 1, 2, 3 and 5 below: no element link, an unknown
%       response type, no response values, a stimid list of another length) is
%       carried whole as v1, kind malformed, citing the generic malformed row
%       (carry-100). Guard 4 (an epoch with no epoch document yet) is not
%       unreadable: it is the pass-1 hand-on epochMint re-calls, unchanged.

arguments
    preBody (1,1) struct
end

RESPONSE_METHOD = 'ndi.app.stimulus.tuning_response';

% READS RAW v1 (did2.convert.rawV1Classes). PREBODY is the document exactly as
% v1 wrote it; every read below is of BODY (PREBODY, with a legacy-only
% identity block read into `base` by jRawBody), and every carry or passthrough
% returns PREBODY untouched. First, what universalRenames would have discarded
% on the renamed path, which carried such a document before any migrator ran
% (carry-049, [renames carry is temporary]): carried the same way here.
collision = jResponseRenameCollisions(preBody, {'stimulus_response_scalar', 'responseType', 'response_type'; ...
    'stimulus_response', 'elementEpochid', 'element_epochid'; ...
    'stimulus_response', 'stimulatorEpochid', 'stimulator_epochid'});
if ~isempty(collision)
    % carry-register: carry-049 (the renamed path carried this collision)
    did2.convert.reportNote('carried_as_v1', 'stimulus_response_scalar', ...
        sourceIdText(preBody), ['[carry-049] universalRenames would discard: ' ...
        strjoin(collision, ', ')]);
    bodies = {preBody};
    return;
end
body = identityBody(preBody);

blk  = subBlock(body, 'stimulus_response_scalar');
resp = subBlock(blk, 'responses');

subjectId = jSubjectOf(body, {'element_id'});
harmonic  = harmonicFromResponseType(charAny(blk, {'response_type', 'responseType'}));
realPart  = numAny(resp, {'response_real', 'responseReal'});
% [unreadable responses are malformed] (Jess Haley, 2026-10-27): guards 1-3
unreadable = {};
if isempty(subjectId)
    unreadable{end+1} = 'no element_id edge';
end
if isempty(harmonic)
    unreadable{end+1} = sprintf('response_type "%s" is not mean or F<n>', ...
        charAny(blk, {'response_type', 'responseType'}));
end
if isempty(realPart)
    unreadable{end+1} = 'no responses.response_real';
end
if ~isempty(unreadable)
    bodies = carryMalformed(preBody, body, unreadable);
    return;
end

% [response links: epoch rebuilt, control as input] (Jess Haley, 2026-10-27):
% the stimulator epoch is left unwritten when it is the response's own epoch
% (the round trip rebuilds it from `element_epochid`); one that differs is
% carried, as every stated one was before (carry-050).
srBlock = subBlock(body, 'stimulus_response');
stimEpoch = charAny(srBlock, {'stimulator_epochid', 'stimulatorEpochid'});
if ~strcmp(stimEpoch, charAny(srBlock, {'element_epochid', 'elementEpochid'}))
    % carry-register: carry-050
    did2.convert.reportNote('carried_as_v1', 'stimulus_response_scalar', ...
        char(body.base.id), ['[carry-050] unplaced: stimulus_response.stimulator_epochid ' ...
        '(differs from element_epochid)']);
    bodies = {preBody};
    return;
end
% the inputs, presentation then control, named back from their classes
[inputs, inputNames] = responseInputs(body);
if ~isequal(inputNames, did2.convert.inputEdgeNames(inputs, ...
        {'stimulus_presentation_id', 'stimulus_control_id'}))
    bodies = carryMalformed(preBody, body, {sprintf(['input edges %s do not rebuild ' ...
        'from the classes they point at: [input names rebuild from the input class]'], ...
        strjoin(inputNames, ', '))});
    return;
end

% GUARD 4 -- the epoch gate, read through the same reader epochMint mints from.
epochString = epochStringOf(body, 'stimulus_response.element_epochid');
epochDocId  = jEpochDocId(body);
if ~isempty(epochString) && isempty(epochDocId)
    bodies = {preBody};
    return;
end

% GUARD 5 -- the reading dimension must describe the value it indexes
% ([unreadable responses are malformed]).
stimid = numAny(resp, {'stimid'});
if ~isempty(stimid) && numel(stimid) ~= numel(realPart)
    bodies = carryMalformed(preBody, body, {sprintf('%d stimid for %d readings', ...
        numel(stimid), numel(realPart))});
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
        'SessionId', jSid(body), 'CreationTimestamp', jStamp(body), ...
        'Validate', false);
else
    anchor = jSessionAnchor(body, 'during');
end

[software, swId, execEnv] = jSoftwareFromApp(body);
[runDocs, osId, interpreterId] = jRunEntities(body, execEnv);
if isempty(swId)
    [software, swId] = jSoftware(RESPONSE_METHOD, '', '', jSid(body), jStamp(body));
end

% The presentation, then the control ([response links: epoch rebuilt, control
% as input], Jess Haley, 2026-10-27; superseding "responses point at the
% presentation only" of [control as covariate], 2026-10-22): INPUTS, read
% above by responseInputs.

methodId = jDependency(body, 'stimulus_response_scalar_parameters_id');
methodOpt = {};
if isempty(methodId)
    methodOpt = {'Method', jLabel(RESPONSE_METHOD)};   % method.term
else
    methodOpt = {'MethodId', methodId};
end

calc = jStatement(body, 'calculation', subjectId, ...
    jLabel('stimulus response'), value, ...
    'ValueKind', 'harmonic_component', ...
    'Dimensions', dims, 'Covariates', covs, ...
    'TimeReferenceIds', {anchor.base.id}, ...
    'InstrumentId', jDependency(body, 'stimulator_id'), ...
    'InputIds', inputs, ...
    'SoftwareId', swId, ...
    'OperatingSystemId', osId, ...
    'InterpreterId', interpreterId, ...
    methodOpt{:}, ...
    'Id', char(body.base.id));   % id preserved -> inbound references resolve

bodies = [{calc, anchor}, software, runDocs];

% The v1 `stimulus_control_id` edge: ONE note per response document this
% migrator converts, as Jess Haley 2026-10-22 decided ([covariate rules named],
% answer "A" to 6.4), so the note count stays the denominator. DETAIL 'input'
% when the edge is an input_id ([response links: epoch rebuilt, control as
% input], 2026-10-27), 'none' when it was empty; 'dropped' is no longer
% written.
controlDetail = 'none';
if ~isempty(jDependency(body, 'stimulus_control_id'))
    controlDetail = 'input';
end
did2.convert.reportNote('stimulus_control_id', 'stimulus_response_scalar', ...
    char(body.base.id), controlDetail);
end

function bodies = carryMalformed(preBody, body, why)
%CARRYMALFORMED Carry a response the migrator cannot read whole as v1, kind
%   malformed ([unreadable responses are malformed], Jess Haley, 2026-10-27),
%   citing the generic malformed row.
id = '';
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, 'id')
    id = char(body.base.id);
end
if isempty(id)
    id = sourceIdText(preBody);
end
% carry-register: carry-100
did2.convert.reportNote('carried_as_v1', 'stimulus_response_scalar', id, ...
    ['[carry-100] malformed: ' strjoin(why, '; ')]);
bodies = {preBody};
end

function [ids, names] = responseInputs(body)
%RESPONSEINPUTS The response's input edges, presentation then control, with
%   their v1 names.
ids = {};
names = {};
for nm = {'stimulus_presentation_id', 'stimulus_control_id'}
    v = jDependency(body, nm{1});
    if ~isempty(v)
        ids{end+1} = v; %#ok<AGROW>
        names{end+1} = nm{1}; %#ok<AGROW>
    end
end
end

% ===================== helpers =============================================

function body = identityBody(preBody)
%IDENTITYBODY The raw v1 document with its identity where the builders read
%   it. A document with a `base` block is returned as it is. A pre-2023
%   document whose only identity block is the legacy `ndi_document` (and which
%   states an id) gets a `base` from it through jRawBody, as universalRenames'
%   wholesale move gave the migrator before the switch. A document with no
%   readable id is returned as it is, so it fails (or passes through) exactly
%   where it did on the renamed path.
body = preBody;
b = did2.convert.v1read.readBase(preBody);
if strcmp(b.source, 'ndi_document') && any(strcmp(b.present, 'id'))
    body = jRawBody(preBody, 'stimulus_response_scalar');
end
end

function id = sourceIdText(preBody)
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
end

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
