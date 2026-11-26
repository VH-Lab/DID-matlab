function tf = oldValueCellShapeDeclared()
%OLDVALUECELLSHAPEDECLARED Does the loaded schema still declare the old value-cell shape?
%
%   TF = did2.unittest.helpers.oldValueCellShapeDeclared() is true when the v2
%   schema in use declares `source_value` on voltage.value: the old numeric
%   shape of a value cell (one cell per reading, the source's number in
%   `source_value`; did-schema docs/plans/did_v2_numeric_shape_plan.md, [one
%   shape for measured numbers], Jess Haley, 2026-11-17). Step 4 of the plan's
%   section 9 removes it from the value cells, and declares logical's value as
%   the block {logical} (Waltham-Data-Science/did-schema#346, branch
%   claude/numeric-value-cells). While it is declared, did2.build writes it on
%   request ('Shape','old'); once it is not, did2.build refuses it
%   (did2:build:unknownField), because the builder writes only what the schema
%   declares. A test that pins the old writer asserts the one that holds for
%   the schema it runs on, so it passes on both (never a silent skip); a test
%   of a reader's refusal writes the old shape by hand.
%
%   See also did2.unittest.helpers.oldListShapeDeclared,
%   did2.unittest.helpers.logicalBlockDeclared.
tf = did2.unittest.helpers.schemaDeclares('voltage', {'value', 'source_value'});
end
