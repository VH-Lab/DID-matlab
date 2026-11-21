function [v, found] = cellSource(c)
%CELLSOURCE What the source wrote in one value cell.
%
%   [V, FOUND] = cellSource(C) reads a value cell's `source_numeric` ([one
%   shape for measured numbers], Jess Haley, 2026-11-17, did-schema
%   did_v2_numeric_shape_plan.md; a relative time reference's start, end and
%   duration and an absolute one's duration are `time` values, [numeric
%   shape details] (2)). A series is one cell, so V holds every reading's;
%   numberOf(V) is the first. A cell in the old numeric shape (its
%   `source_value`) is the error 'did2:read:oldNumericShapeReMigrate'
%   (did2.read.refuseOldNumericShape; section 9 step 4, [no migrated
%   database is kept], Jess Haley, 2026-11-19).
v = [];
found = false;
c = firstOf(c);
if ~isstruct(c) || ~isscalar(c)
    return;
end
if isfield(c, 'source_value') && ~isempty(c.source_value)
    did2.read.refuseOldNumericShape('A value cell', 'source_value');
end
if isfield(c, 'source_numeric')
    v = c.source_numeric;
    found = true;
end
end
