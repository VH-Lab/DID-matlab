function bodies = jMembershipBodies(preBody, entries)
%JMEMBERSHIPBODIES Shared body builder for session<->dataset membership.
%   `entries` is a struct array of membership records (each carrying a member
%   `session_id`) — one element for the flat session_in_a_dataset, N for the
%   nested dataset_session_info aggregate. Emits the bare canonical dataset entity
%   plus one `session -part_of-> dataset` directed_relation per member session.
%   On a schema where `session_id` is an edge the relation is `included_in`
%   (schema:isPartOf) instead: did-schema V_eta_relation_inheritance_plan.md
%   (2026-10-20) gave records their own relation, which passes nothing, and
%   made `part_of` physical only. The same did-schema change, so one question
%   (sessionIdIsEdge) decides both.
%   Shared Brainstorm-J (+migrators_j) helper.
datasetId = jDatasetId(preBody);
bodies = {jBareDataset(preBody, datasetId)};
if ~isstruct(entries); return; end
relation = {'', 'part_of'};
if sessionIdIsEdge()
    relation = {'schema:isPartOf', 'included_in'};
end
for k = 1:numel(entries)
    memberSession = jGetChar(entries(k), 'session_id');
    if isempty(memberSession); continue; end
    if strcmp(memberSession, datasetId); continue; end   % the dataset's own root
    bodies{end+1} = jEntityRelation(preBody, memberSession, datasetId, ...
        relation{2}, '', relation{1}); %#ok<AGROW>
end
end

function tf = sessionIdIsEdge()
% Does the loaded schema store the session id as an EDGE (did-schema
% V_eta_relation_inheritance_plan.md, 2026-10-20)? A migrator holds no cache
% handle, so it asks the shared one -- the cache did2.convert.v1_to_v2 also
% falls back to. False when no schema can be loaded: the historical field shape.
tf = false;
try
    tf = did2.schema.cache.shared().sessionIdIsEdge();
catch
    % no schema to ask
end
end
