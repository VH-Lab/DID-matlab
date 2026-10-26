function v = textOf(v)
%TEXTOF A v1 value as a char row when it is text; anything else as given.
%
%   V = textOf(V): a char array comes back as a row, a scalar string as char,
%   an empty value of any type as ''. A value that is not text (a number, a
%   struct) is returned UNCHANGED: these helpers read, they never convert, so
%   nothing a v1 document states is reshaped on the way in.

if ischar(v)
    v = reshape(v, 1, []);
elseif isstring(v) && isscalar(v)
    v = char(v);
elseif isempty(v) && ~isstruct(v)
    v = '';
end
end
