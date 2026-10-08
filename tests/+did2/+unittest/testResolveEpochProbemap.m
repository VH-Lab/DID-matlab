function tests = testResolveEpochProbemap
%TESTRESOLVEEPOCHPROBEMAP The #66 epochprobemap fold, ALL THREE increments.
%
%   STATUS: WRITTEN 2026-08-21, NEVER EXECUTED HERE. This container has no MATLAB
%   -- `command -v matlab octave octave-cli` prints nothing -- so not one line
%   below has been run; the quick gate (test-migrators-quick.yml) is the first
%   thing that will have an opinion about it.
%
%   WHAT IS UNDER TEST: did2.convert.resolveEpochProbemap decomposes an ingested
%   epoch's serialized `epochprobemap` into one epoch-scoped
%   `<modality>_observation` per probe row, anchored to the minted `epoch`
%   document via a shared 'during' relative_reference, and:
%     1  (observation) attributes each to its subject + instrument;
%     2  (device half) splits the row's devicestring into an acquisition_system_id
%        edge + a grouped `channels` field;
%     3  (rename-thin) rewrites the source epochfiles_ingested to
%        ingestion_manifest, guarded on filenavigator_id + a resolved epoch;
%   and RETIRES #30's coarse session observation for a probe, matched on the
%   (subject, instrument, class) TRIPLE so a spike-sorted probe's neuron trains
%   (same instrument, different subject) are left intact.
%
%   THE FIXTURES ARE BUILT FROM THE WRITER, never from a DID-side schema (the
%   ground-truth rule): the probemap string is the exact tab-delimited shape NDI
%   origin/main +ndi/+epoch/epochprobemap_daqsystem.serialize() emits, and the
%   element / subject / ingested / session bodies reproduce the NDI templates the
%   recording-observation and epoch-mint tests already drive. Shapes are copied
%   from testEpochProbemapMeasurement.m so the two cannot drift.
%
%   THE CHAIN IS THE REAL ONE: v1_to_v2 -> epochMint -> resolveSessionAnchors ->
%   resolveEpochProbemap, in the order the corpus harness composes it. epochMint
%   mints the `epoch` documents this pass anchors to; resolveSessionAnchors folds
%   the #30 observations' session anchors first, exactly as in production.

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function [out, rep] = decompose(v1)
%DECOMPOSE Pass 1, then the batch chain up to and including this pass. Validation
%   is ON from resolveSessionAnchors onward so the minted observations and
%   anchors are checked against the real V_eta schema.
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.resolveSessionAnchors(out, 'Validate', true, ...
    'TargetVersion', 'V_eta');
[out, rep] = did2.convert.resolveEpochProbemap(out, 'Validate', true, ...
    'TargetVersion', 'V_eta');
end

% ===================== the headline decomposition =====================

function testTwoObservationsMintedOneRowRefusedAndTheHash30ObsRetired(testCase)
% The primary scenario, all in one batch:
%   row 1  tet/1/n-trode/L   -> voltage_observation, subject_id = specimen,
%                              instrument_id = the element-subject 'el_1'
%                              (RESOLVED via local_identifier 'tet (ref 1)'),
%                              and it RETIRES the #30 obs that names el_1.
%   row 2  tet/2/n-trode/L   -> voltage_observation, subject_id = specimen,
%                              instrument_id OMITTED (no 'tet (ref 2)' subject).
%   row 3  tet/3/n-trode/x   -> subjectstring 'x@lab' resolves to no subject:
%                              REFUSED, no observation.
subj = subjectBody('specimen_1', 'sess_1', 'L');
el   = elementBody('el_1', 'sess_1', 'tet', '1', 'n-trode', 1, 'specimen_1');
ing  = ingestedWithRows('ing_1', 'sess_1', 't00001', { ...
    {'tet', '1', 'n-trode', 'L'}, ...
    {'tet', '2', 'n-trode', 'L'}, ...
    {'tet', '3', 'n-trode', 'x@lab'}});
[out, rep] = decompose({sessionBody('sd_1', 'sess_1', 'ref'), subj, el, ing});

% --- the report -----------------------------------------------------------
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.epochfiles_ingested_seen, 1);
verifyEqual(testCase, rep.refused_no_epoch, 0);
verifyEqual(testCase, rep.probe_rows_total, 3);
verifyEqual(testCase, rep.rows_no_subjectstring, 0);
verifyEqual(testCase, rep.refused_no_subject, 1);
verifyEqual(testCase, rep.rows_unresolved_modality, 0);
verifyEqual(testCase, rep.rows_stimulator, 0);
verifyEqual(testCase, rep.observations_emitted, 2);
verifyEqual(testCase, rep.instrument_resolved, 1);
verifyEqual(testCase, rep.instrument_omitted, 1);
verifyEqual(testCase, rep.epoch_anchors_minted, 1);
verifyEqual(testCase, rep.session30_observations_retired, 1);
verifyEqual(testCase, rep.retire_skipped_ambiguous, 0);
verifyEqual(testCase, rep.fold_quarantined, 0);
% device half: rows 1+2 reach it (row 3 refused at subject first); the
% devicestring names 'vhspike2', for which no acquisition_system exists here,
% so the edge is OMITTED (unresolved), and the channel spec parses.
verifyEqual(testCase, rep.device_strings_seen, 2);
verifyEqual(testCase, rep.device_acqsystem_unresolved, 2);
verifyEqual(testCase, rep.device_acqsystem_resolved, 0);
verifyEqual(testCase, rep.device_channels_parsed, 2);
% increment 3: the ingested doc is renamed to ingestion_manifest (its
% filenavigator_id 'nav_1' and epoch resolve).
verifyEqual(testCase, rep.manifests_renamed, 1);
verifyEqual(testCase, rep.rename_quarantined, 0);

% --- THE ROW PARTITION reconciles. Single-modality rows, so observations ==
%     recording rows and manipulations == stimulator rows (increment 3).
refused = rep.rows_no_subjectstring + rep.refused_no_subject;
deferred = rep.rows_unresolved_modality + rep.rows_image_deferred;
verifyEqual(testCase, rep.probe_rows_total, ...
    rep.observations_emitted + rep.manipulations_emitted + refused + deferred);

% --- exactly two migrated_probemap_observation documents ------------------
obs = bodiesNamed(out, 'migrated_probemap_observation');
verifyEqual(testCase, numel(obs), 2);

% both are voltage_observations of the specimen, anchored to the same epoch
% 'during' anchor.
anchorIds = {};
withInstrument = 0;
for i = 1:numel(obs)
    b = obs{i};
    verifyEqual(testCase, char(b.document_class.class_name), 'voltage_observation');
    verifyEqual(testCase, depVal(b, 'subject_id'), 'specimen_1');
    tr = depVal(b, 'time_reference_1');
    verifyNotEmpty(testCase, tr);
    anchorIds{end+1} = tr; %#ok<AGROW>
    inst = depVal(b, 'instrument_id');
    if ~isempty(inst)
        verifyEqual(testCase, inst, 'el_1');   % the RESOLVED probe-subject
        withInstrument = withInstrument + 1;
    end
end
verifyEqual(testCase, withInstrument, 1);
% one shared anchor across both observations
verifyEqual(testCase, numel(unique(anchorIds)), 1);

% --- the shared anchor is an epoch-scoped 'during' relative_reference ------
anchors = bodiesNamed(out, 'migrated_probemap_epoch_anchor');
verifyEqual(testCase, numel(anchors), 1);
a = anchors{1};
verifyEqual(testCase, char(a.document_class.class_name), 'relative_reference');
verifyEqual(testCase, a.base.id, anchorIds{1});
verifyEqual(testCase, char(a.relative_reference.value.relation.name), 'intervalDuring');
% its relative_to is the minted epoch document
epochs = bodiesOfClass(out, 'epoch');
verifyEqual(testCase, numel(epochs), 1);
verifyEqual(testCase, depVal(a, 'relative_to'), epochs{1}.base.id);

% --- the #30 observation for el_1 is RETIRED ------------------------------
% element.m emits a voltage_observation (base.name migrated_recording_observation)
% with instrument_id el_1; resolveEpochProbemap replaces it, so it is gone.
recObs = bodiesNamed(out, 'migrated_recording_observation');
for i = 1:numel(recObs)
    verifyNotEqual(testCase, depVal(recObs{i}, 'instrument_id'), 'el_1');
end
verifyEqual(testCase, numel(recObs), 0);   % el_1 was the only direct element

% --- each observation carries the parsed channels, no acquisition_system edge
for i = 1:numel(obs)
    verifyEmpty(testCase, depVal(obs{i}, 'acquisition_system_id')); % unresolved
    ch = obs{i}.subject_interaction.channels;   % hoisted from subject_observation (inc 3)
    verifyEqual(testCase, numel(ch), 1);                 % one group: ai11-14
    verifyEqual(testCase, char(ch(1).type.name), 'ai');
    verifyEqual(testCase, double(ch(1).numbers), [11 12 13 14]);
end

% --- INCREMENT 3: the ingested document is now an ingestion_manifest --------
verifyEqual(testCase, numel(bodiesOfClass(out, 'epochfiles_ingested')), 0);
mani = bodiesOfClass(out, 'ingestion_manifest');
verifyEqual(testCase, numel(mani), 1);
m = mani{1};
verifyEqual(testCase, m.base.id, 'ing_1');                    % id PRESERVED
verifyEqual(testCase, depVal(m, 'filenavigator_id'), 'nav_1'); % RESTORED
verifyEqual(testCase, depVal(m, 'epoch_id'), epochs{1}.base.id); % now an EDGE
verifyEqual(testCase, m.ingestion_manifest.files, {'epochid://t00001'});
% LOSSLESS ROUND-TRIP: the serialized epochprobemap is carried VERBATIM, so the
% stimulator/imaging rows that do not decompose into observations are still
% preserved on the manifest. Recording rows also become observations (above);
% this string is the full-fidelity record ndi.vintage reads back.
verifyEqual(testCase, m.ingestion_manifest.epochprobemap, ...
    ing.epochfiles_ingested.epochprobemap);
end

% ===================== the triple key resolves patch/sharp ===============

function testAPatchElementRetiresBOTHClassesViaTheTripleKey(testCase)
% A `patch` element emits TWO #30 observations (voltage + current), both with
% instrument_id el_2 and subject specimen_2 -- but DIFFERENT classes. Keying the
% retirement on instrument ALONE was ambiguous (2 hits) and kept both; the
% (subject, instrument, CLASS) triple distinguishes them, so the probemap's
% voltage_observation supersedes the #30 voltage_observation and its
% current_observation supersedes the #30 current_observation. BOTH retire.
subj = subjectBody('specimen_2', 'sess_2', 'L');
el   = elementBody('el_2', 'sess_2', 'pat', '1', 'patch', 1, 'specimen_2');
ing  = ingestedWithRows('ing_2', 'sess_2', 't00002', { ...
    {'pat', '1', 'patch', 'L'}});
[out, rep] = decompose({sessionBody('sd_2', 'sess_2', 'ref'), subj, el, ing});

% one patch row -> two observations (voltage + current)
verifyEqual(testCase, rep.observations_emitted, 2);
verifyEqual(testCase, rep.session30_observations_retired, 2);
verifyEqual(testCase, rep.retire_skipped_ambiguous, 0);
verifyEqual(testCase, rep.retire_no_match, 0);
% both #30 observations for el_2 are RETIRED
recObs = bodiesNamed(out, 'migrated_recording_observation');
verifyEqual(testCase, numel(recObs), 0);
end

function testASpikeSortedProbeRetiresOnlyItsOwnDirectRecording(testCase)
% THE BUG THE TRIPLE KEY FIXES (174/174 skipped-ambiguous on Soph). A spike-
% sorted probe carries MORE THAN ONE #30 observation on the same instrument:
%   el_probe  DIRECT n-trode  -> #30 voltage_observation
%                                 subject = specimen, instrument = el_probe
%   el_neuron 'spikes', derived, underlying = el_probe
%                              -> #30 time_observation (spike-train leaf)
%                                 subject = el_neuron, instrument = el_probe
% Keyed on instrument alone that is 2 hits -> ambiguous -> nothing retired. The
% (subject, instrument, class) triple matches only the probe's OWN direct
% recording (subject = the specimen), leaving the neuron's spike train intact.
subj = subjectBody('specimen_sp', 'sess_sp', 'L');
elP  = elementBody('el_probe', 'sess_sp', 'tet', '1', 'n-trode', 1, 'specimen_sp');
elN  = derivedElementBody('el_neuron', 'sess_sp', 'n1', 'spikes', 'el_probe');
ing  = ingestedWithRows('ing_sp', 'sess_sp', 't00sp', { ...
    {'tet', '1', 'n-trode', 'L'}});
[out, rep] = decompose({sessionBody('sd_sp', 'sess_sp', 'ref'), subj, elP, elN, ing});

verifyEqual(testCase, rep.observations_emitted, 1);       % one probemap voltage obs
verifyEqual(testCase, rep.session30_observations_retired, 1);
verifyEqual(testCase, rep.retire_skipped_ambiguous, 0);
% the probe's OWN direct recording (subject specimen_sp) is gone; the neuron's
% spike-train observation (subject el_neuron, instrument el_probe) SURVIVES.
recObs = bodiesNamed(out, 'migrated_recording_observation');
verifyEqual(testCase, numel(recObs), 1);
verifyEqual(testCase, depVal(recObs{1}, 'subject_id'), 'el_neuron');
verifyEqual(testCase, depVal(recObs{1}, 'instrument_id'), 'el_probe');
end

% ===================== an unresolvable subject emits nothing ===========

function testAnUnresolvableSubjectstringEmitsNoObservation(testCase)
% subject_id is the ONE required edge; a row whose subjectstring matches no
% subject document emits NOTHING (never an empty required edge) and is counted.
el  = elementBody('el_3', 'sess_3', 'tet', '1', 'n-trode', 1, 'specimen_3');
ing = ingestedWithRows('ing_3', 'sess_3', 't00003', { ...
    {'tet', '1', 'n-trode', 'nobody@lab'}});
% NB: no subject document for specimen_3's local id, so the row cannot resolve.
[out, rep] = decompose({sessionBody('sd_3', 'sess_3', 'ref'), el, ing});
verifyEqual(testCase, rep.probe_rows_total, 1);
verifyEqual(testCase, rep.refused_no_subject, 1);
verifyEqual(testCase, rep.observations_emitted, 0);
verifyEmpty(testCase, bodiesNamed(out, 'migrated_probemap_observation'));
% nothing minted -> no epoch anchor either
verifyEqual(testCase, rep.epoch_anchors_minted, 0);
end

% ===================== an empty subjectstring column ===================

function testAnEmptySubjectstringIsCountedApart(testCase)
% An empty subjectstring column is a DIFFERENT refusal from a present-but-
% unresolvable one, and must not be summed with it.
subj = subjectBody('specimen_4', 'sess_4', 'L');
el   = elementBody('el_4', 'sess_4', 'tet', '1', 'n-trode', 1, 'specimen_4');
ing  = ingestedWithRows('ing_4', 'sess_4', 't00004', { ...
    {'tet', '1', 'n-trode', ''}, ...
    {'tet', '2', 'n-trode', 'L'}});
[~, rep] = decompose({sessionBody('sd_4', 'sess_4', 'ref'), subj, el, ing});
verifyEqual(testCase, rep.probe_rows_total, 2);
verifyEqual(testCase, rep.rows_no_subjectstring, 1);
verifyEqual(testCase, rep.refused_no_subject, 0);
verifyEqual(testCase, rep.observations_emitted, 1);
end

% ===================== modality rows resolve ==========================

function testModalityRowsResolveToTheRightObservationLeaf(testCase)
% One row per modality family that yields a single observation, all resolvable to
% the same specimen. Asserts localModality maps each type to the leaf
% jRecordingModality maps it to -- the pin that keeps the duplicated map honest.
%
% IMAGING IS DEFERRED, NOT EMITTED, IN INCREMENT 1. `image.value` is
% mustBeNonEmpty, and a probemap row carries no raster metadata, so a
% pure-reference image cell is all-blank and the #38 NonVacuousFields gate (armed
% by default) refuses it -- inventing a dtype to satisfy it is the guess R6/#30
% forbid. So the two-photon-imaging row is COUNTED (rows_image_deferred) and emits
% nothing; the other SIX rows emit. This is the pass recognising a modality it
% cannot honestly express yet, not a validation bug -- see resolveEpochProbemap's
% localModality IMAGE IS DEFERRED note. jRecordingObservation carries the same
% latent blank-image shape but never validates it (its tests run Validate=false).
subj = subjectBody('spec_m', 'sess_m', 'L');
ing  = ingestedWithRows('ing_m', 'sess_m', 't0m', { ...
    {'a', '', 'n-trode',              'L'}, ...   % voltage
    {'b', '', 'patch-i',              'L'}, ...   % current
    {'c', '', 'two-photon-imaging',   'L'}, ...   % image (DEFERRED, not emitted)
    {'d', '', 'spikes',               'L'}, ...   % time
    {'e', '', 'accelerometer',        'L'}, ...   % acceleration
    {'f', '', 'thermometer',          'L'}, ...   % temperature
    {'g', '', 'extracellular_electrode-4', 'L'}}); % voltage (electrode stem)
[out, rep] = decompose({sessionBody('sd_m', 'sess_m', 'ref'), subj, ing});
verifyEqual(testCase, rep.probe_rows_total, 7);
verifyEqual(testCase, rep.observations_emitted, 6);
verifyEqual(testCase, rep.rows_image_deferred, 1);
verifyEqual(testCase, rep.rows_unresolved_modality, 0);

got = sort(cellfun(@(b) char(b.document_class.class_name), ...
    bodiesNamed(out, 'migrated_probemap_observation'), 'UniformOutput', false));
want = sort({'voltage_observation', 'current_observation', ...
    'time_observation', 'acceleration_observation', 'temperature_observation', ...
    'voltage_observation'});
verifyEqual(testCase, got, want);
end

% A stimulator type decomposes into a `term_manipulation` (#66 increment 3, the
% T3 direction) -- NOT an observation; an unmapped type (lick-spout) is Guard A
% and still emits nothing. Split into named micro-checks: the migrator test
% harness reports only the FAILING TEST NAME (no per-assertion diagnostic), so
% each fact gets its own name to localise a regression.
function [out, rep, manips] = stimDecompose()
subj = subjectBody('spec_s', 'sess_s', 'L');
stim = elementBody('stim_1', 'sess_s', 'stim', '1', 'stimulator', 1, 'spec_s');
ing  = ingestedWithRows('ing_s', 'sess_s', 't0s', { ...
    {'stim', '1', 'stimulator', 'L'}, ...
    {'lick', '',  'lick-spout', 'L'}});
[out, rep] = decompose({sessionBody('sd_s', 'sess_s', 'ref'), subj, stim, ing});
manips = bodiesNamed(out, 'migrated_probemap_manipulation');
end

function testStimProbeRowsTotal(testCase)
[~, rep, ~] = stimDecompose(); verifyEqual(testCase, rep.probe_rows_total, 2);
end
function testStimRowsStimulator(testCase)
[~, rep, ~] = stimDecompose(); verifyEqual(testCase, rep.rows_stimulator, 1);
end
function testStimRowsUnresolved(testCase)
[~, rep, ~] = stimDecompose(); verifyEqual(testCase, rep.rows_unresolved_modality, 1);
end
function testStimObservationsEmittedZero(testCase)
[~, rep, ~] = stimDecompose(); verifyEqual(testCase, rep.observations_emitted, 0);
end
function testStimManipulationsEmittedOne(testCase)
[~, rep, ~] = stimDecompose(); verifyEqual(testCase, rep.manipulations_emitted, 1);
end
function testStimNoObservationBody(testCase)
[out, ~, ~] = stimDecompose();
verifyEmpty(testCase, bodiesNamed(out, 'migrated_probemap_observation'));
end

function testStimNotQuarantined(testCase)
[~, rep, ~] = stimDecompose();
verifyEqual(testCase, rep.fold_quarantined, 0);
end

function testStimOneManipulationValidatedAndEmitted(testCase)
[~, ~, manips] = stimDecompose();
verifyEqual(testCase, numel(manips), 1);
end

function testStimManipulationClassSubjectAnchor(testCase)
[~, ~, manips] = stimDecompose();
assertNotEmpty(testCase, manips);
m = manips{1};
verifyEqual(testCase, char(m.document_class.class_name), 'term_manipulation');
verifyEqual(testCase, depVal(m, 'subject_id'), 'spec_s');
verifyNotEmpty(testCase, depVal(m, 'time_reference_1'));
end

function testStimManipulationCarriesTheStimulatorType(testCase)
[~, ~, manips] = stimDecompose();
assertNotEmpty(testCase, manips);
m = manips{1};
verifyEqual(testCase, char(m.subject_statement.variable.name), 'stimulator');
verifyEqual(testCase, char(m.subject_statement.storage_mode), 'inline');
verifyEqual(testCase, char(m.term.value.name), 'stimulator');
end

% ===================== the device half (increment 2) ==================

function testDeviceStringResolvesAcqSystemAndParsesGroupedChannels(testCase)
% `intan1:ai27-28,45;di0-2` -> acquisition_system_id (the migrated daqsystem
% named 'intan1') + two channel groups {ai [27 28 45]} and {di [0 1 2]}.
subj = subjectBody('spec_d', 'sess_d', 'L');
daq  = daqsystemBody('acqsys_d', 'sess_d', 'intan1');
ing  = ingestedWithDeviceRows('ing_d', 'sess_d', 't0d', { ...
    {'p', '', 'n-trode', 'intan1:ai27-28,45;di0-2', 'L'}});
[out, rep] = decompose({sessionBody('sd_d', 'sess_d', 'ref'), subj, daq, ing});

verifyEqual(testCase, rep.device_strings_seen, 1);
verifyEqual(testCase, rep.device_acqsystem_resolved, 1);
verifyEqual(testCase, rep.device_acqsystem_unresolved, 0);
verifyEqual(testCase, rep.device_channels_parsed, 1);
verifyEqual(testCase, rep.device_channels_unparsable, 0);

obs = bodiesNamed(out, 'migrated_probemap_observation');
verifyEqual(testCase, numel(obs), 1);
verifyEqual(testCase, depVal(obs{1}, 'acquisition_system_id'), 'acqsys_d');
ch = obs{1}.subject_interaction.channels;   % hoisted from subject_observation (inc 3)
verifyEqual(testCase, numel(ch), 2);
verifyEqual(testCase, char(ch(1).type.name), 'ai');
verifyEqual(testCase, double(ch(1).numbers), [27 28 45]);
verifyEqual(testCase, char(ch(2).type.name), 'di');
verifyEqual(testCase, double(ch(2).numbers), [0 1 2]);
end

% ===================== the rename-thin guard (increment 3) =============

function testRenameIsGuardedWhenNoFilenavigatorId(testCase)
% ingestion_manifest REQUIRES filenavigator_id. A source epochfiles_ingested
% that carries none is LEFT as the tombstone (never quarantined) and counted --
% the guarded-passthrough idiom. Empty probemap here, so the rename decision is
% the only thing under test.
ing = ingestedRaw('ing_g', 'sess_g', 't0g', '');
ing.depends_on = struct('name', {}, 'value', {});   % NO filenavigator_id
[out, rep] = decompose({sessionBody('sd_g', 'sess_g', 'ref'), ing});

verifyEqual(testCase, rep.epochfiles_ingested_seen, 1);
verifyEqual(testCase, rep.refused_no_epoch, 0);              % epoch DOES resolve
verifyEqual(testCase, rep.rename_skipped_no_filenavigator, 1);
verifyEqual(testCase, rep.manifests_renamed, 0);
verifyEqual(testCase, rep.rename_quarantined, 0);
% the source document is preserved unchanged as the tombstone class
verifyEqual(testCase, numel(bodiesOfClass(out, 'ingestion_manifest')), 0);
verifyEqual(testCase, numel(bodiesOfClass(out, 'epochfiles_ingested')), 1);
end

% ===================== no epoch document ==============================

function testAnIngestedDocWithNoMintedEpochIsRefused(testCase)
% If no `epoch` document exists for the ingested epoch (e.g. no session document,
% so epochMint refused to mint one), the whole ingested document is refused and
% nothing is emitted -- the anchor's required `relative_to` would have nowhere to
% point.
subj = subjectBody('spec_n', 'sess_n', 'L');
el   = elementBody('el_n', 'sess_n', 'tet', '1', 'n-trode', 1, 'spec_n');
ing  = ingestedWithRows('ing_n', 'sess_n', 't0n', {{'tet', '1', 'n-trode', 'L'}});
% NO session document -> epochMint mints no epoch for (sess_n, t0n).
[out, rep] = decompose({subj, el, ing});
verifyEqual(testCase, rep.epochfiles_ingested_seen, 1);
verifyEqual(testCase, rep.refused_no_epoch, 1);
verifyEqual(testCase, rep.observations_emitted, 0);
verifyEmpty(testCase, bodiesNamed(out, 'migrated_probemap_observation'));
end

% ===================== fixtures, from the NDI writer ===================

function v1 = ingestedWithRows(docId, sessionId, epochId, rows)
%INGESTEDWITHROWS A did_v1 epochfiles_ingested whose epochprobemap serialises the
%   given rows, each {name, reference, type, subjectstring}. devicestring is a
%   constant 'vhspike2:ai11-14' (parsed by the device half but resolving to no
%   acquisition_system in these fixtures). For a per-row devicestring, use
%   ingestedWithDeviceRows. Exact serialize() shape.
pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n');
for i = 1:numel(rows)
    r = rows{i};
    pm = [pm, sprintf('%s\t%s\t%s\tvhspike2:ai11-14\t%s\n', ...
        r{1}, r{2}, r{3}, r{4})]; %#ok<AGROW>
end
v1 = ingestedRaw(docId, sessionId, epochId, pm);
end

function v1 = ingestedRaw(docId, sessionId, epochId, probemapValue)
%INGESTEDRAW A did_v1 epochfiles_ingested. Block key set {epoch_id, epochprobemap,
%   files}, dependency {filenavigator_id}, exactly as corpus B's documents carry.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name',         'epochfiles_ingested', ...
    'property_list_name', 'epochfiles_ingested', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', 'nav_1');
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
blk = struct();
blk.epoch_id = epochId;
blk.files = {['epochid://' epochId]};
blk.epochprobemap = probemapValue;
v1.epochfiles_ingested = blk;
end

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 session document. base.id and base.session_id are DIFFERENT
%   strings, as ndi.document / ndi.session mint them.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/session.json', ...
    'validation',         '$NDISCHEMAPATH/session.json', ...
    'class_name',         'session', ...
    'property_list_name', 'session', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', reference);
end

function el = elementBody(docId, sessionId, name, reference, typ, direct, subjectId)
%ELEMENTBODY A did_v1 element. A DIRECT element drives jRecordingObservation to a
%   #30 recording observation of the SPECIMEN, with instrument_id = docId (the
%   element-subject, id preserved). Its subject local_identifier becomes
%   'name (ref reference)', which is the join key a probemap row reconstructs.
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
el.depends_on = struct('name', {'subject_id'}, 'value', {subjectId});
el.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
    'name', name, 'reference', reference, 'type', typ, 'direct', direct);
end

function el = derivedElementBody(docId, sessionId, name, typ, underlyingId)
%DERIVEDELEMENTBODY A did_v1 DERIVED element (direct = 0) with an
%   underlying_element_id -- a sorted neuron on a probe. For type 'spikes' this
%   drives element.m's spike-train leaf: a #30 observation whose SUBJECT is this
%   element (the neuron, id preserved) and whose INSTRUMENT is the underlying
%   probe. That is what puts a SECOND #30 observation on the probe's instrument.
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
el.depends_on = struct('name', {'underlying_element_id'}, 'value', {underlyingId});
el.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', 'ndi.neuron', ...
    'name', name, 'reference', '1', 'type', typ, 'direct', 0);
end

function v1 = daqsystemBody(docId, sessionId, deviceName)
%DAQSYSTEMBODY A did_v1 daqsystem; +migrators_j/daqsystem.m folds it to an
%   `acquisition_system` with base.id AND base.name PRESERVED. base.name is the
%   device half's join key (the name before the ':' in a devicestring).
v1 = struct();
v1.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', deviceName, 'datestamp', '2024-05-01T00:00:00.000Z');
% ndi_daqsystem_class MUST be non-empty: daqsystem.m returns the source as a
% (quarantining) passthrough when implClass AND all edges are empty, so a hollow
% fixture never becomes an acquisition_system. A real class name takes the
% software-fold path and PRESERVES base.id + base.name onto the acquisition_system.
v1.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
v1.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'id', {'', ''});
end

function v1 = ingestedWithDeviceRows(docId, sessionId, epochId, rows)
%INGESTEDWITHDEVICEROWS Like ingestedWithRows, but each row is the FULL 5-tuple
%   {name, reference, type, devicestring, subjectstring} so a test can drive the
%   device half. Exact serialize() shape.
pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n');
for i = 1:numel(rows)
    r = rows{i};
    pm = [pm, sprintf('%s\t%s\t%s\t%s\t%s\n', ...
        r{1}, r{2}, r{3}, r{4}, r{5})]; %#ok<AGROW>
end
v1 = ingestedRaw(docId, sessionId, epochId, pm);
end

function v1 = subjectBody(docId, sessionId, localId)
%SUBJECTBODY A did_v1 subject carrying a local_identifier the subject migrator
%   preserves. The SPECIMEN a probemap subjectstring is joined against.
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', localId, 'description', '');
end

% ===================== helpers ============================================

function out = bodiesNamed(result, baseName)
%BODIESNAMED Migrated bodies (as structs) whose base.name == BASENAME.
out = {};
for k = 1:numel(result.migrated)
    b = result.migrated{k}.toStruct();
    if isfield(b, 'base') && isfield(b.base, 'name') ...
            && strcmp(char(b.base.name), baseName)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function out = bodiesOfClass(result, className)
%BODIESOFCLASS Migrated bodies (as structs) of document_class className.
out = {};
for k = 1:numel(result.migrated)
    b = result.migrated{k}.toStruct();
    if isfield(b, 'document_class') && isfield(b.document_class, 'class_name') ...
            && strcmp(char(b.document_class.class_name), className)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function v = depVal(b, name)
%DEPVAL Value of one depends_on entry on a body STRUCT, '' when absent/empty.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps); items = deps(:)';
elseif isstruct(deps); items = num2cell(deps(:)');
else; return; end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value); v = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
    return;
end
end
