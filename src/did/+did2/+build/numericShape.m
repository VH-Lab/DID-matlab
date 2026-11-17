function shape = numericShape(newShape)
%NUMERICSHAPE Which numeric shape the builders write: 'old' (default) or 'new'.
%
%   SHAPE = did2.build.numericShape() is the shape did2.build writes measured
%   numbers in when a builder is not given 'Shape':
%     'old'  today's shape: a list item's quantity {value, source_value},
%            origin/spacing {value, source_value} and matrix; a value cell's
%            source_value; a series as an array of cells; logical's bare value;
%            a model_fit coefficient's {variable, value}.
%     'new'  the decided shape (Jess Haley, 2026-11-17, did-schema
%            docs/plans/did_v2_numeric_shape_plan.md [one shape for measured
%            numbers]): a flat numeric, unit, source_numeric, source_unit,
%            tolerance; origin, spacing, source_origin, source_spacing;
%            source_numeric in a value cell; a series as one cell of arrays;
%            logical.value.logical; a coefficient as a list item.
%
%   PREV = did2.build.numericShape(SHAPE) sets it for this MATLAB session and
%   returns the previous setting ('' when there was none), so
%   did2.build.numericShape(PREV) restores it; did2.build.numericShape('')
%   clears the setting. Without one, the environment variable DID_NUMERIC_SHAPE ('old' or
%   'new') decides; without that, 'old'.
%
%   WHY 'old' IS THE DEFAULT. The plan's section 9 orders the work: (1) the
%   validator and did2.build READ both shapes -- this change; (2) the writers
%   write the new one; (3) did-schema's class files change; (4) readers drop
%   the old shape. Step 2 is switching this default. Whatever the setting,
%   every builder and the validator accept both shapes.
%
%   Builders that honour it: did2.build.covariate, condition, parameter,
%   valueCell, fitEntry, and compression's parameters (did2.build.compression).
%
%   See also did2.schema.numericShapeFields, did2.read.numeric,
%   did2.read.canonical.

persistent setting
if isempty(setting)
    setting = '';
end
if nargin > 0
    shape = setting;   % the previous SETTING ('' when none), so it can be restored
    newShape = lower(strtrim(char(newShape)));
    if ~any(strcmp(newShape, {'', 'old', 'new'}))
        error('did2:build:badOption', ...
            'numericShape is ''old'' or ''new'' ('''' clears the setting); got ''%s''.', newShape);
    end
    setting = newShape;
    return;
end
shape = current(setting);
end

function shape = current(setting)
if ~isempty(setting)
    shape = setting;
    return;
end
shape = lower(strtrim(getenv('DID_NUMERIC_SHAPE')));
if ~any(strcmp(shape, {'old', 'new'}))
    shape = 'old';
end
end
