function tf = sameCurie(a, b)
%SAMECURIE True when two CURIE texts name one node: equal once the prefix
%   case is set aside (did2.schema.curieKey). A prefix's case is spelling
%   ([spelling is notation], Jess Haley, 2026-10-26; the term registry writes
%   a registered node in its registered spelling, did2.convert.registeredTerm).
tf = false;
if ~(ischar(a) || isstring(a)) || ~(ischar(b) || isstring(b))
    return;
end
a = strtrim(char(a));
b = strtrim(char(b));
tf = strcmp(a, b) || strcmp(curieKeyOf(a), curieKeyOf(b));
end

function k = curieKeyOf(s)
try
    k = char(did2.schema.curieKey(s));
catch
    k = lower(s);
end
end
