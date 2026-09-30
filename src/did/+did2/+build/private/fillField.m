function out = fillField(def, value, path)
%FILLFIELD Check VALUE against one schema field declaration and normalise it.
%
%   OUT = fillField(DEF, VALUE, PATH) is the engine every builder shares. DEF is
%   one entry of a schema `fields` list; PATH is the dotted name used in error
%   messages.
%
%   A field that declares sub-`fields` is a COMPOSITE and is rebuilt from them:
%     * every name VALUE carries must be declared   (did2:build:unknownField)
%     * a sub-field declared mustBeNonEmpty must be given  (did2:build:missingField)
%     * sub-fields that are not given are LEFT OUT, never filled with their
%       blank_value. Several schema rules turn on whether a field is PRESENT
%       (a key "carries origin and spacing if and only if regular is true"),
%       and a blank that is present would break them.
%     * output order is the schema's declared order.
%     * mustBeScalar false means an array: VALUE may be a struct array or a
%       cell of structs, and elements that differ in which fields they carry
%       are merged with [] for the absent ones (see mergeRagged).
%   An `ontology_term` may be given as a char/string (the term's name, no
%   node), or a cellstr/string array of names when it is an array.
%
%   A field with no sub-fields is a LEAF and is checked for its declared type,
%   scalarity, enum and numeric bounds. An unknown leaf type is an error: a
%   builder that cannot check a type must not pretend it did.
%
%   A `structure` with no declared sub-fields cannot be checked and is passed
%   through as given (it must still be a struct).
%
%   The binding constraint (T8) is NOT checked here; it is the schema cache's
%   (strictMode 'BindingConformance').

subDefs = asDefs(getOr(def, 'fields', []));
fieldType = char(getOr(def, 'type', ''));
isArray = ~logical(getOr(def, 'mustBeScalar', true));

if isempty(subDefs)
    if strcmp(fieldType, 'structure')
        if ~isstruct(value)
            error('did2:build:typeMismatch', '"%s" must be a struct.', path);
        end
        out = value;
        return;
    end
    out = fillLeaf(def, value, fieldType, isArray, path);
    return;
end

elems = toElements(value, fieldType, path);
if ~isArray && numel(elems) ~= 1
    error('did2:build:notScalar', ...
        '"%s" is a single %s, but %d were given.', path, fieldType, numel(elems));
end
names = cell(1, numel(subDefs));
for j = 1:numel(subDefs)
    names{j} = char(subDefs{j}.name);
end
for k = 1:numel(elems)
    if isArray
        elemPath = sprintf('%s(%d)', path, k);
    else
        elemPath = path;
    end
    elems{k} = fillStruct(subDefs, names, elems{k}, fieldType, elemPath);
    if strcmp(fieldType, 'ontology_term')
        elems{k} = completeFromValueSet(def, elems{k});
    end
end
if isArray
    out = mergeRagged(elems, names);
else
    out = elems{1};
end
end

% -------------------------------------------------------------------------

function s = fillStruct(subDefs, names, given, fieldType, path)
given = given(1);
extra = reshape(setdiff(fieldnames(given), names, 'stable'), 1, []);
if ~isempty(extra)
    error('did2:build:unknownField', ...
        '"%s" has no field(s) %s. Declared: %s.', path, ...
        strjoin(strcat('"', extra, '"'), ', '), strjoin(names, ', '));
end
s = struct();
for j = 1:numel(subDefs)
    name = names{j};
    subPath = [path '.' name];
    if isfield(given, name) && ~isAbsent(given.(name))
        s.(name) = fillField(subDefs{j}, given.(name), subPath);
    elseif logical(getOr(subDefs{j}, 'mustBeNonEmpty', false))
        error('did2:build:missingField', '"%s" is required.', subPath);
    end
end
if strcmp(fieldType, 'ontology_term') && ~hasText(s, 'node') && ~hasText(s, 'name')
    error('did2:build:emptyTerm', ...
        '"%s" is an ontology term with neither a node nor a name.', path);
end
end

function elems = toElements(value, fieldType, path)
isTerm = strcmp(fieldType, 'ontology_term');
if isTerm && (ischar(value) || isstring(value))
    value = cellstr(value);
end
if isstruct(value)
    elems = num2cell(reshape(value, 1, []));
elseif iscell(value)
    elems = reshape(value, 1, []);
    for k = 1:numel(elems)
        if isTerm && (ischar(elems{k}) || (isstring(elems{k}) && isscalar(elems{k})))
            elems{k} = struct('name', char(elems{k}));
        elseif ~(isstruct(elems{k}) && isscalar(elems{k}))
            error('did2:build:typeMismatch', ...
                'Element %d of "%s" must be a scalar struct, got %s.', ...
                k, path, class(elems{k}));
        end
    end
else
    error('did2:build:typeMismatch', ...
        '"%s" must be a struct (declared type %s), got %s.', ...
        path, fieldType, class(value));
end
end

function out = fillLeaf(def, value, fieldType, isArray, path)
switch fieldType
    case {'char', 'did_uid', 'timestamp', 'date'}
        if isstring(value) && isscalar(value)
            value = char(value);
        end
        if ~(ischar(value) && (isempty(value) || isrow(value)))
            error('did2:build:typeMismatch', ...
                '"%s" must be text (declared type %s), got %s.', path, fieldType, class(value));
        end
    case 'string'
        if isstring(value)
            if isscalar(value)
                value = char(value);
            else
                value = cellstr(value);
            end
        end
        if ~(ischar(value) || iscellstr(value))
            error('did2:build:typeMismatch', ...
                '"%s" must be text or a list of text, got %s.', path, class(value));
        end
    case 'boolean'
        if isnumeric(value) && all(value(:) == 0 | value(:) == 1)
            value = logical(value);
        end
        if ~islogical(value)
            error('did2:build:typeMismatch', '"%s" must be true/false, got %s.', path, class(value));
        end
    case 'integer'
        if ~(isnumeric(value) && isreal(value) && all(mod(value(:), 1) == 0))
            error('did2:build:typeMismatch', '"%s" must be an integer.', path);
        end
        value = double(value);
    case 'double'
        if ~isnumeric(value)
            error('did2:build:typeMismatch', '"%s" must be numeric, got %s.', path, class(value));
        end
        value = double(value);
    case 'matrix'
        if ~(isnumeric(value) || islogical(value))
            error('did2:build:typeMismatch', '"%s" must be a numeric array, got %s.', path, class(value));
        end
    otherwise
        error('did2:build:unknownType', ...
            ['"%s" has declared type "%s", which this builder does not know ' ...
             'how to check. Teach private/fillField.m the type rather than ' ...
             'passing the value through unchecked.'], path, fieldType);
end
if ~isArray && any(strcmp(fieldType, {'boolean', 'integer', 'double'})) && ~isscalar(value)
    error('did2:build:notScalar', '"%s" must be a single value.', path);
end
constraints = getOr(def, 'constraints', struct());
if isstruct(constraints) && isfield(constraints, 'enum') && ~isempty(constraints.enum)
    allowed = reshape(cellstr(string(constraints.enum)), 1, []);
    if ~all(ismember(cellstr(string(value)), allowed))
        error('did2:build:notInEnum', '"%s" is "%s"; allowed: %s.', ...
            path, strjoin(reshape(cellstr(string(value)), 1, []), ', '), strjoin(allowed, ', '));
    end
end
if isstruct(constraints) && isnumeric(value)
    if isfield(constraints, 'minimum') && any(value(:) < constraints.minimum)
        error('did2:build:belowMinimum', '"%s" is below its minimum %g.', path, constraints.minimum);
    end
    if isfield(constraints, 'maximum') && any(value(:) > constraints.maximum)
        error('did2:build:aboveMaximum', '"%s" is above its maximum %g.', path, constraints.maximum);
    end
end
if isstruct(constraints) && isfield(constraints, 'maxLength') && ischar(value) ...
        && numel(value) > constraints.maxLength
    error('did2:build:tooLong', '"%s" is longer than %d characters.', path, constraints.maxLength);
end
out = value;
end

function t = completeFromValueSet(def, t)
%COMPLETEFROMVALUESET A term given by name alone, completed from the field's
%   own value set when the schema lists one (binding.values). Only an EXACT
%   name match fills the node -- nothing is guessed -- and an unmatched name is
%   left as given: whether it is admissible is the binding check's question
%   (strictMode 'BindingConformance'), not the builder's.
constraints = getOr(def, 'constraints', struct());
if ~isstruct(constraints) || ~isfield(constraints, 'binding') ...
        || ~isstruct(constraints.binding) || ~isfield(constraints.binding, 'values')
    return;
end
if hasText(t, 'node') || ~hasText(t, 'name')
    return;
end
members = asDefs(constraints.binding.values);
for k = 1:numel(members)
    if isfield(members{k}, 'name') && strcmp(char(members{k}.name), char(t.name))
        node = char(members{k}.node);
        if ~isempty(node)
            t.node = node;
            t = orderfields(t, intersect({'node', 'name'}, fieldnames(t), 'stable'));
        end
        return;
    end
end
end

function tf = hasText(s, name)
tf = isfield(s, name) && ~isempty(strtrim(char(s.(name))));
end

function v = getOr(s, name, default)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end
