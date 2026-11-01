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
%     - entity            the element itself (id preserved; name -> `name`,
%                         exactly; name/reference -> local_identifier
%                         '<name> | <reference>').
%     - term_assertion(s) its kind, nothing dropped: `type` -> variable
%                         "element type", unless the device kind alone
%                         rebuilds it (THE DEVICE KIND, below);
%                         `ndi_element_class` -> variable "ndi element class"
%                         (the MATLAB reconstruction handle; kept so it is not
%                         lost -- reshaping it into a typed kind is a needs-NDI
%                         companion, the same disposition as the config-class
%                         `ndi_*_class` fields).
%     - term_assertion    a device's kind, variable NCIT:C178920 "Equipment
%                         Type" (the binding registry's subject-defining
%                         variable for a device's finer kind): every device
%                         has one (did2.convert.elementDeviceKind).
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
%     base.name                -> nothing: '' is what ndi.element/newdocument
%                                 writes, and the round trip rebuilds ''. A
%                                 non-empty one is carried, malformed
%                                 (carry-149; Decided by Jess Haley,
%                                 2026-10-30 [element name kept apart,
%                                 base.name carried]): the entity's one
%                                 `name` holds element.name
%     element.name             -> entity.name, exactly (Decided by Jess Haley,
%                                 2026-10-29 [element name and reference
%                                 stored apart]); not written when empty
%     element.name, element.reference -> entity.local_identifier,
%                                 '<name> | <reference>' (did2.convert.
%                                 elementHandle; int2str for an integer, as
%                                 NDI's display form and
%                                 did2.convert.elementLocalIdentifier write
%                                 it). The round trip reads the reference as
%                                 what follows the known name, so a name
%                                 holding ' | ' or ' (ref ', and a
%                                 non-integer reference, rebuild exactly.
%                                 Carried only when both are empty
%                                 (carry-048) or the reference is neither one
%                                 number nor one text (carry-120)
%     element.type             -> the entity type (elementEntityType); a
%                                 device's kind, one Equipment Type assertion;
%                                 and the "element type" assertion where the
%                                 kind alone does not rebuild the word (none
%                                 for a sorted unit)
%     element.ndi_element_class -> the entity type (elementEntityType) and one
%                                 term assertion
%     element.direct           -> which lineage relation is written; for a
%                                 sorted unit on its probe, not written:
%                                 rebuilt as 0 (unitFollowsItsProbe)
%     depends_on subject_id, underlying_element_id -> the lineage relation; a
%                                 sorted unit's subject_id is not written:
%                                 rebuilt from its probe's (unitFollowsItsProbe)
%     depends_on jrclust_clusters_id -> a prov:wasDerivedFrom relation
%
%   THE ENTITY TYPE (elementEntityType): Decided by Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md, [element types have no default]
%   (2026-10-26: a fixed list, NO default) and [element types batch 1] ..
%   [element types batch 4] (2026-10-30), which replace the earlier lists
%   ([electrode spellings and imaging types are devices], [event lines and
%   environment probes are devices], [imaging probes are microscopes or
%   carried] for wide-field and brightfield), and [stimulator is SNOMED CT
%   Stimulator] (2026-10-30), which replaces item (4) of batch 4:
%     on an ndi.probe.* class, a device: n-trode, patch, patch-Vm, patch-I,
%       patch-attached, sharp, sharp-Vm, sharp-Im, wide-field-imaging,
%       two-photon-imaging, one-photon-imaging, brightfield-imaging,
%       lick-spout, reward-well, intraoral-cannula, optogenetic-fiber, ecg,
%       eeg, accelerometer, thermometer, ppg, the literal `electrode-$`, and
%       `stimulator` (a visual-stimulus computer in vhlab, an electrical
%       stimulator in Marder)
%     `spikes`: the sorting run's label (the batch's neuron_extracellular
%       `quality_label`, did2.convert.unitQualityLabels): single -> cell,
%       multi -> Group; no label carried (carry-062, [unlabelled units need
%       a map]); Kilosort/phy labels per [sorter labels map]
%     `ensemble` -> Group
%     carried whole as v1, needs_mapping (carry-063), [element types batch
%       4]: `electrode-<spec>` and `<prefix>_electrode-<spec>` (not keys of
%       probetype2object.json; NDI's probestruct2probe throws on them),
%       `event` (vhlab's sync line), Haley `position` /
%       `distance`, a derived copy (a probe type on a class that is not
%       ndi.probe.*), `neuron`, `cell`, `field`, `lfp`, `madeup`, '',
%       `sharp-I`, `display`, `stim-n-trode`, `n-LED` and any other string
%     [migrator writes the registry spelling] (2026-10-26) the type is written
%       as the registry names it: `Group` (NCIT:C43359), not `group`
%
%   THE DEVICE KIND: Decided by Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md, [element type is a device kind term]
%   (2026-10-27) and [element types batch 1] .. [element types batch 3]
%   (2026-10-30), [element types batch 4] (2), [stimulator is SNOMED CT
%   Stimulator] (2026-10-30): every device gets one
%   Equipment Type assertion, its kind from did2.convert.elementDeviceKind
%   (the table, with each row's decision). The "element type" assertion is
%   REPLACED by it where the kind alone rebuilds the v1 word
%   (did2.convert.elementTypeOfKind: n-trode, electrode-$, lick-spout,
%   reward-well, intraoral-cannula, optogenetic-fiber, ecg, eeg,
%   accelerometer, thermometer, ppg, stimulator). It is STILL WRITTEN:
%     - for a kind several types share (patch electrode, sharp electrode,
%       microscope): the recording or imaging mode goes on the recording
%       observation, which the batch pass mints, not this migrator
%       (did2.convert.resolveEpochProbemap writes the two decided ones as the
%       observation's method term: patch-attached OBI:0002179,
%       brightfield-imaging EMPTY:0000300); the voltage, current, one-photon,
%       two-photon and wide-field mode terms are not decided yet ([element
%       types batch 1], [element types batch 2]), and an element's round trip
%       reads no observation, so the word is kept here for every type of a
%       shared kind ((iii) of [element type is a device kind term]: "until a
%       type has its term, the migrator keeps writing the current statement");
%     - for an ensemble (no device kind), which
%       did2.convert.resolveEpochProbemap keys its epochs on.
%   It is NOT written for a sorted unit: [cell spellings are one meaning] and
%   [cell spellings amended] (Decided by Jess Haley, 2026-10-27, did-schema
%   did_v2_go_forward_class_audit.md) -- "the v1 element type strings
%   `spikes`, `neuron` and `cell` are not kept as a statement or a note"; the
%   unit becomes the entity type [sorted units are cells or groups] gives it,
%   and the round trip and the readers (resolveEpochProbemap, NDI-matlab's
%   ndi.vintage.elementTypeOf) read `spikes` back from that entity type.
%   The "ndi element class" assertion is still written ([ndi element class
%   not kept] waits on NDI-matlab's readers, its Build pending line).
%
%   AN N-TRODE'S NUMBER OF ELECTRODES (nTrodeElectrodeCount): Decided by Jess
%   Haley, 2026-10-29 [n-trode count from the channel list], did-schema
%   V_eta_go_forward_class_audit.md -- "the 'number of electrodes' of an
%   n-trode ([n-trode is a multielectrode array], [number of electrodes
%   minted]) is the count of channels its epochprobemap `devicestring` names
%   ..., cross-checked against the sites of its `probe_geometry` /
%   `site2channelmap` where one exists; when they disagree the device is
%   carried as v1 under a `needs_mapping` register row". The v1 element holds
%   no count; did2.convert.nTrodeElectrodeCounts indexes the batch's
%   epochprobemap rows (epochfiles_ingested) and geometry documents before
%   the first migrator runs. An n-trode device whose rows name one channel
%   count gets one assertion, variable EMPTY:0000408 "number of electrodes",
%   value kind count. When its geometry's site count differs it is carried
%   whole as v1, needs_mapping, carry-156. With no channel list in the batch,
%   or rows naming different counts, no count is written (nothing is
%   invented); each converted n-trode is noted `ntrode_electrode_count` with
%   which of these it was.
%
%   A SORTED UNIT ON ITS PROBE (unitFollowsItsProbe): Decided by Jess Haley,
%   2026-10-27, [unit direct and subject rebuild from the probe]: a unit with
%   an underlying element is written without `direct` and `subject_id`; the
%   round trip rebuilds `direct` as 0 and `subject_id` as the underlying
%   element's subject (did2.convert.elementSubjects, the batch's v1
%   elements). A unit whose `direct` is not 0, or whose subject_id is not its
%   probe's, is carried whole as v1, malformed (carry-120: a value no NDI
%   writer produces; ndi.element copies the underlying element's subject).
%   A unit whose probe is not a v1 element of the batch cannot be checked or
%   rebuilt: it is carried whole as v1, needs_mapping (carry-151, [unit with
%   no probe in the batch carried], Jess Haley, 2026-10-29).

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

% [element name and reference stored apart] (Jess Haley, 2026-10-29): the v1
% name, exactly, is the entity's `name`; `local_identifier` keeps the
% name-and-reference handle ('<name> | <reference>', [element local identifier
% is name and reference], 2026-10-26), and the round trip reads the reference
% as what follows the known name (did2.convert.elementHandle /
% elementNameReferenceApart). A name that itself reads as a pair, or a
% non-integer reference, now converts (no longer carried as unpackable).
nameText = '';
if ischar(name) || (isstring(name) && isscalar(name)); nameText = char(name); end
[localId, problem] = did2.convert.elementHandle(name, reference);
if ~isempty(problem)
    switch problem
        case 'empty'
            row = '[carry-048] needs_mapping: ';
        otherwise
            row = '[carry-120] malformed: ';
    end
    % carry-register: carry-048 (no name and no reference: the identifier
    % would be invented); carry-120 (a name that is not text, or a reference
    % that is neither one number nor one text: NDI-matlab main 441530d0
    % +ndi/element.m shows `reference` with int2str and searches it with
    % 'exact_number', so its writer stores one number)
    did2.convert.reportNote('carried_as_v1', 'element', elementId, ...
        sprintf('%selement.name "%s" / element.reference "%s" (no local_identifier)', ...
        row, nameText, refText(reference)));
    v2Body = {preBody};
    return;
end
% The entity has ONE `name`, and [element name and reference stored apart]
% gives it the element's v1 name. A non-empty v1 base.name then has no field
% of its own. ndi.element/newdocument writes base.name '' (NDI-matlab main
% 441530d0, +ndi/element.m newdocument sets element.* only), so a non-empty
% one is a value no NDI writer produces: Decided by Jess Haley, 2026-10-30
% [element name kept apart, base.name carried] (did-schema
% V_eta_go_forward_class_audit.md), the element is carried whole as v1,
% malformed.
baseName = jBaseName(preBody);
if ~isempty(baseName)
    % carry-register: carry-149 (an element whose base.name is not empty)
    did2.convert.reportNote('carried_as_v1', 'element', elementId, ...
        sprintf(['[carry-149] malformed: base.name "%s" (the entity''s `name` holds ' ...
        'element.name "%s"; [element name kept apart, base.name carried])'], baseName, nameText));
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
if isSortedUnit(type) && ~isempty(underlyingId)
    [why, unchecked] = unitFollowsItsProbe(getField(block, 'direct'), specimenId, underlyingId);
    if ~isempty(why)
        % carry-register: carry-120 (a value no NDI writer produces)
        did2.convert.reportNote('carried_as_v1', 'element', elementId, why);
        v2Body = {preBody};
        return;
    end
    if ~isempty(unchecked)
        % the probe is not in the batch, so the subject cannot be rebuilt from
        % it. [unit with no probe in the batch carried] (Decided by Jess
        % Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md): such
        % a unit "is carried whole as v1 under a register row instead of
        % converting with its subject unchecked". It converted (subject
        % unchecked, note `unit_probe_not_in_batch`) before.
        % carry-register: carry-151
        did2.convert.reportNote('carried_as_v1', 'element', elementId, ...
            ['[carry-151] needs_mapping: sorted unit (unit_probe_not_in_batch): ' ...
            unchecked ' ([unit with no probe in the batch carried])']);
        v2Body = {preBody};
        return;
    end
end

% --- an n-trode's number of electrodes ([n-trode count from the channel list])
electrodeCount = [];
if strcmp(entityType, 'device') && strcmp(strtrim(type), 'n-trode')
    [electrodeCount, why] = nTrodeElectrodeCount(elementId);
    if ~isempty(why)
        % carry-register: carry-156 (its channel count and its geometry's
        % site count disagree)
        did2.convert.reportNote('carried_as_v1', 'element', elementId, why);
        v2Body = {preBody};
        return;
    end
end

% --- the element as an entity (id preserved) -------------------------------
% did-schema #88: one `entity` class with a bound `type`
% (V_eta_entity_composition_plan.md sec. 4), read off the v1 `type` and
% `ndi_element_class` by elementEntityType (decided, above).
subjectDoc = jEntity(preBody, entityType, ...
    struct('local_identifier', localId, 'name', nameText), 'Id', elementId);

bodies = {subjectDoc};

% --- kind assertions (nothing dropped) --------------------------------------
[kindTerm, kindVariable] = did2.convert.elementDeviceKind(type);
isDevice = strcmp(entityType, 'device') && ~isempty(kindTerm);
% a sorted unit (entity type cell or Group) keeps no `element type` assertion:
% [cell spellings are one meaning], [cell spellings amended] (header)
isUnit = isSortedUnit(type) && any(strcmp(entityType, {'cell', 'Group'}));
if ~isempty(type) && ~isUnit ...
        && ~(isDevice && strcmp(did2.convert.elementTypeOfKind(kindTerm.node), type))
    % the v1 word exactly as v1 wrote it: a registered term is taken only when
    % its name IS the word. jLabel matches the registry ignoring case, and since
    % [five probe kinds from NCIT] registered NCIT:C88166 "Accelerometer" it
    % turned `accelerometer` into "Accelerometer", which does not rebuild
    typeTerm = jLabel(type);
    if ~strcmp(char(typeTerm.name), type)
        typeTerm = did2.build.term('', type);
    end
    bodies{end+1} = jStatement(preBody, 'assertion', elementId, ...
        jLabel('element type'), typeTerm, 'ValueKind', 'term');
end
if ~isempty(ndiClass)
    bodies{end+1} = kindAssertion(preBody, elementId, 'ndi element class', ndiClass);
end
if isDevice
    bodies{end+1} = jStatement(preBody, 'assertion', elementId, ...
        kindVariable, kindTerm, 'ValueKind', 'term');
end
if ~isempty(electrodeCount)
    % [n-trode is a multielectrode array]: "its number of electrodes as a
    % statement on the device"; [number of electrodes minted]: EMPTY:0000408
    bodies{end+1} = jStatement(preBody, 'assertion', elementId, ...
        jLabel('number of electrodes'), did2.build.valueCell('count', electrodeCount), ...
        'ValueKind', 'count');
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
%   Decided by Jess Haley (header): [element types have no default],
%   [element types batch 1] .. [element types batch 4], [sorted units are
%   cells or groups], [unlabelled units need a map], [sorter labels map].
%   Types are compared exactly as NDI writes them (probestruct2probe matches
%   its keys exactly), edge blanks aside.
t = '';
why = '';
ty = strtrim(char(elementType));
isProbeClass = startsWith(strtrim(char(ndiClass)), 'ndi.probe.');
% the device types: every type with a decided device kind
[~, ~, kinds] = did2.convert.elementDeviceKind('');
if any(strcmp(ty, kinds(:, 1)))
    if isProbeClass
        t = 'device';
    else
        why = sprintf(['[carry-063] needs_mapping: element type "%s" is a probe type ' ...
            'on class "%s", not ndi.probe.* (a derived copy of its probe)'], ty, char(ndiClass));
    end
    return;
end
switch ty
    case 'spikes'
        label = did2.convert.unitQualityLabels('get', elementId);
        % [sorter labels map] (Decided by Jess Haley, 2026-10-27, did-schema
        % V_eta_go_forward_class_audit.md): a unit whose only label is a
        % Kilosort/phy one maps -- `good` (the curator's mark for a
        % well-isolated single unit) to a single unit, a `cell`; `mua` to a
        % multi-unit, a `group`; a `noise` unit is not a unit and is carried
        % whole as v1, needs_mapping (it narrows [unlabelled units need a
        % map], so it cites carry-062)
        switch label
            case {'single', 'good'}
                t = 'cell';
            case {'multi', 'mua'}
                t = 'Group';
            case 'noise'
                why = sprintf(['[carry-062] needs_mapping: sorted unit (type "%s") ' ...
                    'labelled "noise" by its sorting run: not a unit ([sorter labels map])'], ty);
            otherwise
                if isempty(label)
                    label = 'none';
                end
                why = sprintf(['[carry-062] needs_mapping: sorted unit (type "%s") ' ...
                    'with no single/multi label from its sorting run (label: %s)'], ty, label);
        end
    case 'ensemble'
        t = 'Group';
    otherwise
        % [element types batch 4]: the electrode spellings, event,
        % position, distance, neuron, cell and every other string
        why = sprintf(['[carry-063] needs_mapping: element type "%s" (class "%s") ' ...
            'is not on the element type list ([element types batch 4])'], ty, char(ndiClass));
end
end

function [count, why] = nTrodeElectrodeCount(elementId)
%NTRODEELECTRODECOUNT The number of electrodes of the n-trode ELEMENTID, from
%   the channel list of its epochprobemap rows ([n-trode count from the
%   channel list], Jess Haley, 2026-10-29), or [] when it cannot be read.
%   WHY is the carry note (carry-156) when that count and its geometry's
%   site count disagree, else ''. Notes `ntrode_electrode_count` otherwise.
count = [];
why = '';
info = did2.convert.nTrodeElectrodeCounts('get', elementId);
c = info.channel_counts;
sites = info.site_counts;
if isempty(c)
    if info.rows > 0
        what = sprintf('not written: its %d epochprobemap row(s) name no channels that parse', ...
            info.rows);
    else
        what = 'not written: no epochprobemap row of it in the batch';
    end
elseif ~isscalar(c)
    what = sprintf(['not written: its epochprobemap rows name different channel ' ...
        'counts (%s)'], strjoin(arrayfun(@int2str, c, 'UniformOutput', false), ', '));
elseif ~isempty(sites) && any(sites ~= c)
    why = sprintf(['[carry-156] needs_mapping: n-trode: its epochprobemap channel ' ...
        'list names %d channel(s), its probe_geometry / site2channelmap %s site(s) ' ...
        '([n-trode count from the channel list])'], c, ...
        strjoin(arrayfun(@int2str, sites, 'UniformOutput', false), ' / '));
    return;
else
    count = c;
    what = 'written from the epochprobemap channel list';
    if ~isempty(sites)
        what = [what ', equal to its geometry''s sites'];
    end
end
did2.convert.reportNote('ntrode_electrode_count', 'element', elementId, what);
end

function tf = isSortedUnit(elementType)
tf = any(strcmp(strtrim(char(elementType)), {'spikes', 'neuron', 'cell'}));
end

function [why, unchecked] = unitFollowsItsProbe(direct, subjectId, underlyingId)
%UNITFOLLOWSITSPROBE '' when a sorted unit's `direct` and `subject_id` are
%   what the round trip rebuilds from its probe ([unit direct and subject
%   rebuild from the probe]), else the carry note. UNCHECKED is a note when
%   the probe is not a v1 element of the batch, so the subject cannot be
%   compared.
why = '';
unchecked = '';
if ~(isempty(direct) || ((islogical(direct) || isnumeric(direct)) && isscalar(direct) ...
        && direct == 0))
    why = sprintf(['[carry-120] malformed: sorted unit on underlying element %s ' ...
        'states direct %s; NDI writes 0 for an element built on another'], ...
        underlyingId, directText(direct));
    return;
end
[probeSubject, found] = did2.convert.elementSubjects('get', underlyingId);
if ~found
    unchecked = sprintf(['underlying element %s is not a v1 element of the batch: ' ...
        'subject_id "%s" not checked against the probe''s'], underlyingId, subjectId);
elseif ~strcmp(probeSubject, subjectId)
    why = sprintf(['[carry-120] malformed: sorted unit''s subject_id "%s" is not ' ...
        'its underlying element %s''s subject "%s"; ndi.element copies the ' ...
        'underlying element''s subject'], subjectId, underlyingId, probeSubject);
end
end

function s = directText(v)
try
    s = jsonencode(v);
catch
    s = sprintf('<%s>', class(v));
end
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
