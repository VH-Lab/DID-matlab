function bodies = jMembershipBodies(preBody, entries)
%JMEMBERSHIPBODIES Shared body builder for session<->dataset membership.
%   `entries` is a struct array of membership records (each carrying a member
%   `session_id`) — one element for the flat session_in_a_dataset, N for the
%   nested dataset_session_info aggregate. Emits the bare canonical dataset entity
%   plus one `session -part_of-> dataset` directed_relation per member session.
%   Shared Brainstorm-J (+migrators_j) helper.
datasetId = jDatasetId(preBody);
bodies = {jBareDataset(preBody, datasetId)};
if ~isstruct(entries); return; end
for k = 1:numel(entries)
    memberSession = jGetChar(entries(k), 'session_id');
    if isempty(memberSession); continue; end
    if strcmp(memberSession, datasetId); continue; end   % the dataset's own root
    bodies{end+1} = jEntityRelation(preBody, memberSession, datasetId, ...
        'part_of', 'migrated_session_membership'); %#ok<AGROW>
end
end
