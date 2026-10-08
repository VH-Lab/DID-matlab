function checkRules(cache, className, doc)
%CHECKRULES The cross-field checks a per-field check cannot make.
%
%   checkRules(CACHE, CLASSNAME, DOC) raises did2:build:ruleViolated when DOC
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
%        conditions_one_value     statement.conditions: "carries
%                                 exactly one value form ... Cardinality
%                                 exactly 1"
%        variable_once            statement.conditions: "a variable
%                                 appears at most once across a statement's
%                                 keys and conditions"; data.keys: variable
%                                 "UNIQUE within the list"
%        parameter_one_form       interaction.method_parameters:
%                                 numeric `value`, categorical `term` or
%                                 free-string `text` -- one of them
%        parameter_variable_once  method_parameters: variable "UNIQUE within
%                                 the list"
%        parameters_not_both      interaction.method_parameters: "the
%                                 statement points at a method_parameters
%                                 document by method_parameters_id. Never both."
%        key_n_matches            data.keys: n is the length of the dimension,
%                                 so it equals the number of values/labels
%        datum_order_multikey     sampled_body.datum_order: "REQUIRED in
%                                 practice whenever there is more than one key"
%        require_inherited        a class's `require_inherited` list: an
%                                 inherited optional field or edge the class
%                                 makes required

chain = cache.classChain(className);
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
            case 'datum_type_when_bytes'
                if isTrue(findField(doc, blocks, 'data_body')) ...
                        && isAbsent(findField(doc, blocks, 'datum_type'))
                    violated(ruleName, className, ...
                        '`data_body` is true, so `datum_type` must be given.');
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
        forms = {'term', 'count', 'quantity'};
        given = forms(cellfun(@(f) isfield(conditions(k), f) && ~isAbsent(conditions(k).(f)), forms));
        if numel(given) ~= 1
            violated('conditions_one_value', className, sprintf( ...
                'condition %d carries %d value forms (%s); exactly one of term, count, quantity.', ...
                k, numel(given), strjoin(given, ', ')));
        end
        n = numel(conditions(k).(given{1}).value);
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

for b = 1:numel(blocks)
    block = doc.(blocks{b});
    if ~isstruct(block) || ~isfield(block, 'method_parameters') || isAbsent(block.method_parameters)
        continue;
    end
    params = block.method_parameters;
    pseen = cell(1, numel(params));
    for k = 1:numel(params)
        forms = {'value', 'term', 'text'};
        given = forms(cellfun(@(f) isfield(params(k), f) && ~isAbsent(params(k).(f)), forms));
        if numel(given) ~= 1
            violated('parameter_one_form', className, sprintf( ...
                'parameter %d carries %d value forms (%s); exactly one of value, term, text.', ...
                k, numel(given), strjoin(given, ', ')));
        end
        pseen{k} = termKey(params(k).variable);
    end
    dup = duplicates(pseen);
    if ~isempty(dup)
        violated('parameter_variable_once', className, sprintf( ...
            'parameter variable(s) %s appear more than once.', strjoin(dup, ', ')));
    end
    if ~strcmp(blocks{b}, 'method_parameters') && any(strcmp(edgeNames, 'method_parameters_id'))
        violated('parameters_not_both', className, ...
            'inline `method_parameters` and a `method_parameters_id` edge were both given.');
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
forms = {'values', 'labels', 'positions_from'};
given = forms(cellfun(@(f) isfield(key, f) && ~isAbsent(key.(f)), forms));
if regular && ~isempty(given)
    violated('key_positions_one_form', sprintf('key %d', k), ...
        sprintf('a regular key carries none of values/labels/positions_from; got %s.', strjoin(given, ', ')));
elseif ~regular && numel(given) ~= 1
    violated('key_positions_one_form', sprintf('key %d', k), ...
        sprintf('a key that is not regular carries exactly one of values, labels, positions_from; got %d.', numel(given)));
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
if isfield(key, 'values') && ~isAbsent(key.values) && isfield(key.values, 'values') ...
        && numel(key.values.values) ~= n
    violated('key_n_matches', className, sprintf( ...
        'key %d has n = %d but %d values.', k, n, numel(key.values.values)));
end
if isfield(key, 'labels') && ~isAbsent(key.labels) && numel(key.labels) ~= n
    violated('key_n_matches', className, sprintf( ...
        'key %d has n = %d but %d labels.', k, n, numel(key.labels)));
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
