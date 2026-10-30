function tf = interpolatedListDeclared(className)
%INTERPOLATEDLISTDECLARED Does the loaded schema declare CLASSNAME's
%   `interpolated_values` as the list of [interpolated values are a list]
%   (Decided by Jess Haley, 2026-10-30, did-schema
%   V_eta_go_forward_class_audit.md), i.e. with a `response_transform` on
%   each entry?
%
%   tf = did2.unittest.helpers.interpolatedListDeclared( ...
%       'spatial_frequency_tuning_calculation')
%
%   The same probe the writer makes (+migrators_j/private/jCalculation.m:
%   jSchemaHasPath(leafClass, {'interpolated_values', 'response_transform'})).
%   CLASSNAME is one of the four classes the decision names; for
%   'contrast_sensitivity' (or 'contrast_sensitivity_calculation') the field
%   is value.interpolated_values. False when the class or a step is not
%   declared.
arguments
    className (1,:) char
end
[cls, path] = did2.unittest.helpers.interpolatedListSchema('-path', className);
tf = did2.unittest.helpers.schemaDeclares(cls, [path, {'response_transform'}]);
end
