function result = v1_to_v2(v1Bodies, options)
%V1_TO_V2 Convert did_v1 document bodies to V_delta.
%
%   RESULT = did2.convert.v1_to_v2(V1BODIES) takes one or more
%   did_v1-shaped document bodies (struct, struct array, cell array, or
%   JSON char) and runs each through did2.convert.universalRenames
%   followed by the matching class migrator under
%   did2.convert.migrators.<class_name>. Unregistered classes fall back
%   to did2.convert.migrators.identity (post-universal passthrough).
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
%     Validate     (1,1 logical, default true) - validate each migrated
%                  document via did2.schema.cache.validateDocument.
%                  Validation failures route to quarantine.
%     SchemaCache  ([] or a did2.schema.cache handle, default []) -
%                  override the shared schema cache. Used by tests.
%     Verbose      (1,1 logical, default false) - print the end-of-run
%                  summary report to stdout.
%
%   See also: did2.convert.universalRenames, did2.convert.migrators,
%   docs/v2/PLAN.md §9.6.

arguments
    v1Bodies
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.Verbose (1,1) logical = false
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
        postUniversalBody = did2.convert.universalRenames(preBody);
        className = char(postUniversalBody.document_class.class_name);
        migratorFcn = lookupMigrator(className);
        v2Body = migratorFcn(postUniversalBody);
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

function fcn = lookupMigrator(className)
fqn = ['did2.convert.migrators.', className];
if ~isempty(which(fqn))
    fcn = str2func(fqn);
else
    fcn = @did2.convert.migrators.identity;
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
