function c = asCell(v)
%ASCELL A list (struct array or cell) as a 1xN cell; {} for an empty one.
if iscell(v)
    c = reshape(v, 1, []);
elseif isstruct(v)
    c = num2cell(reshape(v, 1, []));
elseif isempty(v)
    c = {};
else
    c = {v};
end
end
