function bad = others(s, known, where)
%OTHERS The fields of struct S outside KNOWN, each as 'WHERE.field': emitted
%   content an inverse has no place for.
bad = {};
if ~isstruct(s) || ~isscalar(s)
    return;
end
fns = fieldnames(s);
for k = 1:numel(fns)
    if ~any(strcmp(fns{k}, known))
        bad{end+1} = [where '.' fns{k}]; %#ok<AGROW>
    end
end
end
