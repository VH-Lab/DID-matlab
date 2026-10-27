function d = setDependency(d, name, value)
%SETDEPENDENCY ndi.document/set_dependency_value: the value of the depends_on
%   entry NAME, which is added ({name, value}) when the document has none.
%
%   D = did2.unittest.helpers.setDependency(D, NAME, VALUE).
%
%   See also did2.unittest.helpers.ndiDocument.

arguments
    d (1,1) struct
    name (1,:) char
    value (1,:) char
end

if ~isfield(d, 'depends_on') || isempty(d.depends_on)
    d.depends_on = struct('name', name, 'value', value);
    return;
end
deps = d.depends_on;
if iscell(deps); deps = [deps{:}]; end
hit = find(arrayfun(@(e) strcmp(char(e.name), name), deps), 1);
if isempty(hit)
    deps(end + 1) = struct('name', name, 'value', value);
else
    deps(hit).value = value;
end
d.depends_on = deps;
end
