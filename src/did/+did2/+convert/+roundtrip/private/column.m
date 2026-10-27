function x = column(x)
%COLUMN A numeric or logical vector as a column, the shape jsondecode gives a
%   v1 JSON list of numbers; anything else unchanged.
if (isnumeric(x) || islogical(x)) && isvector(x)
    x = x(:);
end
end
