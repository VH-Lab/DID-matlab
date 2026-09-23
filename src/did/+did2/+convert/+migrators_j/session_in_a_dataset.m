function v2Body = session_in_a_dataset(preBody)
%SESSION_IN_A_DATASET Brainstorm-J migrator: did_v1 session_in_a_dataset -> the
%   session<->dataset membership as a first-class relation. Now that `session` is
%   an `entity`, a session belonging to a dataset is a `directed_relation`
%   (session -part_of-> dataset), not a bookkeeping record.
%
%   1 -> N:
%     - dataset            the bare canonical dataset entity (id = D.id() =
%                          base.session_id); deduped by resolveDatasetEntities.
%     - directed_relation  session -part_of-> dataset, where the member session is
%                          the block's `session_id`. Tagged
%                          `migrated_session_membership`: the member session may be
%                          a LINKED session whose documents are not in this batch,
%                          so resolveDatasetEntities drops the edge if the child
%                          does not resolve (best-effort, like the deferred baths).
%
%   Dropped: is_linked / session_creator / session_creator_input1..6 /
%   session_reference are NDI-internal session-assembly reconstruction handles
%   (how the session was linked/rebuilt into the dataset), not go-forward schema
%   content — the same disposition as the retired ndi_<x>_class config handles.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'session_in_a_dataset') && isstruct(preBody.session_in_a_dataset)
    block = preBody.session_in_a_dataset;
end
v2Body = jMembershipBodies(preBody, block);
end
