function [result, report] = resolveRegionParts(result, options)
%RESOLVEREGIONPARTS Merge the copies of one region part; attach a side that
%   another v1 document gives.
%
%   [RESULT, REPORT] = did2.convert.resolveRegionParts(RESULT) takes the struct
%   did2.convert.v1_to_v2 returns (after resolveDeferredBaths, which writes
%   bath parts) and does, over the whole batch, the two things pass 1 cannot:
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
%     2. A SIDE GIVEN LATER. A v1 document whose location is a side (a
%        laterality term, did2.convert.lateralityOf) names no region, so pass 1
%        leaves it as a site observation about the subject, co-anchored with
%        the document's manipulation. It attaches to the subject's region part
%        that has no side when the subject has EXACTLY ONE such part (and
%        every side document of the subject gives the same side): the part is
%        RE-KEYED, its documents taking the ids computed for (subject, region,
%        side), it gains its Laterality assertion, every edge naming an old id
%        names the new one, the side observation is removed and the side
%        document's manipulations move onto the part. Otherwise the side is
%        not attached and is counted, and its site observation stays (NDI's
%        ndi.migrate.internal.pathSPromotion reads it in production).
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
%   has one side, so a subject whose side documents give two sides attaches
%   neither (counted).
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
%   BATCH-PASS-EMITS: NONE -- it drops duplicate copies and re-keys a part;
%       the one document it builds (a re-keyed part's Laterality assertion) is
%       of a class the migrators already write for that part.
%   ---------------------------------------------------------------------
%
%   WHAT IT READS AND WRITES (tools/batch_pass_order.py derives and checks the
%   pass order from these; [migration reliability practices] (c), Jess Haley,
%   2026-10-26). Read from this file's code, class by class.
%   BATCH-PASS-READS: entity(pass-1 region part),
%       assertion(pass-1 region part kind),
%       assertion(pass-1 region part laterality),
%       directed_relation(pass-1 region part_of), observation(side site),
%       manipulation(of a side site's source)
%   BATCH-PASS-ADDS: assertion(re-keyed region part laterality)
%   BATCH-PASS-CHANGES: entity(pass-1 region part),
%       assertion(pass-1 region part kind),
%       directed_relation(pass-1 region part_of), observation(side site),
%       manipulation(of a side site's source)
%   BATCH-PASS-REMOVES: NONE -- it drops duplicate copies of a document that
%       stays (one copy per id) and the side observations it attaches
%       (CHANGES); it folds no class away
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
%     sides_attached, sides_not_attached_no_part,
%     sides_not_attached_several_parts, sides_not_attached_several_sides,
%     parts_rekeyed, parts_rekeyed_onto_existing_part, edges_renamed,
%     manipulations_retargeted, documents_removed, documents_added,
%     rekey_quarantined (a re-keyed document that did not validate: the
%     subject's re-key is not applied), migrated_before, migrated_after, ran.
%
%   Options (name-value): Validate (default true), SchemaCache ([]),
%   TargetVersion ('did_v2') -- forwarded to the v1_to_v2 refold of the
%   re-keyed documents.
%
%   See also did2.convert.regionPart, did2.convert.regionPartIds,
%            did2.convert.lateralityOf, ndi.migrate.internal.pathSPromotion.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char {mustBeMember(options.TargetVersion, {'did_v2'})} = 'did_v2'
end

prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>

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
    'sides_attached',                    0, ...
    'sides_not_attached_no_part',        0, ...
    'sides_not_attached_several_parts',  0, ...
    'sides_not_attached_several_sides',  0, ...
    'parts_rekeyed',                     0, ...
    'parts_rekeyed_onto_existing_part',  0, ...
    'edges_renamed',                     0, ...
    'manipulations_retargeted',          0, ...
    'documents_removed',                 0, ...
    'documents_added',                   0, ...
    'rekey_quarantined',                 0, ...
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

keepMerge = keep;

% ---- 2. a side given later ----------------------------------------------
% every decision below is made on the batch as pass 1 left it (after the
% merge), subject by subject, so it does not depend on the order of reading
partOf = containers.Map('KeyType', 'char', 'ValueType', 'any');     % part id -> parent
relOf  = containers.Map('KeyType', 'char', 'ValueType', 'double');  % part id -> relation index
kindOf = containers.Map('KeyType', 'char', 'ValueType', 'double');  % part id -> kind index
sided  = containers.Map('KeyType', 'char', 'ValueType', 'logical'); % part id -> has a side
present = containers.Map('KeyType', 'char', 'ValueType', 'double'); % any kept id -> index
for k = find(keep)
    if ~isempty(ids{k}); present(ids{k}) = k; end
end
for k = find(keep & isPartDoc)
    switch role{k}
        case 'part_of'
            [ch, pa] = relationEnds(S{k});
            if ~isempty(ch); partOf(ch) = pa; relOf(ch) = k; end
        case 'kind'
            a = edgeValue(S{k}, 'entity_id');
            if ~isempty(a); kindOf(a) = k; end
        case 'laterality'
            a = edgeValue(S{k}, 'entity_id');
            if ~isempty(a); sided(a) = true; end
    end
end
% the subject's no-side region parts
noSide = containers.Map('KeyType', 'char', 'ValueType', 'any');     % subject -> part ids
for k = find(keep & strcmp(role, 'part'))
    p = ids{k};
    if ~isKey(partOf, p) || ~isKey(kindOf, p) || isKey(sided, p); continue; end
    [~, kindIsSide] = did2.convert.lateralityOf(termValue(S{kindOf(p)}));
    if kindIsSide; continue; end
    x = partOf(p);
    if isKey(noSide, x); noSide(x) = [noSide(x), {p}]; else; noSide(x) = {p}; end
end
% the side observations, by subject
sidesOf = containers.Map('KeyType', 'char', 'ValueType', 'any');    % subject -> indices
for k = find(keep & strcmp(role, 'side'))
    x = edgeValue(S{k}, 'entity_id');
    if isempty(x); continue; end
    if isKey(sidesOf, x); sidesOf(x) = [sidesOf(x), k]; else; sidesOf(x) = k; end
end
subjects = sort(sidesOf.keys);
% each side observation's siblings: the other documents its source became
siblingsOf = cell(1, n);
if sidesOf.Count > 0 && isfield(result, 'source_outputs') && ~isempty(result.source_outputs)
    sideAt = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for k = find(keep & strcmp(role, 'side'))
        if ~isempty(ids{k}); sideAt(ids{k}) = k; end
    end
    for r = 1:numel(result.source_outputs)
        out = result.source_outputs(r).output_ids;
        if ischar(out); out = {out}; end
        hit = 0;
        for j = 1:numel(out)
            if isKey(sideAt, char(out{j})); hit = sideAt(char(out{j})); break; end
        end
        if hit == 0; continue; end
        sib = [];
        for j = 1:numel(out)
            if isKey(present, char(out{j})); sib(end+1) = present(char(out{j})); end %#ok<AGROW>
        end
        siblingsOf{hit} = sib;
    end
end
renames = containers.Map('KeyType', 'char', 'ValueType', 'char');   % old id -> new id
moveTo = containers.Map('KeyType', 'double', 'ValueType', 'char');  % manipulation index -> part
added = {};
changedIdx = [];
for q = 1:numel(subjects)
    x = subjects{q};
    ks = sidesOf(x);
    sideKeys = cell(1, numel(ks));
    for j = 1:numel(ks)
        t = termValue(S{ks(j)});
        sideKeys{j} = lower(strtrim(char(t.node)));
    end
    parts = {};
    if isKey(noSide, x); parts = noSide(x); end
    if isempty(parts)
        report.sides_not_attached_no_part = report.sides_not_attached_no_part + numel(ks);
        continue;
    elseif numel(parts) > 1
        report.sides_not_attached_several_parts = ...
            report.sides_not_attached_several_parts + numel(ks);
        continue;
    elseif numel(unique(sideKeys)) > 1
        report.sides_not_attached_several_sides = ...
            report.sides_not_attached_several_sides + numel(ks);
        continue;
    end
    p = parts{1};
    pk = present(p);
    kk = kindOf(p);
    rk = relOf(p);
    sideDoc = S{earliest(S, ks)};
    sideTerm = termValue(sideDoc);
    area = termValue(S{kk});
    nid = did2.convert.regionPartIds(x, area, sideTerm);
    % the side documents' manipulations: the manipulations about the subject
    % the same source document became (RESULT.source_outputs); for a side
    % observation no source row names (a deferred bath's), the manipulations
    % about the subject on its anchor, as NDI's pathSPromotion reads them
    hits = [];
    for j = 1:numel(ks)
        sib = siblingsOf{ks(j)};
        if isempty(sib)
            hits = [hits, coAnchored(S, role, keep, x, firstAnchor(S{ks(j)}))]; %#ok<AGROW>
        else
            for h = sib
                if keep(h) && strcmp(role{h}, 'manip') && strcmp(edgeValue(S{h}, 'entity_id'), x)
                    hits(end+1) = h; %#ok<AGROW>
                end
            end
        end
    end
    hits = unique(hits);
    if isKey(present, nid.part)
        % the sided part is already in the batch: the no-side part becomes it
        report.parts_rekeyed_onto_existing_part = report.parts_rekeyed_onto_existing_part + 1;
        keep([pk kk rk]) = false;
        renames(p) = nid.part;
        renames(ids{kk}) = nid.kind;
        renames(ids{rk}) = nid.relation;
    else
        ent = S{pk};
        ent.base.id = nid.part;
        ent.entity.local_identifier = nid.local_identifier;
        kind = S{kk};
        kind.base.id = nid.kind;
        rel = S{rk};
        rel.base.id = nid.relation;
        renames(p) = nid.part;
        renames(ids{kk}) = nid.kind;
        renames(ids{rk}) = nid.relation;
        S{pk} = ent; S{kk} = kind; S{rk} = rel;
        changedIdx = [changedIdx, pk, kk, rk]; %#ok<AGROW>
        sid = edgeValue(ent, 'session_id');
        if isempty(sid) && isfield(ent.base, 'session_id'); sid = char(ent.base.session_id); end
        ts = '';
        if isfield(ent.base, 'creation_timestamp'); ts = char(ent.base.creation_timestamp); end
        added{end+1} = did2.build.statement('assertion', nid.part, ...
            did2.convert.registeredTerm('NCIT:C25185', 'Laterality'), sideTerm, ...
            'ValueKind', 'term', 'Id', nid.laterality, 'SessionId', sid, ...
            'CreationTimestamp', ts, 'Validate', false); %#ok<AGROW>
        report.parts_rekeyed = report.parts_rekeyed + 1;
    end
    keep(ks) = false;   % the side is now the part's Laterality assertion
    report.sides_attached = report.sides_attached + numel(ks);
    for h = hits
        moveTo(h) = nid.part;
    end
end

% ---- apply the renames and moves ---------------------------------------
if renames.Count > 0 || moveTo.Count > 0
    for k = find(keep)
        if isempty(S{k}) && renames.Count == 0; continue; end
        if isempty(S{k})
            % an edge naming an old id may sit on any document
            try
                deps = docs{k}.get('depends_on');
            catch
                continue;
            end
            if ~namesAny(deps, renames); continue; end
            S{k} = docs{k}.toStruct();
        end
        [s, nRen] = renameEdges(S{k}, renames);
        if isKey(moveTo, k)
            s = setEdge(s, 'entity_id', moveTo(k));
            report.manipulations_retargeted = report.manipulations_retargeted + 1;
        end
        if nRen > 0 || isKey(moveTo, k)
            report.edges_renamed = report.edges_renamed + nRen;
            S{k} = s;
            changedIdx(end+1) = k; %#ok<AGROW>
        end
    end
end
changedIdx = unique(changedIdx(keep(changedIdx)));
if ~isempty(changedIdx) || ~isempty(added)
    fold = [S(changedIdx), added];
    res = did2.convert.v1_to_v2(fold, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);
    if ~isempty(res.quarantine) || numel(res.migrated) ~= numel(fold)
        % nothing half-moved: the batch stays as pass 1 (and the merge) left it
        report.rekey_quarantined = numel(fold) - numel(res.migrated);
        report.sides_attached = 0;
        report.parts_rekeyed = 0;
        report.parts_rekeyed_onto_existing_part = 0;
        report.edges_renamed = 0;
        report.manipulations_retargeted = 0;
        keep = keepMerge;
        added = {};
    else
        for j = 1:numel(changedIdx)
            docs{changedIdx(j)} = res.migrated{j};
        end
        added = res.migrated(numel(changedIdx) + 1:end);
    end
end

report.documents_removed = nnz(~keep);
report.documents_added = numel(added);
result.migrated = [reshape(docs(keep), 1, []), reshape(added, 1, [])];
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

function hits = coAnchored(S, role, keep, subject, anchor)
hits = [];
if isempty(anchor); return; end
for j = find(keep & strcmp(role, 'manip'))
    if strcmp(edgeValue(S{j}, 'entity_id'), subject) ...
            && strcmp(firstAnchor(S{j}), anchor)
        hits(end+1) = j; %#ok<AGROW>
    end
end
end

function tf = namesAny(deps, renames)
tf = false;
if isempty(deps); return; end
if iscell(deps); deps = [deps{:}]; end
f = 'value';
if ~isfield(deps, 'value') && isfield(deps, 'document_id'); f = 'document_id'; end
if ~isfield(deps, f); return; end
for k = 1:numel(deps)
    v = deps(k).(f);
    if (ischar(v) || isstring(v)) && isKey(renames, char(v))
        tf = true;
        return;
    end
end
end

function [s, n] = renameEdges(s, renames)
n = 0;
if ~isfield(s, 'depends_on') || isempty(s.depends_on); return; end
wasCell = iscell(s.depends_on);
deps = s.depends_on;
if wasCell; deps = [deps{:}]; end
f = 'value';
if ~isfield(deps, 'value') && isfield(deps, 'document_id'); f = 'document_id'; end
for k = 1:numel(deps)
    v = deps(k).(f);
    if (ischar(v) || isstring(v)) && isKey(renames, char(v))
        deps(k).(f) = renames(char(v));
        n = n + 1;
    end
end
if wasCell; deps = num2cell(deps); end
s.depends_on = deps;
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
