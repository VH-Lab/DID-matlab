function tf = isAbsent(value)
%ISABSENT True when VALUE means "this field is not given".
%
%   [] , '' , "" , {} and a 0x0 struct all mean absent. This is the same
%   convention did2.schema.cache uses when it rebuilds a ragged struct array:
%   a key one element lacks is filled with [] "because that is exactly what an
%   absent JSON key means here" (cache.m, coerceStructArray). A struct with
%   fields, a logical false and a numeric 0 are VALUES, never absent.

if isstruct(value)
    tf = isempty(value);
elseif isstring(value)
    tf = isempty(value) || (isscalar(value) && strlength(value) == 0);
else
    tf = isempty(value);
end
end
