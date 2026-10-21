function checkRules(cache, className, doc, chain)
%CHECKRULES The cross-field checks a per-field check cannot make.
%
%   checkRules(CACHE, CLASSNAME, DOC, CHAIN) raises did2:build:ruleViolated when DOC
%   breaks one of them. Two kinds, both listed here so a reader has one place
%   to look:
%
%   1. THE SCHEMA'S OWN `rules`, read from every class in the chain. Each rule
%      the builder can check is implemented below BY NAME. A rule name the
%      builder does not know is an ERROR (did2:build:unknownRule), not a skip:
%      a builder that silently ignores a new rule would emit documents it has
%      not checked while appearing to have checked them.
%
%   2. BUILDER CHECKS that the schema states only in a field's documentation
%      (not as a machine-readable rule). Each cites where it is stated:
%        conditions_one_value     statement.conditions: "{variable, unit,
%                                 source_unit, approximate} plus exactly ONE
%                                 value form", holding one value
%        variable_once            statement.conditions: "a variable
%                                 appears at most once across a statement's
%                                 keys and conditions"; data.keys: variable
%                                 "UNIQUE within the list"
%        parameter_one_form       interaction.method.parameters (and the
%                                 standalone method's): the same entry --
%                                 exactly one of `term`, `quantity`, `count`,
%                                 `text`, `matrix` (`method_parameters`
%                                 before #88; `matrix` since #88, data_body
%                                 AMENDMENT 4, where the whole array is ONE
%                                 value)
%        parameter_variable_once  method.parameters: variable "UNIQUE within
%                                 the list"
%        parameters_not_both      interaction.method: "A statement carries
%                                 the inline `method` block OR this edge
%                                 [method_id], NEVER BOTH" (before #88:
%                                 inline `method_parameters` OR
%                                 `method_parameters_id`)
%        key_n_matches            data.keys: n is the length of the dimension,
%                                 so it equals the number of positions in
%                                 `quantity.value` or `term`
%        datum_order_multikey     datum_order (on `data` since did-schema
%                                 #88, on sampled_body before): "REQUIRED in
%                                 practice whenever there is more than one key"
%        require_inherited        a class's `require_inherited` list: an
%                                 inherited optional field or edge the class
%                                 makes required

arguments
    cache (1,1) did2.schema.cache
    className {mustBeText}
    doc (1,1) struct
    chain = {}
end

if isempty(chain)
    chain = cache.classChain(className);
end
blocks = setdiff(fieldnames(doc), {'document_class', 'depends_on', 'files', 'file'}, 'stable');
edgeNames = {};
if isfield(doc, 'depends_on') && ~isempty(doc.depends_on)
    edgeNames = {doc.depends_on.name};
end

% ---- 1. the schema's rules ------------------------------------------------
for c = 1:numel(chain)
    s = cache.getClass(chain{c});
    if ~isfield(s, 'rules') || isempty(s.rules)
        continue;
    end
    rules = asDefs(s.rules);
    for r = 1:numel(rules)
        ruleName = char(rules{r}.name);
        switch ruleName
            case 'key_regular_origin_spacing'
                forEachKey(doc, blocks, @keyRegularOriginSpacing);
            case 'key_positions_one_form'
                forEachKey(doc, blocks, @keyPositionsOneForm);
            case 'key_chunk_sampled_only'
                if ~any(strcmp(chain, 'sampled_body'))
                    forEachKey(doc, blocks, @keyNoChunk);
                end
            case {'datum_type_when_bytes', 'data_type_when_bytes'}
                % `data_type_when_bytes` since 2026-10-08 (the field renamed);
                % the part a per-document check can see is the same: a value
                % whose bytes are in a body must say how they are encoded.
                f = strrep(ruleName, '_when_bytes', '');
                if isTrue(findField(doc, blocks, 'data_body')) ...
                        && isAbsent(findField(doc, blocks, f))
                    violated(ruleName, className, ...
                        sprintf('`data_body` is true, so `%s` must be given.', f));
                end
            case 'clock_with_start'
                % an offset -- a start or an end -- means nothing until its
                % clock is named
                v = findField(doc, blocks, 'value');
                hasOffset = isstruct(v) && ((isfield(v, 'start') && ~isAbsent(v.start)) ...
                    || (isfield(v, 'end') && ~isAbsent(v.end)));
                if hasOffset && (~isfield(v, 'clock') || isAbsent(v.clock))
                    violated(ruleName, className, ...
                        '`value.start` or `value.end` is given, so `value.clock` must be too.');
                end
            case 'end_consistent'
                endConsistent(findField(doc, blocks, 'value'), ruleName, className);
            case 'ingredients_or_product'
                v = findField(doc, blocks, 'value');
                hasIngredients = isstruct(v) && isfield(v, 'ingredients') && ~isAbsent(v.ingredients);
                if ~hasIngredients && ~any(strcmp(edgeNames, 'product_id'))
                    violated(ruleName, className, ...
                        'give `value.ingredients`, a `product_id` edge, or both.');
                end
            otherwise
                error('did2:build:unknownRule', ...
                    ['Class "%s" declares rule "%s", which did2.build does ' ...
                     'not know how to check. Add it to +build/private/' ...
                     'checkRules.m rather than building unchecked documents.'], ...
                    chain{c}, ruleName);
        end
    end
end

% ---- 2. builder checks ----------------------------------------------------
keys = findField(doc, blocks, 'keys');
conditions = findField(doc, blocks, 'conditions');
seen = {};
if isstruct(keys)
    for k = 1:numel(keys)
        seen{end+1} = termKey(keys(k).variable); %#ok<AGROW>
        keyNMatches(keys(k), k, className);
    end
end
if isstruct(conditions)
    for k = 1:numel(conditions)
        given = valueForms(conditions(k));
        if numel(given) ~= 1
            violated('conditions_one_value', className, sprintf( ...
                'condition %d carries %d value forms (%s); exactly one of term, quantity, count, text, matrix.', ...
                k, numel(given), strjoin(given, ', ')));
        end
        n = valueCount(conditions(k), given{1});
        if n ~= 1
            violated('conditions_one_value', className, sprintf( ...
                'condition %d carries %d values; a condition is ONE value true of the whole statement (use a key for more).', k, n));
        end
        seen{end+1} = termKey(conditions(k).variable); %#ok<AGROW>
    end
end
dup = duplicates(seen);
if ~isempty(dup)
    violated('variable_once', className, sprintf( ...
        'variable(s) %s appear more than once across keys and conditions.', strjoin(dup, ', ')));
end

hasMethodEdge = any(ismember(edgeNames, {'method_id', 'method_parameters_id'}));
for b = 1:numel(blocks)
    block = doc.(blocks{b});
    if ~isstruct(block) || ~isscalar(block)
        continue;
    end
    [params, inline] = parametersOf(blocks{b}, block);
    if inline && hasMethodEdge
        violated('parameters_not_both', className, ...
            ['an inline `method` (its term or parameters) and a `method_id` edge ' ...
             'were both given (`method_parameters` / `method_parameters_id` before ' ...
             'did-schema #88).']);
    end
    if isAbsent(params) || ~isstruct(params)
        continue;
    end
    pseen = cell(1, numel(params));
    for k = 1:numel(params)
        given = valueForms(params(k));
        if numel(given) ~= 1
            violated('parameter_one_form', className, sprintf( ...
                'parameter %d carries %d value forms (%s); exactly one of term, quantity, count, text, matrix.', ...
                k, numel(given), strjoin(given, ', ')));
        end
        if valueCount(params(k), given{1}) ~= 1
            violated('parameter_one_form', className, sprintf( ...
                'parameter %d carries %d values; a parameter is ONE value.', ...
                k, valueCount(params(k), given{1})));
        end
        pseen{k} = termKey(params(k).variable);
    end
    dup = duplicates(pseen);
    if ~isempty(dup)
        violated('parameter_variable_once', className, sprintf( ...
            'parameter variable(s) %s appear more than once.', strjoin(dup, ', ')));
    end
end

if any(strcmp(chain, 'sampled_body')) && isstruct(keys) && numel(keys) > 1 ...
        && isAbsent(findField(doc, blocks, 'datum_order'))
    violated('datum_order_multikey', className, sprintf( ...
        'the body has %d keys, so `datum_order` (''C'' or ''F'') must be given.', numel(keys)));
end

for c = 1:numel(chain)
    s = cache.getClass(chain{c});
    if ~isfield(s, 'require_inherited') || isempty(s.require_inherited)
        continue;
    end
    required = cellstr(s.require_inherited);
    for r = 1:numel(required)
        name = required{r};
        if any(strcmp(edgeNames, name))
            continue;
        end
        v = findField(doc, blocks, name);
        if isAbsent(v)
            violated('require_inherited', className, sprintf( ...
                'class "%s" requires the inherited `%s`, which was not given.', chain{c}, name));
        end
    end
end
end

% -------------------------------------------------------------------------

function endConsistent(v, ruleName, className)
% `value.end` needs `value.start`, is not before it, and agrees with
% `value.duration` when both are given (end = start + duration, to 1 ms).
% Works for both time-reference forms: an offset cell {seconds} or a
% wall-clock cell {utc}.
if ~isstruct(v) || ~isfield(v, 'end') || isAbsent(v.end)
    return;
end
if ~isfield(v, 'start') || isAbsent(v.start)
    violated(ruleName, className, '`value.end` is given without `value.start`.');
end
t0 = timeOf(v.start);
t1 = timeOf(v.end);
if isnan(t0) || isnan(t1)
    return;   % a source value with no canonical time: nothing to compare
end
if t1 < t0
    violated(ruleName, className, sprintf( ...
        '`value.end` is %.3f s before `value.start`.', t0 - t1));
end
if isfield(v, 'duration') && ~isAbsent(v.duration) && isfield(v.duration, 'seconds') ...
        && ~isAbsent(v.duration.seconds)
    d = double(v.duration.seconds);
    if abs((t1 - t0) - d) > 1e-3
        violated(ruleName, className, sprintf( ...
            ['`value.duration` (%.3f s) and `value.end` - `value.start` (%.3f s) ' ...
             'disagree; when both are given, end = start + duration.'], d, t1 - t0));
    end
end
end

function t = timeOf(cell)
% seconds: an offset cell's `seconds`, or a wall-clock cell's `utc` as
% seconds since 1970 (NaN when neither can be read)
t = NaN;
if ~isstruct(cell)
    return;
end
if isfield(cell, 'seconds') && ~isAbsent(cell.seconds)
    t = double(cell.seconds);
elseif isfield(cell, 'utc') && ~isAbsent(cell.utc)
    u = char(cell.utc);
    for fmt = {'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''', 'yyyy-MM-dd''T''HH:mm:ss''Z''', ...
            'yyyy-MM-dd''T''HH:mm''Z'''}
        try
            d = datetime(u, 'InputFormat', fmt{1}, 'TimeZone', 'UTC');
            t = posixtime(d);
            return;
        catch
        end
    end
end
end

function v = findField(doc, blocks, name)
v = [];
for b = 1:numel(blocks)
    block = doc.(blocks{b});
    if isstruct(block) && isscalar(block) && isfield(block, name)
        v = block.(name);
        return;
    end
end
end

function forEachKey(doc, blocks, fn)
keys = findField(doc, blocks, 'keys');
if ~isstruct(keys)
    return;
end
for k = 1:numel(keys)
    fn(keys(k), k);
end
end

function keyRegularOriginSpacing(key, k)
regular = isfield(key, 'regular') && isTrue(key.regular);
hasOrigin = isfield(key, 'origin') && ~isAbsent(key.origin);
hasSpacing = isfield(key, 'spacing') && ~isAbsent(key.spacing);
if regular ~= hasOrigin || regular ~= hasSpacing
    violated('key_regular_origin_spacing', sprintf('key %d', k), ...
        'a key carries `origin` and `spacing` if and only if `regular` is true.');
end
end

function keyPositionsOneForm(key, k)
regular = isfield(key, 'regular') && isTrue(key.regular);
forms = {'quantity', 'term', 'positions_from'};
given = forms(cellfun(@(f) isfield(key, f) && ~isAbsent(key.(f)), forms));
if regular && ~isempty(given)
    violated('key_positions_one_form', sprintf('key %d', k), ...
        sprintf('a regular key carries none of quantity/term/positions_from; got %s.', strjoin(given, ', ')));
elseif ~regular && numel(given) ~= 1
    violated('key_positions_one_form', sprintf('key %d', k), ...
        sprintf('a key that is not regular carries exactly one of quantity, term, positions_from; got %d.', numel(given)));
end
end

function keyNoChunk(key, k)
if isfield(key, 'chunk') && ~isAbsent(key.chunk)
    violated('key_chunk_sampled_only', sprintf('key %d', k), ...
        '`chunk` is set only on the keys of a sampled_body.');
end
end

function keyNMatches(key, k, className)
n = key.n;
if isfield(key, 'quantity') && ~isAbsent(key.quantity)
    for f = {'value', 'source_value'}
        if isfield(key.quantity, f{1}) && ~isAbsent(key.quantity.(f{1})) ...
                && numel(key.quantity.(f{1})) ~= n
            violated('key_n_matches', className, sprintf( ...
                'key %d has n = %d but %d quantity.%s.', k, n, numel(key.quantity.(f{1})), f{1}));
        end
    end
end
if isfield(key, 'term') && ~isAbsent(key.term) && numel(key.term) ~= n
    violated('key_n_matches', className, sprintf( ...
        'key %d has n = %d but %d terms.', k, n, numel(key.term)));
end
end

function [params, inline] = parametersOf(blockName, block)
%PARAMETERSOF A block's method settings, and whether they sit inline.
%   On the did-schema #88 shape (DID-schema V_eta_method_plan.md) a
%   statement, relation or clock_alignment_configuration carries
%   `method: {term, parameters}` inline and the standalone `method` document
%   carries `parameters` in its own block; before #88 the list was
%   `method_parameters`, inline on an interaction and on the standalone
%   `method_parameters` document. INLINE is true when the block carries an
%   inline method (on #88 its term alone counts: the block OR the edge, never
%   both) -- the standalone document's own list is not inline.
params = [];
inline = false;
if isfield(block, 'method') && isstruct(block.method) && isscalar(block.method) ...
        && (isfield(block.method, 'term') || isfield(block.method, 'parameters'))
    inline = true;
    if isfield(block.method, 'parameters')
        params = block.method.parameters;
    end
elseif strcmp(blockName, 'method') && isfield(block, 'parameters')
    params = block.parameters;
elseif isfield(block, 'method_parameters') && ~isAbsent(block.method_parameters)
    params = block.method_parameters;
    inline = ~strcmp(blockName, 'method_parameters');
end
end

function given = valueForms(entry)
%VALUEFORMS The value forms a condition or parameter entry carries.
arguments
    entry (1,1) struct
end

given = {};
for f = {'term', 'quantity', 'count', 'text', 'matrix'}
    if isfield(entry, f{1}) && ~isAbsent(entry.(f{1}))
        given{end+1} = f{1}; %#ok<AGROW>
    end
end
end

function n = valueCount(entry, form)
%VALUECOUNT How many values one value form of an entry holds.
arguments
    entry (1,1) struct
    form (1,:) char
end

v = entry.(form);
switch form
    case 'quantity'
        n = 0;
        if isstruct(v) && isfield(v, 'value'); n = numel(v.value); end
    case 'matrix'
        n = double(~isAbsent(v));   % the whole array is ONE value (AMENDMENT 4)
    case 'text'
        n = double(~isAbsent(v));
        if ischar(v) && size(v, 1) > 1; n = size(v, 1); end
        if isstring(v); n = numel(v); end
    otherwise   % term (a struct per value), count
        n = numel(v);
end
end

function s = termKey(term)
%TERMKEY A comparable identity for an ontology term: the node when there is
%   one, else the name (T8: matched by name while the node is staged).
s = '';
if isstruct(term) && isfield(term, 'node') && ~isempty(term.node)
    s = char(term.node);
elseif isstruct(term) && isfield(term, 'name')
    s = char(term.name);
end
end

function d = duplicates(c)
d = {};
c = c(~cellfun(@isempty, c));
if isempty(c)
    return;
end
[u, ~, idx] = unique(c);
counts = accumarray(idx(:), 1);
if ~isempty(counts)
    d = reshape(u(counts > 1), 1, []);
end
end

function tf = isTrue(v)
tf = ~isempty(v) && (islogical(v) || isnumeric(v)) && all(v(:));
end

function violated(ruleName, where, message)
error('did2:build:ruleViolated', '%s (%s): %s', ruleName, where, message);
end
