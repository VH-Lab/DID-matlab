function [v, found] = itemSource(e)
%ITEMSOURCE What the source wrote for a list item's number.
%
%   [V, FOUND] = itemSource(E) reads a list item's flat `source_numeric`
%   (did2.read.numeric; [one shape for measured numbers], Jess Haley,
%   2026-11-17). FOUND is false, and V [], when E states none. An item in
%   the old numeric shape (`quantity.source_value`) is the error
%   'did2:read:oldNumericShapeReMigrate' (section 9 step 4, [no migrated
%   database is kept], Jess Haley, 2026-11-19).
v = [];
found = false;
e = firstOf(e);
if ~isstruct(e) || ~isscalar(e)
    return;
end
r = did2.read.numeric(e);   % refuses the old shape
if isfield(e, 'source_numeric')
    found = ~isempty(e.source_numeric);
end
if found
    v = r.source_numbers;
end
end
