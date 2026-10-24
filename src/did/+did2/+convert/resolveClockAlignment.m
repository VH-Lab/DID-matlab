function [result, report] = resolveClockAlignment(result, options)
%RESOLVECLOCKALIGNMENT V_eta second pass: the `syncgraph` and `filefind` syncrule folds.
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
%   BATCH-PASS-CONSUMES: syncgraph, syncrule
%   BATCH-PASS-EMITS: syncgraph -> document: clock_alignment_policy
%   BATCH-PASS-EMITS: syncrule -> nothing: this pass only stamps the
%       resolved acquisition-system edges onto a filefind rule and re-runs the
%       ARMED per-class migrator (+migrators_j/syncrule), which mints the
%       clock_alignment_configuration and acquisition_channels and is credited
%       there; crediting them here would count that emission twice.
%
%   `syncrule`: ONLY the `ndi.time.syncrule.filefind` rule is consumed here. A
%   file-based `filematch` rule reaches its `clock_alignment_configuration` in
%   PASS 1 (it names no device). A filefind rule names its two acquisition
%   systems BY NAME (parameters daqsystem1 / daqsystem2, filefind.m:32, matched
%   by string against epochnode objectname at filefind.m:133-134), and
%   `acquisition_channels` names its system only by an `acquisition_system_id`
%   EDGE, so pass 1 passes it through (+migrators_j/syncrule.m). This pass
%   resolves each name, WITHIN THE RULE'S OWN SESSION, against the migrated
%   `acquisition_system.name` (v1 daqsystem base.name, preserved by
%   +migrators_j/daqsystem.m), stamps the two ids as transient
%   `resolved_acquisition_system_id` deps and re-runs +migrators_j/syncrule,
%   which emits the [sync configuration] shape: the configuration (base.id
%   preserved, number_fullpath_matches and syncfilename as declared
%   method.parameters), two `acquisition_channels` (each with its resolved
%   `acquisition_system_id`) as the UNORDERED `acquisition_channels_id` pair,
%   and the `software` entity. The channel-based rules (commonTriggers /
%   randomPulses, which also carry channel strings) are NOT consumed here and
%   stay passthroughs, counted as `syncrule_not_filefind`.
%
%   REFUSAL, NOT INVENTION, FOR THE RULE TOO. A name that resolves to ZERO
%   systems in the session, or to MORE THAN ONE, leaves the rule a passthrough
%   and is counted (syncrule_refused_name_missing / _name_ambiguous, per rule;
%   syncrule_names_missing / _names_ambiguous, per name). No system is minted
%   for a missing name and no first match is taken for an ambiguous one. A rule
%   on the empty-session sentinel ("applies in any session") has no session to
%   resolve within and is refused as syncrule_refused_no_session_id. A fold is
%   ALL OR NOTHING: if any of its bodies quarantines on re-validation, the
%   original rule is kept and none of the fold's bodies is appended.
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
    options.TargetVersion (1,:) char {mustBeMember(options.TargetVersion, {'V_eta'})} = 'V_eta'
end

% A batch pass builds documents from the v1 source's own terms, exactly as a
% migrator does inside v1_to_v2, so the T19 TermRegistry check is off while it
% runs, as it is there, and restored after (unregistered terms are still
% collected when did2.build.unregisteredTerms('-collect') is on).
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>

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
    ... % the filefind syncrule arm. syncrules_seen is every `syncrule` still
    ... % in the batch after pass 1 (a passthrough); read the folds beside it.
    'acquisition_systems_indexed',          0, ...
    'syncrules_seen',                       0, ...
    'syncrule_filefind_seen',               0, ...
    'syncrule_not_filefind',                0, ...
    'syncrule_refused_no_session_id',       0, ...
    'syncrule_refused_no_system_name',      0, ...
    'syncrule_refused_name_missing',        0, ...
    'syncrule_refused_name_ambiguous',      0, ...
    'syncrule_names_missing',               0, ...
    'syncrule_names_ambiguous',             0, ...
    'syncrule_refused_migrator_declined',   0, ...
    'syncrule_refused_total',               0, ...
    'syncrule_configurations_folded',       0, ...
    'syncrule_channels_emitted',            0, ...
    'syncrule_software_emitted',            0, ...
    'syncrule_fold_quarantined',            0, ...
    'ran',                          false);
result.clock_alignment_fold = report;

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
        sessionId{k} = did2.schema.cache.sessionIdOf(b);
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

% --- the filefind syncrule arm ----------------------------------------------
% Swaps a folded rule into its own slot and APPENDS its other bodies, so the
% indices 1..n the syncgraph arm below reads are unchanged.
[docs, report, ruleQuarantine] = foldFilefindRules(docs, bodies, classes, ...
    sessionId, docId, report, options);
if ~isempty(ruleQuarantine)
    if isfield(result, 'quarantine') && ~isempty(result.quarantine)
        result.quarantine = [result.quarantine, ruleQuarantine];
    else
        result.quarantine = ruleQuarantine;
    end
end
if report.syncrule_configurations_folded > 0
    result.migrated = docs;
    result.summary = recountSummary(result);
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
    folded  = did2.convert.migrators_j.syncgraph(lendSessionIdField(stamped));
    % The migrator DECLINED if it handed the (stamped) body straight back -- it
    % returns {preBody} on any guard it cannot pass. That must not be counted as
    % a fold: it would replace the passthrough with the SAME body carrying a
    % `session_document_id` dep the class does not declare, which validateDocument
    % would then quarantine. Detect it by class of the first body.
    if isscalar(folded) && strcmp(classNameOf(folded{1}), 'syncgraph')
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

% ===================== the filefind syncrule arm ===========================

function [docs, report, quarantine] = foldFilefindRules(docs, bodies, classes, ...
        sessionId, docId, report, options)
%FOLDFILEFINDRULES Resolve each filefind rule's two system NAMES and re-run the migrator.
quarantine = {};
n = numel(bodies);

% (session id, acquisition_system.name) -> every acquisition_system id that
% claims it. A cell of ids, not one id: the count is what tells a resolved
% name from an ambiguous one.
systemIds = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:n
    if ~strcmp(classes{k}, 'acquisition_system'); continue; end
    report.acquisition_systems_indexed = report.acquisition_systems_indexed + 1;
    nm = '';
    b = bodies{k};
    if isfield(b, 'acquisition_system') && isstruct(b.acquisition_system) ...
            && isfield(b.acquisition_system, 'name')
        nm = char(b.acquisition_system.name);
    end
    if isempty(nm) || isempty(sessionId{k}) || isempty(docId{k}); continue; end
    key = systemKey(sessionId{k}, nm);
    if isKey(systemIds, key)
        systemIds(key) = [systemIds(key), docId(k)];
    else
        systemIds(key) = docId(k);
    end
end

rebuilt = {};        % every body of every attempted fold, in order
groupOf = [];        % per rebuilt body: which attempted fold it belongs to
slotOf  = [];        % per attempted fold: index into docs of the rule
idsOf   = {};        % per attempted fold: base.id of each of its bodies
for k = 1:n
    if ~strcmp(classes{k}, 'syncrule'); continue; end
    report.syncrules_seen = report.syncrules_seen + 1;
    b = bodies{k};
    block = struct();
    if isfield(b, 'syncrule') && isstruct(b.syncrule); block = b.syncrule; end
    impl = '';
    if isfield(block, 'ndi_syncrule_class'); impl = char(block.ndi_syncrule_class); end
    if ~strcmp(impl, 'ndi.time.syncrule.filefind')
        report.syncrule_not_filefind = report.syncrule_not_filefind + 1;
        continue;
    end
    report.syncrule_filefind_seen = report.syncrule_filefind_seen + 1;

    sid = sessionId{k};
    if isempty(sid) || isEmptySessionSentinel(sid)
        report.syncrule_refused_no_session_id = report.syncrule_refused_no_session_id + 1;
        continue;
    end
    params = struct();
    if isfield(block, 'parameters') && isstruct(block.parameters) && isscalar(block.parameters)
        params = block.parameters;
    end
    names = {charParam(params, 'daqsystem1'), charParam(params, 'daqsystem2')};
    if isempty(names{1}) || isempty(names{2})
        report.syncrule_refused_no_system_name = report.syncrule_refused_no_system_name + 1;
        continue;
    end
    resolved = cell(1, 2);
    nMissing = 0;
    nAmbiguous = 0;
    for j = 1:2
        key = systemKey(sid, names{j});
        if ~isKey(systemIds, key)
            nMissing = nMissing + 1;
            continue;
        end
        ids = systemIds(key);
        if numel(ids) > 1
            nAmbiguous = nAmbiguous + 1;
            continue;
        end
        resolved{j} = ids{1};
    end
    report.syncrule_names_missing = report.syncrule_names_missing + nMissing;
    report.syncrule_names_ambiguous = report.syncrule_names_ambiguous + nAmbiguous;
    if nMissing > 0
        report.syncrule_refused_name_missing = report.syncrule_refused_name_missing + 1;
        continue;
    end
    if nAmbiguous > 0
        report.syncrule_refused_name_ambiguous = report.syncrule_refused_name_ambiguous + 1;
        continue;
    end

    stamped = b;
    for j = 1:2
        stamped = stampEdge(stamped, 'resolved_acquisition_system_id', resolved{j});
    end
    folded = did2.convert.migrators_j.syncrule(lendSessionIdField(stamped));
    if isscalar(folded) && strcmp(classNameOf(folded{1}), 'syncrule')
        report.syncrule_refused_migrator_declined = ...
            report.syncrule_refused_migrator_declined + 1;
        continue;
    end
    slotOf(end+1) = k; %#ok<AGROW>
    ids = cell(1, numel(folded));
    for j = 1:numel(folded)
        rebuilt{end+1} = folded{j}; %#ok<AGROW>
        groupOf(end+1) = numel(slotOf); %#ok<AGROW>
        ids{j} = baseField(folded{j}, 'id');
    end
    idsOf{end+1} = ids; %#ok<AGROW>
end

report.syncrule_refused_total = report.syncrule_refused_no_session_id ...
    + report.syncrule_refused_no_system_name ...
    + report.syncrule_refused_name_missing ...
    + report.syncrule_refused_name_ambiguous ...
    + report.syncrule_refused_migrator_declined;

if isempty(slotOf)
    return;
end

out = did2.convert.v1_to_v2(rebuilt, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);
quarantine = out.quarantine;

producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for j = 1:numel(out.migrated)
    try
        producedById(char(out.migrated{j}.get('base.id'))) = j;
    catch
    end
end
for g = 1:numel(slotOf)
    ids = idsOf{g};
    complete = ~isempty(ids);
    for j = 1:numel(ids)
        if isempty(ids{j}) || ~isKey(producedById, ids{j})
            complete = false;
            break;
        end
    end
    if ~complete
        % ALL OR NOTHING: the rule stays the passthrough it was, and nothing
        % of this fold is appended (a lone acquisition_channels or a
        % configuration missing one of its pair would be a fragment).
        report.syncrule_fold_quarantined = report.syncrule_fold_quarantined + 1;
        continue;
    end
    docs{slotOf(g)} = out.migrated{producedById(ids{1})};   % the configuration, rule's id
    for j = 2:numel(ids)
        d = out.migrated{producedById(ids{j})};
        docs{end+1} = d; %#ok<AGROW>
        switch char(d.get('document_class.class_name'))
            case 'acquisition_channels'
                report.syncrule_channels_emitted = report.syncrule_channels_emitted + 1;
            otherwise
                report.syncrule_software_emitted = report.syncrule_software_emitted + 1;
        end
    end
    report.syncrule_configurations_folded = report.syncrule_configurations_folded + 1;
end
end

function k = systemKey(sessionId, name)
k = [char(sessionId) char(0) char(name)];
end

function v = charParam(params, name)
v = '';
if isstruct(params) && isfield(params, name) && ischar(params.(name))
    v = strtrim(params.(name));
end
end

function tf = isEmptySessionSentinel(sid)
%ISEMPTYSESSIONSENTINEL ndi.session.empty_id(): every character '0' except '_'.
%   The same test +migrators_j/syncgraph.m applies: the sentinel means "applies
%   in any session", so there is no one session to resolve a name within.
sid = char(sid);
tf = ~isempty(sid) && all(sid == '0' | sid == '_') && any(sid == '_');
end

% ===================== helpers =============================================

function b = stampSessionDocument(body, sessionDocumentId)
%STAMPSESSIONDOCUMENT Add the `session_document_id` dep jSessionDocId reads.
%   Deliberately a DIFFERENT name from `session_id`: `base.session_id` and the
%   edge `session_id` both already exist and mean the other thing. The migrator
%   sets `clock_alignment_policy.session_id` BY NAME from the resolved id and
%   never copies preBody.depends_on wholesale, so this transient stamp does not
%   reach the emitted policy -- it is read and discarded.
b = stampEdge(body, 'session_document_id', sessionDocumentId);
end

function b = stampEdge(body, edgeName, targetId)
%STAMPEDGE Append one transient dep (EDGENAME -> TARGETID) for a migrator to read.
%   Used for `session_document_id` (syncgraph) and, twice per rule, for
%   `resolved_acquisition_system_id` (filefind syncrule). Neither migrator copies
%   preBody.depends_on, so the stamp never reaches an emitted document.
b = body;
if ~isfield(b, 'depends_on') || isempty(b.depends_on) || ~isstruct(b.depends_on)
    b.depends_on = struct('name', edgeName, 'value', targetId);
    return;
end
% APPEND, preserving every existing edge INTACT. The existing deps came through
% did2.convert.universalRenames, which spells an edge target `document_id`, not
% `value` -- so the new dep must carry the SAME fields as the existing struct
% array (else the `(end+1)` append errors on a field mismatch AND the syncrule_id
% targets, stored in `document_id`, would be lost). jSessionDocId reads
% document_id / value / id in that order, so writing the id into whichever target
% field the array already uses is sufficient; the value field is filled too when
% both exist.
d = b.depends_on;
fn = fieldnames(d);
newdep = struct();
for i = 1:numel(fn)
    newdep.(fn{i}) = '';
end
newdep.name = edgeName;
if any(strcmp(fn, 'document_id'))
    newdep.document_id = targetId;
end
if any(strcmp(fn, 'value'))
    newdep.value = targetId;
end
d(end+1) = newdep;
b.depends_on = d;
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

function b = lendSessionIdField(b)
%LENDSESSIONIDFIELD Put `base.session_id` back on a migrated body a migrator re-reads.
%   This pass re-runs a per-document migrator on a body that has ALREADY been
%   through did2.convert.v1_to_v2. On a schema where `session_id` is an edge
%   (did-schema V_eta_relation_inheritance_plan.md, 2026-10-20) that body
%   carries the edge and no field, while every migrator reads the did_v1 field
%   -- so without this the bodies it emits would name no session and quarantine
%   on the required edge. The field is lent from the edge; v1_to_v2's outbound
%   pass moves it back onto the edge when the bodies are validated. A body that
%   still has the field (the field shape) is returned unchanged.
arguments
    b (1,1) struct
end

if ~isfield(b, 'base') || ~isstruct(b.base) || ~isscalar(b.base) ...
        || isfield(b.base, 'session_id')
    return;
end
sid = did2.schema.cache.sessionIdOf(b);
if ~isempty(sid)
    b.base.session_id = sid;
end
end
