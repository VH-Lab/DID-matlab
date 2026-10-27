function s = cell2strOf(list)
%CELL2STROF A pattern list as NDI writes it: did.datastructures.cell2str /
%   vhlab cell2str, '{ ''a'', ''b'' }' (the inverse of private/jFileMatchList
%   for every list cell2str writes). '' for no list: +file/navigator.m
%   newdocument writes '' when the object has no parameters.
%
%   See also did2.convert.roundtrip.filenavigator.
if isempty(list)
    s = '';
    return;
end
if ischar(list) || (isstring(list) && isscalar(list))
    list = {char(list)};
end
parts = cellfun(@(p) ['''' char(p) ''''], list, 'UniformOutput', false);
s = ['{ ' strjoin(reshape(parts, 1, []), ', ') ' }'];
end
