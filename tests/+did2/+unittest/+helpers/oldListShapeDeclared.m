function tf = oldListShapeDeclared()
%OLDLISTSHAPEDECLARED Does the loaded schema still declare the old list-item shape?
%
%   TF = did2.unittest.helpers.oldListShapeDeclared() is true when the v2
%   schema in use declares `quantity` on statement.conditions: the old numeric
%   shape of a list item (did-schema docs/plans/did_v2_numeric_shape_plan.md,
%   [one shape for measured numbers], Jess Haley, 2026-11-17). Step 4 of the
%   plan's section 9 removes it from did-schema (Waltham-Data-Science/did-schema
%   #373). While it is declared, did2.build writes it on request
%   ('Shape','old'); once it is not, did2.build refuses it
%   (did2:build:unknownField), because the builder writes only what the schema
%   declares. A test that pins the old writer asserts the one that holds for
%   the schema it runs on, so it passes on both (never a silent skip).
tf = did2.unittest.helpers.schemaDeclares('statement', {'conditions', 'quantity'});
end
