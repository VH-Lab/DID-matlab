function tests = testMigratorsJRecordingObservation
%TESTMIGRATORSJRECORDINGOBSERVATION Brainstorm-J: the raw-recording observation.
%
%   ---------------------------------------------------------------------
%   2026-10-21: ONE OBSERVATION PER ELEMENT PER EPOCH, ITS FILES AS BODIES
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-21 (did-schema
%   V_eta_recording_observation_plan.md): migrated recordings link their epoch
%   files as data bodies, matching native V2 (NDI
%   ndi.setup.V2.recordingDocuments): one observation per element per epoch,
%   `data_body` true, an `opaque_body` per epoch file by location (ingested
%   archives as attached), shared by the electrodes recorded in it, with the
%   channel map; a file named but absent is still recorded by location.
%
%   So pass 1 (+migrators_j/element.m) NO LONGER EMITS the observation: an
%   element names no epoch and carries no file, and the value-less session-wide
%   observation it used to emit is refused by rule `value_inline_or_body`
%   (data_body AMENDMENT 5), which quarantined the WHOLE element. The
%   observation is minted per epoch by did2.convert.resolveEpochProbemap from
%   the cached `epochfiles_ingested` document (or by the NDI second pass). The
%   recording tests below therefore drive the DID chain over an element PLUS
%   one epoch's cache (`runEpoch`), and assert the per-epoch observation with
%   its file bodies; the pass-1-only assertions (`runJ`) now say what pass 1
%   leaves: the element-subject, its kind assertions, and the `observes`
%   relation, KEPT until the batch pass emits its replacement.
%
%   The tests that asserted "no body" (testNoBodyIsEmittedBecauseTheElement-
%   CarriesNoBytes and the body-count lines of several others) are INVERTED,
%   not patched: they pinned the old premise that a recording has no bytes to
%   point at, and the decision is that the epoch's files ARE those bytes.
%
%   Derived `spikes` elements emit NO observation now (their per-epoch bytes
%   are on element_epoch documents, and how those become a body is an open
%   question); the spike-train tests are inverted to pin that, so the day it is
%   decided they fail and say so.
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
%   AND SINCE 2026-08-18 IT ALSO COVERS OPEN ITEM #117, which reuses all three:
%
%     TEAM-SIGN-OFF [spike train leaf]  jess, 2026-08-17
%       (did-schema schemas/V_eta_ensemble_plan.md:218)
%       "a per-neuron spike train is a `time_observation` [...] with
%        `statement.variable` = spike. The SPIKE TIMES ARE THE VALUE."
%
%   It is here rather than in a file of its own because it is the same
%   assembler with the two id ROLES exchanged -- the neuron is the subject and
%   the probe beneath it is the instrument -- and splitting it would have put
%   two callers of one function under two suites that could disagree about what
%   it emits. The roles are why `jRecordingObservation`'s arguments are named
%   `instrumentId` / `subjectId` and not `elementId` / `specimenId`.
%
%   WHAT THE SIGNATURE ASKS FOR THAT PASS 1 STILL CANNOT GIVE: the times
%   themselves. They live in the sorter's `.vhsb`, which the `element` document
%   does not carry -- the same reason the voltage case emits no body -- so the
%   statement says `storage_mode: 'reference'` and the `time` block is empty.
%   That is the identical landing-pad state #30 shipped in, not a shortfall
%   peculiar to spikes.
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
% The headline case. An n-trode probe (direct = 1) recording a specimen becomes,
% PER EPOCH, a voltage_observation OF THE SPECIMEN taken WITH the electrode,
% its value in the epoch's files (`data_body` true).
out = runEpoch(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/2024-06-01/t00001/t00001.rhd'});
obs = firstOfClass(out, 'observation+voltage');
verifyNotEmpty(testCase, obs, 'no voltage_observation was emitted for an n-trode epoch');
verifyEqual(testCase, depValue(obs, 'entity_id'), 'specimen_1');   % the SPECIMEN
verifyEqual(testCase, depValue(obs, 'instrument_id'), 'el_1');      % the electrode (T7)
verifyEqual(testCase, obs.get('statement.variable').name, 'voltage');
verifyTrue(testCase, logical(obs.get('value.data_body')), ...
    'the recording''s value is its epoch files: data_body must be true');
% timing: the EPOCH, not the session (one observation per element per epoch)
anchor = docById(out, depValue(obs, 'time_reference_id'));
verifyNotEmpty(testCase, anchor);
ep = docById(out, depValue(anchor, 'referent_id'));
verifyEqual(testCase, did2.unittest.helpers.classKey(ep), 'epoch');
% and pass 1 alone emits no observation at all
verifyFalse(testCase, anyObservationEmitted(runJ(elementDoc('ctx_probe', 'n-trode', ...
    'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''))));
end

function testTheEpochFilesBecomeOpaqueBodiesByLocation(testCase)
% INVERTED 2026-10-21 -- this was testNoBodyIsEmittedBecauseTheElementCarriesNoBytes,
% which asserted that a recording gets NO body. Its premise -- "`element`
% declares no files, so there are never bytes on this path" -- is still true OF
% THE ELEMENT (pass 1 below emits none), and the decision (Jess Haley,
% 2026-10-21) is that the bytes are the EPOCH's files: each becomes an
% opaque_body recorded BY LOCATION (ingest 0, never copied), owned by the
% observation. `epochid://` entries name the epoch, not a file. No size and no
% checksum: the batch pass reads documents, not a disk, so a file NAMED but
% absent (as in every test corpus) is still recorded.
files = {'/data/2024-06-01/t00001/t00001.rhd', '/data/2024-06-01/t00001/reference.txt'};
el = elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', '');
verifyEqual(testCase, countOfClass(runJ(el), 'opaque_body'), 0, ...
    'pass 1 minted a body for an element, which carries no files');
out = runEpoch(el, files);
obs = firstOfClass(out, 'observation+voltage');
verifyNotEmpty(testCase, obs);
bodies = allOfClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 2, 'one opaque_body per named file');
locs = {};
for i = 1:numel(bodies)
    b = bodies{i}.toStruct();
    verifyEqual(testCase, ownersOf(b), {char(obs.get('base.id'))});
    fi = b.files.file_info;
    verifyEqual(testCase, char(fi(1).name), 'body_data_0');
    verifyEqual(testCase, char(fi(1).locations.location_type), 'file');
    verifyEqual(testCase, double(fi(1).locations.ingest), 0);
    locs{end+1} = char(fi(1).locations.location); %#ok<AGROW>
    verifyFalse(testCase, isfield(b.data_body, 'size_bytes') && ~isempty(b.data_body.size_bytes) ...
        && b.data_body.size_bytes > 0, 'a size was invented for a file nobody read');
    verifyTrue(testCase, ~isfield(b.data_body, 'content_hash') || isempty(b.data_body.content_hash));
end
verifyEqual(testCase, sort(locs), sort(files));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
end

function testTheElementIdStaysOnTheSubjectAndTheObservationMintsAFreshId(testCase)
% ID PRESERVATION. ~50 v1 classes reference the element document and every one of
% them means "the recording element", which after migration is the SUBJECT.
% Moving that id onto the observation would silently re-point all of them (the
% 11,448-orphan shape). The observation is new, so nothing can dangle on it.
out = runEpoch(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/t00001/t00001.rhd'});
sub = firstOfClass(out, 'device');   % #88: an entity of type device
obs = firstOfClass(out, 'observation+voltage');
verifyEqual(testCase, sub.get('base.id'), 'el_1');
verifyNotEqual(testCase, obs.get('base.id'), 'el_1');
end

% ===================== multi-channel ======================================

function testMultiChannelProbeIsOneObservationWithAChannelAxis(testCase)
% SIGNED: a 32-site probe is ONE observation, NOT N observations -- per epoch
% now. The channels it owns in the shared file are its channel map, the
% acquisition_channels document (from the probe map's device string, here
% vhspike2:ai11-14), not N statements.
out = runEpoch(elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/t00001/t00001.rhd'});
verifyEqual(testCase, countOfClass(out, 'observation+voltage'), 1, ...
    'a multi-site probe must not fan out into one observation per site');
obs = firstOfClass(out, 'observation+voltage');
ac = docById(out, depValue(obs, 'acquisition_channels_id'));
verifyNotEmpty(testCase, ac, 'the observation names no channel map');
ch = ac.get('acquisition_channels.channels');
verifyEqual(testCase, double(ch(1).numbers(:))', [11 12 13 14]);
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
end

function testUnderscoredElectrodeSpellingAlsoResolves(testCase)
% +ndi/+daq/daqsystemstring.m:13 shows the epochprobemap form of a 4-channel
% extracellular recording as type 'extracellular_electrode-4', while
% probetype2object.json registers the stem as 'electrode-$' and
% +ndi/+database/+metadata_app/+fun/loadProbes.m:46 matches real data with
% regexp 'electrode-\d'. All three reach the same row. The ELEMENT is carried
% whole as v1 ([element types batch 4] (3), Jess Haley, 2026-10-30: the
% spelling is not a probetype2object.json key), so the row's observation is
% minted from the probe map's type alone.
out = runEpoch(elementDoc('ctx', 'extracellular_electrode-4', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/t00001/t00001.rhd'});
verifyEqual(testCase, countOfClass(out, 'observation+voltage'), 1);
obs = firstOfClass(out, 'observation+voltage');
verifyEqual(testCase, obs.get('statement.variable').name, 'voltage');
end

function testSingleChannelPipetteCarriesNoChannelAxis(testCase)
% PROBE-TYPES.md: patch-Vm is "single channel, specifies voltage recording":
% ONE observation per epoch.
out = runEpoch(elementDoc('Vm_a', 'patch-Vm', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/t00001/t00001.abf'});
verifyEqual(testCase, countOfClass(out, 'observation+voltage'), 1);
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
end

% ===================== the retired `observes` relation =====================

function testObservesRelationIsGoneForAMappedRecordingElement(testCase)
% THE RETIREMENT, now in two steps. Pass 1 KEEPS `observes` (it emits no
% observation, so nothing replaces it yet); the batch pass retires it when a
% surviving observation carries the same probe as instrument_id and the same
% specimen as entity_id.
el = elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', '');
verifyTrue(testCase, hasRelation(runJ(el), 'observes'), ...
    'pass 1 dropped `observes` with nothing in its place');
out = runEpoch(el, {'/data/t00001/t00001.rhd'});
verifyFalse(testCase, hasRelation(out, 'observes'), ...
    'the loose `probe observes specimen` relation survived the instrument_id edge');
obs = firstOfClass(out, 'observation+voltage');
verifyEqual(testCase, depValue(obs, 'instrument_id'), 'el_1');
end

function testDerivedElementKeepsItsDerivedFromLineage(testCase)
% REGRESSION GUARD. Only `observes` retires; `derived_from` is untouched.
%
% INVERTED AGAIN 2026-10-21. From 2026-08-18 this asserted that a derived
% `spikes` element emits a (session-wide, value-less) time_observation. That
% document is refused by rule `value_inline_or_body`, and the decision of
% 2026-10-21 makes a recording ONE OBSERVATION PER EPOCH with its files as
% bodies. A spike train's per-epoch bytes are on its element_epoch documents
% (an attached epoch_binary_data.vhsb each, in every corpus), and how those
% become the train's body is NOT DECIDED. So pass 1 emits no observation for
% it, and this pins that: when the derived case is decided, this line fails
% and points here.
out = runJ(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'specimen_1', 'probe_1'));
verifyTrue(testCase, hasRelation(out, 'derived_from'));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
verifyFalse(testCase, anyObservationEmitted(out), ...
    'a derived spikes element emitted an observation before its body is decided');
end

function testDerivedSpikesEmitNoObservationUntilTheirBodyIsDecided(testCase)
% INVERTED 2026-10-21 -- this was testDerivedSpikesBecomesATimeObservationOfTheNeuronItself.
% TEAM-SIGN-OFF [spike train leaf] still says what a spike train IS (a
% time_observation of the neuron, variable spike, with the probe as
% instrument); what changed is WHEN it can be emitted. A train's value is its
% spike times, which are in the element_epoch's attached file per epoch, and
% the observation is now per epoch with its value in bodies. Which file that
% is, per epoch, is an open question (reported, not decided), so nothing is
% emitted -- and nothing is quarantined either, which the old value-less
% observation was.
v1 = elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'specimen_1', 'probe_1');
out = did2.convert.v1_to_v2(withUnitProbe(v1), 'Validate', true, 'TargetVersion', 'V_eta', ...
    'UnitQualityLabels', {'el_1', 'single'});
verifyEmpty(testCase, out.quarantine, 'the derived element quarantined');
verifyEqual(testCase, countOfClass(out, 'observation+time'), 0);
verifyNotEmpty(testCase, firstOfClass(out, 'cell'), 'the neuron must still become a subject');
end

function testASpikesElementWithNoUnderlyingProbeOmitsTheInstrumentEdge(testCase)
% The invented-empty-edge guard, kept for the day the derived observation
% returns: whatever pass 1 emits for a spikes element with no underlying probe,
% no document may carry an `instrument_id` edge naming nothing. (Today it emits
% no observation at all -- see the test above.)
out = runJ(elementDoc('orphan_unit', 'spikes', 'ndi.neuron', 0, 'specimen_1', ''));
for k = 1:numel(out.migrated)
    deps = out.migrated{k}.get('depends_on');
    for j = 1:numel(deps)
        if strcmp(deps(j).name, 'instrument_id')
            verifyNotEmpty(testCase, depValue(out.migrated{k}, 'instrument_id'), ...
                'an instrument_id edge was emitted naming nothing');
        end
    end
end
verifyNotEmpty(testCase, firstOfClass(out, 'cell'));
end

% ===================== two quantities on one instrument ====================

function testPatchProducesAVoltageAndACurrentObservation(testCase)
% PROBE-TYPES.md: patch = "two channels; first is Vm, second is I". Two
% quantities are two `variable`s, so two statements -- NOT one observation with a
% 2-long channel axis, which would label a current trace 'voltage'. Both are in
% the same epoch file, so that file is ONE opaque_body SHARED by both: its
% owner_id repeats (did-schema data_body, 2026-10-21).
out = runEpoch(elementDoc('patch_a', 'patch', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/t00001/t00001.abf'});
verifyEqual(testCase, countOfClass(out, 'observation+voltage'), 1);
verifyEqual(testCase, countOfClass(out, 'observation+current'), 1);
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
volt = firstOfClass(out, 'observation+voltage');
curr = firstOfClass(out, 'observation+current');
verifyEqual(testCase, depValue(volt, 'entity_id'), 'specimen_1');
verifyEqual(testCase, depValue(curr, 'entity_id'), 'specimen_1');
verifyEqual(testCase, depValue(volt, 'instrument_id'), 'el_1');
verifyEqual(testCase, depValue(curr, 'instrument_id'), 'el_1');
verifyEqual(testCase, depValue(volt, 'time_reference_id'), depValue(curr, 'time_reference_id'));
verifyEqual(testCase, volt.get('statement.variable').name, 'voltage');
verifyEqual(testCase, curr.get('statement.variable').name, 'current');
bodies = allOfClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 1, 'one file, one body');
verifyEqual(testCase, sort(ownersOf(bodies{1}.toStruct())), ...
    sort({char(volt.get('base.id')), char(curr.get('base.id'))}), ...
    'the one file must be shared by both observations');
end

function testCurrentPipetteIsNotLabelledVoltage(testCase)
% The unit-error tripwire. patch-I is "single channel, specifies current
% recording"; mapping it to voltage would be the fitcurve SSE/goodness-of-fit
% polarity swap one tier over -- a tidy-looking rename that inverts the meaning.
out = runEpoch(elementDoc('I_a', 'patch-I', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''), ...
    {'/data/t00001/t00001.abf'});
verifyEqual(testCase, countOfClass(out, 'observation+current'), 1);
verifyEqual(testCase, countOfClass(out, 'observation+voltage'), 0);
end

% ===================== imaging ============================================

function testImagingProbeBecomesImageObservation(testCase)
% PROBE-TYPES.md _Imaging_; probetype2object.json registers all four imaging
% types to ndi.probe.image. #88: a raster goes by what its pixels measure --
% intensity. The frames are the epoch's files (a TIFF here), so the batch pass
% no longer defers imaging rows: nothing inline is needed.
% Every imaging probe is a device of kind microscope ([element types batch
% 2], Jess Haley, 2026-10-30; testRawV1RoundTripElement), and records this way.
out = runEpoch(elementDoc('camera', 'two-photon-imaging', 'ndi.probe.image', 1, 'specimen_1', ''), ...
    {'/data/t00001/frames.tif'});
obs = firstOfClass(out, 'observation+intensity');
verifyNotEmpty(testCase, obs);
verifyEqual(testCase, obs.get('statement.variable').name, 'intensity');
verifyEqual(testCase, depValue(obs, 'instrument_id'), 'el_1');
verifyEqual(testCase, depValue(obs, 'entity_id'), 'specimen_1');
verifyFalse(testCase, hasRelation(out, 'observes'));
b = firstOfClass(out, 'opaque_body');
verifyNotEmpty(testCase, b);
verifyEqual(testCase, char(b.get('data_body.format').node), 'EDAM:format_3591');
end

% ===================== the recording mode =================================

function testTheDecidedModeIsTheObservationsMethodTerm(testCase)
% [element type is a device kind term] (Jess Haley, 2026-10-27): the mode
% suffix goes on the recording observation; [imaging mode is a method term]
% (2026-10-29): as a method term. [element types batch 1] / [cell-attached is
% OBI]: -attached is OBI:0002179; [element types batch 2]: brightfield is
% EMPTY:0000300. [recording mode terms] (2026-11-01): -Vm is OBI:0002185
% "current clamp assay", -I / -Im OBI:0002182 "voltage clamp assay";
% [imaging mode terms] (2026-11-01): wide-field OBI:0002437, two-photon
% FBbi:00000254, one-photon FBbi:00000246. A bare patch or sharp names no
% mode, so its observation has no method.
abf = '/data/t00001/t00001.abf';
tif = '/data/t00001/frames.tif';
ts = 'ndi.probe.timeseries.mfdaq';
cases = { ...
    'patch-attached', ts, abf, 'observation+voltage', 'OBI:0002179'; ...
    'brightfield-imaging', 'ndi.probe.image', tif, 'observation+intensity', 'EMPTY:0000300'; ...
    'patch-Vm', ts, abf, 'observation+voltage', 'OBI:0002185'; ...
    'sharp-Vm', ts, abf, 'observation+voltage', 'OBI:0002185'; ...
    'patch-I', ts, abf, 'observation+current', 'OBI:0002182'; ...
    'sharp-Im', ts, abf, 'observation+current', 'OBI:0002182'; ...
    'wide-field-imaging', 'ndi.probe.image', tif, 'observation+intensity', 'OBI:0002437'; ...
    'two-photon-imaging', 'ndi.probe.image', tif, 'observation+intensity', 'FBbi:00000254'; ...
    'one-photon-imaging', 'ndi.probe.image', tif, 'observation+intensity', 'FBbi:00000246'; ...
    'patch', ts, abf, 'observation+voltage', ''};
for k = 1:size(cases, 1)
    [ty, cls, file, key, node] = cases{k, :};
    out = runEpoch(elementDoc('p', ty, cls, 1, 'specimen_1', ''), {file});
    obs = firstOfClass(out, key);
    assertNotEmpty(testCase, obs, ty);
    s = obs.toStruct();
    m = [];
    if isfield(s, 'interaction') && isstruct(s.interaction) && isfield(s.interaction, 'method')
        m = s.interaction.method;
    end
    if isempty(node)
        verifyTrue(testCase, isempty(m) || ~isfield(m, 'term') || isempty(m.term), ...
            [ty ': a mode term with no decision was written']);
    else
        assertTrue(testCase, isstruct(m) && isfield(m, 'term'), [ty ': no method term']);
        verifyEqual(testCase, char(m.term.node), node, ty);
    end
end
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
% the v1 type string finds its registered device kind: did-schema registers
% EMPTY:0000414 "lick spout" ([device kinds minted]) and a name is found
% ignoring hyphens ([term names match ignoring spacing], DID-matlab #294); the
% channel's modality is still unresolved, so the flag and no observation stay
verifyEqual(testCase, flag.get('term.value').name, 'lick spout');
verifyEqual(testCase, depValue(flag, 'entity_id'), 'el_1');
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
banned = {'observation+timeseries', 'observation+signal', 'array', ...
          'observation+dataseries', 'observation+imageseries'};
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

function testElementWithNoTypeAtAllIsCarried(testCase)
% INVERTS testElementWithNoTypeAtAllIsFlaggedNotDropped. A real, reachable
% shape: +setup/+conv/+gluckman/channelname2probename.m:29-35 returns probetype
% = '' for counter / status / ACC channels. [element types have no default]
% (Jess Haley, 2026-10-26): an empty type is on no list, so the element is
% carried as v1 (carry-063) instead of becoming a device flagged `modality
% unresolved`.
out = runJ(elementDoc('counter', '', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', ''));
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, numel(out.passthrough), 1);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-063] '), d);
verifyFalse(testCase, anyObservationEmitted(out));
end

% ===================== the stimulator carve-out ============================

function testStimulatorElementIsADeviceWithNoObservation(testCase)
% INVERTS testStimulatorElementIsCarriedWithNoObservation, which carried a
% stimulator element whole as v1 under [element types batch 4] (4).
% [stimulator is SNOMED CT Stimulator] (Jess Haley, 2026-10-30) replaces that
% item: a v1 `stimulator` element (vhlab's visual-stimulus computer, Marder's
% electrical stimulator) is a device of kind SNOMEDCT:36645008 "Stimulator".
% A stimulator ACTS ON the specimen, so pass 1 mints no observation (the
% wrong direction, T3); its delivery is the probe map's manipulation, and
% until an `instrument_id` edge replaces it `observes` is KEPT. Not flagged
% unresolved: the modality is not unknown, the direction is different.
out = runJ(elementDoc('stim', 'stimulator', 'ndi.probe.timeseries.stimulator', 1, 'specimen_1', ''));
verifyEqual(testCase, numel(out.passthrough), 0, 'the stimulator element was carried');
verifyNotEmpty(testCase, firstOfClass(out, 'device'), 'no device entity');
kind = assertionWithVariable(out, 'Equipment Type');
verifyNotEmpty(testCase, kind, 'no Equipment Type assertion');
if ~isempty(kind)
    verifyEqual(testCase, char(kind.get('statement.variable').node), 'NCIT:C178920');
    value = kind.get('term.value');
    verifyEqual(testCase, char(value.node), 'SNOMEDCT:36645008');
    verifyEqual(testCase, char(value.name), 'Stimulator');
end
verifyFalse(testCase, anyObservationEmitted(out));
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
verifyTrue(testCase, hasRelation(out, 'observes'));
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
verifyEqual(testCase, countOfClass(out, 'device'), 1);   % the element still migrates (#88: a device entity)
end

% ===================== validation =========================================

function testExtracellularRecordingValidatesAgainstVEta(testCase)
% THE VALIDATING RUN, now over the whole DID chain: the element-subject + its
% kind assertions + the epoch + the per-epoch voltage_observation (data_body
% true) + its epoch anchor + the channel map + the opaque_body by location.
% Nothing may quarantine; rule value_inline_or_body is satisfied by data_body.
el = elementDoc('ctx_probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, 'specimen_1', '');
pass1 = did2.convert.v1_to_v2(el, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, pass1.quarantine, 'pass 1 quarantined the element');
out = runEpoch(el, {'/data/t00001/t00001.rhd'}, true);
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('quarantined under validation: [%s] %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyNotEmpty(testCase, firstOfClass(out, 'observation+voltage'));
verifyNotEmpty(testCase, firstOfClass(out, 'opaque_body'));
end

function testTheSpikeTrainAlsoValidatesAgainstVEta(testCase)
% A derived spikes element validates in pass 1 -- no quarantine (the old
% value-less time_observation quarantined the whole element under rule
% value_inline_or_body) -- and emits NO observation until its per-epoch body is
% decided (see testDerivedSpikesEmitNoObservationUntilTheirBodyIsDecided).
v1 = elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'specimen_1', 'probe_1');
out = did2.convert.v1_to_v2(withUnitProbe(v1), 'Validate', true, 'TargetVersion', 'V_eta', ...
    'UnitQualityLabels', {'el_1', 'single'});
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('quarantined under validation: [%s] %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, countOfClass(out, 'observation+time'), 0);
verifyEqual(testCase, countOfClass(out, 'observation+voltage'), 0);
verifyEqual(testCase, countOfClass(out, 'sampled_body'), 0);
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
% every element here is el_1; a `spikes` one is a unit its sorting run labels
% single ([sorted units are cells or groups], Jess Haley, 2026-10-26; without a
% label it is carried, testRawV1RoundTripElement)
out = did2.convert.v1_to_v2(withUnitProbe(v1), 'Validate', false, 'TargetVersion', 'V_eta', ...
    'UnitQualityLabels', {'el_1', 'single'});
end

function batch = withUnitProbe(v1)
%WITHUNITPROBE {V1} plus, when V1 names an underlying element, that probe (an
%   n-trode on V1's subject, id = the underlying_element_id): a sorted unit
%   whose probe is not in the batch is carried whole as v1, carry-151 ([unit
%   with no probe in the batch carried], Jess Haley, 2026-10-29). A probe
%   names no epoch, so it emits no observation of its own.
batch = {v1};
deps = v1.depends_on;
under = deps(strcmp({deps.name}, 'underlying_element_id'));
if isempty(under) || isempty(under(1).value); return; end
subj = deps(strcmp({deps.name}, 'subject_id'));
probe = elementDoc('probe', 'n-trode', 'ndi.probe.timeseries.mfdaq', 1, subj(1).value, '');
probe.base.id = char(under(1).value);
batch{end+1} = probe;
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = did2.unittest.helpers.classKey(out.migrated{k});
end
end

function d = firstOfClass(out, className)
d = [];
for k = 1:numel(out.migrated)
    if strcmp(did2.unittest.helpers.classKey(out.migrated{k}), className)
        d = out.migrated{k};
        return;
    end
end
end

function n = countOfClass(out, className)
n = sum(strcmp(classNames(out), className));
end

function tf = anyObservationEmitted(out)
%ANYOBSERVATIONEMITTED Did anything at all in the batch be an observation?
%   Deliberately a sweep rather than a list: a Guard A / stimulator test that
%   named the classes it does not expect would miss a NEW one. did-schema #88:
%   'observation' / 'observation+<kind>' (classKey); a joined old name ending
%   in '_observation' counts too, so an emitter regressing to it is caught.
names = classNames(out);
tf = any(cellfun(@(n) strcmp(n, 'observation') || strncmp(n, 'observation+', 12) ...
    || (numel(n) > 12 && strcmp(n(end-11:end), '_observation')), names));
end

function tf = hasRelation(out, relationName)
tf = false;
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if ~strcmp(d.get('document_class.class_name'), 'directed_relation'); continue; end
    r = d.get('directed_relation.relation');
    if did2.build.isVocabulary(r, 'relation', relationName); tf = true; return; end   % by node (L1)
end
end

function d = assertionWithVariable(out, variableName)
%ASSERTIONWITHVARIABLE The term_assertion whose statement.variable is
%   VARIABLENAME -- the query shape the Guard A worklist is meant to be found by.
d = [];
for k = 1:numel(out.migrated)
    doc = out.migrated{k};
    if ~strcmp(did2.unittest.helpers.classKey(doc), 'assertion+term'); continue; end
    v = doc.get('statement.variable');
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


function out = runEpoch(el, files, validate)
%RUNEPOCH The DID chain over ELEMENT plus one epoch's v1 cache: a session, the
%   specimen subject (local_identifier 'L'), and an epochfiles_ingested naming
%   epoch t00001, FILES, and one probe-map row for this element (its name,
%   reference '1', its type, device vhspike2:ai11-14, subject 'L'). Mirrors
%   testResolveEpochProbemap's decompose().
if nargin < 3; validate = false; end
sess = struct();
sess.document_class = struct('class_name', 'session', 'class_version', 1, ...
    'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
sess.depends_on = struct('name', {}, 'value', {});
sess.base = struct('id', 'sd_09', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
sess.session = struct('reference', 'ref');
subj = struct();
subj.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
subj.depends_on = struct('name', {}, 'value', {});
subj.base = struct('id', 'specimen_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
subj.subject = struct('local_identifier', 'L', 'description', '');
ing = struct();
ing.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation', '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name', 'epochfiles_ingested', 'property_list_name', 'epochfiles_ingested', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
ing.depends_on = struct('name', 'filenavigator_id', 'value', 'nav_1');
ing.base = struct('id', 'efi_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n%s\t1\t%s\tvhspike2:ai11-14\tL\n', ...
    el.element.name, el.element.type);
ing.epochfiles_ingested = struct('epoch_id', 't00001', ...
    'files', {[{'epochid://t00001'}, files]}, 'epochprobemap', pm);
out = did2.convert.v1_to_v2({sess, subj, el, ing}, 'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.resolveSessionAnchors(out, 'Validate', validate, 'TargetVersion', 'V_eta');
out = did2.convert.resolveEpochProbemap(out, 'Validate', validate, 'TargetVersion', 'V_eta');
end

function c = allOfClass(out, className)
c = {};
for k = 1:numel(out.migrated)
    if strcmp(did2.unittest.helpers.classKey(out.migrated{k}), className)
        c{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
end

function d = docById(out, id)
d = [];
if isempty(id); return; end
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), id); d = out.migrated{k}; return; end
end
end

function ids = ownersOf(b)
%OWNERSOF Every owner_id of a body STRUCT (the edge repeats), in order.
ids = {};
deps = b.depends_on;
if iscell(deps); deps = [deps{:}]; end
for k = 1:numel(deps)
    if ~strcmp(deps(k).name, 'owner_id'); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        ids{end+1} = char(deps(k).document_id); %#ok<AGROW>
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        ids{end+1} = char(deps(k).value); %#ok<AGROW>
    end
end
end
