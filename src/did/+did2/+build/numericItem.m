function item = numericItem(item, shape)
%NUMERICITEM A list item written in the old numeric shape, in the shape the builders write.
%
%   ITEM = did2.build.numericItem(ITEM) takes one list item -- a covariate, a
%   condition, a method or compression parameter -- that a caller assembled
%   by hand in the old shape and returns it in the shape
%   did2.build.numericShape() names ('new' by default):
%
%     old                                  new
%     quantity.value                       numeric
%     quantity.source_value                source_numeric
%     matrix                               numeric
%     origin.value, origin.source_value    origin, source_origin
%     spacing.value, spacing.source_value  spacing, source_spacing
%
%   `unit`, `source_unit`, `approximate` and every other field are kept as
%   they are. Nothing stored changes: every number has one place in the new
%   shape (did-schema docs/plans/did_v2_numeric_shape_plan.md [one shape for
%   measured numbers], Jess Haley, 2026-11-17, section 4). An item already in
%   the new shape, an item with no number (count, term, text, logical, key),
%   and any item when the shape is 'old' come back unchanged.
%
%   ITEM = did2.build.numericItem(ITEM, SHAPE) uses SHAPE ('old' or 'new')
%   instead of did2.build.numericShape().
%
%   A struct array or a cell of structs is converted element by element; a
%   struct array comes back as a cell when its elements' fields differ.
%
%   Pass the result to did2.build.composite, as the old struct was.
%
%   Example:
%     c = struct('variable', v, 'along', 0, 'source_unit', u, ...
%         'quantity', struct('value', t, 'source_value', t));
%     c = did2.build.composite('data', 'covariates', did2.build.numericItem(c));
%
%   See also did2.build.numericShape, did2.build.covariate, did2.read.numeric.

if nargin < 2 || isempty(shape)
    shape = did2.build.numericShape();
end
shape = char(shape);
if ~any(strcmp(shape, {'old', 'new'}))
    error('did2:build:badOption', '''Shape'' is ''old'' or ''new''; got ''%s''.', shape);
end
if strcmp(shape, 'old')
    return;
end
if iscell(item)
    for k = 1:numel(item)
        item{k} = did2.build.numericItem(item{k}, shape);
    end
    return;
end
if ~isstruct(item)
    error('did2:build:typeMismatch', ...
        'did2.build.numericItem converts a list item (a struct), got %s.', class(item));
end
if ~isscalar(item)
    parts = cell(1, numel(item));
    for k = 1:numel(item)
        parts{k} = did2.build.numericItem(item(k), shape);
    end
    try
        item = reshape([parts{:}], size(item));
    catch
        item = parts;   % the elements' fields differ
    end
    return;
end

if isfield(item, 'quantity')
    q = item.quantity;
    item = rmfield(item, 'quantity');
    if isstruct(q) && isscalar(q)
        if isfield(q, 'value') && ~isempty(q.value)
            item.numeric = q.value;
        end
        if isfield(q, 'source_value') && ~isempty(q.source_value)
            item.source_numeric = q.source_value;
        end
    elseif ~isempty(q)
        error('did2:build:typeMismatch', ...
            'numericItem: `quantity` is a {value, source_value} struct.');
    end
end
if isfield(item, 'matrix')
    m = item.matrix;
    item = rmfield(item, 'matrix');
    if ~isempty(m)
        if isfield(item, 'numeric')
            error('did2:build:ruleViolated', ...
                'numericItem: the item gives both `quantity` and `matrix`.');
        end
        item.numeric = m;
    end
end
for n = {'origin', 'spacing'}
    name = n{1};
    if isfield(item, name) && isstruct(item.(name))
        b = item.(name);
        item = rmfield(item, name);
        if isscalar(b) && isfield(b, 'value')
            item.(name) = b.value;
        end
        if isscalar(b) && isfield(b, 'source_value') && ~isempty(b.source_value)
            item.(['source_' name]) = b.source_value;
        end
    end
end
end
