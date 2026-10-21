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
%   PATHS) tells the compiler that the values of the dot-paths in PATHS
%   are kept in the `queryable_scalar_elem` side table (one row per value
%   a document has; they were `q_<flat>` generated columns until
%   2026-10-06). PATHS is a struct array with `path` and `affinity` (as
%   did2.database.sqlitedb passes it) or a cellstr of paths. Scalar
%   predicates against those paths compile to `documents.id IN (SELECT
%   ... FROM queryable_scalar_elem ...)`, which SQLite answers from the
%   (path, value) index. Predicates against paths not in the set fall back
%   to json_extract.
%
%   This is the "JSON1 fallback" compiler called for in PLAN.md §9 step 3.
%   It uses sqlite3 json_extract / json_each / json_type for every
%   document-body predicate, EXISTS over the sidecar tables for `isa`
%   and a wildcard `depends_on`, `documents.id IN (...)` for a named
%   `depends_on` (so SQLite can start from its index), and emits a conservative `1=1` for predicates that
%   sqlite cannot express natively (e.g. `regexp`). did2.database.sqlitedb
%   always runs the in-memory evaluator over the SQL result set as a
%   correctness backstop, so the SQL clause is only required to be an
%   over-approximation of the true result.
%
%   That makes NEGATION the hazard: NOT of an over-approximation drops true
%   matches before the recheck can see them. A negated term is therefore
%   compiled from an EXACT predicate only (scalarPredicate's second form,
%   which knows the value's JSON type: SQL compares 5 with '5' under LOWER,
%   CAST and LIKE, the evaluator does not), and to the conservative 1=1
%   where there is none -- ~regexp, ~exact_number of an array, a ~[*] whose
%   expansion reaches entries the evaluator does not.
%
%   A `[*]` level is read through a CASE on its JSON type, so that it
%   reaches what did2.query's walkPath reaches: the entries of an array, an
%   OBJECT as one entry (jsonencode writes a one-entry array of structures
%   as an object), nothing else; a leaf is read from an object entry only.
%   json_each is never handed a bare text, which it rejects as malformed.
%
%   `hasanyelement` (the correlated "same element" operator, see
%   did2.query) compiles to EXISTS over json_each of the array, with the
%   sub-query's predicates applied to each element (`json_each.value`), so
%   all of them must hold for ONE element. A one-entry array that JSON
%   stores as an object, and a scalar, count as one element, as they do in
%   the evaluator. Where an AND-ed leaf of the sub-query is a path in the
%   queryable_array_elem sidecar, the EXISTS is preceded by `documents.id
%   IN (SELECT doc_id FROM queryable_array_elem ...)` so SQLite can start
%   from the sidecar's index; the EXISTS keeps the correlation. Inside a
%   sub-query a negated leaf that cannot be compiled exactly becomes 1=1
%   (NOT of an over-approximation would drop true matches), and the negated
%   `~hasanyelement` compiles to NOT EXISTS only when its whole sub-query
%   compiles exactly (exact_string, hasfield, and/or of those, nested
%   hasanyelement), and to the conservative 1=1 otherwise.
%
%   See also: did2.query, did2.database.sqlitedb,
%   did-schema/schemas/did_query_model.md.

arguments
    q (1,1) did2.query
    opts.QueryablePaths = {}
    opts.QueryableArrayPaths = []
end

ctx = struct( ...
    'queryablePaths', {asPathSet(opts.QueryablePaths)}, ...
    'queryableArrayPaths', {asArrayPathMap(opts.QueryableArrayPaths)}, ...
    'root', 'body', ...          % the JSON every body path is read from
    'inElement', false, ...      % inside a hasanyelement sub-query?
    'depth', 0);                 % hasanyelement nesting depth (for aliases)
[whereSQL, params] = compileSearchstructArray(q.searchstructure, ctx);
end

function set = asPathSet(paths)
% Normalise the queryable scalar paths into a path -> affinity map. PATHS
% is a struct array with `path` and `affinity` (what did2.database.sqlitedb
% passes, so each value is compared in the column it was stored in), or a
% cellstr of bare paths, whose affinity is then UNKNOWN and the value is
% compared across all three value columns.
set = containers.Map('KeyType', 'char', 'ValueType', 'char');
if isstruct(paths)
    for k = 1:numel(paths)
        p = char(paths(k).path);
        if isempty(p), continue; end
        a = '';
        if isfield(paths(k), 'affinity') && ~isempty(paths(k).affinity)
            a = upper(char(paths(k).affinity));
        end
        set(p) = a;
    end
    return;
end
for k = 1:numel(paths)
    p = char(paths{k});
    if isempty(p)
        continue;
    end
    set(p) = 'UNKNOWN';
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
if ctx.inElement && ~any(strcmp(op, {'or', 'hasanyelement'}))
    % Inside a hasanyelement sub-query the paths are read from one element
    % (ctx.root). Document-level operators (isa, depends_on, the
    % base.session_id column) and the ones whose SQL does not read the
    % element the way the evaluator does are left to the recheck, and a
    % negated leaf is compiled only when its positive form is EXACT: NOT
    % of an over-approximation would drop true matches.
    if any(strcmp(op, {'isa', 'depends_on', 'hasmember', ...
            'hasanysubfield_exact_string'})) ...
            || isempty(char(ss.field)) || strcmp(char(ss.field), sessionIdPath()) ...
            || (isNeg && ~leafIsExact(ss))
        sql = '1=1';
        params = {};
        return;
    end
end
switch op
    case 'hasanyelement'
        [sql, params] = compileHasAnyElement(ss.field, ss.param1, isNeg, ctx);
        return;
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
        [sql, params] = compileDependsOn(ss.param1, ss.param2, isNeg, ctx);
        return;
    case 'hasfield'
        if strcmp(char(ss.field), sessionIdPath())
            [sql, params] = compileSessionIdHasField(isNeg);
            return;
        end
        [sql, params] = compileHasField(ss.field, isNeg, ctx);
        return;
    case 'hasmember'
        [sql, params] = compileHasMember(ss.field, ss.param1, isNeg, ctx);
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
    case {'exact_string', 'exact_string_anycase', 'contains_string', 'wildcard', ...
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

function [sql, params] = compileDependsOn(name, value, isNeg, ctx)
% `depends_on` consults the `depends_on` sidecar table; `*` for `name` is
% the wildcard documented in did_query_model.md.
%
% A NAMED edge compiles to `documents.id IN (SELECT ... FROM depends_on
% ...)`, not to a correlated `EXISTS`. The two mean the same, but SQLite
% can only START from an uncorrelated IN: it reads the edge's rows through
% the depends_on(name, document_id) index and looks each document up by
% id. A correlated EXISTS is evaluated once per document, so the planner
% has to walk the documents table first, and a query with nothing else to
% narrow it (an isa plus an edge, as ndi.dataset sends) SCANNED every
% document. Measured on the Haley V2 dataset (187,673 documents, a worm's
% 22 statements): 0.708 s as EXISTS, 0.0007 s starting from the edge
% (EXPLAIN QUERY PLAN via sqlitedb.testHookExplain). doc_id is NOT NULL,
% so the negated NOT IN has no NULL trap.
%
% The WILDCARD stays a correlated EXISTS: no index has document_id first,
% so an IN would scan the whole depends_on table (several rows per
% document) instead of the documents table.
%
% VALUE, the edge's target, is one of three things:
%   an id            d.document_id = ?
%   a list of ids    d.document_id IN (SELECT value FROM json_each(?)):
%                    any of them, bound as ONE JSON array, so a list of
%                    any length stays under SQLite's 999-variable limit
%   a did2.query     d.document_id IN (SELECT id FROM documents WHERE
%                    <that query>): a document the target matches. Its SQL
%                    is an over-approximation like any other (the
%                    evaluator rechecks), which is sound inside a positive
%                    term and NOT inside a negated one -- NOT IN a superset
%                    drops true matches the recheck never sees -- so the
%                    negated form compiles to the conservative 1=1.
%                    did2.database.sqlitedb never sends this form: it
%                    resolves the target to its ids first (the recheck
%                    needs them), and sends the list.
arguments
    name % the edge name (or '*'); char() below
    value % an id, a list of ids, or a did2.query
    isNeg (1,1) logical
    ctx (1,1) struct
end

name = char(name);
if isa(value, 'did2.query')
    if isNeg
        sql = '1=1';
        params = {};
        return;
    end
    [innerSQL, innerParams] = compileSearchstructArray(value.searchstructure, ctx);
    target = ['d.document_id IN (SELECT id FROM documents WHERE ' innerSQL ')'];
    targetParams = innerParams;
elseif iscell(value) || (isstring(value) && ~isscalar(value))
    ids = cellstr(value);
    target = 'd.document_id IN (SELECT value FROM json_each(?))';
    targetParams = {jsonencode(reshape(ids, 1, []))};
    if isscalar(ids)
        target = 'd.document_id = ?';
        targetParams = ids;
    elseif isempty(ids)
        targetParams = {'[]'};
    end
else
    target = 'd.document_id = ?';
    targetParams = {char(value)};
end
if strcmp(name, '*')
    existsSQL = ['EXISTS (SELECT 1 FROM depends_on d ' ...
        'WHERE d.doc_id = documents.id AND ' target ')'];
    params = targetParams;
    if isNeg
        sql = ['(NOT ' existsSQL ')'];
    else
        sql = existsSQL;
    end
    return;
end
inSQL = ['(SELECT d.doc_id FROM depends_on d WHERE d.name = ? AND ' target ')'];
params = [{name}, targetParams];
if isNeg
    sql = ['(documents.id NOT IN ' inSQL ')'];
else
    sql = ['documents.id IN ' inSQL];
end
end

% -----------------------------------------------------------------------
% leaf operators over the document body
% -----------------------------------------------------------------------

function [sql, params] = compileHasField(fieldPath, isNeg, ctx)
% `hasfield` checks path presence, not value. json_type returns NULL for
% missing paths and non-NULL ('null', 'object', 'array', 'integer',
% 'real', 'text', 'true', 'false') for present-but-arbitrary values.
[stars, prefix, leaf] = splitPathOnStar(fieldPath);
if isempty(stars)
    expr = sprintf('json_type(%s, ''%s'')', ctx.root, jsonPath(prefix));
    if isNeg
        sql = sprintf('(%s IS NULL)', expr);
    else
        sql = sprintf('(%s IS NOT NULL)', expr);
    end
    params = {};
    return;
end
% At least one [*]: existence over the join expansion. With a leaf, the
% leaf must be present (JSON null counts, as walkPath returns it); with
% none, any element reached is a value.
[joinSQL, witnessAlias] = buildArrayJoin(stars, ctx);
if isempty(leaf)
    condition = '1=1';
else
    condition = sprintf('%s IS NOT NULL', leafTypeExpression(witnessAlias, leaf));
end
existsSQL = sprintf('EXISTS (SELECT 1 %s WHERE %s)', joinSQL, condition);
if isNeg
    % NOT EXISTS is exact only where the SQL reaches the elements the
    % evaluator reaches (see starPathIsExact) and there is a leaf: with
    % none, a numeric array's entries count here and not in walkPath.
    if ~isempty(leaf) && starPathIsExact(stars, ctx)
        sql = sprintf('(NOT %s)', existsSQL);
    else
        sql = '1=1';
    end
else
    sql = existsSQL;
end
params = {};
end

function [sql, params] = compileHasMember(fieldPath, target, isNeg, ctx)
% `hasmember`: the value at the field contains the scalar target, as
% did2.query.opHasMember decides it: a text target is a text value equal to
% it, or a text entry of an array (an array holding a text is a cell array
% in MATLAB); a numeric target is equal to a number, or to any entry of a
% numeric array (of any shape). The value is read through a CASE (as
% hasanyelement reads its array), so a text value is never handed to
% json_each, which rejects it as malformed JSON.
%
% The text form is exact. The numeric form walks every nested level
% (json_tree), so it over-approximates (a number inside a mixed array, or
% inside an object, is not a member in the evaluator); its negation and any
% other target compile to the conservative 1=1.
arguments
    fieldPath % the field's dot-path, possibly with [*]; char() below
    target % the member sought
    isNeg (1,1) logical
    ctx (1,1) struct
end

[stars, prefix, leaf] = splitPathOnStar(char(fieldPath));
if isempty(stars)
    joinSQL = 'FROM';
    typeExpr = sprintf('json_type(%s, ''%s'')', ctx.root, jsonPath(prefix));
    valueExpr = scalarValueExpression(prefix, ctx);
    pathExact = true;
else
    [joinSQL, witnessAlias] = buildArrayJoin(stars, ctx);
    joinSQL = [joinSQL ','];
    if isempty(leaf)
        typeExpr = [witnessAlias '.type'];
        valueExpr = [witnessAlias '.value'];
    else
        typeExpr = leafTypeExpression(witnessAlias, leaf);
        valueExpr = leafValueExpression(witnessAlias, leaf);
    end
    pathExact = ~isempty(leaf) && starPathIsExact(stars, ctx);
end

if ischar(target) || (isstring(target) && isscalar(target))
    src = sprintf(['CASE %s WHEN ''array'' THEN %s ' ...
        'WHEN ''text'' THEN json_array(%s) ELSE ''[]'' END'], typeExpr, valueExpr, valueExpr);
    existsSQL = sprintf(['EXISTS (SELECT 1 %s json_each(%s) jm ' ...
        'WHERE jm.type = ''text'' AND jm.value = ?)'], joinSQL, src);
    params = {char(target)};
    exact = pathExact;
elseif (isnumeric(target) || islogical(target)) && isscalar(target)
    src = sprintf(['CASE %s WHEN ''array'' THEN %s ' ...
        'WHEN ''integer'' THEN json_array(%s) WHEN ''real'' THEN json_array(%s) ' ...
        'ELSE ''[]'' END'], typeExpr, valueExpr, valueExpr, valueExpr);
    existsSQL = sprintf(['EXISTS (SELECT 1 %s json_tree(%s) jm ' ...
        'WHERE jm.type IN (''integer'', ''real'') AND CAST(jm.value AS REAL) = ?)'], ...
        joinSQL, src);
    params = {double(target)};
    exact = false;
else
    sql = '1=1';
    params = {};
    return;
end
if isNeg
    if exact
        sql = sprintf('(NOT %s)', existsSQL);
    else
        sql = '1=1';
        params = {};
    end
else
    sql = existsSQL;
end
end

function [sql, params] = compileHasAnySubfieldExact(arrayPath, subNames, targets, isNeg)
% Correlated existence check used by depends_on lowering: each element of
% the array-of-structures at arrayPath must simultaneously match every
% (subNames{i}, targets{i}) pair. The elements are the evaluator's
% (did2.query.opHasAnySubfieldExact): every entry of an array, an object (a
% one-entry array of structures, as jsonencode writes it) as one element,
% nothing else; a sub-field is read only from an object element, so a text
% element is never handed to json_extract (a malformed-JSON error).
if ~iscell(subNames),  subNames = {subNames};  end
if ~iscell(targets),   targets  = {targets};   end
arrayPath = char(arrayPath);
if isempty(arrayPath) || contains(arrayPath, '[*]')
    % The evaluator reads no array here (an empty path, or a `[*]` segment,
    % which is not a field name): it never matches. Permissive all the same.
    sql = '1=1';
    params = {};
    return;
end
clauses = cell(1, numel(subNames));
params  = cell(1, numel(subNames));
exact = true;
for k = 1:numel(subNames)
    sn = char(subNames{k});
    exact = exact && ~contains(sn, '.') && ~isempty(sn);
    subExpr = sprintf('json_extract(%s, ''%s'')', elementRoot('je'), jsonPath(sn));
    clauses{k} = sprintf('%s = ?', subExpr);
    params{k}  = char(targets{k});
end
inner = sprintf('SELECT 1 FROM json_each(%s) je WHERE %s', ...
    starSource('body', arrayPath), strjoin(clauses, ' AND '));
existsSQL = sprintf('EXISTS (%s)', inner);
if isNeg
    if exact
        sql = sprintf('(NOT %s)', existsSQL);
    else
        sql = '1=1';
        params = {};
    end
else
    sql = existsSQL;
end
end

function [sql, params] = compileScalar(op, fieldPath, target, isNeg, ctx)
% Scalar operators. With `[*]` segments, lowers to EXISTS over json_each
% (or against the queryable_array_elem sidecar when the path is indexed).
[stars, prefix, leaf] = splitPathOnStar(fieldPath);

if isempty(stars)
    if strcmp(prefix, sessionIdPath()) && ~ctx.inElement
        [sql, params] = compileSessionIdScalar(op, target, isNeg);
        return;
    end
    if ~ctx.inElement && scalarPathIsIndexed(prefix, ctx)
        [sql, params] = compileScalarFromScalarSidecar(op, prefix, target, isNeg, ctx);
        return;
    end
    valueExpr = scalarValueExpression(prefix, ctx);
    if ~isNeg
        [sql, params] = scalarPredicate(op, valueExpr, target);
        return;
    end
    % Missing path -> ~op should be true: `json_extract` returns NULL for an
    % unresolvable path. NOT of the predicate is sound only where the
    % predicate is EXACT (see scalarPredicate); else the conservative 1=1.
    typeExpr = sprintf('json_type(%s, ''%s'')', ctx.root, jsonPath(prefix));
    [~, ~, exactPred, exactParams] = scalarPredicate(op, valueExpr, target, typeExpr);
    [sql, params] = negateExact(['(' valueExpr ' IS NULL OR NOT (@PRED@))'], ...
        exactPred, exactParams);
    return;
end

if ~ctx.inElement && arrayPathIsIndexed(fieldPath, ctx) ...
        && (isNeg || sidecarCanDecide(op, target))
    [sql, params] = compileScalarFromSidecar(op, fieldPath, target, isNeg, ctx);
    return;
end

[joinSQL, witnessAlias] = buildArrayJoin(stars, ctx);
witnessExpr = leafValueExpression(witnessAlias, leaf);
if ~isNeg
    [predicate, params] = scalarPredicate(op, witnessExpr, target);
    sql = sprintf('EXISTS (SELECT 1 %s WHERE %s)', joinSQL, predicate);
    return;
end
% NOT EXISTS is sound only where the SQL reaches no element the evaluator
% does not (starPathIsExact) and the predicate is exact on each. With no
% leaf the element itself is the value, and a NUMBER element may sit in a
% numeric array, which the evaluator's `[*]` does not iterate (a text one
% always sits in a cell array, which it does), so only the text operators
% are exact there.
exactPred = '';
exactParams = {};
if starPathIsExact(stars, ctx) ...
        && (~isempty(leaf) || ~any(strcmp(op, {'exact_number', 'lessthan', ...
            'lessthaneq', 'greaterthan', 'greaterthaneq'})))
    if isempty(leaf)
        typeExpr = [witnessAlias '.type'];
    else
        typeExpr = leafTypeExpression(witnessAlias, leaf);
    end
    [~, ~, exactPred, exactParams] = scalarPredicate(op, witnessExpr, target, typeExpr);
end
[sql, params] = negateExact(['(NOT EXISTS (SELECT 1 ' joinSQL ' WHERE @PRED@))'], ...
    exactPred, exactParams);
end

function tf = sidecarCanDecide(op, target)
% May a POSITIVE `[*]` term be answered from queryable_array_elem? The
% sidecar has no row for an element whose leaf is empty ('' or JSON null;
% sqlitedb.isEmptyLeaf), so it can only answer an operator that no empty
% leaf satisfies in the evaluator: exact_string '' does, and so may a
% regexp or a wildcard of stars alone. Anything else reads the body
% (json_each). A negated term needs no such care: an element without a row
% cannot satisfy the predicate inside NOT EXISTS, which only widens it.
isText = ischar(target) || (isstring(target) && isscalar(target));
switch op
    case {'exact_string', 'exact_string_anycase', 'contains_string'}
        tf = isText && strlength(string(target)) > 0;
    case 'wildcard'
        tf = isText && ~isempty(regexprep(char(target), '(?<!\\)\*', ''));
    case {'exact_number', 'lessthan', 'lessthaneq', 'greaterthan', 'greaterthaneq'}
        tf = isnumeric(target) && isscalar(target);
    otherwise
        tf = false;
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
%
% Negated, NOT EXISTS of an inexact predicate would drop true matches, so
% only an exact one is negated (the column's affinity stands in for the
% value's type: the sidecar holds what the schema declared), else 1=1.
affinity = arrayPathAffinity(fieldPath, ctx);
valueExpr = sidecarValueExpression(affinity);
inner = ['SELECT 1 FROM queryable_array_elem qae ' ...
    'WHERE qae.doc_id = documents.id AND qae.path = ? AND %s'];
if ~isNeg
    [predicate, params] = scalarPredicate(op, valueExpr, target);
    sql = sprintf(['EXISTS (' inner ')'], predicate);
    params = [{fieldPath}, params];
    return;
end
[~, ~, exactPred, exactParams] = scalarPredicate(op, valueExpr, target, ...
    affinityTypeToken(affinity));
[sql, params] = negateExact(['(NOT EXISTS (' strrep(inner, '%s', '@PRED@') '))'], ...
    exactPred, exactParams);
if ~strcmp(sql, '1=1')
    params = [{fieldPath}, params];
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

function [predicate, params, exactPred, exactParams] = scalarPredicate(op, valueExpr, target, typeExpr)
% Build a single boolean SQL fragment comparing valueExpr to target.
%
% PREDICATE over-approximates the evaluator (did2.query.applyScalarOp):
% every value the evaluator matches, it matches. That is all a positive
% term needs. NOT of it is a different matter -- NOT of a superset drops
% true matches, which the in-memory recheck never sees -- so a negated term
% is built from EXACTPRED instead: a predicate that matches ONLY values the
% evaluator matches, or '' when none can be written, and the caller then
% compiles the negation to the conservative 1=1.
%
% TYPEEXPR says what is known of the value's type, which the exact forms
% need (SQL compares and casts across types where the evaluator does not:
% LOWER(5) is '5', CAST('45' AS REAL) is 45, 5 LIKE '5' is true):
%   a SQL expression    giving the JSON type ('text', 'integer', ...)
%   'TEXTCOL'           the value is text (a TEXT column)
%   'NUMCOL'            the value is a number (a REAL/INTEGER column)
%   '' (or absent)      unknown: only exact_string has an exact form
if nargin < 4
    typeExpr = '';
end
exactPred = '';
exactParams = {};
isText = ischar(target) || (isstring(target) && isscalar(target));
isNum = isnumeric(target) && isscalar(target);
switch op
    case 'exact_string'
        predicate = sprintf('%s = ?', valueExpr);
        params = bindParam(target);
        if isText && ~strcmp(typeExpr, 'NUMCOL')
            % A text target equals only a text value: SQLite does not
            % equate 5 and '5' -- except in a REAL/INTEGER column, whose
            % affinity turns '5' into 5 (NUMCOL: no exact form).
            exactPred = predicate;
            exactParams = params;
        end
    case 'exact_string_anycase'
        % LOWER on both sides; portable across mksqlite without ICU.
        predicate = sprintf('LOWER(%s) = LOWER(?)', valueExpr);
        params = bindParam(target);
        if isText
            % LOWER folds ASCII only, a subset of the evaluator's strcmpi
            [exactPred, exactParams] = guarded(textGuard(typeExpr), predicate, params);
        end
    case 'contains_string'
        % LIKE ignores ASCII case and reads % and _ as wildcards: a superset.
        predicate = sprintf('%s LIKE ?', valueExpr);
        params = {['%' char(target) '%']};
        if isText && strlength(string(target)) > 0
            % instr is case-sensitive and literal, as strfind is (which
            % finds nothing for an empty needle, hence the guard above)
            [exactPred, exactParams] = guarded(textGuard(typeExpr), ...
                sprintf('instr(%s, ?) > 0', valueExpr), {char(target)});
        end
    case 'wildcard'
        % SQLite's LIKE ignores case for ASCII letters only; the in-memory
        % recheck ignores it for all, so a non-ASCII letter in another case
        % is not found in SQL. The recheck cannot add back what SQL drops,
        % so a pattern with non-ASCII characters compiles to the
        % conservative 1=1 and is matched in memory alone.
        if any(char(target) > 127)
            predicate = '1=1';
            params = {};
        else
            predicate = [valueExpr ' LIKE ? ESCAPE ''\'''];   % not sprintf: it reads \ as an escape
            params = {did2.query.wildcardToLike(target)};
            if isText && strlength(string(target)) > 0
                [exactPred, exactParams] = guarded(textGuard(typeExpr), predicate, params);
            end
        end
    case 'regexp'
        % SQLite REGEXP requires a UDF that mksqlite does not register by
        % default. Emit a permissive pre-filter and rely on the in-memory
        % post-filter for correctness. No exact form.
        predicate = '1=1';
        params = {};
    case 'exact_number'
        if isNum
            predicate = sprintf('CAST(%s AS REAL) = ?', valueExpr);
            params = {double(target)};
            [exactPred, exactParams] = guarded(numGuard(typeExpr), predicate, params);
        else
            % Arrays / matrices: full equality is hard in pure SQL.
            % Permissive pre-filter; post-filter enforces equality.
            predicate = '1=1';
            params = {};
        end
    case 'lessthan'
        [predicate, params, exactPred, exactParams] = numericComparison(valueExpr, target, '<', typeExpr);
    case 'lessthaneq'
        [predicate, params, exactPred, exactParams] = numericComparison(valueExpr, target, '<=', typeExpr);
    case 'greaterthan'
        [predicate, params, exactPred, exactParams] = numericComparison(valueExpr, target, '>', typeExpr);
    case 'greaterthaneq'
        [predicate, params, exactPred, exactParams] = numericComparison(valueExpr, target, '>=', typeExpr);
    otherwise
        error('did2:database:unknownOperator', ...
            'Unknown scalar operator "%s".', op);
end
end

function [predicate, params, exactPred, exactParams] = numericComparison(valueExpr, target, sqlOp, typeExpr)
exactPred = '';
exactParams = {};
if isnumeric(target) && isscalar(target)
    predicate = sprintf('CAST(%s AS REAL) %s ?', valueExpr, sqlOp);
    params = {double(target)};
    [exactPred, exactParams] = guarded(numGuard(typeExpr), predicate, params);
else
    predicate = '1=1';
    params = {};
end
end

function g = textGuard(typeExpr)
% The SQL that holds only for a text value; '' when the value is known to
% be text; [] (no exact form) when it is known not to be, or unknown.
switch typeExpr
    case 'TEXTCOL'
        g = '';
    case {'NUMCOL', ''}
        g = [];
    otherwise
        g = sprintf('%s = ''text''', typeExpr);
end
end

function g = numGuard(typeExpr)
% As textGuard, for a number. A JSON true/false is not one: the evaluator
% reads it as a logical, which no numeric operator matches.
switch typeExpr
    case 'NUMCOL'
        g = '';
    case {'TEXTCOL', ''}
        g = [];
    otherwise
        g = sprintf('%s IN (''integer'', ''real'')', typeExpr);
end
end

function [exactPred, exactParams] = guarded(guard, predicate, params)
% PREDICATE restricted by GUARD (see textGuard): [] is no exact form.
if isnumeric(guard) && isempty(guard) && ~ischar(guard)
    exactPred = '';
    exactParams = {};
elseif isempty(guard)
    exactPred = predicate;
    exactParams = params;
else
    exactPred = sprintf('(%s AND %s)', guard, predicate);
    exactParams = params;
end
end

function [sql, params] = negateExact(template, exactPred, exactParams)
% A negated term: TEMPLATE with @PRED@ replaced by the exact predicate, or
% the conservative 1=1 when there is none (see scalarPredicate).
if isempty(exactPred)
    sql = '1=1';
    params = {};
else
    sql = strrep(template, '@PRED@', exactPred);
    params = exactParams;
end
end

function t = affinityTypeToken(affinity)
% A sidecar column's affinity as a scalarPredicate type token.
switch upper(char(affinity))
    case 'TEXT'
        t = 'TEXTCOL';
    case {'REAL', 'INTEGER'}
        t = 'NUMCOL';
    otherwise
        t = '';
end
end

% -----------------------------------------------------------------------
% base.session_id: the field, or the edge that replaced it
% -----------------------------------------------------------------------

function p = sessionIdPath()
% The one path answered from a `documents` column instead of the body.
p = 'base.session_id';
end

function [sql, params] = compileSessionIdScalar(op, target, isNeg)
% A predicate on `base.session_id` compiles against the `documents.session_id`
% COLUMN, not the body. did-schema V_eta_relation_inheritance_plan.md
% (2026-10-20) moved the field onto a required `session_id` depends_on edge,
% and did2.database.sqlitedb fills the column from whichever the document has
% (did2.schema.cache.sessionIdOf), so this one predicate finds a did_v1 or older
% V_eta document by its field and a newer one by its edge -- which is what
% lets `ndi.query('base.session_id', 'exact_string', sid)` keep working on a
% V2 database unchanged. The in-memory recheck agrees: did2.query reads the
% edge for this path when the field is absent.
%
% On a field-shape document the column IS the field (it always was filled from
% it), so nothing a query found before is lost, and the column is indexed
% (documents_session_id), so the usual scoping query is an index lookup.
% Negated, a document with no session id matches, as for any absent path.
arguments
    op {mustBeText}
    target
    isNeg (1,1) logical
end

valueExpr = 'documents.session_id';
if ~isNeg
    [sql, params] = scalarPredicate(op, valueExpr, target);
    return;
end
% the column holds the session id as text; an inexact negation is 1=1
[~, ~, exactPred, exactParams] = scalarPredicate(op, valueExpr, target, 'TEXTCOL');
[sql, params] = negateExact(['(' valueExpr ' IS NULL OR NOT (@PRED@))'], ...
    exactPred, exactParams);
end

function [sql, params] = compileSessionIdHasField(isNeg)
% `hasfield base.session_id`: the field is present, or the edge that replaced
% it is (see compileSessionIdScalar). Presence of the FIELD keeps its old
% meaning (a field present but blank is present), so it is read from the body
% as compileHasField reads it; the edge is read from the depends_on sidecar.
arguments
    isNeg (1,1) logical
end

hasField = sprintf('json_type(body, ''%s'') IS NOT NULL', jsonPath(sessionIdPath()));
hasEdge = ['EXISTS (SELECT 1 FROM depends_on d ' ...
    'WHERE d.doc_id = documents.id AND d.name = ?)'];
if isNeg
    sql = sprintf('(NOT (%s) AND NOT %s)', hasField, hasEdge);
else
    sql = sprintf('((%s) OR %s)', hasField, hasEdge);
end
params = {'session_id'};
end

% -----------------------------------------------------------------------
% path utilities
% -----------------------------------------------------------------------

function tf = scalarPathIsIndexed(dotPath, ctx)
arguments
    dotPath {mustBeText}
    ctx (1,1) struct
end

tf = ~isempty(dotPath) && isfield(ctx, 'queryablePaths') ...
    && isa(ctx.queryablePaths, 'containers.Map') && ctx.queryablePaths.isKey(dotPath);
end

function [sql, params] = compileScalarFromScalarSidecar(op, dotPath, target, isNeg, ctx)
% A queryable scalar path is answered from queryable_scalar_elem, which has
% one row per value a document HAS. An uncorrelated IN, so SQLite starts
% from the (path, value) index. Negated, NOT IN: a document without the
% value matches, as `(column IS NULL OR NOT ...)` did for the generated
% column this replaces (a document has at most one row per scalar path).
arguments
    op {mustBeText}
    dotPath {mustBeText}
    target
    isNeg (1,1) logical
    ctx (1,1) struct
end

affinity = ctx.queryablePaths(dotPath);
switch affinity
    case 'TEXT'
        valueExpr = 'qse.value_text';
    case {'INTEGER', 'REAL'}
        valueExpr = 'qse.value_num';
    case 'UNKNOWN'
        valueExpr = 'COALESCE(qse.value_text, qse.value_num, qse.value_raw)';
    otherwise
        valueExpr = 'qse.value_raw';
end
inner = ['(SELECT qse.doc_id FROM queryable_scalar_elem qse ' ...
    'WHERE qse.path = ? AND @PRED@)'];
if ~isNeg
    [predicate, params] = scalarPredicate(op, valueExpr, target);
    sql = ['documents.id IN ' strrep(inner, '@PRED@', predicate)];
    params = [{dotPath}, params];
    return;
end
% NOT IN a superset drops true matches: only an exact predicate is negated
% (see scalarPredicate), else the conservative 1=1.
[~, ~, exactPred, exactParams] = scalarPredicate(op, valueExpr, target, ...
    affinityTypeToken(affinity));
[sql, params] = negateExact(['(documents.id NOT IN ' inner ')'], exactPred, exactParams);
if ~strcmp(sql, '1=1')
    params = [{dotPath}, params];
end
end

function expr = scalarValueExpression(dotPath, ctx)
% scalarValueExpression - the SQL value expression for a (no-[*]) scalar
% path that is NOT queryable: read from the body (or, inside a
% hasanyelement sub-query, from the element).
arguments
    dotPath {mustBeText}
    ctx (1,1) struct
end

expr = sprintf('json_extract(%s, ''%s'')', ctx.root, jsonPath(dotPath));
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

function [sql, lastAlias] = buildArrayJoin(stars, ctx)
% Build the `FROM json_each(...) je1 [, json_each(...) jeK ...]` portion
% of an EXISTS subquery for a `[*]`-bearing path. Inside a hasanyelement
% sub-query the levels are read from the element (ctx.root) and counted as
% the evaluator counts them (arrayElementSource), so nothing is dropped.
%
% Elsewhere each level is read through starSource, which iterates what
% did2.query's walkPath iterates for a `[*]`: every entry of an array, and
% an OBJECT as one entry -- jsonencode writes a one-entry array of
% structures as an object, and json_each over the object itself would step
% through its fields (a text field then reached json_extract, which SQLite
% rejects as malformed JSON). A deeper level is read from an object entry
% only (elementRoot).
if ctx.inElement
    parts = cell(1, numel(stars));
    for k = 1:numel(stars)
        alias = sprintf('je%d', k);
        if k == 1
            src = arrayElementSource(ctx.root, stars{k});
        elseif isempty(stars{k})
            src = eachElementSource(sprintf('je%d', k - 1));
        else
            src = arrayElementSource(elementRoot(sprintf('je%d', k - 1)), stars{k});
        end
        parts{k} = sprintf('json_each(%s) %s', src, alias);
    end
    sql = ['FROM ' strjoin(parts, ', ')];
    lastAlias = sprintf('je%d', numel(stars));
    return;
end
parts = cell(1, numel(stars));
for k = 1:numel(stars)
    if k == 1
        sourceExpr = starSource(ctx.root, stars{k});
    else
        % Relative dot-path inside the previous element value.
        prevAlias = sprintf('je%d', k - 1);
        if isempty(stars{k})
            sourceExpr = starSourceOfRow(prevAlias);
        else
            sourceExpr = starSource(elementRoot(prevAlias), stars{k});
        end
    end
    parts{k} = sprintf('json_each(%s) je%d', sourceExpr, k);
end
sql = ['FROM ' strjoin(parts, ', ')];
lastAlias = sprintf('je%d', numel(stars));
end

function src = starSource(root, dotPath)
% The value at dotPath under ROOT as the JSON array of the entries a `[*]`
% reaches in did2.query.walkPath: an array as itself, an object as a
% one-entry array, anything else (text, number, null, missing) as none.
p = jsonPath(dotPath);
x = sprintf('json_extract(%s, ''%s'')', root, p);
src = sprintf(['CASE json_type(%s, ''%s'') WHEN ''array'' THEN %s ' ...
    'WHEN ''object'' THEN json_array(json(%s)) ELSE ''[]'' END'], root, p, x, x);
end

function src = starSourceOfRow(alias)
% starSource for the value of a json_each row (a `[*][*]` level).
src = sprintf(['CASE %s.type WHEN ''array'' THEN %s.value ' ...
    'WHEN ''object'' THEN json_array(json(%s.value)) ELSE ''[]'' END'], ...
    alias, alias, alias);
end

function tf = starPathIsExact(stars, ctx)
% Does the json_each expansion of a `[*]` path (outside a hasanyelement
% sub-query) reach only entries did2.query.walkPath reaches, so that NOT
% EXISTS over it is sound? With a leaf it does: the leaf is read from object
% entries only, and those are exactly the evaluator's structure entries. A
% `[*][*]` level never is (walkPath reads `a[*]` as a field name, so it
% reaches nothing there). Without a leaf the caller must also ask whether
% its operator can tell a numeric array's entries (not iterated by walkPath)
% from a cell array's.
tf = ~ctx.inElement && ~isempty(stars{1}) && ~any(cellfun(@isempty, stars(2:end)));
end

function expr = leafValueExpression(witnessAlias, leaf)
% The value expression at the leaf of an `[*]`-bearing path. A leaf is read
% only from an object element (elementRoot): json_extract of a text
% element is a malformed-JSON error.
if isempty(leaf)
    expr = sprintf('%s.value', witnessAlias);
else
    % From an object entry only, also outside a sub-query: json_extract of
    % a text entry is a malformed-JSON error, and the evaluator finds no
    % field in anything but a structure.
    expr = sprintf('json_extract(%s, ''%s'')', elementRoot(witnessAlias), jsonPath(leaf));
end
end

function expr = leafTypeExpression(witnessAlias, leaf)
% The JSON type (json_type) of the value leafValueExpression reads, or
% NULL where there is none.
expr = sprintf('json_type(%s, ''%s'')', elementRoot(witnessAlias), jsonPath(leaf));
end

% -----------------------------------------------------------------------
% hasanyelement: the correlated "same element" operator
% -----------------------------------------------------------------------

function [sql, params] = compileHasAnyElement(fieldPath, sub, isNeg, ctx)
% EXISTS (SELECT 1 FROM json_each(<the array>) haeN WHERE <sub-query on
% haeN>): one element satisfies every predicate of the sub-query. See the
% file header for the sidecar prefilter and for negation.
arguments
    fieldPath % the array's dot-path; char() below
    sub % a did2.query or a search-structure array
    isNeg (1,1) logical
    ctx (1,1) struct
end

subSS = subquerySearchstructOf(sub);
fieldPath = char(fieldPath);
if endsWith(fieldPath, '[*]')
    fieldPath = fieldPath(1:end-3);
end
depth = ctx.depth + 1;
[stars, prefix, leaf] = splitPathOnStar(fieldPath);
if isempty(stars)
    alias = sprintf('hae%d', depth);
    fromSQL = sprintf('json_each(%s) %s', arrayElementSource(ctx.root, prefix), alias);
else
    % `[*]` before the array: every array those levels reach is searched.
    parts = cell(1, numel(stars) + 1);
    prev = '';
    for k = 1:numel(stars)
        a = sprintf('hae%d_%d', depth, k);
        if k == 1
            src = arrayElementSource(ctx.root, stars{k});
        elseif isempty(stars{k})
            src = eachElementSource(prev);
        else
            src = arrayElementSource(elementRoot(prev), stars{k});
        end
        parts{k} = sprintf('json_each(%s) %s', src, a);
        prev = a;
    end
    alias = sprintf('hae%d', depth);
    if isempty(leaf)
        src = eachElementSource(prev);
    else
        src = arrayElementSource(elementRoot(prev), leaf);
    end
    parts{end} = sprintf('json_each(%s) %s', src, alias);
    fromSQL = strjoin(parts, ', ');
end

subCtx = ctx;
subCtx.root = elementRoot(alias);
subCtx.inElement = true;
subCtx.depth = depth;
[subSQL, subParams] = compileSearchstructArray(subSS, subCtx);
existsSQL = sprintf('EXISTS (SELECT 1 FROM %s WHERE %s)', fromSQL, subSQL);

if isNeg
    if searchstructArrayIsExact(subSS)
        sql = sprintf('(NOT %s)', existsSQL);
        params = subParams;
    else
        sql = '1=1';
        params = {};
    end
    return;
end

% Positive: where a sub-query leaf that every true match must satisfy is a
% sidecar path, start from the sidecar's index; the EXISTS still decides
% that one element satisfies the whole sub-query.
[pre, preParams] = sidecarPrefilters(stars, prefix, subSS, ctx);
if isempty(pre)
    sql = existsSQL;
    params = subParams;
else
    sql = ['(' strjoin([pre, {existsSQL}], ' AND ') ')'];
    params = [preParams, subParams];
end
end

function [pre, params] = sidecarPrefilters(stars, arrayPath, subSS, ctx)
% One `documents.id IN (SELECT doc_id FROM queryable_array_elem ...)` per
% AND-ed, positive leaf of the sub-query whose `<array>[*].<leaf>` path is
% in the sidecar and whose predicate the sidecar row decides exactly as the
% evaluator does (so no document with a matching element is dropped):
% exact_string on a non-empty text against a TEXT path, and a scalar
% numeric comparison against a REAL/INTEGER path. Only for a top-level
% array path without `[*]`: the sidecar indexes paths from the document root.
pre = {};
params = {};
if ctx.inElement || ~isempty(stars) || isempty(arrayPath)
    return;
end
m = ctx.queryableArrayPaths;
if ~isa(m, 'containers.Map') || m.Count == 0
    return;
end
for k = 1:numel(subSS)
    leafSS = subSS(k);
    op = char(leafSS.operation);
    f = char(leafSS.field);
    if isempty(f) || contains(f, '[*]')
        continue;
    end
    key = [arrayPath '[*].' f];
    if ~m.isKey(key)
        continue;
    end
    affinity = upper(char(m(key)));
    t = leafSS.param1;
    switch op
        case 'exact_string'
            ok = strcmp(affinity, 'TEXT') && (ischar(t) || (isstring(t) && isscalar(t))) ...
                && strlength(string(t)) > 0;
        case {'exact_number', 'lessthan', 'lessthaneq', 'greaterthan', 'greaterthaneq'}
            ok = any(strcmp(affinity, {'REAL', 'INTEGER'})) && isnumeric(t) && isscalar(t);
        otherwise
            ok = false;
    end
    if ~ok
        continue;
    end
    [predicate, p] = scalarPredicate(op, sidecarValueExpression(affinity), t);
    pre{end+1} = ['documents.id IN (SELECT qae.doc_id FROM queryable_array_elem qae ' ...
        'WHERE qae.path = ? AND ' predicate ')']; %#ok<AGROW>
    params = [params, {key}, p]; %#ok<AGROW>
end
end

function src = arrayElementSource(root, dotPath)
% The value at dotPath under ROOT as a JSON array whose elements are the
% ones did2.query's hasanyelement counts: an array as itself; an object (a
% one-entry array of structures, as jsonencode writes it) or a scalar as a
% one-element array; JSON null or a missing path as no elements. Also
% keeps json_each away from a bare text value, which it would reject.
p = jsonPath(dotPath);
t = sprintf('json_type(%s, ''%s'')', root, p);
x = sprintf('json_extract(%s, ''%s'')', root, p);
src = sprintf(['CASE COALESCE(%s, ''null'') WHEN ''array'' THEN %s ' ...
    'WHEN ''object'' THEN json_array(json(%s)) WHEN ''null'' THEN ''[]'' ' ...
    'ELSE json_array(%s) END'], t, x, x, x);
end

function src = eachElementSource(alias)
% arrayElementSource for the value of a json_each row (a `[*][*]` level).
src = sprintf(['CASE %s.type WHEN ''array'' THEN %s.value ' ...
    'WHEN ''object'' THEN json_array(json(%s.value)) WHEN ''null'' THEN ''[]'' ' ...
    'ELSE json_array(%s.value) END'], alias, alias, alias, alias);
end

function expr = elementRoot(alias)
% A json_each row's value as the root of relative paths: the object, or
% NULL for any other element (no path resolves in it, as in the evaluator).
expr = sprintf('(CASE WHEN %s.type = ''object'' THEN %s.value END)', alias, alias);
end

function ss = subquerySearchstructOf(sub)
if isa(sub, 'did2.query')
    ss = sub.searchstructure;
elseif isstruct(sub)
    ss = sub;
else
    error('did2:database:badSubquery', ...
        'hasanyelement takes a sub-query (a did2.query or search-structure array).');
end
end

function tf = searchstructArrayIsExact(ssArray)
% Does this search-structure array compile, inside a hasanyelement
% sub-query, to SQL that matches an element exactly when the evaluator
% does? Only then may its NOT EXISTS stand in for `~hasanyelement`.
tf = true;
for k = 1:numel(ssArray)
    ss = ssArray(k);
    op = char(ss.operation);
    if ~isempty(op) && op(1) == '~'
        op = op(2:end);
    end
    switch op
        case 'or'
            ok = searchstructArrayIsExact(asStructArray(ss.param1)) ...
                && searchstructArrayIsExact(asStructArray(ss.param2));
        case 'hasanyelement'
            ok = searchstructArrayIsExact(subquerySearchstructOf(ss.param1));
        otherwise
            ok = leafIsExact(ss);
    end
    if ~ok
        tf = false;
        return;
    end
end
end

function tf = leafIsExact(ss)
% A leaf whose element-relative SQL agrees with the evaluator on every
% element: exact_string of a text and hasfield, on a plain dot-path.
op = char(ss.operation);
if ~isempty(op) && op(1) == '~'
    op = op(2:end);
end
f = char(ss.field);
tf = false;
if isempty(f) || contains(f, '[*]') || strcmp(f, sessionIdPath())
    return;
end
switch op
    case 'exact_string'
        t = ss.param1;
        tf = ischar(t) || (isstring(t) && isscalar(t));
    case 'hasfield'
        tf = true;
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
