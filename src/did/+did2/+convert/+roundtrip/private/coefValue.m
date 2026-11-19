function v = coefValue(c)
%COEFVALUE A model_fit coefficient's or constraint's number, from either shape.
%
%   V = coefValue(C) reads what getIn(C, 'value') read before the new numeric
%   shape ([one shape for measured numbers], Jess Haley, 2026-11-17, did-schema
%   did_v2_numeric_shape_plan.md, section 8 answer 5): the old {variable,
%   value}, or the new list item's `numeric`. [] when C states none.
v = [];
c = firstOf(c);
if ~isstruct(c) || ~isscalar(c)
    return;
end
if isfield(c, 'numeric') && ~isempty(c.numeric)
    v = c.numeric;
elseif isfield(c, 'value')
    v = c.value;
end
end
