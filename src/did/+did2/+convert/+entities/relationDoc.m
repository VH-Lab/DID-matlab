function rel = relationDoc(preBody, childId, parentId, relationName, sequence)
%RELATIONDOC One `directed_relation` CHILDID --RELATIONNAME--> PARENTID, built
%   through did2.build.directedRelation (did-schema #88; `child_id`/`parent_id`
%   edges). SEQUENCE ([] for none) is the author order of `has_author`.

arguments
    preBody (1,1) struct
    childId char
    parentId char
    relationName char
    sequence = []
end
base = did2.convert.entities.freshBase(preBody, '');
rel = did2.build.directedRelation(childId, parentId, relationName, ...
    'Sequence', sequence, 'SessionId', base.session_id, ...
    'CreationTimestamp', base.datestamp, 'Validate', false);
end
