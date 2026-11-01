function doc = undirectedRelation(relatumIds, relation, options)
%UNDIRECTEDRELATION A symmetric relation between two ends (its relata).
%
%   DOC = did2.build.undirectedRelation(RELATUMIDS, RELATION, ...) builds an
%   undirected_relation over the documents RELATUMIDS (a cellstr; the schema
%   requires two). Each end may be an entity, a statement or a standalone
%   value, as `directed_relation`'s `child_id` and `parent_id` may (did-schema
%   did_v2_go_forward_class_audit.md, Jess Haley 2026-11-01 [undirected
%   relation widened]). RELATION is a term, or a name completed from the
%   field's bound value set when it matches one exactly.
%
%   The ends are written under the edge name the schema in use declares:
%   `relatum_id` ([undirected ends are relata], 2026-11-01), or `entity_id`
%   for a schema from before that rename. Readers take both
%   (did2.build.relatumIds).
%
%   Options:
%     'Method'   a term (or a name)
%     'MethodParameters'  its settings (did2.build.parameter / list);
%                did-schema #88 only, where `method` is {term, parameters}
%     'ValueId'  a data_type document qualifying the relation
%     'Fields', 'Edges', 'SessionId' (required), 'Id', 'CreationTimestamp',
%     'Validate', 'SchemaCache' -- as did2.build.document.
%
%   See also did2.build.directedRelation, did2.build.relatumIds.

arguments
    relatumIds {mustBeText}
    relation
    options.Method = []
    options.MethodParameters = []
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
fields = methodFields(fields, options.Method, options.MethodParameters, options.SchemaCache);
edges = struct(relatumEdge(options.SchemaCache), {cellstr(relatumIds)}, 'value_id', options.ValueId);
options.Files = {};
doc = forward('undirected_relation', fields, edges, options);
end

function name = relatumEdge(cache)
% `relatum_id` when the schema's undirected_relation declares it, else the
% name it had before [undirected ends are relata], `entity_id`
cache = schemaCache(cache);
name = 'entity_id';
if ~cache.hasClass('undirected_relation')
    return;
end
s = cache.getClass('undirected_relation');
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
deps = asDefs(s.depends_on);
if any(cellfun(@(d) strcmp(char(d.name), 'relatum_id'), deps))
    name = 'relatum_id';
end
end
