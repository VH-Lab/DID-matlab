function doc = undirectedRelation(entityIds, relation, options)
%UNDIRECTEDRELATION A symmetric relation among two or more entities.
%
%   DOC = did2.build.undirectedRelation(ENTITYIDS, RELATION, ...) builds an
%   undirected_relation over the entities ENTITYIDS (a cellstr; the schema
%   requires at least two). RELATION is a term, or a name completed from the
%   field's bound value set when it matches one exactly.
%
%   Options:
%     'Method'   a term (or a name)
%     'ValueId'  a data_type document qualifying the relation
%     'Fields', 'Edges', 'SessionId' (required), 'Id', 'CreationTimestamp',
%     'Validate', 'SchemaCache' -- as did2.build.document.
%
%   See also did2.build.directedRelation.

arguments
    entityIds {mustBeText}
    relation
    options.Method = []
    options.ValueId = ''
    options.Fields (1,1) struct = struct()
    options.Edges = struct()
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

fields = struct('relation', {relation});
if ~isempty(options.Method); fields.method = options.Method; end
edges = struct('entity_id', {cellstr(entityIds)}, 'value_id', options.ValueId);
options.Files = {};
doc = forward('undirected_relation', fields, edges, options);
end
