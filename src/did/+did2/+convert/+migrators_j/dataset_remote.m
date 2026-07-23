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

bodies = {jBareDataset(preBody, datasetId)};

wrId = '';
if ~isempty(cloudId)
    wrId = did.ido.unique_id();
    bodies{end+1} = webResourceDoc(preBody, wrId, 'remote dataset copy', ...
        'NDICloud', cloudId);
    bodies{end+1} = jEntityRelation(preBody, datasetId, wrId, 'stored_at', ...
        'migrated_dataset_remote');
end
if ~isempty(orgName)
    orgId = did.ido.unique_id();
    bodies{end+1} = orgDoc(preBody, orgId, orgName);
    if ~isempty(wrId)
        bodies{end+1} = jEntityRelation(preBody, wrId, orgId, 'hosted_by', ...
            'migrated_dataset_remote');
    end
end

v2Body = bodies;
end

% ===================== builders ========================================

function d = webResourceDoc(preBody, docId, label, scheme, value)
d = entityShell(preBody, 'web_resource', docId, ...
    struct('scheme', scheme, 'value', value));
d.web_resource = struct('label', label);
end

function d = orgDoc(preBody, docId, name)
d = entityShell(preBody, 'organization', docId, ...
    struct('scheme', {}, 'value', {}));
d.organization = struct('full_name', name);
end

function d = entityShell(preBody, className, docId, gids)
d = struct();
d.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
d.depends_on = struct('name', {}, 'value', {});
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
d.base = struct('id', docId, 'session_id', sessionId, ...
    'name', ['migrated_', className], 'datestamp', ds);
% cell-wrap so an empty/multi gids array does not fan the struct into an array
d.entity = struct('global_identifier', {gids});
end
