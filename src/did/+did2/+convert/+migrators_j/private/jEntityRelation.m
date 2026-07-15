function rel = jEntityRelation(preBody, childId, parentId, relationName, docName)
%JENTITYRELATION A directed_relation child --relationName--> parent (entity layer).
%   `docName` is the base.name sentinel — resolveDatasetEntities uses it to find
%   the best-effort session-membership edges it may need to drop when the member
%   session is not in the batch. Shared Brainstorm-J (+migrators_j) helper.
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', childId), ...
    struct('name', 'parent', 'value', parentId)];
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
rel.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', docName, 'datestamp', ds);
rel.directed_relation = struct('relation', jOntologyTerm('', relationName));
end
