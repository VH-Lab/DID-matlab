function elementType = elementGeneralTypeOfKind(kindNode)
%ELEMENTGENERALTYPEOFKIND The general v1 element type of a shared device kind.
%
%   ELEMENTTYPE = did2.convert.elementGeneralTypeOfKind(KINDNODE) is the
%   general v1 probe type of a device kind several v1 types share, for an
%   element whose recording or imaging mode is not known, or '' when there is
%   none. It is the type, among the types whose decided device kind
%   (did2.convert.elementDeviceKind) has the node KINDNODE (compared as
%   CURIEs, prefix case aside), that every other of those types extends as
%   '<type>-<mode>':
%
%     EMPTY:0000411 patch electrode  -> 'patch'  (patch-Vm, patch-I, patch-attached)
%     EMPTY:0000412 sharp electrode  -> 'sharp'  (sharp-Vm, sharp-Im)
%     OBI:0400169 microscope         -> ''       (no general imaging type)
%
%   A kind one type has, or no type has, is ''
%   (did2.convert.elementTypeOfKind reads a one-type kind).
%
%   Decided by Jess Haley, 2026-11-06 ("Read back patch"), to Claude's "for a
%   patch probe that never recorded (no recording observation, so no clamp
%   mode; [clamp mode of unrecorded probe dropped], 2026-11-03), NDI reads
%   back an empty element type. Should it read back the general word `patch`
%   instead (and likewise `sharp` and the imaging types)?". Both words are
%   registered v1 probe types (NDI-matlab ndi_common/probe/
%   probetype2object.json); the four imaging types there are each named for
%   their mode, with no general one. NDI-matlab's reader is
%   ndi.vintage.elementGeneralTypeOfKind.
%
%   See also did2.convert.elementTypeOfKind, did2.convert.elementDeviceKind,
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
names = {};
for k = 1:size(types, 1)
    if sameCurie(types{k, 2}, node)
        names{end+1} = types{k, 1}; %#ok<AGROW>
    end
end
if numel(names) < 2
    return;
end
for k = 1:numel(names)
    others = names([1:k-1, k+1:end]);
    if all(startsWith(others, [names{k} '-']))
        elementType = names{k};
        return;
    end
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
