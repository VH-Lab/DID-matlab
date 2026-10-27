function v2Body = element(preBody)
%ELEMENT Brainstorm-J migrator: did_v1 element -> an `entity` (+ kind
%   assertions + the raw-recording observation + a lineage relation). V_eta
%   retires the recording-side `element` class: any identifiable thing -- an
%   organism, a device/probe, a derived signal or sorted unit -- is an `entity`
%   with a `type` (a device for a probe, a cell or group for a sorted unit, a
%   group for an ensemble; anything else carried: elementEntityType, decided
%   2026-10-26, below). The element document therefore
%   becomes an `entity` with its id PRESERVED, so the ~50 classes that reference
%   it (`element_id` / `underlying_element_id` / `stimulator_id`) keep resolving
%   -- now to an entity.
%
%   1 -> N:
%     - entity            the element itself (id preserved; name/reference ->
%                         local_identifier '<name> | <reference>').
%     - term_assertion(s) its kind, nothing dropped: `type` -> variable
%                         "element type"; `ndi_element_class` -> variable "ndi
%                         element class" (the MATLAB reconstruction handle; kept
%                         so it is not lost -- reshaping it into a typed kind is a
%                         needs-NDI companion, the same disposition as the
%                         config-class `ndi_*_class` fields).
%     - <modality>_observation + sampled_body + session anchor
%                         NO LONGER EMITTED HERE, SINCE 2026-10-21 (Jess Haley,
%                         V_eta_recording_observation_plan.md: one observation
%                         per element PER EPOCH, its epoch files as data
%                         bodies). An element names no epochs and carries no
%                         files, so the observation is minted by the batch pass
%                         did2.convert.resolveEpochProbemap (epochs with a cached
%                         `epochfiles_ingested`) or the NDI second pass (the file
%                         navigator); until then `observes` is KEPT. Below is the
%                         pass-1 shape as it was:
%                         THE RAW RECORDING (open item #30, SIGNED 2026-08-10).
%                         For a DIRECT recording element the signal itself is now
%                         a typed observation OF THE SPECIMEN taken WITH this
%                         element: subject_id = the specimen, instrument_id = this
%                         element-subject (T7), variable = the modality from
%                         `type`, value = a sampled_body. Assembled by
%                         jRecordingObservation; the type -> modality map and its
%                         denominator are in jRecordingModality. Before this, the
%                         raw signal migrated as loose device-attached pieces with
%                         no typed observation and no modality/units at all.
%     - directed_relation the specimen lineage:
%                         * a derived element (has `underlying_element_id`, or
%                           `direct` = 0) -> `derived_from` its underlying element
%                           (safe computational lineage);
%                         * a direct device (`direct` = 1) -> `observes` the
%                           specimen (the instrument-agent role, J's
%                           instrument_id->subject).
%                         `part_of` (the anatomical claim) is NOT emitted
%                         automatically: a sorted neuron is part of the specimen
%                         but a derived signal is not, and we cannot tell them
%                         apart from `type` without an ontology mapping -- so that
%                         promotion is left to curation rather than fabricated.
%
%   ---------------------------------------------------------------------
%   `observes` RETIRES -- BUT ONLY WHERE ITS REPLACEMENT IS PRESENT
%   ---------------------------------------------------------------------
%   The signed decision: "the loose `probe observes specimen` relation RETIRES in
%   favour of the `instrument_id` edge". It does, and it does so exactly where
%   that edge got written -- jRecordingObservation returns RETIREOBSERVES true
%   only when it emitted an observation carrying `instrument_id`. Where it did
%   not (a stimulator-class element, whose delivery is a manipulation and whose
%   instrument edge arrives with the stimulus model #31/#43; or an element type
%   Guard A could not resolve) the relation is KEPT, because dropping a link with
%   nothing standing in its place is data loss, not a retirement. Same shape as
%   the guarded passthroughs in fitcurve.m / openminds_stimulus.m.
%
%   NOTE FOR WHOEVER RUNS THE TEST SUITE NEXT:
%   tests/+did2/+unittest/testMigratorsJ.m carries
%   `testElementDirectDeviceObservesSpecimen`, which asserts the `observes`
%   relation for a direct 'n-trode' element. That type now resolves to a
%   voltage_observation, so the relation is gone and THAT TEST WILL FAIL. It
%   asserts the behaviour this decision retires, so it needs INVERTING, not
%   patching -- the same call as the three tests that had asserted the `epochid`
%   bug (CLAUDE.md: "A TEST WRITTEN FROM THE SAME PREMISE AS THE CODE CANNOT
%   CATCH THE CODE"). It is left alone here only because testMigratorsJ.m is
%   outside this change's file scope and is being edited concurrently.

%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (NDI element.json + base.json at the locked NDI-matlab
%   `main`, 3cb19a8, as ndi.element/newdocument writes it), identity through
%   jRawBody; a carry is the untouched v1 source. Every v1 field and where it
%   goes; did2.convert.roundtrip.element rebuilds the v1 document and
%   testRawV1RoundTripElement compares the two:
%
%     base.id / session_id / datestamp -> the entity's id / session edge /
%                                 creation_timestamp
%     base.name                -> entity.name when not empty ('', what
%                                 ndi.element/newdocument writes, writes
%                                 nothing; jBaseName; Decided by Jess Haley,
%                                 2026-10-27 [v1 name is the entity name])
%     element.name, element.reference -> entity.local_identifier,
%                                 '<name> | <reference>' (NDI's display form;
%                                 did2.convert.elementLocalIdentifier, the
%                                 mirror of NDI ndi.vintage's). Not reversible
%                                 (an empty name, a non-integer reference, a
%                                 reference-less name that reads as a pair):
%                                 carried (carry-048 / carry-055)
%     element.type, element.ndi_element_class -> the entity type
%                                 (elementEntityType) and one term assertion
%                                 each
%     element.direct           -> which lineage relation is written
%     depends_on subject_id, underlying_element_id -> the lineage relation
%     depends_on jrclust_clusters_id -> a prov:wasDerivedFrom relation
%
%   THE ENTITY TYPE (elementEntityType): Decided by Jess Haley, 2026-10-26,
%   did-schema V_eta_go_forward_class_audit.md --
%     [element types have no default]   a fixed list, NO default: a type not
%                                       on it, or a probe type on a class that
%                                       is not ndi.probe.*, is carried
%                                       (carry-063)
%     a registered probe type (NDI probetype2object.json at 3cb19a8: 24 keys)
%                                       on an ndi.probe.* class -> device; with
%       [electrode spellings and imaging types are devices]  `electrode-<spec>`
%                                       and `<prefix>_electrode-<spec>` too,
%                                       and the four imaging types
%       [event lines and environment probes are devices]  `event`,
%                                       `lick-spout`, `reward-well`,
%                                       `intraoral-cannula`
%     [sorted units are cells or groups]  `spikes`, `neuron`, `cell`: the
%                                       sorting run's label (the batch's
%                                       neuron_extracellular `quality_label`,
%                                       did2.convert.unitQualityLabels):
%                                       single -> cell, multi -> group
%     [unlabelled units need a map]     a sorted unit with no label is carried
%                                       (carry-062)
%     `ensemble` -> group

arguments
    preBody (1,1) struct
end

body = jRawBody(preBody, 'element');
v2Body = convertElement(body);
if isscalar(v2Body) && isequaln(v2Body{1}, body)
    v2Body = {preBody};   % a carry is the untouched v1 source
end
end

function v2Body = convertElement(preBody)
block = struct();
if isfield(preBody, 'element') && isstruct(preBody.element); block = preBody.element; end

elementId  = baseId(preBody);
name       = getField(block, 'name');
reference  = getField(block, 'reference');
type       = jGetChar(block, 'type');
ndiClass   = jGetChar(block, 'ndi_element_class');
isDirect   = isTruthy(getField(block, 'direct'));
specimenId   = depValue(preBody, 'subject_id');
underlyingId = depValue(preBody, 'underlying_element_id');
sortingRunId = depValue(preBody, 'jrclust_clusters_id');

% [element local identifier is name and reference] (Jess Haley, 2026-10-26):
% '<name> | <reference>', NDI's display form, read back by splitting at the last
% ' | '. [no invented values] / [generic stage is lossless]: an identifier
% that would not read back exactly is not written; the element is carried.
localId = '';
if isempty(name) || ischar(name) || (isstring(name) && isscalar(name))
    localId = did2.convert.elementLocalIdentifier(char(name), reference);
end
if isempty(localId)
    nameText = '';
    if ischar(name) || (isstring(name) && isscalar(name)); nameText = char(name); end
    row = '[carry-055] ';
    if isempty(nameText) && isEmptyRef(reference); row = '[carry-048] '; end
    % carry-register: carry-048 (no name and no reference); carry-055 (not
    % written reversibly as '<name> | <reference>')
    did2.convert.reportNote('carried_as_v1', 'element', elementId, ...
        sprintf('%sunplaced: element.name "%s" / element.reference "%s" (no reversible local_identifier)', ...
        row, nameText, refText(reference)));
    v2Body = {preBody};
    return;
end

[entityType, why] = elementEntityType(type, ndiClass, elementId);
if isempty(entityType)
    % carry-register: carry-062 (an unlabelled sorted unit); carry-063 (a type
    % with no entity type)
    did2.convert.reportNote('carried_as_v1', 'element', elementId, why);
    v2Body = {preBody};
    return;
end

% --- the element as an entity (id preserved) -------------------------------
% did-schema #88: one `entity` class with a bound `type`
% (V_eta_entity_composition_plan.md sec. 4), read off the v1 `type` and
% `ndi_element_class` by elementEntityType (decided, above).
subjectDoc = jEntity(preBody, entityType, ...
    struct('local_identifier', localId, 'name', jBaseName(preBody)), 'Id', elementId);

bodies = {subjectDoc};

% --- kind assertions (nothing dropped) --------------------------------------
if ~isempty(type)
    bodies{end+1} = kindAssertion(preBody, elementId, 'element type', type);
end
if ~isempty(ndiClass)
    bodies{end+1} = kindAssertion(preBody, elementId, 'ndi element class', ndiClass);
end

% --- the recording as a typed observation (#30, and #117 for spike trains) ---
% TWO ROLE ASSIGNMENTS, NOT ONE, and which applies is decided by `direct`.
%
% DIRECT (`direct` = 1) means the element feeds data straight through
% (element_schema.json: "Does this element directly feed data from an underlying
% element?"), and ndi.probe sets it to 1 by construction (+ndi/probe.m:47-50
% fills inputs{6} = 1). That is the signed #30 shape: the SPECIMEN is observed,
% WITH the electrode (T7).
%
% DERIVED (`direct` = 0) is a computed signal or a sorted unit, and until
% 2026-08-18 this branch emitted NOTHING -- the `if isDirect` below returned
% before jRecordingModality was ever consulted. THAT IS A CORRECTION TO
% V_eta_OPEN_WORK.md row #118, which says 'spikes' elements "take this path
% today", meaning Guard A's `modality unresolved` term_assertion. They do not
% and never did: Guard A is inside jRecordingObservation, and nothing derived
% reached it. Measured on 20211116: 21 of 23 elements are
% `type = 'spikes', direct = false, ndi_element_class = 'ndi.neuron'`, and each
% produced a subject, two kind assertions and a `derived_from` -- no observation
% of any kind, and no worklist entry either.
%
% A SPIKE TRAIN INVERTS THE ROLES. TEAM-SIGN-OFF [spike train leaf]
% (V_eta_ensemble_plan.md:218) makes the train an observation OF THE NEURON --
% and the neuron-subject is THIS element, whose id is preserved by the subject
% document minted above. The instrument is the probe underneath it. So the
% arguments are the mirror of the direct case, which is why
% jRecordingObservation's parameters were renamed to say `instrumentId` and
% `subjectId` rather than `elementId` and `specimenId`.
%
% Only 'spikes' takes the derived branch. Every other derived type falls
% through to jRecordingModality's `otherwise` and would surface as a
% `modality unresolved` worklist entry for a signal whose modality question is
% a different one (#118) -- so the branch is opened for the type that has a
% signature and no wider.
% 2026-10-21: jRecordingObservation still resolves the modality (and Guard A's
% worklist label) but EMITS NO OBSERVATION and never retires `observes`; the
% per-epoch observation with its file bodies is minted by the batch pass /
% NDI second pass, which also retires `observes` once it has a replacement.
recordingBodies = {};
retireObserves = false;
unresolvedLabel = '';
if isDirect
    [recordingBodies, retireObserves, unresolvedLabel] = jRecordingObservation( ...
        preBody, elementId, specimenId, type, ndiClass);
elseif strcmpi(strtrim(type), 'spikes')
    [recordingBodies, ~, unresolvedLabel] = jRecordingObservation( ...
        preBody, underlyingId, elementId, type, ndiClass);
    % `retireObserves` is deliberately DISCARDED here. It governs whether the
    % loose `observes` relation may be dropped now that `instrument_id` names
    % the instrument -- and the lineage branch below never emits `observes` for
    % a derived element anyway (it emits `derived_from` to the underlying
    % element). Threading it through would let a spike train silently change a
    % relation that belongs to a different decision.
end
if ~isempty(unresolvedLabel)
    % Guard A's queryable worklist entry, built from declared fields only --
    % see the jRecordingObservation header for why the signed
    % `modality_unresolved` flag has no schema home yet.
    bodies{end+1} = kindAssertion(preBody, elementId, 'modality unresolved', ...
        unresolvedLabel);
end

% --- the specimen / lineage relation ----------------------------------------
if ~isempty(underlyingId)
    bodies{end+1} = lineageRelation(preBody, elementId, underlyingId, 'derived_from');
elseif isDirect && ~isempty(specimenId)
    if ~retireObserves
        bodies{end+1} = lineageRelation(preBody, elementId, specimenId, 'observes');
    end
elseif ~isempty(specimenId)
    bodies{end+1} = lineageRelation(preBody, elementId, specimenId, 'derived_from');
end

% --- the sorting run a neuron was derived from ------------------------------
% ([neuron derived from its sorting run], Jess Haley, 2026-10-25) a sorted
% neuron whose `jrclust_clusters_id` names a JRCLUST run keeps that link as a
% `prov:wasDerivedFrom` relation from the neuron entity to the JRCLUST
% calculation, beside its `derived_from` the electrode. jrclust_clusters.m keeps
% the v1 id, so the edge resolves as written. It was dropped before (depValue
% read only `subject_id` and `underlying_element_id`).
if ~isempty(sortingRunId)
    bodies{end+1} = jEntityRelation(preBody, elementId, sortingRunId, ...
        'wasDerivedFrom', '', 'prov:wasDerivedFrom');
end

v2Body = [bodies, recordingBodies];
end

% ===================== builders ========================================

function a = kindAssertion(preBody, subjectId, variableName, valueName)
a = jStatement(preBody, 'assertion', subjectId, ...
    jLabel(variableName), jLabel(valueName), 'ValueKind', 'term');
end

function rel = lineageRelation(preBody, childId, parentId, relationName)
%LINEAGERELATION child --relationName--> parent (both entities).
%   `observes` is NOT in did-schema #88's relation set (dropped, #73 audit 2
%   D5). It is still written for the one branch that has no replacement (a
%   direct stimulator or unresolved element, whose instrument edge arrives with
%   the stimulus model), because dropping the probe -> specimen link with nothing
%   standing in its place is data loss. It validates only because the binding
%   conformance switch is off (#32). A SCHEMA QUESTION, reported with the port.
rel = jEntityRelation(preBody, childId, parentId, relationName);
end

function [t, why] = elementEntityType(elementType, ndiClass, elementId)
%ELEMENTENTITYTYPE The entity.type an element takes, or '' and the carry note.
%   Decided by Jess Haley, 2026-10-26 (header): [element types have no
%   default], [electrode spellings and imaging types are devices], [event lines
%   and environment probes are devices], [sorted units are cells or groups],
%   [unlabelled units need a map]. Types are compared exactly as NDI writes
%   them (probestruct2probe matches its keys exactly), edge blanks aside.
t = '';
why = '';
ty = strtrim(char(elementType));
isProbeClass = startsWith(strtrim(char(ndiClass)), 'ndi.probe.');
% NDI-matlab main 3cb19a8 src/ndi/ndi_common/probe/probetype2object.json
probeTypes = {'n-trode', 'electrode-$', 'patch', 'patch-Vm', 'patch-I', ...
    'patch-attached', 'sharp', 'sharp-Vm', 'sharp-Im', 'wide-field-imaging', ...
    'two-photon-imaging', 'one-photon-imaging', 'brightfield-imaging', ...
    'lick-spout', 'intraoral-cannula', 'optogenetic-fiber', 'reward-well', ...
    'stimulator', 'ecg', 'eeg', 'accelerometer', 'thermometer', 'ppg', 'event'};
isElectrodeSpelling = ~isempty(regexp(ty, '^([A-Za-z0-9]+_)?electrode-\S+$', 'once'));
if any(strcmp(ty, probeTypes)) || isElectrodeSpelling
    if isProbeClass
        t = 'device';
    else
        why = sprintf(['[carry-063] needs_mapping: element type "%s" is a probe type ' ...
            'on class "%s", not ndi.probe.* (a derived copy of its probe)'], ty, char(ndiClass));
    end
    return;
end
switch ty
    case {'spikes', 'neuron', 'cell'}
        label = did2.convert.unitQualityLabels('get', elementId);
        switch label
            case 'single'
                t = 'cell';
            case 'multi'
                t = 'group';
            otherwise
                if isempty(label)
                    label = 'none';
                end
                why = sprintf(['[carry-062] needs_mapping: sorted unit (type "%s") ' ...
                    'with no single/multi label from its sorting run (label: %s)'], ty, label);
        end
    case 'ensemble'
        t = 'group';
    otherwise
        why = sprintf(['[carry-063] needs_mapping: element type "%s" (class "%s") ' ...
            'is not on the element type list'], ty, char(ndiClass));
end
end

function tf = isEmptyRef(r)
tf = isempty(r) || ((ischar(r) || isstring(r)) && isempty(strtrim(char(r))));
end

function s = refText(r)
if ischar(r) || (isstring(r) && isscalar(r))
    s = char(r);
elseif isnumeric(r) && isscalar(r)
    s = num2str(r, 17);
elseif isempty(r)
    s = '';
else
    s = sprintf('<%s>', class(r));
end
end

function id = baseId(preBody)
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = preBody.base.id;
end
end

function v = getField(block, name)
v = [];
if isstruct(block) && isfield(block, name); v = block.(name); end
end

function tf = isTruthy(v)
tf = false;
if islogical(v) && ~isempty(v); tf = v(1);
elseif isnumeric(v) && ~isempty(v); tf = v(1) ~= 0;
elseif ischar(v); tf = any(strcmpi(strtrim(v), {'1', 'true', 'yes'})); end
end

function v = depValue(preBody, name)
v = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value); v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
            return;
        end
    end
end
end
