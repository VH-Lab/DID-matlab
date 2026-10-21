function block = failureDocuments(result)
%FAILUREDOCUMENTS Name the documents behind a corpus run's failure counters.
%
%   BLOCK = did2.unittest.helpers.failureDocuments(RESULT) returns the
%   `failure_documents` block of a corpus report: for each failure kind, the
%   document ids that tools/extract_failure_fixtures.py needs to lift the
%   failing v1 source documents into a quick-suite fixture.
%
%   Until this block the report carried COUNTS for three of the four kinds
%   (quarantine by reason, fragments by class, empty required edges by class
%   and edge) and ids only for orphans, so reproducing a corpus failure meant
%   re-running the corpus. The counts stay where they were and remain the
%   census; this block is the pointer from a count to its documents.
%
%   Kinds and what their id means:
%     quarantine           `source_id`: the v1 base.id (from original_body)
%     fragment             `source_id`: the v1 base.id
%     orphan               `doc_id`: the MIGRATED document's base.id (often,
%                          not always, the v1 id) and `edge_document_id`
%     empty_required_edge  `doc_id`: the MIGRATED document's base.id
%
%   Every list is capped and the cap is stated beside the complete count, so a
%   truncated list never reads as the whole set. A kind whose source field is
%   absent from RESULT is written as `not_measured`, never as an empty list.

cap = 2000;
block = struct();
block.cap = cap;

% --- quarantine -----------------------------------------------------------
q = struct('source_id', {}, 'class_name', {}, 'identifier', {});
if isfield(result, 'quarantine')
    nq = numel(result.quarantine);
    for k = 1:min(nq, cap)
        e = result.quarantine(k);
        q(end+1) = struct('source_id', idFromJson(e.original_body), ... %#ok<AGROW>
            'class_name', char(e.class_name), 'identifier', char(e.identifier));
    end
    block.quarantine_count = nq;
    block.quarantine = q;
else
    block.quarantine = 'not_measured';
end

% --- fragments -------------------------------------------------------------
if isfield(result, 'summary') && isfield(result.summary, 'fragment_source_ids')
    ids = result.summary.fragment_source_ids;
    block.fragment_count = numel(ids);
    block.fragment = ids(1:min(numel(ids), cap));
else
    block.fragment = 'not_measured';
end

% --- orphans (the reference-integrity block's own capped sample) ----------
o = struct('doc_id', {}, 'doc_class', {}, 'edge_name', {}, 'edge_document_id', {});
if isfield(result, 'reference_integrity') && isfield(result.reference_integrity, 'orphans')
    ri = result.reference_integrity;
    for k = 1:numel(ri.orphans)
        r = ri.orphans(k);
        o(end+1) = struct('doc_id', char(r.doc_id), 'doc_class', char(r.doc_class), ... %#ok<AGROW>
            'edge_name', char(r.edge_name), 'edge_document_id', char(r.edge_document_id));
    end
    block.orphan_count = ri.orphan_count;
    block.orphan = o;
else
    block.orphan = 'not_measured';
end

% --- empty required edges (silentLoss's capped per-document sample) -------
if isfield(result, 'silent_loss') && isfield(result.silent_loss, 'empty_required_dependency_docs')
    sl = result.silent_loss;
    block.empty_required_edge_count = sl.empty_dependency_count;
    block.empty_required_edge = sl.empty_required_dependency_docs;
else
    block.empty_required_edge = 'not_measured';
end
end

function id = idFromJson(txt)
id = '';
try
    if isstruct(txt)
        b = txt;
    else
        b = jsondecode(char(txt));
    end
    if isfield(b, 'base') && isfield(b.base, 'id')
        id = char(b.base.id);
    end
catch
end
end
