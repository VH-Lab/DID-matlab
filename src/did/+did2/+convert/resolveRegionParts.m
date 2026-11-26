function [result, report] = resolveRegionParts(result, options)
%RESOLVEREGIONPARTS Merge the copies of one region part; leave a side that
%   another v1 document gives where it is.
%
%   [RESULT, REPORT] = did2.convert.resolveRegionParts(RESULT) takes the struct
%   did2.convert.v1_to_v2 returns (after resolveDeferredBaths, which writes
%   bath parts) and does, over the whole batch, what pass 1 cannot:
%
%     1. MERGE. Pass 1 writes a treatment's (treatment, treatment_drug,
%        virus_injection; a deferred bath) region part in its final shape,
%        each of its documents with an id computed from (subject, region, side)
%        (did2.convert.regionPart, did2.convert.regionPartIds), so two source
%        documents naming one region of one subject write two copies of each
%        document under one id. Each id keeps ONE copy: the one from the
%        earliest source document (the earliest creation_timestamp, which is
%        the source's datestamp; then the session id; then the copy's JSON,
%        so the choice never depends on the order documents are read in). A
%        dropped copy that still differs from the kept one once the values it
%        took from its own source (its session and creation timestamp) are set
%        aside -- a region label spelled differently -- is counted, and the
%        kept copy stays.
%     2. A SIDE GIVEN BY ANOTHER DOCUMENT STAYS. A v1 document whose location
%        is a side (a laterality term, did2.convert.lateralityOf) names no
%        region, so pass 1 leaves it as a site observation about the subject,
%        co-anchored with the document's manipulation. It is NOT attached to
%        any region part ([side said about its region], below): a side
%        attaches to a part only when one v1 document names the region and
%        its side together, and pass 1 already builds that part with its
%        side. Every such side document is counted (sides_not_attached), and
%        of them those whose subject has exactly one unsided region part
%        (sides_not_attached_subject_has_one_unsided_part: the case the rule
%        before 2026-11-25 re-keyed that part with the side). Its site
%        observation stays (NDI's ndi.migrate.internal.pathSPromotion reads it,
%        and folds a side onto a part only within one source document).
%
%   DECIDED. did-schema did_v2_go_forward_class_audit.md: [duplicate parts
%   merged in DID] (Jess Haley, 2026-11-17: "a DID-matlab batch pass merges the
%   identical copies, so DID-matlab's own output never holds a duplicate id");
%   [part re-keyed when its side arrives] (2026-11-17: "a part computed without
%   a side and given its laterality later from another v1 document is
%   re-keyed, so its id always matches its content (subject, region, side)");
%   [region part ids computed] (2026-11-19): "(1) copies of one region part
%   minted from different source documents take their values from the earliest
%   source document, so they are identical; two copies with the same id that
%   still differ (for example a region label spelled differently) keep the
%   first and are counted; (2) a side given later by another v1 document
%   attaches to an existing part with no side only when the subject has
%   exactly one no-side part for that region, else it is not attached and is
%   counted; (3) the part, its kind assertion, its laterality assertion and its
%   `part_of` relation each take a computed document id from
%   `did2.convert.mintId` in a context keyed on `<subject id>|<region node,
%   lowercased>|side:<side node>`". [one part per side] (2026-10-21): a part
%   has one side.
%   [side said about its region] (Jess Haley, 2026-11-25) amends (2) of
%   [region part ids computed]: "a side attaches to a region part only when
%   the v1 document states it about that region (the region and its side
%   named together); a side stated about something else, such as a probe's
%   hemisphere, stays a statement about that thing and is never moved onto a
%   part, and no part is chosen because it is the subject's only unsided
%   one." So [part re-keyed when its side arrives] no longer happens here: no
%   part is re-keyed, nothing is added and no edge is renamed.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py.
%
%   BATCH-PASS-CONSUMES: NONE -- this pass reads no did_v1 source class. It
%       works on the region parts and site observations the per-document
%       migrators (treatment, treatment_drug, virus_injection) and
%       resolveDeferredBaths have already written, which are credited there.
%   BATCH-PASS-EMITS: NONE -- it drops duplicate copies of a region part's
%       documents; it builds no document.
%   ---------------------------------------------------------------------
%
%   WHAT IT READS AND WRITES (tools/batch_pass_order.py derives and checks the
%   pass order from these; [migration reliability practices] (c), Jess Haley,
%   2026-10-26). Read from this file's code, class by class.
%   (The side site observations and the manipulations co-anchored with them
%   are read only to count them, so they are not a read here.)
%   BATCH-PASS-READS: entity(pass-1 region part),
%       assertion(pass-1 region part kind),
%       assertion(pass-1 region part laterality),
%       directed_relation(pass-1 region part_of)
%   BATCH-PASS-ADDS: NONE -- [side said about its region] (2026-11-25): no
%       part is re-keyed, so no Laterality assertion is built
%   BATCH-PASS-CHANGES: entity(pass-1 region part),
%       assertion(pass-1 region part kind),
%       assertion(pass-1 region part laterality),
%       directed_relation(pass-1 region part_of)
%   BATCH-PASS-REMOVES: NONE -- it drops duplicate copies of a document that
%       stays (one copy per id, CHANGES); it folds no class away
%   The region parts it reads are the ones pass 1 and resolveDeferredBaths
%   write; the parts NDI's second pass mints later (pathSPromotion) take the
%   same computed ids and are found there, never copied, so this pass need
%   not see them.
%
%   REPORT (also RESULT.region_part_resolution), denominators first:
%     documents_inspected, region_part_documents_seen (the part entities,
%     kind and laterality assertions and part_of relations), parts_seen (part
%     entities), duplicate_ids (ids held by more than one copy),
%     duplicate_copies_dropped, duplicate_copies_differing (+
%     duplicate_ids_differing, at most 50), side_observations_seen (a side
%     site observation co-anchored with a manipulation about its entity;
%     side_observations_not_co_anchored, e.g. a probe_location's hemisphere,
%     are not side documents and are left as they are),
%     sides_not_attached (every side observation seen: none is attached,
%     [side said about its region]), sides_not_attached_subject_has_one_unsided_part
%     (of them, those whose subject has exactly one unsided region part),
%     documents_removed (the duplicate copies), migrated_before,
%     migrated_after, ran.
%
%   Options (name-value): Validate (default true), SchemaCache ([]),
%   TargetVersion ('did_v2') -- accepted as every batch pass takes them; this
%   pass builds no document, so nothing is validated.
%
%   See also did2.convert.regionPart, did2.convert.regionPartIds,
%            did2.convert.lateralityOf, ndi.migrate.internal.pathSPromotion.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char {mustBeMember(options.TargetVersion, {'did_v2'})} = 'did_v2'
end

% The T19 TermRegistry check is left as the caller set it (armed by default),
% so a term this pass builds that the registry does not hold is an error,
% did2:build:unregisteredTerm (it is still collected when
% did2.build.unregisteredTerms('-collect') is on). [early migration pieces
% fixed] item 3 (Jess Haley, 2026-10-26, did-schema
% did_v2_go_forward_class_audit.md; VH-Lab/DID-matlab#486): the check stays on
% during migration. This pass built no unregistered term on any corpus
% (DID-matlab V2 f1a781b8, Test code run 45635644069, Soph run 45706973786), so
% it no longer turns the check off; did2.convert.v1_to_v2 still does.

report = struct( ...
    'documents_inspected',               0, ...
    'documents_unreadable',              0, ...
    'region_part_documents_seen',        0, ...
    'parts_seen',                        0, ...
    'duplicate_ids',                     0, ...
    'duplicate_copies_dropped',          0, ...
    'duplicate_copies_differing',        0, ...
    'duplicate_ids_differing',           {{}}, ...
    'side_observations_seen',            0, ...
    'side_observations_not_co_anchored', 0, ...
    'sides_not_attached',                0, ...
    'sides_not_attached_subject_has_one_unsided_part', 0, ...
    'documents_removed',                 0, ...
    'migrated_before',                   0, ...
    'migrated_after',                    0, ...
    'ran',                               false);
result.region_part_resolution = report;
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.region_part_resolution = report;
    return;
end
report.ran = true;
docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;
report.migrated_before = n;

% ---- read: the region-part documents and the side observations ----------
role = repmat({''}, 1, n);   % 'part' | 'kind' | 'laterality' | 'part_of' | 'side' | 'manip'
S = cell(1, n);
ids = repmat({''}, 1, n);
for k = 1:n
    try
        cls = docs{k}.className();
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    if ~any(strcmp(cls, {'entity', 'assertion', 'directed_relation', ...
            'observation', 'manipulation'}))
        continue;
    end
    try
        s = docs{k}.toStruct();
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    r = roleOf(cls, s);
    if isempty(r); continue; end
    role{k} = r;
    S{k} = s;
    ids{k} = baseId(s);
end
% a side observation is a treatment's (or a bath's) only when a manipulation
% about the same entity shares its anchor (one source document wrote both,
% as NDI's pathSPromotion reads them); one about a probe (a probe_location's
% hemisphere) is no side of a subject's part, and is left for NDI's
% pathSPromotion 'located' mode, counted
anchored = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = find(strcmp(role, 'manip'))
    a = firstAnchor(S{k});
    if ~isempty(a); anchored([edgeValue(S{k}, 'entity_id') '|' a]) = true; end
end
for k = find(strcmp(role, 'side'))
    if ~isKey(anchored, [edgeValue(S{k}, 'entity_id') '|' firstAnchor(S{k})])
        role{k} = '';
        S{k} = [];
        ids{k} = '';
        report.side_observations_not_co_anchored = ...
            report.side_observations_not_co_anchored + 1;
    end
end
isPartDoc = ismember(role, {'part', 'kind', 'laterality', 'part_of'});
report.region_part_documents_seen = nnz(isPartDoc);
report.parts_seen = nnz(strcmp(role, 'part'));
report.side_observations_seen = nnz(strcmp(role, 'side'));
keep = true(1, n);

% ---- 1. merge: one copy per id, the earliest source's -------------------
byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = find(isPartDoc)
    if isempty(ids{k}); continue; end
    if isKey(byId, ids{k}); byId(ids{k}) = [byId(ids{k}), k]; else; byId(ids{k}) = k; end
end
dupIds = byId.keys;
for i = 1:numel(dupIds)
    ks = byId(dupIds{i});
    if numel(ks) < 2; continue; end
    report.duplicate_ids = report.duplicate_ids + 1;
    first = earliest(S, ks);
    differs = false;
    for k = ks
        if k == first; continue; end
        keep(k) = false;
        report.duplicate_copies_dropped = report.duplicate_copies_dropped + 1;
        if ~sameCopy(S{first}, S{k})
            differs = true;
            report.duplicate_copies_differing = report.duplicate_copies_differing + 1;
        end
    end
    if differs && numel(report.duplicate_ids_differing) < 50
        report.duplicate_ids_differing{end+1} = dupIds{i};
    end
end

% ---- 2. a side another document gives stays where it is ----------------
% [side said about its region] (Jess Haley, 2026-11-25) amends (2) of [region
% part ids computed]: a side attaches to a region part only when the v1
% document states it about that region (the region and its side named
% together, which pass 1 builds: did2.convert.regionPart); a side document
% that names no region stays the site observation pass 1 wrote, and no part is
% chosen because it is the subject's only unsided one. Counted: every such
% side document, and of them those whose subject has exactly one unsided
% region part (the case the old rule attached).
partOf = containers.Map('KeyType', 'char', 'ValueType', 'any');     % part id -> parent
kindOf = containers.Map('KeyType', 'char', 'ValueType', 'double');  % part id -> kind index
sided  = containers.Map('KeyType', 'char', 'ValueType', 'logical'); % part id -> has a side
for k = find(keep & isPartDoc)
    switch role{k}
        case 'part_of'
            [ch, pa] = relationEnds(S{k});
            if ~isempty(ch); partOf(ch) = pa; end
        case 'kind'
            a = edgeValue(S{k}, 'entity_id');
            if ~isempty(a); kindOf(a) = k; end
        case 'laterality'
            a = edgeValue(S{k}, 'entity_id');
            if ~isempty(a); sided(a) = true; end
    end
end
% the number of unsided region parts of each subject
noSide = containers.Map('KeyType', 'char', 'ValueType', 'double');  % subject -> count
for k = find(keep & strcmp(role, 'part'))
    p = ids{k};
    if ~isKey(partOf, p) || ~isKey(kindOf, p) || isKey(sided, p); continue; end
    [~, kindIsSide] = did2.convert.lateralityOf(termValue(S{kindOf(p)}));
    if kindIsSide; continue; end
    x = partOf(p);
    if isKey(noSide, x); noSide(x) = noSide(x) + 1; else; noSide(x) = 1; end
end
for k = find(keep & strcmp(role, 'side'))
    report.sides_not_attached = report.sides_not_attached + 1;
    x = edgeValue(S{k}, 'entity_id');
    if ~isempty(x) && isKey(noSide, x) && noSide(x) == 1
        report.sides_not_attached_subject_has_one_unsided_part = ...
            report.sides_not_attached_subject_has_one_unsided_part + 1;
    end
end

report.documents_removed = nnz(~keep);
result.migrated = reshape(docs(keep), 1, []);
report.migrated_after = numel(result.migrated);
result.region_part_resolution = report;
end

% ===================== roles ===========================================

function r = roleOf(cls, s)
r = '';
switch cls
    case 'entity'
        if isTissue(s); r = 'part'; end
    case 'assertion'
        v = variableNode(s);
        if strcmpi(v, 'UBERON:0000061')
            r = 'kind';
        elseif strcmpi(v, 'NCIT:C25185')
            r = 'laterality';
        end
    case 'directed_relation'
        if isfield(s, 'directed_relation') && isstruct(s.directed_relation) ...
                && isfield(s.directed_relation, 'relation')
            t = s.directed_relation.relation;
            nm = '';
            if isstruct(t) && isfield(t, 'name'); nm = char(t.name);
            elseif ischar(t) || isstring(t); nm = char(t); end
            if strcmpi(strtrim(nm), 'part_of') || strcmpi(strtrim(nm), 'part of')
                r = 'part_of';
            end
        end
    case 'observation'
        if strcmpi(variableNode(s), 'NCIT:C13717')
            [~, isSide] = did2.convert.lateralityOf(termValue(s));
            if isSide; r = 'side'; end
        end
    case 'manipulation'
        r = 'manip';
end
end

function tf = isTissue(s)
tf = false;
if ~isfield(s, 'entity') || ~isstruct(s.entity) || ~isfield(s.entity, 'type')
    return;
end
t = s.entity.type;
if isstruct(t)
    nm = ''; nd = '';
    if isfield(t, 'name'); nm = char(t.name); end
    if isfield(t, 'node'); nd = char(t.node); end
    tf = strcmpi(strtrim(nm), 'tissue') || strcmpi(strtrim(nd), 'UBERON:0000479');
elseif ischar(t) || isstring(t)
    tf = strcmpi(strtrim(char(t)), 'tissue');
end
end

function v = variableNode(s)
v = '';
if isfield(s, 'statement') && isstruct(s.statement) && isfield(s.statement, 'variable')
    t = s.statement.variable;
    if isstruct(t) && isfield(t, 'node') && ~isempty(t.node)
        v = strtrim(char(t.node));
    end
end
end

function t = termValue(s)
t = struct('node', '', 'name', '');
if isfield(s, 'term') && isstruct(s.term) && isfield(s.term, 'value') ...
        && isstruct(s.term.value) && ~isempty(s.term.value)
    x = s.term.value(1);
    if isfield(x, 'node'); t.node = char(x.node); end
    if isfield(x, 'name'); t.name = char(x.name); end
end
end

% ===================== the earliest copy ===============================

function first = earliest(S, ks)
%EARLIEST The index in KS of the copy from the earliest source: the earliest
%   creation_timestamp, then the session id, then the JSON text (no tie is
%   left to reading order).
keys = cell(1, numel(ks));
for j = 1:numel(ks)
    s = S{ks(j)};
    ts = '';
    if isfield(s, 'base') && isfield(s.base, 'creation_timestamp')
        ts = char(s.base.creation_timestamp);
    end
    sid = edgeValue(s, 'session_id');
    if isempty(sid) && isfield(s, 'base') && isfield(s.base, 'session_id')
        sid = char(s.base.session_id);
    end
    keys{j} = sprintf('%s\t%s\t%s', ts, sid, jsonencode(s));
end
[~, o] = sort(keys);
first = ks(o(1));
end

function tf = sameCopy(a, b)
%SAMECOPY A and B are one document once the values each took from its own
%   source (session, creation timestamp) are set aside.
tf = isequaln(neutral(a), neutral(b));
end

function s = neutral(s)
if isfield(s, 'base') && isstruct(s.base)
    if isfield(s.base, 'creation_timestamp'); s.base.creation_timestamp = ''; end
    if isfield(s.base, 'session_id'); s.base.session_id = ''; end
end
s = setEdge(s, 'session_id', '');
end

% ===================== edges ===========================================

function id = baseId(s)
id = '';
if isfield(s, 'base') && isstruct(s.base) && isfield(s.base, 'id') && ~isempty(s.base.id)
    id = char(s.base.id);
end
end

function [deps, valueField] = edgeList(s)
deps = struct('name', {}, 'value', {});
valueField = 'value';
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
deps = s.depends_on;
if iscell(deps)
    deps = [deps{:}];
end
if ~isempty(deps) && ~isfield(deps, 'value') && isfield(deps, 'document_id')
    valueField = 'document_id';
end
end

function v = edgeValue(s, name)
v = '';
[deps, f] = edgeList(s);
for k = 1:numel(deps)
    if strcmp(char(deps(k).name), name) && ~isempty(deps(k).(f))
        v = char(deps(k).(f));
        return;
    end
end
end

function a = firstAnchor(s)
a = edgeValue(s, 'time_reference_id');
end

function [ch, pa] = relationEnds(s)
ch = edgeValue(s, 'child_id');
pa = edgeValue(s, 'parent_id');
end

function s = setEdge(s, name, value)
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    if ~isempty(value)
        s.depends_on = struct('name', name, 'value', value);
    end
    return;
end
wasCell = iscell(s.depends_on);
deps = s.depends_on;
if wasCell; deps = [deps{:}]; end
f = 'value';
if ~isfield(deps, 'value') && isfield(deps, 'document_id'); f = 'document_id'; end
for k = 1:numel(deps)
    if strcmp(char(deps(k).name), name)
        deps(k).(f) = value;
    end
end
if wasCell; deps = num2cell(deps); end
s.depends_on = deps;
end
