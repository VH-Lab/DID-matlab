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
%      The data_body AMENDMENT 6 rules (covariate_one_value_form,
%      covariate_along, covariate_single_dimension_forms, covariate_cyclic,
%      dimension_chunk_sampled_only, covariate_shape, variable_once) are
%      checked in part 2 by checkDimensionsCovariates, for every document,
%      under those names. covariate_shape and variable_once were builder-only
%      checks until did-schema named them schema rules (Jess Haley 2026-10-22
%      [covariate rules named], 6.1a); their names were already the schema's.
%      covariate_cyclic: `cyclic` only on an `origin`+`spacing` or a
%      `quantity` covariate along one dimension (Jess Haley 2026-10-22
%      [covariate details], 5.1a; numeric `count` and `matrix` before).
%      dimension_chunk_sampled_only also refuses a `chunk` on an
%      acquisition_epoch's dimensions ([covariate details], 5.3a).
%
%   2. BUILDER CHECKS that the schema states only in a field's documentation
%      (not as a machine-readable rule). Each cites where it is stated:
%        conditions_one_value     statement.conditions: "{variable, unit,
%                                 source_unit, approximate} plus exactly ONE
%                                 value form", holding one value
%        variable_once            (a schema rule since 2026-10-22, part 1
%                                 above; checked here) did-schema data_body
%                                 AMENDMENT 6: "A variable appears at most
%                                 once across a statement's conditions, its
%                                 value's covariates, and any one of its
%                                 bodies' covariates" -- per document, its
%                                 conditions and covariates
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
%        covariate_shape          (a schema rule since 2026-10-22, part 1
%                                 above; checked here) AMENDMENT 6: "Shape: the extents of the
%                                 `along` dimensions, in that order; for
%                                 `matrix`, those extents followed by the
%                                 array's own shape" (was key_n_matches)
%        datum_order_multidimension  datum_order (on `data` since did-schema
%                                 #88, on sampled_body before): stated by a
%                                 writer with more than one dimension; the
%                                 builder requires it on a sampled_body
%                                 (was datum_order_multikey)
%        require_inherited        a class's `require_inherited` list: an
%                                 inherited optional field or edge the class
%                                 makes required
%   (Schema rules ingredients_match_edges and ingredient_in_formulation, did-schema
%   dose.json 2026-10-21: the first is checked; the second needs the formulation
%   document and is left to a batch check, by name.)
%        value_in_set             binding_registry_meta.json: a variable whose
%                                 row lists `values` takes its term value
%                                 from that closed list (Jess Haley,
%                                 2026-10-21); did2:build:valueOutsideSet,
%                                 armed with strictMode('TermRegistry')

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
            case {'covariate_one_value_form', 'covariate_along', ...
                    'covariate_single_dimension_forms', 'covariate_cyclic', ...
                    'dimension_chunk_sampled_only', 'covariate_shape', ...
                    'variable_once'}
                % did-schema data_body AMENDMENT 6 (Jess Haley, 2026-10-22
                % [covariates]). Every rule on `dimensions` / `covariates`
                % is checked, whether or not the schema names it, by
                % checkDimensionsCovariates below (part 2), so a schema
                % that names one adds no second check here.
                continue;
            case {'datum_type_when_bytes', 'data_type_when_bytes'}
                % `data_type_when_bytes` since 2026-10-08 (the field renamed).
                % Jess Haley, 2026-10-21 (did-schema data_body AMENDMENT 5):
                % `data_type` is required only when the bytes are a PLAIN
                % ARRAY -- a sampled_body, or an untyped inline array; an
                % opaque_body's `format` term is the encoding, so
                % `data_body: true` alone no longer demands it. A body's kind
                % is not visible on its owner, so the sampled_body half is a
                % batch check; the part a per-document check can see is an
                % inline value given as a bare numeric or text array, which
                % no declared cell is.
                f = strrep(ruleName, '_when_bytes', '');
                v = findField(doc, blocks, 'value');
                if (isnumeric(v) || ischar(v) || isstring(v)) && ~isAbsent(v) ...
                        && isAbsent(findField(doc, blocks, f))
                    violated(ruleName, className, ...
                        sprintf('`value` is a bare array the schema does not type, so `%s` must be given.', f));
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
            case 'value_inline_or_body'
                % did-schema data_body AMENDMENT 5 (Jess Haley, 2026-10-21;
                % decided, not signed): a value is inline (`value` filled) or
                % in data bodies (`data_body` true), never neither. It
                % replaces the required `value` of term, date, logical,
                % polynomial, model_fit, tuning_curve, contrast_sensitivity,
                % harmonic_component and receptive_field. CLARIFICATION
                % (Jess Haley, 2026-10-21): a statement may also take its
                % value from a shared value document through a non-empty
                % `value_id` edge (did-schema statement.json); the shared
                % document itself is inline or in bodies.
                if ~isTrue(findField(doc, blocks, 'data_body')) ...
                        && isBlankValue(findField(doc, blocks, 'value')) ...
                        && ~hasEdge(doc, 'value_id')
                    violated(ruleName, className, ...
                        ['`value` is empty and `data_body` is not true: the ' ...
                         'value is neither inline nor in data bodies.']);
                end
            case 'ingredients_or_product'
                % A statement whose value kind is `formulation` (a bath: a
                % manipulation valued by its formulation, Jess Haley,
                % 2026-10-21) takes its value through `value_id`; its own
                % `value` is then empty and the shared formulation document,
                % checked when it is built, holds the ingredients
                % (did-schema statement.json, `value_id`). Ported from
                % claude/port-88 ff6d542.
                if hasEdge(doc, 'value_id')
                    continue;
                end
                v = findField(doc, blocks, 'value');
                hasIngredients = isstruct(v) && isfield(v, 'ingredients') && ~isAbsent(v.ingredients);
                if ~hasIngredients && ~any(strcmp(edgeNames, 'product_id'))
                    violated(ruleName, className, ...
                        'give `value.ingredients`, a `product_id` edge, or both.');
                end
            case 'ingredients_match_edges'
                % did-schema dose.json (Jess Haley, 2026-10-21 [dose per
                % ingredient]): `value.ingredients` has exactly one entry per
                % `ingredient_id` edge, in the same order. Checkable here.
                v = findField(doc, blocks, 'value');
                nIng = 0;
                if isstruct(v) && isfield(v, 'ingredients') && ~isAbsent(v.ingredients)
                    nIng = numel(v.ingredients);
                end
                nEdge = sum(strcmp(edgeNames, 'ingredient_id') ...
                    | ~cellfun(@isempty, regexp(edgeNames, '^ingredient_id_\d+$', 'once')));
                if nIng ~= nEdge
                    violated(ruleName, className, sprintf( ...
                        ['`value.ingredients` has %d entr(ies) and the dose has %d ' ...
                         '`ingredient_id` edge(s); they must match one to one.'], nIng, nEdge));
                end
            case 'ingredient_in_formulation'
                % NOT checkable on the dose alone: it needs the formulation
                % the dose's formulation_id names (did-schema dose.json: "a
                % batch (database) check, or a builder check when the
                % formulation is at hand"). did2.build builds one document and
                % never has the formulation at hand, so this rule is KNOWN and
                % deliberately left to a batch check -- listed here so it is
                % not an unknown rule, and so the gap is in one place. A
                % caller that holds both documents (a migrator, an import)
                % runs did2.build.checkDoseIngredients(dose, formulation).
                continue;
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
% Only the blocks that declare AMENDMENT 6's pair: `data` (and every value
% class under it) and `acquisition_epoch`. coordinate_system has its own,
% unrelated `dimensions` field ({axis, positive_direction, spacing}).
a6Blocks = blocks(ismember(blocks, {'data', 'acquisition_epoch'}));
dims = findField(doc, a6Blocks, 'dimensions');
covs = findField(doc, a6Blocks, 'covariates');
conditions = findField(doc, blocks, 'conditions');
seen = checkDimensionsCovariates(dims, covs, any(strcmp(chain, 'sampled_body')), className);
% [covariate details] 5.3a (Jess Haley 2026-10-22): an acquisition_epoch's
% dimensions carry no `chunk`. Checked on that block by name, so a document
% carrying both blocks cannot hide it behind the first one findField reads.
if isfield(doc, 'acquisition_epoch') && isstruct(doc.acquisition_epoch) ...
        && isscalar(doc.acquisition_epoch) && isfield(doc.acquisition_epoch, 'dimensions')
    eDims = doc.acquisition_epoch.dimensions;
    if iscell(eDims); eDims = [eDims{:}]; end
    if isstruct(eDims) && isfield(eDims, 'chunk')
        for k = 1:numel(eDims)
            if ~isAbsent(eDims(k).chunk)
                violated('dimension_chunk_sampled_only', ...
                    sprintf('%s acquisition_epoch dimension %d', className, k - 1), ...
                    'an acquisition_epoch''s dimensions carry no `chunk`; `chunk` is a sampled_body''s.');
            end
        end
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
                'condition %d carries %d values; a condition is ONE value true of the whole statement (use a covariate along a dimension for more).', k, n));
        end
        seen{end+1} = termKey(conditions(k).variable); %#ok<AGROW>
    end
end
dup = duplicates(seen);
if ~isempty(dup)
    violated('variable_once', className, sprintf( ...
        'variable(s) %s appear more than once across covariates and conditions.', strjoin(dup, ', ')));
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

if any(strcmp(chain, 'sampled_body')) && isstruct(dims) && numel(dims) > 1 ...
        && isAbsent(findField(doc, blocks, 'datum_order'))
    violated('datum_order_multidimension', className, sprintf( ...
        'the body has %d dimensions, so `datum_order` (''C'' or ''F'') must be given.', numel(dims)));
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

valueInClosedSet(cache, doc, blocks, className);
end

function valueInClosedSet(cache, doc, blocks, className)
% value_in_set: a statement whose variable's binding row lists `values` (a
% CLOSED list; DID-schema binding_registry_meta.json, Jess Haley
% 2026-10-21) takes its term value from that list. Armed with the term
% registry check (strictMode 'TermRegistry'); a migration disarms both.
variable = findField(doc, blocks, 'variable');
if ~isstruct(variable) || ~did2.schema.cache.strictMode('TermRegistry')
    return;
end
value = [];
for b = 1:numel(blocks)
    block = doc.(blocks{b});
    if isstruct(block) && isscalar(block) && isfield(block, 'value') ...
            && isstruct(block.value) && isfield(block.value, 'node')
        value = block.value;
        break;
    end
end
if isempty(value)
    return;
end
[tf, reason] = did2.schema.valueInSet(variable, value, cache.bindingRegistry);
if ~tf
    error('did2:build:valueOutsideSet', ...
        ['value_in_set (%s): %s. A closed value list is changed in DID-schema''s ' ...
         'binding_registry_meta.json, through review.'], className, reason);
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

function seen = checkDimensionsCovariates(dims, covs, isSampledBody, className)
%CHECKDIMENSIONSCOVARIATES did-schema data_body AMENDMENT 6 (Jess Haley,
%   2026-10-22 [covariates], [along by index], [matrix covariate]): the rules
%   on a value's `dimensions` and `covariates`. Returns the covariates'
%   variable identities, for variable_once.
seen = {};
nDims = 0;
extents = [];
if isstruct(dims)
    nDims = numel(dims);
    extents = zeros(1, nDims);
    for k = 1:nDims
        extents(k) = double(dims(k).n);
        if ~isSampledBody && isfield(dims, 'chunk') && ~isAbsent(dims(k).chunk)
            violated('dimension_chunk_sampled_only', sprintf('%s dimension %d', className, k - 1), ...
                '`chunk` is set only on the dimensions of a sampled_body.');
        end
    end
end
if ~isstruct(covs)
    return;
end
for k = 1:numel(covs)
    c = covs(k);
    where = sprintf('%s covariate %d', className, k - 1);
    along = [];
    if isfield(c, 'along'); along = c.along; end
    if iscell(along); along = cell2mat(along); end
    along = double(reshape(along, 1, []));
    if isempty(along)
        violated('covariate_along', where, ...
            'a covariate runs along at least one dimension; a fact true of the whole value is a condition.');
    end
    if numel(unique(along)) ~= numel(along)
        violated('covariate_along', where, sprintf('`along` repeats a dimension: %s.', mat2str(along)));
    end
    if any(along < 0 | along ~= round(along) | along >= nDims)
        violated('covariate_along', where, sprintf( ...
            '`along` %s names a dimension the value does not have (it has %d; indices are 0-based).', ...
            mat2str(along), nDims));
    end
    hasOrigin = isfield(c, 'origin') && ~isAbsent(c.origin);
    hasSpacing = isfield(c, 'spacing') && ~isAbsent(c.spacing);
    if hasOrigin ~= hasSpacing
        violated('covariate_one_value_form', where, '`origin` and `spacing` are given together or not at all.');
    end
    given = {};
    if hasOrigin && hasSpacing; given{end+1} = 'origin+spacing'; end
    for f = {'quantity', 'count', 'term', 'text', 'logical', 'matrix', 'document'}
        if isfield(c, f{1}) && ~isAbsent(c.(f{1})) ...
                && ~(strcmp(f{1}, 'document') && isequal(c.document, -1))   % -1: the blank, not used
            given{end+1} = f{1}; %#ok<AGROW>
        end
    end
    if numel(given) ~= 1
        violated('covariate_one_value_form', where, sprintf( ...
            'carries %d value forms (%s); exactly one of origin+spacing, quantity, count, term, text, logical, matrix, document.', ...
            numel(given), strjoin(given, ', ')));
    end
    form = given{1};
    if any(strcmp(form, {'origin+spacing', 'document'})) && numel(along) ~= 1
        violated('covariate_single_dimension_forms', where, sprintf( ...
            'a covariate given by %s runs along exactly one dimension; `along` has %d.', form, numel(along)));
    end
    if isfield(c, 'cyclic') && isTrue(c.cyclic) ...
            && ~(any(strcmp(form, {'origin+spacing', 'quantity'})) && numel(along) == 1)
        % Jess Haley 2026-10-22 [covariate details], 5.1a
        violated('covariate_cyclic', where, sprintf( ...
            ['`cyclic` applies only to an origin+spacing or a quantity covariate ' ...
             'along exactly one dimension (this one is %s along %d).'], form, numel(along)));
    end
    covariateShape(c, form, extents(along + 1), where);
    seen{end+1} = termKey(c.variable); %#ok<AGROW>
end
end

function covariateShape(c, form, ext, where)
% Shape: the extents of the `along` dimensions, in that order; for `matrix`,
% those extents followed by the array's own shape (AMENDMENT 6).
switch form
    case {'origin+spacing', 'document'}
        return;   % generated, or n entries of another document (a batch check)
    case 'quantity'
        for f = {'value', 'source_value'}
            if isfield(c.quantity, f{1}) && ~isAbsent(c.quantity.(f{1}))
                shapeMatches(c.quantity.(f{1}), ext, false, sprintf('quantity.%s', f{1}), where);
            end
        end
    case 'matrix'
        shapeMatches(c.matrix, ext, true, 'matrix', where);
    otherwise
        shapeMatches(c.(form), ext, false, form, where);
end
end

function shapeMatches(v, ext, isMatrix, what, where)
if isMatrix
    sz = size(v);
    sz(end+1:numel(ext)) = 1;
    if numel(ext) == 1 && ext == 1 && sz(1) ~= 1
        % one position: JSON may drop the leading length-1 axis of the array
        return;
    end
    if ~isequal(sz(1:numel(ext)), ext)
        violated('covariate_shape', where, sprintf( ...
            '`%s` has leading shape %s, but the `along` dimensions'' extents are %s.', ...
            what, mat2str(sz(1:numel(ext))), mat2str(ext)));
    end
    return;
end
if numel(v) ~= prod(ext)
    violated('covariate_shape', where, sprintf( ...
        '`%s` has %d value(s), but the `along` dimensions'' extents are %s (%d positions).', ...
        what, numel(v), mat2str(ext), prod(ext)));
end
if numel(ext) > 1 && ~isvector(v)
    % along several dimensions the array keeps their shape (a flat list of
    % the right count -- a struct array the builder flattened -- is accepted)
    sz = size(v);
    sz(end+1:numel(ext)) = 1;
    if ~isequal(sz(1:numel(ext)), ext)
        violated('covariate_shape', where, sprintf( ...
            '`%s` has shape %s, but the `along` dimensions'' extents are %s.', ...
            what, mat2str(size(v)), mat2str(ext)));
    end
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

function tf = isBlankValue(v)
% Nothing filled at any depth: absent, or a struct / cell whose every leaf is
% blank ({node: '', name: ''} is a blank term). false and 0 are values.
if iscell(v)
    tf = all(cellfun(@isBlankValue, v));
elseif isstruct(v)
    tf = true;
    names = fieldnames(v);
    for e = 1:numel(v)
        for n = 1:numel(names)
            if ~isBlankValue(v(e).(names{n}))
                tf = false;
                return;
            end
        end
    end
else
    tf = isAbsent(v);
end
end

function tf = hasEdge(doc, name)
tf = false;
if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
for k = 1:numel(doc.depends_on)
    d = doc.depends_on(k);
    if iscell(doc.depends_on)
        d = doc.depends_on{k};
    end
    % did2.build writes an edge as {name, document_id}; a v1-shaped one
    % carries `value`
    if strcmp(char(d.name), name) && ((isfield(d, 'document_id') && ~isAbsent(d.document_id)) ...
            || (isfield(d, 'value') && ~isAbsent(d.value)))
        tf = true;
        return;
    end
end
end

function violated(ruleName, where, message)
error('did2:build:ruleViolated', '%s (%s): %s', ruleName, where, message);
end
