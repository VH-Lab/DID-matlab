function id = jDatasetId(preBody)
%JDATASETID The canonical dataset id = D.id(), which dataset-level documents
%   (metadata_editor / dataset_remote / session_in_a_dataset / dataset_session_info)
%   carry as base.session_id (an ndi.document created in a dataset D gets
%   base.session_id = D.id()). This is the id every dataset entity and every
%   dataset-referencing relation converges on. Falls back to base.id, then a
%   fresh id, so the migrator never emits an empty reference.
%   Shared Brainstorm-J (+migrators_j) helper.
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id') && ~isempty(preBody.base.session_id)
        id = char(preBody.base.session_id);
    elseif isfield(preBody.base, 'id') && ~isempty(preBody.base.id)
        id = char(preBody.base.id);
    end
end
if isempty(id); id = did.ido.unique_id(); end
end
