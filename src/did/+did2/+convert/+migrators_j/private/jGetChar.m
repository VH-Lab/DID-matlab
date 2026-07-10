function s = jGetChar(block, name)
%JGETCHAR Read a char/string/scalar-numeric field from a struct as char ('' if absent).
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
s = '';
if isstruct(block) && isfield(block, name)
    v = block.(name);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    elseif isnumeric(v) && isscalar(v)
        s = num2str(v);
    end
end
end
