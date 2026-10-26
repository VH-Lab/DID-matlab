function leaves = flattenLeaves(s)
%FLATTENLEAVES Every leaf field of a document body, with its path.
%
%   LEAVES = flattenLeaves(S) is a struct array {path, steps, value}, one per
%   leaf: a value that is not a struct (text, a number, a cellstr), or a
%   struct that is empty or has no fields (an empty block or list). A struct
%   array is walked by element, and so is ANY `depends_on` or `superclasses`,
%   even of one element, so that `depends_on(1).name` is one path whether the
%   list has one entry or several. A cell holding structs is walked by cell.
%   STEPS is the path as a cell: a char is a field, a number a struct-array
%   element, a 1x1 cell {k} a cell element (resolveSteps reads it back).

leaves = struct('path', {}, 'steps', {}, 'value', {});
leaves = walk(s, '', {}, '', leaves);
end

function leaves = walk(v, path, steps, fieldName, leaves)
if isstruct(v) && ~isempty(v) && ~isempty(fieldnames(v))
    indexed = ~isscalar(v) || any(strcmp(fieldName, {'depends_on', 'superclasses'}));
    if indexed
        for k = 1:numel(v)
            leaves = walkStruct(v(k), sprintf('%s(%d)', path, k), [steps, {k}], leaves);
        end
    else
        leaves = walkStruct(v, path, steps, leaves);
    end
elseif iscell(v) && ~isempty(v) && any(cellfun(@isstruct, v(:)))
    for k = 1:numel(v)
        leaves = walk(v{k}, sprintf('%s{%d}', path, k), [steps, {{k}}], '', leaves);
    end
else
    leaves(end+1) = struct('path', path, 'steps', {steps}, 'value', {v});
end
end

function leaves = walkStruct(v, path, steps, leaves)
fns = fieldnames(v);
for f = 1:numel(fns)
    name = fns{f};
    if isempty(path)
        p = name;
    else
        p = [path '.' name];
    end
    leaves = walk(v.(name), p, [steps, {name}], name, leaves);
end
end
