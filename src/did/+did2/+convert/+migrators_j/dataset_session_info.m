function v2Body = dataset_session_info(preBody)
%DATASET_SESSION_INFO Brainstorm-J migrator: did_v1 dataset_session_info -> the
%   session<->dataset membership as first-class relations. This is the legacy
%   AGGREGATE form of session_in_a_dataset: the `dataset_session_info` block holds
%   a `dataset_session_info` structure (scalar or array), one entry per member
%   session, each with the same fields (session_id, is_linked, session_creator,
%   session_creator_input1..6, session_reference). It dissolves exactly like
%   session_in_a_dataset — a bare dataset entity + one session -part_of-> dataset
%   edge per member session (best-effort; dropped by resolveDatasetEntities when a
%   linked member session is not in the batch). The assembly/reconstruction fields
%   are dropped as NDI-internal handles.

arguments
    preBody (1,1) struct
end

entries = struct([]);
if isfield(preBody, 'dataset_session_info') && isstruct(preBody.dataset_session_info) ...
        && isfield(preBody.dataset_session_info, 'dataset_session_info')
    inner = preBody.dataset_session_info.dataset_session_info;
    if isstruct(inner); entries = inner; end
end
v2Body = jMembershipBodies(preBody, entries);
end
