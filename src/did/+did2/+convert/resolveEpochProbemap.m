function [result, report] = resolveEpochProbemap(result, options)
%RESOLVEEPOCHPROBEMAP Decompose an ingested epoch's serialized `epochprobemap`
%   into one epoch-scoped `<modality>_observation` per probe row, retiring #30's
%   coarse session-scoped observation for that same probe.
%
%   The epochprobemap decomposition (DID-schema V_eta_OPEN_WORK.md row #66),
%   ALL THREE INCREMENTS:
%     1  OBSERVATION half: one epoch-scoped `<modality>_observation` per probe
%        row (subject_id, instrument_id, per-epoch 'during' anchor).
%     2  DEVICE half: the row's `devicestring` (`intan1:ai27-28,45;di1-4`)
%        splits into an `acquisition_system_id` edge (device name resolved
%        against `acquisition_system.base.name`) and a structured `channels`
%        field ({type, numbers} per group) on the observation.
%     3  RENAME-THIN: the source `epochfiles_ingested` becomes `ingestion_manifest`
%        (filenavigator_id RESTORED, epoch_id an EDGE, the char `epoch_id` dropped;
%        the serialized `epochprobemap` KEPT VERBATIM for lossless read-back)
%        once the probemap has been decomposed off it. STIMULATOR rows ALSO
%        decompose as of the 2026-08-21 increment -- one `term_manipulation` each
%        (T3, mkManipulation) -- so only IMAGING rows still ride the string alone.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: epochfiles_ingested, acquisition_epoch, pyraview
%   BATCH-PASS-EMITS: epochfiles_ingested -> document: voltage_observation, current_observation, time_observation, acceleration_observation, temperature_observation, term_manipulation, ingestion_manifest, relative_reference, opaque_body, intensity_observation
%   BATCH-PASS-EMITS: acquisition_epoch -> document: time_observation, opaque_body, relative_reference
%   BATCH-PASS-EMITS: pyraview -> nothing: its level bodies (minted by
%       +migrators_j/pyraview through epochMint) are RE-POINTED to the epoch's
%       recording observation and its separate observation retired; nothing
%       new is minted for it here, so crediting it would count epochMint's
%       emission twice.
%
%   ---------------------------------------------------------------------
%   THE EPOCH'S FILES ARE THE OBSERVATIONS' DATA BODIES (2026-10-21)
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-21 (did-schema
%   V_eta_recording_observation_plan.md): migrated recordings link their epoch
%   files as data bodies, matching native V2 (NDI
%   ndi.setup.V2.recordingDocuments): one observation per element per epoch,
%   `data_body` true, an `opaque_body` per epoch file by location (ingested
%   archives as attached), SHARED by the electrodes recorded in it, with the
%   channel map; a file named but absent is still recorded by location.
%
%   This pass is where that is buildable from the document batch, because the
%   epochfiles_ingested document names the epoch, its probe-map rows (which
%   electrode, which channels) AND its files. So every recording observation
%   minted here says `data_body: true`, and, per epoch:
%
%     INGESTED   the epoch's `daqreader_*_epochdata_ingested` document carries
%                the recording as attached file series (`ai_group1_seg.nbf_#`,
%                `channel_list.bin`, ...). Joined through the acquisition
%                system: epochfiles_ingested.filenavigator_id =
%                acquisition_system.epoch_file_pattern_id, whose reader_id =
%                the archive's daqreader_id, at the same epoch string. One
%                opaque_body per attached series, its members carried AS
%                ATTACHED (locations verbatim) as body_data_0..N-1.
%     OTHERWISE  one opaque_body per file the cache names (`epochid://` entries
%                excluded), recorded BY LOCATION: location = the path v1
%                recorded, location_type 'file', ingest 0, never copied. Size
%                and checksum are OMITTED: this pass reads documents, never a
%                disk, so it cannot know whether the file is present (the test
%                corpora ship document JSON only -- "files named but absent"
%                is a property of that test data, counted, not a failure).
%
%   Every body names, through a REPEATED `owner_id` (did-schema data_body,
%   T15), every recording observation of that epoch that survived validation;
%   each observation's own channels are its `acquisition_channels_id`. And the
%   loose `probe observes specimen` relation that +migrators_j/element.m keeps
%   is RETIRED here for every (probe, specimen) pair that now has a surviving
%   observation carrying the `instrument_id` edge (`observes_retired`).
%
%   NOT HERE: epochs with no epochfiles_ingested cache (PRED, 20211116: their
%   files are found by the file navigator, so the NDI second pass mints them).
%
%   THREE MORE JOBS, all decided by Jess Haley, 2026-10-21 ("a"):
%     SPIKE TRAINS   a derived `spikes` element (a sorted neuron) gets one
%                    time_observation per epoch -- entity the neuron, instrument
%                    the element it was sorted from (`derived_from`), variable
%                    GO:0001508 "action potential", `data_body` true -- and its
%                    element_epoch's epoch_binary_data.vhsb is the opaque_body
%                    owned by it (spike_* counters).
%     V1 ARCHIVES    a daqreader_*_epochdata_ingested is RETIRED once every file
%                    it holds is carried by a surviving per-epoch body, verified
%                    per document, and only if nothing that survives names it;
%                    otherwise kept and counted (archive_* counters).
%     PYRAVIEW       each pyraview level body (epochMint's fold) is re-pointed
%                    to the recording observation emitted here for the same
%                    element (instrument) and epoch, and the separate pyraview
%                    observation is retired; with no such observation it is
%                    kept as it was, and counted (pyraview_* counters). The
%                    pyraview observation's datum_type and its clocked anchor do
%                    not move with the levels.
%
%   IMAGING ROWS ARE NO LONGER DEFERRED (2026-10-21). They were left to the
%   second pass because the old `image` value cell was required and a probemap
%   row carries no raster metadata. did-schema #88 retired `image` (a camera
%   frame is an `intensity_observation`, as jRecordingModality maps it), and with
%   the frames in the epoch's file bodies (`data_body` true) nothing inline is
%   needed, so an imaging row is an ordinary recording row. `rows_image_deferred`
%   is kept as a counter and now reads 0.
%
%   `epochfiles_ingested` IS now consumed: after its probemap is decomposed into
%   observations, the document itself is rewritten to `ingestion_manifest`
%   (increment 3), GUARDED -- a document that cannot supply the manifest's two
%   required edges (filenavigator_id, a resolvable epoch) is left as the
%   `epochfiles_ingested` tombstone rather than quarantined. The other emissions
%   are the per-probe observations and, one per epoch, the shared 'during' anchor
%   they point at.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A BATCH PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   Each probe row must be attributed to a SUBJECT (the specimen it records) and
%   an INSTRUMENT (its own element-subject, T7), and both are OTHER documents:
%   the subjectstring column names a `subject.local_identifier` and the
%   (name, reference) columns name an element-subject minted by
%   +migrators_j/element.m. It must also anchor to the `epoch` DOCUMENT that
%   epochMint minted for this ingested epoch -- a find over the whole batch.
%   A single-document migrator sees one document; this is a corpus-wide join,
%   the same wall as epochMint, resolveSessionAnchors and jEpochDocId.
%
%   ---------------------------------------------------------------------
%   ORDER: AFTER epochMint (it needs the `epoch` documents to anchor to) AND
%   AFTER resolveSessionAnchors (so the #30 observations it retires have already
%   had their session anchors folded to `relative_reference`, and so this pass
%   mints its OWN 'during' anchor as a final `relative_reference` directly rather
%   than a pass-1 handle needing a later fold).
%   ---------------------------------------------------------------------
%
%   ---------------------------------------------------------------------
%   THE PRIVATE HELPERS ARE RECONSTRUCTED LOCALLY, ON PURPOSE
%   ---------------------------------------------------------------------
%   The observation shape (jRecordingObservation), the type->modality map
%   (jRecordingModality) and the ontology-term / class-block / quantity-block
%   builders all live in +did2/+convert/+migrators_j/private, which is
%   UNREACHABLE from this package (+convert) -- MATLAB `private` folders are
%   visible only to functions in the parent folder. So they are rebuilt here,
%   the same reason did2.convert.epochMint reconstructs its own readers. The
%   ROWS of `localModality` are pinned against jRecordingModality by
%   tests/+did2/+unittest/testResolveEpochProbemap.m so the two cannot drift in
%   silence. If jRecordingModality gains a row, add it here and to that test.
%
%   ---------------------------------------------------------------------
%   WHAT IT REFUSES TO DO, AND COUNTS INSTEAD
%   ---------------------------------------------------------------------
%   A probe row it cannot attribute honestly emits NOTHING and is counted:
%
%     no epoch document for this ingested epoch  -> refused_no_epoch (whole doc)
%     empty subjectstring column                 -> rows_no_subjectstring
%     subjectstring resolves to no `subject`     -> refused_no_subject
%     modality is 'stimulator'                   -> rows_stimulator
%     modality is imaging (image, not emittable)  -> rows_image_deferred
%     modality is 'unresolved'                   -> rows_unresolved_modality
%
%   `subject_id` is the ONE required edge on the observation chain, and an empty
%   required edge validates clean because +did2/+validate/references.m:90 skips
%   empty edges -- the invented-empty-edge pattern, 7,233 documents and counting.
%   So a row with no resolvable subject emits NO observation, never an empty one.
%   `instrument_id` is OPTIONAL, so an unresolved instrument OMITS the edge
%   (`instrument_omitted`) rather than emitting it empty or dropping the row.
%
%   Options mirror the sibling passes (Validate / SchemaCache / TargetVersion).
%
%   See also: did2.convert.v1_to_v2, did2.convert.epochMint,
%   did2.convert.resolveSessionAnchors,
%   did2.convert.migrators_j (element, epochfiles_ingested).

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% A batch pass builds documents from the v1 source's own terms, exactly as a
% migrator does inside v1_to_v2, so the T19 TermRegistry check is off while it
% runs, as it is there, and restored after (unregistered terms are still
% collected when did2.build.unregisteredTerms('-collect') is on).
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>

% DENOMINATOR FIRST, and unconditionally (Operating Rule 5). Every field is
% defined before a single document is read, so "did not run" and "ran and found
% nothing" are different readings of the same struct.
report = struct( ...
    'documents_inspected',            0, ...
    'documents_unreadable',           0, ...
    'epochfiles_ingested_seen',       0, ...
    'refused_no_epoch',               0, ...
    'probe_rows_total',               0, ...
    'rows_no_subjectstring',          0, ...
    'refused_no_subject',             0, ...
    'rows_unresolved_modality',       0, ...
    'rows_image_deferred',            0, ...
    'rows_stimulator',                0, ...
    'observations_emitted',           0, ...
    'manipulations_emitted',          0, ...
    'instrument_resolved',            0, ...
    'instrument_omitted',             0, ...
    'device_strings_seen',            0, ...
    'device_acqsystem_resolved',      0, ...
    'device_acqsystem_unresolved',    0, ...
    'device_channels_parsed',         0, ...
    'device_channels_unparsable',     0, ...
    'epoch_anchors_minted',           0, ...
    'session30_observations_retired', 0, ...
    'session30_anchors_removed',      0, ...
    'retire_skipped_ambiguous',       0, ...
    'retire_no_match',                0, ...
    'manifests_renamed',              0, ...
    'rename_skipped_no_filenavigator',0, ...
    'rename_skipped_no_epoch',        0, ...
    'rename_quarantined',             0, ...
    'rename_skipped_rows_without_home',0, ...
    'acquisition_channels_minted',    0, ...
    'channels_unbindable_type',       0, ...
    'fold_quarantined',               0, ...
    'epochs_with_observations',       0, ...
    'epochs_from_archive',            0, ...
    'epochs_by_location',             0, ...
    'epochs_no_file_named',           0, ...
    'bodies_from_archive',            0, ...
    'archive_members_carried',        0, ...
    'bodies_by_location',             0, ...
    'bodies_size_and_checksum_omitted',0, ...
    'body_owner_links',               0, ...
    'bodies_quarantined',             0, ...
    'body_build_refused',             0, ...
    'body_build_first_error',         '', ...
    'observes_retired',               0, ...
    'spike_epochs_seen',              0, ...
    'spike_trains_emitted',           0, ...
    'spike_refused_no_epoch',         0, ...
    'spike_epochs_no_file',           0, ...
    'spike_instrument_resolved',      0, ...
    'spike_bodies',                   0, ...
    'spike_bodies_quarantined',       0, ...
    'archive_docs_inspected',         0, ...
    'archive_docs_retired',           0, ...
    'archive_docs_kept_unowned_files',0, ...
    'archive_files_unowned',          0, ...
    'archive_kept_referenced',        0, ...
    'archive_dangling_references',    0, ...
    'pyraview_observations_seen',     0, ...
    'pyraview_levels_repointed',      0, ...
    'pyraview_observations_retired',  0, ...
    'pyraview_kept_no_recording_observation', 0, ...
    'pyraview_kept_referenced',       0, ...
    'pyraview_repoint_quarantined',   0, ...
    'ran',                            false);
result.epoch_probemap_fold = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % the observation leaves + relative_reference exist only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.epoch_probemap_fold = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ---------------------------------------------
% A document this cannot read is COUNTED, never dropped.
bodies = cell(1, n);
classOf = repmat({''}, 1, n);
sessionIds = repmat({''}, 1, n);
docIds = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k} = b;
        classOf{k} = classNameOf(b);
        sessionIds{k} = did2.schema.cache.sessionIdOf(b);
        docIds{k} = baseField(b, 'id');
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- index epochs, subjects and #30 observations --------------------------
% (a) minted/found `epoch` documents by (session_id, local_identifier) -> id.
epochIdByKey = containers.Map('KeyType', 'char', 'ValueType', 'char');
% (b) `subject` documents by (session_id, local_identifier) -> id. This one map
%     resolves BOTH joins: the subjectstring column (a bare local identifier)
%     and the probe (name, reference) columns (encoded 'name (ref X)' the way
%     +migrators_j/element.m mints a probe-subject's local_identifier).
subjectIdByKey = containers.Map('KeyType', 'char', 'ValueType', 'char');
% (c) `acquisition_system` documents by (session_id, base.name) -> id. The device
%     half: a probemap devicestring names a rig by NAME (daqsystem.base.name,
%     PRESERVED onto the acquisition_system by +migrators_j/daqsystem.m), so this
%     resolves that name to the migrated document id. base.name is the join key
%     the live NDI query uses too (system.m:229 / syncgraph.m:404-408).
acqSystemIdByName = containers.Map('KeyType', 'char', 'ValueType', 'char');
% (d) #30 observations keyed by the (subject_id, instrument_id, class_name)
%     TRIPLE -- NOT instrument_id alone. jRecordingObservation stamps
%     base.name = 'migrated_recording_observation'; but a single probe (instrument)
%     carries MORE THAN ONE #30 observation whenever it is spike-sorted: its own
%     direct recording (subject = the specimen) AND one per derived neuron
%     (subject = the neuron, instrument = this probe, per the spike-train leaf).
%     Keying on instrument alone made every such probe `retire_skipped_ambiguous`
%     (174 of 174 on Soph, 0 retired). The probemap observation supersedes ONLY
%     the probe's own direct recording of the SAME specimen and modality, so the
%     subject and the class must be in the key. A cell of {index} per triple.
obs30ByTriple = containers.Map('KeyType', 'char', 'ValueType', 'any');
% (e) 2026-10-21, the file bodies: acquisition_system.epoch_file_pattern_id (the
%     v1 filenavigator id, preserved) -> its reader_id (the v1 daqreader id),
%     and each `daqreader_*_epochdata_ingested` archive by (session, reader,
%     epoch string). (f) the loose `observes` relations, by (child, parent).
readerIdByNavId = containers.Map('KeyType', 'char', 'ValueType', 'char');
archiveIdxByKey = containers.Map('KeyType', 'char', 'ValueType', 'double');
observesIdxByPair = containers.Map('KeyType', 'char', 'ValueType', 'any');
spikeElements = containers.Map('KeyType', 'char', 'ValueType', 'logical');
derivedParent = containers.Map('KeyType', 'char', 'ValueType', 'char');
acqEpochIdx = [];
sampledIdx = [];
archiveIdxAll = [];
for k = 1:n
    if isempty(bodies{k}); continue; end
    b = bodies{k};
    if strcmp(classOf{k}, 'acquisition_epoch'); acqEpochIdx(end+1) = k; end %#ok<AGROW>
    if strcmp(classOf{k}, 'sampled_body'); sampledIdx(end+1) = k; end %#ok<AGROW>
    if isArchiveClass(classOf{k}); archiveIdxAll(end+1) = k; end %#ok<AGROW>
    if isElementTypeAssertion(b, 'spikes')
        eid = depValueOf(b, 'entity_id');
        if ~isempty(eid); spikeElements(eid) = true; end
    end
    switch classOf{k}
        case 'epoch'
            lid = '';
            if isfield(b, 'entity') && isstruct(b.entity)
                lid = charField(b.entity, {'local_identifier'});
            end
            if ~isempty(lid) && ~isempty(docIds{k})
                key = epochKey(sessionIds{k}, lid);
                if ~isKey(epochIdByKey, key); epochIdByKey(key) = docIds{k}; end
            end
        case 'acquisition_system'
            nm = '';
            if isfield(b, 'acquisition_system') && isstruct(b.acquisition_system)
                nm = charField(b.acquisition_system, {'name'});
            end
            if isempty(nm); nm = baseField(b, 'name'); end
            if ~isempty(nm) && ~isempty(docIds{k})
                key = epochKey(sessionIds{k}, nm);
                if ~isKey(acqSystemIdByName, key)
                    acqSystemIdByName(key) = docIds{k};
                end
            end
            navId = depValueOf(b, 'epoch_file_pattern_id');
            rdrId = depValueOf(b, 'reader_id');
            if ~isempty(navId) && ~isempty(rdrId) && ~isKey(readerIdByNavId, navId)
                readerIdByNavId(navId) = rdrId;
            end
        case 'directed_relation'
            if strcmp(relationNameOf(b), 'derived_from')
                ch = depValueOf(b, 'child_id');
                if ~isempty(ch) && ~isKey(derivedParent, ch)
                    derivedParent(ch) = depValueOf(b, 'parent_id');
                end
            end
            if strcmp(relationNameOf(b), 'observes')
                pk = [depValueOf(b, 'child_id') '|' depValueOf(b, 'parent_id')];
                if isKey(observesIdxByPair, pk)
                    observesIdxByPair(pk) = [observesIdxByPair(pk), k];
                else
                    observesIdxByPair(pk) = k;
                end
            end
        otherwise
            if isArchiveClass(classOf{k})
                rdr = depValueOf(b, 'daqreader_id');
                ep = archiveEpochOf(b);
                if ~isempty(rdr) && ~isempty(ep)
                    ak = archiveKey(sessionIds{k}, rdr, ep);
                    if ~isKey(archiveIdxByKey, ak); archiveIdxByKey(ak) = k; end
                end
            end
            % did-schema #88: an animal, a probe, a cell are all one `entity`
            % class told apart by `type`; any entity that is not a record
            % (session, dataset, software, ...) can be a probemap subject or
            % the probe itself, found by its local_identifier.
            if isfield(b, 'entity') && isstruct(b.entity) ...
                    && ~any(strcmp(classOf{k}, {'session', 'dataset', 'software', ...
                    'operating_system', 'organization', 'person', 'protocol'}))
                lid = charField(b.entity, {'local_identifier'});
                if ~isempty(lid) && ~isempty(docIds{k})
                    key = epochKey(sessionIds{k}, lid);
                    if ~isKey(subjectIdByKey, key); subjectIdByKey(key) = docIds{k}; end
                end
            end
    end
    if isRecording30Observation(b)
        subj  = depValueOf(b, 'entity_id');
        instr = depValueOf(b, 'instrument_id');
        if ~isempty(subj) && ~isempty(instr)
            tk = obs30TripleKey(subj, instr, classOf{k});
            if isKey(obs30ByTriple, tk)
                obs30ByTriple(tk) = [obs30ByTriple(tk), {k}];
            else
                obs30ByTriple(tk) = {k};
            end
        end
    end
end

% --- the probemap loop ----------------------------------------------------
newBodies = {};       % structs to validate + append
newGroupAnchor = {};  % base.id of the epoch anchor each new observation points at
anchorByEpochId = containers.Map('KeyType', 'char', 'ValueType', 'char');
anchorBodyById  = containers.Map('KeyType', 'char', 'ValueType', 'any');
retire30Ids = {};     % #30 observation base.ids to remove, once replacements land
% For each retired #30 obs, remember which new-body ids replace it, so the
% removal is gated on a replacement actually surviving validation.
retireReplacementIds = containers.Map('KeyType', 'char', 'ValueType', 'any');
% #30 anchor id -> {retired-obs-id, ...}: candidate for removal once its obs go.
retire30AnchorCand = containers.Map('KeyType', 'char', 'ValueType', 'any');
% INCREMENT 3: source epochfiles_ingested docId -> its ingestion_manifest body.
% Applied in the rebuild, GUARDED on the manifest surviving validation.
renameBodyBySrcId = containers.Map('KeyType', 'char', 'ValueType', 'any');
acIdByKey   = containers.Map('KeyType', 'char', 'ValueType', 'char');
acBodyById  = containers.Map('KeyType', 'char', 'ValueType', 'any');
newGroupAc = {};     % acquisition_channels base.id each new body points at ('' = none)
% 2026-10-21: per epochfiles_ingested document, the observations it minted and
% where their files are -- the bodies are built after validation, owned by the
% observations that survived.
epochSpecs = struct('src', {}, 'obsIds', {}, 'sid', {}, 'datestamp', {}, ...
    'epochString', {}, 'navId', {});
obsPairById = containers.Map('KeyType', 'char', 'ValueType', 'char');
recByInstrEpoch = containers.Map('KeyType', 'char', 'ValueType', 'char');
spikeObsIds = containers.Map('KeyType', 'char', 'ValueType', 'double');  % obs id -> acquisition_epoch idx

for k = 1:n
    if ~strcmp(classOf{k}, 'epochfiles_ingested'); continue; end
    report.epochfiles_ingested_seen = report.epochfiles_ingested_seen + 1;
    b = bodies{k};
    sid = sessionIds{k};
    es = epochStringOf(b);
    if isempty(es) || ~isKey(epochIdByKey, epochKey(sid, es))
        report.refused_no_epoch = report.refused_no_epoch + 1;
        report.rename_skipped_no_epoch = report.rename_skipped_no_epoch + 1;
        continue;     % no epoch -> cannot fill ingestion_manifest.epoch_id; stays
    end
    epochDocId = epochIdByKey(epochKey(sid, es));
    datestamp = baseField(b, 'creation_timestamp');
    if isempty(datestamp); datestamp = baseField(b, 'datestamp'); end
    if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
    fnId = depValueOf(b, 'filenavigator_id');

    % did-schema #88 (#73 review item 39): ingestion_manifest carries NO
    % serialized epochprobemap. Every row must have a home before the v1
    % document may be renamed; a row that does not decompose (an imaging row,
    % an unresolved type, a row naming no resolvable subject) keeps the WHOLE
    % v1 document as a passthrough, so the row is never silently dropped.
    rowsWithoutHome = 0;
    specObsIds = {};
    pm = probemapCharOf(b);
    rowsPM = [];
    if ~isempty(pm); rowsPM = parseProbemapRows(pm); end
    for r = 1:numel(rowsPM)
        report.probe_rows_total = report.probe_rows_total + 1;
        row = rowsPM(r);
        if isempty(row.subjectstring)
            report.rows_no_subjectstring = report.rows_no_subjectstring + 1;
            rowsWithoutHome = rowsWithoutHome + 1;
            continue;
        end
        subjKey = epochKey(sid, row.subjectstring);
        if ~isKey(subjectIdByKey, subjKey)
            report.refused_no_subject = report.refused_no_subject + 1;
            rowsWithoutHome = rowsWithoutHome + 1;
            continue;
        end
        subjectId = subjectIdByKey(subjKey);

        [entries, disposition] = localModality(row.type);
        switch disposition
            case 'stimulator'
                report.rows_stimulator = report.rows_stimulator + 1;
            case 'recording'
            case 'image_deferred'
                report.rows_image_deferred = report.rows_image_deferred + 1;
                rowsWithoutHome = rowsWithoutHome + 1;
                continue;
            otherwise    % 'unresolved' or anything unexpected
                report.rows_unresolved_modality = ...
                    report.rows_unresolved_modality + 1;
                rowsWithoutHome = rowsWithoutHome + 1;
                continue;
        end

        instrumentId = '';
        probeLocalId = probeLocalIdentifier(row.name, row.reference);
        probeKey = epochKey(sid, probeLocalId);
        if ~isempty(probeLocalId) && isKey(subjectIdByKey, probeKey)
            instrumentId = subjectIdByKey(probeKey);
        end

        acqSystemId = '';
        channels = emptyChannels();
        if ~isempty(row.devicestring)
            report.device_strings_seen = report.device_strings_seen + 1;
            [deviceName, channels, chanOk] = parseDeviceString(row.devicestring);
            if chanOk
                report.device_channels_parsed = report.device_channels_parsed + 1;
            else
                report.device_channels_unparsable = ...
                    report.device_channels_unparsable + 1;
            end
            if ~isempty(deviceName)
                dk = epochKey(sid, deviceName);
                if isKey(acqSystemIdByName, dk)
                    acqSystemId = acqSystemIdByName(dk);
                    report.device_acqsystem_resolved = ...
                        report.device_acqsystem_resolved + 1;
                else
                    report.device_acqsystem_unresolved = ...
                        report.device_acqsystem_unresolved + 1;
                end
            end
        end

        % #73 item 56: the rig + channels are ONE shared acquisition_channels
        % document per distinct (session, rig, channels), named by the
        % statement's acquisition_channels_id edge. A channel type outside
        % the bound set (ai/ao/di/do) is not invented into it: the document is
        % not minted and the row is counted.
        acId = '';
        if ~isempty(acqSystemId) || ~isempty(channels)
            if channelsBindable(channels)
                ak = channelsKey(sid, acqSystemId, channels);
                if isKey(acIdByKey, ak)
                    acId = acIdByKey(ak);
                else
                    acBody = mkAcquisitionChannels(acqSystemId, channels, sid, datestamp);
                    acId = acBody.base.id;
                    acIdByKey(ak) = acId;
                    acBodyById(acId) = acBody;
                    report.acquisition_channels_minted = ...
                        report.acquisition_channels_minted + 1;
                end
            else
                report.channels_unbindable_type = report.channels_unbindable_type + 1;
            end
        end

        if isKey(anchorByEpochId, epochDocId)
            anchorId = anchorByEpochId(epochDocId);
        else
            anchor = mkEpochAnchor(epochDocId, sid, datestamp);
            anchorId = anchor.base.id;
            anchorByEpochId(epochDocId) = anchorId;
            anchorBodyById(anchorId) = anchor;
            report.epoch_anchors_minted = report.epoch_anchors_minted + 1;
        end

        if strcmp(disposition, 'stimulator')
            manip = mkManipulation(row.type, subjectId, instrumentId, ...
                anchorId, sid, datestamp, acId);
            newBodies{end+1} = manip;              %#ok<AGROW>
            newGroupAnchor{end+1} = anchorId;      %#ok<AGROW>
            newGroupAc{end+1} = acId;              %#ok<AGROW>
            if isempty(instrumentId)
                report.instrument_omitted = report.instrument_omitted + 1;
            else
                report.instrument_resolved = report.instrument_resolved + 1;
            end
            continue;
        end

        for e = 1:numel(entries)
            obs = mkObservation(entries(e), subjectId, instrumentId, anchorId, ...
                sid, datestamp, acId);
            newBodies{end+1} = obs;                 %#ok<AGROW>
            specObsIds{end+1} = obs.base.id;        %#ok<AGROW>
            if ~isempty(instrumentId)
                obsPairById(obs.base.id) = [char(instrumentId) '|' char(subjectId)];
                rk = recKey(instrumentId, epochDocId, entries(e).class);
                if ~isKey(recByInstrEpoch, rk); recByInstrEpoch(rk) = obs.base.id; end
            end
            newGroupAnchor{end+1} = anchorId;       %#ok<AGROW>
            newGroupAc{end+1} = acId;               %#ok<AGROW>

            if ~isempty(instrumentId)
                tk = obs30TripleKey(subjectId, instrumentId, entries(e).class);
                if isKey(obs30ByTriple, tk)
                    hits = obs30ByTriple(tk);
                    if isscalar(hits)
                        obs30Id = docIds{hits{1}};
                        if ~isempty(obs30Id) && ~any(strcmp(obs30Id, retire30Ids))
                            retire30Ids{end+1} = obs30Id;         %#ok<AGROW>
                            retireReplacementIds(obs30Id) = {obs.base.id};
                            anchorId30 = depValueOf(bodies{hits{1}}, 'time_reference_id');
                            if ~isempty(anchorId30)
                                retire30AnchorCand(anchorId30) = {obs30Id};
                            end
                        elseif ~isempty(obs30Id) && isKey(retireReplacementIds, obs30Id)
                            retireReplacementIds(obs30Id) = ...
                                [retireReplacementIds(obs30Id), {obs.base.id}];
                        end
                    elseif numel(hits) > 1
                        report.retire_skipped_ambiguous = ...
                            report.retire_skipped_ambiguous + 1;
                    end
                else
                    report.retire_no_match = report.retire_no_match + 1;
                end
            end
        end
        if isempty(instrumentId)
            report.instrument_omitted = report.instrument_omitted + numel(entries);
        else
            report.instrument_resolved = report.instrument_resolved + numel(entries);
        end
    end

    if ~isempty(specObsIds)
        epochSpecs(end+1) = struct('src', k, 'obsIds', {specObsIds}, ...
            'sid', sid, 'datestamp', datestamp, 'epochString', es, ...
            'navId', fnId); %#ok<AGROW>
    end

    if isempty(fnId)
        report.rename_skipped_no_filenavigator = ...
            report.rename_skipped_no_filenavigator + 1;
    elseif rowsWithoutHome > 0
        report.rename_skipped_rows_without_home = ...
            report.rename_skipped_rows_without_home + 1;
    else
        renameBodyBySrcId(docIds{k}) = ...
            mkIngestionManifest(b, fnId, epochDocId, sid, datestamp);
    end
end

% ---- spike trains (Jess Haley, 2026-10-21, "a") ------------------------
% A spike-sorted neuron (a `spikes` element) gets ONE observation per epoch:
% entity = the neuron subject (ids preserved by +migrators_j/element.m),
% instrument = the element it was sorted from (its `derived_from` parent),
% value kind time (spike times), `data_body` true, and the epoch's
% `epoch_binary_data.vhsb` file (on its element_epoch, now acquisition_epoch)
% as an opaque_body owned by it -- the pattern of the raw recording bodies
% above. No file named -> no observation (counted), never a bodiless one.
for i = 1:numel(acqEpochIdx)
    k = acqEpochIdx(i);
    b = bodies{k};
    elId = depValueOf(b, 'element_id');
    if isempty(elId) || ~isKey(spikeElements, elId); continue; end
    report.spike_epochs_seen = report.spike_epochs_seen + 1;
    sid = sessionIds{k};
    es = archiveEpochOf(b);
    if isempty(es) || ~isKey(epochIdByKey, epochKey(sid, es))
        report.spike_refused_no_epoch = report.spike_refused_no_epoch + 1;
        continue;
    end
    if isempty(vhsbFileInfo(b))
        report.spike_epochs_no_file = report.spike_epochs_no_file + 1;
        continue;
    end
    epochDocId = epochIdByKey(epochKey(sid, es));
    datestamp = baseField(b, 'creation_timestamp');
    if isempty(datestamp); datestamp = baseField(b, 'datestamp'); end
    if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
    if isKey(anchorByEpochId, epochDocId)
        anchorId = anchorByEpochId(epochDocId);
    else
        anchor = mkEpochAnchor(epochDocId, sid, datestamp);
        anchorId = anchor.base.id;
        anchorByEpochId(epochDocId) = anchorId;
        anchorBodyById(anchorId) = anchor;
        report.epoch_anchors_minted = report.epoch_anchors_minted + 1;
    end
    instrumentId = '';
    if isKey(derivedParent, elId); instrumentId = derivedParent(elId); end
    obs = did2.build.statement('observation', char(elId), SPIKE_TRAIN_VARIABLE(), ...
        [], 'DataBody', true, 'TimeReferenceIds', {anchorId}, ...
        'InstrumentId', char(instrumentId), ...
        'SessionId', char(sid), 'CreationTimestamp', char(datestamp), ...
        'Validate', false, 'ValueKind', 'time');
    newBodies{end+1} = obs;              %#ok<AGROW>
    newGroupAnchor{end+1} = anchorId;    %#ok<AGROW>
    newGroupAc{end+1} = '';              %#ok<AGROW>
    spikeObsIds(obs.base.id) = k;
    if ~isempty(instrumentId)
        report.spike_instrument_resolved = report.spike_instrument_resolved + 1;
    end
end

report.archive_docs_inspected = numel(archiveIdxAll);
pyraviewOwners = pyraviewOwnerIndex(bodies, classOf, docIds, sampledIdx);
report.pyraview_observations_seen = double(pyraviewOwners.Count);

renameBodies = renameBodyBySrcId.values;
if isempty(newBodies) && isempty(renameBodies)
    % nothing emitted: no archive file has a new owner, and no pyraview has a
    % recording observation to move to -- both kept, and counted as such
    report.archive_docs_kept_unowned_files = report.archive_docs_inspected;
    report.archive_files_unowned = countArchiveFiles(bodies, archiveIdxAll);
    report.pyraview_kept_no_recording_observation = report.pyraview_observations_seen;
    result.epoch_probemap_fold = report;
    return;
end

% --- validate the OBSERVATIONS + anchors: quarantines here are REAL --------
% Observations + their epoch anchors go through together, so an observation's
% `time_reference_1` names a document present in the same batch. Cross-batch
% edges (subject_id, instrument_id) point OUTSIDE this rebuild set, exactly as
% resolveSessionAnchors' relative_to does -- v1_to_v2's per-batch validate does
% not resolve references (that is the corpus orphan gate), so this is fine.
% A quarantined observation is a defect and propagates to the 0-quarantine gate.
producedById = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(newBodies)
    anchorBodies = anchorBodyById.values;
    acBodies = acBodyById.values;
    out = did2.convert.v1_to_v2([newBodies, anchorBodies(:)', acBodies(:)'], ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    report.fold_quarantined = numel(out.quarantine);
    if ~isempty(out.quarantine)
        if isfield(result, 'quarantine') && ~isempty(result.quarantine)
            result.quarantine = [result.quarantine, out.quarantine];
        else
            result.quarantine = out.quarantine;
        end
    end
    % Match on base.id, not position: a quarantined body leaves no slot.
    for k = 1:numel(out.migrated)
        try
            producedById(char(out.migrated{k}.get('base.id'))) = out.migrated{k};
        catch
        end
    end
end

% --- validate the RENAMES SEPARATELY: a manifest quarantine is NOT a gate ---
% failure. Renaming epochfiles_ingested -> ingestion_manifest is a step toward
% done (formerly "Bar-2"); the source tombstone is a valid integrity fallback
% (formerly "Bar-1"), so a manifest that cannot
% validate leaves the source unchanged (guarded) and is counted
% (rename_quarantined), never added to result.quarantine. Same idiom as every
% guarded passthrough (fitcurve, openminds_stimulus, image_stack).
manifestById = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(renameBodies)
    outRen = did2.convert.v1_to_v2(renameBodies(:)', ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    for k = 1:numel(outRen.migrated)
        try
            manifestById(char(outRen.migrated{k}.get('base.id'))) = outRen.migrated{k};
        catch
        end
    end
end

% --- carry ALL-OR-NOTHING per epoch group ---------------------------------
% An observation references its anchor; if the anchor quarantined, its whole
% group is withheld (mirror epochMint's carry). An observation that quarantined
% while its anchor survived is dropped alone. An anchor is emitted only if at
% least one observation pointing at it survived.
anchorAlive = containers.Map('KeyType', 'char', 'ValueType', 'logical');
anchorKeys = anchorByEpochId.values;
for a = 1:numel(anchorKeys)
    aid = anchorKeys{a};
    anchorAlive(aid) = isKey(producedById, aid);
end
anchorHasSurvivor = containers.Map('KeyType', 'char', 'ValueType', 'logical');
acHasSurvivor = containers.Map('KeyType', 'char', 'ValueType', 'logical');

emittedNewIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
appended = {};
for j = 1:numel(newBodies)
    id = newBodies{j}.base.id;
    aid = newGroupAnchor{j};
    if ~anchorAlive(aid); continue; end          % group withheld: anchor died
    if ~isKey(producedById, id); continue; end    % this body quarantined
    acId = newGroupAc{j};
    if ~isempty(acId) && ~isKey(producedById, acId); continue; end  % its channels died
    appended{end+1} = producedById(id); %#ok<AGROW>
    % newBodies carries BOTH the recording observations and the stimulator
    % manipulations (#66 increment 3). Count each into its own counter, by the
    % base.name the mint sites set, so a manipulation is never counted as an
    % observation. Both are survivor-counts (post-validation).
    if strcmp(newBodies{j}.document_class.class_name, 'manipulation')
        report.manipulations_emitted = report.manipulations_emitted + 1;
    elseif isKey(spikeObsIds, id)
        report.spike_trains_emitted = report.spike_trains_emitted + 1;
    else
        report.observations_emitted = report.observations_emitted + 1;
    end
    emittedNewIds(id) = true;
    anchorHasSurvivor(aid) = true;
    if ~isempty(acId); acHasSurvivor(acId) = true; end
end
acKeys = acHasSurvivor.keys;
for a = 1:numel(acKeys)
    appended{end+1} = producedById(acKeys{a}); %#ok<AGROW>
end
% Anchors: emit only where a surviving observation references them.
for a = 1:numel(anchorKeys)
    aid = anchorKeys{a};
    if isKey(anchorHasSurvivor, aid) && anchorHasSurvivor(aid) ...
            && isKey(producedById, aid)
        appended{end+1} = producedById(aid); %#ok<AGROW>
    end
end

% --- 2026-10-21: the epoch files, as data bodies of the surviving observations
[fileBodies, report, newQuarantine, archiveCarried] = mkEpochFileBodies(epochSpecs, ...
    emittedNewIds, bodies, docIds, readerIdByNavId, archiveIdxByKey, options, report);
appended = [appended, fileBodies];

% the spike-train bodies: one per surviving spike observation
[spikeBodies, spikeQ] = mkSpikeBodies(spikeObsIds, emittedNewIds, bodies, ...
    sessionIds, options);
report.spike_bodies = numel(spikeBodies);
report.spike_bodies_quarantined = numel(spikeQ);
appended = [appended, spikeBodies];
newQuarantine = [newQuarantine, spikeQ];

% ---- pyraview levels move to the recording observation -------------------
% (Jess Haley, 2026-10-21, "a"; the signed plan): each pyraview level is a
% data body owned by that epoch's recording observation -- the one emitted
% above for the same element (its instrument) and epoch -- and the separate
% pyraview observation is no longer emitted. Where no recording observation
% exists for that element and epoch, it is kept as it was, and counted.
pyraviewRetire = containers.Map('KeyType', 'char', 'ValueType', 'logical');
levelReplace = containers.Map('KeyType', 'char', 'ValueType', 'any');
levelIdsByPv = containers.Map('KeyType', 'char', 'ValueType', 'any');
pvKeys = pyraviewOwners.keys;
for i = 1:numel(pvKeys)
    pv = pyraviewOwners(pvKeys{i});
    rk = recKey(pv.entityId, pv.epochDocId, pv.className);
    if isempty(pv.epochDocId) || ~isKey(recByInstrEpoch, rk) ...
            || ~isKey(emittedNewIds, recByInstrEpoch(rk))
        report.pyraview_kept_no_recording_observation = ...
            report.pyraview_kept_no_recording_observation + 1;
        continue;
    end
    recId = recByInstrEpoch(rk);
    moved = {};
    for j = 1:numel(pv.levelIdx)
        lb = bodies{pv.levelIdx(j)};
        lb = setOwner(lb, recId);
        moved{end+1} = lb; %#ok<AGROW>
    end
    res = did2.convert.v1_to_v2(moved, ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    if ~isempty(res.quarantine) || numel(res.migrated) ~= numel(moved)
        report.pyraview_repoint_quarantined = report.pyraview_repoint_quarantined + 1;
        report.pyraview_kept_no_recording_observation = ...
            report.pyraview_kept_no_recording_observation + 1;
        continue;
    end
    lids = {};
    for j = 1:numel(res.migrated)
        lid = char(res.migrated{j}.get('base.id'));
        levelReplace(lid) = res.migrated{j};
        lids{end+1} = lid; %#ok<AGROW>
    end
    levelIdsByPv(pvKeys{i}) = lids;
    report.pyraview_levels_repointed = report.pyraview_levels_repointed + numel(moved);
    pyraviewRetire(pvKeys{i}) = true;
end

% ---- v1 ingested archives retire once every file has a new owner ---------
% (Jess Haley, 2026-10-21, "a"): a daqreader_*_epochdata_ingested document is
% retired only when EVERY file it holds is carried by a surviving per-epoch
% data body above, verified per document; one file without a new owner keeps
% the document (counted). Its id must not be referenced by anything that
% survives: a reference keeps it too, and is counted.
archiveRetire = containers.Map('KeyType', 'char', 'ValueType', 'logical');
candidates = {};
for i = 1:numel(archiveIdxAll)
    k = archiveIdxAll(i);
    held = archiveFileNames(bodies{k});
    carried = {};
    if isKey(archiveCarried, k); carried = archiveCarried(k); end
    unowned = setdiff(held, carried);
    if isempty(held) || ~isempty(unowned)
        report.archive_docs_kept_unowned_files = report.archive_docs_kept_unowned_files + 1;
        report.archive_files_unowned = report.archive_files_unowned + numel(unowned);
        continue;
    end
    candidates{end+1} = docIds{k}; %#ok<AGROW>
end

% the final set's references, with every planned removal applied
plannedGone = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for c = 1:numel(candidates); plannedGone(candidates{c}) = true; end
pvIds = pyraviewRetire.keys;
for c = 1:numel(pvIds); plannedGone(pvIds{c}) = true; end
lvKeys = levelReplace.keys;
for c = 1:numel(lvKeys); plannedGone(lvKeys{c}) = true; end   % replaced below
refs = referencedIdSet(bodies, docIds, plannedGone, [appended, levelReplace.values]);
for c = 1:numel(candidates)
    if isKey(refs, candidates{c})
        report.archive_kept_referenced = report.archive_kept_referenced + 1;
        report.archive_dangling_references = report.archive_dangling_references + 1;
        continue;
    end
    archiveRetire(candidates{c}) = true;
    report.archive_docs_retired = report.archive_docs_retired + 1;
end
for c = 1:numel(pvIds)
    if isKey(refs, pvIds{c})
        % something that survives still names the pyraview observation: keep it
        remove(pyraviewRetire, pvIds{c});
        lids = levelIdsByPv(pvIds{c});
        for j = 1:numel(lids); remove(levelReplace, lids{j}); end   % levels stay with it
        report.pyraview_levels_repointed = report.pyraview_levels_repointed - numel(lids);
        report.pyraview_kept_referenced = report.pyraview_kept_referenced + 1;
        continue;
    end
    report.pyraview_observations_retired = report.pyraview_observations_retired + 1;
end
if ~isempty(newQuarantine)
    if isfield(result, 'quarantine') && ~isempty(result.quarantine)
        result.quarantine = [result.quarantine, newQuarantine];
    else
        result.quarantine = newQuarantine;
    end
end

% --- 2026-10-21: retire `observes` where a surviving observation now carries
% the same (instrument, specimen) pair as its instrument_id / entity_id edges.
observesRetire = containers.Map('KeyType', 'char', 'ValueType', 'logical');
emittedKeys = emittedNewIds.keys;
for i = 1:numel(emittedKeys)
    if ~isKey(obsPairById, emittedKeys{i}); continue; end
    pk = obsPairById(emittedKeys{i});
    if ~isKey(observesIdxByPair, pk); continue; end
    idxs = observesIdxByPair(pk);
    for j = 1:numel(idxs)
        rid = docIds{idxs(j)};
        if ~isempty(rid) && ~isKey(observesRetire, rid)
            observesRetire(rid) = true;
            report.observes_retired = report.observes_retired + 1;
        end
    end
end

% --- commit retirements, gated on a surviving replacement -----------------
% A matched #30 observation is removed ONLY if at least one of the observations
% minted to replace it survived. Otherwise the coarse observation is kept -- a
% quarantined replacement already fails the 0-quarantine gate loudly, and
% keeping #30 means nothing is stranded in the meantime.
retireSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:numel(retire30Ids)
    obs30Id = retire30Ids{i};
    repl = retireReplacementIds(obs30Id);
    survived = false;
    for m = 1:numel(repl)
        if isKey(emittedNewIds, repl{m}); survived = true; break; end
    end
    if survived
        retireSet(obs30Id) = true;
        report.session30_observations_retired = ...
            report.session30_observations_retired + 1;
    end
end

% --- decide which #30 session anchors become removable --------------------
% A #30 anchor (base.name == 'migrated_session_anchor') whose only referent was
% a retired observation, and which nothing in the FINAL document set references,
% is removed. The referent check is positive: build the set of every id still
% pointed at after the retirements, and remove an anchor only if its id is
% absent from it.
removeAnchorSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
anchorCandKeys = retire30AnchorCand.keys;
if ~isempty(anchorCandKeys)
    referenced = referencedIdSet(bodies, docIds, retireSet, appended);
    for i = 1:numel(anchorCandKeys)
        aid = anchorCandKeys{i};
        % find the anchor document in the existing set and confirm its marker
        idx = findDocById(docIds, aid);
        if idx == 0; continue; end
        if ~isSessionAnchor(bodies{idx}, sessionIds{idx})
            continue;
        end
        if ~isKey(referenced, aid)
            removeAnchorSet(aid) = true;
            report.session30_anchors_removed = ...
                report.session30_anchors_removed + 1;
        end
    end
end

% --- rebuild the migrated set: drop retired obs + removable anchors, append -
% and REPLACE each renamed epochfiles_ingested with its ingestion_manifest
% (increment 3), id-preserved. A manifest that quarantined leaves the source
% doc unchanged (guarded, counted rename_quarantined above).
kept = {};
for k = 1:n
    id = docIds{k};
    if ~isempty(id) && (isKey(retireSet, id) || isKey(removeAnchorSet, id) ...
            || isKey(observesRetire, id) || isKey(archiveRetire, id) ...
            || isKey(pyraviewRetire, id))
        continue;
    end
    if ~isempty(id) && isKey(levelReplace, id)
        kept{end+1} = levelReplace(id); %#ok<AGROW>
        continue;
    end
    if ~isempty(id) && isKey(renameBodyBySrcId, id)
        if isKey(manifestById, id)   % manifest survived (it preserves the id)
            kept{end+1} = manifestById(id); %#ok<AGROW>
            report.manifests_renamed = report.manifests_renamed + 1;
            continue;
        else
            report.rename_quarantined = report.rename_quarantined + 1;
            % fall through: keep the source epochfiles_ingested unchanged
        end
    end
    kept{end+1} = docs{k}; %#ok<AGROW>
end
result.migrated = [kept, appended];
result.summary = recountSummary(result);
result.epoch_probemap_fold = report;
end

% ===================== builders ========================================

function obs = mkObservation(entry, subjectId, instrumentId, anchorId, ...
        sessionId, datestamp, acId)
% A recording row -> a <modality>_observation of the specimen (did-schema #88:
% a direction + a value kind), the probe as instrument (T7), the rig + channels
% through acquisition_channels_id (#73 item 56). Its value is the epoch's files:
% `data_body` true (2026-10-21, native V2 shape; mkEpochFileBodies builds them).
if nargin < 7; acId = ''; end
% did-schema #88: the direction class plus ONE value-kind mixin, never a
% '<kind>_observation' leaf name (entry.class stays the switch key only)
obs = did2.build.statement('observation', char(subjectId), ...
    did2.convert.registeredTerm('', entry.variable), [], 'ValueKind', entry.mixin, ...
    'DataBody', true, ...
    'TimeReferenceIds', {anchorId}, 'InstrumentId', char(instrumentId), ...
    'AcquisitionChannelsId', char(acId), ...
    'SessionId', char(sessionId), 'CreationTimestamp', char(datestamp), ...
    'Validate', false);
end

function m = mkManipulation(stimType, subjectId, instrumentId, anchorId, ...
        sessionId, datestamp, acId)
% A stimulator row -> a term_manipulation of the specimen: the stimulator type
% as both the variable and the term value (#66 increment 3), the stimulator
% element-subject as instrument (T7), the wiring through acquisition_channels_id.
if nargin < 7; acId = ''; end
typeTerm = did2.convert.registeredTerm('', stimType);
m = did2.build.statement('manipulation', char(subjectId), typeTerm, typeTerm, ...
    'TimeReferenceIds', {anchorId}, 'InstrumentId', char(instrumentId), ...
    'AcquisitionChannelsId', char(acId), ...
    'SessionId', char(sessionId), 'CreationTimestamp', char(datestamp), ...
    'Validate', false, 'ValueKind', 'term');
end

function anchor = mkEpochAnchor(epochDocId, sessionId, datestamp)
% "during the epoch": a relative_time_reference onto the epoch entity.
anchor = did2.build.relativeTimeReference(char(epochDocId), 'Relation', 'intervalDuring', ...
    'SessionId', char(sessionId), 'CreationTimestamp', char(datestamp), ...
    'Validate', false);
end

function ac = mkAcquisitionChannels(acqSystemId, channels, sessionId, datestamp)
fields = struct();
if ~isempty(channels)
    fields.channels = channels;
end
edges = struct();
if ~isempty(acqSystemId)
    edges.acquisition_system_id = char(acqSystemId);
end
ac = did2.build.document('acquisition_channels', fields, 'Edges', edges, ...
    'SessionId', char(sessionId), 'CreationTimestamp', char(datestamp), ...
    'Validate', false);
end

function tf = channelsBindable(channels)
% acquisition_channels.channels.type is bound REQUIRED to ai | ao | di | do.
tf = true;
for i = 1:numel(channels)
    if ~any(strcmp(char(channels(i).type.name), {'ai', 'ao', 'di', 'do'}))
        tf = false; return;
    end
end
end

function k = channelsKey(sessionId, acqSystemId, channels)
parts = {char(sessionId), char(acqSystemId)};
for i = 1:numel(channels)
    parts{end+1} = [char(channels(i).type.name) sprintf('%d,', channels(i).numbers)]; %#ok<AGROW>
end
k = strjoin(parts, char(0));
end

function t = mkOntologyTerm(node, name)
t = struct('node', char(node), 'name', char(name));
end

function m = mkIngestionManifest(srcBody, filenavigatorId, epochDocId, ...
        sessionId, datestamp)
% did-schema #88: ingestion_manifest {files} with the epoch_file_pattern_id
% edge (v1 filenavigator_id, the epoch_file_pattern keeps its id) and the
% epoch_id edge. No serialized epochprobemap (#73 review item 39): the caller
% only renames when every row has decomposed.
srcId = baseField(srcBody, 'id');
if isempty(srcId); srcId = did.ido.unique_id(); end
m = did2.build.document('ingestion_manifest', ...
    struct('files', {ingestedFilesOf(srcBody)}), ...
    'Edges', struct('epoch_file_pattern_id', char(filenavigatorId), ...
                    'epoch_id', char(epochDocId)), ...
    'Id', srcId, 'SessionId', char(sessionId), ...
    'CreationTimestamp', char(datestamp), 'Validate', false);
end

function files = ingestedFilesOf(body)
%INGESTEDFILESOF The `files` list off an epochfiles_ingested block, {} if absent.
files = {};
if ~isstruct(body) || ~isfield(body, 'epochfiles_ingested') ...
        || ~isstruct(body.epochfiles_ingested)
    return;
end
blk = body.epochfiles_ingested;
if isfield(blk, 'files') && ~isempty(blk.files)
    v = blk.files;
    if iscell(v); files = v(:)';
    elseif ischar(v); files = {v};
    elseif isstring(v); files = cellstr(v(:)');
    end
end
end

function k = obs30TripleKey(subjectId, instrumentId, className)
%OBS30TRIPLEKEY The (subject, instrument, class) key a probemap observation and
%   the #30 observation it supersedes must share. NUL-joined so no component
%   value can bleed into the next (ids and class names never contain NUL).
k = [char(subjectId), char(0), char(instrumentId), char(0), char(className)];
end

% ===================== the device string ==============================

function ch = emptyChannels()
%EMPTYCHANNELS A 0x0 struct array of the channels shape, so `isempty` is true and
%   the observation OMITS the field (absent-is-valid) when no device string
%   parsed. Fields match subject_observation.channels ({type, numbers}).
ch = struct('type', {}, 'numbers', {});
end

function [deviceName, channels, ok] = parseDeviceString(devicestring)
%PARSEDEVICESTRING Split v1's devicestring into a device NAME and grouped
%   {type, numbers} CHANNELS -- the two halves the epoch plan mounts on the
%   observation. Format (ndi daqsystemstring / acquisition_channels.json):
%
%       'intan1:ai27-28,45,88;di1-4'
%        \____/ \_______________________/
%        name   groups, ';'-separated; each is a TYPE (letters) + a
%               ','-separated list of numbers or 'a-b' inclusive ranges.
%
%   `deviceName` is '' when there is no ':'. `channels` is a struct array, one
%   entry per group. `ok` is false when a group could not be parsed; what did
%   parse is still emitted (partial, never invented).
deviceName = '';
channels = emptyChannels();
ok = true;
s = strtrim(char(devicestring));
if isempty(s); return; end
colon = find(s == ':', 1);
if isempty(colon)
    deviceName = s;      % a bare device name, no channel spec
    return;
end
deviceName = strtrim(s(1:colon-1));
spec = strtrim(s(colon+1:end));
if isempty(spec); return; end
groups = strsplit(spec, ';');
for g = 1:numel(groups)
    grp = strtrim(groups{g});
    if isempty(grp); continue; end
    tok = regexp(grp, '^([A-Za-z]+)(.*)$', 'tokens', 'once');
    if isempty(tok); ok = false; continue; end
    [nums, numsOk] = parseNumberSpec(tok{2});
    if ~numsOk; ok = false; end
    channels(end+1) = struct('type', mkOntologyTerm('', tok{1}), ...
        'numbers', nums); %#ok<AGROW>
end
end

function [nums, ok] = parseNumberSpec(s)
%PARSENUMBERSPEC 'ai27-28,45,88' tail -> [27 28 45 88]. Comma-separated single
%   numbers or 'a-b' inclusive ranges. ok is false on an unparsable token.
nums = [];
ok = true;
s = strtrim(char(s));
if isempty(s); return; end
parts = strsplit(s, ',');
for p = 1:numel(parts)
    part = strtrim(parts{p});
    if isempty(part); continue; end
    rng = regexp(part, '^(\d+)-(\d+)$', 'tokens', 'once');
    if ~isempty(rng)
        a = str2double(rng{1}); b = str2double(rng{2});
        if isfinite(a) && isfinite(b) && b >= a
            nums = [nums, a:b]; %#ok<AGROW>
        else
            ok = false;
        end
        continue;
    end
    v = str2double(part);
    if isfinite(v) && v == floor(v)
        nums = [nums, v]; %#ok<AGROW>
    else
        ok = false;
    end
end
end

% ===================== the modality map ================================

function [entries, disposition] = localModality(elementType)
%LOCALMODALITY DUPLICATE of +migrators_j/private/jRecordingModality's type map,
%   reconstructed here because that private helper is unreachable from +convert.
%   Its rows are pinned against jRecordingModality's by
%   testResolveEpochProbemap.m so the two cannot drift. Covers the SAME rows;
%   `multichannel` is dropped (this pass mints no body, so there is no axis to
%   flag). Since 2026-10-21 there is NO divergence: imaging maps to
%   intensity_observation with disposition 'recording', as in jRecordingModality
%   (it was 'image_deferred'; see the note below). If jRecordingModality gains a
%   row, add it here and update that test.
if nargin < 1 || isempty(elementType); elementType = ''; end
key = lower(strtrim(char(elementType)));

entries = emptyEntries();
disposition = 'unresolved';
if isempty(key); return; end

if any(strcmp(key, {'stimulator', 'event', 'intraoral-cannula', ...
        'optogenetic-fiber', 'display', 'stim-n-trode', 'n-led'}))
    disposition = 'stimulator';
    return;
end

% multi-site electrode families: 'n-trode' and any '...electrode-' stem
if strcmp(key, 'n-trode') || ~isempty(regexp(key, '^([a-z0-9_]*_)?electrode-', 'once'))
    entries = mkEntry('voltage_observation', 'voltage', 'voltage');
    disposition = 'recording';
    return;
end

% IMAGE IS DEFERRED, NOT UNRESOLVED. Imaging types ARE a recognised modality --
% jRecordingModality maps them to image_observation and the entry below records
% that mapping so the map still mirrors it -- but they cannot be emitted VALIDLY
% in increment 1. `image` is the one data_type whose `value` cell is
% mustBeNonEmpty, and a probemap row carries NO raster metadata, so every
% descriptor (dtype/axes/color_model) is genuinely unknown. A blank `value` cell
% is REFUSED by the #38 NonVacuousFields gate (armed by default: +did2/+schema/
% cache.m validateField -> did2:validation:vacuousField), and inventing a dtype
% to satisfy it is exactly the guess R6/#30 wrote their rule against. So imaging
% is COUNTED (rows_image_deferred) and left to the second pass, which reaches the
% raster metadata -- never emitted as a vacuous husk. This differs from
% jRecordingModality only in the DISPOSITION (the type->leaf mapping is identical);
% jRecordingObservation carries the same latent blank-cell shape, untested because
% its own tests validate with Validate=false.
%
% NO LONGER DEFERRED, 2026-10-21 (the paragraph above is history): #88 maps a
% camera frame to `intensity_observation` (jRecordingModality, row for row), and
% with the frames in the epoch's file bodies (`data_body` true) no value cell is
% needed, so there is nothing to leave blank.
if any(strcmp(key, {'wide-field-imaging', 'two-photon-imaging', ...
        'one-photon-imaging', 'brightfield-imaging'}))
    entries = mkEntry('intensity_observation', 'intensity', 'intensity');
    disposition = 'recording';
    return;
end

switch key
    case {'patch-vm', 'patch-attached', 'sharp-vm'}
        entries = mkEntry('voltage_observation', 'voltage', 'voltage');
    case {'patch-i', 'sharp-i', 'sharp-im'}
        entries = mkEntry('current_observation', 'current', 'current');
    case {'patch', 'sharp'}
        entries = [mkEntry('voltage_observation', 'voltage', 'voltage'), ...
                   mkEntry('current_observation', 'current', 'current')];
    case 'spikes'
        entries = mkEntry('time_observation', 'time', 'spike');
    case {'ecg', 'eeg'}
        entries = mkEntry('voltage_observation', 'voltage', 'voltage');
    case 'accelerometer'
        entries = mkEntry('acceleration_observation', 'acceleration', 'acceleration');
    case 'thermometer'
        entries = mkEntry('temperature_observation', 'temperature', 'temperature');
    otherwise
        return;   % 'lick-spout', 'reward-well', 'ppg', anything new -> unresolved
end
disposition = 'recording';
end

function e = emptyEntries()
e = struct('class', {}, 'mixin', {}, 'variable', {});
end

function e = mkEntry(className, mixin, variable)
e = struct('class', className, 'mixin', mixin, 'variable', variable);
end

% ===================== probemap parsing ================================

function rows = parseProbemapRows(s)
%PARSEPROBEMAPROWS All FIVE columns per probe row of a serialize() char.
%   Extends epochMint's parseProbemap (which returns only nrows + subjectstring)
%   to the whole row. The writer (NDI epochprobemap_daqsystem.serialize) emits a
%   5-column tab-delimited HEADER then one '\n'-terminated line per probe:
%   name<TAB>reference<TAB>type<TAB>devicestring<TAB>subjectstring. On an
%   unrecognised header every non-empty line is treated as a data row, so a real
%   row is never dropped to a mis-detected header.
rows = struct('name', {}, 'reference', {}, 'type', {}, ...
    'devicestring', {}, 'subjectstring', {});
s = char(s);
tab = sprintf('\t');
nl  = sprintf('\n');
lines = strsplit(s, nl, 'CollapseDelimiters', false);
keep = {};
for i = 1:numel(lines)
    if ~isempty(strtrim(lines{i})); keep{end+1} = lines{i}; end %#ok<AGROW>
end
if isempty(keep); return; end
expected = {'name', 'reference', 'type', 'devicestring', 'subjectstring'};
hfields = strsplit(keep{1}, tab, 'CollapseDelimiters', false);
recognized = numel(hfields) == numel(expected) ...
    && all(cellfun(@(a, b) strcmpi(strtrim(a), b), hfields, expected));
if recognized
    dataLines = keep(2:end);
else
    dataLines = keep;
end
for i = 1:numel(dataLines)
    cols = strsplit(dataLines{i}, tab, 'CollapseDelimiters', false);
    rows(end+1) = struct( ...
        'name',          colAt(cols, 1), ...
        'reference',     colAt(cols, 2), ...
        'type',          colAt(cols, 3), ...
        'devicestring',  colAt(cols, 4), ...
        'subjectstring', colAt(cols, 5)); %#ok<AGROW>
end
end

function v = colAt(cols, i)
if numel(cols) >= i; v = strtrim(cols{i}); else; v = ''; end
end

function s = probemapCharOf(body)
%PROBEMAPCHAROF The `epochprobemap` value off an epochfiles_ingested body, '' if
%   absent/empty or not a char. Snake-first with a camelCase fallback.
s = '';
if ~isstruct(body) || ~isfield(body, 'epochfiles_ingested') ...
        || ~isstruct(body.epochfiles_ingested) ...
        || ~isscalar(body.epochfiles_ingested)
    return;
end
blk = body.epochfiles_ingested;
for name = {'epochprobemap', 'epochProbeMap'}
    f = name{1};
    if isfield(blk, f) && ~isempty(blk.(f))
        v = blk.(f);
        if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
        return;
    end
end
end

function es = epochStringOf(body)
%EPOCHSTRINGOF The epoch-id char field off an epochfiles_ingested block.
es = '';
if ~isstruct(body) || ~isfield(body, 'epochfiles_ingested') ...
        || ~isstruct(body.epochfiles_ingested)
    return;
end
es = charField(body.epochfiles_ingested, {'epoch_id', 'epochId', 'epochid'});
end

function lid = probeLocalIdentifier(name, reference)
%PROBELOCALIDENTIFIER The element-subject local_identifier a probe row maps to.
%   Mirrors +migrators_j/element.m: localId = name, or 'name (ref REFERENCE)'
%   when a reference is present. The probemap serialises `reference` with
%   int2str and element.m stringifies with num2str; for the integer references
%   probes carry these agree, which is the join's one soft spot (documented in
%   the pass header / the build report).
name = char(name);
reference = char(reference);
lid = name;
if ~isempty(reference)
    lid = strtrim(sprintf('%s (ref %s)', name, reference));
end
end

% ===================== the epoch files as bodies (2026-10-21) ==========

function [out, report, quarantine, archiveCarried] = mkEpochFileBodies(specs, emittedIds, bodies, ...
        docIds, readerIdByNavId, archiveIdxByKey, options, report)
%MKEPOCHFILEBODIES One opaque_body per epoch file, owned by every surviving
%   recording observation of that epoch (owner_id repeats). Ingested: the
%   archive's attached series, carried as attached. Otherwise: the files the
%   cache names, by location. Validated here; a quarantine is a real defect.
out = {};
quarantine = [];
pending = {};
archiveCarried = containers.Map('KeyType', 'double', 'ValueType', 'any');
carriedById = containers.Map('KeyType', 'char', 'ValueType', 'any');  % body id -> {archive idx, names}
for s = 1:numel(specs)
    sp = specs(s);
    owners = {};
    for i = 1:numel(sp.obsIds)
        if isKey(emittedIds, sp.obsIds{i}); owners{end+1} = sp.obsIds{i}; end %#ok<AGROW>
    end
    if isempty(owners); continue; end
    report.epochs_with_observations = report.epochs_with_observations + 1;
    src = bodies{sp.src};
    made = {};
    archive = [];
    archiveIdx = 0;
    if ~isempty(sp.navId) && isKey(readerIdByNavId, sp.navId)
        ak = archiveKey(sp.sid, readerIdByNavId(sp.navId), sp.epochString);
        if isKey(archiveIdxByKey, ak)
            archiveIdx = archiveIdxByKey(ak);
            archive = bodies{archiveIdx};
        end
    end
    try
        if ~isempty(archive)
            [made, nMembers, memberNames] = archiveBodies(archive, owners, sp);
            for mi = 1:numel(made)
                carriedById(char(made{mi}.base.id)) = {archiveIdx, memberNames{mi}};
            end
            if ~isempty(made)
                report.epochs_from_archive = report.epochs_from_archive + 1;
                report.bodies_from_archive = report.bodies_from_archive + numel(made);
                report.archive_members_carried = report.archive_members_carried + nMembers;
            end
        end
        if isempty(made)
            made = locationBodies(src, owners, sp);
            if ~isempty(made)
                report.epochs_by_location = report.epochs_by_location + 1;
                report.bodies_by_location = report.bodies_by_location + numel(made);
                report.bodies_size_and_checksum_omitted = ...
                    report.bodies_size_and_checksum_omitted + numel(made);
            end
        end
    catch err
        made = {};
        report.body_build_refused = report.body_build_refused + 1;
        if isempty(report.body_build_first_error)
            report.body_build_first_error = sprintf('%s: %s', err.identifier, err.message);
        end
    end
    if isempty(made)
        report.epochs_no_file_named = report.epochs_no_file_named + 1;
        continue;
    end
    report.body_owner_links = report.body_owner_links + numel(made) * numel(owners);
    pending = [pending, made]; %#ok<AGROW>
end
if isempty(pending); return; end
res = did2.convert.v1_to_v2(pending, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);
report.bodies_quarantined = numel(res.quarantine);
quarantine = res.quarantine;
out = res.migrated(:)';
for i = 1:numel(out)
    try
        bid = char(out{i}.get('base.id'));
    catch
        continue;
    end
    if ~isKey(carriedById, bid); continue; end
    c = carriedById(bid);
    prev = {};
    if isKey(archiveCarried, c{1}); prev = archiveCarried(c{1}); end
    archiveCarried(c{1}) = [prev, c{2}];
end
end

function [made, nMembers, memberNames] = archiveBodies(archive, owners, sp)
%ARCHIVEBODIES The ingested recording, one opaque_body per attached file series
%   of a daqreader_*_epochdata_ingested document. A series slot `foo_#` holds
%   the members `foo_1`, `foo_2`, ... (mfdaq.m attaches its segments that way);
%   they become body_data_0, body_data_1, ... in order, locations VERBATIM, so
%   the bytes are the very ones v1 attached. A declared slot with no attached
%   member is skipped (mfdaq declares 62 slots and fills those it used).
made = {};
nMembers = 0;
memberNames = {};   % per made body: the v1 file_info names it carries
if ~isfield(archive, 'files') || ~isstruct(archive.files); return; end
list = {};
if isfield(archive.files, 'file_list'); list = cellstrOf(archive.files.file_list); end
infos = {};
if isfield(archive.files, 'file_info') && ~isempty(archive.files.file_info)
    fi = archive.files.file_info;
    if isstruct(fi); infos = num2cell(fi(:)'); elseif iscell(fi); infos = fi(:)'; end
end
names = cell(1, numel(infos));
for i = 1:numel(infos)
    names{i} = '';
    if isstruct(infos{i}) && isfield(infos{i}, 'name'); names{i} = char(infos{i}.name); end
end
for L = 1:numel(list)
    slot = list{L};
    if endsWith(slot, '_#')
        stem = slot(1:end-1);
        idx = []; seg = [];
        for i = 1:numel(names)
            if startsWith(names{i}, stem)
                tail = names{i}(numel(stem)+1:end);
                if ~isempty(tail) && all(isstrprop(tail, 'digit'))
                    idx(end+1) = i; seg(end+1) = str2double(tail); %#ok<AGROW>
                end
            end
        end
        [~, order] = sort(seg);
        idx = idx(order);
    else
        idx = find(strcmp(names, slot));
        idx = idx(1:min(1, numel(idx)));
    end
    if isempty(idx); continue; end
    flds = struct('filename', slot);
    comp = compressionOf(names{idx(1)});
    if isempty(comp); comp = compressionOf(slot); end
    if ~isempty(comp); flds.compression = comp; end
    body = did2.build.opaqueBody(owners, binaryFormat(), ...
        'Chunks', numel(idx), ...
        'Fields', flds, ...
        'Description', sprintf(['The ingested recording of epoch %s: v1 attached ' ...
            'file series %s, carried as attached (%d member(s)).'], ...
            sp.epochString, slot, numel(idx)), ...
        'SessionId', sp.sid, 'CreationTimestamp', sp.datestamp, 'Validate', false);
    fi = struct('name', {}, 'locations', {});
    for m = 1:numel(idx)
        loc = struct();
        if isfield(infos{idx(m)}, 'locations'); loc = infos{idx(m)}.locations; end
        fi(end+1) = struct('name', sprintf('body_data_%d', m-1), 'locations', {loc}); %#ok<AGROW>
    end
    body.files.file_info = fi;
    made{end+1} = body; %#ok<AGROW>
    memberNames{end+1} = names(idx); %#ok<AGROW>
    nMembers = nMembers + numel(idx);
end
end

function made = locationBodies(src, owners, sp)
%LOCATIONBODIES One opaque_body per file the epochfiles_ingested cache names,
%   recorded BY LOCATION (ingest 0, never copied), exactly as
%   ndi.setup.V2.recordingDocuments / ndi.document/add_file record a file they
%   do not take in. `epochid://` entries name the epoch, not a file. No size, no
%   checksum: this pass reads documents, not a disk.
made = {};
files = ingestedFilesOf(src);
for f = 1:numel(files)
    path = char(files{f});
    if isempty(strtrim(path)) || contains(path, '://'); continue; end
    [~, stem, ext] = fileparts(path);
    flds = struct('filename', [stem ext]);
    comp = compressionOf([stem ext]);
    if ~isempty(comp); flds.compression = comp; end
    body = did2.build.opaqueBody(owners, formatForExtension(ext), ...
        'Fields', flds, ...
        'Description', sprintf(['A raw recording file of epoch %s, recorded by ' ...
            'location where the source keeps it (named by the v1 ' ...
            'epochfiles_ingested cache; not ingested, never copied).'], sp.epochString), ...
        'SessionId', sp.sid, 'CreationTimestamp', sp.datestamp, 'Validate', false);
    body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
        'delete_original', 0, 'uid', did.ido.unique_id(), 'location', path, ...
        'parameters', '', 'location_type', 'file', 'ingest', 0));
    made{end+1} = body; %#ok<AGROW>
end
end

function t = SPIKE_TRAIN_VARIABLE()
%SPIKE_TRAIN_VARIABLE The variable of a spike-train observation: GO:0001508
%   "action potential" (Jess Haley, 2026-10-21). The ONE place it is chosen.
t = struct('node', 'GO:0001508', 'name', 'action potential');
end

function tf = isElementTypeAssertion(b, typeName)
% +migrators_j/element.m's `element type` term assertion, valued TYPENAME.
tf = false;
if ~isstruct(b) || ~isfield(b, 'statement') || ~isstruct(b.statement) ...
        || ~isfield(b.statement, 'variable'); return; end
v = b.statement.variable;
if ~(isstruct(v) && isfield(v, 'name') && strcmp(char(v.name), 'element type')); return; end
fn = fieldnames(b);
for i = 1:numel(fn)
    x = b.(fn{i});
    if isstruct(x) && isscalar(x) && isfield(x, 'value') && isstruct(x.value) ...
            && isscalar(x.value) && isfield(x.value, 'name') ...
            && strcmpi(strtrim(char(x.value.name)), typeName)
        tf = true;
        return;
    end
end
end

function k = recKey(instrumentId, epochDocId, className)
k = [char(instrumentId), char(0), char(epochDocId), char(0), char(className)];
end

function fi = vhsbFileInfo(b)
% the `epoch_binary_data.vhsb` file_info entry of an acquisition_epoch, [] if none
fi = [];
infos = fileInfos(b);
for i = 1:numel(infos)
    if isstruct(infos{i}) && isfield(infos{i}, 'name') ...
            && strcmp(char(infos{i}.name), 'epoch_binary_data.vhsb')
        fi = infos{i};
        return;
    end
end
end

function infos = fileInfos(b)
infos = {};
if ~isstruct(b) || ~isfield(b, 'files') || ~isstruct(b.files) ...
        || ~isfield(b.files, 'file_info') || isempty(b.files.file_info)
    return;
end
fi = b.files.file_info;
if isstruct(fi); infos = num2cell(fi(:)'); elseif iscell(fi); infos = fi(:)'; end
end

function names = archiveFileNames(b)
% every file a v1 ingested archive holds: its attached file_info names
names = {};
infos = fileInfos(b);
for i = 1:numel(infos)
    if isstruct(infos{i}) && isfield(infos{i}, 'name') && ~isempty(infos{i}.name)
        names{end+1} = char(infos{i}.name); %#ok<AGROW>
    end
end
names = unique(names);
end

function n = countArchiveFiles(bodies, idx)
n = 0;
for i = 1:numel(idx)
    n = n + numel(archiveFileNames(bodies{idx(i)}));
end
end

function [out, quarantine] = mkSpikeBodies(spikeObsIds, emittedIds, bodies, sessionIds, options)
% one opaque_body per surviving spike observation: its acquisition_epoch's
% epoch_binary_data.vhsb, locations VERBATIM (the bytes v1 attached)
out = {};
quarantine = [];
pending = {};
ids = spikeObsIds.keys;
for i = 1:numel(ids)
    if ~isKey(emittedIds, ids{i}); continue; end
    k = spikeObsIds(ids{i});
    b = bodies{k};
    fi = vhsbFileInfo(b);
    datestamp = baseField(b, 'creation_timestamp');
    if isempty(datestamp); datestamp = baseField(b, 'datestamp'); end
    if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
    body = did2.build.opaqueBody({ids{i}}, binaryFormat(), ...
        'Fields', struct('filename', 'epoch_binary_data.vhsb'), ...
        'Description', sprintf(['The spike times of epoch %s: the v1 ' ...
            'element_epoch file epoch_binary_data.vhsb, carried as attached.'], ...
            archiveEpochOf(b)), ...
        'SessionId', char(sessionIds{k}), 'CreationTimestamp', datestamp, ...
        'Validate', false);
    loc = struct();
    if isfield(fi, 'locations'); loc = fi.locations; end
    body.files.file_info = struct('name', 'body_data_0', 'locations', {loc});
    pending{end+1} = body; %#ok<AGROW>
end
if isempty(pending); return; end
res = did2.convert.v1_to_v2(pending, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);
quarantine = res.quarantine;
out = res.migrated(:)';
end

function owners = pyraviewOwnerIndex(bodies, classOf, docIds, sampledIdx)
%PYRAVIEWOWNERINDEX The pyraview observations in the batch, keyed by id: an
%   observation with `data_body` true whose sampled_bodies epochMint folded from
%   a v1 pyraview -- recognised as a recording-kind observation that names NO
%   instrument (the element itself is its entity, +migrators_j/pyraview.m) and
%   owns sampled_bodies. Each entry: entityId, epochDocId (its anchor's
%   referent when that is an epoch), className, levelIdx (its bodies).
owners = containers.Map('KeyType', 'char', 'ValueType', 'any');
idxById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(docIds)
    if ~isempty(docIds{k}); idxById(docIds{k}) = k; end
end
for i = 1:numel(sampledIdx)
    sb = bodies{sampledIdx(i)};
    oid = depValueOf(sb, 'owner_id');
    if isempty(oid) || ~isKey(idxById, oid); continue; end
    ok = idxById(oid);
    ob = bodies{ok};
    cn = classOf{ok};
    if ~any(strcmp(cn, {'voltage_observation', 'current_observation'})); continue; end
    if ~isempty(depValueOf(ob, 'instrument_id')); continue; end
    if isKey(owners, oid)
        e = owners(oid);
        e.levelIdx(end+1) = sampledIdx(i);
        owners(oid) = e;
        continue;
    end
    epochDocId = '';
    aid = depValueOf(ob, 'time_reference_id');
    if ~isempty(aid) && isKey(idxById, aid)
        ab = bodies{idxById(aid)};
        rid = depValueOf(ab, 'referent_id');
        if ~isempty(rid) && isKey(idxById, rid) && strcmp(classOf{idxById(rid)}, 'epoch')
            epochDocId = rid;
        end
    end
    owners(oid) = struct('entityId', depValueOf(ob, 'entity_id'), ...
        'epochDocId', epochDocId, 'className', cn, 'levelIdx', sampledIdx(i));
end
end

function b = setOwner(b, ownerId)
% a body struct with its `owner_id` edge(s) replaced by the one OWNERID
deps = b.depends_on;
if iscell(deps); deps = [deps{:}]; end
keep = ~strcmp({deps.name}, 'owner_id');
d = deps(find(~keep, 1));
if isfield(d, 'value'); d.value = char(ownerId); end          % set only the fields
if isfield(d, 'document_id'); d.document_id = char(ownerId); end   % it already has
b.depends_on = [deps(keep), d];
end

function c = compressionOf(name)
%COMPRESSIONOF A data body's `compression`: 'gzip' when the file name ends in
%   .tgz or .gz (the ingested `.nbf.tgz` segments), else '' -- left empty.
%   Jess Haley, 2026-10-21 ("a"); `compression` is a plain char field
%   (did-schema data_body: "e.g. 'lzw', 'gzip'").
c = '';
n = lower(strtrim(char(name)));
if endsWith(n, '.tgz') || endsWith(n, '.gz')
    c = 'gzip';
end
end

function f = binaryFormat()
f = struct('node', 'EDAM:format_2333', 'name', 'Binary format');
end

function f = formatForExtension(ext)
%FORMATFOREXTENSION An EDAM file-format term for a raw file, by extension, as
%   the native V2 Haley import chooses one (sessionDocuments.m: .mp4 MPEG-4,
%   .tif TIFF); text files are Textual format; every other acquisition format
%   (Intan .rhd, Spike2 .smr, .mat, ...) has no EDAM term and is Binary format.
switch lower(char(ext))
    case '.mp4',            f = struct('node', 'EDAM:format_3997', 'name', 'MPEG-4');
    case {'.tif', '.tiff'}, f = struct('node', 'EDAM:format_3591', 'name', 'TIFF');
    case {'.txt', '.csv', '.tsv'}, f = struct('node', 'EDAM:format_2330', 'name', 'Textual format');
    otherwise,              f = binaryFormat();
end
end

function tf = isArchiveClass(cn)
tf = startsWith(cn, 'daqreader_') && endsWith(cn, 'epochdata_ingested');
end

function k = archiveKey(sessionId, readerId, epochString)
k = [char(sessionId) '|' char(readerId) '|' char(epochString)];
end

function es = archiveEpochOf(b)
es = '';
if isfield(b, 'epochid') && isstruct(b.epochid)
    es = charField(b.epochid, {'epochid', 'epoch_id'});
end
end

function c = cellstrOf(v)
c = {};
if iscell(v); c = cellfun(@char, v(:)', 'UniformOutput', false);
elseif ischar(v) && ~isempty(v); c = {v};
elseif isstring(v); c = cellstr(v(:)');
end
end

function r = relationNameOf(b)
r = '';
if ~isfield(b, 'directed_relation') || ~isstruct(b.directed_relation) ...
        || ~isfield(b.directed_relation, 'relation')
    return;
end
v = b.directed_relation.relation;
if isstruct(v) && isfield(v, 'name'); r = char(v.name);
elseif ischar(v) || isstring(v); r = char(v); end
end

% ===================== small readers ===================================

function k = epochKey(sessionId, localIdentifier)
%EPOCHKEY The shared (session, string) key -- delegated so it cannot drift from
%   epochMint's mint key.
k = did2.convert.epochIndex.pairKey(char(sessionId), char(localIdentifier));
end

function tf = isRecording30Observation(body)
%ISRECORDING30OBSERVATION True for a #30 observation, by its assembler's stamp
%   On did-schema #88 there is no base.name to stamp (#73 item 54), so the
%   observation is recognised by its SHAPE, which only jRecordingObservation
%   produces: an `observation` of a recording value kind, naming an
%   instrument_id, and carrying NO value (the samples live in the recording,
%   not on the statement). A pre-#88 body is still recognised by its stamp.
tf = false;
if ~isstruct(body) || ~isfield(body, 'document_class')
    return;
end
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, 'name') ...
        && strcmp(char(body.base.name), 'migrated_recording_observation')
    tf = true;
    return;
end
if ~strcmp(char(body.document_class.class_name), 'observation')
    return;
end
hasInstrument = false;
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    hasInstrument = any(strcmp({body.depends_on.name}, 'instrument_id'));
end
if ~hasInstrument
    return;
end
kinds = {'voltage', 'current', 'time', 'acceleration', 'temperature', 'intensity'};
for k = 1:numel(kinds)
    if isfield(body, kinds{k})
        blk = body.(kinds{k});
        if isstruct(blk) && isfield(blk, 'value') && ~isempty(blk.value)
            return;     % a value: a measurement, not a recording's statement
        end
        tf = true;
        return;
    end
end
superNames = {};
try
    sc = body.document_class.superclasses;
    if isstruct(sc); superNames = {sc.class_name}; end
catch
end
tf = any(ismember(kinds, superNames));
end

function tf = isSessionAnchor(body, sessionId)
%ISSESSIONANCHOR A "during the session" anchor: a pre-#88 body by its stamp, a
%   #88 relative_time_reference by its shape -- its referent is the session
%   and it states no start (no base.name is written on #88, item 54).
tf = false;
if ~isstruct(body); return; end
if strcmp(baseField(body, 'name'), 'migrated_session_anchor')
    tf = true; return;
end
if ~strcmp(classNameOf(body), 'relative_time_reference'); return; end
if isempty(sessionId) || ~strcmp(depValueOf(body, 'referent_id'), sessionId); return; end
v = struct();
if isfield(body, 'relative_time_reference') && isstruct(body.relative_time_reference) ...
        && isfield(body.relative_time_reference, 'value')
    v = body.relative_time_reference.value;
end
tf = ~(isstruct(v) && isfield(v, 'start') && ~isempty(v.start));
end

function cn = classNameOf(b)
% The class to switch on. did-schema #88: an `entity` reads as its type
% ('epoch', 'organism', ...); a statement as <value kind>_<direction>.
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
if strcmp(cn, 'entity') && isfield(b, 'entity') && isstruct(b.entity) ...
        && isfield(b.entity, 'type')
    t = b.entity.type;
    if isstruct(t) && isfield(t, 'name') && ~isempty(t.name)
        cn = char(t.name);
    end
elseif any(strcmp(cn, {'observation', 'assertion', 'manipulation', 'calculation'}))
    try
        sc = b.document_class.superclasses;
        if isstruct(sc); sc = num2cell(sc); end
        names = cell(1, numel(sc));
        for k = 1:numel(sc)
            if isstruct(sc{k}); names{k} = char(sc{k}.class_name); else; names{k} = char(sc{k}); end
        end
        kind = char(did2.schema.cache.shared().documentValueKind(cn, names));
        if ~isempty(kind); cn = [kind '_' cn]; end
    catch
    end
end
end

function v = baseField(b, name)
v = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, name)
    x = b.base.(name);
    if ischar(x) || isstring(x); v = char(x); end
end
end

function v = charField(s, candidates)
v = '';
for k = 1:numel(candidates)
    if isstruct(s) && isfield(s, candidates{k})
        x = s.(candidates{k});
        if ischar(x) || isstring(x); v = char(x); return; end
    end
end
end

function v = depValueOf(b, name)
%DEPVALUEOF Value of one depends_on entry on a body STRUCT, '' when absent or
%   present-and-empty. Tolerant of `value`/`document_id` and of cell/struct.
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps)
    items = deps(:)';
elseif isstruct(deps)
    items = num2cell(deps(:)');
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value); return;
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id); return;
    end
    return;
end
end

function idx = findDocById(docIds, id)
idx = 0;
for k = 1:numel(docIds)
    if strcmp(docIds{k}, id); idx = k; return; end
end
end

function refset = referencedIdSet(bodies, docIds, retireSet, appended)
%REFERENCEDIDSET Every id pointed at by a depends_on in the FINAL document set:
%   existing bodies MINUS the retired observations, PLUS the appended new ones.
%   Used only to confirm a candidate #30 anchor is truly unreferenced before
%   removing it -- positive evidence, never absence of a search.
refset = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(bodies)
    if isempty(bodies{k}); continue; end
    id = docIds{k};
    if ~isempty(id) && isKey(retireSet, id); continue; end   % retired: gone
    addRefs(refset, bodies{k});
end
for k = 1:numel(appended)
    try
        addRefs(refset, appended{k}.toStruct());
    catch
    end
end
end

function addRefs(refset, b)
if ~isstruct(b) || ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps)
    items = deps(:)';
elseif isstruct(deps)
    items = num2cell(deps(:)');
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d); continue; end
    val = '';
    if isfield(d, 'value') && ~isempty(d.value); val = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); val = char(d.document_id); end
    if ~isempty(val); refset(val) = true; end
end
end

function summary = recountSummary(result)
summary = struct();
if isfield(result, 'summary') && isstruct(result.summary); summary = result.summary; end
summary.migrated_count = numel(result.migrated);
if isfield(result, 'quarantine'); summary.quarantine_count = numel(result.quarantine); end
byClass = struct();
for k = 1:numel(result.migrated)
    fieldName = matlab.lang.makeValidName(result.migrated{k}.className());
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end
