function d = jBareDataset(preBody, datasetId)
%JBAREDATASET A bare `dataset` entity keyed on the dataset id (D.id()).
%   Every dataset-level container (session_in_a_dataset / dataset_remote /
%   dataset_session_info) mints one of these so all their edges converge on ONE
%   canonical dataset entity per dataset. The resolveDatasetEntities pass then
%   collapses the duplicates (and the rich metadata_editor dataset) to a single
%   entity per id, richest-wins — so every dataset ends with exactly one.
%   Shared Brainstorm-J (+migrators_j) helper.
%
%   did-schema #88: an `entity` of type dataset (the `dataset` class went,
%   V_eta_entity_composition_plan.md sec. 4), id DATASETID -- its base.id IS
%   its session id (V_eta_relation_inheritance_plan.md item 4 and its
%   "a dataset folder's own record is the dataset entity"). It carries no
%   name: the bare record exists so membership relations resolve, and
%   resolveDatasetEntities keeps the richer (named) dataset entity when both
%   are in the batch.

d = jEntity(preBody, 'dataset', struct(), 'Id', datasetId, 'SessionId', datasetId);
end
