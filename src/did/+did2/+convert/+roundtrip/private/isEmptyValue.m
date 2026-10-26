function tf = isEmptyValue(v)
%ISEMPTYVALUE True for a value that states nothing: '', [], {}, an empty
%   string, an empty struct array, or a struct with no fields.
if isstruct(v)
    tf = isempty(v) || isempty(fieldnames(v));
elseif isstring(v)
    tf = isempty(v) || (isscalar(v) && strlength(v) == 0);
else
    tf = isempty(v);
end
end
