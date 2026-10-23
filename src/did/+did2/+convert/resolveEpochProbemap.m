function [result, report] = resolveEpochProbemap(result, options)
%RESOLVEEPOCHPROBEMAP Decompose an ingested epoch's serialized `epochprobemap`
%   into one epoch-scoped observation (direction `observation` + the modality's
%   value-kind mixin) per probe row, retiring #30's
%   coarse session-scoped observation for that same probe.
%
%   The epochprobemap decomposition (DID-schema V_eta_OPEN_WORK.md row #66),
%   ALL THREE INCREMENTS:
%     1  OBSERVATION half: one epoch-scoped observation of the modality per probe
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
%   `element` is consumed because each per-epoch recording observation (Jess
%   Haley 2026-10-21 [epoch files as data bodies], [spike trains as epoch
%   bodies]) is the observation OF that element: its instrument is the
%   element-entity +migrators_j/element.m kept under the element's own id,
%   found by the probe-map row's name and reference, and the element's
%   `observes` relation is retired here once that observation carries the
%   instrument_id edge. The same documents are also listed under
%   epochfiles_ingested, whose probe-map rows and files they are built from.
%
%   BATCH-PASS-CONSUMES: epochfiles_ingested, acquisition_epoch, pyraview, element,
%       daqmetadatareader_epochdata_ingested
%   BATCH-PASS-EMITS: epochfiles_ingested -> document: observation+voltage, observation+current, observation+time, observation+acceleration, observation+temperature, manipulation+term, ingestion_manifest, relative_reference, opaque_body, observation+intensity
%   BATCH-PASS-EMITS: acquisition_epoch -> document: observation+time, calculation+position, calculation+length, calculation+item, coordinate_system, opaque_body, relative_time_reference
%   BATCH-PASS-EMITS: pyraview -> nothing: its level bodies (minted by
%       +migrators_j/pyraview through epochMint) are RE-POINTED to the epoch's
%       recording observation and its separate observation retired; nothing
%       new is minted for it here, so crediting it would count epochMint's
%       emission twice.
%   BATCH-PASS-EMITS: element -> document: observation+voltage, observation+current, observation+intensity, observation+acceleration, observation+temperature, observation+time, opaque_body, relative_time_reference
%   BATCH-PASS-EMITS: daqmetadatareader_epochdata_ingested -> document: opaque_body
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
%                    pyraview observation's data type and its anchor are folded
%                    as [pyraview leftovers, schema form] decides (see the
%                    re-point step below).
%
%   IMAGING ROWS ARE NO LONGER DEFERRED (2026-10-21). They were left to the
%   second pass because the old `image` value cell was required and a probemap
%   row carries no raster metadata. did-schema #88 retired `image` (a camera
%   frame is an observation of `intensity`, as jRecordingModality maps it), and with
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
    'rigs_without_daqsystem',         0, ...
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
    'channels_derived_read_mode',     0, ...
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
    'acquisition_epoch_seen',         0, ...
    'acquisition_epoch_dissolved',    0, ...
    'acquisition_epoch_kept_type_undecided', 0, ...
    'acquisition_epoch_kept_types',   '', ...
    'acquisition_epoch_kept_no_epoch', 0, ...
    'acquisition_epoch_kept_no_file', 0, ...
    'acquisition_epoch_kept_clock',   0, ...
    'acquisition_epoch_kept_not_rebuilt', 0, ...
    'acquisition_epoch_kept_no_subject', 0, ...
    'acquisition_epoch_kept_ensemble_unverified', 0, ...
    'position_calculations_emitted',  0, ...
    'distance_calculations_emitted',  0, ...
    'nearest_patch_calculations_emitted', 0, ...
    'coordinate_systems_minted',      0, ...
    'distance_without_position',      0, ...
    'nearest_patch_without_patches',  0, ...
    'element_epoch_anchors_minted',   0, ...
    'archive_docs_inspected',         0, ...
    'archive_docs_retired',           0, ...
    'archive_docs_kept_unowned_files',0, ...
    'archive_files_unowned',          0, ...
    'archive_kept_referenced',        0, ...
    'archive_dangling_references',    0, ...
    'metadata_archives_inspected',    0, ...
    'metadata_archives_to_body',      0, ...
    'metadata_archive_owner_links',   0, ...
    'metadata_archives_kept_no_owner',0, ...
    'metadata_archives_kept_no_bytes',0, ...
    'metadata_archives_quarantined',  0, ...
    'pyraview_observations_seen',     0, ...
    'pyraview_levels_repointed',      0, ...
    'pyraview_observations_retired',  0, ...
    'pyraview_kept_no_recording_observation', 0, ...
    'pyraview_kept_referenced',       0, ...
    'pyraview_repoint_quarantined',   0, ...
    'pyraview_data_type_moved',       0, ...
    'pyraview_kept_data_type_conflict', 0, ...
    'pyraview_anchor_equal_epoch_dropped', 0, ...
    'pyraview_anchor_to_time_key',    0, ...
    'pyraview_anchor_not_comparable_to_time_key', 0, ...
    'pyraview_kept_start_conflict',   0, ...
    'sorter_calculations_seen',       0, ...
    'sorter_inputs_linked',           0, ...
    'sorter_input_edges',             0, ...
    'sorter_input_fallback_entity',   0, ...
    'sorter_link_quarantined',        0, ...
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
kindOf = repmat({''}, 1, n);     % a statement's value kind (classOf is its direction)
sessionIds = repmat({''}, 1, n);
docIds = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k} = b;
        classOf{k} = classNameOf(b);
        [~, kindOf{k}] = did2.convert.statementKind(b);
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
rigsWithoutSystem = containers.Map('KeyType', 'char', 'ValueType', 'logical');
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
% element entity id -> its v1 element `type` (the `element type` assertion of
% +migrators_j/element.m). The element_epoch dissolution keys on it.
elementTypeById = containers.Map('KeyType', 'char', 'ValueType', 'char');
derivedParent = containers.Map('KeyType', 'char', 'ValueType', 'char');
acqEpochIdx = [];
sampledIdx = [];
archiveIdxAll = [];
% (g) #73 review item 61: each v1 `daqmetadatareader_epochdata_ingested` (the
%     epoch's parsed stimulus parameters, one .nbf.tgz as `data.bin`) by
%     (session, metadata reader, epoch string), and each acquisition system's
%     epoch parameter readers (the v1 daqmetadatareaders, ids preserved by
%     +migrators_j/daqsystem.m) by its file pattern (the v1 filenavigator).
metaArchiveIdxByKey = containers.Map('KeyType', 'char', 'ValueType', 'double');
paramReadersByNavId = containers.Map('KeyType', 'char', 'ValueType', 'any');
metaArchiveIdxAll = [];
for k = 1:n
    if isempty(bodies{k}); continue; end
    b = bodies{k};
    if strcmp(classOf{k}, 'acquisition_epoch'); acqEpochIdx(end+1) = k; end %#ok<AGROW>
    if strcmp(classOf{k}, 'sampled_body'); sampledIdx(end+1) = k; end %#ok<AGROW>
    if isArchiveClass(classOf{k}); archiveIdxAll(end+1) = k; end %#ok<AGROW>
    if strcmp(classOf{k}, 'daqmetadatareader_epochdata_ingested')
        metaArchiveIdxAll(end+1) = k; %#ok<AGROW>
        mrd = depValueOf(b, 'daqmetadatareader_id');
        mep = archiveEpochOf(b);
        if ~isempty(mrd) && ~isempty(mep)
            mk = archiveKey(sessionIds{k}, mrd, mep);
            if ~isKey(metaArchiveIdxByKey, mk); metaArchiveIdxByKey(mk) = k; end
        end
    end
    et = elementTypeOfAssertion(b);
    if ~isempty(et)
        eid = depValueOf(b, 'entity_id');
        if ~isempty(eid) && ~isKey(elementTypeById, eid)
            elementTypeById(eid) = et;
        end
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
            prIds = depValuesOf(b, 'epoch_parameter_reader_id');
            if ~isempty(navId) && ~isempty(prIds) && ~isKey(paramReadersByNavId, navId)
                paramReadersByNavId(navId) = prIds;
            end
        case 'directed_relation'
            if did2.build.isVocabulary(relationOf(b), 'relation', 'derived_from')   % by node (L1)
                ch = depValueOf(b, 'child_id');
                if ~isempty(ch) && ~isKey(derivedParent, ch)
                    derivedParent(ch) = depValueOf(b, 'parent_id');
                end
            end
            if did2.build.isVocabulary(relationOf(b), 'relation', 'observes')   % a pass-1 handle with no node
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
            tk = obs30TripleKey(subj, instr, classOf{k}, kindOf{k});
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
% #73 review item 61: per epochfiles_ingested document, the stimulator
% manipulations it minted -- the owners of that epoch's metadata archive.
stimSpecs = struct('manipIds', {}, 'sid', {}, 'epochString', {}, 'navId', {});
obsPairById = containers.Map('KeyType', 'char', 'ValueType', 'char');
recByInstrEpoch = containers.Map('KeyType', 'char', 'ValueType', 'char');
spikeObsIds = containers.Map('KeyType', 'char', 'ValueType', 'double');  % obs id -> acquisition_epoch idx
spikeAnchorByObs = containers.Map('KeyType', 'char', 'ValueType', 'char');  % obs id -> its own anchor id
seriesKindById = containers.Map('KeyType', 'char', 'ValueType', 'char');    % stmt id -> its report counter
csOfStmt = containers.Map('KeyType', 'char', 'ValueType', 'char');          % position stmt id -> its coordinate system

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
    specManipIds = {};
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
                    % [rig minting with edges] (Jess Haley 2026-10-22, 2a): a
                    % system is only ever the one migrated from the rig's v1
                    % daqsystem, with its reader_id and epoch_file_pattern_id;
                    % a rig with no daqsystem document gets NO system (never a
                    % name-only one) and is counted, once per (session, rig)
                    report.device_acqsystem_unresolved = ...
                        report.device_acqsystem_unresolved + 1;
                    if ~isKey(rigsWithoutSystem, dk)
                        rigsWithoutSystem(dk) = true;
                        report.rigs_without_daqsystem = report.rigs_without_daqsystem + 1;
                    end
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
                report.channels_derived_read_mode = ...
                    report.channels_derived_read_mode + derivedReadModes(channels);
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
            specManipIds{end+1} = manip.base.id;   %#ok<AGROW>
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
                rk = recKey(instrumentId, epochDocId, entries(e).class, entries(e).mixin);
                if ~isKey(recByInstrEpoch, rk); recByInstrEpoch(rk) = obs.base.id; end
            end
            newGroupAnchor{end+1} = anchorId;       %#ok<AGROW>
            newGroupAc{end+1} = acId;               %#ok<AGROW>

            if ~isempty(instrumentId)
                tk = obs30TripleKey(subjectId, instrumentId, entries(e).class, entries(e).mixin);
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
    if ~isempty(specManipIds)
        stimSpecs(end+1) = struct('manipIds', {specManipIds}, 'sid', sid, ...
            'epochString', es, 'navId', fnId); %#ok<AGROW>
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

% ---- the element_epoch dissolution (F1, D2) -----------------------------
% Decided by Jess Haley, 2026-10-22 [epoch dissolution before merge] (F1,
% did-schema V_eta_epoch_plan.md, building TEAM-SIGN-OFF [epoch] 2026-08-08 /
% 2026-08-17 and its AMENDMENT 1), with [spike trains as epoch bodies] and
% [spike train variable] (Jess Haley, 2026-10-21,
% V_eta_recording_observation_plan.md). A v1 element_epoch (here
% acquisition_epoch, its interim name) is ONE element's slice of one epoch: its
% own clock extent and its own .vhsb payload. It DISSOLVES into
%   - ONE observation per (element, epoch), base.id PRESERVED (the v1
%     element_epoch id, so `ensemble.element_epoch_id` and any other inbound
%     edge keeps resolving), entity = the element entity, instrument = the
%     element it was derived from (its `derived_from` parent), `data_body` true;
%   - its OWN relative_time_reference onto the minted `epoch` entity, built
%     from the v1 t0_t1 + epoch_clock (clock, start t0, end t1): the spike
%     times in the body are readings of that clock;
%   - the .vhsb, carried as attached, as the observation's data body
%     (opaque_body, `body_data_0`; the NDI second pass,
%     ndi.migrate.internal.epochSeriesBodies, re-describes it as a sampled_body
%     with complete extents when the bytes are on the computer doing the
%     migration -- a document-only corpus never has them).
% and the acquisition_epoch LEAVES the batch once all three survived
% validation. One statement per epoch, not one per element: the
% time_reference_id family on an interaction names ONE extent (interaction.json),
% so twelve epochs cannot share one statement's anchor.
%
% KEYED ON THE ELEMENT `type`, never on spikes (AMENDMENT 1: the .vhsb is a
% generic (timepoints, datapoints) series). derivedSeriesKind is the one table;
% a type with no decided row keeps its acquisition_epoch, counted by type.
% THE JH ROWS (Decided by Jess Haley, 2026-10-22 [JH position and distance],
% V_eta_epoch_plan.md): a `position` epoch is a position calculation of the
% worm and a `distance` epoch a length calculation of `signed distance to
% region boundary` plus an item calculation of `nearest bacterial patch`, the
% shapes ndi.setup.conv.haley.trackDocuments writes. The worm is the element's
% `derived_from` parent (+migrators_j/element.m, a derived element with no
% underlying element); the element itself is the instrument, the one link from
% the element to its series. A distance's inputs are the position calculation
% of the same worm and body part (element names <stem>_position /
% <stem>_distance); its patches (item_id) are the v1 distance_metadata's
% endpoint B rows, in order.
elementLid = containers.Map('KeyType', 'char', 'ValueType', 'char');
patchIdsByElement = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:n
    b = bodies{k};
    if isempty(b) || isempty(docIds{k}); continue; end
    if isKey(elementTypeById, docIds{k}) && isfield(b, 'entity') && isstruct(b.entity)
        elementLid(docIds{k}) = charField(b.entity, {'local_identifier'});
    end
    if strcmp(classOf{k}, 'distance_metadata')
        eid = depValueOf(b, 'element_id');
        ids = distanceEndpointIds(b, 'B');
        if ~isempty(eid) && ~isempty(ids); patchIdsByElement(eid) = ids; end
    end
end
idInBatch = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:n
    if ~isempty(docIds{k}); idInBatch(docIds{k}) = true; end
end
% (session, worm, stem) -> the position calculation's id (= its epoch's id)
positionByStem = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:numel(acqEpochIdx)
    k = acqEpochIdx(i);
    elId = depValueOf(bodies{k}, 'element_id');
    if isempty(elId) || ~isKey(elementTypeById, elId) ...
            || ~strcmp(elementTypeById(elId), 'position') || ~isKey(derivedParent, elId)
        continue;
    end
    positionByStem(stemKey(sessionIds{k}, derivedParent(elId), elementLid, elId)) = docIds{k};
end
csByEpoch = containers.Map('KeyType', 'char', 'ValueType', 'char');
seriesGroups = containers.Map('KeyType', 'double', 'ValueType', 'any');  % k -> {stmt ids}
seriesInputs = containers.Map('KeyType', 'double', 'ValueType', 'char'); % k -> position id it uses
for i = 1:numel(acqEpochIdx)
    k = acqEpochIdx(i);
    b = bodies{k};
    report.acquisition_epoch_seen = report.acquisition_epoch_seen + 1;
    elId = depValueOf(b, 'element_id');
    elType = '';
    if ~isempty(elId) && isKey(elementTypeById, elId); elType = elementTypeById(elId); end
    kind = derivedSeriesKind(elType);
    if strcmp(elType, 'ensemble')
        % An ensemble element's epoch holds the COMBINED (times, neuron)
        % bytes. Decided by Jess Haley, 2026-10-22 [no ensemble cache]: not
        % kept as a cache, and "dropped only after every member neuron's
        % train is verified present for that epoch" -- a check over the
        % ensemble map, which ndi.migrate.internal.ensembleMembership makes
        % (and drops this document with the map when it passes). Here,
        % unverified, it stays, counted.
        report.acquisition_epoch_kept_ensemble_unverified = ...
            report.acquisition_epoch_kept_ensemble_unverified + 1;
        continue;
    end
    if isempty(kind)
        report.acquisition_epoch_kept_type_undecided = ...
            report.acquisition_epoch_kept_type_undecided + 1;
        report.acquisition_epoch_kept_types = tallyName( ...
            report.acquisition_epoch_kept_types, firstNonEmptyChar(elType, 'no-element-type'));
        continue;
    end
    if strcmp(elType, 'spikes')
        report.spike_epochs_seen = report.spike_epochs_seen + 1;
    end
    sid = sessionIds{k};
    es = archiveEpochOf(b);
    if isempty(es) || ~isKey(epochIdByKey, epochKey(sid, es))
        report.spike_refused_no_epoch = report.spike_refused_no_epoch + strcmp(elType, 'spikes');
        report.acquisition_epoch_kept_no_epoch = report.acquisition_epoch_kept_no_epoch + 1;
        continue;
    end
    if isempty(vhsbFileInfo(b))
        report.spike_epochs_no_file = report.spike_epochs_no_file + strcmp(elType, 'spikes');
        report.acquisition_epoch_kept_no_file = report.acquisition_epoch_kept_no_file + 1;
        continue;
    end
    [clk, t0, t1] = epochLocalClock(b);
    if isempty(clk)
        % no dev_local_time record: an offset "from the epoch" is defined
        % only on the epoch's own clock. Its other clocks (JH's
        % exp_global_time) are the epoch's own extents, minted onto the epoch
        % entity by did2.convert.epochMint (#60 option A) from this document.
        report.acquisition_epoch_kept_clock = report.acquisition_epoch_kept_clock + 1;
        continue;
    end
    % who the statement is about, and with what
    if kind.aboutElement
        entityId = elId;
        instrumentId = '';
        if isKey(derivedParent, elId); instrumentId = derivedParent(elId); end
    else
        if ~isKey(derivedParent, elId)
            report.acquisition_epoch_kept_no_subject = ...
                report.acquisition_epoch_kept_no_subject + 1;
            continue;
        end
        entityId = derivedParent(elId);
        instrumentId = elId;
    end
    epochDocId = epochIdByKey(epochKey(sid, es));
    datestamp = baseField(b, 'creation_timestamp');
    if isempty(datestamp); datestamp = baseField(b, 'datestamp'); end
    if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
    sec = struct('node', 'om:second-Time', 'name', 'second');
    anchor = did2.build.relativeTimeReference(char(epochDocId), 'Clock', clk, ...
        'Start', t0, 'StartSourceValue', t0, 'StartSourceUnit', sec, ...
        'StartApproximate', false, ...
        'End', t1, 'EndSourceValue', t1, 'EndSourceUnit', sec, ...
        'EndApproximate', false, ...
        'SessionId', char(sid), 'CreationTimestamp', char(datestamp), ...
        'Validate', false);
    anchorId = anchor.base.id;
    % keyed per series (its own extent), so the group carry below treats it as
    % any other anchor: alive only if validated, emitted only if referenced
    anchorByEpochId(['element_epoch|' docIds{k}]) = anchorId;
    anchorBodyById(anchorId) = anchor;
    report.element_epoch_anchors_minted = report.element_epoch_anchors_minted + 1;
    common = {'DataBody', true, 'TimeReferenceIds', {anchorId}, ...
        'InstrumentId', char(instrumentId), ...
        'SessionId', char(sid), 'CreationTimestamp', char(datestamp), 'Validate', false};
    group = {};
    for j = 1:numel(kind.statements)
        st = kind.statements(j);
        args = [common, {'ValueKind', st.valueKind}];
        if j == 1; args = [args, {'Id', char(docIds{k})}]; end %#ok<AGROW>
        if ~isempty(st.method)
            args = [args, {'Method', st.method}]; %#ok<AGROW>
            if ~isempty(st.methodParameters)
                args = [args, {'MethodParameters', st.methodParameters}]; %#ok<AGROW>
            end
        end
        if ~isempty(st.conditions); args = [args, {'Conditions', st.conditions}]; end %#ok<AGROW>
        csId = '';
        edges = struct();
        if strcmp(st.valueKind, 'position')
            % the pixel grid this track is in (trackDocuments' coordinate
            % system, uncalibrated: v1 records pixels and no scale), one per
            % epoch, ON the epoch it was recorded in
            if isKey(csByEpoch, epochDocId)
                csId = csByEpoch(epochDocId);
            else
                cs = mkPixelCoordinateSystem(epochDocId, sid, datestamp);
                csId = cs.base.id;
                csByEpoch(epochDocId) = csId;
                acBodyById(csId) = cs;
                report.coordinate_systems_minted = report.coordinate_systems_minted + 1;
            end
            edges.coordinate_system_id = csId;
        end
        if strcmp(st.valueKind, 'item')
            if isKey(patchIdsByElement, elId) ...
                    && all(cellfun(@(x) isKey(idInBatch, x), patchIdsByElement(elId)))
                edges.item_id = patchIdsByElement(elId);
            else
                report.nearest_patch_without_patches = report.nearest_patch_without_patches + 1;
            end
        end
        if ~isempty(fieldnames(edges)); args = [args, {'Edges', edges}]; end %#ok<AGROW>
        if st.inputsPosition
            pk = stemKey(sid, entityId, elementLid, elId);
            if isKey(positionByStem, pk)
                args = [args, {'InputIds', {positionByStem(pk)}}]; %#ok<AGROW>
                seriesInputs(k) = positionByStem(pk);
            else
                report.distance_without_position = report.distance_without_position + 1;
            end
        end
        stmt = did2.build.statement(kind.className, char(entityId), st.variable, [], args{:});
        newBodies{end+1} = stmt;             %#ok<AGROW>
        newGroupAnchor{end+1} = anchorId;    %#ok<AGROW>
        newGroupAc{end+1} = csId;            %#ok<AGROW>
        spikeObsIds(stmt.base.id) = k;
        spikeAnchorByObs(stmt.base.id) = anchorId;
        seriesKindById(stmt.base.id) = st.counter;
        if ~isempty(csId); csOfStmt(stmt.base.id) = csId; end
        group{end+1} = stmt.base.id; %#ok<AGROW>
    end
    seriesGroups(k) = group;
    if ~isempty(instrumentId) && kind.aboutElement
        report.spike_instrument_resolved = report.spike_instrument_resolved + 1;
    end
end

report.archive_docs_inspected = numel(archiveIdxAll);
report.metadata_archives_inspected = numel(metaArchiveIdxAll);
pyraviewOwners = pyraviewOwnerIndex(bodies, classOf, kindOf, docIds, sampledIdx);
report.pyraview_observations_seen = double(pyraviewOwners.Count);

% [sorter input] (Jess Haley, 2026-10-21; did-schema
% V_eta_go_forward_class_audit.md): a spike-sorter output -- the calculation
% with the `label` value kind and variable 'spike cluster assignment' that
% +migrators_j/jrclust_clusters and jSorterOutput emit, about the sorted
% electrode -- "takes as its input the per-epoch recording observations of
% the electrode it sorted, when they exist, falling back to the electrode
% entity when they do not". Those observations are emitted HERE (the electrode
% is their instrument), so the input edges are added here; the fallback is the
% calculation's own entity_id (the electrode), with no input_id, because
% `input_id` is typed to statements, never an entity (calculation.json).
sorterIdx = [];
for k = 1:n
    if strcmp(classOf{k}, 'calculation') && strcmp(kindOf{k}, 'label') ...
            && isSorterVariable(bodies{k})
        sorterIdx(end+1) = k; %#ok<AGROW>
    end
end
report.sorter_calculations_seen = numel(sorterIdx);

renameBodies = renameBodyBySrcId.values;
if isempty(newBodies) && isempty(renameBodies)
    % nothing emitted: no archive file has a new owner, and no pyraview has a
    % recording observation to move to -- both kept, and counted as such
    report.archive_docs_kept_unowned_files = report.archive_docs_inspected;
    report.archive_files_unowned = countArchiveFiles(bodies, archiveIdxAll);
    report.metadata_archives_kept_no_owner = report.metadata_archives_inspected;
    report.pyraview_kept_no_recording_observation = report.pyraview_observations_seen;
    report.sorter_input_fallback_entity = report.sorter_calculations_seen;
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
recIdsByInstr = containers.Map('KeyType', 'char', 'ValueType', 'any');   % electrode -> its recording observations
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
        c = seriesKindById(id);
        report.(c) = report.(c) + 1;
    else
        report.observations_emitted = report.observations_emitted + 1;
        instr = depValueOf(newBodies{j}, 'instrument_id');
        if ~isempty(instr)
            if isKey(recIdsByInstr, instr)
                recIdsByInstr(instr) = [recIdsByInstr(instr), {id}];
            else
                recIdsByInstr(instr) = {id};
            end
        end
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
[spikeBodies, spikeQ] = mkSpikeBodies(seriesGroups, emittedNewIds, bodies, ...
    sessionIds, options);
report.spike_bodies = numel(spikeBodies);
report.spike_bodies_quarantined = numel(spikeQ);
appended = [appended, spikeBodies];
newQuarantine = [newQuarantine, spikeQ];
% THE DISSOLUTION COMMITS PER TRAIN, ALL OR NOTHING: the observation, its own
% anchor and its body all survived -> the acquisition_epoch leaves (the
% observation carries its id). Any one missing -> the observation and its
% anchor are withdrawn and the acquisition_epoch stays, counted, so an id is
% never held by two documents and no observation claims bytes it has no body for.
bodyOwners = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for j = 1:numel(spikeBodies)
    try
        sb = spikeBodies{j};
        if isa(sb, 'did2.document'); sb = sb.toStruct(); end
        ow = depValuesOf(sb, 'owner_id');
        for m = 1:numel(ow); bodyOwners(ow{m}) = true; end
    catch
    end
end
acqEpochRetire = containers.Map('KeyType', 'char', 'ValueType', 'logical');
withdraw = containers.Map('KeyType', 'char', 'ValueType', 'logical');
groupKs = cell2mat(seriesGroups.keys);
okGroup = containers.Map('KeyType', 'double', 'ValueType', 'logical');
for j = 1:numel(groupKs)
    g = seriesGroups(groupKs(j));
    ok = ~isempty(g);
    for m = 1:numel(g)
        ok = ok && isKey(emittedNewIds, g{m}) && isKey(bodyOwners, g{m});
    end
    okGroup(groupKs(j)) = ok;
end
% a distance whose position calculation (its input) did not land is
% withdrawn too: an input edge must name a document that is emitted
for j = 1:numel(groupKs)
    kk = groupKs(j);
    if okGroup(kk) && isKey(seriesInputs, kk)
        pid = seriesInputs(kk);
        if ~isKey(spikeObsIds, pid) || ~okGroup(spikeObsIds(pid))
            okGroup(kk) = false;
        end
    end
end
for j = 1:numel(groupKs)
    kk = groupKs(j);
    g = seriesGroups(kk);
    if okGroup(kk)
        acqEpochRetire(docIds{kk}) = true;
        report.acquisition_epoch_dissolved = report.acquisition_epoch_dissolved + 1;
        continue;
    end
    report.acquisition_epoch_kept_not_rebuilt = report.acquisition_epoch_kept_not_rebuilt + 1;
    for m = 1:numel(g)
        tid = g{m};
        if isKey(emittedNewIds, tid)
            withdraw(tid) = true;
            c = seriesKindById(tid);
            report.(c) = report.(c) - 1;
            remove(emittedNewIds, tid);
        end
        if isKey(spikeAnchorByObs, tid); withdraw(spikeAnchorByObs(tid)) = true; end
        if isKey(csOfStmt, tid); withdraw(csOfStmt(tid)) = true; end
    end
    % the group's body (owned by its statements only) goes with them
    for m = 1:numel(spikeBodies)
        try
            sb = spikeBodies{m};
            if isa(sb, 'did2.document'); sb = sb.toStruct(); end
            if any(ismember(depValuesOf(sb, 'owner_id'), g))
                withdraw(char(sb.base.id)) = true;
                report.spike_bodies = report.spike_bodies - 1;
            end
        catch
        end
    end
end
if withdraw.Count > 0
    keepA = true(1, numel(appended));
    for j = 1:numel(appended)
        a = appended{j};
        if isa(a, 'did2.document'); aid = char(a.get('base.id')); else; aid = char(a.base.id); end
        keepA(j) = ~isKey(withdraw, aid);
    end
    appended = appended(keepA);
end

% ---- #73 review item 61: the epoch's metadata archive -> an opaque_body ----
% "data.bin (a .nbf.tgz of the epoch's parsed stimulus parameters, written by
% NDI metadatareader.ingest_epochfiles) becomes an opaque_body owned by the
% stimulator's term_manipulation for that epoch". The stimulator manipulations
% are the ones minted above from the same epochfiles_ingested document; the
% archive is the one whose metadata reader is an epoch parameter reader of the
% acquisition system that document's file pattern belongs to, at the same
% epoch string. The body KEEPS the archive's base.id and takes its place, so
% the v1 document is retired only when its one file has a new owner (Jess
% Haley, 2026-10-21 [ingested epoch documents retired]); no owner, no bytes or
% a quarantined body keeps the v1 document, counted.
[metaReplace, metaQ, report] = mkMetadataArchiveBodies(stimSpecs, ...
    emittedNewIds, bodies, paramReadersByNavId, metaArchiveIdxByKey, options, report);
newQuarantine = [newQuarantine, metaQ];

% ---- pyraview levels move to the recording observation -------------------
% (Jess Haley, 2026-10-21, "a"; the signed plan): each pyraview level is a
% data body owned by that epoch's recording observation -- the one emitted
% above for the same element (its instrument) and epoch -- and the separate
% pyraview observation is no longer emitted. Where no recording observation
% exists for that element and epoch, it is kept as it was, and counted.
pyraviewRetire = containers.Map('KeyType', 'char', 'ValueType', 'logical');
levelReplace = containers.Map('KeyType', 'char', 'ValueType', 'any');
levelIdsByPv = containers.Map('KeyType', 'char', 'ValueType', 'any');
recDataType = containers.Map('KeyType', 'char', 'ValueType', 'any');   % recId -> {dt, sdt}
pvFold = containers.Map('KeyType', 'char', 'ValueType', 'any');        % pvId -> what moved
idxByIdAll = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(docIds)
    if ~isempty(docIds{k}); idxByIdAll(docIds{k}) = k; end
end
pvKeys = pyraviewOwners.keys;
for i = 1:numel(pvKeys)
    pv = pyraviewOwners(pvKeys{i});
    rk = recKey(pv.entityId, pv.epochDocId, pv.className, pv.valueKind);
    if isempty(pv.epochDocId) || ~isKey(recByInstrEpoch, rk) ...
            || ~isKey(emittedNewIds, recByInstrEpoch(rk))
        report.pyraview_kept_no_recording_observation = ...
            report.pyraview_kept_no_recording_observation + 1;
        continue;
    end
    recId = recByInstrEpoch(rk);
    % [pyraview leftovers, schema form] (Jess Haley, 2026-10-21; did-schema
    % V_eta_recording_observation_plan.md): "the retired pyraview observation's
    % data type goes on the recording observation's value (value.data_type,
    % which covers its sampled_body levels; a sampled_body never repeats it),
    % and a time anchor that does not equal the epoch becomes the level body's
    % time key (start offset) and is counted. No new body fields."
    %
    % THE DATA TYPE. One recording observation may receive the levels of
    % several pyraviews (one per filter band); its one value.data_type must
    % cover them all, so a pyraview whose type differs from one already placed
    % there is kept as it was, and counted -- never overwritten.
    [dt, sdt] = valueDataType(bodies{pv.obsIdx});
    if ~isempty(dt) && isKey(recDataType, recId) ...
            && ~isequal(recDataType(recId), {dt, sdt})
        report.pyraview_kept_data_type_conflict = report.pyraview_kept_data_type_conflict + 1;
        report.pyraview_kept_no_recording_observation = ...
            report.pyraview_kept_no_recording_observation + 1;
        continue;
    end
    % THE ANCHOR. +migrators_j/pyraview anchors on the epoch with the v1
    % epochclocktimes: clock, start t0, duration t1-t0 -- clock READINGS, the
    % convention epochMint's own extent references use. NDI's writer
    % (+ndi/+gui/+app/+pyraview/makePyraviewDoc.m) takes t0/t1 from the epoch
    % table and writes nativeStartTime = decimationStartTimes = t0, so each
    % level's time key origin is ALREADY that start on that clock. So:
    %   equal to the epoch (same clock, start, duration as one of the epoch's
    %     own extent references)        -> dropped, counted;
    %   not equal, or the epoch states no extent on that clock (not
    %     comparable)                    -> the start lives in the level's time
    %     key: every level origin must equal the anchor's start, which is then
    %     the start offset the key carries; counted;
    %   a level origin that differs from that start -> two facts disagree and
    %     neither is picked: kept as it was, counted.
    [anchorState, startSec] = anchorAgainstEpoch(bodies, idxByIdAll, pv);
    if ~strcmp(anchorState, 'equal')
        allAt = true;
        for j = 1:numel(pv.levelIdx)
            o = timeKeyOrigin(bodies{pv.levelIdx(j)});
            if isempty(o) || isempty(startSec) || abs(o - startSec) > 1e-9 * max(1, abs(startSec))
                allAt = false;
            end
        end
        if ~allAt
            report.pyraview_kept_start_conflict = report.pyraview_kept_start_conflict + 1;
            report.pyraview_kept_no_recording_observation = ...
                report.pyraview_kept_no_recording_observation + 1;
            continue;
        end
    end
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
    pvFold(pvKeys{i}) = struct('recId', recId, 'dt', dt, 'sdt', sdt, 'anchor', anchorState);
    if ~isempty(dt); recDataType(recId) = {dt, sdt}; end
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
dtByRec = containers.Map('KeyType', 'char', 'ValueType', 'any');
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
    f = pvFold(pvIds{c});
    switch f.anchor
        case 'equal';  report.pyraview_anchor_equal_epoch_dropped = report.pyraview_anchor_equal_epoch_dropped + 1;
        case 'differs'; report.pyraview_anchor_to_time_key = report.pyraview_anchor_to_time_key + 1;
        otherwise; report.pyraview_anchor_not_comparable_to_time_key = ...
                report.pyraview_anchor_not_comparable_to_time_key + 1;
    end
    if ~isempty(f.dt); dtByRec(f.recId) = {f.dt, f.sdt}; end
end
% the data type lands on each recording observation whose pyraview retired
recIdsDt = dtByRec.keys;
for c = 1:numel(recIdsDt)
    for m = 1:numel(appended)
        a = appended{m};
        if isa(a, 'did2.document'); aid = char(a.get('base.id')); else; aid = char(a.base.id); end
        if ~strcmp(aid, recIdsDt{c}); continue; end
        pair = dtByRec(recIdsDt{c});
        st = a;
        if isa(st, 'did2.document'); st = st.toStruct(); end
        st.value.data_type = pair{1};
        if ~isempty(pair{2}); st.value.source_data_type = pair{2}; end
        res = did2.convert.v1_to_v2({st}, ...
            'Validate',      options.Validate, ...
            'SchemaCache',   options.SchemaCache, ...
            'TargetVersion', options.TargetVersion);
        if isempty(res.quarantine) && isscalar(res.migrated)
            appended{m} = res.migrated{1};
            report.pyraview_data_type_moved = report.pyraview_data_type_moved + 1;
        else
            report.pyraview_repoint_quarantined = report.pyraview_repoint_quarantined + 1;
        end
        break;
    end
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

% ---- [sorter input]: the sorted electrode's recording observations ------
sorterReplace = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(sorterIdx)
    sb = bodies{sorterIdx(i)};
    el = depValueOf(sb, 'entity_id');
    if isempty(el) || ~isKey(recIdsByInstr, el)
        report.sorter_input_fallback_entity = report.sorter_input_fallback_entity + 1;
        continue;
    end
    ins = recIdsByInstr(el);
    for m = 1:numel(ins)
        sb = addEdge(sb, 'input_id', ins{m});
    end
    res = did2.convert.v1_to_v2({sb}, ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    if ~isempty(res.quarantine) || ~isscalar(res.migrated)
        % kept as it was (the electrode fallback), and counted
        report.sorter_link_quarantined = report.sorter_link_quarantined + 1;
        report.sorter_input_fallback_entity = report.sorter_input_fallback_entity + 1;
        continue;
    end
    sorterReplace(docIds{sorterIdx(i)}) = res.migrated{1};
    report.sorter_inputs_linked = report.sorter_inputs_linked + 1;
    report.sorter_input_edges = report.sorter_input_edges + numel(ins);
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
    if ~isempty(id) && isKey(acqEpochRetire, id) && strcmp(classOf{k}, 'acquisition_epoch')
        continue;   % dissolved: its observation (same id) is in `appended`
    end
    if ~isempty(id) && isKey(levelReplace, id)
        kept{end+1} = levelReplace(id); %#ok<AGROW>
        continue;
    end
    if ~isempty(id) && isKey(sorterReplace, id)
        kept{end+1} = sorterReplace(id); %#ok<AGROW>
        continue;
    end
    if ~isempty(id) && isKey(metaReplace, id)
        kept{end+1} = metaReplace(id); %#ok<AGROW>
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
% A recording row -> an observation of the specimen (did-schema #88: a
% direction + a value kind), the probe as instrument (T7), the rig + channels
% through acquisition_channels_id (#73 item 56). Its value is the epoch's files:
% `data_body` true (2026-10-21, native V2 shape; mkEpochFileBodies builds them).
if nargin < 7; acId = ''; end
% did-schema #88: the direction class plus ONE value-kind mixin
obs = did2.build.statement(entry.class, char(subjectId), ...
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
% acquisition_channels.channels.type is bound REQUIRED to the ten channel
% types (did-schema #88, Jess Haley 2026-10-22 [channel types]; ai | ao | di |
% do before). did2.convert.channelType gives a node to exactly those, so a
% type is bindable when it has a node: compared BY NODE ([vocabulary nodes]
% L2), never by label.
tf = true;
for i = 1:numel(channels)
    if isempty(char(channels(i).type.node))
        tf = false; return;
    end
end
end

function n = derivedReadModes(channels)
% how many channel groups name one of NDI's eight derived read modes, which
% are not channel types ([channel types])
n = 0;
for i = 1:numel(channels)
    [~, kind] = did2.convert.channelType(char(channels(i).type.name));
    if isempty(char(channels(i).type.node)) && strcmp(kind, 'derived')
        n = n + 1;
    end
end
end

function k = channelsKey(sessionId, acqSystemId, channels)
parts = {char(sessionId), char(acqSystemId)};
for i = 1:numel(channels)
    t = channels(i).type;
    key = char(t.node);
    if isempty(key); key = char(t.name); end
    parts{end+1} = [key sprintf('%d,', channels(i).numbers)]; %#ok<AGROW>
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

function k = obs30TripleKey(subjectId, instrumentId, className, valueKind)
%OBS30TRIPLEKEY The (subject, instrument, class, value kind) key a probemap
%   observation and the #30 observation it supersedes must share (did-schema
%   #88: the class is the direction, the value kind its mixin). NUL-joined so
%   no component value can bleed into the next (ids and class names never
%   contain NUL).
k = [char(subjectId), char(0), char(instrumentId), char(0), char(className), ...
    char(0), char(valueKind)];
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
    % the v1 prefix -> its channel type term (Jess Haley 2026-10-22 [channel
    % types]); a derived read mode or an unknown prefix stays a bare label,
    % which channelsBindable refuses and the caller counts
    channels(end+1) = struct('type', did2.convert.channelType(tok{1}), ...
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
%   an observation of intensity with disposition 'recording', as in jRecordingModality
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
    entries = mkEntry('voltage', 'voltage');
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
% camera frame to an observation of `intensity` (jRecordingModality, row for row), and
% with the frames in the epoch's file bodies (`data_body` true) no value cell is
% needed, so there is nothing to leave blank.
if any(strcmp(key, {'wide-field-imaging', 'two-photon-imaging', ...
        'one-photon-imaging', 'brightfield-imaging'}))
    entries = mkEntry('intensity', 'intensity');
    disposition = 'recording';
    return;
end

switch key
    case {'patch-vm', 'patch-attached', 'sharp-vm'}
        entries = mkEntry('voltage', 'voltage');
    case {'patch-i', 'sharp-i', 'sharp-im'}
        entries = mkEntry('current', 'current');
    case {'patch', 'sharp'}
        entries = [mkEntry('voltage', 'voltage'), ...
                   mkEntry('current', 'current')];
    case 'spikes'
        entries = mkEntry('time', 'spike');
    case {'ecg', 'eeg'}
        entries = mkEntry('voltage', 'voltage');
    case 'accelerometer'
        entries = mkEntry('acceleration', 'acceleration');
    case 'thermometer'
        entries = mkEntry('temperature', 'temperature');
    otherwise
        return;   % 'lick-spout', 'reward-well', 'ppg', anything new -> unresolved
end
disposition = 'recording';
end

function e = emptyEntries()
e = struct('class', {}, 'mixin', {}, 'variable', {});
end

function e = mkEntry(mixin, variable)
% did-schema #88: an `observation` (the direction) listing ONE value-kind mixin
e = struct('class', 'observation', 'mixin', mixin, 'variable', variable);
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

function t = elementTypeOfAssertion(b)
% The value of +migrators_j/element.m's `element type` term assertion (the v1
% element.type, e.g. 'spikes'), lower-cased; '' for any other document.
t = '';
if ~isstruct(b) || ~isfield(b, 'statement') || ~isstruct(b.statement) ...
        || ~isfield(b.statement, 'variable'); return; end
v = b.statement.variable;
if ~(isstruct(v) && isfield(v, 'name') && strcmp(char(v.name), 'element type')); return; end
fn = fieldnames(b);
for i = 1:numel(fn)
    x = b.(fn{i});
    if isstruct(x) && isscalar(x) && isfield(x, 'value') && isstruct(x.value) ...
            && isscalar(x.value) && isfield(x.value, 'name') && ~isempty(x.value.name)
        t = lower(strtrim(char(x.value.name)));
        return;
    end
end
end

function kind = derivedSeriesKind(elementType)
%DERIVEDSERIESKIND What a derived element's per-epoch series (its v1
%   element_epoch .vhsb) becomes, by the element's v1 `type` -- THE ONE TABLE
%   (F1 AMENDMENT 1: key on type, never assume spikes). [] when no row is
%   decided: that element_epoch is kept as acquisition_epoch and counted by
%   type (acquisition_epoch_kept_types). Each row names its direction class,
%   whether the statements are about the ELEMENT (spikes: the neuron) or about
%   its `derived_from` parent with the element as instrument (JH: the worm),
%   and one entry per statement, the first keeping the epoch's id.
%     spikes    observation + time, GO:0001508 "action potential" (Jess Haley,
%               2026-10-21 [spike train variable]; [spike train leaf])
%     position  calculation + position, PATO:0000140 "position", method video
%               tracking (interpolation method linear, maximum gap filled 10
%               s), a pixel coordinate system
%     distance  calculation + length, EMPTY:0000384 "signed distance to region
%               boundary" (condition Location = bacterial patch; method
%               distance transform), and calculation + item, EMPTY:0000297
%               "nearest bacterial patch" (item_id the patches); input: the
%               position calculation
%   The JH rows: Decided by Jess Haley, 2026-10-22 [JH position and distance],
%   "the shapes the Haley V2 import already writes (trackDocuments.m)"; the
%   terms, methods and parameters are trackDocuments' own.
kind = [];
blank = struct('variable', [], 'valueKind', '', 'method', [], 'methodParameters', [], ...
    'conditions', [], 'inputsPosition', false, 'counter', '');
switch lower(strtrim(char(elementType)))
    case 'spikes'
        st = blank;
        st.variable = SPIKE_TRAIN_VARIABLE(); st.valueKind = 'time';
        st.counter = 'spike_trains_emitted';
        kind = struct('className', 'observation', 'aboutElement', true, 'statements', st);
    case 'position'
        st = blank;
        st.variable = term('PATO:0000140', 'position'); st.valueKind = 'position';
        st.method = term('EMPTY:0000301', 'video tracking');
        st.methodParameters = did2.build.list( ...
            did2.build.parameter(term('EMPTY:0000305', 'interpolation method'), ...
                'Term', term('EMPTY:0000306', 'linear interpolation')), ...
            did2.build.parameter(term('EMPTY:0000307', 'maximum gap filled'), ...
                'Value', 10, 'Unit', term('om:second-Time', 'second')));
        st.counter = 'position_calculations_emitted';
        kind = struct('className', 'calculation', 'aboutElement', false, 'statements', st);
    case 'distance'
        d = blank;
        d.variable = term('EMPTY:0000384', 'signed distance to region boundary');
        d.valueKind = 'length';
        d.method = term('EMPTY:0000302', 'distance transform');
        d.conditions = did2.build.list(did2.build.condition(term('NCIT:C25341', 'Location'), ...
            'Term', term('EMPTY:0000325', 'bacterial patch')));
        d.inputsPosition = true;
        d.counter = 'distance_calculations_emitted';
        it = blank;
        it.variable = term('EMPTY:0000297', 'nearest bacterial patch');
        it.valueKind = 'item';
        it.inputsPosition = true;
        it.counter = 'nearest_patch_calculations_emitted';
        kind = struct('className', 'calculation', 'aboutElement', false, ...
            'statements', [d, it]);
end
end

function t = term(node, name)
t = struct('node', node, 'name', name);
end

function [clk, t0, t1] = epochLocalClock(b)
% The dev_local_time clock record of an acquisition_epoch (`clocks`: {name, t0,
% t1}); '' when there is none or it is malformed. Other clocks (JH's
% exp_global_time) are not offsets from the epoch; the epoch carries them as
% its own extents (did2.convert.epochMint, #60 option A).
clk = ''; t0 = []; t1 = [];
if ~isfield(b, 'acquisition_epoch') || ~isstruct(b.acquisition_epoch) ...
        || ~isfield(b.acquisition_epoch, 'clocks'); return; end
c = b.acquisition_epoch.clocks;
if isstruct(c); c = num2cell(c); end
if ~iscell(c); return; end
hit = {};
for i = 1:numel(c)
    e = c{i};
    if isstruct(e) && isscalar(e) && isfield(e, 'name') && strcmp(char(e.name), 'dev_local_time') ...
            && isfield(e, 't0') && isfield(e, 't1')
        hit{end+1} = e; %#ok<AGROW>
    end
end
if numel(hit) ~= 1; return; end
a = double(hit{1}.t0); z = double(hit{1}.t1);
if ~isscalar(a) || ~isscalar(z) || ~isfinite(a) || ~isfinite(z) || z < a; return; end
clk = 'dev_local_time'; t0 = a; t1 = z;
end

function k = stemKey(sessionId, wormId, elementLid, elementId)
% (session, worm, element name less its _position / _distance suffix and its
% ' (ref N)'): the key that pairs a worm body part's position and distance
lid = '';
if isKey(elementLid, elementId); lid = elementLid(elementId); end
if iscell(lid); if isempty(lid); lid = ''; else; lid = lid{1}; end; end
lid = char(lid);
if size(lid, 1) > 1; lid = lid(1, :); end
lid = regexprep(lid, '\s*\(ref [^)]*\)\s*$', '');
lid = regexprep(lid, '_(position|distance)$', '');
k = [char(sessionId) char(0) char(wormId) char(0) lid];
end

function ids = distanceEndpointIds(b, label)
% the document ids of a migrated distance_metadata's endpoint LABEL (v1
% ontologyStringValues_<label>, comma-separated, in integerIDs order)
ids = {};
if ~isfield(b, 'distance_metadata') || ~isstruct(b.distance_metadata) ...
        || ~isfield(b.distance_metadata, 'endpoints'); return; end
ep = b.distance_metadata.endpoints;
if isstruct(ep); ep = num2cell(ep); end
for i = 1:numel(ep)
    e = ep{i};
    if ~isstruct(e) || ~isfield(e, 'label') || ~strcmp(char(e.label), label) ...
            || ~isfield(e, 'string_ids'); continue; end
    % the migrated form may be a comma-joined char, a cellstr or a string
    % array (one id each) -- read every shape rather than assume one
    v = e.string_ids;
    if isstring(v); v = cellstr(v); end
    if ischar(v); v = cellstr(v); end
    if ~iscell(v); return; end
    parts = {};
    for j = 1:numel(v)
        if ~(ischar(v{j}) || isstring(v{j})); continue; end
        q = strtrim(strsplit(char(v{j}), ','));
        parts = [parts, q]; %#ok<AGROW>
    end
    ids = parts(~cellfun(@isempty, parts));
    return;
end
end

function cs = mkPixelCoordinateSystem(epochDocId, sid, datestamp)
% trackDocuments' pixel grid (ndi.setup.conv.haley.geometryDocuments):
% reference point the image upper-left corner, x toward image right, y toward
% image down -- with NO spacing, because v1 records pixels and no scale
% (`spacing` absent = uncalibrated, coordinate_system.json); ON the epoch.
ax = @(a, an, d, dn) struct('axis', term(a, an), 'positive_direction', term(d, dn));
cs = did2.build.document('coordinate_system', struct( ...
    'reference_point', term('EMPTY:0000310', 'image upper-left corner'), ...
    'axes', did2.build.list(ax('STATO:0000006', 'x-axis', 'EMPTY:0000311', 'image right'), ...
        ax('STATO:0000008', 'y-axis', 'EMPTY:0000312', 'image down'))), ...
    'Edges', struct('referent_id', char(epochDocId)), ...
    'SessionId', char(sid), 'CreationTimestamp', char(datestamp), 'Validate', false);
end

function s = tallyName(s, name)
% "name=count; ..." -- a by-name tally kept as text in a scalar report field
parts = regexp(s, '([^=;\s]+)=(\d+)', 'tokens');
names = cellfun(@(p) p{1}, parts, 'UniformOutput', false);
counts = cellfun(@(p) str2double(p{2}), parts);
hit = find(strcmp(names, name), 1);
if isempty(hit)
    names{end+1} = name; counts(end+1) = 1;
else
    counts(hit) = counts(hit) + 1;
end
items = cell(1, numel(names));
for i = 1:numel(names); items{i} = sprintf('%s=%d', names{i}, counts(i)); end
s = strjoin(items, '; ');
end

function s = firstNonEmptyChar(a, b)
s = char(a);
if isempty(s); s = char(b); end
end

function k = recKey(instrumentId, epochDocId, className, valueKind)
k = [char(instrumentId), char(0), char(epochDocId), char(0), char(className), ...
    char(0), char(valueKind)];
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

function [replace, quarantine, report] = mkMetadataArchiveBodies(specs, ...
        emittedIds, bodies, paramReadersByNavId, metaArchiveIdxByKey, options, report)
%MKMETADATAARCHIVEBODIES #73 review item 61: one opaque_body per v1
%   daqmetadatareader_epochdata_ingested whose epoch has a surviving stimulator
%   manipulation, owned by it (owner_id repeats when the epoch has several,
%   T15). The body keeps the archive's base.id, so it REPLACES the v1 document
%   (REPLACE: archive id -> validated body). Its one file, `data.bin`, is
%   carried as attached (locations verbatim) as body_data_0. Format:
%   EMPTY:0000367 "NDI binary format" (Jess Haley, 2026-10-22 [NDI binary
%   format]), compression gzip (NDI metadatareader.ingest_epochfiles
%   attaches [metadatafile '.nbf.tgz']). No data_type: Jess Haley,
%   2026-10-21 [data_type only for plain arrays].
replace = containers.Map('KeyType', 'char', 'ValueType', 'any');
quarantine = [];
ownersByIdx = containers.Map('KeyType', 'double', 'ValueType', 'any');
for s = 1:numel(specs)
    sp = specs(s);
    owners = {};
    for i = 1:numel(sp.manipIds)
        if isKey(emittedIds, sp.manipIds{i}); owners{end+1} = sp.manipIds{i}; end %#ok<AGROW>
    end
    if isempty(owners) || isempty(sp.navId) || ~isKey(paramReadersByNavId, sp.navId)
        continue;
    end
    prIds = paramReadersByNavId(sp.navId);
    for r = 1:numel(prIds)
        mk = archiveKey(sp.sid, prIds{r}, sp.epochString);
        if ~isKey(metaArchiveIdxByKey, mk); continue; end
        idx = metaArchiveIdxByKey(mk);
        prev = {};
        if isKey(ownersByIdx, idx); prev = ownersByIdx(idx); end
        ownersByIdx(idx) = unique([prev, owners], 'stable');
    end
end
idxs = ownersByIdx.keys;
pending = {};
for i = 1:numel(idxs)
    idx = idxs{i};
    ab = bodies{idx};
    infos = fileInfos(ab);
    fi = [];
    for j = 1:numel(infos)
        if isstruct(infos{j}) && isfield(infos{j}, 'name') ...
                && strcmp(char(infos{j}.name), 'data.bin')
            fi = infos{j};
            break;
        end
    end
    if isempty(fi)
        report.metadata_archives_kept_no_bytes = report.metadata_archives_kept_no_bytes + 1;
        continue;
    end
    loc = struct();
    if isfield(fi, 'locations'); loc = fi.locations; end
    % Decided by Jess Haley, 2026-10-22 [NDI binary format]: the archive is
    % NDI's own `.nbf.tgz` (NDI-compress write_ndibinary: a gzip-compressed tar
    % of an .nbh header and an .nbf data file), so it is compressed gzip
    % whatever its stored name says.
    flds = struct('filename', 'data.bin', 'compression', 'gzip');
    owners = ownersByIdx(idx);
    sid = did2.schema.cache.sessionIdOf(ab);
    ds = baseField(ab, 'creation_timestamp');
    if isempty(ds); ds = baseField(ab, 'datestamp'); end
    if isempty(ds); ds = '2024-01-01T00:00:00.000Z'; end
    try
        body = did2.build.opaqueBody(owners, ndiBinaryFormat(), ...
            'Id', char(baseField(ab, 'id')), 'Fields', flds, ...
            'Description', sprintf(['The parsed stimulus parameters of epoch %s, ' ...
                'as NDI''s metadata reader stored them (v1 ' ...
                'daqmetadatareader_epochdata_ingested data.bin, carried as attached).'], ...
                archiveEpochOf(ab)), ...
            'SessionId', char(sid), 'CreationTimestamp', char(ds), 'Validate', false);
    catch err
        report.body_build_refused = report.body_build_refused + 1;
        if isempty(report.body_build_first_error)
            report.body_build_first_error = sprintf('%s: %s', err.identifier, err.message);
        end
        continue;
    end
    body.files.file_info = struct('name', 'body_data_0', 'locations', {loc});
    pending{end+1} = body; %#ok<AGROW>
    report.metadata_archive_owner_links = report.metadata_archive_owner_links + numel(owners);
end
if ~isempty(pending)
    res = did2.convert.v1_to_v2(pending, ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    quarantine = res.quarantine;
    report.metadata_archives_quarantined = numel(res.quarantine);
    for i = 1:numel(res.migrated)
        try
            bid = char(res.migrated{i}.get('base.id'));
        catch
            continue;
        end
        replace(bid) = res.migrated{i};
    end
end
report.metadata_archives_to_body = double(replace.Count);
report.metadata_archives_kept_no_owner = report.metadata_archives_inspected ...
    - double(ownersByIdx.Count);
end

function s = firstLocation(loc)
% the first stored location string of a file_info `locations` value, '' if none
s = '';
if iscell(loc) && ~isempty(loc); loc = loc{1}; end
if isstruct(loc) && ~isempty(loc) && isfield(loc, 'location')
    s = char(loc(1).location);
end
end

function [out, quarantine] = mkSpikeBodies(seriesGroups, emittedIds, bodies, sessionIds, options)
% one opaque_body per dissolved element_epoch: its epoch_binary_data.vhsb,
% locations VERBATIM (the bytes v1 attached), owned by EVERY statement the
% epoch became (a `distance` epoch's two calculations share it; owner_id
% repeats, T15) -- built only when all of them survived validation
out = {};
quarantine = [];
pending = {};
ks = seriesGroups.keys;
for i = 1:numel(ks)
    k = ks{i};
    g = seriesGroups(k);
    if isempty(g) || ~all(cellfun(@(x) isKey(emittedIds, x), g)); continue; end
    b = bodies{k};
    fi = vhsbFileInfo(b);
    datestamp = baseField(b, 'creation_timestamp');
    if isempty(datestamp); datestamp = baseField(b, 'datestamp'); end
    if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
    body = did2.build.opaqueBody(g, binaryFormat(), ...
        'Fields', struct('filename', 'epoch_binary_data.vhsb'), ...
        'Description', sprintf(['The (timepoints, datapoints) series of epoch %s: ' ...
            'the v1 element_epoch file epoch_binary_data.vhsb, carried as attached.'], ...
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

function owners = pyraviewOwnerIndex(bodies, classOf, kindOf, docIds, sampledIdx)
%PYRAVIEWOWNERINDEX The pyraview observations in the batch, keyed by id: an
%   observation with `data_body` true whose sampled_bodies epochMint folded from
%   a v1 pyraview -- recognised as a recording-kind observation that names NO
%   instrument (the element itself is its entity, +migrators_j/pyraview.m) and
%   owns sampled_bodies. Each entry: entityId, epochDocId (its anchor's
%   referent when that is an epoch), className (the direction), valueKind,
%   levelIdx (its bodies). A recording-kind observation is an `observation`
%   whose value kind is voltage or current; did2.convert.statementKind also
%   reads a pre-port document's joined class name that way.
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
    vk = kindOf{ok};
    if ~strcmp(cn, 'observation') || ~any(strcmp(vk, {'voltage', 'current'})); continue; end
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
    anchorIdx = 0;
    if ~isempty(aid) && isKey(idxById, aid); anchorIdx = idxById(aid); end
    owners(oid) = struct('entityId', depValueOf(ob, 'entity_id'), ...
        'epochDocId', epochDocId, 'className', cn, 'valueKind', vk, ...
        'levelIdx', sampledIdx(i), 'obsIdx', ok, 'anchorIdx', anchorIdx);
end
end

function [dt, sdt] = valueDataType(b)
% the statement's value.data_type / source_data_type, '' when absent
dt = ''; sdt = '';
if isstruct(b) && isfield(b, 'value') && isstruct(b.value)
    if isfield(b.value, 'data_type'); dt = char(b.value.data_type); end
    if isfield(b.value, 'source_data_type'); sdt = char(b.value.source_data_type); end
end
end

function [state, startSec] = anchorAgainstEpoch(bodies, idxById, pv)
%ANCHORAGAINSTEPOCH 'equal' when the pyraview's anchor states the same clock,
%   start and duration as one of its epoch's own extent references (epochMint:
%   the epoch's `time_reference_id` edges); 'differs' when the epoch states an
%   extent on that clock and it is not the same; 'not_comparable' when the epoch
%   states none on that clock (a third state, never read as equal). STARTSEC is
%   the anchor's start in seconds ([] when it has none).
state = 'not_comparable';
startSec = [];
if pv.anchorIdx == 0; return; end
[clk, startSec, dur] = refValue(bodies{pv.anchorIdx});
if isempty(startSec)
    % no metric offset: "during the epoch" is the epoch itself
    state = 'equal';
    return;
end
if ~isKey(idxById, pv.epochDocId); return; end
eb = bodies{idxById(pv.epochDocId)};
refIds = depValuesOf(eb, 'time_reference_id');
for r = 1:numel(refIds)
    if ~isKey(idxById, refIds{r}); continue; end
    [c2, s2, d2] = refValue(bodies{idxById(refIds{r})});
    if isempty(s2) || ~strcmpi(c2, clk); continue; end
    same = abs(s2 - startSec) <= 1e-9 * max(1, abs(startSec));
    if ~isempty(dur) || ~isempty(d2)
        same = same && ~isempty(dur) && ~isempty(d2) ...
            && abs(d2 - dur) <= 1e-9 * max(1, abs(dur));
    end
    if same; state = 'equal'; else; state = 'differs'; end
    return;
end
end

function [clk, startSec, dur] = refValue(b)
% a relative_time_reference's clock name, start and duration (seconds)
clk = ''; startSec = []; dur = [];
if ~isstruct(b) || ~isfield(b, 'relative_time_reference'); return; end
v = b.relative_time_reference;
if ~isstruct(v) || ~isfield(v, 'value') || ~isstruct(v.value); return; end
v = v.value;
if isfield(v, 'clock')
    c = v.clock;
    if isstruct(c) && isfield(c, 'name'); c = c.name; end
    if ischar(c) || isstring(c); clk = char(c); end
end
if isfield(v, 'start') && isstruct(v.start) && isfield(v.start, 'seconds') ...
        && ~isempty(v.start.seconds)
    startSec = double(v.start.seconds);
end
if isfield(v, 'duration') && isstruct(v.duration) && isfield(v.duration, 'seconds') ...
        && ~isempty(v.duration.seconds)
    dur = double(v.duration.seconds);
end
end

function o = timeKeyOrigin(b)
% the origin (seconds) of a body's time axis, [] when it has none.
% did-schema data_body AMENDMENT 6 (`keys` until 2026-10-22): found as the
% COVARIATE WHOSE VARIABLE is 'time' and that carries `origin` (pyraview's
% regular time covariate, along its time dimension); the dimension itself is
% not consulted, since the origin lives only on the covariate.
o = [];
if ~isstruct(b) || ~isfield(b, 'data') || ~isstruct(b.data) || ~isfield(b.data, 'covariates'); return; end
cs = b.data.covariates;
if iscell(cs); cs = [cs{:}]; end
for k = 1:numel(cs)
    if ~isfield(cs(k), 'variable'); continue; end
    v = cs(k).variable;
    nm = '';
    if isstruct(v) && isfield(v, 'name'); nm = char(v.name); end
    if strcmpi(nm, 'time') && isfield(cs(k), 'origin') && isstruct(cs(k).origin) ...
            && isfield(cs(k).origin, 'value') && ~isempty(cs(k).origin.value)
        o = double(cs(k).origin.value);
        return;
    end
end
end

function v = depValuesOf(b, name)
% every target of the edge NAME (an edge declared `multiple` repeats)
v = {};
if ~isstruct(b) || ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
if iscell(deps); deps = [deps{:}]; end
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name); continue; end
    x = '';
    if isfield(d, 'value') && ~isempty(d.value); x = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); x = char(d.document_id); end
    if ~isempty(x); v{end+1} = x; end %#ok<AGROW>
end
end

function tf = isSorterVariable(b)
% the spike-sorter output's variable, 'spike cluster assignment'
tf = false;
if ~isstruct(b) || ~isfield(b, 'statement') || ~isstruct(b.statement) ...
        || ~isfield(b.statement, 'variable'); return; end
v = b.statement.variable;
if isstruct(v) && isfield(v, 'name')
    tf = strcmpi(strtrim(char(v.name)), 'spike cluster assignment');
end
end

function b = addEdge(b, name, id)
% B with one more NAME edge to ID, spelled as B's own edges are spelled
deps = b.depends_on;
if iscell(deps); deps = [deps{:}]; end
d = deps(1);
fn = fieldnames(d);
for f = 1:numel(fn); d.(fn{f}) = ''; end
d.name = name;
if isfield(d, 'value'); d.value = char(id); end
if isfield(d, 'document_id'); d.document_id = char(id); end
b.depends_on = [deps(:)', d];
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

function f = ndiBinaryFormat()
%NDIBINARYFORMAT EMPTY:0000367 "NDI binary format" (Jess Haley, 2026-10-22
%   [NDI binary format]; minted in empty-ontology draft PR #23, registered in
%   did-schema dad8567).
f = struct('node', 'EMPTY:0000367', 'name', 'NDI binary format');
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

function r = relationOf(b)
% the relation term, {node, name} (a bare name from an older writer as {'', name})
r = struct('node', '', 'name', '');
if ~isfield(b, 'directed_relation') || ~isstruct(b.directed_relation) ...
        || ~isfield(b.directed_relation, 'relation')
    return;
end
v = b.directed_relation.relation;
if isstruct(v) && isscalar(v)
    if isfield(v, 'node'); r.node = char(v.node); end
    if isfield(v, 'name'); r.name = char(v.name); end
elseif ischar(v) || isstring(v)
    r.name = char(v);
end
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
% ('epoch', 'organism', ...); a statement as its DIRECTION ('observation', ...),
% its value kind read separately by did2.convert.statementKind (which also
% reads a pre-port joined class name as direction + kind).
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
if strcmp(cn, 'entity') && isfield(b, 'entity') && isstruct(b.entity) ...
        && isfield(b.entity, 'type')
    % by node: the stored name is the ontology label ("recording epoch",
    % "Session"; [vocabulary nodes] L1, L2), the handle is 'epoch', 'session'
    t = did2.build.vocabularyHandle('entity_type', b.entity.type);
    if ~isempty(t); cn = t; end
elseif ~isempty(cn)
    cn = did2.convert.statementKind(b);
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
