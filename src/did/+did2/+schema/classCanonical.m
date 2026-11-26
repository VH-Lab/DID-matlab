function names = classCanonical(className, cache)
%CLASSCANONICAL The canonical field(s) a value class declares.
%
%   NAMES = did2.schema.classCanonical(CLASSNAME) is the cellstr of the fields
%   CLASSNAME's top-level `canonical` list names ({field, unit} rows; did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers],
%   Jess Haley, 2026-11-17, section 2: "each class declaring its canonical
%   field and unit"), e.g. {'volts'} for voltage and concentration's seven.
%   {} when the class declares no such list (count, date, score, logical,
%   dose, ...), when it is not in the schema, or when CLASSNAME is empty.
%
%   NAMES = did2.schema.classCanonical(CLASSNAME, CACHE) reads it from the
%   did2.schema.cache CACHE (default: the shared one).
%
%   did2.schema.numericShapeFields takes NAMES to recognise a value cell and
%   mark its series once did-schema no longer declares the old `source_value`
%   in the value cells (section 9 step 4, did-schema#346).
%
%   See also did2.schema.numericShapeFields, did2.read.canonical.

if nargin < 2 || isempty(cache)
    cache = did2.schema.cache.shared();
end
names = {};
className = char(className);
if isempty(className)
    return;
end
try
    if ~cache.hasClass(className)
        return;
    end
    s = cache.getClass(className);
catch
    return;
end
if ~isstruct(s) || ~isfield(s, 'canonical') || isempty(s.canonical)
    return;
end
rows = s.canonical;
if isstruct(rows)
    rows = num2cell(reshape(rows, 1, []));
end
for k = 1:numel(rows)
    r = rows{k};
    if isstruct(r) && isfield(r, 'field') && ~isempty(r.field)
        names{end+1} = char(r.field); %#ok<AGROW>
    end
end
end
