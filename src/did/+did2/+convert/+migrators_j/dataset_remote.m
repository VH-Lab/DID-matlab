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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI dataset_remote.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+cloud/+internal/createRemoteDatasetDoc.m
%   writes it: base.session_id = the dataset's id, no depends_on). Every v1
%   field and where it goes; did2.convert.roundtrip.dataset_remote rebuilds the
%   v1 document and testRawV1RoundTripSession compares the two:
%
%     base.session_id             -> the dataset entity's id
%     base.datestamp              -> its creation_timestamp
%     base.id                     -> NOT KEPT: a known finding, a question for
%                                    the team
%     base.name                   -> not kept ('' on every writer document)
%     dataset_remote.dataset_id   -> the dataset's global_identifier
%                                    `ndicloud:<id>`
%     dataset_remote.organization_id
%                                 -> the organization entity's name (the
%                                    writer stores the cloud organization's
%                                    id here, not a name: a finding), and the
%                                    dataset -hosted_by-> organization relation
%
%   A field, block or edge outside these, which the renamed path dropped
%   without a word, now carries the document whole as v1 (private/jRawAccount,
%   jRawCarry; no register row yet); what the renamed path would have
%   discarded (an `ndi_document` beside `base`, a depends_on `version`) is
%   carried, carry-049, as before.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above): what the migrator does not read
% carries the untouched v1 document; a legacy identity block is read as base.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, ...
    struct('dataset_remote', {{'dataset_id', 'organization_id'}}), {});
if jRawCarry('dataset_remote', src, collision, unplaced)
    v2Body = {src};
    return;
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
    orgId = did2.convert.mintId('organization');
    bodies = [bodies, did2.convert.entities.entityDoc(preBody, 'organization', orgId, ...
        struct('full_name', orgName), {}, true)];
    bodies{end+1} = jEntityRelation(preBody, datasetId, orgId, 'hosted_by');
end
v2Body = bodies;
end
