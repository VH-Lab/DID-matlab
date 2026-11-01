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
%     sources_quarantined      sources pass 1 quarantined
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
%     sources_without_id       sources stating no v1 id
%     sources_compared         sources handed to the per-class check
%     sources_ok               of those, the ones that round trip clean
%     sources_stored_as_v1, stored_as_v1_by_class   of the compared, the
%                              passthroughs still unchanged at the end, so
%                              stored as their v1 source (see above)
%     sources_changed_by_batch_pass, changed_by_class
%     sources_no_inverse, no_inverse_by_class
%     unattributed_documents   final documents no source became (minted by a
%                              batch pass)
%     failures_total, failures_by_class   compared sources that are not
%                              clean, counted exactly
%     failures                 struct array {source_id, class_name, lost,
%                              lost_values, invented, unplaced}: in batch
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
passBody = passthroughBodies(result);

report = struct('sources_inspected', numel(bodies), 'final_documents', numel(final), ...
    'sources_quarantined', 0, 'ids_kept', 0, 'ids_lost', 0, ...
    'ids_lost_by_class', struct(), 'ids_lost_ids', {{}}, ...
    'ids_released', 0, 'ids_released_by_class', struct(), 'sources_without_id', 0, ...
    'sources_compared', 0, 'sources_ok', 0, ...
    'sources_stored_as_v1', 0, 'stored_as_v1_by_class', struct(), ...
    'sources_changed_by_batch_pass', 0, 'changed_by_class', struct(), ...
    'sources_no_inverse', 0, 'no_inverse_by_class', struct(), ...
    'unattributed_documents', 0, 'failures_total', 0, 'failures_by_class', struct(), ...
    'failures', struct('source_id', {}, 'class_name', {}, 'lost', {}, ...
        'lost_values', {}, 'invented', {}, 'unplaced', {}), 'ok', false);
sampled = struct();
attributed = false(1, numel(final));
for r = 1:numel(rows)
    row = rows(r);
    if row.input_index < 1 || row.input_index > numel(bodies)
        continue;
    end
    v1 = bodies{row.input_index};
    cls = row.class_name;
    if isempty(cls); cls = '<unknown>'; end
    if ~row.done
        report.sources_quarantined = report.sources_quarantined + 1;
        continue;
    end
    % [every v1 id survives]
    if isempty(row.id)
        report.sources_without_id = report.sources_without_id + 1;
    elseif any(strcmp(finalIds, row.id))
        report.ids_kept = report.ids_kept + 1;
    elseif any(strcmp(cls, RELEASED_ID_CLASSES())) && isempty(ctxReferrers(ctx, row.id))
        report.ids_released = report.ids_released + 1;
        report.ids_released_by_class = bump(report.ids_released_by_class, cls);
    else
        report.ids_lost = report.ids_lost + 1;
        report.ids_lost_by_class = bump(report.ids_lost_by_class, cls);
        report.ids_lost_ids{end+1} = row.id;
    end
    outs = row.output_ids;
    if ischar(outs); outs = {outs}; end
    [present, where] = ismember(outs, finalIds);
    attributed(where(present)) = true;
    if ~all(present)
        report.sources_changed_by_batch_pass = report.sources_changed_by_batch_pass + 1;
        report.changed_by_class = bump(report.changed_by_class, cls);
        continue;
    end
    if isempty(outs)
        continue;   % a source that became nothing (its migrator wrote none)
    end
    docs = finalBodies(where);
    storedAsV1 = false;
    if isscalar(outs) && isKey(passBody, outs{1})
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
    report.sources_compared = report.sources_compared + 1;
    if storedAsV1
        report.sources_stored_as_v1 = report.sources_stored_as_v1 + 1;
        report.stored_as_v1_by_class = bump(report.stored_as_v1_by_class, cls);
    end
    if c.ok
        report.sources_ok = report.sources_ok + 1;
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
                'invented', {c.invented}, 'unplaced', {c.unplaced});
        end
    end
end
report.unattributed_documents = nnz(~attributed);
report.ok = report.sources_ok == report.sources_compared && report.ids_lost == 0 ...
    && report.sources_changed_by_batch_pass == 0 && report.sources_no_inverse == 0;
end

% ===================== helpers =========================================

function c = RELEASED_ID_CLASSES()
% the v1 classes a decision lets lose their id when nothing references it
% ([a rebuilt document may lose its id], Jess Haley, 2026-10-27, amending
% [every v1 id survives]):
%   dataset_session_info  the decision's own example: rebuilt from the
%                         memberships, it writes no V2 document
%   daqreader_mfdaq_epochdata_ingested  [segment length is the time chunk]
%                         (Jess Haley, 2026-10-29): "The v1 archive document
%                         is not kept: its id goes under [a rebuilt document
%                         may lose its id] unless something links to it"
%                         (did2.convert.resolveEpochProbemap retires it only
%                         then)
c = {'dataset_session_info', 'daqreader_mfdaq_epochdata_ingested'};
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
