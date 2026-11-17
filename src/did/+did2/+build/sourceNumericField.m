function name = sourceNumericField(shape)
%SOURCENUMERICFIELD The name of a value cell's "what the source wrote" field.
%
%   NAME = did2.build.sourceNumericField() is 'source_numeric' when
%   did2.build.numericShape() is 'new' (the default) and 'source_value' when it
%   is 'old': in a numeric value cell (voltage.value, mass.value, a time
%   reference's start, end, duration or clock_tolerance, dose's amounts, ...)
%   the number as the source wrote it was `source_value` and is
%   `source_numeric` in the new shape (did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers]
%   and [numeric shape details] (2), Jess Haley, 2026-11-17).
%
%   NAME = did2.build.sourceNumericField(SHAPE) names it for SHAPE ('old' or
%   'new').
%
%   For a caller that assembles a value cell by hand:
%     c = struct('seconds', 3600, did2.build.sourceNumericField(), 1, ...
%         'source_unit', did2.build.term('om:hour', 'hour'));
%
%   Not for a true timestamp -- a date, or an absolute time reference's start
%   or end written as text -- whose `source_value` is the source's text and
%   keeps that name in both shapes.
%
%   See also did2.build.numericShape, did2.build.numericItem.

if nargin < 1 || isempty(shape)
    shape = did2.build.numericShape();
end
switch char(shape)
    case 'new'
        name = 'source_numeric';
    case 'old'
        name = 'source_value';
    otherwise
        error('did2:build:badOption', '''Shape'' is ''old'' or ''new''; got ''%s''.', char(shape));
end
end
