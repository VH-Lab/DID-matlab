function [v, found] = itemNumbers(e)
%ITEMNUMBERS A list item's canonical number(s), from the numeric shape.
%
%   [V, FOUND] = itemNumbers(E) reads a list item's flat `numeric`
%   (did2.read.numeric; [one shape for measured numbers], Jess Haley,
%   2026-11-17, did-schema did_v2_numeric_shape_plan.md). E is a covariate,
%   condition or parameter (the first element of a cell or struct array, as
%   getIn reads it). FOUND is false, and V [], when E states no number. An
%   item in the old numeric shape (`quantity`, `matrix`) is the error
%   'did2:read:oldNumericShapeReMigrate' (section 9 step 4, [no migrated
%   database is kept], Jess Haley, 2026-11-19).
v = [];
found = false;
e = firstOf(e);
if ~isstruct(e) || ~isscalar(e)
    return;
end
r = did2.read.numeric(e);   % refuses the old shape
if isfield(e, 'numeric') && ~isempty(e.numeric)
    v = r.numbers;
    found = true;
end
end
