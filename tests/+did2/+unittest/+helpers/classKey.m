function name = classKey(doc)
%CLASSKEY The name a test switches on for a did-schema #88 document.
%
%   NAME = did2.unittest.helpers.classKey(DOC) takes a did2.document or a body
%   struct and returns:
%
%     a statement   (observation / assertion / manipulation / calculation plus
%                   ONE value-kind mixin)      -> '<direction>+<kind>', e.g.
%                   'observation+score': the direction and the value kind,
%                   both asserted (did-schema #88; never a joined leaf name)
%     a named calculator ('tuning_curve_calculation', ...) -> its class name
%     an `entity`   -> its type, e.g. 'organism', 'epoch', 'software'
%     anything else -> document_class.class_name
%
%   A document that names a joined '<kind>_<direction>' class is NOT
%   normalised: it answers that raw class name, so a test asserting
%   '<direction>+<kind>' FAILS on an emitter that still writes the old form
%   (the guard over the source is testNoOldLeafNames).
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
    [direction, kind] = did2.convert.statementKind(doc);
    if ~isempty(kind)
        name = [direction '+' kind];
    end
end
end
