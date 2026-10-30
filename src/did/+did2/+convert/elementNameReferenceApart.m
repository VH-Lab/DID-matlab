function [name, reference, apart] = elementNameReferenceApart(entityName, localId)
%ELEMENTNAMEREFERENCEAPART A migrated element's name and reference, read from its `name` first.
%
%   [NAME, REFERENCE, APART] = did2.convert.elementNameReferenceApart(ENTITYNAME, LOCALID)
%
%   The inverse of did2.convert.elementHandle. Decided by Jess Haley,
%   2026-10-29 [element name and reference stored apart] (did-schema
%   V_eta_go_forward_class_audit.md): the element's v1 name is the entity's
%   `name`, and the reference is what follows that KNOWN name in
%   `local_identifier`, so a name holding ' | ' or ' (ref ' reads back
%   exactly. ENTITYNAME is the entity's `name` ('' or [] when it has none).
%
%   APART is true when the pair was read this way:
%     LOCALID equal to ENTITYNAME                  NAME, REFERENCE []
%     LOCALID = [ENTITYNAME ' | ' X]               NAME, REFERENCE X
%     LOCALID = [ENTITYNAME ' (ref ' X ')']        NAME, REFERENCE X (the form
%                                                  migrated documents carried
%                                                  before 2026-10-26)
%     no ENTITYNAME and LOCALID = [' | ' X]        NAME '', REFERENCE X (an
%                                                  element with an empty name)
%   X is a number when str2double reads it as one (v1 `reference` is numeric
%   on every NDI-written element; elementHandle writes a number so that it
%   reads back exactly), else the text.
%
%   APART is false otherwise: a document migrated before this decision, whose
%   `name` (if any) is its v1 base.name ([v1 name is the entity name],
%   2026-10-27) and whose LOCALID alone holds the pair. NAME and REFERENCE
%   are then today's parse, did2.convert.elementNameReference(LOCALID), and a
%   caller rebuilds base.name from ENTITYNAME.
%
%   See also did2.convert.elementHandle, did2.convert.elementNameReference,
%            did2.convert.roundtrip.element.

arguments
    entityName
    localId
end

entityName = textOf(entityName);
localId = textOf(localId);
apart = true;
if ~isempty(entityName)
    name = entityName;
    n = numel(name);
    if strcmp(localId, name)
        reference = [];
        return;
    end
    if startsWith(localId, [name ' | ']) && numel(localId) > n + 3
        reference = referenceValue(localId(n + 4:end));
        return;
    end
    if startsWith(localId, [name ' (ref ']) && endsWith(localId, ')') ...
            && numel(localId) > n + 7
        reference = referenceValue(localId(n + 7:end - 1));
        return;
    end
elseif startsWith(localId, ' | ') && numel(localId) > 3
    name = '';
    reference = referenceValue(localId(4:end));
    return;
end
apart = false;
[name, reference] = did2.convert.elementNameReference(localId);
end

function v = referenceValue(s)
% a number when the text is one (exactly what elementHandle wrote for a
% numeric reference), else the text
d = str2double(s);
if (~isnan(d) || strcmpi(strtrim(s), 'nan')) && isreal(d)
    v = d;
else
    v = s;
end
end

function s = textOf(v)
s = '';
if isstring(v) && isscalar(v)
    s = char(v);
elseif ischar(v)
    s = v;
end
end
