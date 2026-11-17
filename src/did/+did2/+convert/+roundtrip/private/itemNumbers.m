function [v, found] = itemNumbers(e)
%ITEMNUMBERS A list item's canonical number(s), from either numeric shape.
%
%   [V, FOUND] = itemNumbers(E) reads what getIn(E, 'quantity', 'value') read
%   before the new numeric shape ([one shape for measured numbers], Jess
%   Haley, 2026-11-17, did-schema did_v2_numeric_shape_plan.md): the old
%   `quantity.value`, or the new flat `numeric` (did2.read.numeric). E is a
%   covariate, condition or parameter (the first element of a cell or struct
%   array, as getIn reads it). FOUND is false, and V [], when E states no
%   number. An old-shape `matrix` is not read here, as getIn did not read
%   it; in the new shape a matrix is `numeric` and is.
v = [];
found = false;
e = firstOf(e);
if ~isstruct(e) || ~isscalar(e)
    return;
end
if isfield(e, 'quantity') && isstruct(e.quantity) && isscalar(e.quantity)
    if isfield(e.quantity, 'value')
        v = e.quantity.value;
        found = true;
    end
    return;
end
if isfield(e, 'numeric') && ~isempty(e.numeric)
    r = did2.read.numeric(e);
    v = r.numbers;
    found = true;
end
end
