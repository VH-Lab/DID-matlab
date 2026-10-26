function k = axisKey(term)
%AXISKEY The axis a written dimension term names: 'x', 'y', 'z', 'time',
%   'channel', or the term's own name.
%
%   K = did2.convert.axisKey(TERM). TERM is a {node, name} struct (a cell
%   holding one, or a name as text). An axis is recognised BY NODE first --
%   NCIT:C44477 x, NCIT:C44478 y, NCIT:C44479 z, om:Time time, NCIT:C44170
%   channel, the nodes did2.convert.axisTerm writes -- and then by name, so a
%   term written before the registry held the node ('z', 'time', 'channel')
%   reads the same. Any other term returns its name unchanged ('' for none).

arguments
    term
end

k = '';
if iscell(term)
    if isempty(term); return; end
    term = term{1};
end
node = '';
name = '';
if isstruct(term) && isscalar(term)
    if isfield(term, 'node') && ~isempty(term.node); node = char(term.node); end
    if isfield(term, 'name') && ~isempty(term.name); name = char(term.name); end
elseif ischar(term) || (isstring(term) && isscalar(term))
    name = char(term);
end
switch upper(strtrim(node))
    case 'NCIT:C44477', k = 'x'; return;
    case 'NCIT:C44478', k = 'y'; return;
    case 'NCIT:C44479', k = 'z'; return;
    case 'OM:TIME',     k = 'time'; return;
    case 'NCIT:C44170', k = 'channel'; return;
end
k = name;
end
