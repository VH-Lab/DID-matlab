function value = jSyncDependency(bodyStruct, name)
%JSYNCDEPENDENCY Read one `depends_on` target id by name ('' if absent/empty).
%
%   Read TOLERANTLY, because the same edge is spelled three ways depending on how
%   far through the pipeline the body is:
%
%       `value`        a raw migrator body (what +migrators_j hands back)
%       `document_id`  after did2.convert.universalRenames rewrote depends_on
%                      "rewrite depends_on entries to the V_delta (name,
%                       document_id) shape ... precedence is document_id > value
%                       > id" (universalRenames.m:38-43)
%       `id`           an unconverted did_v1 body
%
%   Same contract as private/jEpochDocId's inner read; factored out because the
%   clock-alignment migrators need it for four different edge names.
%
%   Shared helper for the Brainstorm-J (+migrators_j) clock-alignment migrators.

value = '';
if ~isfield(bodyStruct, 'depends_on') || isempty(bodyStruct.depends_on)
    return;
end
deps = bodyStruct.depends_on;
if ~isstruct(deps)
    return;
end
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), char(name))
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            value = char(d.(f));
            return;
        end
    end
    return;
end
end
