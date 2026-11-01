function [doc, sw, swName, spec] = daqParts(bodies, className, spec, ctx)
%DAQPARTS The one document of class CLASSNAME a converted acquisition-system
%   family document became, and the `software` entity its `software_id` edge
%   names (its name: the v1 implementation class).
%
%   [DOC, SW, SWNAME, SPEC] = daqParts(BODIES, CLASSNAME, SPEC). DOC is the
%   first emitted document of CLASSNAME ([] when none, which is unplaced); SW
%   the software entity ([] when the document names none); SWNAME its
%   entity.name ('' when none). Every other emitted document is unplaced in
%   SPEC: the migrators emit exactly the document and, when the v1 document
%   names its class, its one software entity (private/jSoftware).
%
%   [...] = daqParts(BODIES, CLASSNAME, SPEC, CTX): a software entity that is
%   not among BODIES is read from CTX, the index of the whole final batch
%   (did2.convert.roundtrip.wholeBatch), by the id the edge names; it is read,
%   not placed. With no CTX (a per-class round trip) it must be emitted.
%
%   See also did2.convert.roundtrip.daqsystem, .filenavigator, .daqreader,
%            .daqreader_ndr, .daqmetadatareader, .syncgraph.
if nargin < 4; ctx = []; end
doc = [];
sw = [];
swName = '';
used = false(1, numel(bodies));
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), className)
        doc = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(doc)
    spec.unplaced{end+1} = sprintf('no %s was emitted', className);
    return;
end
swIds = edgeIds(doc, 'software_id');
if numel(swIds) > 1
    spec.unplaced{end+1} = sprintf('the %s names %d software entities', className, numel(swIds));
end
if ~isempty(swIds)
    for k = 1:numel(bodies)
        b = bodies{k};
        if ~used(k) && isEntityOfType(b, 'software') && strcmp(char(getIn(b, 'base', 'id')), swIds{1})
            sw = b;
            used(k) = true;
            swName = fieldText(b.entity, 'name');
            break;
        end
    end
    if isempty(sw)
        b = ctxDoc(ctx, swIds{1});
        if ~isempty(b) && isEntityOfType(b, 'software')
            sw = b;
            swName = fieldText(b.entity, 'name');
        end
    end
    if isempty(sw)
        spec.unplaced{end+1} = sprintf('the software entity %s the %s names was not emitted', ...
            swIds{1}, className);
    elseif ~strcmp(fieldText(sw.entity, 'local_identifier'), swName)
        % pass 1 writes the class name as both name and local identifier (no
        % version); anything else is not what the migrator made
        spec.unplaced{end+1} = 'the software entity''s local identifier is not its name';
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a v1 %s', ...
        k, classNameOf(bodies{k}), className);
end
end
