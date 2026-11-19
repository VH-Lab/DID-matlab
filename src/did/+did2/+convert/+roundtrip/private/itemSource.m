function [v, found] = itemSource(e)
%ITEMSOURCE What the source wrote for a list item's number, from either shape.
%
%   [V, FOUND] = itemSource(E) reads what getIn(E, 'quantity', 'source_value')
%   read before the new numeric shape ([one shape for measured numbers], Jess
%   Haley, 2026-11-17): the old `quantity.source_value`, or the new flat
%   `source_numeric` (did2.read.numeric). FOUND is false, and V [], when E
%   states none.
v = [];
found = false;
e = firstOf(e);
if ~isstruct(e) || ~isscalar(e)
    return;
end
r = did2.read.numeric(e);
if isfield(e, 'quantity') && isstruct(e.quantity) && isscalar(e.quantity)
    found = isfield(e.quantity, 'source_value');
elseif isfield(e, 'source_numeric')
    found = ~isempty(e.source_numeric);
end
if found
    v = r.source_numbers;
end
end
