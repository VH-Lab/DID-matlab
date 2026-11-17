function [v, found] = cellSource(c)
%CELLSOURCE What the source wrote in one value cell, from either shape.
%
%   [V, FOUND] = cellSource(C) reads what getIn(C, 'source_value') read before
%   the new numeric shape ([one shape for measured numbers], Jess Haley,
%   2026-11-17, did-schema did_v2_numeric_shape_plan.md): a value cell's old
%   `source_value`, or its new `source_numeric`. In the new shape a series is
%   one cell, so V holds every reading's; numberOf(V) is the first, as it was.
v = [];
found = false;
c = firstOf(c);
if ~isstruct(c) || ~isscalar(c)
    return;
end
if isfield(c, 'source_numeric') && ~isempty(c.source_numeric)
    v = c.source_numeric;
    found = true;
elseif isfield(c, 'source_value')
    v = c.source_value;
    found = true;
elseif isfield(c, 'source_numeric')
    found = true;
end
end
