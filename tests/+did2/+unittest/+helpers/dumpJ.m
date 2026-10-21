function dumpJ(where, name, v)
% SCRATCH ONLY: print a value as JSON so a test's actual output can be read from CI.
try
    v = plain(v);
    fprintf('\nDUMP<<%s|%s>> %s\n', where, name, jsonencode(v));
catch ME
    fprintf('\nDUMP<<%s|%s>> !! %s\n', where, name, ME.message);
end
end
function v = plain(v)
if isa(v, 'did2.document')
    if isscalar(v); v = v.toStruct(); else; v = arrayfun(@(d) d.toStruct(), v, 'UniformOutput', false); end
elseif iscell(v)
    v = cellfun(@plain, v, 'UniformOutput', false);
elseif isstruct(v)
    if isscalar(v)
        f = fieldnames(v);
        for k = 1:numel(f); v.(f{k}) = plain(v.(f{k})); end
    else
        v = arrayfun(@plain, v, 'UniformOutput', false);
    end
elseif isobject(v) && ~isstring(v)
    v = sprintf('<%s>', class(v));
end
end
