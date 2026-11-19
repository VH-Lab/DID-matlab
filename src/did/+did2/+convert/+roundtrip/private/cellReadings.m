function [x, unitNodes, missing] = cellReadings(values)
%CELLREADINGS Each reading's source number and source unit.
%
%   [X, UNITNODES, MISSING] = cellReadings(VALUES) reads a value class's
%   value -- VALUES the cell list asCell gives of it -- one reading at a
%   time: X(j) is reading j's source number (numberOf, so NaN when it is
%   absent or not finite, MISSING(j) true then), UNITNODES{j} the node of its
%   source unit. A series ([one shape for measured numbers], Jess Haley,
%   2026-11-17, did-schema did_v2_numeric_shape_plan.md, section 8 answer 4)
%   is ONE cell whose `source_numeric` holds every reading, with one
%   `source_unit` for the series. X is a column. The old numeric shape, one
%   cell per reading each with its `source_value`, is the error
%   'did2:read:oldNumericShapeReMigrate' (section 9 step 4, [no migrated
%   database is kept], Jess Haley, 2026-11-19).
x = zeros(0, 1);
unitNodes = {};
missing = false(0, 1);
values = asCell(values);
if numel(values) > 1
    did2.read.refuseOldNumericShape('A numeric value', 'a series stored one cell per reading');
end
for j = 1:numel(values)
    c = firstOf(values{j});
    [v, ~] = cellSource(c);
    [unode, ~] = termParts(getIn(c, 'source_unit'));
    if isnumeric(v) && numel(v) > 1
        parts = num2cell(double(v(:)'));   % one cell, every reading
    else
        parts = {v};
    end
    for p = 1:numel(parts)
        n = numberOf(parts{p});
        if isempty(n)
            x(end+1, 1) = NaN; %#ok<AGROW>
            missing(end+1, 1) = true; %#ok<AGROW>
        else
            x(end+1, 1) = n; %#ok<AGROW>
            missing(end+1, 1) = false; %#ok<AGROW>
        end
        unitNodes{end+1} = unode; %#ok<AGROW>
    end
end
end
