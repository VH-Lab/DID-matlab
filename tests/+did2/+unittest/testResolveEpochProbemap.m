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

function testTwoObservationsMintedOneRowRefusedAndObservesRetired(testCase)
% RENAMED 2026-10-21 from testTwoObservationsMintedOneRowRefusedAndTheHash30ObsRetired.
% Pass 1 no longer emits the session-wide "#30" observation (Jess Haley,
% 2026-10-21: one observation per element PER EPOCH, its epoch files as data
% bodies), so there is no #30 observation to retire: session30_observations_retired
% is now 0. What pass 1 leaves instead is the loose `observes` relation (el_1
% observes specimen_1), and THAT is what this pass retires once an observation
% carries el_1 as instrument_id. Each observation is `data_body` true. The
% fixture names no file (only `epochid://`), so the epoch is counted
% epochs_no_file_named and no body is minted.
% UPDATED for did-schema #88. Two of three rows decompose (the third names a
% subject not in the batch); the observations are of the specimen, anchored at
% the minted epoch, with the probe as instrument where it resolves and the
% channels on a shared acquisition_channels document. NEW ON #88: the
% ingestion_manifest has no epochprobemap slot (#73 item 39), so the source is
% renamed ONLY when every row decomposed; here one did not, so the
% epochfiles_ingested passes through intact (rename_skipped_rows_without_home).
subj = subjectBody('specimen_1', 'sess_1', 'L');
el   = elementBody('el_1', 'sess_1', 'tet', '1', 'n-trode', 1, 'specimen_1');
ing  = ingestedWithRows('ing_1', 'sess_1', 't00001', { ...
    {'tet', '1', 'n-trode', 'L'}, ...
    {'tet', '2', 'n-trode', 'L'}, ...
    {'tet', '3', 'n-trode', 'x@lab'}});
[out, rep] = decompose({sessionBody('sd_1', 'sess_1', 'ref'), subj, el, ing});

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
verifyEqual(testCase, rep.session30_observations_retired, 0);   % none emitted by pass 1 now
verifyEqual(testCase, rep.retire_skipped_ambiguous, 0);
verifyEqual(testCase, rep.fold_quarantined, 0);
verifyEqual(testCase, rep.observes_retired, 1);
verifyEqual(testCase, rep.epochs_with_observations, 1);
verifyEqual(testCase, rep.epochs_no_file_named, 1);
verifyEqual(testCase, rep.bodies_by_location + rep.bodies_from_archive, 0);
verifyEqual(testCase, rep.device_strings_seen, 2);
verifyEqual(testCase, rep.device_acqsystem_unresolved, 2);
verifyEqual(testCase, rep.device_acqsystem_resolved, 0);
verifyEqual(testCase, rep.device_channels_parsed, 2);
verifyEqual(testCase, rep.manifests_renamed, 0);
verifyEqual(testCase, rep.rename_skipped_rows_without_home, 1);
verifyEqual(testCase, rep.rename_quarantined, 0);
refused = rep.rows_no_subjectstring + rep.refused_no_subject;
deferred = rep.rows_unresolved_modality + rep.rows_image_deferred;
verifyEqual(testCase, rep.probe_rows_total, ...
    rep.observations_emitted + rep.manipulations_emitted + refused + deferred);

obs = bodiesNamed(out, 'migrated_probemap_observation');
verifyEqual(testCase, numel(obs), 2);
anchorIds = {};
withInstrument = 0;
for i = 1:numel(obs)
    b = obs{i};
    verifyEqual(testCase, char(did2.unittest.helpers.classKey(b)), 'observation+voltage');
    verifyTrue(testCase, logical(b.value.data_body));   % its value is the epoch's files
    verifyEqual(testCase, depVal(b, 'entity_id'), 'specimen_1');
    tr = depVal(b, 'time_reference_id');
    verifyNotEmpty(testCase, tr);
    anchorIds{end+1} = tr; %#ok<AGROW>
    inst = depVal(b, 'instrument_id');
    if ~isempty(inst)
        verifyEqual(testCase, inst, 'el_1');   % the RESOLVED probe-subject
        withInstrument = withInstrument + 1;
    end
    ch = channelsOf(out, b);
    verifyEqual(testCase, numel(ch), 1);                 % one group: ai11-14
    verifyEqual(testCase, char(ch(1).type.name), 'ai');
    verifyEqual(testCase, double(ch(1).numbers(:))', [11 12 13 14]);
end
verifyEqual(testCase, withInstrument, 1);
verifyEqual(testCase, numel(unique(anchorIds)), 1);
anchors = bodiesNamed(out, 'migrated_probemap_epoch_anchor');
verifyEqual(testCase, numel(anchors), 1);
a = anchors{1};
verifyEqual(testCase, a.base.id, anchorIds{1});
verifyEqual(testCase, char(a.relative_time_reference.value.relation.name), 'intervalDuring');
epochs = bodiesOfClass(out, 'epoch');
verifyEqual(testCase, numel(epochs), 1);
verifyEqual(testCase, depVal(a, 'referent_id'), epochs{1}.base.id);
verifyEqual(testCase, numel(bodiesNamed(out, 'migrated_recording_observation')), 0);
% the source passes through intact: its third row has no home on #88
verifyEqual(testCase, numel(bodiesOfClass(out, 'ingestion_manifest')), 0);
src = bodiesOfClass(out, 'epochfiles_ingested');
verifyEqual(testCase, numel(src), 1);
verifyEqual(testCase, src{1}.epochfiles_ingested.epochprobemap, ...
    ing.epochfiles_ingested.epochprobemap);
end


% ===================== the triple key resolves patch/sharp ===============

function testAPatchRowShareOneFileBodyAndRetireObserves(testCase)
% RENAMED 2026-10-21 from testAPatchElementRetiresBOTHClassesViaTheTripleKey.
% The two #30 observations it retired are no longer emitted by pass 1. The
% patch row still yields TWO observations (voltage + current); both were
% recorded in the epoch's one file, so that file is ONE opaque_body owned by
% BOTH (owner_id repeats, did-schema data_body 2026-10-21), recorded by
% location, and the element's `observes` relation is retired.
subj = subjectBody('specimen_2', 'sess_2', 'L');
el   = elementBody('el_2', 'sess_2', 'pat', '1', 'patch', 1, 'specimen_2');
ing  = ingestedWithRows('ing_2', 'sess_2', 't00002', { ...
    {'pat', '1', 'patch', 'L'}}, {'/data/t00002/cell.abf'});
[out, rep] = decompose({sessionBody('sd_2', 'sess_2', 'ref'), subj, el, ing});
verifyEqual(testCase, rep.observations_emitted, 2);
verifyEqual(testCase, rep.session30_observations_retired, 0);
verifyEqual(testCase, rep.observes_retired, 1);
verifyEqual(testCase, rep.bodies_by_location, 1);
verifyEqual(testCase, rep.body_owner_links, 2);
verifyEqual(testCase, rep.bodies_quarantined, 0);
obs = bodiesNamed(out, 'migrated_probemap_observation');
ids = sort(cellfun(@(b) char(b.base.id), obs, 'UniformOutput', false));
bodies = bodiesOfClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 1);
verifyEqual(testCase, sort(depVals(bodies{1}, 'owner_id')), ids);
verifyEqual(testCase, char(bodies{1}.files.file_info(1).locations.location), '/data/t00002/cell.abf');
verifyEqual(testCase, double(bodies{1}.files.file_info(1).locations.ingest), 0);
verifyEqual(testCase, numel(bodiesNamed(out, 'migrated_recording_observation')), 0);
end

function testASpikeSortedProbeGetsOnlyItsOwnEpochObservation(testCase)
% RENAMED 2026-10-21 from testASpikeSortedProbeRetiresOnlyItsOwnDirectRecording.
% Pass 1 now emits no observation for EITHER element (the probe's is per
% epoch, minted here; the neuron's spike train waits on an open question about
% its element_epoch body), so the probe row yields one voltage observation and
% nothing about the neuron is touched.
subj = subjectBody('specimen_sp', 'sess_sp', 'L');
elP  = elementBody('el_probe', 'sess_sp', 'tet', '1', 'n-trode', 1, 'specimen_sp');
elN  = derivedElementBody('el_neuron', 'sess_sp', 'n1', 'spikes', 'el_probe');
ing  = ingestedWithRows('ing_sp', 'sess_sp', 't00sp', { ...
    {'tet', '1', 'n-trode', 'L'}});
[out, rep] = decompose({sessionBody('sd_sp', 'sess_sp', 'ref'), subj, elP, elN, ing});
verifyEqual(testCase, rep.observations_emitted, 1);
verifyEqual(testCase, rep.session30_observations_retired, 0);
verifyEqual(testCase, rep.observes_retired, 1);
verifyEqual(testCase, numel(bodiesNamed(out, 'migrated_recording_observation')), 0);
obs = bodiesNamed(out, 'migrated_probemap_observation');
verifyEqual(testCase, depVal(obs{1}, 'instrument_id'), 'el_probe');
end

% ===================== the epoch's files as bodies (2026-10-21) =========

function testAGzippedFileBodyStatesItsCompression(testCase)
% Jess Haley, 2026-10-21 ("a"): a data body's `compression` is 'gzip' when the
% file name ends in .tgz or .gz, and is left empty otherwise.
subj = subjectBody('specimen_z', 'sess_z', 'L');
el   = elementBody('el_z', 'sess_z', 'pat', '1', 'patch', 1, 'specimen_z');
ing  = ingestedWithRows('ing_z', 'sess_z', 't00009', { ...
    {'pat', '1', 'patch', 'L'}}, {'/data/t00009/seg.nbf.tgz', '/data/t00009/cell.abf'});
[out, rep] = decompose({sessionBody('sd_z', 'sess_z', 'ref'), subj, el, ing});
verifyEqual(testCase, rep.bodies_quarantined, 0);
bodies = bodiesOfClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 2);
seen = 0;
for i = 1:numel(bodies)
    db = bodies{i}.data_body;
    hasComp = isfield(db, 'compression') && ~isempty(db.compression);
    switch char(db.filename)
        case 'seg.nbf.tgz'
            verifyTrue(testCase, hasComp, 'a .tgz file body states its compression');
            if hasComp; verifyEqual(testCase, char(db.compression), 'gzip'); end
            seen = seen + 1;
        case 'cell.abf'
            verifyFalse(testCase, hasComp, 'an uncompressed file leaves compression empty');
            seen = seen + 1;
    end
end
verifyEqual(testCase, seen, 2, 'both file bodies inspected');
end

function testTwoProbesInOneFileShareItsBodyAndEachKeepsItsChannels(testCase)
% Jess Haley, 2026-10-21: an opaque_body per epoch file, SHARED by the
% electrodes recorded in it, with the channel map. Two n-trodes on different
% channels of one Intan file -> one body per named file (the .rhd and the
% channel-grouping .txt), each owned by BOTH observations; each observation's
% channels are its own acquisition_channels document. `epochid://` is not a
% file. Formats by extension: .rhd Binary format, .txt Textual format.
subj = subjectBody('spec_f', 'sess_f', 'L');
ing  = ingestedWithDeviceRows('ing_f', 'sess_f', 't0f', { ...
    {'a', '', 'n-trode', 'intan1:ai1-4', 'L'}, ...
    {'b', '', 'n-trode', 'intan1:ai5-8', 'L'}}, ...
    {'/data/t0f/t0f.rhd', '/data/t0f/vhintan_channelgrouping.txt'});
[out, rep] = decompose({sessionBody('sd_f', 'sess_f', 'ref'), subj, ing});
verifyEqual(testCase, rep.observations_emitted, 2);
verifyEqual(testCase, rep.epochs_by_location, 1);
verifyEqual(testCase, rep.bodies_by_location, 2);
verifyEqual(testCase, rep.bodies_size_and_checksum_omitted, 2);
verifyEqual(testCase, rep.body_owner_links, 4);
verifyEqual(testCase, rep.bodies_quarantined, 0);
obs = bodiesNamed(out, 'migrated_probemap_observation');
ids = sort(cellfun(@(b) char(b.base.id), obs, 'UniformOutput', false));
bodies = bodiesOfClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 2);
fmts = {};
for i = 1:numel(bodies)
    verifyEqual(testCase, sort(depVals(bodies{i}, 'owner_id')), ids);
    verifyEqual(testCase, char(bodies{i}.files.file_info(1).locations.location_type), 'file');
    fmts{end+1} = char(bodies{i}.data_body.format.node); %#ok<AGROW>
end
verifyEqual(testCase, sort(fmts), sort({'EDAM:format_2333', 'EDAM:format_2330'}));
ch1 = channelsOf(out, obs{1}); ch2 = channelsOf(out, obs{2});
verifyNotEqual(testCase, double(ch1(1).numbers(:))', double(ch2(1).numbers(:))');
end

function testAnIngestedEpochTakesItsArchiveAsAttached(testCase)
% INGESTED: the recording is the archive attached to the epoch's
% daqreader_*_epochdata_ingested document, found through the acquisition
% system (epoch_file_pattern_id = the epochfiles' filenavigator_id, reader_id =
% the archive's daqreader_id) at the same epoch. One opaque_body per attached
% series, members in segment order as body_data_0..N-1 with their locations
% VERBATIM; a declared series with no attached member is skipped; the raw file
% paths the cache names are NOT used.
subj = subjectBody('spec_i', 'sess_i', 'L');
daq  = struct();
daq.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
daq.base = struct('id', 'acqsys_i', 'session_id', 'sess_i', ...
    'name', 'intan1', 'datestamp', '2024-05-01T00:00:00.000Z');
daq.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
daq.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'value', {'nav_1', 'rdr_i'});
arc = struct();
arc.document_class = struct('class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
arc.base = struct('id', 'arc_i', 'session_id', 'sess_i', 'name', '', ...
    'datestamp', '2024-05-01T00:00:00.000Z');
arc.depends_on = struct('name', 'daqreader_id', 'value', 'rdr_i');
arc.epochid = struct('epochid', 't0i');
arc.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0 10]));
loc = @(u) struct('delete_original', 0, 'uid', u, 'location', ['ndic://ds/' u], ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0);
arc.files = struct('file_list', {{'ai_group1_seg.nbf_#', 'channel_list.bin', 'di_group1_seg.nbf_#'}}, ...
    'file_info', struct('name', {'ai_group1_seg.nbf_2', 'channel_list.bin', 'ai_group1_seg.nbf_1'}, ...
        'locations', {loc('u2'), loc('uc'), loc('u1')}));
ing  = ingestedWithDeviceRows('ing_i', 'sess_i', 't0i', { ...
    {'p', '', 'n-trode', 'intan1:ai1-4', 'L'}}, {'/raw/t0i/t0i.rhd'});
[out, rep] = decompose({sessionBody('sd_i', 'sess_i', 'ref'), subj, daq, arc, ing});
verifyEqual(testCase, rep.observations_emitted, 1);
verifyEqual(testCase, rep.epochs_from_archive, 1);
verifyEqual(testCase, rep.bodies_from_archive, 2);
verifyEqual(testCase, rep.archive_members_carried, 3);
verifyEqual(testCase, rep.bodies_by_location, 0);
verifyEqual(testCase, rep.bodies_quarantined, 0);
bodies = bodiesOfClass(out, 'opaque_body');
verifyEqual(testCase, numel(bodies), 2);
for i = 1:numel(bodies)
    fi = bodies{i}.files.file_info;
    switch char(bodies{i}.data_body.filename)
        case 'ai_group1_seg.nbf_#'
            verifyEqual(testCase, {fi.name}, {'body_data_0', 'body_data_1'});
            verifyEqual(testCase, {fi(1).locations.uid, fi(2).locations.uid}, {'u1', 'u2'});
        case 'channel_list.bin'
            verifyEqual(testCase, numel(fi), 1);
            verifyEqual(testCase, char(fi(1).locations.uid), 'uc');
        otherwise
            verifyFail(testCase, 'an unexpected archive body');
    end
end
% Jess Haley, 2026-10-21 ("a"): every file the v1 archive holds (both
% ai_group1 members and channel_list.bin) is carried by a surviving body and
% nothing that survives names it, so the archive document is RETIRED.
verifyEqual(testCase, rep.archive_docs_inspected, 1);
verifyEqual(testCase, rep.archive_docs_retired, 1);
verifyEqual(testCase, rep.archive_docs_kept_unowned_files, 0);
verifyEqual(testCase, rep.archive_dangling_references, 0);
verifyEmpty(testCase, docById(out, 'arc_i'), 'the fully-owned archive is retired');
end

function testAnArchiveWithAFileNoBodyCarriesIsKept(testCase)
% The same ingested epoch, but the archive also holds a file no data body
% carries (`stray.bin`, attached but in no declared series): the document is
% KEPT, and the unowned file is counted. Verified per document.
subj = subjectBody('spec_k', 'sess_k', 'L');
daq  = struct();
daq.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
daq.base = struct('id', 'acqsys_k', 'session_id', 'sess_k', ...
    'name', 'intan1', 'datestamp', '2024-05-01T00:00:00.000Z');
daq.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
daq.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'value', {'nav_1', 'rdr_k'});
arc = struct();
arc.document_class = struct('class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
arc.base = struct('id', 'arc_k', 'session_id', 'sess_k', 'name', '', ...
    'datestamp', '2024-05-01T00:00:00.000Z');
arc.depends_on = struct('name', 'daqreader_id', 'value', 'rdr_k');
arc.epochid = struct('epochid', 't0k');
arc.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0 10]));
loc = @(u) struct('delete_original', 0, 'uid', u, 'location', ['ndic://ds/' u], ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0);
arc.files = struct('file_list', {{'ai_group1_seg.nbf_#'}}, ...
    'file_info', struct('name', {'ai_group1_seg.nbf_1', 'stray.bin'}, ...
        'locations', {loc('u1'), loc('us')}));
ing  = ingestedWithDeviceRows('ing_k', 'sess_k', 't0k', { ...
    {'p', '', 'n-trode', 'intan1:ai1-4', 'L'}}, {'/raw/t0k/t0k.rhd'});
[out, rep] = decompose({sessionBody('sd_k', 'sess_k', 'ref'), subj, daq, arc, ing});
verifyEqual(testCase, rep.bodies_from_archive, 1);
verifyEqual(testCase, rep.archive_docs_inspected, 1);
verifyEqual(testCase, rep.archive_docs_retired, 0);
verifyEqual(testCase, rep.archive_docs_kept_unowned_files, 1);
verifyEqual(testCase, rep.archive_files_unowned, 1);
verifyNotEmpty(testCase, docById(out, 'arc_k'), 'an archive with an unowned file is kept');
end

% ===================== spike trains (2026-10-21) ========================

function v1 = elementEpochBody(docId, sessionId, elementId, epochId, withFile)
%ELEMENTEPOCHBODY A did_v1 element_epoch, as NDI's writer makes it
%   (+ndi/element.m:367-378: newdocument('element_epoch', 'element_epoch.
%   epoch_clock', ..., 'element_epoch.t0_t1', ..., 'epochid.epochid', ...),
%   set_dependency_value('element_id', ...)), with the epoch's samples attached
%   as `epoch_binary_data.vhsb` (ndi.element.timeseries.addepoch).
v1 = struct();
v1.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', [struct('class_name', 'base', 'class_version', '1.0.0'), ...
                     struct('class_name', 'epochid', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', elementId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0 10]);
v1.epochid = struct('epochid', epochId);
if withFile
    v1.files = struct('file_list', {{'epoch_binary_data.vhsb'}}, ...
        'file_info', struct('name', 'epoch_binary_data.vhsb', 'locations', ...
            struct('delete_original', 0, 'uid', 'vhsb_1', ...
                'location', '/data/t00sp/neuron.vhsb', 'parameters', '', ...
                'location_type', 'file', 'ingest', 1)));
else
    v1.files = struct('file_list', {{'epoch_binary_data.vhsb'}});
end
end

function testASortedNeuronGetsOneSpikeTrainObservationPerEpoch(testCase)
% Jess Haley, 2026-10-21 ("a"): a spike-sorted neuron gets one observation per
% epoch -- entity the neuron (id preserved), instrument the probe it was
% sorted from, value kind time, `data_body` true, variable GO:0001508
% "action potential" -- with its element_epoch's .vhsb as the opaque_body.
subj = subjectBody('specimen_sp', 'sess_sp', 'L');
elP  = elementBody('el_probe', 'sess_sp', 'tet', '1', 'n-trode', 1, 'specimen_sp');
elN  = derivedElementBody('el_neuron', 'sess_sp', 'n1', 'spikes', 'el_probe');
ee   = elementEpochBody('ee_1', 'sess_sp', 'el_neuron', 't00sp', true);
ing  = ingestedWithRows('ing_sp', 'sess_sp', 't00sp', {{'tet', '1', 'n-trode', 'L'}});
[out, rep] = decompose({sessionBody('sd_sp', 'sess_sp', 'ref'), subj, elP, elN, ee, ing});
verifyEqual(testCase, rep.spike_epochs_seen, 1);
verifyEqual(testCase, rep.spike_trains_emitted, 1);
verifyEqual(testCase, rep.spike_instrument_resolved, 1);
verifyEqual(testCase, rep.spike_bodies, 1);
verifyEqual(testCase, rep.spike_bodies_quarantined, 0);
verifyEqual(testCase, rep.observations_emitted, 1, 'the probe row is still its own observation');
spike = {};
obsAll = bodiesOfClass(out, 'observation+time');
for i = 1:numel(obsAll)
    if strcmp(depVal(obsAll{i}, 'entity_id'), 'el_neuron'); spike{end+1} = obsAll{i}; end %#ok<AGROW>
end
assertEqual(testCase, numel(spike), 1, 'one spike-train observation of the neuron');
o = spike{1};
verifyTrue(testCase, isfield(o, 'time'), 'the value kind is time');
verifyEqual(testCase, depVal(o, 'instrument_id'), 'el_probe');
verifyEqual(testCase, char(o.statement.variable.node), 'GO:0001508');
verifyEqual(testCase, char(o.statement.variable.name), 'action potential');
b = {};
ob = bodiesOfClass(out, 'opaque_body');
for i = 1:numel(ob)
    if any(strcmp(depVals(ob{i}, 'owner_id'), char(o.base.id))); b{end+1} = ob{i}; end %#ok<AGROW>
end
assertEqual(testCase, numel(b), 1, 'the spike train owns exactly one body');
verifyEqual(testCase, char(b{1}.data_body.filename), 'epoch_binary_data.vhsb');
verifyEqual(testCase, char(b{1}.files.file_info(1).locations.location), '/data/t00sp/neuron.vhsb');
end

function testASpikeEpochWithNoVhsbFileEmitsNoObservation(testCase)
% No epoch_binary_data.vhsb attached: no file to be the body, so no
% observation (never a bodiless one); counted.
subj = subjectBody('specimen_sq', 'sess_sq', 'L');
elP  = elementBody('el_probe_q', 'sess_sq', 'tet', '1', 'n-trode', 1, 'specimen_sq');
elN  = derivedElementBody('el_neuron_q', 'sess_sq', 'n1', 'spikes', 'el_probe_q');
ee   = elementEpochBody('ee_q', 'sess_sq', 'el_neuron_q', 't00sq', false);
ing  = ingestedWithRows('ing_sq', 'sess_sq', 't00sq', {{'tet', '1', 'n-trode', 'L'}});
[~, rep] = decompose({sessionBody('sd_sq', 'sess_sq', 'ref'), subj, elP, elN, ee, ing});
verifyEqual(testCase, rep.spike_epochs_seen, 1);
verifyEqual(testCase, rep.spike_epochs_no_file, 1);
verifyEqual(testCase, rep.spike_trains_emitted, 0);
verifyEqual(testCase, rep.spike_bodies, 0);
end

% ===================== pyraview levels (2026-10-21) =====================

function v1 = pyraviewV1(docId, sessionId, elementId, epochId)
%PYRAVIEWV1 A did_v1 pyraview (the PRED shape; testMigratorsJMeasurementFilter's
%   fixture) naming element ELEMENTID at epoch EPOCHID, two levels.
v1 = struct();
v1.document_class = struct('class_name', 'pyraview', 'class_version', '1.0.0', ...
    'superclasses', [struct('class_name', 'base', 'class_version', '1.0.0'), ...
                     struct('class_name', 'epochid', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {elementId});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'pyr', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.pyraview = struct('label', 'high', 'native_rate', 20000, ...
    'native_start_time', 0, 'channels', 4, 'data_type', 'double', ...
    'decimation_sampling_rates', [20000 200]);
v1.files = struct('file_list', {{'level1.bin', 'level2.bin'}});
v1.epochclocktimes = struct('clocktype', 'dev_local_time', 't0_t1', [0 10]);
v1.epochid = struct('epochid', epochId);
end

function testPyraviewLevelsMoveToTheEpochsRecordingObservation(testCase)
% Jess Haley, 2026-10-21 ("a"): each pyraview level is a data body owned by
% that epoch's recording observation (the one emitted here for the same
% element and epoch), and the separate pyraview observation is retired.
subj = subjectBody('specimen_pv', 'sess_pv', 'L');
el   = elementBody('el_pv', 'sess_pv', 'tet', '1', 'n-trode', 1, 'specimen_pv');
ing  = ingestedWithRows('ing_pv', 'sess_pv', 't00pv', {{'tet', '1', 'n-trode', 'L'}});
pv   = pyraviewV1('pv_1', 'sess_pv', 'el_pv', 't00pv');
[out, rep] = decompose({sessionBody('sd_pv', 'sess_pv', 'ref'), subj, el, ing, pv});
verifyEqual(testCase, rep.pyraview_observations_seen, 1);
verifyEqual(testCase, rep.pyraview_observations_retired, 1);
verifyEqual(testCase, rep.pyraview_levels_repointed, 2);
verifyEqual(testCase, rep.pyraview_kept_no_recording_observation, 0);
verifyEmpty(testCase, docById(out, 'pv_1'), 'the separate pyraview observation is retired');
obs = bodiesNamed(out, 'migrated_probemap_observation');
assertEqual(testCase, numel(obs), 1);
recId = char(obs{1}.base.id);
levels = bodiesOfClass(out, 'sampled_body');
verifyEqual(testCase, numel(levels), 2);
for i = 1:numel(levels)
    verifyEqual(testCase, depVals(levels{i}, 'owner_id'), {recId}, ...
        'a level body is owned by the recording observation');
end
end

% ---- [pyraview leftovers, schema form] (Jess Haley, 2026-10-21) ----------
% did-schema V_eta_recording_observation_plan.md: "the retired pyraview
% observation's data type goes on the recording observation's value
% (value.data_type, which covers its sampled_body levels; a sampled_body never
% repeats it), and a time anchor that does not equal the epoch becomes the
% level body's time key (start offset) and is counted. No new body fields."

function [out, rep] = pyraviewFold(pvT0T1, nativeStart, withEpochExtent)
%PYRAVIEWFOLD One probe, one epoch, one pyraview. WITHEPOCHEXTENT adds NDI's
%   element_epoch for the probe (t0_t1 [0 10] on dev_local_time), which is
%   where epochMint reads the epoch's own extent from.
subj = subjectBody('specimen_pf', 'sess_pf', 'L');
el   = elementBody('el_pf', 'sess_pf', 'tet', '1', 'n-trode', 1, 'specimen_pf');
ing  = ingestedWithRows('ing_pf', 'sess_pf', 't00pf', {{'tet', '1', 'n-trode', 'L'}});
pv   = pyraviewV1('pv_f', 'sess_pf', 'el_pf', 't00pf');
pv.epochclocktimes.t0_t1 = pvT0T1;
pv.pyraview.native_start_time = nativeStart;
v1 = {sessionBody('sd_pf', 'sess_pf', 'ref'), subj, el, ing, pv};
if withEpochExtent
    v1{end+1} = elementEpochBody('ee_pf', 'sess_pf', 'el_pf', 't00pf', false);
end
[out, rep] = decompose(v1);
end

function testThePyraviewDataTypeLandsOnTheRecordingObservationsValue(testCase)
[out, rep] = pyraviewFold([0 10], 0, true);
verifyEqual(testCase, rep.pyraview_observations_retired, 1);
verifyEqual(testCase, rep.pyraview_data_type_moved, 1);
verifyEqual(testCase, rep.pyraview_kept_data_type_conflict, 0);
obs = bodiesNamed(out, 'migrated_probemap_observation');
assertEqual(testCase, numel(obs), 1);
% the v1 'double', normalised; the source spelling kept beside it
verifyEqual(testCase, char(obs{1}.value.data_type), 'float64');
verifyEqual(testCase, char(obs{1}.value.source_data_type), 'double');
% "a sampled_body never repeats it": no new body field
levels = bodiesOfClass(out, 'sampled_body');
verifyEqual(testCase, numel(levels), 2);
for i = 1:numel(levels)
    verifyFalse(testCase, isfield(levels{i}.sampled_body, 'data_type'));
    verifyFalse(testCase, isfield(levels{i}.sampled_body, 'source_data_type'));
end
end

function testAnAnchorEqualToTheEpochIsDroppedAndCounted(testCase)
% pyraview t0_t1 [0 10] on dev_local_time == the epoch's own extent (NDI's
% writer takes both from the epoch table, makePyraviewDoc.m).
[out, rep] = pyraviewFold([0 10], 0, true);
verifyEqual(testCase, rep.pyraview_anchor_equal_epoch_dropped, 1);
verifyEqual(testCase, rep.pyraview_anchor_to_time_key, 0);
verifyEqual(testCase, rep.pyraview_anchor_not_comparable_to_time_key, 0);
verifyEqual(testCase, rep.pyraview_kept_start_conflict, 0);
verifyEmpty(testCase, docById(out, 'pv_f'));
end

function testAnAnchorThatDiffersFromTheEpochBecomesTheTimeKeyStart(testCase)
% THE OTHER DIRECTION. The pyraview covers [2 10] of a [0 10] epoch: the anchor
% is not the epoch. Its start (2 s on the epoch's clock) is what the levels'
% time keys carry, so the move happens and is counted apart.
[out, rep] = pyraviewFold([2 10], 2, true);
verifyEqual(testCase, rep.pyraview_anchor_equal_epoch_dropped, 0);
verifyEqual(testCase, rep.pyraview_anchor_to_time_key, 1);
verifyEqual(testCase, rep.pyraview_observations_retired, 1);
levels = bodiesOfClass(out, 'sampled_body');
verifyEqual(testCase, numel(levels), 2);
for i = 1:numel(levels)
    k = levels{i}.data.keys;
    names = arrayfun(@(a) char(a.variable.name), k, 'UniformOutput', false);
    t = k(strcmp(names, 'time'));
    verifyEqual(testCase, double(t.origin.value), 2, 'the start offset is the time key origin');
end
end

function testAStartTheLevelsDoNotCarryKeepsThePyraview(testCase)
% A differing anchor whose start is NOT the levels' time origin: two facts
% disagree, neither is picked. Kept as it was, and counted.
[out, rep] = pyraviewFold([2 10], 0, true);
verifyEqual(testCase, rep.pyraview_kept_start_conflict, 1);
verifyEqual(testCase, rep.pyraview_observations_retired, 0);
verifyEqual(testCase, rep.pyraview_data_type_moved, 0);
verifyNotEmpty(testCase, docById(out, 'pv_f'));
% the recording observation is the one with the probe as instrument (the kept
% pyraview observation names none)
obs = bodiesNamed(out, 'migrated_probemap_observation');
rec = obs(cellfun(@(b) strcmp(depVal(b, 'instrument_id'), 'el_pf'), obs));
assertEqual(testCase, numel(rec), 1);
verifyTrue(testCase, ~isfield(rec{1}.value, 'data_type') || isempty(rec{1}.value.data_type), ...
    'nothing moved, so the recording observation gains no data type');
end

function testAnEpochWithNoExtentIsNotComparableNeverEqual(testCase)
% With no element_epoch the epoch states no extent: "not comparable" is its
% own count, never read as equal. The start still sits on the levels' time
% keys (0 == 0), so the move happens.
[~, rep] = pyraviewFold([0 10], 0, false);
verifyEqual(testCase, rep.pyraview_anchor_not_comparable_to_time_key, 1);
verifyEqual(testCase, rep.pyraview_anchor_equal_epoch_dropped, 0);
verifyEqual(testCase, rep.pyraview_observations_retired, 1);
end

function testAPyraviewWithNoRecordingObservationIsKeptAndCounted(testCase)
% No probemap row for the pyraview's element at that epoch: nothing to move
% to, so the pyraview observation and its levels stay as they were; counted.
subj = subjectBody('specimen_pw', 'sess_pw', 'L');
el   = elementBody('el_pw', 'sess_pw', 'tet', '1', 'n-trode', 1, 'specimen_pw');
elO  = elementBody('el_other', 'sess_pw', 'oth', '1', 'n-trode', 1, 'specimen_pw');
ing  = ingestedWithRows('ing_pw', 'sess_pw', 't00pw', {{'oth', '1', 'n-trode', 'L'}});
pv   = pyraviewV1('pv_2', 'sess_pw', 'el_pw', 't00pw');
[out, rep] = decompose({sessionBody('sd_pw', 'sess_pw', 'ref'), subj, el, elO, ing, pv});
verifyEqual(testCase, rep.pyraview_observations_seen, 1);
verifyEqual(testCase, rep.pyraview_observations_retired, 0);
verifyEqual(testCase, rep.pyraview_kept_no_recording_observation, 1);
verifyNotEmpty(testCase, docById(out, 'pv_2'), 'kept as it was');
levels = bodiesOfClass(out, 'sampled_body');
for i = 1:numel(levels)
    verifyEqual(testCase, depVals(levels{i}, 'owner_id'), {'pv_2'});
end
end

% ===================== [sorter input] (Jess Haley, 2026-10-21) ===========
% did-schema V_eta_go_forward_class_audit.md: spike-sorter output "takes as its
% input the per-epoch recording observations of the electrode it sorted, when
% they exist, falling back to the electrode entity when they do not".

function v1 = jrclustV1(docId, sessionId, elementId)
%JRCLUSTV1 A did_v1 jrclust_clusters as NDI's writer makes it
%   (+ndi/+fun/+probe/+import/+jrclust/probe.m: element_id = the probe, the
%   res.mat MD5, no attached file).
v1 = struct();
v1.document_class = struct('class_name', 'jrclust_clusters', 'class_version', '1.0.0', ...
    'superclasses', [struct('class_name', 'base', 'class_version', '1.0.0'), ...
                     struct('class_name', 'app', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {elementId});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'jc', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.jrclust_clusters = struct('res_mat_md5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');
end

function testASorterTakesTheElectrodesRecordingObservationsAsInput(testCase)
subj = subjectBody('specimen_js', 'sess_js', 'L');
el   = elementBody('el_js', 'sess_js', 'tet', '1', 'n-trode', 1, 'specimen_js');
ingA = ingestedWithRows('ing_jsa', 'sess_js', 't00jsa', {{'tet', '1', 'n-trode', 'L'}});
ingB = ingestedWithRows('ing_jsb', 'sess_js', 't00jsb', {{'tet', '1', 'n-trode', 'L'}});
jc   = jrclustV1('jc_s', 'sess_js', 'el_js');
[out, rep] = decompose({sessionBody('sd_js', 'sess_js', 'ref'), subj, el, ingA, ingB, jc});
verifyEqual(testCase, rep.sorter_calculations_seen, 1, 'DENOMINATOR');
verifyEqual(testCase, rep.sorter_inputs_linked, 1);
verifyEqual(testCase, rep.sorter_input_edges, 2, 'one recording observation per epoch');
verifyEqual(testCase, rep.sorter_input_fallback_entity, 0);
calc = docById(out, 'jc_s');
assertNotEmpty(testCase, calc);
verifyEqual(testCase, char(did2.unittest.helpers.classKey(calc)), 'calculation+label');
obs = bodiesNamed(out, 'migrated_probemap_observation');
recIds = {};
for i = 1:numel(obs)
    if strcmp(depVal(obs{i}, 'instrument_id'), 'el_js'); recIds{end+1} = char(obs{i}.base.id); end %#ok<AGROW>
end
verifyEqual(testCase, numel(recIds), 2);
verifyEqual(testCase, sort(depVals(calc, 'input_id')), sort(recIds));
verifyEqual(testCase, depVal(calc, 'entity_id'), 'el_js', 'still about the electrode');
end

function testASorterWithNoRecordingObservationFallsBackToTheElectrode(testCase)
% THE OTHER DIRECTION: no probemap row for the electrode, so no recording
% observation; the calculation keeps the electrode as its entity and gets NO
% input_id (input_id is typed to statements, never an entity). Counted.
subj = subjectBody('specimen_jf', 'sess_jf', 'L');
el   = elementBody('el_jf', 'sess_jf', 'tet', '1', 'n-trode', 1, 'specimen_jf');
elO  = elementBody('el_jo', 'sess_jf', 'oth', '1', 'n-trode', 1, 'specimen_jf');
ing  = ingestedWithRows('ing_jf', 'sess_jf', 't00jf', {{'oth', '1', 'n-trode', 'L'}});
jc   = jrclustV1('jc_f', 'sess_jf', 'el_jf');
[out, rep] = decompose({sessionBody('sd_jf', 'sess_jf', 'ref'), subj, el, elO, ing, jc});
verifyEqual(testCase, rep.sorter_calculations_seen, 1, 'DENOMINATOR');
verifyEqual(testCase, rep.sorter_inputs_linked, 0);
verifyEqual(testCase, rep.sorter_input_fallback_entity, 1);
calc = docById(out, 'jc_f');
assertNotEmpty(testCase, calc);
verifyEmpty(testCase, depVals(calc, 'input_id'));
verifyEqual(testCase, depVal(calc, 'entity_id'), 'el_jf');
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
subj = subjectBody('spec_m', 'sess_m', 'L');
ing  = ingestedWithRows('ing_m', 'sess_m', 't0m', { ...
    {'a', '', 'n-trode',              'L'}, ...   % voltage
    {'b', '', 'patch-i',              'L'}, ...   % current
    {'c', '', 'two-photon-imaging',   'L'}, ...   % intensity (no longer deferred, 2026-10-21)
    {'d', '', 'spikes',               'L'}, ...   % time
    {'e', '', 'accelerometer',        'L'}, ...   % acceleration
    {'f', '', 'thermometer',          'L'}, ...   % temperature
    {'g', '', 'extracellular_electrode-4', 'L'}}); % voltage (electrode stem)
[out, rep] = decompose({sessionBody('sd_m', 'sess_m', 'ref'), subj, ing});
verifyEqual(testCase, rep.probe_rows_total, 7);
verifyEqual(testCase, rep.observations_emitted, 7);
verifyEqual(testCase, rep.rows_image_deferred, 0);   % #88 + data bodies: imaging is an intensity_observation
verifyEqual(testCase, rep.rows_unresolved_modality, 0);
% UPDATED for #88: the leaf is the observation direction + its value kind
got = sort(cellfun(@(b) char(did2.unittest.helpers.classKey(b)), ...
    bodiesNamed(out, 'migrated_probemap_observation'), 'UniformOutput', false));
want = sort({'observation+voltage', 'observation+current', ...
    'observation+time', 'observation+acceleration', 'observation+temperature', ...
    'observation+voltage', 'observation+intensity'});
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
verifyEqual(testCase, char(did2.unittest.helpers.classKey(m)), 'manipulation+term');
verifyEqual(testCase, depVal(m, 'entity_id'), 'spec_s');
verifyNotEmpty(testCase, depVal(m, 'time_reference_id'));
end


function testStimManipulationCarriesTheStimulatorType(testCase)
% UPDATED for #88: no storage_mode; the stimulator type is the variable and the
% term value.
[~, ~, manips] = stimDecompose();
assertNotEmpty(testCase, manips);
m = manips{1};
verifyEqual(testCase, char(m.statement.variable.name), 'stimulator');
verifyEqual(testCase, char(m.term.value.name), 'stimulator');
end


% ===================== the device half (increment 2) ==================

% ---- #73 review item 61: the epoch's metadata archive ---------------------
% "data.bin (a .nbf.tgz of the epoch's parsed stimulus parameters, written by
% NDI metadatareader.ingest_epochfiles) becomes an opaque_body owned by the
% stimulator's term_manipulation for that epoch." The archive is found through
% the acquisition system: its epoch_file_pattern_id is the epochfiles'
% filenavigator_id and its epoch_parameter_reader_id (the v1
% daqmetadatareader_id_#) is the archive's daqmetadatareader_id, at the same
% epoch string. Fixtures follow the writer (NDI origin/main
% +ndi/+daq/metadatareader.m ingest_epochfiles: epochid block,
% daqmetadatareader_id edge, one file `data.bin` added from
% [metadatafile '.nbf.tgz']).
function [out, rep] = metadataDecompose(archiveEpoch)
subj = subjectBody('spec_m', 'sess_m', 'L');
stim = elementBody('stim_m', 'sess_m', 'stim', '1', 'stimulator', 1, 'spec_m');
daq = daqsystemBody('acqsys_m', 'sess_m', 'stimdev');
daq.depends_on = struct('name', {'filenavigator_id', 'daqreader_id', ...
    'daqmetadatareader_id_1'}, 'value', {'nav_1', 'rdr_m', 'mdr_m'});
ing = ingestedWithRows('ing_m', 'sess_m', 't0m', {{'stim', '1', 'stimulator', 'L'}});
[out, rep] = decompose({sessionBody('sd_m', 'sess_m', 'ref'), subj, stim, daq, ...
    metadataArchiveBody('mda_m', 'sess_m', 'mdr_m', archiveEpoch), ing});
end

function v1 = metadataArchiveBody(docId, sessionId, readerId, epochId)
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/daqmetadatareader_epochdata_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/daqmetadatareader_epochdata_ingested_schema.json', ...
    'class_name',         'daqmetadatareader_epochdata_ingested', ...
    'property_list_name', 'daqmetadatareader_epochdata_ingested', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', ...
        {'$NDIDOCUMENTPATH/base.json', '$NDIDOCUMENTPATH/epochid.json'}));
v1.depends_on = struct('name', 'daqmetadatareader_id', 'value', readerId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochid = struct('epochid', epochId);
v1.daqmetadatareader_epochdata_ingested = struct();
v1.files = struct('file_list', {{'data.bin'}}, ...
    'file_info', struct('name', 'data.bin', 'locations', struct( ...
        'delete_original', 0, 'uid', 'umd', 'location', '/tmp/abc123.nbf.tgz', ...
        'parameters', '', 'location_type', 'file', 'ingest', 1)));
end

function testAMetadataArchiveBecomesTheStimulatorManipulationsBody(testCase)
[out, rep] = metadataDecompose('t0m');
verifyEqual(testCase, rep.metadata_archives_inspected, 1);
verifyEqual(testCase, rep.metadata_archives_to_body, 1);
verifyEqual(testCase, rep.metadata_archives_kept_no_owner, 0);
verifyEqual(testCase, rep.metadata_archives_quarantined, 0);
manips = bodiesNamed(out, 'migrated_probemap_manipulation');
assertEqual(testCase, numel(manips), 1);
d = docById(out, 'mda_m');
assertNotEmpty(testCase, d, 'the body keeps the archive''s id');
verifyEqual(testCase, char(did2.unittest.helpers.classKey(d)), 'opaque_body');
verifyEqual(testCase, depVals(d, 'owner_id'), {char(manips{1}.base.id)});
% UPDATED 2026-10-22, Decided by Jess Haley [NDI binary format]:
% EMPTY:0000367 "NDI binary format" (was EDAM:format_2333 "Binary format").
verifyEqual(testCase, char(d.data_body.format.node), 'EMPTY:0000367');
verifyEqual(testCase, char(d.data_body.format.name), 'NDI binary format');
verifyEqual(testCase, char(d.data_body.filename), 'data.bin');
verifyEqual(testCase, char(d.data_body.compression), 'gzip');
verifyFalse(testCase, isfield(d, 'value'), 'an opaque body carries no data_type');
fi = d.files.file_info;
verifyEqual(testCase, char(fi(1).name), 'body_data_0');
verifyEqual(testCase, char(fi(1).locations.location), '/tmp/abc123.nbf.tgz');
verifyEmpty(testCase, bodiesOfClass(out, 'daqmetadatareader_epochdata_ingested'), ...
    'the v1 document is replaced: its one file has a new owner');
end

function testAMetadataArchiveWithNoStimulatorManipulationIsKept(testCase)
% another epoch's archive: no stimulator manipulation of ITS epoch -> kept, counted
[out, rep] = metadataDecompose('t9z');
verifyEqual(testCase, rep.metadata_archives_inspected, 1);
verifyEqual(testCase, rep.metadata_archives_to_body, 0);
verifyEqual(testCase, rep.metadata_archives_kept_no_owner, 1);
d = docById(out, 'mda_m');
assertNotEmpty(testCase, d);
verifyEqual(testCase, char(did2.unittest.helpers.classKey(d)), ...
    'daqmetadatareader_epochdata_ingested');
end

function testDeviceStringResolvesAcqSystemAndParsesGroupedChannels(testCase)
% UPDATED for #88: the system is named on the acquisition_channels document the
% observation names (acquisition_system_id), and the grouped channels live there.
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
chDoc = docById(out, depVal(obs{1}, 'acquisition_channels_id'));
verifyEqual(testCase, depVal(chDoc, 'acquisition_system_id'), 'acqsys_d');
ch = chDoc.acquisition_channels.channels;
verifyEqual(testCase, numel(ch), 2);
verifyEqual(testCase, char(ch(1).type.name), 'ai');
verifyEqual(testCase, double(ch(1).numbers(:))', [27 28 45]);
verifyEqual(testCase, char(ch(2).type.name), 'di');
verifyEqual(testCase, double(ch(2).numbers(:))', [0 1 2]);
% every row decomposed, so the source is renamed to the manifest
verifyEqual(testCase, numel(bodiesOfClass(out, 'ingestion_manifest')), 1);
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

function v1 = ingestedWithRows(docId, sessionId, epochId, rows, files)
if nargin < 5; files = {}; end
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
v1 = ingestedRaw(docId, sessionId, epochId, pm, files);
end

function v1 = ingestedRaw(docId, sessionId, epochId, probemapValue, files)
if nargin < 5; files = {}; end
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
blk.files = [{['epochid://' epochId]}, files];
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

function v1 = ingestedWithDeviceRows(docId, sessionId, epochId, rows, files)
if nargin < 5; files = {}; end
%INGESTEDWITHDEVICEROWS Like ingestedWithRows, but each row is the FULL 5-tuple
%   {name, reference, type, devicestring, subjectstring} so a test can drive the
%   device half. Exact serialize() shape.
pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n');
for i = 1:numel(rows)
    r = rows{i};
    pm = [pm, sprintf('%s\t%s\t%s\t%s\t%s\n', ...
        r{1}, r{2}, r{3}, r{4}, r{5})]; %#ok<AGROW>
end
v1 = ingestedRaw(docId, sessionId, epochId, pm, files);
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

function tf = isDirection(key, direction)
% KEY (did2.unittest.helpers.classKey) is a statement of DIRECTION: the #88
% '<direction>+<kind>'. A joined old name does NOT count, so an emitter that
% regressed to one fails here.
tf = strcmp(key, direction) || strncmp(key, [direction '+'], numel(direction) + 1);
end

function out = bodiesNamed(result, baseName)
%BODIESNAMED The bodies a role marker used to tag on base.name.
%   UPDATED for did-schema #88: V_eta documents write no base.name (#73 item 54),
%   so the role is read off the structure instead:
%     migrated_probemap_observation / _manipulation
%         an observation / manipulation whose time reference anchors at an EPOCH
%         (the probemap pass anchors every row at its epoch);
%     migrated_probemap_epoch_anchor
%         a relative_time_reference whose referent is an epoch;
%     migrated_recording_observation
%         an observation with an instrument whose time reference anchors at the
%         SESSION (the element migrator's whole-session recording observation).
docs = cell(1, numel(result.migrated));
byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(result.migrated)
    docs{k} = result.migrated{k}.toStruct();
    byId(char(docs{k}.base.id)) = docs{k};
end
out = {};
for k = 1:numel(docs)
    b = docs{k};
    leaf = char(did2.unittest.helpers.classKey(b));
    switch baseName
        case 'migrated_probemap_epoch_anchor'
            hit = strcmp(leaf, 'relative_time_reference') ...
                && strcmp(entityTypeOf(byId, depVal(b, 'referent_id')), 'epoch');
        case 'migrated_probemap_observation'
            hit = isDirection(leaf, 'observation') ...
                && strcmp(anchorKind(byId, b), 'epoch');
        case 'migrated_probemap_manipulation'
            hit = isDirection(leaf, 'manipulation') ...
                && strcmp(anchorKind(byId, b), 'epoch');
        case 'migrated_recording_observation'
            hit = isDirection(leaf, 'observation') && ~isempty(depVal(b, 'instrument_id')) ...
                && strcmp(anchorKind(byId, b), 'session');
        otherwise
            error('bodiesNamed: unknown role %s', baseName);
    end
    if hit; out{end+1} = b; end %#ok<AGROW>
end
end


function out = bodiesOfClass(result, className)
%BODIESOFCLASS Migrated bodies (as structs) of document_class className.
out = {};
for k = 1:numel(result.migrated)
    b = result.migrated{k}.toStruct();
    if isfield(b, 'document_class') && isfield(b.document_class, 'class_name') ...
            && strcmp(char(did2.unittest.helpers.classKey(b)), className)
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

function t = anchorKind(byId, b)
% the entity type of the referent of B's (first) time reference
t = '';
tr = depVal(b, 'time_reference_id');
if isempty(tr) || ~isKey(byId, tr); return; end
t = entityTypeOf(byId, depVal(byId(tr), 'referent_id'));
end


function t = entityTypeOf(byId, id)
t = '';
if isempty(id) || ~isKey(byId, id); return; end
d = byId(id);
if isfield(d, 'entity') && isfield(d.entity, 'type') && isfield(d.entity.type, 'name')
    t = char(d.entity.type.name);
end
end


function ch = channelsOf(result, b)
% #88: an observation's channels live on the acquisition_channels document it
% names by acquisition_channels_id
ch = [];
id = depVal(b, 'acquisition_channels_id');
for k = 1:numel(result.migrated)
    d = result.migrated{k}.toStruct();
    if strcmp(char(d.base.id), id)
        ch = d.acquisition_channels.channels;
        return;
    end
end
end


function d = docById(result, id)
d = [];
for k = 1:numel(result.migrated)
    s = result.migrated{k}.toStruct();
    if strcmp(char(s.base.id), id); d = s; return; end
end
end

function v = depVals(b, name)
%DEPVALS Every value of a REPEATED edge (owner_id, T15), in order.
v = {};
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps); items = deps(:)';
else; items = num2cell(deps(:)'); end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~strcmp(char(d.name), name); continue; end
    if isfield(d, 'value') && ~isempty(d.value); v{end+1} = char(d.value); %#ok<AGROW>
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); v{end+1} = char(d.document_id); end %#ok<AGROW>
end
end
