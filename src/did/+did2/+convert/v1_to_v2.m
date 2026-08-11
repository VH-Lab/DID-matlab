function result = v1_to_v2(v1Bodies, options)
%V1_TO_V2 Convert did_v1 document bodies to V_delta.
%
%   RESULT = did2.convert.v1_to_v2(V1BODIES) takes one or more
%   did_v1-shaped document bodies (struct, struct array, cell array, or
%   JSON char) and runs each through this pipeline:
%
%     1. did2.convert.universalRenames    (cross-cutting renames)
%     2. matching superclass migrators under
%        +did2.+convert.+migrators.<superclass_name>, or, when
%        TargetVersion is 'V_eta' and one exists,
%        +did2.+convert.+migrators_j.+super.<superclass_name>
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
%     TargetVersion    (1,:) char, default 'V_delta') - migration target.
%                      'V_delta' (default) preserves the historical
%                      class-preserving 1->1 behaviour. 'V_epsilon' routes
%                      classes that have a Brainstorm-E split migrator
%                      under +did2.+convert.+migrators_e (treatment,
%                      ontology_table_row) through that migrator instead,
%                      which may fan one source body out to several
%                      destination documents (1 -> N). 'V_zeta' routes
%                      classes that have a Brainstorm-I split/fold migrator
%                      under +did2.+convert.+migrators_i (treatment,
%                      ontology_table_row, subject_group, treatment_drug,
%                      virus_injection, treatment_transfer, stimulus_bath)
%                      through that migrator, targeting the Brainstorm-I
%                      classes (the subject_interaction spine with
%                      method/variable/target_structure, shape-typed
%                      observation leaves, and generic_manipulation).
%                      'V_eta' routes classes that have a Brainstorm-J
%                      split/fold migrator under +did2.+convert.+migrators_j
%                      through that migrator, targeting the Brainstorm-J
%                      subject model (bare-identity subject, restored
%                      subject_statement owning `variable`, subject_observation/
%                      subject_manipulation, data-type-named leaves +
%                      dose/formulation/chemical composites, term_manipulation,
%                      and subject_relation documents; no injection/bath, no
%                      escape hatch). Any non-'V_delta' target stamps
%                      document_class.schema_version with the target name.
%
%   STATUS of the 2026-08-11 edit (`summary.legacy_ndi_document`, the
%   accumulator and its printer): WRITTEN WITHOUT MATLAB OR OCTAVE AND NOT
%   EXECUTED. Neither is available in the environment it was written in, so
%   CI is the first run of this code.
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
    options.TargetVersion (1,:) char = 'V_delta'
end

bodies = normaliseInput(v1Bodies);

migrated = {};
quarantine = struct( ...
    'original_body', {}, ...
    'class_name',    {}, ...
    'identifier',    {}, ...
    'reason',        {}, ...
    'failed_at',     {});
quarNames = {}; quarValues = [];
classCountNames = {};
classCountValues = [];
% Phase 1 report-only: documents a migrator handed back UNCHANGED. See
% countUnconverted below for why this is counted separately from `migrated`.
unconvNames = {};
unconvValues = [];
% Phase 1 report-only: FRAGMENTS -- see countFragments below. The third failure
% mode, and the only one no counter could see.
fragNames = {};
fragValues = [];
% THE LEGACY IDENTITY BLOCK (`ndi_document` -> `base`). DENOMINATOR FIRST AND
% UNCONDITIONALLY (Operating Rule 5): this struct is complete before the loop
% starts and is attached to the summary whether or not any body carries the
% block, so an all-zero block means "no body in this batch had one" and never
% means "nothing looked".
%
% `bodies_reaching_universal_renames` is incremented AT THE CALL SITE, not
% summed from the per-body reports, because a body that throws inside
% universalRenames produces no report and would otherwise vanish from its own
% denominator. `bodies_skipped_already_target` is the idempotency
% short-circuit, which never calls the pass at all; the two plus
% `bodies_unreached` account for `total` exactly.
%
% WHAT THE NUMBERS MEAN is in did2.convert.universalRenames's header, and the
% one-line version is: `moved_wholesale_no_base` is the arm that renames the
% container and does nothing to the contents, on the one path that exists
% because the contents differ; the `moved_carrying_*` counters say whether the
% block was the 2019 shape (broken) or the 2020 shape (sound).
legacy = struct( ...
    'bodies_total',                        numel(bodies), ...
    'bodies_reaching_universal_renames',   0, ...
    'bodies_skipped_already_target',       0, ...
    'bodies_unreached',                    0, ...
    'ndi_document_block_seen',             0, ...
    'moved_wholesale_no_base',             0, ...
    'discarded_ndi_document_base_present', 0, ...
    'moved_missing_id',                    0, ...
    'moved_missing_session_id',            0, ...
    'moved_with_any_undeclared_field',     0, ...
    'moved_undeclared_field_instances',    0, ...
    'moved_carrying_experiment_unique_reference', 0, ...
    'moved_carrying_document_unique_reference',   0, ...
    'moved_carrying_type',                 0, ...
    'moved_carrying_database_version',     0);
legacyMovedNames = {};   legacyMovedValues = [];
legacyDiscNames  = {};   legacyDiscValues  = [];

for k = 1:numel(bodies)
    rawBody = bodies{k};
    originalJSON = encodeForQuarantine(rawBody);
    className = '<unknown>';
    try
        preBody = ensureStruct(rawBody);
        if isAlreadyTarget(preBody, options.TargetVersion)
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
            v2Bodies = {v2Body};
            legacy.bodies_skipped_already_target = ...
                legacy.bodies_skipped_already_target + 1;
        else
            % Incremented BEFORE the call: a body that throws inside the pass
            % still reached it, and a denominator that quietly excluded the
            % failures would be the "all-zero reads as clean" defect again.
            legacy.bodies_reaching_universal_renames = ...
                legacy.bodies_reaching_universal_renames + 1;
            [postUniversalBody, legacyReport] = did2.convert.universalRenames( ...
                preBody, 'RenameClassNames', options.RenameClassNames);
            className = char(postUniversalBody.document_class.class_name);
            legacy = accumulateLegacyReport(legacy, legacyReport);
            if legacyReport.moved_wholesale_no_base
                [legacyMovedNames, legacyMovedValues] = bumpClassCounter( ...
                    legacyMovedNames, legacyMovedValues, className);
            end
            if legacyReport.discarded_ndi_document_base_present
                [legacyDiscNames, legacyDiscValues] = bumpClassCounter( ...
                    legacyDiscNames, legacyDiscValues, className);
            end
            v2Body = applySuperclassMigrators(postUniversalBody, className, ...
                options.TargetVersion);
            % runConcreteMigrator returns a CELL of one-or-more bodies.
            % Default (TargetVersion 'V_delta') always returns a single
            % body via the existing per-class migrator, so behaviour is
            % unchanged. Under TargetVersion 'V_epsilon' (+migrators_e) or
            % 'V_zeta' (+migrators_i) a class with a split/fold migrator
            % (treatment, ontology_table_row, ...) may fan out to several
            % bodies (1 -> N).
            v2Bodies = runConcreteMigrator(v2Body, className, ...
                options.TargetVersion);
            % PHASE 1 REPORT-ONLY (V_eta_ground_truth_plan.md): did the migrator
            % hand its input straight back? `bodies = {preBody}` is how a
            % migrator says "nothing to do here". It is used BOTH deliberately
            % (a class whose conversion needs the migrated-id graph, so pass 1
            % leaves it for the NDI second pass) AND accidentally (the migrator
            % looked for a field the source document does not have, found
            % nothing, and fell through to its fallback). The two are
            % indistinguishable downstream: an unconverted document is counted
            % in `migrated_count` because nothing errored, so an accidental
            % passthrough looks exactly like a successful migration.
            %
            % Counting it per class separates them by expectation rather than by
            % code: a class that is SUPPOSED to convert but shows a high
            % unconverted count is a bug, in one line, without reading anything.
            % probe_geometry, electrode_offset_voltage, site2channelmap and
            % spike_interface_sorting_outputs all fail exactly this way -- and
            % did2.validate.silentLoss cannot see them, because the carried
            % document is a perfectly valid v1-class document.
            %
            % Deliberately NOT computed on the idempotency short-circuit above:
            % that path skips the migrators by design and is not a passthrough.
            if isscalar(v2Bodies) && isequaln(v2Bodies{1}, v2Body)
                [unconvNames, unconvValues] = bumpClassCounter( ...
                    unconvNames, unconvValues, className);
            elseif did2.validate.isFragment(v2Bodies, 'SchemaCache', options.SchemaCache)
                % PHASE 1 REPORT-ONLY: the FRAGMENT mode. See countFragments.
                [fragNames, fragValues] = bumpClassCounter( ...
                    fragNames, fragValues, className);
            end
        end
        % Collect every produced body. Each is padded, optionally
        % validated, and counted independently so a 1 -> N split lands
        % N documents in `migrated` (or quarantines the whole source
        % body on the first failure, as before).
        for bi = 1:numel(v2Bodies)
            outBody = ensureClassBlocks(v2Bodies{bi}, options.SchemaCache);
            if ~strcmp(options.TargetVersion, 'V_delta') ...
                    && isfield(outBody, 'document_class') ...
                    && isstruct(outBody.document_class)
                outBody.document_class.schema_version = options.TargetVersion;
            end
            doc = did2.document(outBody);
            if options.Validate
                doc.validate('SchemaCache', options.SchemaCache);
            end
            migrated{end+1} = doc; %#ok<AGROW>
            outName = className;
            if isfield(outBody, 'document_class') ...
                    && isstruct(outBody.document_class) ...
                    && isfield(outBody.document_class, 'class_name')
                outName = char(outBody.document_class.class_name);
            end
            [classCountNames, classCountValues] = bumpClassCounter( ...
                classCountNames, classCountValues, outName);
        end
    catch err
        % `identifier` is carried alongside `reason` so the rollup can group
        % by FAILURE KIND rather than by message text. Messages interpolate
        % class and edge names, so every one of the 7,233 empty-required-edge
        % quarantines has a slightly different string -- grouping on those
        % would produce 7,233 groups of one and hide the shape completely.
        entry = struct( ...
            'original_body', originalJSON, ...
            'class_name',    className, ...
            'identifier',    err.identifier, ...
            'reason',        err.message, ...
            'failed_at',     currentUTCTimestamp());
        quarantine(end+1) = entry; %#ok<AGROW>
        [quarNames, quarValues] = bumpClassCounter(quarNames, quarValues, ...
            sprintf('%s|%s', className, err.identifier));
    end
end

% `bodies_unreached` closes the denominator: every body either reached
% universalRenames, took the idempotency short-circuit, or failed before
% either (a non-struct input, undecodable JSON). Written as a subtraction so
% the three sum to `total` by construction rather than by hope.
legacy.bodies_unreached = legacy.bodies_total ...
    - legacy.bodies_reaching_universal_renames ...
    - legacy.bodies_skipped_already_target;
legacy.moved_by_class = buildByClassTable(legacyMovedNames, legacyMovedValues);
legacy.discarded_by_class = buildByClassTable(legacyDiscNames, legacyDiscValues);

result = struct();
result.migrated = migrated;
result.quarantine = quarantine;
result.summary = struct( ...
    'total',            numel(bodies), ...
    'migrated_count',   numel(migrated), ...
    'quarantine_count', numel(quarantine), ...
    'quarantine_by_class', buildByClassTable(quarNames, quarValues), ...
    'by_class',         buildByClassTable(classCountNames, classCountValues), ...
    'unconverted_count', sum(unconvValues), ...
    'unconverted_by_class', buildByClassTable(unconvNames, unconvValues), ...
    'fragment_count',     sum(fragValues), ...
    'fragment_by_class',  buildByClassTable(fragNames, fragValues), ...
    'legacy_ndi_document', legacy);

% PHASE 1, REPORT-ONLY (V_eta_ground_truth_plan.md). Count the data that
% migrates away without a trace: required depends_on edges left empty, and
% required fields whose value is present but vacuous (an all-blank struct).
%
% THE PARAGRAPH THAT WAS HERE IS NOW HISTORY, and the change of state matters
% enough to say so rather than overwrite it. It read: "Neither is visible to
% the existing gates ... This RAISES NOTHING and changes no outcome; it
% produces the census that ranks the repair work. Enforcement lands only once
% these counts reach zero."
%
% As of 2026-08-10 BOTH conditions ARE visible to the gates -- #38 and then
% #37 were armed by default in did2.schema.cache.strictMode -- so a document
% with an empty required edge now QUARANTINES here instead of migrating clean.
% Enforcement did NOT wait for these counts to reach zero; the team armed #37
% against a measured 7,233 on purpose, to see the issues rather than ship
% hollow documents.
%
% This audit still RAISES NOTHING and still changes no outcome. Its job has
% changed, though: it no longer decides WHEN to enforce, it PREDICTS what
% enforcement costs, over the same batch, by the same rules. When the census
% and the quarantine rollup disagree about a class, one of the two paired
% implementations has drifted -- that is the signal, and it is why they are
% locked together by test.
try
    result.silent_loss = did2.validate.silentLoss(migrated, ...
        'SchemaCache', options.SchemaCache);
catch auditErr
    result.silent_loss = struct('audit_failed', auditErr.message);
end

% #64: the same shape one tier over -- a class declares payload FILES and the
% document carries none, or carries bytes the class never declares. The schema
% cache allows `file`/`files` as a top-level key and never looks inside, so
% neither direction trips anything. REPORT ONLY, raises nothing.
try
    result.file_list_audit = did2.validate.fileList(migrated, ...
        'SchemaCache', options.SchemaCache);
catch fileErr
    result.file_list_audit = struct('audit_failed', fileErr.message);
end

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

function tf = isAlreadyTarget(body, targetVersion)
% Return true when BODY is already a TARGETVERSION-shaped document so the
% per-body migration loop can skip universalRenames and the per-class
% migrators (it still gets ensureClassBlocks + validate). Both conditions
% must hold so the short-circuit only fires when we have high confidence
% the body is already at the target:
%   (a) document_class.schema_version is the literal char TARGETVERSION
%       (set by the last run of universalRenames, the writer, or -- for
%       'V_epsilon' -- a context assembler such as
%       ndi.migrate.internal.stimulusBathToBath that emits ready-made
%       target bodies), AND
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
if ~ischar(sv) || ~strcmp(sv, targetVersion)
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

function bodies = runConcreteMigrator(v2Body, className, targetVersion)
%RUNCONCRETEMIGRATOR Run the concrete-class migrator, return a cell of bodies.
%   Default ('V_delta') preserves the historical 1 -> 1 behaviour: the
%   per-class migrator under +did2.+convert.+migrators is applied and a
%   single-element cell is returned. Under 'V_epsilon', a class that has
%   a Brainstorm-E split migrator under +did2.+convert.+migrators_e is
%   routed there instead; that migrator may return either a single body
%   (struct) or several (struct array / cell), enabling the treatment ->
%   manipulation and ontology_table_row -> observations (1 -> N) splits.
splitPackage = '';
if strcmp(targetVersion, 'V_epsilon')
    splitPackage = 'did2.convert.migrators_e.';
elseif strcmp(targetVersion, 'V_zeta')
    splitPackage = 'did2.convert.migrators_i.';
elseif strcmp(targetVersion, 'V_eta')
    splitPackage = 'did2.convert.migrators_j.';
end
if ~isempty(splitPackage)
    fqn = [splitPackage, className];
    if ~isempty(which(fqn))
        out = feval(str2func(fqn), v2Body);
        bodies = normaliseMigratorOutput(out);
        return;
    end
end
migratorFcn = lookupMigrator(className);
bodies = {migratorFcn(v2Body)};
end

function bodies = normaliseMigratorOutput(out)
%NORMALISEMIGRATOROUTPUT Coerce a migrator's output to a cell of bodies.
if iscell(out)
    bodies = out(:)';
elseif isstruct(out)
    if isscalar(out)
        bodies = {out};
    else
        bodies = cell(1, numel(out));
        for k = 1:numel(out)
            bodies{k} = out(k);
        end
    end
else
    error('did2:convert:badMigratorOutput', ...
        'A split migrator must return a struct or cell of bodies (got %s).', ...
        class(out));
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
    placementInfo = cache.resolvePlacement(className);
    ancestors = cache.superclasses(className);
catch
    return;
end
% Placement-aware: only classes that contribute a body block (per
% V_gamma_SPEC.md "Field placement") get an empty struct manufactured
% for them. An abstract class whose declared fields are all
% `placement: "concrete_class"` (e.g., `calculator`) does NOT
% materialize on the instance body.
for k = 1:numel(placementInfo.blocksContributed)
    cls = placementInfo.blocksContributed{k};
    if ~isfield(body, cls)
        body.(cls) = struct();
    end
end
% Drop stray EMPTY blocks left by v1 for chain classes that the target
% schema does NOT host on the instance. v1 documents carried a property
% block for every class in their hierarchy, including parents that became
% abstract / fieldless in V_delta/V_epsilon (abstract classes are new
% here). Those arrive as empty structs and would trip the strict
% undeclared-top-level-block check. Only EMPTY such blocks are removed --
% a non-empty one signals real data a migrator must place, so it is left
% to fail loudly rather than be silently dropped.
chainClasses = [reshape(ancestors, 1, []), {className}];
nonContributing = setdiff(chainClasses, placementInfo.blocksContributed);
for k = 1:numel(nonContributing)
    cls = nonContributing{k};
    if isfield(body, cls) && isstruct(body.(cls)) ...
            && (numel(body.(cls)) == 0 || isempty(fieldnames(body.(cls))))
        body = rmfield(body, cls);
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

function body = applySuperclassMigrators(body, concreteClassName, targetVersion)
% Walk document_class.superclasses (as normalised by universalRenames)
% and run any matching +migrators/<superclass>.m before the
% concrete-class migrator runs. Skips entries whose name matches the
% concrete class or is empty, and skips entries that have no
% registered migrator (silent no-op, same convention as the identity
% fallback).
%
% ---------------------------------------------------------------------
% TARGET-VERSION OVERRIDE  (added for #46: ngrid.coordinates)
% ---------------------------------------------------------------------
% This step was NOT bypassed by the migrators_j split, and that was a
% silent data loss rather than a design: runConcreteMigrator routes a
% class to +migrators_j INSTEAD of +migrators, but the SUPERCLASS pass
% above it kept running the V_delta migrators unconditionally. So under
% TargetVersion 'V_eta', +migrators/ngrid.m -- whose whole job is the
% V_delta reshape (data_dim -> dim_sizes, derive ndims, rmfield
% coordinates, rmfield data_size) -- was deleting `coordinates` on every
% ontologyImage and every hartley_calc document before the J migrator
% ever saw the body. testMigratorsJ records the symptom in its own
% comment ("in the real pipeline the ngrid SUPERCLASS migrator runs
% first and deletes it").
%
% A target-version override fixes it the same way runConcreteMigrator
% does. THE OVERRIDE LIVES IN A DEDICATED SUBPACKAGE
% (+migrators_j/+super/), NOT in +migrators_j itself, and that is
% load-bearing: +migrators_j is full of CONCRETE-class migrators whose
% names are also superclass names somewhere in the v1 zoo (element,
% subject, image, measurement, filenavigator, pyraview, ...), and those
% return a CELL OF BODIES (1 -> N). Picking one up here would hand a
% cell to a step contracted to return a single struct. A separate
% namespace makes that collision impossible by construction rather than
% by an allow-list somebody has to maintain.
%
% A superclass override must return exactly one body: it reshapes a
% property block, it does not split documents.
if nargin < 3 || isempty(targetVersion)
    targetVersion = 'V_delta';
end
superPackage = '';
if strcmp(targetVersion, 'V_eta')
    superPackage = 'did2.convert.migrators_j.super.';
end
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
    fqn = '';
    if ~isempty(superPackage) && ~isempty(which([superPackage, name]))
        fqn = [superPackage, name];
    elseif ~isempty(which(['did2.convert.migrators.', name]))
        fqn = ['did2.convert.migrators.', name];
    end
    if ~isempty(fqn)
        % feval IS NECESSARY HERE. GitHub code scanning alert 173 says
        % "calling functions using 'feval' is usually not necessary; call the
        % function directly instead" -- a FALSE POSITIVE. `fqn` is COMPUTED
        % four lines above from the superclass name plus whichever package
        % `which()` resolves, so there is no name to write literally: dynamic
        % dispatch by class name is the entire mechanism of the superclass
        % migrator chain. "Call it directly" is not an available option.
        out = feval(fqn, body);
        if ~isstruct(out) || ~isscalar(out)
            error('did2:convert:badSuperclassMigratorOutput', ...
                ['Superclass migrator %s returned %s; a superclass ' ...
                 'migrator reshapes ONE body and must return a scalar ' ...
                 'struct (splitting is the concrete migrator''s job).'], ...
                fqn, class(out));
        end
        body = out;
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

function acc = accumulateLegacyReport(acc, rep)
%ACCUMULATELEGACYREPORT Sum one universalRenames per-body legacy report.
%
%   Every counter universalRenames reports is summed by NAME into the batch
%   accumulator. A field the pass reports and this accumulator does not
%   declare is an ERROR rather than a silent drop -- a counter that reached
%   the pass and stopped here would be exactly the write-only condition the
%   census work exists to remove. `bodies_inspected` is deliberately NOT
%   summed: the batch denominator is kept at the call site (see the header on
%   `legacy` above), because a body that throws inside the pass returns no
%   report at all.
names = fieldnames(rep);
for k = 1:numel(names)
    fn = names{k};
    if strcmp(fn, 'bodies_inspected')
        continue;
    end
    if ~isfield(acc, fn)
        error('did2:convert:legacyCounterUnaccumulated', ...
            ['did2.convert.universalRenames reports `%s` and ' ...
             'did2.convert.v1_to_v2 does not accumulate it; the count ' ...
             'would reach no report.'], fn);
    end
    acc.(fn) = acc.(fn) + rep.(fn);
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
printUnconverted(result);
printFragments(result);
printLegacyNdiDocument(result);
printSilentLoss(result);
printQuarantine(result);
end

function printLegacyNdiDocument(result)
%PRINTLEGACYNDIDOCUMENT The legacy identity block, denominator first.
%
%   PRINTED UNCONDITIONALLY, including when every counter is zero. Zero here
%   means "no body in this batch carried an `ndi_document` block", which is
%   the expected reading for every corpus we hold -- corpus run 31464483119
%   inspected 633,432 documents across 6 corpora and quarantined 0, so no
%   pre-`base` document is in any of them. That is a fact about the SAMPLE and
%   NOT evidence none exist: a 2019-era NDI database is precisely what this
%   migration is for. An absent line and a zero line would be the same output,
%   which is the failure this project keeps paying for.
if ~isfield(result.summary, 'legacy_ndi_document'); return; end
L = result.summary.legacy_ndi_document;
fprintf(['  legacy ndi_document: %d body(ies) reached universalRenames ' ...
    '(of %d; %d already at target, %d never reached it)\n'], ...
    L.bodies_reaching_universal_renames, L.bodies_total, ...
    L.bodies_skipped_already_target, L.bodies_unreached);
fprintf('      %8d  carried an `ndi_document` block\n', ...
    L.ndi_document_block_seen);
fprintf('      %8d  MOVED WHOLESALE into `base` (no `base` present)\n', ...
    L.moved_wholesale_no_base);
fprintf('      %8d  discarded (`base` present and wins)\n', ...
    L.discarded_ndi_document_base_present);
if L.moved_wholesale_no_base == 0; return; end
fprintf('      of the moved: %d missing required `id`, %d missing `session_id`\n', ...
    L.moved_missing_id, L.moved_missing_session_id);
fprintf('                    %d carrying %d field(s) `base` does not declare\n', ...
    L.moved_with_any_undeclared_field, L.moved_undeclared_field_instances);
fprintf(['                    2019 vintage: %d experiment_unique_reference, ' ...
    '%d document_unique_reference, %d type, %d database_version\n'], ...
    L.moved_carrying_experiment_unique_reference, ...
    L.moved_carrying_document_unique_reference, ...
    L.moved_carrying_type, L.moved_carrying_database_version);
end

function printQuarantine(result)
%PRINTQUARANTINE Quarantines PER CLASS AND REASON, denominator first.
%
%   WHY THIS IS A ROLLUP AND NOT A LIST. Arming #37 (2026-08-10) is expected
%   to quarantine ~7,233 documents in two known rows --
%   stimulus_presentation.element_id 2,670 and image_observation.subject_id
%   4,563. The previous version printed ONE LINE PER DOCUMENT, so that is
%   7,233 near-identical lines; the summary line above it prints ONE NUMBER,
%   7,233. Both are unreadable in the same way, from opposite ends: neither
%   lets you see a THIRD row appear.
%
%   A gate that is going to sit red for a while has exactly one job -- make a
%   NEW offender distinguishable from the known ones on the day it shows up.
%   So: group by (class, error identifier), largest first, denominator
%   printed FIRST and UNCONDITIONALLY per the standing rule, and keep a
%   bounded sample of full messages for the detail a count cannot carry.
%
%   Grouping is on the IDENTIFIER, not the message: messages interpolate
%   class and edge names, so grouping on text yields N groups of one.
%
%   The labels are rebuilt from the RAW entries rather than read off
%   summary.quarantine_by_class, deliberately. That table runs its keys
%   through matlab.lang.makeValidName so they can be struct fieldnames, which
%   rewrites both the '|' separator and the ':' inside every error identifier
%   into underscores -- 'a|did2:validation:x' renders as
%   'a_did2_validation_x', where the class/reason boundary is no longer
%   recoverable. The table stays for programmatic callers, matching the
%   existing by_class convention; the human-readable rollup is computed here
%   from strings that were never mangled.
if isempty(result.quarantine)
    return;
end
labels = {};
counts = [];
for k = 1:numel(result.quarantine)
    ident = result.quarantine(k).identifier;
    if isempty(ident); ident = '(no identifier)'; end
    label = sprintf('%s | %s', result.quarantine(k).class_name, ident);
    idx = find(strcmp(labels, label), 1);
    if isempty(idx)
        labels{end+1} = label; %#ok<AGROW>
        counts(end+1) = 1;     %#ok<AGROW>
    else
        counts(idx) = counts(idx) + 1;
    end
end
[counts, order] = sort(counts, 'descend');
names = labels(order);

% DENOMINATOR FIRST: how many documents were quarantined, out of how many
% inspected, across how many distinct (class, reason) rows. A count without
% its denominator is not evidence.
fprintf(['  quarantine: %d of %d document(s), in %d (class, reason) ' ...
    'row(s):\n'], numel(result.quarantine), result.summary.total, ...
    numel(names));
for k = 1:numel(names)
    fprintf('    %8d  %s\n', counts(k), names{k});
end

% A bounded sample of real messages. The counts say WHICH rows exist; a
% message says what one actually looked like. Capped so a red corpus run
% stays readable -- and the cap ANNOUNCES ITSELF rather than truncating
% silently, because a silent truncation is how a report starts lying.
sampleCap = 10;
shown = min(sampleCap, numel(result.quarantine));
fprintf('  quarantine sample (%d of %d shown):\n', shown, ...
    numel(result.quarantine));
for k = 1:shown
    fprintf('    [%s] %s\n', result.quarantine(k).class_name, ...
        result.quarantine(k).reason);
end
end


function printSilentLoss(result)
%PRINTSILENTLOSS Report-only census of data that migrates away unseen.
if ~isfield(result, 'silent_loss'); return; end
sl = result.silent_loss;
if isfield(sl, 'audit_failed')
    fprintf('  silent-loss audit: FAILED (%s)\n', sl.audit_failed);
    return;
end
if sl.empty_dependency_count == 0 && sl.vacuous_field_count == 0
    return;
end
fprintf(['  silent-loss audit (REPORT ONLY -- not a failure): %d empty required ' ...
         'edge(s), %d vacuous required field(s)\n'], ...
    sl.empty_dependency_count, sl.vacuous_field_count);
for k = 1:min(numel(sl.empty_required_dependency), 15)
    e = sl.empty_required_dependency(k);
    fprintf('    %6d  empty edge   %s.%s\n', e.count, e.class_name, e.edge_name);
end
for k = 1:min(numel(sl.vacuous_required_field), 15)
    f = sl.vacuous_required_field(k);
    fprintf('    %6d  blank value  %s / %s.%s\n', f.count, f.class_name, ...
        f.block, f.field_name);
end
end


function printFragments(result)
%PRINTFRAGMENTS Report-only: migrations that produced ONLY scaffolding.
%   The third failure mode, and the one nothing could see before. See
%   countFragments (below) for what it means and why it matters.
if ~isfield(result.summary, 'fragment_count'); return; end
if result.summary.fragment_count == 0; return; end
fprintf(['  FRAGMENTS (REPORT ONLY -- migrator emitted only scaffolding, ' ...
         'payload dropped): %d\n'], result.summary.fragment_count);
tbl = result.summary.fragment_by_class;
names = fieldnames(tbl);
counts = zeros(1, numel(names));
for k = 1:numel(names); counts(k) = tbl.(names{k}); end
[counts, order] = sort(counts, 'descend');
for k = 1:min(numel(names), 20)
    fprintf('    %6d  %s\n', counts(k), names{order(k)});
end
end

function printUnconverted(result)
%PRINTUNCONVERTED Report-only: documents a migrator handed back unchanged.
%   Not a failure. A high count on a class that is meant to convert is the
%   signal; a class deferred to the NDI second pass is expected to be here.
if ~isfield(result.summary, 'unconverted_count'); return; end
if result.summary.unconverted_count == 0; return; end
fprintf(['  unconverted (REPORT ONLY -- migrator returned its input ' ...
         'unchanged): %d\n'], result.summary.unconverted_count);
tbl = result.summary.unconverted_by_class;
names = fieldnames(tbl);
counts = zeros(1, numel(names));
for k = 1:numel(names); counts(k) = tbl.(names{k}); end
[counts, order] = sort(counts, 'descend');
for k = 1:min(numel(names), 20)
    fprintf('    %6d  %s\n', counts(k), names{order(k)});
end
end
