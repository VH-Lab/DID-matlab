function result = v1_to_v2(v1Bodies, options)
%V1_TO_V2 Convert did_v1 document bodies to V_delta.
%
%   RESULT = did2.convert.v1_to_v2(V1BODIES) takes one or more
%   did_v1-shaped document bodies (struct, struct array, cell array, or
%   JSON char) and runs each through this pipeline:
%
%     1. did2.convert.universalRenames    (cross-cutting renames)
%     2. matching superclass migrators under
%        +did2.+convert.+migrators.<superclass_name>
%     3. concrete-class migrator under
%        +did2.+convert.+migrators.<class_name>  (identity fallback)
%     4. ensureClassBlocks: pad empty `struct()` property blocks for
%        every class in the V_delta inheritance chain that the v1
%        source or the migrators did not already produce. Lets the
%        validator pass without each migrator having to manufacture
%        placeholder blocks for inherited classes. Silent no-op if
%        the schema cache cannot resolve the chain.
%
%   Bodies that are already V_delta-shaped
%   (document_class.schema_version == 'V_delta' AND no v1-only
%   underscore-prefixed top-level markers) short-circuit steps 1-3 and
%   go straight to ensureClassBlocks + validate. Makes the converter
%   safely re-runnable so a partial normalisation or migration run can
%   resume after an interruption
%   without corrupting already-converted docs.
%
%   Documents that fail any step land in the quarantine table; nothing
%   is silently dropped.
%
%   The result struct has three fields:
%     migrated   - cell array of did2.document instances that survived
%                  every step.
%     quarantine - struct array with original_body (char, JSON-encoded
%                  input), class_name (char, post-universal-rename class
%                  name, or '<unknown>' if reading the header failed),
%                  reason (char, the captured error message), and
%                  failed_at (UTC ISO-8601 timestamp).
%     summary    - struct with `total`, `migrated_count`,
%                  `quarantine_count`, and a `by_class` struct mapping
%                  the post-universal class name to its migrated count.
%
%   Options (name-value):
%     Validate         (1,1 logical, default true) - validate each
%                      migrated document via
%                      did2.schema.cache.validateDocument. Validation
%                      failures route to quarantine.
%     SchemaCache      ([] or a did2.schema.cache handle, default []) -
%                      override the shared schema cache. Used by tests.
%     Verbose          (1,1 logical, default false) - print the
%                      end-of-run summary report to stdout.
%     CheckReferences  (1,1 logical, default false) - after the per-doc
%                      pipeline finishes, run did2.validate.references
%                      against the migrated batch. The result lands
%                      under result.references. Orphan edges are NOT
%                      routed to quarantine; the report lets callers
%                      decide how to react.
%     ReferenceDatabase (did2.database.sqlitedb or [], default []) -
%                      if supplied, references-check accepts edges
%                      that resolve to documents already stored in
%                      this DB (e.g. when ingesting an incremental
%                      batch on top of a populated database).
%     RenameClassNames (1,1 logical, default true) - forward to
%                      did2.convert.universalRenames. Pass false on
%                      read paths whose bodies still spell their
%                      identifiers in the legacy (camelCase) form so
%                      the body stays schema-compatible while still
%                      gaining the V_delta shape transformations.
%
%   See also: did2.convert.universalRenames, did2.convert.migrators,
%   docs/v2/PLAN.md §9.6.

arguments
    v1Bodies
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.Verbose (1,1) logical = false
    options.CheckReferences (1,1) logical = false
    options.ReferenceDatabase = []
    options.RenameClassNames (1,1) logical = true
end

bodies = normaliseInput(v1Bodies);

migrated = {};
quarantine = struct( ...
    'original_body', {}, ...
    'class_name',    {}, ...
    'reason',        {}, ...
    'failed_at',     {});
classCountNames = {};
classCountValues = [];

for k = 1:numel(bodies)
    rawBody = bodies{k};
    originalJSON = encodeForQuarantine(rawBody);
    className = '<unknown>';
    try
        preBody = ensureStruct(rawBody);
        if isAlreadyVDelta(preBody)
            % Idempotency short-circuit: the body is already V_delta,
            % so skip universalRenames and the per-class migrators.
            % ensureClassBlocks still runs (it rebuilds the V_delta
            % superclass chain — required) and validate still runs
            % (gate against drift). Keeps the database normalisation
            % and migration commands safely re-runnable after an
            % interruption.
            v2Body = preBody;
            if isfield(v2Body, 'document_class') ...
                    && isstruct(v2Body.document_class) ...
                    && isfield(v2Body.document_class, 'class_name')
                className = char(v2Body.document_class.class_name);
            end
        else
            postUniversalBody = did2.convert.universalRenames(preBody, ...
                'RenameClassNames', options.RenameClassNames);
            className = char(postUniversalBody.document_class.class_name);
            v2Body = applySuperclassMigrators(postUniversalBody, className);
            migratorFcn = lookupMigrator(className);
            v2Body = migratorFcn(v2Body);
        end
        v2Body = ensureClassBlocks(v2Body, options.SchemaCache);
        doc = did2.document(v2Body);
        if options.Validate
            doc.validate('SchemaCache', options.SchemaCache);
        end
        migrated{end+1} = doc; %#ok<AGROW>
        [classCountNames, classCountValues] = bumpClassCounter( ...
            classCountNames, classCountValues, className);
    catch err
        entry = struct( ...
            'original_body', originalJSON, ...
            'class_name',    className, ...
            'reason',        err.message, ...
            'failed_at',     currentUTCTimestamp());
        quarantine(end+1) = entry; %#ok<AGROW>
    end
end

result = struct();
result.migrated = migrated;
result.quarantine = quarantine;
result.summary = struct( ...
    'total',            numel(bodies), ...
    'migrated_count',   numel(migrated), ...
    'quarantine_count', numel(quarantine), ...
    'by_class',         buildByClassTable(classCountNames, classCountValues));

if options.CheckReferences
    if ~isempty(options.ReferenceDatabase)
        result.references = did2.validate.references(migrated, ...
            'Database', options.ReferenceDatabase);
    else
        result.references = did2.validate.references(migrated);
    end
end

if options.Verbose
    printSummary(result);
end
end

function bodies = normaliseInput(v1Bodies)
if iscell(v1Bodies)
    bodies = v1Bodies(:);
elseif isstruct(v1Bodies)
    if isscalar(v1Bodies)
        bodies = {v1Bodies};
    else
        bodies = cell(numel(v1Bodies), 1);
        for k = 1:numel(v1Bodies)
            bodies{k} = v1Bodies(k);
        end
    end
elseif (ischar(v1Bodies) && isvector(v1Bodies)) ...
        || (isstring(v1Bodies) && isscalar(v1Bodies))
    bodies = {char(v1Bodies)};
else
    error('did2:convert:badInput', ...
        'v1_to_v2 accepts struct, struct array, cell array, or JSON char.');
end
end

function out = ensureStruct(body)
if isstruct(body) && isscalar(body)
    out = body;
elseif ischar(body) || (isstring(body) && isscalar(body))
    decoded = jsondecode(char(body));
    if ~isstruct(decoded) || ~isscalar(decoded)
        error('did2:convert:badInput', ...
            'JSON body must decode to a JSON object (got %s).', class(decoded));
    end
    out = decoded;
else
    error('did2:convert:badInput', ...
        'v1 body must be a scalar struct or JSON char (got %s).', class(body));
end
end

function tf = isAlreadyVDelta(body)
% Return true when BODY is already a V_delta-shaped document so the
% per-body migration loop can skip universalRenames and the per-class
% migrators. Both conditions must hold so the short-circuit only fires
% when we have high confidence the body is V_delta:
%   (a) document_class.schema_version is the literal char 'V_delta'
%       (set by the last run of universalRenames, or by the writer),
%       AND
%   (b) the body carries no v1-only structural markers — underscore-
%       prefixed top-level keys (e.g., legacy _classname,
%       _class_version) that predate the document_class header and
%       could not survive a real V_delta build.
%
% (a) alone would misclassify a body that was tagged V_delta out-of-
% band but still carries legacy field shapes; (b) alone would skip
% the bulk of v1 corpora, which do not happen to use the underscore
% markers but still need every other v1->V_delta rewrite.
tf = false;
if ~isstruct(body) || ~isscalar(body)
    return;
end
if ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) ...
        || ~isscalar(body.document_class) ...
        || ~isfield(body.document_class, 'schema_version')
    return;
end
sv = body.document_class.schema_version;
if isstring(sv) && isscalar(sv)
    sv = char(sv);
end
if ~ischar(sv) || ~strcmp(sv, 'V_delta')
    return;
end
topKeys = fieldnames(body);
for k = 1:numel(topKeys)
    name = topKeys{k};
    if ~isempty(name) && name(1) == '_'
        return;
    end
end
tf = true;
end

function fcn = lookupMigrator(className)
fqn = ['did2.convert.migrators.', className];
if ~isempty(which(fqn))
    fcn = str2func(fqn);
else
    fcn = @did2.convert.migrators.identity;
end
end

function body = ensureClassBlocks(body, schemaCacheOverride)
% Make sure every class in the V_delta schema chain for the body's
% concrete class has a property block in the document, manufacturing
% empty `struct()` blocks for any chain entry that the v1 source did
% not provide. Also rebuilds document_class.superclasses from the
% V_delta schema chain so the snapshot matches the spec (same set,
% same order, class-name-by-class-name) even when V_delta has
% reordered or extended the chain relative to v1. V_delta's
% validator rejects documents whose chain blocks are missing or
% whose superclasses snapshot drifts from the schema, so this
% padding lets the per-class migrators stay focused on real field
% moves rather than placeholder bookkeeping.
%
% Silent no-op if the schema cache cannot resolve the class chain
% (e.g., the class is unknown to the cache, or the cache itself is
% not configured). In that case validation will catch the underlying
% issue downstream; this function does not raise.
if ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) ...
        || ~isfield(body.document_class, 'class_name')
    return;
end
className = char(body.document_class.class_name);
cache = schemaCacheOverride;
if isempty(cache)
    try
        cache = did2.schema.cache.shared();
    catch
        return;
    end
end
if isempty(cache)
    return;
end
try
    chain = cache.classChain(className);
    ancestors = cache.superclasses(className);
catch
    return;
end
for k = 1:numel(chain)
    cls = chain{k};
    if ~isfield(body, cls)
        body.(cls) = struct();
    end
end
sc = struct('class_name', {}, 'class_version', {});
for k = 1:numel(ancestors)
    ancDC = cache.getClass(ancestors{k}).document_class;
    sc(end+1) = struct( ...
        'class_name',    char(ancDC.class_name), ...
        'class_version', char(ancDC.class_version)); %#ok<AGROW>
end
body.document_class.superclasses = sc;
end

function body = applySuperclassMigrators(body, concreteClassName)
% Walk document_class.superclasses (as normalised by universalRenames)
% and run any matching +migrators/<superclass>.m before the
% concrete-class migrator runs. Skips entries whose name matches the
% concrete class or is empty, and skips entries that have no
% registered migrator (silent no-op, same convention as the identity
% fallback).
if ~isfield(body, 'document_class') ...
        || ~isfield(body.document_class, 'superclasses') ...
        || ~isstruct(body.document_class.superclasses) ...
        || isempty(body.document_class.superclasses)
    return;
end
sc = body.document_class.superclasses;
seen = {};
for k = 1:numel(sc)
    if ~isfield(sc(k), 'class_name')
        continue;
    end
    name = char(sc(k).class_name);
    if isempty(name) || strcmp(name, concreteClassName) ...
            || any(strcmp(seen, name))
        continue;
    end
    seen{end+1} = name; %#ok<AGROW>
    fqn = ['did2.convert.migrators.', name];
    if ~isempty(which(fqn))
        body = feval(fqn, body);
    end
end
end

function ts = currentUTCTimestamp()
ts = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function text = encodeForQuarantine(rawBody)
if ischar(rawBody) || (isstring(rawBody) && isscalar(rawBody))
    text = char(rawBody);
elseif isstruct(rawBody)
    try
        text = jsonencode(rawBody);
    catch
        text = '';
    end
else
    text = '';
end
end

function [names, counts] = bumpClassCounter(names, counts, name)
idx = find(strcmp(names, name), 1);
if isempty(idx)
    names{end+1} = name; %#ok<AGROW>
    counts(end+1) = 1; %#ok<AGROW>
else
    counts(idx) = counts(idx) + 1;
end
end

function tbl = buildByClassTable(names, counts)
tbl = struct();
for k = 1:numel(names)
    fieldName = matlab.lang.makeValidName(names{k});
    tbl.(fieldName) = counts(k);
end
end

function printSummary(result)
fprintf('did2.convert.v1_to_v2 summary:\n');
fprintf('  total:            %d\n', result.summary.total);
fprintf('  migrated_count:   %d\n', result.summary.migrated_count);
fprintf('  quarantine_count: %d\n', result.summary.quarantine_count);
if ~isempty(result.quarantine)
    fprintf('  quarantine reasons:\n');
    for k = 1:numel(result.quarantine)
        fprintf('    [%s] %s\n', result.quarantine(k).class_name, ...
            result.quarantine(k).reason);
    end
end
end
