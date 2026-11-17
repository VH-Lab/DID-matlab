function r = numeric(item)
%NUMERIC The number a list item states, read from either numeric shape.
%
%   R = did2.read.numeric(ITEM) reads one list item -- a covariate, a
%   condition, a method or compression parameter, a model_fit coefficient or
%   constraint -- in the old shape or the new one ([one shape for measured
%   numbers], Jess Haley, 2026-11-17, did-schema did_v2_numeric_shape_plan.md)
%   and returns the same struct for both:
%
%     form            'numeric'  a number (old `quantity`, `matrix`, a
%                                coefficient's `value`; new `numeric`)
%                     'origin'   regular positions (old origin/spacing blocks;
%                                new flat origin, spacing)
%                     ''         no number (a count, term, text, logical, key)
%     numbers         the canonical number(s): old quantity.value, matrix or
%                     value; new numeric. [] when none.
%     unit            the canonical unit (the item's `unit`), [] when none
%     source_numbers  what the source wrote: old quantity.source_value (text on
%                     a condition or parameter); new source_numeric. [] when none.
%     source_unit     the item's `source_unit`, [] when none
%     tolerance       {minus, plus} (new shape only), [] when none
%     origin, spacing                 the regular form's canonical numbers
%     source_origin, source_spacing   ... and as the source wrote them
%
%   The old shape is read until step 4 of the plan's section 9 removes it, so
%   a reader that calls this is not touched when step 2 switches the writers.
%
%   ITEM is a scalar struct; a struct array or a cell of structs gives a
%   struct array, one element per item.
%
%   Example:
%     r = did2.read.numeric(doc.data.covariates(1));
%     r.numbers, r.unit
%
%   See also did2.read.canonical, did2.build.numericShape.

if iscell(item)
    item = item(:)';
    if isempty(item)
        r = blank();
        r = r([]);
        return;
    end
    r = repmat(blank(), 1, numel(item));
    for k = 1:numel(item)
        r(k) = did2.read.numeric(item{k});
    end
    return;
end
if ~isstruct(item)
    error('did2:read:badInput', 'did2.read.numeric reads a list item (a struct), got %s.', class(item));
end
if numel(item) ~= 1
    r = blank();
    r = repmat(r, 1, numel(item));
    for k = 1:numel(item)
        r(k) = did2.read.numeric(item(k));
    end
    return;
end

r = blank();
r.unit = get(item, 'unit');
r.source_unit = get(item, 'source_unit');
r.tolerance = get(item, 'tolerance');

origin = get(item, 'origin');
spacing = get(item, 'spacing');
if ~isempty(origin) || ~isempty(spacing)
    r.form = 'origin';
    [r.origin, r.source_origin] = regular(origin, get(item, 'source_origin'));
    [r.spacing, r.source_spacing] = regular(spacing, get(item, 'source_spacing'));
    return;
end

q = get(item, 'quantity');
if isstruct(q) && ~isempty(q)
    r.form = 'numeric';
    r.numbers = get(q, 'value');
    r.source_numbers = get(q, 'source_value');
    return;
end
if hasAny(item, 'numeric') || hasAny(item, 'source_numeric')
    r.form = 'numeric';
    r.numbers = get(item, 'numeric');
    r.source_numbers = get(item, 'source_numeric');
    return;
end
if hasAny(item, 'matrix')
    r.form = 'numeric';
    r.numbers = item.matrix;
    return;
end
% a model_fit coefficient or constraint in the old shape: {variable, value}
v = get(item, 'value');
if isnumeric(v) && ~isempty(v) && isfield(item, 'variable')
    r.form = 'numeric';
    r.numbers = v;
end
end

% -------------------------------------------------------------------------

function r = blank()
r = struct('form', '', 'numbers', [], 'unit', [], 'source_numbers', [], ...
    'source_unit', [], 'tolerance', [], 'origin', [], 'spacing', [], ...
    'source_origin', [], 'source_spacing', []);
end

function [v, src] = regular(x, flatSource)
% old: {value, source_value}; new: a flat number beside source_<name>
if isstruct(x)
    v = get(x, 'value');
    src = get(x, 'source_value');
else
    v = x;
    src = flatSource;
end
end

function v = get(s, name)
v = [];
if isstruct(s) && isscalar(s) && isfield(s, name)
    v = s.(name);
end
end

function tf = hasAny(s, name)
tf = isfield(s, name) && ~isempty(s.(name));
end
