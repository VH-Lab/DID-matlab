function name = leafName(doc)
%LEAFNAME The leaf name a did-schema #88 document is spelled by.
%
%   NAME = did2.unittest.helpers.leafName(DOC) takes a did2.document or a body
%   struct and returns the name a test can switch on:
%
%     a statement   (observation / assertion / manipulation / calculation plus
%                   a value-kind mixin)        -> '<kind>_<direction>', e.g.
%                   'score_observation' -- the spelling did2.build resolves
%     an `entity`   -> its type, e.g. 'organism', 'epoch', 'software'
%     anything else -> document_class.class_name
%
%   On did-schema #88 a statement's class_name is only its direction, so a test
%   written against the pre-#73 leaf classes reads the leaf through this.
if isa(doc, 'did2.document')
    doc = doc.toStruct();
end
name = '';
if ~isstruct(doc) || ~isfield(doc, 'document_class')
    return;
end
name = char(doc.document_class.class_name);
if strcmp(name, 'entity') && isfield(doc, 'entity') && isstruct(doc.entity) ...
        && isfield(doc.entity, 'type') && isstruct(doc.entity.type) ...
        && isfield(doc.entity.type, 'name') && ~isempty(doc.entity.type.name)
    name = char(doc.entity.type.name);
    return;
end
if any(strcmp(name, {'observation', 'assertion', 'manipulation', 'calculation'}))
    sc = doc.document_class.superclasses;
    if isstruct(sc); sc = num2cell(sc); end
    supers = cell(1, numel(sc));
    for k = 1:numel(sc)
        if isstruct(sc{k}); supers{k} = char(sc{k}.class_name); else; supers{k} = char(sc{k}); end
    end
    kind = '';
    try
        kind = char(did2.schema.cache.shared().documentValueKind(name, supers));
    catch
    end
    if ~isempty(kind)
        name = [kind '_' name];
    end
end
end
