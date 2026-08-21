function [result, report] = resolveEpochProbemap(result, options)
%RESOLVEEPOCHPROBEMAP Decompose an ingested epoch's serialized `epochprobemap`
%   into one epoch-scoped `<modality>_observation` per probe row, retiring #30's
%   coarse session-scoped observation for that same probe.
%
%   INCREMENT 1 of the epochprobemap decomposition (DID-schema V_eta_OPEN_WORK.md
%   row #66). This is the OBSERVATION half only. It DELIBERATELY does NOT rename
%   `epochfiles_ingested` -> `ingestion_manifest`, does NOT drop the probemap, and
%   does NOT touch the device half (`acquisition_system_id`, `channels`) -- those
%   are increments 2/3 and need a schema change this build may not make (Operating
%   Rule 1). `+migrators_j/epochfiles_ingested.m` stays a guarded passthrough.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: epochfiles_ingested
%   BATCH-PASS-EMITS: epochfiles_ingested -> document: voltage_observation, current_observation, time_observation, acceleration_observation, temperature_observation, relative_reference
%
%   `image_observation` is DELIBERATELY NOT in that list. Imaging types are a
%   recognised modality (jRecordingModality maps them to image_observation, and
%   localModality mirrors that), but they CANNOT be emitted VALIDLY in increment
%   1 -- see the IMAGE IS DEFERRED note on localModality. They are counted
%   (rows_image_deferred) and left to the second pass, never emitted blank.
%
%   `epochfiles_ingested` is NOT consumed in the sense of being rewritten -- it
%   is READ for its `epoch_id` and `epochprobemap`, and left exactly as it is
%   (increment 3 renames it). The emissions are the per-probe observations and,
%   one per epoch, the shared 'during' anchor they point at.
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
    'instrument_resolved',            0, ...
    'instrument_omitted',             0, ...
    'epoch_anchors_minted',           0, ...
    'session30_observations_retired', 0, ...
    'session30_anchors_removed',      0, ...
    'retire_skipped_ambiguous',       0, ...
    'retire_no_match',                0, ...
    'fold_quarantined',               0, ...
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
        sessionIds{k} = baseField(b, 'session_id');
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
% (d) #30 observations grouped by their instrument_id value. jRecordingObservation
%     stamps base.name = 'migrated_recording_observation' at exactly one site, so
%     the marker needs no modality-class list. A cell of {index} per instrument.
obs30ByInstrument = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:n
    if isempty(bodies{k}); continue; end
    b = bodies{k};
    switch classOf{k}
        case 'epoch'
            lid = '';
            if isfield(b, 'epoch') && isstruct(b.epoch)
                lid = charField(b.epoch, {'local_identifier'});
            end
            if ~isempty(lid) && ~isempty(docIds{k})
                key = epochKey(sessionIds{k}, lid);
                if ~isKey(epochIdByKey, key); epochIdByKey(key) = docIds{k}; end
            end
        case 'subject'
            lid = '';
            if isfield(b, 'subject') && isstruct(b.subject)
                lid = charField(b.subject, {'local_identifier'});
            end
            if ~isempty(lid) && ~isempty(docIds{k})
                key = epochKey(sessionIds{k}, lid);
                if ~isKey(subjectIdByKey, key); subjectIdByKey(key) = docIds{k}; end
            end
    end
    if isRecording30Observation(b)
        instr = depValueOf(b, 'instrument_id');
        if ~isempty(instr)
            if isKey(obs30ByInstrument, instr)
                obs30ByInstrument(instr) = [obs30ByInstrument(instr), {k}];
            else
                obs30ByInstrument(instr) = {k};
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

for k = 1:n
    if ~strcmp(classOf{k}, 'epochfiles_ingested'); continue; end
    report.epochfiles_ingested_seen = report.epochfiles_ingested_seen + 1;
    b = bodies{k};
    sid = sessionIds{k};
    es = epochStringOf(b);
    if isempty(es) || ~isKey(epochIdByKey, epochKey(sid, es))
        report.refused_no_epoch = report.refused_no_epoch + 1;
        continue;
    end
    epochDocId = epochIdByKey(epochKey(sid, es));

    pm = probemapCharOf(b);
    if isempty(pm); continue; end     % no probemap text -> no rows to decompose
    rowsPM = parseProbemapRows(pm);
    if isempty(rowsPM); continue; end
    datestamp = baseField(b, 'datestamp');
    if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end

    for r = 1:numel(rowsPM)
        report.probe_rows_total = report.probe_rows_total + 1;
        row = rowsPM(r);

        % ---- SUBJECT (required) --------------------------------------------
        if isempty(row.subjectstring)
            report.rows_no_subjectstring = report.rows_no_subjectstring + 1;
            continue;
        end
        subjKey = epochKey(sid, row.subjectstring);
        if ~isKey(subjectIdByKey, subjKey)
            report.refused_no_subject = report.refused_no_subject + 1;
            continue;
        end
        subjectId = subjectIdByKey(subjKey);

        % ---- MODALITY ------------------------------------------------------
        [entries, disposition] = localModality(row.type);
        switch disposition
            case 'stimulator'
                report.rows_stimulator = report.rows_stimulator + 1;
                continue;
            case 'recording'
                % assemble below
            case 'image_deferred'
                % Recognised imaging modality, but not emittable in increment 1
                % (a blank image `value` cell is refused by #38; see
                % localModality). Counted and left to the second pass.
                report.rows_image_deferred = report.rows_image_deferred + 1;
                continue;
            otherwise    % 'unresolved' or anything unexpected
                report.rows_unresolved_modality = ...
                    report.rows_unresolved_modality + 1;
                continue;
        end

        % ---- INSTRUMENT (optional): the probe's own element-subject --------
        instrumentId = '';
        probeLocalId = probeLocalIdentifier(row.name, row.reference);
        probeKey = epochKey(sid, probeLocalId);
        if ~isempty(probeLocalId) && isKey(subjectIdByKey, probeKey)
            instrumentId = subjectIdByKey(probeKey);
        end

        % ---- the shared per-epoch 'during' anchor --------------------------
        if isKey(anchorByEpochId, epochDocId)
            anchorId = anchorByEpochId(epochDocId);
        else
            anchor = mkEpochAnchor(epochDocId, sid, datestamp);
            anchorId = anchor.base.id;
            anchorByEpochId(epochDocId) = anchorId;
            anchorBodyById(anchorId) = anchor;
            report.epoch_anchors_minted = report.epoch_anchors_minted + 1;
        end

        % ---- mint the observation(s) (patch/sharp yield two) ---------------
        mintedIdsThisRow = {};
        for e = 1:numel(entries)
            obs = mkObservation(entries(e), subjectId, instrumentId, anchorId, ...
                sid, datestamp);
            newBodies{end+1} = obs;                 %#ok<AGROW>
            newGroupAnchor{end+1} = anchorId;       %#ok<AGROW>
            mintedIdsThisRow{end+1} = obs.base.id;  %#ok<AGROW>
        end
        if isempty(instrumentId)
            report.instrument_omitted = report.instrument_omitted + numel(entries);
        else
            report.instrument_resolved = report.instrument_resolved + numel(entries);
        end

        % ---- REPLACE #30's coarse observation for this probe ---------------
        % Only when the probe resolved to an element-subject AND exactly one #30
        % observation names it. 0 -> nothing to retire; >1 -> a patch/sharp
        % element with two #30 observations, ambiguous, so KEEP them rather than
        % risk stranding one. The retirement is committed only after a
        % replacement survives validation (below).
        if ~isempty(instrumentId) && isKey(obs30ByInstrument, instrumentId)
            hits = obs30ByInstrument(instrumentId);
            if numel(hits) == 1
                obsIdx = hits{1};
                obs30Id = docIds{obsIdx};
                if ~isempty(obs30Id) && ~any(strcmp(obs30Id, retire30Ids))
                    retire30Ids{end+1} = obs30Id;                %#ok<AGROW>
                    retireReplacementIds(obs30Id) = mintedIdsThisRow;
                    anchorId30 = depValueOf(bodies{obsIdx}, 'time_reference_1');
                    if ~isempty(anchorId30)
                        retire30AnchorCand(anchorId30) = {obs30Id};
                    end
                end
            elseif numel(hits) > 1
                report.retire_skipped_ambiguous = ...
                    report.retire_skipped_ambiguous + 1;
            end
        elseif ~isempty(instrumentId)
            report.retire_no_match = report.retire_no_match + 1;
        end
    end
end

if isempty(newBodies)
    result.epoch_probemap_fold = report;
    return;
end

% --- validate the new bodies through the same door every other pass uses ---
% Observations + their epoch anchors go through together, so an observation's
% `time_reference_1` names a document present in the same batch. Cross-batch
% edges (subject_id, instrument_id) point OUTSIDE this rebuild set, exactly as
% resolveSessionAnchors' relative_to does -- v1_to_v2's per-batch validate does
% not resolve references (that is the corpus orphan gate), so this is fine.
anchorBodies = anchorBodyById.values;
rebuildIn = [newBodies, anchorBodies(:)'];
out = did2.convert.v1_to_v2(rebuildIn, ...
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
producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(out.migrated)
    try
        producedById(char(out.migrated{k}.get('base.id'))) = k;
    catch
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

emittedNewIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
appended = {};
for j = 1:numel(newBodies)
    id = newBodies{j}.base.id;
    aid = newGroupAnchor{j};
    if ~anchorAlive(aid); continue; end          % group withheld: anchor died
    if ~isKey(producedById, id); continue; end    % this observation quarantined
    appended{end+1} = out.migrated{producedById(id)}; %#ok<AGROW>
    report.observations_emitted = report.observations_emitted + 1;
    emittedNewIds(id) = true;
    anchorHasSurvivor(aid) = true;
end
% Anchors: emit only where a surviving observation references them.
for a = 1:numel(anchorKeys)
    aid = anchorKeys{a};
    if isKey(anchorHasSurvivor, aid) && anchorHasSurvivor(aid) ...
            && isKey(producedById, aid)
        appended{end+1} = out.migrated{producedById(aid)}; %#ok<AGROW>
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
        if ~strcmp(baseField(bodies{idx}, 'name'), 'migrated_session_anchor')
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
kept = {};
for k = 1:n
    id = docIds{k};
    if ~isempty(id) && (isKey(retireSet, id) || isKey(removeAnchorSet, id))
        continue;
    end
    kept{end+1} = docs{k}; %#ok<AGROW>
end
result.migrated = [kept, appended];
result.summary = recountSummary(result);
result.epoch_probemap_fold = report;
end

% ===================== builders ========================================

function obs = mkObservation(entry, subjectId, instrumentId, anchorId, ...
        sessionId, datestamp)
%MKOBSERVATION One <modality>_observation. Field-for-field the shape
%   +migrators_j/private/jRecordingObservation.m emits, base.name distinct
%   ('migrated_probemap_observation') so it is never mistaken for a #30 obs.
obs = struct();
obs.document_class = classBlock(entry.class, {'subject_observation', entry.mixin});
obs.depends_on = struct('name', 'subject_id', 'value', subjectId);
if ~isempty(instrumentId)
    obs.depends_on(end+1) = struct('name', 'instrument_id', 'value', instrumentId); % T7
end
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchorId);
obs.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_probemap_observation', 'datestamp', datestamp);
obs.subject_statement = struct( ...
    'variable', mkOntologyTerm('', entry.variable), ...
    'storage_mode', 'reference');
obs.subject_interaction = struct('method', mkOntologyTerm('', ''));
obs.subject_observation = struct();
obs = attachQuantityBlock(obs, entry.mixin);
end

function anchor = mkEpochAnchor(epochDocId, sessionId, datestamp)
%MKEPOCHANCHOR The shared per-epoch 'during' relative_reference. Minted as the
%   FINAL class (relative_reference 2.0.0 <- time_reference 4.0.0) because this
%   pass runs AFTER resolveSessionAnchors -- there is no later fold to resolve a
%   pass-1 handle, and `relative_to` is fillable here (the epoch document exists).
%   Mirrors the corpus-proven body resolveSessionAnchors builds at :546-561.
anchor = struct();
anchor.document_class = struct( ...
    'class_name',     'relative_reference', ...
    'class_version',  '2.0.0', ...
    'superclasses',   struct('class_name', 'time_reference', ...
                             'class_version', '4.0.0'), ...
    'schema_version', 'V_eta');
anchor.depends_on = struct('name', 'relative_to', 'value', epochDocId);
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_probemap_epoch_anchor', 'datestamp', datestamp);
anchor.relative_reference = struct('value', ...
    struct('relation', struct('node', 'time:intervalDuring', 'name', 'intervalDuring')));
end

function obs = attachQuantityBlock(obs, mixin)
%ATTACHQUANTITYBLOCK The data_type block, empty because the value is body-backed
%   (storage_mode 'reference'). Every mixin takes an empty struct because its
%   `value` is optional and so absent-is-valid. `image` is the exception --
%   `image.value` is mustBeNonEmpty, and a blank cell is refused by the #38
%   NonVacuousFields gate -- so imaging is DEFERRED upstream (localModality
%   returns 'image_deferred') and NEVER reaches this function. The `image` branch
%   below is therefore currently unreachable; it is kept, matching
%   jRecordingObservation's shape, so a second increment that can fill the cell
%   (from real raster metadata) has the landing pad ready. Reconstructed from
%   jRecordingObservation's own attachQuantityBlock.
if strcmp(mixin, 'image')
    obs.image = struct();
    obs.image.value = struct('pixels', [], 'dtype', '', ...
        'color_model', mkOntologyTerm('', ''));
    return;
end
obs.(mixin) = struct();
end

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function t = mkOntologyTerm(node, name)
%MKONTOLOGYTERM {node, name}. Reconstructed jOntologyTerm (unreachable private).
t = struct('node', char(node), 'name', char(name));
end

% ===================== the modality map ================================

function [entries, disposition] = localModality(elementType)
%LOCALMODALITY DUPLICATE of +migrators_j/private/jRecordingModality's type map,
%   reconstructed here because that private helper is unreachable from +convert.
%   Its rows are pinned against jRecordingModality's by
%   testResolveEpochProbemap.m so the two cannot drift. Covers the SAME rows;
%   `multichannel` is dropped (this pass mints no body, so there is no axis to
%   flag). The ONLY intentional divergence is DISPOSITION, not mapping: imaging
%   types map to image_observation exactly as jRecordingModality does, but this
%   pass returns disposition 'image_deferred' (see the IMAGE IS DEFERRED note
%   below) because it cannot emit a valid pure-reference image cell in increment
%   1. If jRecordingModality gains a row, add it here and update that test.
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
if any(strcmp(key, {'wide-field-imaging', 'two-photon-imaging', ...
        'one-photon-imaging', 'brightfield-imaging'}))
    entries = mkEntry('image_observation', 'image', 'image');
    disposition = 'image_deferred';
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

% ===================== small readers ===================================

function k = epochKey(sessionId, localIdentifier)
%EPOCHKEY The shared (session, string) key -- delegated so it cannot drift from
%   epochMint's mint key.
k = did2.convert.epochIndex.pairKey(char(sessionId), char(localIdentifier));
end

function tf = isRecording30Observation(body)
%ISRECORDING30OBSERVATION True for a #30 observation, by its assembler's stamp
%   (jRecordingObservation sets base.name = 'migrated_recording_observation').
tf = false;
if ~isstruct(body) || ~isfield(body, 'base') || ~isstruct(body.base) ...
        || ~isfield(body.base, 'name')
    return;
end
tf = strcmp(char(body.base.name), 'migrated_recording_observation');
end

function cn = classNameOf(b)
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
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
