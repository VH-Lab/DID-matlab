function elementType = elementTypeOfKind(kindNode)
%ELEMENTTYPEOFKIND The v1 element type a device kind alone rebuilds.
%
%   ELEMENTTYPE = did2.convert.elementTypeOfKind(KINDNODE) is the one v1
%   probe type whose decided device kind (did2.convert.elementDeviceKind) has
%   the node KINDNODE, compared as CURIEs (prefix case aside), or '' when no
%   type has it or several do (a patch electrode, a sharp electrode, a
%   microscope: the recording or imaging mode tells them apart, and the
%   migrator keeps the "element type" assertion for them until the modes are
%   decided and written).
%
%   [element type is a device kind term] (Decided by Jess Haley, 2026-10-27,
%   did-schema V_eta_go_forward_class_audit.md): "the round trip rebuilds the
%   v1 word from kind plus mode". A kind with one type needs no mode.
%
%   See also did2.convert.elementDeviceKind, did2.convert.migrators_j.element,
%   did2.convert.roundtrip.element.

arguments
    kindNode = ''
end

elementType = '';
node = strtrim(char(kindNode));
if isempty(node)
    return;
end
[~, ~, types] = did2.convert.elementDeviceKind('');
hit = false(size(types, 1), 1);
for k = 1:size(types, 1)
    hit(k) = sameCurie(types{k, 2}, node);
end
if nnz(hit) == 1
    elementType = types{hit, 1};
end
end

function tf = sameCurie(a, b)
% the prefix compared ignoring case (wikidata / Wikidata), the local part exactly
ia = strfind(a, ':');
ib = strfind(b, ':');
if isempty(ia) || isempty(ib)
    tf = strcmp(a, b);
    return;
end
tf = strcmpi(a(1:ia(1)-1), b(1:ib(1)-1)) && strcmp(a(ia(1)+1:end), b(ib(1)+1:end));
end
