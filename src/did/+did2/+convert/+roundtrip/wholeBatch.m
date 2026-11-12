function report = wholeBatch(v1Bodies, result)
%WHOLEBATCH Take a migrated batch's FINAL documents back to v1, source by
%   source, and compare each with the v1 document it came from.
%
%   REPORT = did2.convert.roundtrip.wholeBatch(V1BODIES, RESULT). V1BODIES is
%   what was handed to did2.convert.v1_to_v2 (a cell of structs or JSON text,
%   in the same order); RESULT is its result AFTER every batch pass has run on
%   it (epochs, baths, the file-reference fold, ...: the batch as it will be
%   stored). RESULT.source_outputs (written by v1_to_v2) names, for each source,
%   the base.id of every document it became.
%
%   WHY. Decided by Jess Haley, 2026-10-27 [whole-batch round trip] (did-schema
%   V_eta_go_forward_class_audit.md): "one test takes a migrated corpus's FINAL
%   V2 batch (after every batch pass: epochs, baths, the file-reference fold)
%   back to v1 and compares it with the original, alongside the per-class round
%   trips ([lossless means round trip]); it runs before the final corpus run".
%   And [every v1 id survives] (the same day): "each v1 document's id becomes
%   the id of the V2 document that most directly replaces it ... a whole-batch
%   id check".
%
%   HOW. For each source: its documents are looked up in the final batch by
%   the ids pass 1 gave them. When all are still there, they are handed --
%   as the batch passes left them -- to did2.convert.roundtrip.check, the
%   per-class inverse, with an index of the whole final batch
%   (private/batchContext) for an inverse that reads documents a batch pass
%   made (an ingested epoch's probe-map statements, a clock mapping's
%   per-system references). When one is gone (a batch pass replaced or folded
%   it), the source is counted CHANGED BY A BATCH PASS and not compared: that
%   pass has no inverse yet (Build pending: an inverse for each batch pass). A
%   class with no inverse is counted NO INVERSE. Nothing is guessed.
%
%   AN INVERSE FOR A BATCH PASS. A class listed in BATCH_PASS_INVERSES (below)
%   has an inverse that reads, from CTX, what a batch pass did to its
%   documents; such a source is compared on the documents of its that remain,
%   counted in sources_compared and also in sources_compared_after_batch_pass
%   (by class: compared_after_batch_pass_by_class). Its failures are counted
%   like any other. Today: `element`, whose `observes` relation
%   did2.convert.resolveEpochProbemap retires once a recording observation
%   carries the same pair (did2.convert.roundtrip.element reads it there).
%   Test code run 41322059537 counted element CHANGED BY A BATCH PASS in B
%   (143) and Dab (547). And `daqreader_mfdaq_epochdata_ingested`, the v1
%   ingested archive did2.convert.resolveEpochProbemap RETIRES once its files
%   and clocks have new owners ([segment length is the time chunk], Jess
%   Haley, 2026-10-29): NONE of its documents remains, so it is compared on
%   the documents that pass made of it, found here (LOCATED AFTER A BATCH
%   PASS: the `opaque_body` documents whose file_info holds a location uid of
%   the archive's, which resolveEpochProbemap carries verbatim), and
%   roundtrip.daqreader_mfdaq_epochdata_ingested reads the rest from CTX. Its
%   id is released ([a rebuilt document may lose its id]), so the rebuilt
%   document's base.id, which nothing could rebuild, is not counted against
%   it: it is in ids_released already. Test code run 43077600408 (DID-matlab
%   299fa0f2) counted it CHANGED BY A BATCH PASS in B (1,242) and Dab (2,846).
%
%   STORED AS ITS v1 SOURCE. A source pass 1 passed through unchanged is in
%   RESULT.passthrough with the body pass 1 emitted for it. When the final
%   document of its id is still IDENTICAL to that body (isequaln of the two
%   structs), the pipeline stores the v1 SOURCE in its place, stamped 'did_v1'
%   (NDI-matlab ndi.migrate.internal.carryUnchangedAsV1, the last step of
%   ndi.migrate.local; Decided by Jess Haley, 2026-10-24 [passthrough stays
%   v1] and [passthrough stays v1: how]). So that is the document compared
%   here, exactly as that step makes it, and the source is also counted
%   STORED AS v1 (sources_stored_as_v1, by class): it round trips because it
%   was not converted, which is a different statement from a conversion that
%   round trips. A passthrough a later step changed is compared as it is.
%
%   REPORT, the denominators first (Operating Rule 5):
%     sources_inspected        numel(V1BODIES)
%     final_documents          numel(RESULT.migrated)
%     sources_quarantined      sources pass 1 quarantined (its denominator:
%                              of these,)
%       sources_resolved_by_batch_pass, resolved_by_batch_pass_by_class
%                              a later pass put a document under the source's
%                              v1 id (did2.convert.resolveDeferredBaths
%                              re-migrates the baths pass 1 defers, carrying or
%                              converting each under its id): the source is
%                              then id-checked and compared on that document
%                              like any other. Until 2026-11-01 these were
%                              skipped, so on Test code run 41322059537 Dab's
%                              1,605 deferred baths were neither id-checked
%                              nor compared. A pass that re-migrates
%                              a deferred source through v1_to_v2 records
%                              every document the re-run made of it in
%                              RESULT.batch_pass_outputs ({id, pass,
%                              output_ids, context_ids}; today
%                              did2.convert.epochMint for a deferred
%                              pyraview), and the source is compared on
%                              all of them plus its context_ids (the epoch
%                              its anchor names). Without that record it
%                              was compared on the one document holding
%                              its id: PRED's pyraview, on Test code run
%                              43169466173, read "no level body was
%                              emitted" while its level bodies were
%                              in the batch.
%       sources_still_quarantined  no final document holds its id
%     ids_kept / ids_lost      sources whose v1 id some final document holds,
%                              or does not ([every v1 id survives]);
%                              ids_lost_by_class, ids_lost_ids (all of them)
%     ids_released             of the ids no final document holds, those a
%                              decision lets go (RELEASED_ID_CLASSES, below):
%                              the source's class is listed there AND no final
%                              document references the id ([a rebuilt document
%                              may lose its id], Jess Haley, 2026-10-27:
%                              allowed "when no other document references
%                              it"). Counted apart from ids_lost, never in it;
%                              ids_released_by_class. A listed class whose id
%                              IS referenced is counted lost.
%     ACCEPTED LOSSES          a v1 value a decision lets go as a recorded
%                              exception to the lossless rule, listed by name
%                              and counted, never silently (ACCEPTED_LOSSES,
%                              below):
%       accepted_losses_total, accepted_losses_by_name
%                              how many values each accepted loss covered
%       accepted_losses        struct array {name, decision, source_id,
%                              class_name, path}, every one (they are few)
%       ids_accepted_lost, ids_accepted_lost_by_class
%                              of the ids no final document holds, those an
%                              accepted loss covers (counted apart from
%                              ids_lost and ids_released, and in
%                              accepted_losses)
%       NOT MIGRATED BY A DECISION. A source a batch pass did not migrate by
%                              a decision is in RESULT.not_migrated ({id,
%                              class_name, reason, decision, ...}; today
%                              did2.convert.resolveResponseParameters, an
%                              orphaned parameters document with an
%                              identical used twin, [orphaned response
%                              settings are an accepted loss], Jess Haley,
%                              2026-11-12). An accepted loss marked LISTED
%                              covers only such a source: its id is counted
%                              in ids_accepted_lost (after the id check
%                              below) and the source is not compared, as
%                              there is no document of it to compare: the
%                              whole document is the accepted loss. One
%                              whose id is referenced is counted lost.
%       accepted_id_check      the check an accepted id loss needs first
%                              ([v1 session document id not kept]: "the
%                              build first checks that no v1 document in the
%                              corpora points at such an id (by depends_on
%                              or by value); one that does is reported, not
%                              dropped"): {documents_scanned, ids_checked,
%                              ids_referenced, referenced} where referenced
%                              is a struct array {id, class_name, by_id,
%                              by_class, field}: a v1 document (or, by_class
%                              '<final batch>', a final document) that
%                              names the id. A referenced id is NOT accepted:
%                              it counts in ids_lost
%     sources_without_id       sources stating no v1 id
%     sources_compared         sources handed to the per-class check
%     sources_ok               of those, the ones that round trip clean
%     sources_stored_as_v1, stored_as_v1_by_class   of the compared, the
%                              passthroughs still unchanged at the end, so
%                              stored as their v1 source (see above)
%     DEFERRED TO THE SECOND PASS  a v1 value this batch cannot hold because
%                              NDI-matlab's second pass writes it, as the
%                              class's inverse declares it (spec.deferred,
%                              did2.convert.roundtrip.check): listed by field
%                              and counted, never silently, and never lost.
%                              First case: an ingested archive's
%                              sample_analog_segment and
%                              sample_digital_segment ([archive segment
%                              lengths measured after the second pass], Jess
%                              Haley, 2026-11-12). A source whose only
%                              difference is such a value is clean at the DID
%                              stage: it counts in sources_ok, and in
%                              deferred_to_second_pass.sources_ok.
%       deferred_to_second_pass  struct, its denominator first:
%                              sources_compared (as above), sources (of those,
%                              with at least one deferred value), sources_ok
%                              (of those, clean at the DID stage), values
%                              (deferred values in all), fields (struct array
%                              {class_name, path, sources, decision}, one per
%                              class and field)
%     sources_compared_after_batch_pass, compared_after_batch_pass_by_class
%                              of the compared, those some (or, for a class
%                              locatedAfterPass finds, all) of whose documents
%                              a batch pass removed, read by an inverse for
%                              that pass (BATCH_PASS_INVERSES)
%     sources_changed_by_batch_pass, changed_by_class
%     sources_no_inverse, no_inverse_by_class
%     unattributed_documents   final documents no source became (minted by a
%                              batch pass)
%     failures_total, failures_by_class   compared sources that are not
%                              clean, counted exactly
%     failures                 struct array {source_id, class_name, lost,
%                              lost_values, invented, unplaced, deferred
%                              (the paths deferred to the second pass)}: in batch
%                              order, at most CLASS_CAP (5) per class and
%                              FAILURE_CAP (200) in all (a sample of every
%                              failing class; the counts above are exact).
%                              lost_values holds the first CLASS_CAP lost
%                              fields as text, 'path: v1 <...> rebuilt <...>',
%                              each value JSON-encoded and cut to 200
%                              characters
%     ok                       compared sources all clean, no id lost, nothing
%                              changed and nothing without an inverse
%
%   See also did2.convert.roundtrip.check, did2.convert.v1_to_v2.

arguments
    v1Bodies
    result (1,1) struct
end

bodies = asCellOfStructs(v1Bodies);
reloadBatchIndexes(bodies);
if ~isfield(result, 'source_outputs')
    error('did2:convert:roundtrip:noSourceOutputs', ...
        ['RESULT has no source_outputs: it was not made by a v1_to_v2 that ' ...
        'records what each source became.']);
end
rows = result.source_outputs;
final = result.migrated;
finalIds = cell(1, numel(final));
finalBodies = cell(1, numel(final));
for k = 1:numel(final)
    finalBodies{k} = bodyOf(final{k});
    finalIds{k} = idOf(finalBodies{k});
end
ctx = batchContext(finalBodies);
notMigrated = notMigratedIds(result);
passBody = passthroughBodies(result);
passOutputs = batchPassOutputs(result);

report = struct('sources_inspected', numel(bodies), 'final_documents', numel(final), ...
    'sources_quarantined', 0, 'sources_resolved_by_batch_pass', 0, ...
    'resolved_by_batch_pass_by_class', struct(), 'sources_still_quarantined', 0, ...
    'ids_kept', 0, 'ids_lost', 0, ...
    'ids_lost_by_class', struct(), 'ids_lost_ids', {{}}, ...
    'ids_released', 0, 'ids_released_by_class', struct(), ...
    'ids_accepted_lost', 0, 'ids_accepted_lost_by_class', struct(), ...
    'accepted_losses_total', 0, 'accepted_losses_by_name', struct(), ...
    'accepted_losses', struct('name', {}, 'decision', {}, 'source_id', {}, ...
        'class_name', {}, 'path', {}), ...
    'accepted_id_check', struct(), 'sources_without_id', 0, ...
    'sources_compared', 0, 'sources_ok', 0, ...
    'deferred_to_second_pass', struct('sources_compared', 0, 'sources', 0, ...
        'sources_ok', 0, 'values', 0, 'fields', struct('class_name', {}, ...
        'path', {}, 'sources', {}, 'decision', {})), ...
    'sources_stored_as_v1', 0, 'stored_as_v1_by_class', struct(), ...
    'sources_compared_after_batch_pass', 0, 'compared_after_batch_pass_by_class', struct(), ...
    'sources_changed_by_batch_pass', 0, 'changed_by_class', struct(), ...
    'sources_no_inverse', 0, 'no_inverse_by_class', struct(), ...
    'unattributed_documents', 0, 'failures_total', 0, 'failures_by_class', struct(), ...
    'failures', struct('source_id', {}, 'class_name', {}, 'lost', {}, ...
        'lost_values', {}, 'invented', {}, 'unplaced', {}, 'deferred', {}), 'ok', false);
accepted = ACCEPTED_LOSSES();
[report.accepted_id_check, idReferenced] = acceptedIdCheck(bodies, rows, accepted, ctx, notMigrated);
sampled = struct();
uidIndex = [];   % bodyUidIndex, built on first use (uidIndexBuilt)
uidIndexBuilt = false;
attributed = false(1, numel(final));
for r = 1:numel(rows)
    row = rows(r);
    if row.input_index < 1 || row.input_index > numel(bodies)
        continue;
    end
    v1 = bodies{row.input_index};
    contextIds = {};
    cls = row.class_name;
    if isempty(cls); cls = v1ClassName(v1); end
    if isempty(row.id)
        % v1_to_v2 records a source's id and class only when it migrates; a
        % source it deferred (quarantine) has neither, so read them from the
        % v1 body (a later pass may have put a document under that id)
        row.id = v1Id(v1);
    end
    if ~row.done
        report.sources_quarantined = report.sources_quarantined + 1;
        if isempty(row.id) || ~any(strcmp(finalIds, row.id))
            report.sources_still_quarantined = report.sources_still_quarantined + 1;
            continue;
        end
        % a later pass put a document under its v1 id (sources_resolved_by_batch_pass)
        report.sources_resolved_by_batch_pass = report.sources_resolved_by_batch_pass + 1;
        report.resolved_by_batch_pass_by_class = bump(report.resolved_by_batch_pass_by_class, cls);
        row.output_ids = {row.id};
        if isKey(passOutputs, row.id)
            % the pass recorded every document its re-run made of the source
            % (RESULT.batch_pass_outputs; see sources_resolved_by_batch_pass)
            rec = passOutputs(row.id);
            row.output_ids = rec.output_ids;
            contextIds = rec.context_ids;
        end
    end
    % [every v1 id survives]
    released = false;
    listed = ~isempty(row.id) && isKey(notMigrated, row.id);
    if isempty(row.id)
        report.sources_without_id = report.sources_without_id + 1;
    elseif any(strcmp(finalIds, row.id))
        report.ids_kept = report.ids_kept + 1;
    elseif any(strcmp(cls, RELEASED_ID_CLASSES())) && isempty(ctxReferrers(ctx, row.id))
        report.ids_released = report.ids_released + 1;
        report.ids_released_by_class = bump(report.ids_released_by_class, cls);
        released = true;
    elseif ~isempty(acceptedIdLoss(accepted, cls, listed)) && ~isKey(idReferenced, row.id)
        a = acceptedIdLoss(accepted, cls, listed);
        report.ids_accepted_lost = report.ids_accepted_lost + 1;
        report.ids_accepted_lost_by_class = bump(report.ids_accepted_lost_by_class, cls);
        report = noteAccepted(report, a, row.id, cls, '(the v1 id)');
        if a.listed
            continue;   % NOT MIGRATED BY A DECISION: nothing of it to compare
        end
    else
        report.ids_lost = report.ids_lost + 1;
        report.ids_lost_by_class = bump(report.ids_lost_by_class, cls);
        report.ids_lost_ids{end+1} = row.id;
    end
    outs = row.output_ids;
    if ischar(outs); outs = {outs}; end
    [present, where] = ismember(outs, finalIds);
    attributed(where(present)) = true;
    afterPass = false;
    located = [];
    if ~all(present)
        if any(strcmp(cls, BATCH_PASS_INVERSES())) && ~any(present)
            % none remains: what the pass made of it (LOCATED AFTER A BATCH PASS)
            if ~uidIndexBuilt
                uidIndex = bodyUidIndex(finalBodies);
                uidIndexBuilt = true;
            end
            located = locatedAfterPass(cls, v1, uidIndex);
        end
        if ~any(strcmp(cls, BATCH_PASS_INVERSES())) || (~any(present) && isempty(located))
            report.sources_changed_by_batch_pass = report.sources_changed_by_batch_pass + 1;
            report.changed_by_class = bump(report.changed_by_class, cls);
            continue;
        end
        afterPass = true;   % compared on what remains (AN INVERSE FOR A BATCH PASS)
    end
    if isempty(outs)
        continue;   % a source that became nothing (its migrator wrote none)
    end
    docs = finalBodies(where(present));
    if ~isempty(located)
        docs = finalBodies(located);
    end
    if ~isempty(contextIds)
        % documents the inverse reads that the source did not become (the
        % epoch a deferred pyraview names); one gone is not supplied, and the
        % inverse says what it could not rebuild
        [cPresent, cWhere] = ismember(contextIds, finalIds);
        docs = [docs, finalBodies(cWhere(cPresent))];
    end
    storedAsV1 = false;
    if isempty(located) && isscalar(outs) && isKey(passBody, outs{1})
        rec = passBody(outs{1});
        if rec.input_index == row.input_index && isequaln(docs{1}, rec.body)
            % the pipeline stores the v1 source in its place (see HOW)
            src = v1;
            src.document_class.schema_version = 'did_v1';
            docs = {src};
            storedAsV1 = true;
        end
    end
    try
        c = did2.convert.roundtrip.check(v1, docs, ctx);
    catch err
        if strcmp(err.identifier, 'did2:convert:roundtrip:noInverse')
            report.sources_no_inverse = report.sources_no_inverse + 1;
            report.no_inverse_by_class = bump(report.no_inverse_by_class, cls);
            continue;
        end
        rethrow(err);
    end
    % an ACCEPTED LOSS is listed and counted, and is not a failure
    [c, report] = takeAcceptedLosses(c, report, accepted, row.id, cls, v1, docs, ctx, idReferenced, listed);
    if released && ~isempty(c.lost)
        % a RELEASED id ([a rebuilt document may lose its id]) is counted in
        % ids_released; the rebuilt document cannot hold it, and that is the
        % same fact, not a second loss
        c.lost = c.lost(~strcmp({c.lost.path}, 'base.id'));
        c.ok = isempty(c.lost) && isempty(c.invented) && isempty(c.unplaced);
    end
    report.sources_compared = report.sources_compared + 1;
    report.deferred_to_second_pass = noteDeferred(report.deferred_to_second_pass, c, cls);
    if afterPass
        report.sources_compared_after_batch_pass = report.sources_compared_after_batch_pass + 1;
        report.compared_after_batch_pass_by_class = bump(report.compared_after_batch_pass_by_class, cls);
    end
    if storedAsV1
        report.sources_stored_as_v1 = report.sources_stored_as_v1 + 1;
        report.stored_as_v1_by_class = bump(report.stored_as_v1_by_class, cls);
    end
    if c.ok
        report.sources_ok = report.sources_ok + 1;
        if isfield(c, 'deferred') && ~isempty(c.deferred)
            report.deferred_to_second_pass.sources_ok = ...
                report.deferred_to_second_pass.sources_ok + 1;
        end
    else
        report.failures_total = report.failures_total + 1;
        report.failures_by_class = bump(report.failures_by_class, cls);
        f = matlab.lang.makeValidName(cls);
        nThis = 0;
        if isfield(sampled, f); nThis = sampled.(f); end
        if numel(report.failures) < 200 && nThis < 5   % FAILURE_CAP, CLASS_CAP
            sampled.(f) = nThis + 1;
            lostPaths = {};
            if ~isempty(c.lost); lostPaths = {c.lost.path}; end
            report.failures(end+1) = struct('source_id', row.id, 'class_name', cls, ...
                'lost', {lostPaths}, 'lost_values', {lostValues(c.lost, 5)}, ...
                'invented', {c.invented}, 'unplaced', {c.unplaced}, ...
                'deferred', {deferredPaths(c)});
        end
    end
end
report.unattributed_documents = nnz(~attributed);
report.deferred_to_second_pass.sources_compared = report.sources_compared;
report.ok = report.sources_ok == report.sources_compared && report.ids_lost == 0 ...
    && report.sources_changed_by_batch_pass == 0 && report.sources_no_inverse == 0;
end

% ===================== helpers =========================================

function m = batchPassOutputs(result)
% v1 id -> {output_ids, context_ids} of each source a batch pass re-migrated
% (RESULT.batch_pass_outputs; did2.convert.epochMint's
% resolveDeferredPyraviews). A source recorded twice keeps its last record.
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isfield(result, 'batch_pass_outputs') || ~isstruct(result.batch_pass_outputs)
    return;
end
for k = 1:numel(result.batch_pass_outputs)
    r = result.batch_pass_outputs(k);
    if isempty(r.id); continue; end
    o = r.output_ids;
    if ischar(o); o = {o}; end
    c = r.context_ids;
    if ischar(c); c = {c}; end
    m(char(r.id)) = struct('output_ids', {reshape(o, 1, [])}, ...
        'context_ids', {reshape(c, 1, [])});
end
end

function id = v1Id(v1)
% the base.id a v1 body states ('' when none)
id = '';
if isstruct(v1) && isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'id') ...
        && (ischar(v1.base.id) || (isstring(v1.base.id) && isscalar(v1.base.id)))
    id = char(v1.base.id);
end
end

function c = v1ClassName(v1)
% the class a v1 body names ('<unknown>' when it names none)
c = '<unknown>';
if isstruct(v1) && isfield(v1, 'document_class') && isstruct(v1.document_class) ...
        && isfield(v1.document_class, 'class_name') && ~isempty(v1.document_class.class_name)
    c = char(v1.document_class.class_name);
end
end

function c = BATCH_PASS_INVERSES()
% the classes whose inverse reads, from the whole batch, what a batch pass did
% to their documents (AN INVERSE FOR A BATCH PASS, above)
c = {'element', ...   % resolveEpochProbemap retires `observes`; roundtrip.element
    'daqreader_mfdaq_epochdata_ingested'};   % resolveEpochProbemap retires the archive
end

function idx = locatedAfterPass(cls, v1, uidIndex)
%LOCATEDAFTERPASS The positions, in batch order, of the final documents a
%   batch pass made of a source NONE of whose own documents remains ([] when
%   none, or when the class has no such lookup). A
%   `daqreader_mfdaq_epochdata_ingested`: the opaque_body documents
%   resolveEpochProbemap built from its attached files, which hold its
%   location uids verbatim (UIDINDEX, bodyUidIndex).
idx = [];
if ~strcmp(cls, 'daqreader_mfdaq_epochdata_ingested') || ~isstruct(v1) ...
        || ~isfield(v1, 'files') || ~isstruct(v1.files) || ~isfield(v1.files, 'file_info')
    return;
end
for u = fileUids(v1.files.file_info)
    if isKey(uidIndex, u{1})
        idx = [idx, uidIndex(u{1})]; %#ok<AGROW>
    end
end
idx = unique(idx);
end

function m = bodyUidIndex(finalBodies)
% location uid -> the positions of every final opaque_body whose file_info
% holds it
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(finalBodies)
    b = finalBodies{k};
    if ~strcmp(classNameOf(b), 'opaque_body') || ~isfield(b, 'files') ...
            || ~isstruct(b.files) || ~isfield(b.files, 'file_info')
        continue;
    end
    for u = fileUids(b.files.file_info)
        if isKey(m, u{1})
            m(u{1}) = [m(u{1}), k];
        else
            m(u{1}) = k;
        end
    end
end
end

function uids = fileUids(fileInfo)
% every location uid a files.file_info list holds, in order (1xN cellstr)
uids = {};
infos = fileInfo;
if isstruct(infos); infos = num2cell(reshape(infos, 1, [])); end
if ~iscell(infos); return; end
for i = 1:numel(infos)
    if ~isstruct(infos{i}) || ~isscalar(infos{i}) || ~isfield(infos{i}, 'locations')
        continue;
    end
    locs = infos{i}.locations;
    if isstruct(locs); locs = num2cell(reshape(locs, 1, [])); end
    if ~iscell(locs); continue; end
    for j = 1:numel(locs)
        if isstruct(locs{j}) && isscalar(locs{j}) && isfield(locs{j}, 'uid') ...
                && ~isempty(locs{j}.uid) && (ischar(locs{j}.uid) || isstring(locs{j}.uid))
            uids{end+1} = char(locs{j}.uid); %#ok<AGROW>
        end
    end
end
end

function d = noteDeferred(d, c, cls)
% count C's values deferred to the second pass (DEFERRED TO THE SECOND PASS)
if ~isfield(c, 'deferred') || isempty(c.deferred)
    return;
end
d.sources = d.sources + 1;
d.values = d.values + numel(c.deferred);
for k = 1:numel(c.deferred)
    p = c.deferred(k).path;
    j = find(strcmp({d.fields.class_name}, cls) & strcmp({d.fields.path}, p), 1);
    if isempty(j)
        d.fields(end+1) = struct('class_name', cls, 'path', p, 'sources', 1, ...
            'decision', c.deferred(k).why);
    else
        d.fields(j).sources = d.fields(j).sources + 1;
    end
end
end

function p = deferredPaths(c)
% the paths C deferred to the second pass (cellstr)
p = {};
if isfield(c, 'deferred') && ~isempty(c.deferred)
    p = {c.deferred.path};
end
end

function a = ACCEPTED_LOSSES()
%ACCEPTED_LOSSES The v1 values a decision lets go, as recorded exceptions to
%   the lossless rule ([lossless means round trip], [every v1 id survives]).
%   Each: NAME (how the report lists it), DECISION (the did-schema
%   did_v2_go_forward_class_audit.md tag), CLASSES (the v1 classes), PATHS
%   (the round-trip paths it covers; '(the v1 id)' for the source's own id in
%   the id check), ID (true when the source's v1 id itself may be gone: the id
%   is first checked, acceptedIdCheck) and WHEN (@(v1, docs, ctx) -> true when
%   the loss applies to this source; [] for always). LISTED (true: only for a
%   source RESULT.not_migrated lists, NOT MIGRATED BY A DECISION) is set
%   false on every entry but those that say otherwise, at the end.
a = struct('name', {}, 'decision', {}, 'classes', {}, 'paths', {}, 'id', {}, 'when', {});
% [v1 session document id not kept] (Decided by Jess Haley, 2026-11-03): the
% own base.id of a v1 `session` and of a v1 `dataset_remote` document is not
% kept; the session (dataset) entity keeps the session (dataset) id, as NDI's
% v2 writer does
a(end+1) = struct('name', 'v1 session document id', ...
    'decision', '[v1 session document id not kept] (Jess Haley, 2026-11-03)', ...
    'classes', {{'session', 'dataset_remote'}}, 'paths', {{'base.id'}}, ...
    'id', true, 'when', []);
% [dataset storage session date dropped] (Decided by Jess Haley, 2026-11-03):
% when a dataset's own v1 `session` document folds into the dataset entity
% ([dataset session reference]), its base.datestamp is not kept; the dataset
% entity keeps the dataset document's creation time. Experiment sessions keep
% their own: accepted only when the session's one document is a dataset entity
a(end+1) = struct('name', 'dataset storage session date', ...
    'decision', '[dataset storage session date dropped] (Jess Haley, 2026-11-03)', ...
    'classes', {{'session'}}, 'paths', {{'base.datestamp'}}, ...
    'id', false, 'when', @foldedIntoDataset);
% [clamp mode of unrecorded probe dropped] (Decided by Jess Haley, 2026-11-03):
% a patch, sharp or imaging element with no recording keeps its device kind
% and its v1 `element type` statement is not kept; did2.convert.
% resolveEpochProbemap drops it. Accepted only for such an element: its v1
% type is one of a device kind several types share, and its documents hold
% that kind and no `element type` statement
a(end+1) = struct('name', 'mode of a probe that never recorded', ...
    'decision', '[clamp mode of unrecorded probe dropped] (Jess Haley, 2026-11-03)', ...
    'classes', {{'element'}}, 'paths', {{'element.type'}}, ...
    'id', false, 'when', @unrecordedModeDropped);
% [unlinked device is not an element] (Decided by Jess Haley, 2026-11-11): a
% migrated v1 probe whose device has no recording observation (`instrument_id`)
% and no wiring (`connected to`, RO:0002170) in the final batch is not an
% element ([element recognised by its links]); it keeps its device entity
% (type, subject link), and no "ndi element class" assertion is kept for it,
% so its v1 ndi_element_class is not rebuilt: a known difference from v1 (a
% probe with no epochs reads back as a device, not an element). Accepted only
% for such a device (unlinkedDevice). This batch is the one before
% NDI-matlab's second pass, which mints the recordings of an epoch with no
% ingested cache; a device that pass links is an element in NDI-matlab.
a(end+1) = struct('name', 'device with no links is not an element', ...
    'decision', '[unlinked device is not an element] (Jess Haley, 2026-11-11)', ...
    'classes', {{'element'}}, 'paths', {{'element.ndi_element_class'}}, ...
    'id', false, 'when', @unlinkedDevice);
% [jrclust settings-file name dropped] (Decided by Jess Haley, 2026-11-11,
% replacing [one-reading quick answers] Q5): the settings-file name a
% `jrclust_clusters` holds -- base.name, which NDI-matlab's writer
% (+ndi/+fun/+probe/+import/+jrclust/probe.m) sets from its `prmName` option,
% and the Soph vintage's ndi_document.name ('jrclust.prm'), which
% did2.convert.roundtrip.check compares as base.name ([ndi_document read as
% base]) -- is not carried: the document migrates to its decided shape, and
% the name is a recorded difference from v1, whatever its value
% (did2.convert.jrclustSettingsNameDropped; roundtrip.jrclust_clusters does
% not rebuild it)
a(end+1) = struct('name', 'jrclust settings file name', ...
    'decision', '[jrclust settings-file name dropped] (Jess Haley, 2026-11-11)', ...
    'classes', {{'jrclust_clusters'}}, 'paths', {{'base.name'}}, ...
    'id', false, 'when', []);
[a.listed] = deal(false);
% [orphaned response settings are an accepted loss] (Decided by Jess Haley,
% 2026-11-12): an orphaned stimulus_response_scalar_parameters_basic (referred
% to by no document) with an identical used twin in its session is not
% migrated; it is listed in known_v1_defects and its loss is accepted here.
% LISTED: only a source did2.convert.resolveResponseParameters recorded in
% RESULT.not_migrated; any other parameters document whose id is gone is lost
a(end+1) = struct('name', 'orphaned response settings', ...
    'decision', '[orphaned response settings are an accepted loss] (Jess Haley, 2026-11-12)', ...
    'classes', {{'stimulus_response_scalar_parameters_basic'}}, 'paths', {{'base.id'}}, ...
    'id', true, 'when', [], 'listed', true);
end

function m = notMigratedIds(result)
% v1 id -> true for each source RESULT.not_migrated lists (NOT MIGRATED BY A
% DECISION)
m = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if ~isfield(result, 'not_migrated') || ~isstruct(result.not_migrated)
    return;
end
for k = 1:numel(result.not_migrated)
    id = result.not_migrated(k).id;
    if ischar(id) || (isstring(id) && isscalar(id))
        if ~isempty(char(id)); m(char(id)) = true; end
    end
end
end

function tf = unlinkedDevice(v1, docs, ctx)
% DOCS' entity is a `device` (by node), CTX holds no recording observation
% and no `connected to` wiring of it (deviceLinks), and its documents keep
% no "ndi element class" assertion (one that is kept wins: [assertion wins
% while written])
tf = false;
if isempty(ctx) || ~isstruct(v1) || ~isfield(v1, 'base') || ~isstruct(v1.base) ...
        || ~isfield(v1.base, 'id')
    return;
end
id = char(v1.base.id);
isDevice = false;
for k = 1:numel(docs)
    b = docs{k};
    if isEntityOfType(b, 'device') && strcmp(idOf(b), id)
        isDevice = true;
    elseif strcmp(classNameOf(b), 'assertion')
        [~, variable] = termParts(getIn(b, 'statement', 'variable'));
        if strcmpi(variable, 'ndi element class')
            return;
        end
    end
end
tf = isDevice && isempty(deviceLinks(ctx, id));
end

function tf = foldedIntoDataset(~, docs, ~)
% the session's one final document is the dataset entity (a dataset's own
% session, roundtrip.session)
tf = isscalar(docs) && isEntityOfType(docs{1}, 'dataset');
end

function tf = unrecordedModeDropped(v1, docs, ctx)
% V1's element.type is a type of a shared device kind, DOCS state that kind
% and no `element type`, and no observation in CTX names the element as its
% instrument: the probe never recorded. A RECORDED probe whose statement was
% dropped ([recording mode terms]) rebuilds its word from its observations'
% modes, so a difference there is a failure, not this accepted loss.
tf = false;
if ~isempty(ctx) && isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'id')
    id = char(v1.base.id);
    for k = ctxReferrers(ctx, id)
        b = ctx.docs{k};
        if strcmp(classNameOf(b), 'observation') && any(strcmp(edgeIds(b, 'instrument_id'), id))
            return;
        end
    end
end
if ~isstruct(v1) || ~isfield(v1, 'element') || ~isstruct(v1.element) ...
        || ~isfield(v1.element, 'type')
    return;
end
type = strtrim(char(v1.element.type));
kind = did2.convert.elementDeviceKind(type);
if isempty(kind) || ~isempty(did2.convert.elementTypeOfKind(kind.node))
    return;
end
hasKind = false;
for k = 1:numel(docs)
    b = docs{k};
    if ~isstruct(b) || ~isfield(b, 'statement') || ~isstruct(b.statement) ...
            || ~isfield(b.statement, 'variable') || ~isstruct(b.statement.variable)
        continue;
    end
    v = lower(char(b.statement.variable.name));
    if strcmp(v, 'element type')
        return;
    end
    if strcmp(v, 'equipment type') && isfield(b, 'term') && isstruct(b.term) ...
            && isfield(b.term, 'value') && isstruct(b.term.value) ...
            && strcmp(char(b.term.value.node), char(kind.node))
        hasKind = true;
    end
end
tf = hasKind;
end

function a = acceptedIdLoss(accepted, cls, listed)
% the accepted loss that lets a source of class CLS lose its own v1 id ([] if
% none); one marked LISTED only when the source is (LISTED true)
a = [];
for k = 1:numel(accepted)
    if accepted(k).listed && ~listed
        continue;
    end
    if accepted(k).id && any(strcmp(accepted(k).classes, cls))
        a = accepted(k);
        return;
    end
end
end

function report = noteAccepted(report, a, sourceId, cls, path)
report.accepted_losses_total = report.accepted_losses_total + 1;
report.accepted_losses_by_name = bump(report.accepted_losses_by_name, a.name);
report.accepted_losses(end+1) = struct('name', a.name, 'decision', a.decision, ...
    'source_id', sourceId, 'class_name', cls, 'path', path);
end

function [c, report] = takeAcceptedLosses(c, report, accepted, sourceId, cls, v1, docs, ctx, idReferenced, listed)
% move the lost fields an accepted loss covers out of C.lost into the report's
% accepted list, and recompute C.ok
if isempty(c.lost)
    return;
end
keep = true(1, numel(c.lost));
for k = 1:numel(accepted)
    a = accepted(k);
    if ~any(strcmp(a.classes, cls)) || (a.listed && ~listed)
        continue;
    end
    if a.id && isKey(idReferenced, sourceId)
        continue;   % a referenced id is not accepted (acceptedIdCheck)
    end
    if ~isempty(a.when) && ~a.when(v1, docs, ctx)
        continue;
    end
    for j = find(keep)
        if any(strcmp(c.lost(j).path, a.paths))
            keep(j) = false;
            if a.id && strcmp(c.lost(j).path, 'base.id') && ~isempty(report.accepted_losses) ...
                    && strcmp(report.accepted_losses(end).source_id, sourceId) ...
                    && strcmp(report.accepted_losses(end).name, a.name)
                continue;   % the same value the id check listed: once
            end
            report = noteAccepted(report, a, sourceId, cls, c.lost(j).path);
        end
    end
end
c.lost = c.lost(keep);
c.ok = isempty(c.lost) && isempty(c.invented) && isempty(c.unplaced);
end

function [check, referenced] = acceptedIdCheck(bodies, rows, accepted, ctx, notMigrated)
%ACCEPTEDIDCHECK Before an accepted loss lets a v1 id go, check that nothing
%   points at it: no other v1 document names it, by a depends_on value or as
%   any value anywhere in the document (its JSON text holds the id), and no
%   final document references it. REFERENCED maps each id that something
%   names to true; CHECK reports the denominator and every hit.
referenced = containers.Map('KeyType', 'char', 'ValueType', 'logical');
check = struct('documents_scanned', 0, 'ids_checked', 0, 'ids_referenced', 0, ...
    'referenced', struct('id', {}, 'class_name', {}, 'by_id', {}, 'by_class', {}, 'field', {}));
ids = {};
classes = {};
owners = [];
for r = 1:numel(rows)
    row = rows(r);
    if row.input_index < 1 || row.input_index > numel(bodies)
        continue;
    end
    v1 = bodies{row.input_index};
    cls = row.class_name;
    if isempty(cls); cls = v1ClassName(v1); end
    id = v1Id(v1);
    if isempty(id) || isempty(acceptedIdLoss(accepted, cls, isKey(notMigrated, id)))
        continue;
    end
    ids{end+1} = id; %#ok<AGROW>
    classes{end+1} = cls; %#ok<AGROW>
    owners(end+1) = row.input_index; %#ok<AGROW>
end
check.ids_checked = numel(ids);
if isempty(ids)
    check.documents_scanned = numel(bodies);
    return;
end
for k = 1:numel(bodies)
    check.documents_scanned = check.documents_scanned + 1;
    try
        txt = jsonencode(bodies{k});
    catch
        txt = '';
    end
    for i = 1:numel(ids)
        if owners(i) == k || ~contains(txt, ids{i})
            continue;
        end
        referenced(ids{i}) = true;
        check.referenced(end+1) = struct('id', ids{i}, 'class_name', classes{i}, ...
            'by_id', v1Id(bodies{k}), 'by_class', v1ClassName(bodies{k}), ...
            'field', fieldNaming(bodies{k}, ids{i}, ''));
    end
end
for i = 1:numel(ids)
    hits = ctxReferrers(ctx, ids{i});
    if ~isempty(hits)
        referenced(ids{i}) = true;
        check.referenced(end+1) = struct('id', ids{i}, 'class_name', classes{i}, ...
            'by_id', idOf(ctx.docs{hits(1)}), 'by_class', '<final batch>', 'field', '');
    end
end
check.ids_referenced = double(referenced.Count);
end

function p = fieldNaming(v, id, path)
% the first path under V whose text value holds ID ('' when none is found)
p = '';
if ischar(v) || (isstring(v) && isscalar(v))
    if contains(char(v), id); p = path; end
elseif isstruct(v)
    for e = 1:numel(v)
        fns = fieldnames(v);
        for f = 1:numel(fns)
            sub = path;
            if numel(v) > 1; sub = sprintf('%s(%d)', sub, e); end
            if isempty(sub); sub = fns{f}; else; sub = [sub '.' fns{f}]; end %#ok<AGROW>
            p = fieldNaming(v(e).(fns{f}), id, sub);
            if ~isempty(p); return; end
        end
    end
elseif iscell(v)
    for e = 1:numel(v)
        p = fieldNaming(v{e}, id, sprintf('%s{%d}', path, e));
        if ~isempty(p); return; end
    end
end
end

function c = RELEASED_ID_CLASSES()
% the v1 classes a decision lets lose their id when nothing references it
% ([a rebuilt document may lose its id], Jess Haley, 2026-10-27, amending
% [every v1 id survives]):
%   dataset_session_info  the decision's own example: rebuilt from the
%                         memberships, it writes no v2 document
%   daqreader_mfdaq_epochdata_ingested  [segment length is the time chunk]
%                         (Jess Haley, 2026-10-29): "The v1 archive document
%                         is not kept: its id goes under [a rebuilt document
%                         may lose its id] unless something links to it"
%                         (did2.convert.resolveEpochProbemap retires it only
%                         then)
c = {'dataset_session_info', 'daqreader_mfdaq_epochdata_ingested'};
end

function reloadBatchIndexes(bodies)
%RELOADBATCHINDEXES Index the WHOLE v1 batch again for the inverses that read
%   it: did2.convert.elementSubjects (roundtrip.element rebuilds a sorted
%   unit's subject_id from its probe's, [unit direct and subject rebuild from
%   the probe]), did2.convert.stimulusPresentationSpecs (roundtrip.hartley_calc
%   rebuilds stimulus_properties from the presentation, [hartley leftovers
%   checked]) and did2.convert.tuningBatchIndex (did2.convert.inputEdgeNames
%   and did2.convert.tuningStimids, read by the tuning and response inverses,
%   [input names rebuild from the input class], [tuning stimids rebuild]).
%
%   WHY. did2.convert.v1_to_v2 resets and loads these per call. The batch
%   passes call v1_to_v2 again on their own small sub-batches (epochMint,
%   resolveEpochProbemap, foldGenericFiles, ...), so after the last pass the
%   indexes hold the LAST SUB-BATCH, not the batch this report reads. Every
%   inverse that read them then found nothing: on Test code run 41322059537
%   (DID-matlab b513b228) every 20211116 element with an underlying element
%   (21, all sorted units) lost its subject_id, and the sampled hartley_calc
%   failures their stimulus_properties, while the per-class round-trip tests
%   (one v1_to_v2 call) rebuild both. The whole-batch report indexes V1BODIES
%   itself, as v1_to_v2 does.
for f = {@did2.convert.elementSubjects, @did2.convert.stimulusPresentationSpecs, ...
        @did2.convert.tuningBatchIndex}
    f{1}('reset');
    f{1}('load', bodies);
end
end

function c = asCellOfStructs(v1Bodies)
if isstruct(v1Bodies)
    c = num2cell(reshape(v1Bodies, 1, []));
elseif iscell(v1Bodies)
    c = reshape(v1Bodies, 1, []);
else
    c = {v1Bodies};
end
for k = 1:numel(c)
    if ischar(c{k}) || (isstring(c{k}) && isscalar(c{k}))
        c{k} = jsondecode(char(c{k}));
    end
end
end

function b = bodyOf(d)
% a final document as a struct (did2.document's toStruct)
b = d;
try
    if isa(d, 'did2.document')
        b = d.toStruct();
    end
catch
    b = struct();
end
end

function id = idOf(b)
id = '';
if isstruct(b) && isscalar(b) && isfield(b, 'base') && isstruct(b.base) ...
        && isfield(b.base, 'id')
    id = char(b.base.id);
end
end

function m = passthroughBodies(result)
% base.id -> {input_index, body} of each document pass 1 passed through
% (did2.convert.v1_to_v2's result.passthrough)
m = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isfield(result, 'passthrough') || ~isstruct(result.passthrough)
    return;
end
for k = 1:numel(result.passthrough)
    rec = result.passthrough(k);
    id = char(rec.id);
    if ~isempty(id) && ~isKey(m, id)
        m(id) = struct('input_index', rec.input_index, 'body', rec.body);
    end
end
end

function out = lostValues(lost, cap)
% the first CAP lost fields as text: 'path: v1 <...> rebuilt <...>'
out = {};
for k = 1:min(cap, numel(lost))
    out{end+1} = sprintf('%s: v1 %s rebuilt %s', lost(k).path, ...
        shortText(lost(k).v1), shortText(lost(k).rebuilt)); %#ok<AGROW>
end
end

function t = shortText(v)
try
    t = jsonencode(v);
catch
    t = '<not encodable>';
end
if numel(t) > 200
    t = [t(1:200) '...'];
end
end

function s = bump(s, name)
f = matlab.lang.makeValidName(name);
if isfield(s, f)
    s.(f) = s.(f) + 1;
else
    s.(f) = 1;
end
end
