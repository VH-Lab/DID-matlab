function v = coefValue(c)
%COEFVALUE A model_fit coefficient's or constraint's number.
%
%   V = coefValue(C) reads the list item's `numeric` ([one shape for
%   measured numbers], Jess Haley, 2026-11-17, did-schema
%   did_v2_numeric_shape_plan.md, section 8 answer 5). [] when C states
%   none. The old {variable, value} is the error
%   'did2:read:oldNumericShapeReMigrate' (did2.read.numeric; section 9 step
%   4, [no migrated database is kept], Jess Haley, 2026-11-19).
v = [];
c = firstOf(c);
if ~isstruct(c) || ~isscalar(c)
    return;
end
r = did2.read.numeric(c);   % refuses the old shape
if strcmp(r.form, 'numeric')
    v = r.numbers;
end
end
