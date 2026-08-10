function bodies = syncgraph(preBody)
%SYNCGRAPH Brainstorm-J migrator: did_v1 `syncgraph` -> `clock_alignment_policy`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   1 -> 1 or 2:  the policy, plus (when the source names an implementation) one
%   `software` entity.
%
%   TEAM-SIGN-OFF [sync configuration], jess@walthamdatascience.com / 2026-08-08:
%     "... syncgraph -> `clock_alignment_policy`, earning its existence on
%      membership; both preserve base.id, and syncrule_id_# is un-tightened back
%      to NDI's optional."
%
%   ---------------------------------------------------------------------
%   GROUND TRUTH -- AND THE ONE PLACE TEMPLATE AND SCHEMA DISAGREE
%   ---------------------------------------------------------------------
%     git show origin/main:src/ndi/ndi_common/database_documents/daq/syncgraph.json
%        "depends_on": [ ],
%        "syncgraph": { "ndi_syncgraph_class": "ndi_syncgraph" }
%     git show origin/main:src/ndi/ndi_common/schema_documents/daq/syncgraph_schema.json
%        "depends_on": [ { "name": "syncrule_id", "mustbenotempty": 0} ]
%
%   The template's `depends_on` is EMPTY and the schema declares `syncrule_id`.
%   The WRITER settles it, and it agrees with the schema:
%
%     git show origin/main:src/ndi/+ndi/+time/syncgraph.m:845-851
%        ndi_document_obj_set{1} = ndi.document('syncgraph', ...
%           'syncgraph.ndi_syncgraph_class', class(obj), ...
%           'base.id', obj.id(), 'base.session_id', obj.session.id());
%        for i=1:numel(obj.rules)
%           ndi_document_obj_set{end+1} = obj.rules{i}.newdocument();
%           ndi_document_obj_set{1} = ndi_document_obj_set{1}. ...
%              add_dependency_value_n('syncrule_id', obj.rules{i}.id());
%        end
%
%   `add_dependency_value_n` names the entries `syncrule_id_1`, `syncrule_id_2`,
%   ... (did/document.m:349: `newName = [dependency_name '_' int2str(numel(d)+1)]`),
%   so this migrator reads BOTH the numbered family and a bare `syncrule_id`.
%
%   REPAIR 3 in the plan: `syncrule_id_#` was never invented -- what V_eta got
%   wrong was TIGHTENING NDI's `"mustbenotempty": 0` into a requirement. A
%   rule-less graph is LEGAL in NDI, and `clock_alignment_configuration_#` is
%   declared `min_count: 0` accordingly, so this migrator emits ZERO edges for a
%   rule-less graph rather than one blank one.
%
%   ---------------------------------------------------------------------
%   WHY THE CLASS EXISTS AT ALL (the T12 question, answered in the plan)
%   ---------------------------------------------------------------------
%   `syncgraph.addrule` / `removerule` both exist, so the set of rules IN FORCE
%   is not "every syncrule document in the session" -- a rule can be in the
%   database and not in the graph. Folding the edges onto `session` would
%   reconstruct a DIFFERENT set. That membership is the entire content of the
%   migrated document, which is why it carries no fields and only edges.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NO SESSION => NO POLICY. PASS THE DOCUMENT THROUGH.
%   ---------------------------------------------------------------------
%   `clock_alignment_policy.session_id` is REQUIRED (mustBeNonEmpty: true) and it
%   is the ONE edge here that cannot be reconstructed later. The writer sets
%   `base.session_id` from `obj.session.id()`, so it is normally a real session
%   document -- which migrates 1:1 with its id preserved (the coverage ledger's
%   `session -> session, persist` row), so the edge resolves.
%
%   Two cases where it would not, and both pass through instead of emitting a
%   blank REQUIRED edge -- the failure that put 5,316 syncrule_mapping documents
%   into the census while validating clean, because
%   +did2/+validate/references.m:90 SKIPS empty edges:
%
%     * no `base.session_id` at all;
%     * the sentinel '0000000000000000_0000000000000000' that
%       ndi.session.empty_id() produces ("no specific session" / "applies in any
%       session" -- +ndi/+session/empty_id.m). Pointing a REQUIRED edge at a
%       document that by construction does not exist is an orphan, not a fact.
%
%   `syncgraph` is NOT phase-8 deleted (schemas/V_eta/stable/syncgraph.json is
%   present and stable), so a passed-through document has a schema to validate
%   against -- the thing that made the image_stack passthrough impossible.
%
%   base.id IS PRESERVED ON BOTH BRANCHES, so `syncrule_mapping`'s `syncgraph_id`
%   edge -- and the live NDI query built on it -- resolves either way.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'syncgraph') && isstruct(preBody.syncgraph)
    block = preBody.syncgraph;
end

sessionId = '';
if isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isfield(preBody.base, 'session_id')
    sessionId = char(preBody.base.session_id);
end
if isempty(sessionId) || isEmptySessionSentinel(sessionId)
    bodies = {preBody};      % THE GUARD -- see the header
    return;
end

implClass = jGetCharAny(block, {'ndi_syncgraph_class', 'ndiSyncgraphClass'});
[software, swId] = jSyncSoftware(preBody, implClass);

policy = struct();
policy.document_class = struct('class_name', 'clock_alignment_policy', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');

deps = struct('name', {}, 'value', {});
deps(end+1) = struct('name', 'session_id', 'value', sessionId);
if ~isempty(swId)
    deps(end+1) = struct('name', 'software_id', 'value', swId);
end
ruleIds = syncruleIds(preBody);
for k = 1:numel(ruleIds)
    % RENUMBERED FROM 1, not copied: v1's index is bookkeeping inside its own
    % depends_on list, and a source that has been edited can leave a gap. What
    % must be preserved is the SET (membership is the whole content) and the
    % family's own contiguity, which countFamily (silentLoss.m:243) reads.
    deps(end+1) = struct('name', sprintf('clock_alignment_configuration_%d', k), ...
        'value', ruleIds{k}); %#ok<AGROW>
end
policy.depends_on = deps;
policy.base = carryBase(preBody, sessionId);
% The class declares NO fields; a concrete class always contributes a property
% block (schema/cache.m resolvePlacement), so the block is present and empty.
policy.clock_alignment_policy = struct();

bodies = {policy};
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== small helpers =======================================

function ids = syncruleIds(preBody)
%SYNCRULEIDS Every populated `syncrule_id` / `syncrule_id_<n>` target, in order.
%   Numbered entries are sorted by their index so the migrated family follows the
%   source's order; a bare `syncrule_id` (what the schema literally declares) is
%   accepted too and sorts first.
ids = {};
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
deps = preBody.depends_on;
idx = [];
vals = {};
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name'); continue; end
    nm = char(d.name);
    if strcmp(nm, 'syncrule_id')
        n = 0;
    elseif startsWith(nm, 'syncrule_id_') ...
            && ~isempty(nm(13:end)) && all(isstrprop(nm(13:end), 'digit'))
        n = str2double(nm(13:end));
    else
        continue;
    end
    v = jSyncDependency(preBody, nm);
    if isempty(v); continue; end   % never carry a blank edge forward
    idx(end+1) = n; %#ok<AGROW>
    vals{end+1} = v; %#ok<AGROW>
end
if isempty(idx); return; end
[~, order] = sort(idx);
ids = vals(order);
end

function tf = isEmptySessionSentinel(sessionId)
%ISEMPTYSESSIONSENTINEL ndi.session.empty_id(): every character a '0' except '_'.
%   +ndi/+session/empty_id.m builds it by overwriting a fresh id's characters, so
%   it is matched by shape rather than by a hard-coded literal.
tf = false;
if isempty(sessionId); return; end
tf = all(sessionId == '0' | sessionId == '_');
end

function b = carryBase(preBody, sessionId)
%CARRYBASE base PRESERVED -- id, session_id, name, datestamp.
b = struct('id', '', 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
if isfield(preBody, 'base') && isstruct(preBody.base)
    src = preBody.base;
    fn = {'id', 'name', 'datestamp'};
    for k = 1:numel(fn)
        if isfield(src, fn{k}) && ~isempty(src.(fn{k}))
            b.(fn{k}) = src.(fn{k});
        end
    end
end
if isempty(b.id); b.id = did.ido.unique_id(); end
end
