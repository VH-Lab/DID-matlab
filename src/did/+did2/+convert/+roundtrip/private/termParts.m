function [node, name] = termParts(t)
%TERMPARTS A term's node and name as text ('' when absent).
node = '';
name = '';
t = firstOf(t);
if isstruct(t) && isscalar(t)
    if isfield(t, 'node') && ~isempty(t.node); node = char(t.node); end
    if isfield(t, 'name') && ~isempty(t.name); name = char(t.name); end
elseif ischar(t) || (isstring(t) && isscalar(t))
    name = char(t);
end
end
