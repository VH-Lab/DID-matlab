function d = jBareDataset(preBody, datasetId)
%JBAREDATASET A bare `dataset` entity keyed on the dataset id (D.id()).
%   Every dataset-level container (session_in_a_dataset / dataset_remote /
%   dataset_session_info) mints one of these so all their edges converge on ONE
%   canonical dataset entity per dataset. The resolveDatasetEntities pass then
%   collapses the duplicates (and the rich metadata_editor dataset) to a single
%   entity per id, richest-wins — so every dataset ends with exactly one.
%   Shared Brainstorm-J (+migrators_j) helper.
d = struct();
d.document_class = struct('class_name', 'dataset', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
d.depends_on = struct('name', {}, 'value', {});
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
    ds = preBody.base.datestamp;
end
% the dataset entity is its own session context: id == session_id == the dataset id
d.base = struct('id', datasetId, 'session_id', datasetId, ...
    'name', 'migrated_dataset', 'datestamp', ds);
d.entity = struct('global_identifier', {struct('scheme', {}, 'value', {})});
d.dataset = struct('full_name', '', 'short_name', '', 'version', '', ...
    'description', '', 'license', '', 'release_date', '');
end
