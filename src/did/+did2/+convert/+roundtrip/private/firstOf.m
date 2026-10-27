function v = firstOf(v)
%FIRSTOF The first element of a non-scalar struct array or of a cell; V
%   itself otherwise.
if iscell(v) && ~isempty(v)
    v = v{1};
elseif isstruct(v) && numel(v) > 1
    v = v(1);
end
end
