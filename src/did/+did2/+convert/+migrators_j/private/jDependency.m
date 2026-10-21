function v = jDependency(body, name)
%JDEPENDENCY The id a body's depends_on entry NAME names, '' when absent.
%   Reads both spellings: v1 {name, value} and the normalised
%   {name, document_id} (universalRenames). A cell of entries is accepted.

v = '';
if ~isstruct(body) || ~isfield(body, 'depends_on') || isempty(body.depends_on)
    return;
end
deps = body.depends_on;
if isstruct(deps)
    deps = num2cell(deps);
end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            v = char(d.(key{1}));
            return;
        end
    end
end
end
