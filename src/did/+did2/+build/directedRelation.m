function doc = directedRelation(childId, parentId, relation, options)
%DIRECTEDRELATION A directed relation: CHILDID <RELATION> PARENTID.
%
%   DOC = did2.build.directedRelation(CHILDID, PARENTID, RELATION, ...) builds a
%   directed_relation between two entities, statements or data_type documents
%   (e.g. a probe `part_of` a subject, a cell `member_of` an ensemble).
%   RELATION is a term, or a name completed from the field's bound value set
%   when it matches one exactly.
%
%   Options:
%     'Order'             integer position among siblings, counted from 0
%                         (`directed_relation.order`; named `sequence` until
%                         did-schema T20). Omitted: -1, unordered
%     'Method'            a term (or a name): how the relation was established
%     'MethodParameters'  the settings of that method (did2.build.parameter /
%                         list); did-schema #88 only, where a relation's
%                         `method` is the block {term, parameters}
%     'TimeReferenceIds'  cellstr: when it held (T15 `multiple`)
%     'EpochId'           the epoch it is scoped to
%     'ValueId'           a data_type document qualifying the relation
%     'Fields', 'Edges', 'SessionId' (required), 'Id', 'CreationTimestamp',
%     'Validate', 'SchemaCache' -- as did2.build.document.
%
%   See also did2.build.undirectedRelation.

arguments
    childId (1,:) char
    parentId (1,:) char
    relation
    options.Order = []
    options.Method = []
    options.MethodParameters = []
    options.TimeReferenceIds = {}
    options.EpochId = ''
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
% `order` counts from 0 (T14; Jess Haley, 2026-10-21 [author order from 0]),
% so 0 is a real position and -1 is "unordered" (did-schema: blank and
% default -1, as `positions_from`). An absent 'Order' writes -1 explicitly.
if isempty(options.Order)
    fields.order = -1;
else
    if ~isscalar(options.Order) || options.Order < 0 || options.Order ~= round(options.Order)
        error('did2:build:badOption', ...
            '''Order'' is a position counted from 0 (an integer >= 0); omit it for an unordered relation.');
    end
    fields.order = options.Order;
end
fields = methodFields(fields, options.Method, options.MethodParameters, options.SchemaCache);
edges = struct('child_id', childId, 'parent_id', parentId, ...
    'time_reference_id', {options.TimeReferenceIds}, ...
    'epoch_id', options.EpochId, 'value_id', options.ValueId);
options.Files = {};
doc = forward('directed_relation', fields, edges, options);
end
