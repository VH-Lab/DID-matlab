function tf = isEntityOfType(body, handle)
%ISENTITYOFTYPE True when BODY is an `entity` whose type is HANDLE ('organism',
%   'group'), compared by node through did2.build.vocabularyHandle.
tf = false;
if ~strcmp(classNameOf(body), 'entity') || ~isfield(body, 'entity') ...
        || ~isstruct(body.entity) || ~isfield(body.entity, 'type')
    return;
end
tf = strcmp(did2.build.vocabularyHandle('entity_type', body.entity.type), handle);
end
