function s = fieldText(block, name)
%FIELDTEXT BLOCK.(NAME) as char, or '' when BLOCK does not have it.
s = '';
if isstruct(block) && isscalar(block) && isfield(block, name) && ~isempty(block.(name))
    s = char(block.(name));
end
end
