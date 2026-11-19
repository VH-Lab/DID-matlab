function elementType = elementTypeOfKindAndMode(kindNode, modeNodes)
%ELEMENTTYPEOFKINDANDMODE The v1 element type a shared device kind and its recording modes rebuild.
%
%   ELEMENTTYPE = did2.convert.elementTypeOfKindAndMode(KINDNODE, MODENODES)
%   is the one v1 probe type whose decided device kind
%   (did2.convert.elementDeviceKind) has the node KINDNODE and whose decided
%   recording or imaging mode (did2.convert.elementRecordingMode) has a node
%   in MODENODES (a char node, or a cell of them: the `method.term` nodes of
%   the element's recording observations). CURIEs are compared with the
%   prefix ignoring case and the local part exactly. A node that is no mode
%   of that kind is ignored; when the nodes name two different types, or
%   none, the answer is ''.
%
%   The kinds this reads back are the ones several v1 types share (patch
%   electrode, sharp electrode, microscope), which
%   did2.convert.elementTypeOfKind cannot read back alone. [element type is
%   a device kind term] (Decided by Jess Haley, 2026-10-27, did-schema
%   did_v2_go_forward_class_audit.md): "the round trip rebuilds the v1 word
%   from kind plus mode". The same rule as NDI-matlab's
%   ndi.vintage.elementTypeOfKindAndMode and ndi.vintage.elementTypeOf
%   (typeOfKindAndModes) at V2 39d8603c: each (kind, mode) pair names one
%   type; `sharp-I` is not a type of the kind table (it is carried whole as
%   v1, [element types batch 4] (9)), so voltage clamp on a sharp electrode
%   reads `sharp-Im`.
%
%   See also did2.convert.elementRecordingMode,
%   did2.convert.elementGeneralTypeOfKind, did2.convert.roundtrip.element.

arguments
    kindNode = ''
    modeNodes = {}
end

elementType = '';
kind = strtrim(char(kindNode));
if isempty(kind)
    return;
end
if ~iscell(modeNodes)
    modeNodes = {modeNodes};
end
[~, ~, types] = did2.convert.elementDeviceKind('');
found = {};
for k = 1:size(types, 1)
    if ~sameCurie(types{k, 2}, kind)
        continue;
    end
    mode = did2.convert.elementRecordingMode(types{k, 1});
    if isempty(mode)
        continue;
    end
    for m = 1:numel(modeNodes)
        node = modeNodes{m};
        if ~(ischar(node) || (isstring(node) && isscalar(node))) || strlength(string(node)) == 0
            continue;
        end
        if sameCurie(char(mode.node), strtrim(char(node))) && ~any(strcmp(found, types{k, 1}))
            found{end+1} = types{k, 1}; %#ok<AGROW>
        end
    end
end
if isscalar(found)
    elementType = found{1};
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
