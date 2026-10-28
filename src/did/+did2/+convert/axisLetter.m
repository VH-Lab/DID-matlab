function L = axisLetter(term)
%AXISLETTER The v1 `dimension_order` letter an image axis's label stands for,
%   through ONE fixed table; '' when the label is not in it.
%
%   L = did2.convert.axisLetter(TERM). TERM is a dimension label as text (a v1
%   `dimension_labels` entry, or a letter when the stack has no labels) or a
%   written {node, name} term. The table, compared without case:
%
%     X   x, width,  X-Coordinate (NCIT:C44477)
%     Y   y, height, Y-Coordinate (NCIT:C44478)
%     Z   z, depth,  Z-Coordinate (NCIT:C44479)
%     T   t, time    (om:Time)
%     C   c, channel (NCIT:C44170)
%
%   A term is read by its node first (the nodes did2.convert.axisTerm writes),
%   then by its name.
%
%   Decided by Jess Haley, 2026-10-27 [axis letters derive from labels]
%   (did-schema V_eta_go_forward_class_audit.md): "a v1 `dimension_order`
%   (e.g. "YX") is not stored; the round trip derives each letter from the V2
%   dimension's label through a fixed table; a video or image whose labels do
%   not map one-to-one onto its v1 letters is carried whole as v1".
%   did2.convert.migrators_j.image_stack carries such a stack;
%   did2.convert.roundtrip.imageStack rebuilds `dimension_order` from it.

arguments
    term
end

L = '';
node = '';
name = '';
if iscell(term)
    if isempty(term); return; end
    term = term{1};
end
if isstruct(term) && isscalar(term)
    if isfield(term, 'node') && ~isempty(term.node); node = strtrim(char(term.node)); end
    if isfield(term, 'name') && ~isempty(term.name); name = strtrim(char(term.name)); end
elseif ischar(term) || (isstring(term) && isscalar(term))
    name = strtrim(char(term));
end
switch upper(node)
    case 'NCIT:C44477', L = 'X'; return;
    case 'NCIT:C44478', L = 'Y'; return;
    case 'NCIT:C44479', L = 'Z'; return;
    case 'OM:TIME',     L = 'T'; return;
    case 'NCIT:C44170', L = 'C'; return;
end
switch lower(name)
    case {'x', 'width', 'x-coordinate'},  L = 'X';
    case {'y', 'height', 'y-coordinate'}, L = 'Y';
    case {'z', 'depth', 'z-coordinate'},  L = 'Z';
    case {'t', 'time'},                   L = 'T';
    case {'c', 'channel'},                L = 'C';
end
end
