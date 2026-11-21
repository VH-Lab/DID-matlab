% +READ  Read measured numbers from the numeric shape.
%
%   Decided by Jess Haley, 2026-11-17, did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers]:
%   list items are flat (numeric, unit, source_numeric, source_unit,
%   tolerance; origin, spacing, source_origin, source_spacing), a value cell's
%   source number is source_numeric, a series is one cell of arrays, and
%   logical's value is the block {logical}. Step 4 of the plan's section 9
%   ([no migrated database is kept], Jess Haley, 2026-11-19) removed the old
%   shape from these readers: a number stored in it is the error
%   'did2:read:oldNumericShapeReMigrate', and the database is migrated again
%   from v1.
%
%   Files
%     numeric    - the number a list item states (a covariate, condition,
%                  method or compression parameter, model_fit coefficient)
%     canonical  - a value's number(s): a value class's value, logical's
%                  value, or a whole document's
%     oldNumericForm        - which old-shape form a list item holds
%     refuseOldNumericShape - the error for a number in the old shape
%
%   See also did2.build.numericShape, did2.schema.numericShapeFields.
