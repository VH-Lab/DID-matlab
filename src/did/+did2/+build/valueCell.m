function cells = valueCell(typeName, canonical, options)
%VALUECELL The `value` of a data_type: one typed cell per reading.
%
%   CELLS = did2.build.valueCell(TYPENAME, CANONICAL, ...) builds the value
%   array of the data_type TYPENAME ('voltage', 'time', 'mass', 'count',
%   'score', 'date', 'concentration', ...), one cell per element of CANONICAL
%   (series-as-cardinality, Brainstorm I: a single reading is the length-1
%   case). The cell's fields are read from TYPENAME's schema, e.g.
%
%       voltage        {volts, source_unit, source_value, approximate}
%       count          {count, approximate}
%       score          {score, scale, scale_min, scale_max, source_unit, source_value, approximate}
%       date           {instant, precision, source_value, approximate}
%       concentration  {molar, grams_per_liter, ..., source_unit, source_value, approximate}
%
%   CANONICAL fills the canonical field -- by default the FIRST field the type
%   declares (volts, seconds, grams, count, score, instant, molar, ...). It is a
%   numeric array, or a cellstr for a text canonical such as date.instant.
%   Pass the value already converted to the canonical unit: the builder does
%   not convert units.
%
%   Options:
%     'Canonical'    which field CANONICAL fills, when the type has several
%                    (concentration: 'molar', 'grams_per_liter', ...).
%     'SourceValue'  what the source wrote, one per cell (numeric array, or a
%                    cellstr when the type's source_value is text).
%     'SourceUnit'   the source's unit: one char for all cells, or a cellstr.
%     'Approximate'  logical, scalar (all cells) or one per cell.
%     'Fields'       any other declared fields: a scalar struct applied to
%                    every cell, or a struct array with one element per cell
%                    (e.g. struct('precision','day') for a date,
%                    struct('scale', did2.build.term(...), 'scale_min', 0, ...)
%                    for a score).
%     'SchemaCache'  a did2.schema.cache; default the shared one.
%   An option the type does not declare (e.g. 'SourceUnit' for count) is an
%   error, as is any required cell field left unfilled (date.precision).
%
%   Example:
%     v = did2.build.valueCell('voltage', [0.012 0.013], ...
%         'SourceValue', [12 13], 'SourceUnit', 'mV');
%
%   See also did2.build.composite, did2.build.term.

arguments
    typeName (1,:) char
    canonical
    options.Canonical (1,:) char = ''
    options.SourceValue = []
    options.SourceUnit = ''
    options.Approximate = []
    options.Fields = struct([])
    options.SchemaCache = []
end

cache = schemaCache(options.SchemaCache);
def = fieldDef(cache, typeName, 'value');
subDefs = asDefs(getSub(def));
if isempty(subDefs)
    error('did2:build:notACell', ...
        '"%s.value" declares no cell fields; build it with did2.build.composite.', typeName);
end
if strcmp(char(def.type), 'ontology_term')
    error('did2:build:notACell', ...
        '"%s.value" is an ontology term; build it with did2.build.term.', typeName);
end
names = cellfun(@(d) char(d.name), subDefs, 'UniformOutput', false);

canonName = options.Canonical;
if isempty(canonName)
    canonName = names{1};
elseif ~any(strcmp(canonName, names))
    error('did2:build:unknownField', ...
        '"%s.value" has no field "%s". Declared: %s.', typeName, canonName, strjoin(names, ', '));
end

canon = asList(canonical);
n = numel(canon);
if n == 0
    error('did2:build:missingField', 'valueCell: no canonical value given.');
end
source = asList(options.SourceValue);
unit = asList(options.SourceUnit);
approx = asList(options.Approximate);
extra = options.Fields;
checkLength('SourceValue', source, n);
checkLength('SourceUnit', unit, n);
checkLength('Approximate', approx, n);
if ~isempty(extra) && ~(isscalar(extra) || numel(extra) == n)
    error('did2:build:sizeMismatch', ...
        'valueCell: ''Fields'' has %d elements for %d cells.', numel(extra), n);
end
requireDeclared('SourceValue', 'source_value', source, names, typeName);
requireDeclared('SourceUnit', 'source_unit', unit, names, typeName);
requireDeclared('Approximate', 'approximate', approx, names, typeName);

elems = cell(1, n);
for k = 1:n
    s = struct();
    if ~isempty(extra)
        e = extra(min(k, numel(extra)));
        fn = fieldnames(e);
        for f = 1:numel(fn)
            s.(fn{f}) = e.(fn{f});
        end
    end
    s.(canonName) = canon{k};
    if ~isempty(source); s.source_value = pick(source, k); end
    if ~isempty(unit);   s.source_unit  = pick(unit, k);   end
    if ~isempty(approx); s.approximate  = pick(approx, k); end
    elems{k} = s;
end
cells = fillField(def, elems, [typeName '.value']);
end

% -------------------------------------------------------------------------

function c = asList(v)
if isempty(v)
    c = {};
elseif ischar(v)
    c = {v};
elseif isstring(v)
    c = cellstr(v);
    c = reshape(c, 1, []);
elseif iscell(v)
    c = reshape(v, 1, []);
else
    c = num2cell(reshape(v, 1, []));
end
end

function checkLength(optName, c, n)
if ~isempty(c) && numel(c) ~= 1 && numel(c) ~= n
    error('did2:build:sizeMismatch', ...
        'valueCell: ''%s'' has %d elements for %d cells.', optName, numel(c), n);
end
end

function requireDeclared(optName, fieldName, c, names, typeName)
if ~isempty(c) && ~any(strcmp(fieldName, names))
    error('did2:build:unknownField', ...
        'valueCell: "%s" cells have no "%s", so ''%s'' does not apply.', ...
        typeName, fieldName, optName);
end
end

function v = pick(c, k)
v = c{min(k, numel(c))};
end

function raw = getSub(def)
raw = [];
if isfield(def, 'fields')
    raw = def.fields;
end
end
