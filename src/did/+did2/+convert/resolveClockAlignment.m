function [result, report] = resolveClockAlignment(result, options)
%RESOLVECLOCKALIGNMENT V_eta second pass: un-gate the `syncgraph` fold.
%
%   [RESULT, REPORT] = did2.convert.resolveClockAlignment(RESULT) takes the
%   struct returned by did2.convert.v1_to_v2 (after the sibling post-passes) and
%   folds every `syncgraph` document that passed pass 1 through into a
%   `clock_alignment_policy`, anchored to the SESSION DOCUMENT, with base.id
%   PRESERVED. REPORT is also attached as RESULT.clock_alignment_fold.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py.
%
%   BATCH-PASS-CONSUMES: syncgraph
%   BATCH-PASS-EMITS: syncgraph -> document: clock_alignment_policy
%
%   NO ROW FOR `syncrule`. A file-based `syncrule` (a filematch rule) reaches its
%   `clock_alignment_configuration` in PASS 1 -- `clock_alignment_configuration`
%   declares no `session_id`, so its migrator needs no session lookup and no
%   batch pass. Only `syncgraph` gates on the session, because
%   `clock_alignment_policy.session_id` is REQUIRED and names the session
%   DOCUMENT's base.id, which a single-document migrator cannot resolve.
%
%   ---------------------------------------------------------------------
%   WHY A BATCH PASS, AND WHY THIS ONE RATHER THAN A ROW IN epochMint
%   ---------------------------------------------------------------------
%   `+migrators_j/syncgraph.m` emits the policy when `jSessionDocId(preBody)`
%   returns a non-empty id, and that helper answers '' for every did_v1 document
%   by construction: mapping `base.session_id` to the session document's base.id
%   is a corpus-wide lookup (ndi.document.m:57 mints base.id fresh;
%   ndi.session.m:215 stamps base.session_id separately), which is exactly what
%   this pass supplies. The seam is a stamped `session_document_id` dependency,
%   the sibling of the `epoch_id` stamp jEpochDocId reads -- see
%   +migrators_j/private/jSessionDocId.m.
%
%   epochMint ALREADY builds this session index (for `epoch.session_id`), so this
%   fold could in principle be a third arming row there. It is a separate pass
%   instead because epochMint's arming stamps an `epoch_id` edge, and this fold
%   needs a `session_document_id` stamp -- a different index and a different edge.
%   Bolting a second edge onto that already-large armed loop would couple two
%   folds that fail for different reasons; resolveSessionAnchors is the structural
%   precedent this mirrors (it builds the same session index and folds by base.id).
%
%   ---------------------------------------------------------------------
%   REFUSAL, NOT INVENTION
%   ---------------------------------------------------------------------
%   A syncgraph is FOLDED only when its session id resolves to exactly one
%   session document. Every refusal is counted with a named reason, never turned
%   into an empty edge:
%       no `base.session_id`                  -> refused_no_session_id
%       no `session` document claims that id  -> refused_no_session_document
%       two `session` documents claim it      -> refused_ambiguous_session
%       the migrator declined after the stamp -> refused_migrator_declined
%   A refused syncgraph keeps the passthrough it had. base.id is preserved on
%   both branches, so `syncrule_mapping`'s `syncgraph_id` edge -- and the live NDI
%   query on it -- resolves either way.
%
%   STATUS: WRITTEN 2026-08-18 IN A CONTAINER WITH NO MATLAB. NOT ONE LINE OF
%   THIS FILE HAS BEEN EXECUTED. test-migrators-quick.yml and the V_eta e2e are
%   the first things with an opinion.
%
%   See also: did2.convert.resolveSessionAnchors, did2.convert.epochMint,
%   did2.convert.migrators_j.syncgraph.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

report = struct( ...
    'documents_inspected',          0, ...
    'documents_unreadable',         0, ...
    'session_documents_seen',       0, ...
    'syncgraphs_seen',              0, ...
    'refused_no_session_id',        0, ...
    'refused_no_session_document',  0, ...
    'refused_ambiguous_session',    0, ...
    'refused_migrator_declined',    0, ...
    'refused_total',                0, ...
    'policies_folded',              0, ...
    'extra_bodies_emitted',         0, ...
    'fold_quarantined',             0, ...
    'ran',                          false);
result.clock_alignment_fold = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % `clock_alignment_policy` exists only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.clock_alignment_fold = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ---------------------------------------------
% A document this cannot read is COUNTED, never dropped -- the silentLoss rule.
bodies    = cell(1, n);
classes   = cell(1, n);
sessionId = cell(1, n);
docId     = cell(1, n);
for k = 1:n
    classes{k} = ''; sessionId{k} = ''; docId{k} = '';
    try
        b = docs{k}.toStruct();
        bodies{k}    = b;
        classes{k}   = classNameOf(b);
        sessionId{k} = baseField(b, 'session_id');
        docId{k}     = baseField(b, 'id');
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- index the session documents (base.session_id -> session doc base.id) --
sessionDocId    = containers.Map('KeyType', 'char', 'ValueType', 'char');
sessionDocCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~strcmp(classes{k}, 'session'); continue; end
    report.session_documents_seen = report.session_documents_seen + 1;
    sid = sessionId{k};
    if isempty(sid) || isempty(docId{k}); continue; end
    if isKey(sessionDocCount, sid)
        sessionDocCount(sid) = sessionDocCount(sid) + 1;
    else
        sessionDocCount(sid) = 1;
        sessionDocId(sid) = docId{k};
    end
end

% --- fold every syncgraph whose session resolves ---------------------------
changedIdx = [];       % index into docs of a syncgraph being replaced
rebuilt = {};          % the stamped-and-refolded bodies awaiting validation
primaryOf = {};        % base.id of the policy that must come back out per changedIdx
for k = 1:n
    if ~strcmp(classes{k}, 'syncgraph'); continue; end
    report.syncgraphs_seen = report.syncgraphs_seen + 1;

    sid = sessionId{k};
    if isempty(sid)
        report.refused_no_session_id = report.refused_no_session_id + 1;
        continue;
    end
    if ~isKey(sessionDocId, sid)
        report.refused_no_session_document = report.refused_no_session_document + 1;
        continue;
    end
    if sessionDocCount(sid) > 1
        report.refused_ambiguous_session = report.refused_ambiguous_session + 1;
        continue;
    end

    stamped = stampSessionDocument(bodies{k}, sessionDocId(sid));
    folded  = did2.convert.migrators_j.syncgraph(stamped);
    % The migrator DECLINED if it handed the (stamped) body straight back -- it
    % returns {preBody} on any guard it cannot pass. That must not be counted as
    % a fold: it would replace the passthrough with the SAME body carrying a
    % `session_document_id` dep the class does not declare, which validateDocument
    % would then quarantine. Detect it by class of the first body.
    if numel(folded) == 1 && strcmp(classNameOf(folded{1}), 'syncgraph')
        report.refused_migrator_declined = report.refused_migrator_declined + 1;
        continue;
    end

    for j = 1:numel(folded)
        rebuilt{end+1} = folded{j};      %#ok<AGROW>
    end
    changedIdx(end+1) = k;               %#ok<AGROW>
    primaryOf{end+1}  = docId{k};        %#ok<AGROW> policy preserves the syncgraph base.id
end

report.refused_total = report.refused_no_session_id ...
    + report.refused_no_session_document ...
    + report.refused_ambiguous_session ...
    + report.refused_migrator_declined;

if isempty(changedIdx)
    result.clock_alignment_fold = report;
    return;
end

% --- validate through the same door every other pass uses ------------------
% The bodies are tagged schema_version == TargetVersion, so v1_to_v2
% short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate. A body
% that cannot validate lands in `quarantine` and the ORIGINAL syncgraph is kept,
% so a bad fold degrades to "not folded" rather than to a lost document.
out = did2.convert.v1_to_v2(rebuilt, ...
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

% Match the PRIMARY policy on base.id (the syncgraph's, preserved) and swap it
% into the syncgraph's slot; every OTHER produced body (the `software` entity,
% new id, no slot) is APPENDED. A quarantined primary leaves the original in
% place. This is the resolveDeferred / resolveSessionAnchors contract.
producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
consumed = false(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    try
        producedById(char(out.migrated{k}.get('base.id'))) = k;
    catch
    end
end
folded = 0;
for j = 1:numel(changedIdx)
    id = primaryOf{j};
    if ~isempty(id) && isKey(producedById, id)
        idx = producedById(id);
        docs{changedIdx(j)} = out.migrated{idx};
        consumed(idx) = true;
        folded = folded + 1;
    end
end
% APPEND every produced body that was not a primary swap (the software entities).
extra = 0;
for k = 1:numel(out.migrated)
    if consumed(k); continue; end
    docs{end+1} = out.migrated{k};  %#ok<AGROW>
    extra = extra + 1;
end
report.policies_folded = folded;
report.extra_bodies_emitted = extra;

result.migrated = docs;
result.summary = recountSummary(result);
result.clock_alignment_fold = report;
end

% ===================== helpers =============================================

function b = stampSessionDocument(body, sessionDocumentId)
%STAMPSESSIONDOCUMENT Add the `session_document_id` dep jSessionDocId reads.
%   Deliberately a DIFFERENT name from `session_id`: `base.session_id` and the
%   edge `session_id` both already exist and mean the other thing. The migrator
%   sets `clock_alignment_policy.session_id` BY NAME from the resolved id and
%   never copies preBody.depends_on wholesale, so this transient stamp does not
%   reach the emitted policy -- it is read and discarded.
b = body;
dep = struct('name', 'session_document_id', 'value', sessionDocumentId);
if ~isfield(b, 'depends_on') || isempty(b.depends_on)
    b.depends_on = dep;
    return;
end
d = b.depends_on;
if isstruct(d)
    % Normalise to a 1xN struct array with the SAME fields, then append.
    if ~isfield(d, 'name');  [d.name]  = deal(''); end
    if ~isfield(d, 'value'); [d.value] = deal(''); end
    keep = struct('name', {d.name}, 'value', {d.value});
    b.depends_on = [keep, dep];
else
    b.depends_on = dep;   % a malformed edge list is replaced by the one we need
end
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
    v = char(b.base.(name));
end
end

function summary = recountSummary(result)
% Recompute migrated/quarantine counts and by_class after the fold. `total`
% keeps its meaning (source bodies read); `unconverted_*` are left untouched --
% they are the pass-1 measurement and this pass is not pass 1.
summary = result.summary;
summary.migrated_count = numel(result.migrated);
if isfield(result, 'quarantine')
    summary.quarantine_count = numel(result.quarantine);
end
byClass = struct();
for k = 1:numel(result.migrated)
    try
        name = result.migrated{k}.className();
    catch
        continue;
    end
    fieldName = matlab.lang.makeValidName(name);
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end
