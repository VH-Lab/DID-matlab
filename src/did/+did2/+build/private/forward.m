function doc = forward(className, fields, namedEdges, options)
%FORWARD Build via did2.build.document from a wrapper's options.
%
%   A wrapper (statement, sampledBody, ...) names its common edges as options
%   of its own; NAMEDEDGES is a struct of those, with absent ones left empty.
%   They are joined to the caller's free-form options.Edges -- the same edge
%   named both ways is an error rather than a silent overwrite -- and to
%   options.Fields, the escape hatch for any declared field the wrapper does
%   not name.

edges = options.Edges;
if iscell(edges)
    pairs = edges;
    edges = struct();
    for k = 1:size(pairs, 1)
        name = char(pairs{k, 1});
        if isfield(edges, name)
            edges.(name) = [cellstr(edges.(name)), cellstr(pairs{k, 2})];
        else
            edges.(name) = pairs{k, 2};
        end
    end
end
names = fieldnames(namedEdges);
for k = 1:numel(names)
    v = namedEdges.(names{k});
    if isAbsent(v)
        continue;
    end
    if isfield(edges, names{k})
        error('did2:build:repeatedEdge', ...
            'Edge "%s" was given both by its own option and in ''Edges''.', names{k});
    end
    edges.(names{k}) = v;
end

extra = options.Fields;
names = fieldnames(extra);
for k = 1:numel(names)
    if isfield(fields, names{k}) && ~isAbsent(fields.(names{k}))
        error('did2:build:ambiguousField', ...
            'Field "%s" was given both by its own option and in ''Fields''.', names{k});
    end
    fields.(names{k}) = extra.(names{k});
end

doc = did2.build.document(className, fields, ...
    'SessionId', options.SessionId, 'Edges', edges, 'Files', options.Files, ...
    'Id', options.Id, 'CreationTimestamp', options.CreationTimestamp, ...
    'Validate', options.Validate, 'SchemaCache', options.SchemaCache);
end
