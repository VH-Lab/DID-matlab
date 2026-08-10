function tests = testMigratorsJRecordingObservation
%TESTMIGRATORSJRECORDINGOBSERVATION Brainstorm-J: the raw-recording observation.
%
%   Covers open item #30:
%
%     TEAM-SIGN-OFF [raw recording observation]  jess, 2026-08-10
%       (did-schema schemas/V_eta_recording_observation_plan.md:99)
%       "a raw continuous recording IS a typed `<modality>_observation` of the
%        SPECIMEN: `subject_id` = the specimen, `instrument_id` = the
%        electrode/probe in the instrument role (T7), `variable` = the modality
%        from the element/probe type, body = `sampled_body`, timing = the
%        existing epoch anchor; the loose `probe observes specimen` relation
%        RETIRES in favour of the `instrument_id` edge. Guard A stands: an
%        unmapped element type still yields a VALUED observation over a bare
%        self-describing `sampled_body` with a queryable `modality_unresolved`
%        flag -- never a `timeseries_observation` or `array` class -- and the
%        build gate is ZERO fallbacks on the real corpus. Multi-channel is ONE
%        observation with a channel axis, not N observations."
%
%   The build lives in migrators_j/element.m (the direct-element branch) plus
%   private/jRecordingObservation.m (the assembler) and
%   private/jRecordingModality.m (the type -> modality map and its denominator).
%
%   ---------------------------------------------------------------------
%   TWO PLACES WHERE THE BUILD DOES NOT MATCH THE SIGNED TEXT, AND WHY THE
%   TESTS ASSERT THE BUILD
%   ---------------------------------------------------------------------
%   1. GUARD A IS ONLY HALF-BUILDABLE TODAY. Its signed form needs a CONCRETE,
%      UNDIMENSIONED observation leaf and a `modality_unresolved` field. Neither
%      exists: `subject_observation` is declared abstract
%      (schemas/V_eta/stable/subject_observation.json) and
%      +did2/+schema/cache.m:507-511 raises
%      `did2:validation:abstractInstantiation` for any document naming an
%      abstract class, while every concrete `*_observation` leaf mixes in a
%      dimensioned data_type; and `grep -rn "modality_unresolved"
%      /home/user/DID-schema/schemas/` matches ONLY the two decision documents,
%      never a class or a field. Both are DID-schema changes, out of this
%      change's scope. So the unresolved path emits no fabricated dimensioned
%      observation and instead records the flag as a term_assertion on the
%      element-subject (variable 'modality unresolved', value = the type), and
%      KEEPS the `observes` relation so nothing is lost. Tested as built, below,
%      and flagged in the build report. THESE TESTS WILL NEED UPDATING when the
%      schema half lands -- that is the intended signal, not a defect.
%
%   2. `patch` AND `sharp` PRODUCE TWO OBSERVATIONS EACH. PROBE-TYPES.md
%      documents both as two channels of two DIFFERENT quantities (Vm and I).
%      Two quantities are two `variable`s, so they are two statements. The signed
%      multi-channel rule ("ONE observation with a channel axis") is about N
%      SITES OF ONE MODALITY, which is the n-trode/electrode-* case and is tested
%      as one observation. Recorded as a team question in the build report.
%
%   ---------------------------------------------------------------------
%   HOW THESE TESTS ARE DRIVEN
%   ---------------------------------------------------------------------
%   Through did2.convert.v1_to_v2, never the migrator function directly, so the
%   universalRenames pass runs exactly as it does on a real document. Bodies come
%   back as did2.document OBJECTS -- read with .get('dotted.path'). A depends_on
%   entry is spelled `value` on a body a migrator built and `document_id` after
%   universalRenames, so depValue below takes document_id when present and falls
%   back to value (the precedence in +did2/+validate/references.m:176-179).
%
%   NOT VERIFIED BY EXECUTION: there is no MATLAB in the authoring environment,
%   so these tests have never been run.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJRecordingObservation');

tests = functiontests(localfunctions);
end

% ===================== the mapped recording case ===========================

function testExtracellularProbeBecomesVoltageObservationOfTheSpecimen(testCase)
% The headline case. An n-trode probe (direct = 1) recording a specimen becomes a
% voltage_observation OF THE SPECIMEN taken WITH the electrode.
out = runJ(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));

obs = firstOfClass(out, 'voltage_observation');
verifyNotEmpty(testCase, obs, 'no voltage_observation was emitted for an n-trode');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'specimen_1');   % the SPECIMEN
verifyEqual(testCase, depValue(obs, 'instrument_id'), 'el_1');      % the electrode (T7)
verifyEqual(testCase, obs.get('subject_statement.variable').name, 'voltage');
verifyEqual(testCase, obs.get('subject_statement.storage_mode'), 'body');
% timing: the shared session 'during' anchor (the epoch join is the second pass)
verifyNotEmpty(testCase, depValue(obs, 'time_reference_1'));
anchor = firstOfClass(out, 'session_relative_reference');
verifyNotEmpty(testCase, anchor);
verifyEqual(testCase, depValue(obs, 'time_reference_1'), anchor.get('base.id'));
end

function testTheBodyValuesTheObservation(testCase)
% storage_mode 'body' has to point at a real sampled_body, and that body has to
% point back at THIS observation (sampled_body.statement is a required edge).
out = runJ(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
obs = firstOfClass(out, 'voltage_observation');
body = firstOfClass(out, 'sampled_body');
verifyNotEmpty(testCase, body, 'the observation is not valued by a sampled_body');
verifyEqual(testCase, depValue(body, 'statement'), obs.get('base.id'));
verifyEqual(testCase, body.get('sampled_body.datum').kind, 'array');
end

function testTheElementIdStaysOnTheSubjectAndTheObservationMintsAFreshId(testCase)
% ID PRESERVATION. ~50 v1 classes reference the element document and every one of
% them means "the recording element", which after migration is the SUBJECT.
% Moving that id onto the observation would silently re-point all of them (the
% 11,448-orphan shape). The observation is new, so nothing can dangle on it.
out = runJ(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
sub = firstOfClass(out, 'subject');
obs = firstOfClass(out, 'voltage_observation');
verifyEqual(testCase, sub.get('base.id'), 'el_1');
verifyNotEqual(testCase, obs.get('base.id'), 'el_1');
end

% ===================== multi-channel ======================================

function testMultiChannelProbeIsOneObservationWithAChannelAxis(testCase)
% SIGNED: a 32-site probe is ONE observation whose sampled_body carries a channel
% axis, NOT N observations.
out = runJ(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEqual(testCase, countOfClass(out, 'voltage_observation'), 1, ...
    'a multi-site probe must not fan out into one observation per site');
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 1);

body = firstOfClass(out, 'sampled_body');
axs = body.get('sampled_body.axes');
verifyEqual(testCase, numel(axs), 1);
verifyEqual(testCase, axs(1).name, 'channel');
verifyEqual(testCase, axs(1).kind, 'index');
% The EXTENT is deliberately absent: the channel count is not on the element
% document (PROBE-TYPES.md: for an n-trode it "is calculated from the number of
% channels specified in the device string", which lives in the epochprobemap).
% Writing a 0 here would be the spikewaves bug -- a body that cleanly describes
% an empty recording. This assertion is the tripwire against that.
verifyFalse(testCase, isfield(axs(1), 'length') && ~isempty(axs(1).length), ...
    'the channel axis invented a length the element document does not carry');
end

function testUnderscoredElectrodeSpellingAlsoResolves(testCase)
% +ndi/+daq/daqsystemstring.m:13 shows the epochprobemap form of a 4-channel
% extracellular recording as type 'extracellular_electrode-4', while
% probetype2object.json registers the stem as 'electrode-$' and
% +ndi/+database/+metadata_app/+fun/loadProbes.m:46 matches real data with
% regexp 'electrode-\d'. All three reach the same row.
out = runJ(elementDoc('ctx', 'extracellular_electrode-4', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEqual(testCase, countOfClass(out, 'voltage_observation'), 1);
body = firstOfClass(out, 'sampled_body');
axesOut = body.get('sampled_body.axes');
verifyEqual(testCase, axesOut(1).name, 'channel');
end

function testSingleChannelPipetteCarriesNoChannelAxis(testCase)
% PROBE-TYPES.md: patch-Vm is "single channel, specifies voltage recording".
% A single-channel body has no channel dimension to declare.
out = runJ(elementDoc('Vm_a', 'patch-Vm', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEqual(testCase, countOfClass(out, 'voltage_observation'), 1);
body = firstOfClass(out, 'sampled_body');
verifyError(testCase, @() body.get('sampled_body.axes'), ?MException, ...
    'a single-channel pipette body declared a channel axis');
end

% ===================== the retired `observes` relation =====================

function testObservesRelationIsGoneForAMappedRecordingElement(testCase)
% THE RETIREMENT. The instrument_id edge replaces it.
out = runJ(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyFalse(testCase, hasRelation(out, 'observes'), ...
    'the loose `probe observes specimen` relation survived the instrument_id edge');
obs = firstOfClass(out, 'voltage_observation');
verifyEqual(testCase, depValue(obs, 'instrument_id'), 'el_1');
end

function testDerivedElementKeepsItsDerivedFromLineage(testCase)
% REGRESSION GUARD. Only `observes` retires. A derived element (direct = 0 with an
% underlying element) is untouched: derived_from stays and NO observation is
% minted -- spike trains ride with the ensemble model's NDI second pass.
out = runJ(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'specimen_1', 'probe_1'));
verifyTrue(testCase, hasRelation(out, 'derived_from'));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
verifyFalse(testCase, anyObservationEmitted(out));
end

% ===================== two quantities on one instrument ====================

function testPatchProducesAVoltageAndACurrentObservation(testCase)
% PROBE-TYPES.md: patch = "two channels; first is Vm, second is I". Two
% quantities are two `variable`s, so two statements -- NOT one observation with a
% 2-long channel axis, which would label a current trace 'voltage'.
out = runJ(elementDoc('patch_a', 'patch', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEqual(testCase, countOfClass(out, 'voltage_observation'), 1);
verifyEqual(testCase, countOfClass(out, 'current_observation'), 1);
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 2);
% both are OF the specimen and WITH the same instrument, and share one anchor
volt = firstOfClass(out, 'voltage_observation');
curr = firstOfClass(out, 'current_observation');
verifyEqual(testCase, depValue(volt, 'subject_id'), 'specimen_1');
verifyEqual(testCase, depValue(curr, 'subject_id'), 'specimen_1');
verifyEqual(testCase, depValue(volt, 'instrument_id'), 'el_1');
verifyEqual(testCase, depValue(curr, 'instrument_id'), 'el_1');
verifyEqual(testCase, depValue(volt, 'time_reference_1'), depValue(curr, 'time_reference_1'));
verifyEqual(testCase, countOfClass(out, 'session_relative_reference'), 1);
verifyEqual(testCase, volt.get('subject_statement.variable').name, 'voltage');
verifyEqual(testCase, curr.get('subject_statement.variable').name, 'current');
end

function testCurrentPipetteIsNotLabelledVoltage(testCase)
% The unit-error tripwire. patch-I is "single channel, specifies current
% recording"; mapping it to voltage would be the fitcurve SSE/goodness-of-fit
% polarity swap one tier over -- a tidy-looking rename that inverts the meaning.
out = runJ(elementDoc('I_a', 'patch-I', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEqual(testCase, countOfClass(out, 'current_observation'), 1);
verifyEqual(testCase, countOfClass(out, 'voltage_observation'), 0);
end

% ===================== imaging ============================================

function testImagingProbeBecomesImageObservation(testCase)
% PROBE-TYPES.md _Imaging_; probetype2object.json registers all four imaging
% types to ndi.probe.image.
out = runJ(elementDoc('camera', 'wide-field-imaging', 'ndi.probe.image', 1, 'specimen_1', ''));
obs = firstOfClass(out, 'image_observation');
verifyNotEmpty(testCase, obs);
verifyEqual(testCase, obs.get('subject_statement.variable').name, 'image');
verifyEqual(testCase, depValue(obs, 'instrument_id'), 'el_1');
% draft/image.json is the only data_type declaring `value` mustBeNonEmpty, so the
% raster cell has to be present even though the pixels are not.
verifyNotEmpty(testCase, fieldnames(obs.get('image.value')));
verifyFalse(testCase, hasRelation(out, 'observes'));
end

% ===================== Guard A ============================================

function testUnmappedTypeIsFlaggedQueryablyAndKeepsObserves(testCase)
% GUARD A, AS BUILT. 'lick-spout' is registered in probetype2object.json but has
% ZERO occurrences in any .m file on NDI origin/main, so nothing states what its
% channel measures. The build refuses to guess a dimensioned quantity, records
% the unresolved state where a query can find it, and keeps `observes` so the
% probe -> specimen link is not lost in the meantime.
%
% WHEN THE SCHEMA HALF LANDS (a concrete undimensioned observation leaf + a
% `modality_unresolved` field) this test must be rewritten to assert a VALUED
% observation over a bare self-describing sampled_body, per the signed text. See
% the file header.
out = runJ(elementDoc('spout', 'lick-spout', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));

flag = assertionWithVariable(out, 'modality unresolved');
verifyNotEmpty(testCase, flag, 'an unmapped element type produced no queryable flag');
verifyEqual(testCase, flag.get('term.value').name, 'lick-spout');
verifyEqual(testCase, depValue(flag, 'subject_id'), 'el_1');
% nothing was invented, and nothing was lost
verifyFalse(testCase, anyObservationEmitted(out));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
verifyTrue(testCase, hasRelation(out, 'observes'));
end

function testAMappedTypeIsNotFlaggedUnresolved(testCase)
% The flag has to mean something: a resolved type must not carry it, or the
% worklist query returns every element and says nothing.
out = runJ(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEmpty(testCase, assertionWithVariable(out, 'modality unresolved'));
end

function testBannedClassNamesAreNeverMinted(testCase)
% T11 bans `timeseries_observation` / `signal_observation`, and R6 KILLED `array`
% outright. Swept across the resolved, the stimulator and the Guard A paths at
% once, so a future map edit cannot reintroduce one on a branch nobody looked at.
banned = {'timeseries_observation', 'signal_observation', 'array', ...
          'dataseries_observation', 'imageseries_observation'};
types = {'n-trode', 'patch', 'patch-Vm', 'wide-field-imaging', 'thermometer', ...
         'lick-spout', 'ppg', 'reward-well', 'stimulator', 'event', '', 'madeup'};
for t = 1:numel(types)
    out = runJ(elementDoc('e', types{t}, 'ndi.element', 1, 'specimen_1', ''));
    names = classNames(out);
    for b = 1:numel(banned)
        verifyFalse(testCase, any(strcmp(names, banned{b})), ...
            sprintf('type "%s" minted the banned class %s', types{t}, banned{b}));
    end
end
end

function testElementWithNoTypeAtAllIsFlaggedNotDropped(testCase)
% A real, reachable shape: +setup/+conv/+gluckman/channelname2probename.m:29-35
% returns probetype = '' for counter / status / ACC channels. An empty type is
% Guard A with the ndi_element_class as the best-known label -- never a silent
% gap, and never a guessed modality.
out = runJ(elementDoc('counter', '', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
flag = assertionWithVariable(out, 'modality unresolved');
verifyNotEmpty(testCase, flag);
verifyEqual(testCase, flag.get('term.value').name, 'ndi.probe.timeseries.mfdaq');
verifyFalse(testCase, anyObservationEmitted(out));
end

% ===================== the stimulator carve-out ============================

function testStimulatorElementEmitsNoObservationAndKeepsObserves(testCase)
% A stimulator ACTS ON the specimen; an observation would be the wrong direction
% (T3). probetype2object.json maps it to ndi.probe.timeseries.stimulator, and
% +gui/+app/pyraview.m:90-92 excludes stimulator probes from the recording set.
% Its `instrument_id` edge arrives with the stimulus model (#31/#43); until then
% `observes` is KEPT, because dropping a link with nothing in its place is loss,
% not retirement.
out = runJ(elementDoc('stim', 'stimulator', 'ndi.probe.timeseries.stimulator', 1, 'specimen_1', ''));
verifyFalse(testCase, anyObservationEmitted(out));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
verifyTrue(testCase, hasRelation(out, 'observes'));
% NOT flagged unresolved: the modality is not unknown, the DIRECTION is different.
verifyEmpty(testCase, assertionWithVariable(out, 'modality unresolved'));
end

% ===================== no specimen => no observation =======================

function testNoSpecimenMeansNoObservationAndNoEmptyRequiredEdge(testCase)
% subject_statement.subject_id is REQUIRED, and an empty required edge validates
% clean because +did2/+validate/references.m:90 skips empty edges -- the
% invented-empty-edge pattern that put 7,233 documents into the census. So a
% direct element with no subject_id emits nothing rather than an observation
% about nobody.
out = runJ(elementDoc('orphan_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, '', ''));
verifyFalse(testCase, anyObservationEmitted(out));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
verifyEqual(testCase, countOfClass(out, 'subject'), 1);   % the element still migrates
end

% ===================== validation =========================================

function testExtracellularRecordingValidatesAgainstVEta(testCase)
% THE ONE VALIDATING RUN. The whole emitted set -- subject + two kind assertions
% + voltage_observation + sampled_body + session anchor -- has to satisfy V_eta
% as declared: no undeclaredField, no missing mustBeNonEmpty, and no abstract
% class instantiated.
v1 = elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', '');
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('quarantined under validation: [%s] %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, countOfClass(out, 'voltage_observation'), 1);
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 1);
verifyEqual(testCase, countOfClass(out, 'session_relative_reference'), 1);
end

% ===================== fixtures ===========================================

function el = elementDoc(name, typ, ndiClass, direct, subjectId, underlyingId)
%ELEMENTDOC A did_v1 `element` body, built from the NDI template -- NOT from a
%   DID-side schema (the ground-truth rule). Fields and dependencies are exactly
%   those of
%     git show origin/main:src/ndi/ndi_common/database_documents/element.json
%       depends_on: underlying_element_id, subject_id
%       element:    ndi_element_class, name, reference, type, direct
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
deps = struct('name', {'subject_id'}, 'value', {subjectId});
if ~isempty(underlyingId)
    deps(end+1) = struct('name', 'underlying_element_id', 'value', underlyingId);
end
el.depends_on = deps;
el.base = struct('id', 'el_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', ndiClass, 'name', name, ...
    'reference', '1', 'type', typ, 'direct', direct);
end

% ===================== helpers ============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
end

function d = firstOfClass(out, className)
d = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        d = out.migrated{k};
        return;
    end
end
end

function n = countOfClass(out, className)
n = sum(strcmp(classNames(out), className));
end

function tf = anyObservationEmitted(out)
%ANYOBSERVATIONEMITTED Did anything at all in the batch end in '_observation'?
%   Deliberately a SUFFIX sweep rather than a list: a Guard A / stimulator test
%   that named the classes it does not expect would miss a NEW one.
names = classNames(out);
tf = any(cellfun(@(n) numel(n) > 12 && strcmp(n(end-11:end), '_observation'), names));
end

function tf = hasRelation(out, relationName)
tf = false;
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if ~strcmp(d.get('document_class.class_name'), 'directed_relation'); continue; end
    r = d.get('directed_relation.relation');
    if strcmp(r.name, relationName); tf = true; return; end
end
end

function d = assertionWithVariable(out, variableName)
%ASSERTIONWITHVARIABLE The term_assertion whose subject_statement.variable is
%   VARIABLENAME -- the query shape the Guard A worklist is meant to be found by.
d = [];
for k = 1:numel(out.migrated)
    doc = out.migrated{k};
    if ~strcmp(doc.get('document_class.class_name'), 'term_assertion'); continue; end
    v = doc.get('subject_statement.variable');
    if strcmp(v.name, variableName); d = doc; return; end
end
end

function v = depValue(doc, name)
% Takes document_id when present and falls back to value -- the precedence in
% +did2/+validate/references.m:176-179. Which spelling a body carries depends on
% whether the edge was built by a migrator or came through universalRenames.
v = '';
deps = doc.get('depends_on');
for k = 1:numel(deps)
    if ~strcmp(deps(k).name, name); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v = char(deps(k).value);
    end
    return;
end
end
