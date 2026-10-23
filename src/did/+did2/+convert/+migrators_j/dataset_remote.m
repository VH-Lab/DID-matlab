function v2Body = dataset_remote(preBody)
%DATASET_REMOTE Brainstorm-J migrator: did_v1 dataset_remote -> the remote copy as
%   a first-class relation. A dataset_remote records that a local dataset is
%   mirrored to a cloud location (its cloud `dataset_id` + remote `organization_id`).
%   In J that is not a bespoke class but the entity-layer pattern used for every
%   external reference: the remote copy IS a `web_resource`, and the association is
%   a `directed_relation` (exactly as dataset documentation became
%   dataset -documented_by-> web_resource).
%
%   1 -> N (all endpoints minted here, so no orphan risk):
%     - dataset       the bare canonical dataset entity, keyed on the dataset id
%                     (base.session_id = D.id()); deduped against the rich
%                     metadata_editor dataset by resolveDatasetEntities.
%     - web_resource  the remote copy; the cloud id rides on global_identifier
%                     (scheme 'NDICloud').
%     - directed_relation  dataset -stored_at-> web_resource.
%     - organization  (if a remote org namespace is given) + web_resource
%                     -hosted_by-> organization.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'dataset_remote') && isstruct(preBody.dataset_remote)
    block = preBody.dataset_remote;
end
datasetId = jDatasetId(preBody);
cloudId = jGetChar(block, 'dataset_id');          % the id AT the remote service
orgName = jGetChar(block, 'organization_id');     % the remote org namespace

% did-schema #88: `web_resource` and `stored_at` retired (sec. 7: a URL is an
% address for the thing it names), so the cloud copy is the dataset's own
% identifier, `ndicloud:<id>` (a registered prefix), on the dataset entity.
% `hosted_by` returned 2026-10-15 with the DATASET as its child (dataset ->
% organization), so the remote org hangs off the dataset directly.
bareFields = struct();
if ~isempty(cloudId)
    bareFields.global_identifier = {['ndicloud:' cloudId]};
end
bodies = {jEntity(preBody, 'dataset', bareFields, 'Id', datasetId, 'SessionId', datasetId)};
if ~isempty(orgName)
    orgId = did.ido.unique_id();
    bodies = [bodies, did2.convert.entities.entityDoc(preBody, 'organization', orgId, ...
        struct('full_name', orgName), {}, true)];
    bodies{end+1} = jEntityRelation(preBody, datasetId, orgId, 'hosted_by');
end
v2Body = bodies;
end
