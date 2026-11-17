function r = canonical(x, options)
%CANONICAL A statement's number(s), read from either numeric shape.
%
%   R = did2.read.canonical(X) reads a numeric value -- a value class's
%   `value` (voltage.value, mass.value, concentration.value, ...), logical's
%   `value`, or a whole document (did2.document or struct), whose value it
%   finds -- in the old shape or the new one ([one shape for measured
%   numbers], Jess Haley, 2026-11-17, did-schema
%   did_v2_numeric_shape_plan.md), and returns the same struct for both:
%
%     field           the canonical field read ('volts', 'grams', 'molar',
%                     'logical', ...); a cellstr, one per reading, when the
%                     readings of an old-shape series fill different ones
%                     (a concentration). '' when none was found.
%     numbers         the reading(s), a row: old -- one per cell of the value
%                     array; new -- the canonical field of the one cell.
%                     [] when no cell states one; in an old-shape series, NaN
%                     for a cell that states none while others do.
%     source_numbers  what the source wrote, a row: old source_value per
%                     cell (NaN for a cell that states none while others do);
%                     new source_numeric. [] when none.
%     source_unit     the source's unit: one term, or (old shape, when the
%                     cells differ) a struct array with one per reading
%     approximate     true/false: one, or one per reading when the cells differ
%     tolerance       {minus, plus}: the first one given, [] when none
%     n               how many readings
%
%   Old shape: a series is an array of cells of one number each, the source's
%   number is `source_value`, logical's value is bare true/false. New shape:
%   ONE cell whose canonical field and `source_numeric` are arrays, and
%   logical's value is the block {logical}. The old shape is read until step 4
%   of the plan's section 9 removes it, so a reader that calls this is not
%   touched when step 2 switches the writers.
%
%   Options:
%     'Field'        the canonical field to read, when it is known.
%     'Class'        the value class (e.g. 'concentration'); its canonical
%                    fields are then read from its schema: the numeric fields
%                    its value cell declares first, until the class declares
%                    its `canonical` (plan section 2).
%     'SchemaCache'  a did2.schema.cache for 'Class' and documents; default
%                    the shared one.
%   Without 'Field' or 'Class', a cell's canonical field is its first numeric
%   field other than source_value, source_numeric, approximate and tolerance
%   that holds a number.
%
%   Example:
%     r = did2.read.canonical(doc);          % a voltage statement
%     r.numbers, r.source_numbers, r.source_unit
%
%   See also did2.read.numeric, did2.build.valueCell, did2.build.numericShape.

arguments
    x
    options.Field (1,:) char = ''
    options.Class (1,:) char = ''
    options.SchemaCache = []
end

className = options.Class;
value = x;
if isa(x, 'did2.document')
    x = x.toStruct();
end
if isstruct(x) && isscalar(x) && isfield(x, 'document_class')
    [value, kindClass] = documentValue(x, options.SchemaCache);
    if isempty(className); className = kindClass; end
end

r = struct('field', '', 'numbers', [], 'source_numbers', [], 'source_unit', [], ...
    'approximate', [], 'tolerance', [], 'n', 0);
if isempty(value)
    return;
end
if islogical(value) || (isnumeric(value) && ~isstruct(value))
    % logical's old shape: the bare value
    r.field = 'logical';
    r.numbers = reshape(value, 1, []);
    r.n = numel(r.numbers);
    return;
end
if iscell(value)
    value = [value{:}];
end
if ~isstruct(value)
    error('did2:read:badInput', 'did2.read.canonical reads a value cell, got %s.', class(value));
end

canonNames = {};
if ~isempty(options.Field)
    canonNames = {options.Field};
elseif ~isempty(className)
    canonNames = classCanonical(className, options.SchemaCache);
end

nCells = numel(value);
fields = cell(1, nCells);
nums = cell(1, nCells);
srcs = cell(1, nCells);
units = cell(1, nCells);
approx = cell(1, nCells);
for k = 1:nCells
    e = value(k);
    f = pickField(e, canonNames);
    fields{k} = f;
    if ~isempty(f)
        nums{k} = reshape(e.(f), 1, []);
    end
    if isfield(e, 'source_numeric') && ~isempty(e.source_numeric)
        srcs{k} = reshape(e.source_numeric, 1, []);
    elseif isfield(e, 'source_value') && ~isempty(e.source_value)
        srcs{k} = reshape(e.source_value, 1, []);
    end
    if isfield(e, 'source_unit'); units{k} = e.source_unit; end
    if isfield(e, 'approximate'); approx{k} = e.approximate; end
    if isempty(r.tolerance) && isfield(e, 'tolerance') && isstruct(e.tolerance) ...
            && ~isempty(e.tolerance) && ~isempty(fieldnames(e.tolerance))
        r.tolerance = e.tolerance;
    end
end
anyNum = any(~cellfun(@isempty, nums));
numericSrc = all(cellfun(@(s) isnumeric(s) || islogical(s), srcs));
anySrc = any(~cellfun(@isempty, srcs));
if numericSrc && nCells > 1
    % the old shape: one reading per cell, so a cell that states no canonical
    % (a gap) or no source number reads NaN there, keeping the two aligned
    for k = 1:nCells
        m = max([numel(nums{k}), numel(srcs{k}), 1]);
        if anyNum && isempty(nums{k}); nums{k} = NaN(1, m); end
        if anySrc && isempty(srcs{k}); srcs{k} = NaN(1, m); end
    end
end
r.numbers = [nums{:}];
r.n = max(numel(r.numbers), numel([srcs{:}]) * numericSrc);
if numericSrc
    r.source_numbers = [srcs{:}];
else
    r.source_numbers = srcs;   % text a source wrote (not a numeric class)
end
named = fields(~cellfun(@isempty, fields));
if isempty(named)
    r.field = '';
elseif all(strcmp(named, named{1}))
    r.field = named{1};
else
    r.field = fields;
end
r.source_unit = oneOrEach(units);
r.approximate = oneOrEach(approx);
end

% -------------------------------------------------------------------------

function [value, kind] = documentValue(s, cacheArg)
% The value a document states, and the value class it is of.
value = [];
kind = '';
className = '';
if isfield(s.document_class, 'class_name')
    className = char(s.document_class.class_name);
end
try
    cache = cacheOf(cacheArg);
    ancestors = {};
    if isfield(s.document_class, 'superclasses')
        sc = s.document_class.superclasses;
        if iscell(sc); sc = [sc{:}]; end
        if isstruct(sc) && isfield(sc, 'class_name')
            ancestors = arrayfun(@(e) char(e.class_name), sc, 'UniformOutput', false);
        end
    end
    kind = cache.documentValueKind(className, ancestors);
catch
    kind = '';
end
if ~isempty(kind) && isfield(s, kind) && isstruct(s.(kind)) && isfield(s.(kind), 'value')
    value = s.(kind).value;
    return;
end
if ~isempty(className) && isfield(s, className) && isstruct(s.(className)) ...
        && isfield(s.(className), 'value')
    kind = className;
    value = s.(className).value;
    return;
end
kind = '';
blocks = setdiff(fieldnames(s), {'document_class', 'depends_on', 'base', 'files', 'file'}, 'stable');
for k = 1:numel(blocks)
    b = s.(blocks{k});
    if isstruct(b) && isscalar(b) && isfield(b, 'value')
        value = b.value;
        kind = blocks{k};
        return;
    end
end
end

function names = classCanonical(className, cacheArg)
% The canonical field(s) of a value class: the fields
% did2.schema.numericShapeFields marks `series` (bar source_numeric).
names = {};
try
    cache = cacheOf(cacheArg);
    own = cache.getClass(className).fields;
    if isstruct(own); own = num2cell(reshape(own, 1, [])); end
    def = [];
    for k = 1:numel(own)
        if strcmp(char(own{k}.name), 'value')
            def = own{k};
        end
    end
catch
    def = [];
end
if isempty(def) || ~isfield(def, 'fields') || isempty(def.fields)
    if ~isempty(def) && isfield(def, 'type') && strcmp(char(def.type), 'boolean')
        names = {'logical'};
    end
    return;
end
defs = did2.schema.numericShapeFields(def.fields, 'value');
for k = 1:numel(defs)
    if isfield(defs{k}, 'series') && defs{k}.series ...
            && ~strcmp(char(defs{k}.name), 'source_numeric')
        names{end+1} = char(defs{k}.name); %#ok<AGROW>
    end
end
if isempty(names) && ~isempty(defs)
    names = {char(defs{1}.name)};
end
end

function f = pickField(e, canonNames)
f = '';
if ~isempty(canonNames)
    for k = 1:numel(canonNames)
        if isfield(e, canonNames{k}) && ~isempty(e.(canonNames{k}))
            f = canonNames{k};
            return;
        end
    end
    return;
end
skip = {'source_value', 'source_numeric', 'source_unit', 'approximate', 'tolerance'};
fn = fieldnames(e);
for k = 1:numel(fn)
    if any(strcmp(fn{k}, skip))
        continue;
    end
    v = e.(fn{k});
    if (isnumeric(v) || islogical(v)) && ~isempty(v)
        f = fn{k};
        return;
    end
end
end

function v = oneOrEach(c)
given = c(~cellfun(@isempty, c));
if isempty(given)
    v = [];
    return;
end
same = true;
for k = 2:numel(c)
    if ~isequal(c{k}, c{1})
        same = false;
        break;
    end
end
if same
    v = c{1};
elseif all(cellfun(@isstruct, c))
    try
        v = [c{:}];
    catch
        v = c;
    end
else
    v = c;
end
end

function cache = cacheOf(cacheArg)
if isempty(cacheArg)
    cache = did2.schema.cache.shared();
else
    cache = cacheArg;
end
end
