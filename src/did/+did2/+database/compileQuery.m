function [whereSQL, params] = compileQuery(q, opts)
% did2.database.compileQuery  Compile a did2.query to a SQL WHERE clause.
%
%   [WHERESQL, PARAMS] = did2.database.compileQuery(Q) returns a SQL WHERE
%   clause and a bound-parameter cell array suitable for binding against
%   the `documents` table laid out in docs/v2/PLAN.md §3 (columns: id,
%   classname, class_version, session_id, datestamp, body, body_hash,
%   plus the `superclasses(doc_id, classname)` and
%   `depends_on(doc_id, name, document_id)` sidecar tables).
%
%   [WHERESQL, PARAMS] = did2.database.compileQuery(Q, 'QueryablePaths',
%   PATHS) tells the compiler that the dot-paths listed in the cellstr
%   PATHS are surfaced as `q_<flat>` STORED generated columns on the
%   documents table (PLAN.md §3.2). Scalar predicates against those
%   paths compile to a direct comparison against the column instead of
%   `json_extract(body, '$.<path>')`, which lets sqlite use the column's
%   index. Predicates against paths not in the set fall back to
%   json_extract.
%
%   This is the "JSON1 fallback" compiler called for in PLAN.md §9 step 3.
%   It uses sqlite3 json_extract / json_each / json_type for every
%   document-body predicate, EXISTS over the sidecar tables for `isa`
%   and `depends_on`, and emits a conservative `1=1` for predicates that
%   sqlite cannot express natively (e.g. `regexp`). did2.database.sqlitedb
%   always runs the in-memory evaluator over the SQL result set as a
%   correctness backstop, so the SQL clause is only required to be an
%   over-approximation of the true result.
%
%   See also: did2.query, did2.database.sqlitedb,
%   did-schema/schemas/did_query_model.md.

arguments
    q (1,1) did2.query
    opts.QueryablePaths cell = {}
    opts.QueryableArrayPaths = []
end

ctx = struct( ...
    'queryablePaths', {asPathSet(opts.QueryablePaths)}, ...
    'queryableArrayPaths', {asArrayPathMap(opts.QueryableArrayPaths)});
[whereSQL, params] = compileSearchstructArray(q.searchstructure, ctx);
end

function set = asPathSet(paths)
% Normalise a cellstr of paths into a containers.Map for O(1) lookup.
set = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(paths)
    p = char(paths{k});
    if isempty(p)
        continue;
    end
    set(p) = true;
end
end

function map = asArrayPathMap(arrayDefs)
% Normalise the QueryableArrayPaths input into a path -> affinity map.
% Accepts a struct array (one entry per sidecar-indexed path; the
% schema-cache shape with `.path` and `.affinity`), a cellstr of bare
% paths (assumes TEXT affinity), or empty for "no indexed array paths."
map = containers.Map('KeyType', 'char', 'ValueType', 'char');
if isempty(arrayDefs)
    return;
end
if isstruct(arrayDefs)
    for k = 1:numel(arrayDefs)
        p = char(arrayDefs(k).path);
        if isempty(p)
            continue;
        end
        if isfield(arrayDefs(k), 'affinity') && ~isempty(arrayDefs(k).affinity)
            map(p) = char(arrayDefs(k).affinity);
        else
            map(p) = 'TEXT';
        end
    end
elseif iscell(arrayDefs)
    for k = 1:numel(arrayDefs)
        p = char(arrayDefs{k});
        if ~isempty(p)
            map(p) = 'TEXT';
        end
    end
end
end

% -----------------------------------------------------------------------
% compile entry points
% -----------------------------------------------------------------------

function [sql, params] = compileSearchstructArray(ssArray, ctx)
% Conjunction over the elements of a search-structure array.
params = {};
if isempty(ssArray)
    sql = '1=1';
    return;
end
parts = cell(1, numel(ssArray));
for k = 1:numel(ssArray)
    [parts{k}, sub] = compileSearchstruct(ssArray(k), ctx);
    params = [params, sub]; %#ok<AGROW>
end
if isscalar(parts)
    % A single conjunct doesn't need outer parens; this keeps the SQL
    % readable and lets `compileQuery(did2.query('x','regexp','y'))`
    % return its scalar leaf verbatim ('1=1' for unsupported leaves,
    % `EXISTS (...)` for indexed lookups).
    sql = parts{1};
else
    sql = ['(' strjoin(parts, ') AND (') ')'];
end
end

function [sql, params] = compileSearchstruct(ss, ctx)
op = ss.operation;
isNeg = ~isempty(op) && op(1) == '~';
if isNeg
    op = op(2:end);
end
switch op
    case 'or'
        if isNeg
            error('did2:database:badOperator', ...
                'The `or` operator cannot be negated; negate the leaves.');
        end
        [a, pa] = compileSearchstructArray(asStructArray(ss.param1), ctx);
        [b, pb] = compileSearchstructArray(asStructArray(ss.param2), ctx);
        sql = ['((' a ') OR (' b '))'];
        params = [pa, pb];
        return;
    case 'isa'
        [sql, params] = compileIsa(ss.param1, isNeg);
        return;
    case 'depends_on'
        [sql, params] = compileDependsOn(ss.param1, ss.param2, isNeg);
        return;
    case 'hasfield'
        [sql, params] = compileHasField(ss.field, isNeg);
        return;
    case 'hasmember'
        [sql, params] = compileHasMember(ss.field, ss.param1, isNeg);
        return;
    case 'hasanysubfield_contains_string'
        % Sugar: <field>[*].<sub> + contains_string
        subPath = sprintf('%s[*].%s', ss.field, char(ss.param1));
        [sql, params] = compileScalar('contains_string', subPath, ss.param2, isNeg, ctx);
        return;
    case 'hasanysubfield_exact_string'
        [sql, params] = compileHasAnySubfieldExact(ss.field, ...
            ss.param1, ss.param2, isNeg);
        return;
    case {'exact_string', 'exact_string_anycase', 'contains_string', ...
          'regexp', 'exact_number', ...
          'lessthan', 'lessthaneq', 'greaterthan', 'greaterthaneq'}
        [sql, params] = compileScalar(op, ss.field, ss.param1, isNeg, ctx);
        return;
    otherwise
        error('did2:database:unknownOperator', ...
            'Unknown operator "%s".', ss.operation);
end
end

% -----------------------------------------------------------------------
% document-level operators
% -----------------------------------------------------------------------

function [sql, params] = compileIsa(className, isNeg)
% `isa` consults the `superclasses` sidecar table.
className = char(className);
existsSQL = ['EXISTS (SELECT 1 FROM superclasses sc ' ...
    'WHERE sc.doc_id = documents.id AND sc.classname = ?)'];
if isNeg
    sql = ['(NOT ' existsSQL ')'];
else
    sql = existsSQL;
end
params = {className};
end

function [sql, params] = compileDependsOn(name, value, isNeg)
% `depends_on` consults the `depends_on` sidecar table; `*` for `name` is
% the wildcard documented in did_query_model.md.
name  = char(name);
value = char(value);
if strcmp(name, '*')
    existsSQL = ['EXISTS (SELECT 1 FROM depends_on d ' ...
        'WHERE d.doc_id = documents.id AND d.document_id = ?)'];
    params = {value};
else
    existsSQL = ['EXISTS (SELECT 1 FROM depends_on d ' ...
        'WHERE d.doc_id = documents.id AND d.name = ? AND d.document_id = ?)'];
    params = {name, value};
end
if isNeg
    sql = ['(NOT ' existsSQL ')'];
else
    sql = existsSQL;
end
end

% -----------------------------------------------------------------------
% leaf operators over the document body
% -----------------------------------------------------------------------

function [sql, params] = compileHasField(fieldPath, isNeg)
% `hasfield` checks path presence, not value. json_type returns NULL for
% missing paths and non-NULL ('null', 'object', 'array', 'integer',
% 'real', 'text', 'true', 'false') for present-but-arbitrary values.
[stars, prefix, leaf] = splitPathOnStar(fieldPath);
if isempty(stars)
    expr = sprintf('json_type(body, ''%s'')', jsonPath(prefix));
    if isNeg
        sql = sprintf('(%s IS NULL)', expr);
    else
        sql = sprintf('(%s IS NOT NULL)', expr);
    end
    params = {};
    return;
end
% At least one [*]: existence over the join expansion.
[joinSQL, witnessAlias] = buildArrayJoin(stars);
witnessExpr = leafValueExpression(witnessAlias, leaf);
condition = sprintf('json_type(%s) IS NOT NULL', witnessExpr);
inner = sprintf('SELECT 1 %s WHERE %s', joinSQL, condition);
existsSQL = sprintf('EXISTS (%s)', inner);
if isNeg
    sql = sprintf('(NOT %s)', existsSQL);
else
    sql = existsSQL;
end
params = {};
end

function [sql, params] = compileHasMember(fieldPath, target, isNeg)
% `hasmember`: the field is a flat array and contains the scalar target.
[stars, prefix, leaf] = splitPathOnStar(fieldPath);
if isempty(stars)
    arrayExpr = sprintf('json_extract(body, ''%s'')', jsonPath(prefix));
    inner = sprintf('SELECT 1 FROM json_each(%s) je WHERE %s', ...
        arrayExpr, valueEquality('je.value', target));
    existsSQL = sprintf('EXISTS (%s)', inner);
    params = bindParam(target);
else
    % `arr[*].sub.hasmember`: leaf must address an array.
    [joinSQL, witnessAlias] = buildArrayJoin(stars);
    witnessExpr = leafValueExpression(witnessAlias, leaf);
    inner = sprintf(['SELECT 1 %s, json_each(%s) je ' ...
        'WHERE %s'], joinSQL, witnessExpr, valueEquality('je.value', target));
    existsSQL = sprintf('EXISTS (%s)', inner);
    params = bindParam(target);
end
if isNeg
    sql = sprintf('(NOT %s)', existsSQL);
else
    sql = existsSQL;
end
end

function [sql, params] = compileHasAnySubfieldExact(arrayPath, subNames, targets, isNeg)
% Correlated existence check used by depends_on lowering: each element of
% the array-of-structures at arrayPath must simultaneously match every
% (subNames{i}, targets{i}) pair.
if ~iscell(subNames),  subNames = {subNames};  end
if ~iscell(targets),   targets  = {targets};   end
arrayExpr = sprintf('json_extract(body, ''%s'')', jsonPath(arrayPath));
clauses = cell(1, numel(subNames));
params  = cell(1, numel(subNames));
for k = 1:numel(subNames)
    subExpr = sprintf('json_extract(je.value, ''%s'')', ...
        jsonPath(char(subNames{k})));
    clauses{k} = sprintf('%s = ?', subExpr);
    params{k}  = char(targets{k});
end
inner = sprintf('SELECT 1 FROM json_each(%s) je WHERE %s', ...
    arrayExpr, strjoin(clauses, ' AND '));
existsSQL = sprintf('EXISTS (%s)', inner);
if isNeg
    sql = sprintf('(NOT %s)', existsSQL);
else
    sql = existsSQL;
end
end

function [sql, params] = compileScalar(op, fieldPath, target, isNeg, ctx)
% Scalar operators. With `[*]` segments, lowers to EXISTS over json_each
% (or against the queryable_array_elem sidecar when the path is indexed).
[stars, prefix, leaf] = splitPathOnStar(fieldPath);

if isempty(stars)
    valueExpr = scalarValueExpression(prefix, ctx);
    [predicate, params] = scalarPredicate(op, valueExpr, target);
    if isNeg
        % Missing path -> ~op should be true. The generated column (or
        % `json_extract` fallback) returns NULL for unresolvable paths.
        sql = sprintf('(%s IS NULL OR NOT (%s))', valueExpr, predicate);
    else
        sql = predicate;
    end
    return;
end

if arrayPathIsIndexed(fieldPath, ctx)
    [sql, params] = compileScalarFromSidecar(op, fieldPath, target, isNeg, ctx);
    return;
end

[joinSQL, witnessAlias] = buildArrayJoin(stars);
witnessExpr = leafValueExpression(witnessAlias, leaf);
[predicate, params] = scalarPredicate(op, witnessExpr, target);
inner = sprintf('SELECT 1 %s WHERE %s', joinSQL, predicate);
existsSQL = sprintf('EXISTS (%s)', inner);
if isNeg
    sql = sprintf('(NOT %s)', existsSQL);
else
    sql = existsSQL;
end
end

function tf = arrayPathIsIndexed(fieldPath, ctx)
% True iff this exact '[*]'-bearing path is in the sidecar set.
tf = false;
if ~isfield(ctx, 'queryableArrayPaths')
    return;
end
m = ctx.queryableArrayPaths;
if ~isa(m, 'containers.Map') || m.Count == 0
    return;
end
tf = m.isKey(fieldPath);
end

function affinity = arrayPathAffinity(fieldPath, ctx)
% Look up the declared SQLite affinity for an indexed array path.
% Defaults to 'TEXT' when the path is present but lacks an affinity.
affinity = 'TEXT';
if ~isfield(ctx, 'queryableArrayPaths')
    return;
end
m = ctx.queryableArrayPaths;
if ~isa(m, 'containers.Map') || ~m.isKey(fieldPath)
    return;
end
v = m(fieldPath);
if ~isempty(v)
    affinity = v;
end
end

function [sql, params] = compileScalarFromSidecar(op, fieldPath, target, isNeg, ctx)
% Compile a scalar `[*]` predicate against queryable_array_elem.
%
% Positive predicates compile to `EXISTS (SELECT 1 FROM
% queryable_array_elem qae WHERE qae.doc_id = documents.id
% AND qae.path = ? AND <predicate>)`. Negation flips to `NOT EXISTS
% (...)` — which also matches docs with no sidecar rows at this path,
% preserving the in-memory rule that an unresolvable path under `~op`
% matches.
%
% Operators sqlite cannot express natively (regexp, multi-element
% exact_number) compile to a permissive `1=1` predicate; the
% in-memory post-filter in did2.database.sqlitedb.search enforces
% correctness regardless.
affinity = arrayPathAffinity(fieldPath, ctx);
valueExpr = sidecarValueExpression(affinity);
[predicate, params] = scalarPredicate(op, valueExpr, target);
inner = sprintf(['SELECT 1 FROM queryable_array_elem qae ' ...
    'WHERE qae.doc_id = documents.id AND qae.path = ? AND %s'], predicate);
params = [{fieldPath}, params];
existsSQL = sprintf('EXISTS (%s)', inner);
if isNeg
    sql = sprintf('(NOT %s)', existsSQL);
else
    sql = existsSQL;
end
end

function expr = sidecarValueExpression(affinity)
% Pick the right value_* column on queryable_array_elem for an affinity.
switch upper(char(affinity))
    case {'REAL', 'INTEGER'}
        expr = 'qae.value_num';
    otherwise
        expr = 'qae.value_text';
end
end

function [predicate, params] = scalarPredicate(op, valueExpr, target)
% Build a single boolean SQL fragment comparing valueExpr to target.
switch op
    case 'exact_string'
        predicate = sprintf('%s = ?', valueExpr);
        params = bindParam(target);
    case 'exact_string_anycase'
        % LOWER on both sides; portable across mksqlite without ICU.
        predicate = sprintf('LOWER(%s) = LOWER(?)', valueExpr);
        params = bindParam(target);
    case 'contains_string'
        predicate = sprintf('%s LIKE ?', valueExpr);
        params = {['%' char(target) '%']};
    case 'regexp'
        % SQLite REGEXP requires a UDF that mksqlite does not register by
        % default. Emit a permissive pre-filter and rely on the in-memory
        % post-filter for correctness.
        predicate = '1=1';
        params = {};
    case 'exact_number'
        if isnumeric(target) && isscalar(target)
            predicate = sprintf('CAST(%s AS REAL) = ?', valueExpr);
            params = {double(target)};
        else
            % Arrays / matrices: full equality is hard in pure SQL.
            % Permissive pre-filter; post-filter enforces equality.
            predicate = '1=1';
            params = {};
        end
    case 'lessthan'
        [predicate, params] = numericComparison(valueExpr, target, '<');
    case 'lessthaneq'
        [predicate, params] = numericComparison(valueExpr, target, '<=');
    case 'greaterthan'
        [predicate, params] = numericComparison(valueExpr, target, '>');
    case 'greaterthaneq'
        [predicate, params] = numericComparison(valueExpr, target, '>=');
    otherwise
        error('did2:database:unknownOperator', ...
            'Unknown scalar operator "%s".', op);
end
end

function [predicate, params] = numericComparison(valueExpr, target, sqlOp)
if isnumeric(target) && isscalar(target)
    predicate = sprintf('CAST(%s AS REAL) %s ?', valueExpr, sqlOp);
    params = {double(target)};
else
    predicate = '1=1';
    params = {};
end
end

% -----------------------------------------------------------------------
% path utilities
% -----------------------------------------------------------------------

function expr = scalarValueExpression(dotPath, ctx)
% scalarValueExpression - the SQL value expression for a (no-[*]) scalar
%   path. Routes to the `q_<flat>` generated column when the path is
%   declared queryable; otherwise falls back to `json_extract(body, ...)`.
if ~isempty(dotPath) && isfield(ctx, 'queryablePaths') ...
        && isa(ctx.queryablePaths, 'containers.Map') ...
        && ctx.queryablePaths.isKey(dotPath)
    % Match did2.schema.cache.columnNameFor: always lowercase so the
    % SQL identifier matches the column name SQLite ended up storing.
    expr = ['q_' lower(strrep(dotPath, '.', '_'))];
else
    expr = sprintf('json_extract(body, ''%s'')', jsonPath(dotPath));
end
end

function out = jsonPath(dotPath)
% Convert a dot-path like 'base.name' to a JSON1 path '$.base.name'.
% Empty dot-path -> '$'. No [*] segments allowed here.
if isempty(dotPath)
    out = '$';
    return;
end
parts = strsplit(dotPath, '.');
buf = cell(1, numel(parts));
for k = 1:numel(parts)
    buf{k} = ['.' parts{k}];
end
out = ['$' strjoin(buf, '')];
end

function [stars, prefix, leaf] = splitPathOnStar(fieldPath)
% Split a `[*]`-segmented dot-path into:
%   stars  - cell array of "prefix-up-to-the-array" dot-paths, one per [*].
%   prefix - the dot-path before the first [*] (or the whole path if none).
%   leaf   - the trailing dot-path after the last [*] (possibly '').
%
% Example: 'multiscales[*].datasets[*].path'
%   stars  = {'multiscales', 'datasets'} (relative paths inside each level)
%   prefix = ''  (unused when stars is non-empty)
%   leaf   = 'path'
%
% For 'axes[*].name':
%   stars = {'axes'}, prefix = '', leaf = 'name'.
%
% For 'base.name':
%   stars = {}, prefix = 'base.name', leaf = ''.

stars = {};
prefix = '';
leaf = '';

if isempty(fieldPath) || ~contains(fieldPath, '[*]')
    prefix = fieldPath;
    return;
end

remaining = fieldPath;
firstStar = true;
while contains(remaining, '[*]')
    starIdx = strfind(remaining, '[*]');
    starIdx = starIdx(1);
    before = remaining(1:starIdx - 1);
    after  = remaining(starIdx + 3:end);
    if firstStar
        % `before` is the full prefix from the document root.
        stars{end+1} = before; %#ok<AGROW>
        firstStar = false;
    else
        % `before` is the relative path from the previous element value.
        % Strip a leading '.' if present.
        if ~isempty(before) && before(1) == '.'
            before = before(2:end);
        end
        stars{end+1} = before; %#ok<AGROW>
    end
    if ~isempty(after) && after(1) == '.'
        after = after(2:end);
    end
    remaining = after;
end
leaf = remaining;
end

function [sql, lastAlias] = buildArrayJoin(stars)
% Build the `FROM json_each(...) je1 [, json_each(...) jeK ...]` portion
% of an EXISTS subquery for a `[*]`-bearing path.
parts = cell(1, numel(stars));
for k = 1:numel(stars)
    if k == 1
        sourceExpr = sprintf('json_extract(body, ''%s'')', jsonPath(stars{k}));
    else
        % Relative dot-path inside the previous element value.
        prevAlias = sprintf('je%d', k - 1);
        if isempty(stars{k})
            sourceExpr = sprintf('%s.value', prevAlias);
        else
            sourceExpr = sprintf('json_extract(%s.value, ''%s'')', ...
                prevAlias, jsonPath(stars{k}));
        end
    end
    alias = sprintf('je%d', k);
    if k == 1
        parts{k} = sprintf('json_each(%s) %s', sourceExpr, alias);
    else
        parts{k} = sprintf(', json_each(%s) %s', sourceExpr, alias);
    end
end
sql = ['FROM ' strjoin(parts, '')];
lastAlias = sprintf('je%d', numel(stars));
end

function expr = leafValueExpression(witnessAlias, leaf)
% The value expression at the leaf of an `[*]`-bearing path.
if isempty(leaf)
    expr = sprintf('%s.value', witnessAlias);
else
    expr = sprintf('json_extract(%s.value, ''%s'')', ...
        witnessAlias, jsonPath(leaf));
end
end

% -----------------------------------------------------------------------
% misc helpers
% -----------------------------------------------------------------------

function out = bindParam(target)
% Coerce a query parameter to a sqlite-binding-friendly scalar.
if ischar(target)
    out = {target};
elseif isstring(target) && isscalar(target)
    out = {char(target)};
elseif isnumeric(target) && isscalar(target)
    out = {double(target)};
elseif islogical(target) && isscalar(target)
    out = {double(target)};
else
    % Multi-element arrays / cells: bind as char(0); the in-memory
    % post-filter will enforce correctness.
    out = {''};
end
end

function frag = valueEquality(expr, target)
% Boolean SQL comparing `expr` to a bound `?` placeholder of the right type.
if isnumeric(target) && isscalar(target)
    frag = sprintf('CAST(%s AS REAL) = ?', expr);
else
    frag = sprintf('%s = ?', expr);
end
end

function ssArray = asStructArray(value)
% Normalise an `or` branch parameter to a search-structure struct array.
if isempty(value)
    ssArray = struct('field', {}, 'operation', {}, 'param1', {}, 'param2', {});
    return;
end
if isstruct(value)
    ssArray = value;
    return;
end
if iscell(value)
    if isempty(value)
        ssArray = struct('field', {}, 'operation', {}, 'param1', {}, 'param2', {});
    else
        ssArray = [value{:}];
    end
    return;
end
error('did2:database:badInput', ...
    'or-branch parameter must be a search-structure array or cell array.');
end
