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
%   per-class inverse. When one is gone (a batch pass replaced or folded it),
%   the source is counted CHANGED BY A BATCH PASS and not compared: that pass
%   has no inverse yet (Build pending: an inverse for each batch pass). A class
%   with no inverse is counted NO INVERSE. Nothing is guessed.
%
%   REPORT, the denominators first (Operating Rule 5):
%     sources_inspected        numel(V1BODIES)
%     final_documents          numel(RESULT.migrated)
%     sources_quarantined      sources pass 1 quarantined
%     ids_kept / ids_lost      sources whose v1 id some final document holds,
%                              or does not ([every v1 id survives]);
%                              ids_lost_by_class, ids_lost_ids (all of them)
%     sources_without_id       sources stating no v1 id
%     sources_compared         sources handed to the per-class check
%     sources_ok               of those, the ones that round trip clean
%     sources_changed_by_batch_pass, changed_by_class
%     sources_no_inverse, no_inverse_by_class
%     unattributed_documents   final documents no source became (minted by a
%                              batch pass)
%     failures_total, failures_by_class   compared sources that are not
%                              clean, counted exactly
%     failures                 struct array {source_id, class_name, lost,
%                              invented, unplaced}: the first FAILURE_CAP (200)
%                              of them, in batch order (a sample; the counts
%                              above are exact)
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
for k = 1:numel(final)
    finalIds{k} = idOf(final{k});
end

report = struct('sources_inspected', numel(bodies), 'final_documents', numel(final), ...
    'sources_quarantined', 0, 'ids_kept', 0, 'ids_lost', 0, ...
    'ids_lost_by_class', struct(), 'ids_lost_ids', {{}}, 'sources_without_id', 0, ...
    'sources_compared', 0, 'sources_ok', 0, ...
    'sources_changed_by_batch_pass', 0, 'changed_by_class', struct(), ...
    'sources_no_inverse', 0, 'no_inverse_by_class', struct(), ...
    'unattributed_documents', 0, 'failures_total', 0, 'failures_by_class', struct(), ...
    'failures', struct('source_id', {}, 'class_name', {}, 'lost', {}, ...
        'invented', {}, 'unplaced', {}), 'ok', false);
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
    try
        c = did2.convert.roundtrip.check(v1, final(where));
    catch err
        if strcmp(err.identifier, 'did2:convert:roundtrip:noInverse')
            report.sources_no_inverse = report.sources_no_inverse + 1;
            report.no_inverse_by_class = bump(report.no_inverse_by_class, cls);
            continue;
        end
        rethrow(err);
    end
    report.sources_compared = report.sources_compared + 1;
    if c.ok
        report.sources_ok = report.sources_ok + 1;
    else
        report.failures_total = report.failures_total + 1;
        report.failures_by_class = bump(report.failures_by_class, cls);
        if numel(report.failures) < 200   % FAILURE_CAP
            lostPaths = {};
            if ~isempty(c.lost); lostPaths = {c.lost.path}; end
            report.failures(end+1) = struct('source_id', row.id, 'class_name', cls, ...
                'lost', {lostPaths}, 'invented', {c.invented}, 'unplaced', {c.unplaced});
        end
    end
end
report.unattributed_documents = nnz(~attributed);
report.ok = report.sources_ok == report.sources_compared && report.ids_lost == 0 ...
    && report.sources_changed_by_batch_pass == 0 && report.sources_no_inverse == 0;
end

% ===================== helpers =========================================

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

function id = idOf(d)
id = '';
try
    if isa(d, 'did2.document')
        id = char(d.get('base.id'));
    elseif isstruct(d) && isfield(d, 'base') && isfield(d.base, 'id')
        id = char(d.base.id);
    end
catch
    id = '';
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
