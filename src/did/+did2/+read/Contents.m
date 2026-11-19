% +READ  Read measured numbers from either numeric shape.
%
%   Decided by Jess Haley, 2026-11-17, did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers]:
%   list items become flat (numeric, unit, source_numeric, source_unit,
%   tolerance; origin, spacing, source_origin, source_spacing), a value cell's
%   source_value becomes source_numeric, a series becomes one cell of arrays,
%   and logical's value becomes the block {logical}. Until step 4 of the
%   plan's section 9 removes the old shape, documents of both shapes exist;
%   these readers return the same answer for both, so a reader that calls
%   them is not touched when step 2 switches the writers.
%
%   Files
%     numeric    - the number a list item states (a covariate, condition,
%                  method or compression parameter, model_fit coefficient)
%     canonical  - a value's number(s): a value class's value, logical's
%                  value, or a whole document's
%
%   See also did2.build.numericShape, did2.schema.numericShapeFields.
