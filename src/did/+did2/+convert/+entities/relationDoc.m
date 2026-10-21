function rel = relationDoc(preBody, childId, parentId, relationName, order)
%RELATIONDOC One `directed_relation` CHILDID --RELATIONNAME--> PARENTID, built
%   through did2.build.directedRelation (did-schema #88; `child_id`/`parent_id`
%   edges). ORDER ([] for none) is the author order of `has_author`, written to
%   `directed_relation.order` (`sequence` until did-schema T20).

arguments
    preBody (1,1) struct
    childId char
    parentId char
    relationName char
    order = []
end
base = did2.convert.entities.freshBase(preBody, '');
rel = did2.build.directedRelation(childId, parentId, relationName, ...
    'Order', order, 'SessionId', base.session_id, ...
    'CreationTimestamp', base.datestamp, 'Validate', false);
end
