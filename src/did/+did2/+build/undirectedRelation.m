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
%   The ends are written as `relatum_id` edges ([undirected ends are relata],
%   Jess Haley 2026-11-01). The old name, `entity_id`, is neither written nor
%   read any more: did-schema declares only `relatum_id`, and the code drops
%   `entity_id` after the schema renamed it (the decision's last step).
%   did2.build.relatumIds reads the ends.
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
edges = struct('relatum_id', {cellstr(relatumIds)}, 'value_id', options.ValueId);
options.Files = {};
doc = forward('undirected_relation', fields, edges, options);
end
