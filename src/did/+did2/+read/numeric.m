function r = numeric(item)
%NUMERIC The number a list item states, read from the numeric shape.
%
%   R = did2.read.numeric(ITEM) reads one list item -- a covariate, a
%   condition, a method or compression parameter, a model_fit coefficient or
%   constraint -- in the numeric shape of did-schema
%   did_v2_numeric_shape_plan.md ([one shape for measured numbers], Jess
%   Haley, 2026-11-17), and returns:
%
%     form            'numeric'  a number (`numeric`)
%                     'origin'   regular positions (flat origin, spacing)
%                     ''         no number (a count, term, text, logical, key)
%     numbers         the canonical number(s): `numeric`. [] when none.
%     unit            the canonical unit (the item's `unit`), [] when none
%     source_numbers  what the source wrote: `source_numeric` (text on a
%                     condition or parameter where v1 wrote text). [] when none.
%     source_unit     the item's `source_unit`, [] when none
%     tolerance       {minus, plus}, [] when none
%     origin, spacing                 the regular form's canonical numbers
%     source_origin, source_spacing   ... and as the source wrote them
%
%   An item in the OLD numeric shape (a `quantity`, a `matrix`, origin and
%   spacing as {value, source_value} blocks, a coefficient's {variable,
%   value}) is not read: it is the error 'did2:read:oldNumericShapeReMigrate'
%   (did2.read.refuseOldNumericShape), and the database is migrated again
%   from v1 (section 9 step 4, [no migrated database is kept], Jess Haley,
%   2026-11-19). A blank old field (an empty quantity or matrix) is not an
%   old form.
%
%   ITEM is a scalar struct; a struct array or a cell of structs gives a
%   struct array, one element per item.
%
%   Example:
%     r = did2.read.numeric(doc.data.covariates(1));
%     r.numbers, r.unit
%
%   See also did2.read.canonical, did2.read.oldNumericForm,
%   did2.build.numericShape.

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

old = did2.read.oldNumericForm(item);
if ~isempty(old)
    did2.read.refuseOldNumericShape(sprintf('List item "%s"', variableName(item)), old);
end

r = blank();
r.unit = get(item, 'unit');
r.source_unit = get(item, 'source_unit');
r.tolerance = get(item, 'tolerance');

origin = get(item, 'origin');
spacing = get(item, 'spacing');
if ~isempty(origin) || ~isempty(spacing)
    r.form = 'origin';
    r.origin = origin;
    r.spacing = spacing;
    r.source_origin = get(item, 'source_origin');
    r.source_spacing = get(item, 'source_spacing');
    return;
end

if hasAny(item, 'numeric') || hasAny(item, 'source_numeric')
    r.form = 'numeric';
    r.numbers = get(item, 'numeric');
    r.source_numbers = get(item, 'source_numeric');
end
end

% -------------------------------------------------------------------------

function r = blank()
r = struct('form', '', 'numbers', [], 'unit', [], 'source_numbers', [], ...
    'source_unit', [], 'tolerance', [], 'origin', [], 'spacing', [], ...
    'source_origin', [], 'source_spacing', []);
end

function n = variableName(item)
n = '';
v = get(item, 'variable');
if isstruct(v) && isscalar(v) && isfield(v, 'name')
    n = char(v.name);
elseif ischar(v) || (isstring(v) && isscalar(v))
    n = char(v);
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
