function t = axisTerm(name)
%AXISTERM An array axis's term, as the term registry writes it.
%
%   T = did2.convert.axisTerm(NAME) returns the {node, name} term a migrator
%   writes for the axis NAME ('x', 'y', 'z', 't' or 'time', any other name).
%
%   [migrator writes the registry spelling] and [term labels stay as the
%   ontology spells them] (Jess Haley, 2026-10-26, did-schema
%   V_eta_go_forward_class_audit.md): a term the registry already holds is
%   written with the registry's node and label. The axis letters map to
%
%     x          NCIT:C44477  X-Coordinate
%     y          NCIT:C44478  Y-Coordinate
%     z          NCIT:C44479  Z-Coordinate
%     t, time    om:Time      time
%
%   ONLY WHERE THE LOADED REGISTRY HOLDS THE NODE: the node is looked up in
%   the loaded schema's term registry (did2.convert.registeredTerm), and an
%   axis whose node the registry does not hold is written as before, by NAME
%   (did2.convert.registeredTerm('', NAME)), never with a node the registry
%   has not registered. Any other NAME is did2.convert.registeredTerm('', NAME).
%
%   The inverse, a written axis term back to its letter, is
%   did2.convert.axisKey.

arguments
    name {mustBeText}
end

name = strtrim(char(name));
node = axisNode(name);
if ~isempty(node)
    r = did2.convert.registeredTerm(node, '');
    if ~isempty(r.name)
        t = r;
        return;
    end
end
t = did2.convert.registeredTerm('', name);
end

function node = axisNode(name)
switch lower(name)
    case 'x',         node = 'NCIT:C44477';
    case 'y',         node = 'NCIT:C44478';
    case 'z',         node = 'NCIT:C44479';
    case {'t', 'time'}, node = 'om:Time';
    otherwise,        node = '';
end
end
