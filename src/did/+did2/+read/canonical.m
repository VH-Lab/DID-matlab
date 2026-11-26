function r = canonical(x, options)
%CANONICAL A statement's number(s), read from the numeric shape.
%
%   R = did2.read.canonical(X) reads a numeric value -- a value class's
%   `value` (voltage.value, mass.value, concentration.value, ...), logical's
%   `value`, or a whole document (did2.document or struct), whose value it
%   finds -- in the numeric shape of did-schema did_v2_numeric_shape_plan.md
%   ([one shape for measured numbers], Jess Haley, 2026-11-17), and returns:
%
%     field           the canonical field read ('volts', 'grams', 'molar',
%                     'logical', ...). '' when none was found.
%     numbers         the reading(s), a row: the canonical field of the one
%                     cell. [] when the cell states none.
%     source_numbers  what the source wrote, a row: `source_numeric`. [] when
%                     none.
%     source_unit     the source's unit: one term for the series
%     approximate     true/false, one for the series
%     tolerance       {minus, plus}, [] when none
%     n               how many readings
%
%   A series is ONE cell whose canonical field and `source_numeric` are
%   arrays, and logical's value is the block {logical}. A value in the OLD
%   numeric shape -- logical's bare true/false, a cell's numeric
%   `source_value`, or (for a numeric value class: one whose value declares
%   `source_numeric`, or whose cells carry a source record) a series stored
%   as one cell per reading -- is not read: it is the error
%   'did2:read:oldNumericShapeReMigrate' (did2.read.refuseOldNumericShape),
%   and the database is migrated again from v1 (section 9 step 4, [no
%   migrated database is kept], Jess Haley, 2026-11-19).
%
%   Options:
%     'Field'        the canonical field to read, when it is known.
%     'Class'        the value class (e.g. 'concentration'); its canonical
%                    fields are then read from its schema: the fields its
%                    `canonical` list names (plan section 2), else the
%                    numeric fields its value cell declares first.
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
%   See also did2.read.numeric, did2.read.refuseOldNumericShape,
%   did2.build.valueCell, did2.build.numericShape.

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
what = 'A value';
if ~isempty(className)
    what = sprintf('A %s value', className);
end
if islogical(value) || (isnumeric(value) && ~isstruct(value))
    % logical's old shape: the bare value
    did2.read.refuseOldNumericShape(what, 'a bare logical');
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

if isfield(value, 'source_value') && any(arrayfun(@(e) isnumeric(e.source_value) ...
        && ~isempty(e.source_value), value))
    did2.read.refuseOldNumericShape(what, 'source_value');
end
if numel(value) > 1 && isNumericClass(className, value, options.SchemaCache)
    did2.read.refuseOldNumericShape(what, 'a series stored one cell per reading');
end

% the one cell of a numeric value (a class that is not one, such as count,
% keeps a cell per reading: its readings are each cell's, in order)
e = value(1);
f = pickField(e, canonNames);
r.field = f;
if ~isempty(f)
    parts = cell(1, numel(value));
    for k = 1:numel(value)
        if isfield(value(k), f)
            parts{k} = reshape(value(k).(f), 1, []);
        end
    end
    r.numbers = [parts{:}];
end
if isfield(e, 'source_numeric') && ~isempty(e.source_numeric)
    r.source_numbers = reshape(e.source_numeric, 1, []);
end
if isfield(e, 'source_unit') && ~isempty(e.source_unit)
    r.source_unit = e.source_unit;
end
if isfield(e, 'approximate') && ~isempty(e.approximate)
    r.approximate = e.approximate;
end
if isfield(e, 'tolerance') && isstruct(e.tolerance) && ~isempty(e.tolerance) ...
        && ~isempty(fieldnames(e.tolerance))
    r.tolerance = e.tolerance;
end
nSource = 0;
if isnumeric(r.source_numbers) || islogical(r.source_numbers)
    nSource = numel(r.source_numbers);
end
r.n = max(numel(r.numbers), nSource);
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
% The canonical field(s) of a value class: those its `canonical` list names
% (did2.schema.classCanonical, plan section 2), else the fields
% did2.schema.numericShapeFields marks `series` (bar source_numeric), else
% its value's first field (logical's block {logical}).
names = {};
try
    names = did2.schema.classCanonical(className, cacheOf(cacheArg));
catch
    names = {};
end
if ~isempty(names)
    return;
end
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

function tf = isNumericClass(className, value, cacheArg)
% a numeric value class: its value declares `source_numeric` (when the class
% is known and its schema read), else its cells carry a source record
tf = false;
if ~isempty(className)
    try
        cache = cacheOf(cacheArg);
        own = cache.getClass(className).fields;
        if isstruct(own); own = num2cell(reshape(own, 1, [])); end
        for k = 1:numel(own)
            if strcmp(char(own{k}.name), 'value') && isfield(own{k}, 'fields') ...
                    && ~isempty(own{k}.fields)
                sub = own{k}.fields;
                if isstruct(sub); sub = num2cell(reshape(sub, 1, [])); end
                tf = any(cellfun(@(d) strcmp(char(d.name), 'source_numeric'), sub));
                return;
            end
        end
    catch
    end
end
tf = any(isfield(value, {'source_value', 'source_numeric', 'source_unit'}));
end

function cache = cacheOf(cacheArg)
if isempty(cacheArg)
    cache = did2.schema.cache.shared();
else
    cache = cacheArg;
end
end
