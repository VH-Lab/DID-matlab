function ids = edgeIds(body, name)
%EDGEIDS Every id an emitted document's depends_on edge NAME names, in
%   order, as a 1xN cellstr (read with did2.convert.v1read.readDependsOn, so
%   either spelling of an edge is read).
ids = {};
if ~isstruct(body) || ~isscalar(body)
    return;
end
deps = did2.convert.v1read.readDependsOn(body, 'Name', ['^' name '$']);
for k = 1:numel(deps)
    if ~isempty(deps(k).document_id)
        ids{end+1} = char(deps(k).document_id); %#ok<AGROW>
    end
end
end
