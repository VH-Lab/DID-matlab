function tf = sameValue(a, b)
%SAMEVALUE True when two v1 values state the same thing.
%   Text compares as text (a string and a char of the same characters are
%   equal; a char column and a row too); everything else by isequaln. Two
%   EMPTY values of any type are the same (an empty field states nothing).
if isEmptyValue(a) && isEmptyValue(b)
    tf = true;
    return;
end
if isText(a) && isText(b)
    tf = strcmp(reshape(char(a), 1, []), reshape(char(b), 1, []));
    return;
end
tf = isequaln(a, b);
end

function tf = isText(v)
tf = ischar(v) || (isstring(v) && isscalar(v));
end
