function tf = logicalBlockDeclared()
%LOGICALBLOCKDECLARED Does the loaded schema declare logical's value as the block {logical}?
%
%   TF = did2.unittest.helpers.logicalBlockDeclared() is true when the v2
%   schema in use declares logical.value.logical: the numeric shape's
%   logical (did-schema docs/plans/did_v2_numeric_shape_plan.md, [one shape
%   for measured numbers], Jess Haley, 2026-11-17, section 3), declared by
%   did-schema when it removes the old shape, a bare true/false (section 9
%   step 4, Waltham-Data-Science/did-schema#346). False on a schema whose
%   logical.value is a bare `boolean`, where did2.build and the validator
%   read both the bare value and the block.
%
%   See also did2.unittest.helpers.oldValueCellShapeDeclared.
tf = did2.unittest.helpers.schemaDeclares('logical', {'value', 'logical'});
end
