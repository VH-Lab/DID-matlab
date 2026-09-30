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
%     'Sequence'          integer order among siblings
%     'Method'            a term (or a name): how the relation was established
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
    options.Sequence = []
    options.Method = []
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
if ~isempty(options.Sequence); fields.sequence = options.Sequence; end
if ~isempty(options.Method);   fields.method = options.Method;     end
edges = struct('child_id', childId, 'parent_id', parentId, ...
    'time_reference_id', {options.TimeReferenceIds}, ...
    'epoch_id', options.EpochId, 'value_id', options.ValueId);
options.Files = {};
doc = forward('directed_relation', fields, edges, options);
end
