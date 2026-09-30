function defs = asDefs(raw)
%ASDEFS A schema `fields` / `depends_on` list as a cell array of structs.
%
%   jsondecode returns a struct ARRAY when every entry shares the same keys
%   and a CELL when they do not; the rest of the builder only wants one shape.
%   A missing or empty list is {}.

if isempty(raw)
    defs = {};
elseif iscell(raw)
    defs = reshape(raw, 1, []);
elseif isstruct(raw)
    defs = num2cell(reshape(raw, 1, []));
else
    error('did2:build:badSchema', ...
        'A schema field list is a %s, not a struct array or cell.', class(raw));
end
end
