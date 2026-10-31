function result = v1_to_v2(v1Bodies, options)
%V1_TO_V2 Convert did_v1 document bodies to V_eta (pass 1, per document).
%
%   RESULT = did2.convert.v1_to_v2(V1BODIES) takes one or more
%   did_v1-shaped document bodies (struct, struct array, cell array, or
%   JSON char) and runs each through this pipeline:
%
%     0. a class listed by did2.convert.rawV1Classes skips steps 1-2: its
%        +migrators_j migrator reads the RAW v1 document (Decided by Jess
%        Haley, 2026-10-26 [migrators read raw v1]); see 'RawV1Classes'.
%        A class listed by did2.convert.noMigratorCarryRows has no migrator:
%        it skips steps 1-4 and is carried whole as v1, the untouched v1
%        source, citing its carry register row (Decided by Jess Haley,
%        2026-10-31 [classes without a migrator carry as v1]); see
%        'NoMigratorCarryClasses'
%     1. did2.convert.universalRenames    (cross-cutting renames)
%     2. matching superclass migrators: the V_eta override under
%        +did2.+convert.+migrators_j.+super.<superclass_name> when one
%        exists, else the base migrator under
%        +did2.+convert.+migrators.<superclass_name>
%     3. concrete-class migrator: the V_eta split/fold migrator under
%        +did2.+convert.+migrators_j.<class_name> when one exists, else
%        the base migrator under +did2.+convert.+migrators.<class_name>
%        (identity fallback)
%     4. ensureClassBlocks: pad empty `struct()` property blocks for
%        every class in the V_eta inheritance chain that the v1
%        source or the migrators did not already produce. Lets the
%        validator pass without each migrator having to manufacture
%        placeholder blocks for inherited classes. Silent no-op if
%        the schema cache cannot resolve the chain.
%
%   Bodies that are already converted (document_class.schema_version is a
%   V2 stamp, 'did_v2' -- a stamp check, not a rank against 'V_eta', [early
%   migration pieces fixed] (4), Jess Haley, 2026-10-26 -- AND no v1-only
%   underscore-prefixed top-level markers; did2.convert.isAlreadyTarget)
%   short-circuit steps 1-3 and
%   go straight to ensureClassBlocks + validate. Makes the converter
%   safely re-runnable so a partial normalisation or migration run can
%   resume after an interruption
%   without corrupting already-converted docs.
%
%   Documents that fail any step land in the quarantine table; nothing
%   is silently dropped.
%
%   The result struct has these fields:
%     migrated   - cell array of did2.document instances that survived
%                  every step.
%     quarantine - struct array with original_body (char, JSON-encoded
%                  input), class_name (char, post-universal-rename class
%                  name, or '<unknown>' if reading the header failed),
%                  reason (char, the captured error message), and
%                  failed_at (UTC ISO-8601 timestamp).
%     passthrough - struct array, one per v1 document NO migrator changed
%                  (superclass and concrete migrators returned the
%                  universalRenames output unchanged): `input_index` (its
%                  position in V1BODIES), `id` (base.id), `class_name`, and
%                  `body` (the struct emitted for it). Report-only here; see
%                  ndi.migrate.local, which stamps the ones still unchanged at
%                  the end of the whole pipeline 'did_v1' ([passthrough stays
%                  v1: how]). `summary.passthrough_count` is its length.
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
%                      gaining the shared shape transformations.
%     UnitQualityLabels (cell, default {}) - {ELEMENTID, LABEL, ...}: the
%                      single/multi label of sorted units whose
%                      neuron_extracellular is not in this batch
%                      (did2.convert.unitQualityLabels; [sorted units are
%                      cells or groups], Jess Haley, 2026-10-26). The batch's
%                      own neuron_extracellular documents are read anyway.
%     RawV1Classes     (cellstr, default did2.convert.rawV1Classes()) - the
%                      v1 classes whose migrator takes the RAW v1 document:
%                      no universalRenames, no superclass migrators, and a
%                      carry is the untouched v1 source ([migrators read raw
%                      v1]). Counted as `bodies_read_raw_v1` in
%                      summary.legacy_ndi_document. Pass {} to run every
%                      class through universalRenames as before the switch
%                      (testRawV1RoundTrip compares the two).
%     NoMigratorCarryClasses (cellstr, default
%                      did2.convert.noMigratorCarryRows()) - the v1 classes
%                      with no migrator, each carried whole as v1 (the
%                      untouched v1 source, stamped did_v1) with a
%                      `carried_as_v1` note citing its carry register row; no
%                      universalRenames, no superclass migrators, no identity
%                      fallback ([classes without a migrator carry as v1],
%                      Jess Haley, 2026-10-31). Counted as
%                      `bodies_carried_no_migrator` in
%                      summary.legacy_ndi_document. Pass {} to run those
%                      classes through universalRenames as before.
%     Audits           (1,1 logical, default true) - run the report-only
%                      census instruments over the batch (silentLoss,
%                      fileList, timeReferenceFamilies) into
%                      result.silent_loss / .file_list_audit /
%                      .time_reference_families. They raise nothing and
%                      change no outcome. Pass false on a READ path that
%                      discards them: on one-document reads they cost more
%                      than the conversion itself (NDI reading the 10,536
%                      Haley V2 subjects: 23.5 s of 51 s profiled). When false,
%                      each of the three fields is struct('audit_skipped',
%                      true) -- never an empty census, which would read as
%                      clean.
%     TargetVersion    (1,:) char, default 'V_eta') - migration target.
%                      'V_eta' is the only target; any other name is an
%                      argument-validation error. The option is kept so
%                      callers can name the target they mean.
%                      'V_eta' routes classes that have a Brainstorm-J
%                      split/fold migrator under +did2.+convert.+migrators_j
%                      through that migrator, targeting the V_eta model
%                      (one `entity` class with a bound `type`; statements
%                      whose class is the direction -- observation, assertion,
%                      manipulation, calculation -- with the value kind as a
%                      mixin; directed_relation documents; no injection/bath,
%                      no escape hatch). A class with no +migrators_j file
%                      takes its +migrators one (identity fallback). A 'V_eta'
%                      target stamps
%                      document_class.schema_version with the target name.
%                      THIS IS PASS 1 ONLY: the batch post-passes and the
%                      NDI second pass that complete a V_eta migration
%                      run in ndi.migrate.local, not here.
%                      The 'V_epsilon' and 'V_zeta' targets (+migrators_e,
%                      +migrators_i) were removed with did-schema #88, which
%                      deleted schemas/V_alpha .. V_zeta (OPEN_WORK #128);
%                      asking for either is an argument-validation error.
%
%   STATUS of the 2026-08-11 edit (`summary.legacy_ndi_document`, the
%   accumulator and its printer): WRITTEN WITHOUT MATLAB OR OCTAVE AND NOT
%   EXECUTED. Neither is available in the environment it was written in, so
%   CI is the first run of this code.
%
%   See also: did2.convert.universalRenames, did2.convert.migrators.

arguments
    v1Bodies
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.Verbose (1,1) logical = false
    options.CheckReferences (1,1) logical = false
    options.ReferenceDatabase = []
    options.RenameClassNames (1,1) logical = true
    options.TargetVersion (1,:) char {mustBeMember(options.TargetVersion, {'V_eta', 'did_v2'})} = 'V_eta'
    options.Audits (1,1) logical = true
    options.RawV1Classes cell = did2.convert.rawV1Classes()
    options.NoMigratorCarryClasses cell = did2.convert.noMigratorCarryRows()
    options.UnitQualityLabels cell = {}
end

% [old ndi_document blocks carry] (Decided by Jess Haley, 2026-10-27): the note
% for a document carried because it holds a legacy `ndi_document` block beside
% `base` (hasLegacyBlockBesideBase), on either path. It keeps the words the
% renamed path's carry-049 note used for the same block.
LEGACY_BLOCK_NOTE = ['[carry-049] universalRenames would discard: ndi_document ' ...
    '(a legacy identity block beside base; [old ndi_document blocks carry])'];

% a migrator transcribes the v1 source's own terms, which the term
% registry (strictMode 'TermRegistry', tenet T19) need not hold yet: the check
% is for imports, so it is off while this runs and restored after
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>
% The generic migration is not affected by [V2 builder refuses retired]
% (Jess Haley, 2026-10-24): strictMode 'RetiredClasses' is off while it runs.
prevRetiredClasses = did2.schema.cache.strictMode('RetiredClasses', false);
restoreRetiredClasses = onCleanup(@() did2.schema.cache.strictMode('RetiredClasses', prevRetiredClasses)); %#ok<NASGU>
% A document whose v1 source states no creation time carries the time the
% migration ran ([no invented values], Jess Haley, 2026-10-25): one time for the
% whole call, unless a caller already pinned one for a longer run.
if isempty(did2.convert.migrationTime('get'))
    did2.convert.migrationTime('pin');
    unpinMigrationTime = onCleanup(@() did2.convert.migrationTime('unpin'));
end

bodies = normaliseInput(v1Bodies);

% The generator settings of every v1 stimulus_presentation in this batch, read
% by a migrator that must compare a copy against them and cannot follow an
% edge itself (hartley_calc: [hartley leftovers checked], Jess Haley,
% 2026-10-26). Reset per batch, like the notes below.
did2.convert.stimulusPresentationSpecs('reset');
did2.convert.stimulusPresentationSpecs('load', bodies);
% The classes, responses and presentations the tuning and response migrators
% need from other documents (Jess Haley, 2026-10-27: [input names rebuild from
% the input class], [tuning stimids rebuild]). Reset per batch.
did2.convert.tuningBatchIndex('reset');
did2.convert.tuningBatchIndex('load', bodies);
% The reference of every v1 session in this batch, read by jMembershipBodies
% to compare an ingested session's session_reference ([ingested session
% membership], Jess Haley, 2026-10-26).
did2.convert.sessionReferences('reset');
did2.convert.sessionReferences('load', bodies);
% The single/multi label each sorted unit's sorting run gives it (the
% `quality_label` of the neuron_extracellular naming it), read by
% migrators_j.element ([sorted units are cells or groups], Jess Haley,
% 2026-10-26).
did2.convert.unitQualityLabels('reset');
did2.convert.unitQualityLabels('load', bodies);
did2.convert.unitQualityLabels('add', options.UnitQualityLabels);
% The subject_id of every v1 element in this batch, read by
% migrators_j.element to check a sorted unit's subject against its probe's,
% and by roundtrip.element to rebuild it ([unit direct and subject rebuild
% from the probe], Jess Haley, 2026-10-27).
did2.convert.elementSubjects('reset');
did2.convert.elementSubjects('load', bodies);
% The channel counts every n-trode's epochprobemap rows name, and its
% geometry's site counts, read by migrators_j.element for the n-trode's
% "number of electrodes" ([n-trode count from the channel list], Jess Haley,
% 2026-10-29).
did2.convert.nTrodeElectrodeCounts('reset');
did2.convert.nTrodeElectrodeCounts('load', bodies);

% Asked ONCE per call, of the schema the documents validate against: does
% `base` declare `session_id` as an edge (did-schema
% V_eta_relation_inheritance_plan.md, 2026-10-20) or as the field it always
% was? See renameOutboundBaseFields.
sessionEdge = outboundSchemaCache(options.SchemaCache).sessionIdIsEdge();

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
% WHICH sources fragmented, by v1 base.id, so a failing corpus run names the
% documents tools/extract_failure_fixtures.py lifts into a quick-suite fixture.
% Complete (one short id per fragment); the counts above stay the census.
fragIds = {};
% Report-only: documents a migrator CONSUMED and EMITTED NOTHING for -- an empty
% cell back from a split migrator (a metadata-only lightsheetZarrLevel was one,
% #73 L3(c), until it became a file-less body on 2026-10-26). Without this the source would vanish from every count: it is not
% migrated, not quarantined, not unconverted and not a fragment.
emptyNames = {};
emptyValues = [];
% PASSED THROUGH, by input position (Decided by Jess Haley, 2026-10-24
% [passthrough stays v1] and [passthrough stays v1: how], did-schema
% V_eta_go_forward_class_audit.md): a v1 document that no migrator changed --
% the superclass migrators AND the concrete migrator handed back the
% universalRenames output unchanged -- is recorded with the body this pass
% emitted for it. Pass 1 still emits it as today (the NDI second pass keeps
% receiving what it receives today); the caller that runs the WHOLE pipeline
% (ndi.migrate.local) compares each recorded body with the document at the
% end, and one still identical is stored as its v1 source, stamped 'did_v1'.
% Recording changes no outcome here.
passthrough = struct('input_index', {}, 'id', {}, 'class_name', {}, 'body', {});
% Of those, the ones whose class has no V_eta schema (no tombstone): carried
% as v1 without V_eta validation, by class (see the validation step).
v1NoSchemaNames = {};
v1NoSchemaValues = [];
% Of the documents a migrator carried whole as v1, those V_eta validation
% refused (a tombstone that does not describe the v1 shape): counted, by class.
carriedUnvalNames = {};
carriedUnvalValues = [];
% DIMENSION TERMS WITH NO NODE (Jess Haley 2026-10-22 [covariate details],
% answer "B" to 5.4): a dimension's term is bound `preferred` for now, and
% each corpus report counts the dimensions whose term has no node, so the move
% to `required` (with variables, OPEN_WORK #129) rests on a measured number.
% Per emitted class: dimensions written (the denominator) and how many of
% them have a term with an empty node. Counted on every migrated document's
% `data` and `acquisition_epoch` blocks, the two that declare AMENDMENT 6's
% `dimensions`.
dimTermClasses = {};
dimTermWritten = [];
dimTermNoNode = [];
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
% because the contents differ; the `moved_vintage_*` counters say WHICH of the
% four `ndi_document` shapes the block was, which is what decides whether the
% move was sound. The 2020-05-19 vintage (the longest-lived, nearly three years)
% already spells `id`/`session_id` and moves CORRECTLY; the two 2019 shapes land
% with no usable identity at all. A single arm count mixes them.
legacy = struct( ...
    'bodies_total',                        numel(bodies), ...
    'bodies_reaching_universal_renames',   0, ...
    'bodies_skipped_already_target',       0, ...
    'bodies_read_raw_v1',                  0, ...
    'bodies_carried_no_migrator',          0, ...
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
    'moved_carrying_database_version',     0, ...
    'moved_vintage_bodies_classified',     0, ...
    'moved_vintage_2019_05_unique_reference',       0, ...
    'moved_vintage_2019_11_experiment_document_id', 0, ...
    'moved_vintage_2019_12_experiment_id_and_id',   0, ...
    'moved_vintage_2020_05_session_id_and_id',      0, ...
    'moved_vintage_unknown',               0, ...
    'moved_vintage_unreadable_block',      0);
legacyMovedNames = {};   legacyMovedValues = [];
legacyDiscNames  = {};   legacyDiscValues  = [];
% Notes a migrator leaves about HOW it migrated a document (did2.convert.
% reportNote), e.g. a treatment whose route is unknown. Reset per batch; a
% quarantined body's notes are dropped, since that body did not migrate.
did2.convert.reportNote('reset');
% Deterministic ids for the documents a migrator MINTS (practice (b) of
% [migration reliability practices], Jess Haley, 2026-10-26): each source body
% opens a did2.convert.mintId context keyed on its v1 base.id, so a minted
% document's id is derived from that id and its role, and two runs on the same
% input give the same ids. A body with no id mints random ids, as before.
mintDepth = did2.convert.mintId('-depth');
restoreMint = onCleanup(@() did2.convert.mintId('-popto', mintDepth));

% What each source became, for [dependents of a carried document carry]
% (carryDependents, after the loop): done (not quarantined), carried as v1,
% read raw, already a V2 document, its class, its id, its depends_on edges, and
% the indices of its documents in `migrated`.
nBodies = numel(bodies);
srcDone = false(nBodies, 1);
srcCarried = false(nBodies, 1);
srcRaw = false(nBodies, 1);
srcTarget = false(nBodies, 1);
srcClass = cell(nBodies, 1);
srcId = cell(nBodies, 1);
srcDepNames = cell(nBodies, 1);
srcDepIds = cell(nBodies, 1);
srcOut = cell(nBodies, 1);
srcOutIds = cell(nBodies, 1);   % the base.id of each document a source became
% [global-clock oneepoch carried with its element] (carryOneEpochsWithElement):
% the register rows each source's carry note cites, and which sources a
% migrator handed back to be carried with their output element
srcCarryRows = repmat({{}}, nBodies, 1);
srcWithElement = false(nBodies, 1);

for k = 1:numel(bodies)
    rawBody = bodies{k};
    nBefore = numel(migrated);
    originalJSON = encodeForQuarantine(rawBody);
    className = '<unknown>';
    passedThrough = false;
    carried = false;
    noteMark = did2.convert.reportNote('mark');
    did2.convert.mintId('-popto', mintDepth);
    try
        preBody = ensureStruct(rawBody);
        % the mint key: base.id, else the legacy identity, else the source's
        % JSON (did2.convert.mintKey), so a base-less document mints the same
        % ids on every run too (practice (b))
        did2.convert.mintId('-push', did2.convert.mintKey(preBody));
        refuseUnknownSchemaVersion(preBody);
        if did2.convert.isAlreadyTarget(preBody, options.TargetVersion)
            % Idempotency short-circuit: the body is already stamped
            % did_v2 (a stamp check), so skip universalRenames and the per-class migrators.
            % ensureClassBlocks still runs (it rebuilds the target's
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
            srcTarget(k) = true;
            legacy.bodies_skipped_already_target = ...
                legacy.bodies_skipped_already_target + 1;
        else
            rawClass = rawV1ClassNameOf(preBody);
            if any(strcmp(rawClass, options.RawV1Classes))
                % A CLASS SWITCHED TO RAW v1 (did2.convert.rawV1Classes;
                % Decided by Jess Haley, 2026-10-26 [migrators read raw v1]):
                % its migrator reads the document exactly as v1 wrote it. No
                % universalRenames, no superclass migrators; a carry is the
                % untouched v1 source. Counted in the denominator below
                % (`bodies_read_raw_v1`), so a raw body is never "unreached".
                legacy.bodies_read_raw_v1 = legacy.bodies_read_raw_v1 + 1;
                srcRaw(k) = true;
                className = rawClass;
                v2Body = preBody;
                carryBody = preBody;
                superUnchanged = true;
                if hasLegacyBlockBesideBase(preBody)
                    % [old ndi_document blocks carry] (Decided by Jess Haley,
                    % 2026-10-27): carried whole, the block kept; no migrator runs
                    % carry-register: carry-049
                    did2.convert.reportNote('carried_as_v1', className, ...
                        sourceIdOf(preBody), LEGACY_BLOCK_NOTE);
                    v2Bodies = {preBody};
                else
                    v2Bodies = runRawV1Migrator(preBody, className);
                end
                if isscalar(v2Bodies) && isequaln(v2Bodies{1}, preBody) ...
                        && (did2.convert.reportNote('pending', 'carried_as_v1') > 0 ...
                        || did2.convert.reportNote('pending', 'carried_with_element') > 0)
                    carried = true;
                end
            elseif any(strcmp(rawClass, options.NoMigratorCarryClasses))
                % A CLASS WITH NO MIGRATOR (did2.convert.noMigratorCarryRows;
                % Decided by Jess Haley, 2026-10-31 [classes without a
                % migrator carry as v1]: "the 9 v1 classes with no migrator
                % are kept unchanged as v1 [...] Each would get a carry row,
                % and a migrator can replace that row later"). Carried whole
                % as v1: the untouched v1 source, no universalRenames, no
                % superclass migrators, no identity fallback. Counted in the
                % denominator below (`bodies_carried_no_migrator`). A legacy
                % `ndi_document` block beside `base` still cites carry-049,
                % as on the other paths ([old ndi_document blocks carry]).
                legacy.bodies_carried_no_migrator = legacy.bodies_carried_no_migrator + 1;
                srcRaw(k) = true;
                className = rawClass;
                if hasLegacyBlockBesideBase(preBody)
                    carryNote = LEGACY_BLOCK_NOTE;
                else
                    carryNote = sprintf(['%s awaiting_home: %s has no migrator ' ...
                        '([classes without a migrator carry as v1])'], ...
                        did2.convert.noMigratorCarryRows(rawClass), rawClass);
                end
                % carry-register: carry-049 carry-158 carry-159 carry-160 carry-161
                %   carry-162 carry-163 carry-164 via noMigratorCarryRows.m
                did2.convert.reportNote('carried_as_v1', className, ...
                    sourceIdOf(preBody), carryNote);
                v2Body = preBody;
                carryBody = preBody;
                superUnchanged = true;
                v2Bodies = {preBody};
                carried = true;
            else
                % Incremented BEFORE the call: a body that throws inside the pass
                % still reached it, and a denominator that quietly excluded the
                % failures would be the "all-zero reads as clean" defect again.
                legacy.bodies_reaching_universal_renames = ...
                    legacy.bodies_reaching_universal_renames + 1;
                [postUniversalBody, legacyReport, renameDropped] = did2.convert.universalRenames( ...
                    preBody, 'RenameClassNames', options.RenameClassNames);
                className = char(postUniversalBody.document_class.class_name);
                carryBody = postUniversalBody;
                legacy = accumulateLegacyReport(legacy, legacyReport);
                if legacyReport.moved_wholesale_no_base
                    [legacyMovedNames, legacyMovedValues] = bumpClassCounter( ...
                        legacyMovedNames, legacyMovedValues, className);
                end
                if legacyReport.discarded_ndi_document_base_present
                    [legacyDiscNames, legacyDiscValues] = bumpClassCounter( ...
                        legacyDiscNames, legacyDiscValues, className);
                end
                if hasLegacyBlockBesideBase(preBody)
                    % [old ndi_document blocks carry] (Decided by Jess Haley,
                    % 2026-10-27, did-schema V_eta_go_forward_class_audit.md:
                    % "register row carry-049 widens to every class: a v1
                    % document with an `ndi_document` block beside `base` is
                    % carried whole as v1, never losing the block"). The carry
                    % is the v1 source, NOT the universalRenames output, which
                    % has discarded the block. universalRenames still ran above,
                    % so its legacy counters still count the body.
                    % carry-register: carry-049
                    did2.convert.reportNote('carried_as_v1', className, ...
                        sourceIdOf(preBody), LEGACY_BLOCK_NOTE);
                    v2Body = preBody;
                    superUnchanged = true;
                    v2Bodies = {v2Body};
                    carried = true;
                elseif isempty(renameDropped)
                    v2Body = applySuperclassMigrators(postUniversalBody, className, ...
                        options.TargetVersion);
                    superUnchanged = isequaln(v2Body, postUniversalBody);
                    % runConcreteMigrator returns a CELL of one-or-more bodies.
                    % A class with a base migrator only returns a single body; a
                    % class with a +migrators_j split/fold migrator (treatment,
                    % ...) may fan out to several (1 -> N).
                    v2Bodies = runConcreteMigrator(v2Body, className, ...
                        options.TargetVersion);
                    % A CARRY IS THE V1 SOURCE, NOT THE SUPERCLASS-RESHAPED BODY.
                    % A migrator carries a document by returning its input
                    % unchanged with a `carried_as_v1` note ([generic stage is
                    % lossless], [partly placed is carried as v1], Jess Haley,
                    % 2026-10-25). Its input is the body AFTER the superclass
                    % migrators, which may have reshaped it (+migrators/filter.m
                    % renamed `type` -> `filter_type` until it was deleted,
                    % 2026-10-27; the image_stack_parameters
                    % override strips an empty `timestamp`), and such a body was
                    % not recorded as a passthrough, so it came out under its
                    % tombstone stamped did_v2. The carried document is the
                    % universalRenames output instead -- the same body every other
                    % passthrough is -- recorded as a passthrough, so the caller
                    % stores its untouched v1 source, stamped did_v1.
                    if isscalar(v2Bodies) && isequaln(v2Bodies{1}, v2Body) ...
                            && (did2.convert.reportNote('pending', 'carried_as_v1') > 0 ...
                            || did2.convert.reportNote('pending', 'carried_with_element') > 0)
                        v2Body = postUniversalBody;
                        v2Bodies = {postUniversalBody};
                        superUnchanged = true;
                        carried = true;
                    end
                else
                    % [generic stage is lossless] / [partly placed is carried as
                    % v1] (Jess Haley, 2026-10-25): universalRenames discarded v1
                    % content it keeps nowhere, so no migrator runs and the body is
                    % a passthrough, carried whole as v1 (its v1 source is what the
                    % end of ndi.migrate.local stores).
                    % carry-register: carry-049 (v1_class '*', temporary: [renames
                    % carry is temporary], removed with the pass)
                    did2.convert.reportNote('carried_as_v1', className, ...
                        sourceIdOf(preBody), ['[carry-049] universalRenames would discard: ' ...
                        strjoin(renameDropped, ', ')]);
                    v2Body = postUniversalBody;
                    superUnchanged = true;
                    v2Bodies = {v2Body};
                    carried = true;
                end
            end
            % [v1 name goes to the class's own name field] (Decided by Jess
            % Haley, 2026-10-27, did-schema V_eta_go_forward_class_audit.md):
            % a v1 base.name is written to the V2 class's own name field
            % (entity, method, acquisition_system, element, measurement) or,
            % for a data body, to its free text; "a statement with a non-empty
            % v1 name is carried whole as v1 with a needs-home register row,
            % and the number of such statements is counted in the next corpus
            % run". THE CHECK, for every CONVERTED source whose replacement
            % (the emitted document holding its id, else the first) is a
            % STATEMENT: a non-empty v1 name no emitted document holds (a
            % top-level `name`, `description` or `notes` of its own blocks,
            % v1NameIsKept) carries the source whole as v1, and is noted
            % `v1_name_statement_carried` (the count); the register row is
            % carry-106. Writing the name to the own name field of the other
            % targets is each migrator's
            % (jBaseName: entities; jMethodParameters and
            % resolveResponseParameters: method.name; daqsystem:
            % acquisition_system.name; image_stack: its body). THE MEASURE,
            % for every other CONVERTED source: a non-empty v1 name no
            % emitted document holds in one of its own blocks (`base` is not
            % read: V2 base.name is kept only until the retire classes leave,
            % [base.name kept until retire classes leave]) is noted
            % `v1_name_not_kept` (DETAIL the name), so a migrator that drops
            % it, or a target class with no name field, is counted rather than
            % silent. It does not carry: what such a document should do is not
            % decided (Proposed, not decided), so it has no register row.
            if ~carried && ~isempty(v2Bodies) ...
                    && ~(isscalar(v2Bodies) && isequaln(v2Bodies{1}, v2Body))
                v1Name = v1NameOf(preBody);
                if isWriterDefaultName(className, v1Name)
                    v1Name = '';   % notation, rebuilt by the round trip
                end
                if ~isempty(v1Name) && replacementIsStatement(v2Bodies, sourceIdOf(preBody)) ...
                        && ~v1NameIsKept(v2Bodies, v1Name)
                    what = 'a statement has no name field';
                    did2.convert.reportNote('v1_name_statement_carried', className, ...
                        sourceIdOf(preBody), v1Name);
                    % carry-register: carry-106
                    did2.convert.reportNote('carried_as_v1', className, sourceIdOf(preBody), ...
                        sprintf(['[carry-106] awaiting_home: base.name "%s" (%s; [v1 name ' ...
                        'goes to the class''s own name field])'], v1Name, what));
                    v2Body = carryBody;
                    superUnchanged = true;
                    v2Bodies = {v2Body};
                    carried = true;
                elseif ~isempty(v1Name) && ~v1NameIsKept(v2Bodies, v1Name)
                    % [v1 name goes to the class's own name field]: a
                    % converted non-statement whose v1 name no emitted
                    % document holds -- counted, not carried
                    did2.convert.reportNote('v1_name_not_kept', className, ...
                        sourceIdOf(preBody), v1Name);
                end
            end
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
            if isempty(v2Bodies)
                [emptyNames, emptyValues] = bumpClassCounter( ...
                    emptyNames, emptyValues, className);
            elseif isscalar(v2Bodies) && isequaln(v2Bodies{1}, v2Body)
                [unconvNames, unconvValues] = bumpClassCounter( ...
                    unconvNames, unconvValues, className);
                passedThrough = superUnchanged;
            elseif did2.validate.isFragment(v2Bodies, 'SchemaCache', options.SchemaCache)
                % PHASE 1 REPORT-ONLY: the FRAGMENT mode. See countFragments.
                [fragNames, fragValues] = bumpClassCounter( ...
                    fragNames, fragValues, className);
                fragIds{end+1} = sourceIdOf(preBody); %#ok<AGROW>
            end
        end
        % Collect every produced body. Each is padded, optionally
        % validated, and counted independently so a 1 -> N split lands
        % N documents in `migrated` (or quarantines the whole source
        % body on the first failure, as before).
        for bi = 1:numel(v2Bodies)
            if carried
                % A CARRIED DOCUMENT IS v1 END TO END ([generic stage is
                % lossless], [passthrough stays v1: how], Jess Haley,
                % 2026-10-24/25): the universalRenames output, no V_eta
                % class blocks padded on, no base fields renamed, stamped
                % 'did_v1' here and not left for the end of the pipeline --
                % a did2_v2 stamp let a later reader (a batch pass's
                % re-validation, NDI's second pass) validate it against the
                % V_eta tombstone of the same name (PRED pyraview:
                % `filter.type` refused by the `filter` tombstone). A
                % 'did_v1' body is never validated against V_eta
                % (did2.schema.cache.validateDocument / rehydrate).
                outBody = v2Bodies{bi};
                if isfield(outBody, 'document_class') && isstruct(outBody.document_class)
                    outBody.document_class.schema_version = 'did_v1';
                end
            else
                outBody = did2.convert.ensureClassBlocks(v2Bodies{bi}, options.SchemaCache);
                outBody = renameOutboundBaseFields(outBody, options.TargetVersion, sessionEdge);
                if isfield(outBody, 'document_class') ...
                        && isstruct(outBody.document_class)
                    % the STAMP, not the set name TargetVersion (Jess Haley,
                    % 2026-10-25 [document stamps]: a V2 document is 'did_v2')
                    outBody.document_class.schema_version = ...
                        did2.convert.targetStamp(options.TargetVersion);
                end
            end
            doc = did2.document(outBody);
            if options.Validate && carried && passedThrough
                % not validated, but still COUNTED when V_eta keeps no
                % schema for its class (passthrough_unvalidated_no_schema)
                try
                    vc = options.SchemaCache;
                    if isempty(vc); vc = did2.schema.cache.shared(); end
                    vc.getClass(className);
                catch
                    [v1NoSchemaNames, v1NoSchemaValues] = bumpClassCounter( ...
                        v1NoSchemaNames, v1NoSchemaValues, className);
                end
            end
            if options.Validate && ~carried
                try
                    doc.validate('SchemaCache', options.SchemaCache);
                catch vErr
                    % [generic stage is lossless] / [partly placed is carried
                    % as v1] and [passthrough stays v1: how] (Jess Haley,
                    % 2026-10-25 / 2026-10-24): a v1 document carried WHOLE
                    % whose class V_eta keeps no tombstone for is a v1
                    % document, stored as did_v1 without V_eta validation; it
                    % is counted here instead of quarantined. Any other
                    % failure, and any failure of a document a migrator
                    % changed, still quarantines.
                    % A CARRIED document is v1 by definition: V_eta validation
                    % (its tombstone, if any) is not its contract, so a
                    % failure is counted, never a quarantine.
                    if passedThrough && strcmp(vErr.identifier, 'did2:schema:missingClass')
                        [v1NoSchemaNames, v1NoSchemaValues] = bumpClassCounter( ...
                            v1NoSchemaNames, v1NoSchemaValues, className);
                    elseif carried
                        [carriedUnvalNames, carriedUnvalValues] = bumpClassCounter( ...
                            carriedUnvalNames, carriedUnvalValues, className);
                    else
                        rethrow(vErr);
                    end
                end
            end
            migrated{end+1} = doc; %#ok<AGROW>
            if passedThrough
                passthrough(end+1) = struct('input_index', k, ...
                    'id', sourceIdOf(outBody), 'class_name', className, ...
                    'body', outBody); %#ok<AGROW>
            end
            outName = className;
            if isfield(outBody, 'document_class') ...
                    && isstruct(outBody.document_class) ...
                    && isfield(outBody.document_class, 'class_name')
                outName = char(outBody.document_class.class_name);
            end
            [classCountNames, classCountValues] = bumpClassCounter( ...
                classCountNames, classCountValues, outName);
            [nDim, nNoNode] = dimensionTermCounts(outBody);
            if nDim > 0
                ix = find(strcmp(dimTermClasses, outName), 1);
                if isempty(ix)
                    dimTermClasses{end+1} = outName; %#ok<AGROW>
                    dimTermWritten(end+1) = 0; %#ok<AGROW>
                    dimTermNoNode(end+1) = 0; %#ok<AGROW>
                    ix = numel(dimTermClasses);
                end
                dimTermWritten(ix) = dimTermWritten(ix) + nDim;
                dimTermNoNode(ix) = dimTermNoNode(ix) + nNoNode;
            end
        end
        srcDone(k) = true;
        srcCarried(k) = carried;
        srcWithElement(k) = carried ...
            && did2.convert.reportNote('pending', 'carried_with_element') > 0;
        srcCarryRows{k} = carryRowsCited( ...
            did2.convert.reportNote('pendingDetails', 'carried_as_v1'));
        srcClass{k} = className;
        [srcId{k}, srcDepNames{k}, srcDepIds{k}] = sourceEdges(preBody);
        srcOut{k} = nBefore + 1:numel(migrated);
        srcOutIds{k} = cellfun(@(d) char(d.get('base.id')), migrated(srcOut{k}), ...
            'UniformOutput', false);
    catch err
        did2.convert.reportNote('truncate', noteMark);
        % a body that quarantines did not pass through: drop its record if
        % it was made before the failure (validation runs after the record)
        if passedThrough && ~isempty(passthrough) && passthrough(end).input_index == k
            passthrough(end) = [];
        end
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
    did2.convert.mintId('-popto', mintDepth);
end

% [fit classes kept; session list rebuilt] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): a dataset_session_info writes no
% V2 document; it is rebuilt from the dataset's session memberships, and one
% that does not rebuild exactly is carried whole as v1.
[migrated, passthrough, classCountNames, classCountValues, srcCarried] = ...
    carryUnrebuiltSessionLists(bodies, migrated, passthrough, classCountNames, ...
    classCountValues, srcDone, srcCarried, srcRaw, srcTarget, srcClass, srcId, ...
    srcDepIds, options.RenameClassNames);

% [dependents of a carried document carry] (Jess Haley, 2026-10-26, did-schema
% V_eta_go_forward_class_audit.md): a document whose edge names a document
% carried as v1 is carried too, down the chain (carry-064).
carriedBeforeDependents = srcCarried;
[migrated, passthrough, classCountNames, classCountValues, srcCarried] = carryDependents( ...
    bodies, migrated, passthrough, classCountNames, classCountValues, ...
    srcDone, srcCarried, srcRaw, srcTarget, srcClass, srcId, srcDepNames, ...
    srcDepIds, srcOut, options.RenameClassNames);
% what carryDependents carried cites its row (its note: carry-064)
srcCarryRows(srcCarried & ~carriedBeforeDependents) = {{'carry-064'}};

% [global-clock oneepoch carried with its element] (Jess Haley, 2026-10-30,
% did-schema V_eta_go_forward_class_audit.md): a global-clock oneepoch is
% carried with its output element, its note citing the element's carry. Once
% every source, and every dependent of a carried one, is placed.
carryOneEpochsWithElement(srcDone, srcCarried, srcWithElement, srcClass, ...
    srcId, srcDepNames, srcDepIds, srcCarryRows);

% [carried v1 validates against NDI templates] (Decided by Jess Haley,
% 2026-10-27, did-schema V_eta_go_forward_class_audit.md): "a document carried
% whole as v1 is validated against NDI-matlab's v1 templates at the locked NDI
% `main`, not against did-schema tombstones". Every carried source -- its v1
% SOURCE, which is what ndi.migrate.local stores -- is checked against its
% class's NDI template (did2.validate.v1Document) when Validate is on. REPORT,
% not quarantine: a carry for a field outside the template (carry-100) is
% meant to fail it. With no template set (DID_NDI_TEMPLATE_PATH / NDI_MATLAB
% unset or empty) it says NOT CHECKED.
carriedTemplateCheck = carriedV1TemplateCheck(bodies, srcCarried, srcDone, ...
    srcClass, srcId, options.Validate);

% `bodies_unreached` closes the denominator: every body either reached
% universalRenames, took the idempotency short-circuit, was read raw by a
% switched class's migrator (did2.convert.rawV1Classes), was carried whole as
% a class with no migrator (did2.convert.noMigratorCarryRows), or failed
% before any of them (a non-struct input, undecodable JSON). Written as a
% subtraction so the five sum to `total` by construction rather than by hope.
legacy.bodies_unreached = legacy.bodies_total ...
    - legacy.bodies_reaching_universal_renames ...
    - legacy.bodies_skipped_already_target ...
    - legacy.bodies_read_raw_v1 ...
    - legacy.bodies_carried_no_migrator;
% THE VINTAGE PARTITION, CHECKED RATHER THAN ASSUMED. Six buckets classify
% every body that took the wholesale-move arm, and a body falling through all
% six is exactly what the `unknown` bucket exists to catch -- so if the sum ever
% stops matching, the counter has started losing bodies silently and must say
% so here, at the batch, rather than render a plausible breakdown that does not
% add up. Raised, not warned: a breakdown that does not partition its arm is a
% wrong measurement, and this project's standing failure is measurements that
% read clean while measuring nothing.
vintageSum = legacy.moved_vintage_2019_05_unique_reference ...
    + legacy.moved_vintage_2019_11_experiment_document_id ...
    + legacy.moved_vintage_2019_12_experiment_id_and_id ...
    + legacy.moved_vintage_2020_05_session_id_and_id ...
    + legacy.moved_vintage_unknown ...
    + legacy.moved_vintage_unreadable_block;
if vintageSum ~= legacy.moved_vintage_bodies_classified ...
        || legacy.moved_vintage_bodies_classified ~= legacy.moved_wholesale_no_base
    error('did2:convert:legacyVintagePartitionBroken', ...
        ['The legacy `ndi_document` vintage buckets do not partition the ' ...
         'wholesale-move arm: %d bucket(s) summed, %d body(ies) classified, ' ...
         '%d body(ies) took the arm. A body that reaches no bucket is the ' ...
         'condition the `unknown` bucket exists to make visible.'], ...
        vintageSum, legacy.moved_vintage_bodies_classified, ...
        legacy.moved_wholesale_no_base);
end
legacy.moved_by_class = buildByClassTable(legacyMovedNames, legacyMovedValues);
legacy.discarded_by_class = buildByClassTable(legacyDiscNames, legacyDiscValues);

result = struct();
result.migrated = migrated;
result.quarantine = quarantine;
result.passthrough = passthrough;
% [whole-batch round trip] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): what each source became, by id, so
% did2.convert.roundtrip.batch can take the FINAL batch (after every batch
% pass) back to v1 source by source. One row per input body: its index, v1 id
% and class, whether it was carried as v1 (here or by carryDependents), and
% the base.id of every document it became ({} when it quarantined). A carried
% source became its own v1 document.
srcOutRows = cell(1, nBodies);
for k = 1:nBodies
    outIds = srcOutIds{k};
    if srcCarried(k)
        outIds = {srcId{k}};
    end
    if isempty(outIds); outIds = {}; end
    srcOutRows{k} = struct('input_index', k, 'id', char(srcId{k}), ...
        'class_name', char(srcClass{k}), 'done', srcDone(k), ...
        'carried', srcCarried(k), 'output_ids', {reshape(outIds, 1, [])});
end
if isempty(srcOutRows)
    result.source_outputs = struct('input_index', {}, 'id', {}, 'class_name', {}, ...
        'done', {}, 'carried', {}, 'output_ids', {});
else
    result.source_outputs = [srcOutRows{:}];
end
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
    'fragment_source_ids', {fragIds}, ...
    'emitted_nothing_count',    sum(emptyValues), ...
    'emitted_nothing_by_class', buildByClassTable(emptyNames, emptyValues), ...
    'passthrough_count', numel(passthrough), ...
    'passthrough_unvalidated_no_schema_count', sum(v1NoSchemaValues), ...
    'passthrough_unvalidated_no_schema_by_class', buildByClassTable(v1NoSchemaNames, v1NoSchemaValues), ...
    'carried_failing_veta_validation_count', sum(carriedUnvalValues), ...
    'carried_failing_veta_validation_by_class', buildByClassTable(carriedUnvalNames, carriedUnvalValues), ...
    'legacy_ndi_document', legacy, ...
    'carried_v1_template_check', carriedTemplateCheck, ...
    'dimension_terms', dimensionTermSummary(numel(migrated), ...
        dimTermClasses, dimTermWritten, dimTermNoNode), ...
    'migration_notes', did2.convert.reportNote('collect'));

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
if options.Audits
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

    % #52 EVIDENCE, not a gate: how many time references does one statement carry,
    % and what shapes occur when it carries more than one. The team has to name (or
    % decline to name) the roles of `time_reference_1..N`, and the one thing it does
    % not have is the distribution and the shapes over real data. This produces
    % them. REPORT ONLY -- it raises nothing and changes no outcome, and it proposes
    % no role vocabulary.
    %
    % It is a SEPARATE INSTRUMENT from silentLoss's `family_uniqueness_violation`,
    % which asks whether the members of a family violate the signed uniqueness rule.
    % A batch can satisfy that rule perfectly and still be full of shapes nobody has
    % decided the meaning of: distinct clocks and distinct anchors are both
    % "unique", and they are not the same modelling situation.
    try
        result.time_reference_families = did2.validate.timeReferenceFamilies( ...
            migrated, 'SchemaCache', options.SchemaCache);
    catch trfErr
        result.time_reference_families = struct('audit_failed', trfErr.message);
    end
else
    skipped = struct('audit_skipped', true);
    result.silent_loss = skipped;
    result.file_list_audit = skipped;
    result.time_reference_families = skipped;
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

function refuseUnknownSchemaVersion(body)
%REFUSEUNKNOWNSCHEMAVERSION Stop, rather than migrate a vintage we do not know.
%   A body whose `document_class.schema_version` is present but NOT on the
%   did_v1 -> did_v2 line is either RETIRED (an earlier name of the V2 stamp,
%   'V_eta' or 'V_delta', no longer accepted: [V_eta stamp not accepted], Jess
%   Haley, 2026-10-25) or written by a did2 NEWER than this one. Both are
%   refused with the same identifier; the message says which. There are
%   only two things to do with it and one of them is destructive:
%
%     convert it  -- run universalRenames and the v1-era per-class migrators
%                    over a document from the future, reshaping fields whose
%                    meaning this code does not know. SILENT, and lossy.
%     refuse it   -- quarantine with a named reason and let the caller decide.
%
%   The first version of the ordering fix chose CONVERT, on the reasoning that
%   an unrecognised name is "not at the target, so migrate it forward". That is
%   backwards: forward from WHERE is precisely what is unknown. Corrected on the
%   team's instruction, 2026-08-14 -- "an unrecognized version shouldn't
%   convert".
%
%   A body with NO schema_version at all is did_v1 and is NOT refused: absence
%   is the origin of the line (rank 0), not an unknown vintage. Collapsing those
%   two would quarantine every real v1 document in existence.
%
%   Thrown rather than returned so the per-body catch quarantines it with an
%   IDENTIFIER, which is what the rollup groups by -- message text interpolates
%   the version name and would scatter one failure kind across many groups.
if ~isstruct(body) || ~isscalar(body) ...
        || ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) || ~isscalar(body.document_class) ...
        || ~isfield(body.document_class, 'schema_version')
    return;
end
sv = body.document_class.schema_version;
if isstring(sv) && isscalar(sv)
    sv = char(sv);
end
if ~ischar(sv) || isempty(sv)
    return;      % absent or blank == did_v1, the origin of the line
end
[~, known] = did2.convert.schemaVersionRank(sv);
if ~known && any(strcmp(sv, {'V_eta', 'V_delta'}))
    error('did2:convert:unknownSchemaVersion', ...
        ['document_class.schema_version is ''%s'', a RETIRED name of the V2 ' ...
         'stamp. did2 no longer accepts it: V2 documents are stamped ''%s'' ' ...
         '([V_eta stamp not accepted], 2026-10-25). Re-run the import or ' ...
         'migration that wrote this document with the current did2.'], ...
        sv, did2.schema.v2Stamp());
end
if ~known
    error('did2:convert:unknownSchemaVersion', ...
        ['document_class.schema_version is ''%s'', which is not on the ' ...
         'did_v1 -> did_v2 line this did2 knows. Refusing to migrate it: ' ...
         'this document was written by a NEWER did2, and running the v1-era ' ...
         'migrators over it would reshape fields whose meaning is unknown ' ...
         'here. Upgrade did2, or migrate this document with the version that ' ...
         'wrote it.'], sv);
end
end

function id = sourceIdOf(body)
%SOURCEIDOF The v1 document's base.id, or '' when it carries none.
id = '';
if isstruct(body) && isscalar(body) && isfield(body, 'base') ...
        && isstruct(body.base) && isscalar(body.base) && isfield(body.base, 'id')
    v = body.base.id;
    if ischar(v); id = v; elseif isstring(v) && isscalar(v); id = char(v); end
end
end

function name = v1NameOf(body)
%V1NAMEOF The v1 base.name (or the legacy identity block's name) as text, ''
%   when there is none or it is empty.
name = '';
b = did2.convert.v1read.readBase(body);
v = b.name;
if ischar(v)
    name = v;
elseif isstring(v) && isscalar(v)
    name = char(v);
end
if isempty(strtrim(name))
    name = '';
end
end

function tf = isWriterDefaultName(className, name)
%ISWRITERDEFAULTNAME True when NAME is a writer's fixed default for the class,
%   which the round trip rebuilds, so it is notation and does not carry the
%   document: [jrclust default name is notation] (Decided by Jess Haley,
%   2026-10-27, did-schema V_eta_go_forward_class_audit.md): "a
%   `jrclust_clusters` named `jrclust.prm`, the JRCLUST writer's fixed default,
%   is not carried under [v1 name goes to the class's own name field]: the name
%   is notation, rebuilt by the round trip; any other name still carries"
%   (did2.convert.roundtrip.jrclust_clusters restates it).
tf = any(strcmp(className, {'jrclust_clusters'})) && strcmp(name, 'jrclust.prm');
end

function tf = v1NameIsKept(bodies, name)
%V1NAMEISKEPT True when an emitted document holds NAME, unchanged, in a
%   top-level `name`, `description` or `notes` field of one of its own blocks
%   (entity.name, acquisition_system.name, method.name, data_body.description,
%   ...). `base`, `document_class`, `depends_on`, `files` and `statement` are
%   not read: a statement's notes are not its name.
tf = false;
skip = {'base', 'document_class', 'depends_on', 'files', 'file', 'statement'};
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isstruct(b) || ~isscalar(b)
        continue;
    end
    fns = fieldnames(b);
    for j = 1:numel(fns)
        if any(strcmp(fns{j}, skip)) || ~isstruct(b.(fns{j})) || ~isscalar(b.(fns{j}))
            continue;
        end
        blk = b.(fns{j});
        for f = {'name', 'description', 'notes'}
            if isfield(blk, f{1}) && (ischar(blk.(f{1})) || (isstring(blk.(f{1})) ...
                    && isscalar(blk.(f{1})))) && strcmp(char(blk.(f{1})), name)
                tf = true;
                return;
            end
        end
    end
end
end

function tf = replacementIsStatement(bodies, sourceId)
%REPLACEMENTISSTATEMENT True when the emitted document that most directly
%   replaces the source -- the one holding its id, else the first -- is a
%   statement (it has a `statement` block).
tf = false;
pick = [];
for k = 1:numel(bodies)
    b = bodies{k};
    if isstruct(b) && isscalar(b) && isfield(b, 'base') && isstruct(b.base) ...
            && isfield(b.base, 'id') && strcmp(char(b.base.id), sourceId)
        pick = b;
        break;
    end
end
if isempty(pick) && isstruct(bodies{1})
    pick = bodies{1};
end
tf = isstruct(pick) && isscalar(pick) && isfield(pick, 'statement');
end

function tf = hasLegacyBlockBesideBase(body)
%HASLEGACYBLOCKBESIDEBASE True when a v1 body holds a NON-EMPTY `ndi_document`
%   block beside `base`: [old ndi_document blocks carry] (Decided by Jess Haley,
%   2026-10-27, did-schema V_eta_go_forward_class_audit.md), carry-049 for
%   every class. An EMPTY block -- [], JSON `{}`, or one whose every field is
%   empty -- states nothing and does not carry: [empty ndi_document block is
%   notation] (Decided by Jess Haley, 2026-10-27: "Its absence is not a
%   loss"); the document converts, and the round trip counts a missing block
%   and an empty one as the same. A body with only `ndi_document` (a pre-2023
%   vintage, whose block IS its identity) is not this case.
tf = isstruct(body) && isscalar(body) && isfield(body, 'ndi_document') ...
    && isfield(body, 'base') && ~did2.convert.isEmptyBlock(body.ndi_document);
end

function name = rawV1ClassNameOf(body)
%RAWV1CLASSNAMEOF A raw v1 body's class name, as v1 spells it ('' if none).
%   The switch (did2.convert.rawV1Classes) is keyed on the v1 spelling, read by
%   did2.convert.v1read.readStamp, never on a universalRenames output.
stamp = did2.convert.v1read.readStamp(body);
name = stamp.class_name;
if ~ischar(name)
    name = '';
end
end

function bodies = runRawV1Migrator(rawBody, className)
%RUNRAWV1MIGRATOR Run a switched class's migrator on the RAW v1 body.
%   A class listed by did2.convert.rawV1Classes has its own +migrators_j
%   migrator by definition ([early migration pieces fixed] (1): no identity
%   fallback), so a missing one is an error, which quarantines the document.
%   The migrator's name is the v1 name, except where rawV1Classes' one table
%   maps it (contrasttuning_calc -> contrast_tuning_calc, temporary).
fqn = ['did2.convert.migrators_j.', did2.convert.rawV1Classes(className)];
if isempty(which(fqn))
    error('did2:convert:rawV1NoMigrator', ...
        ['%s is listed by did2.convert.rawV1Classes but has no ' ...
        '+migrators_j migrator.'], className);
end
bodies = normaliseMigratorOutput(feval(str2func(fqn), rawBody));
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
%   A class with no +migrators_j migrator gets its base migrator under
%   +did2.+convert.+migrators (identity when it has none) and a
%   single-element cell is returned. A class that has
%   a Brainstorm-J split/fold migrator under +did2.+convert.+migrators_j is
%   routed there instead; that migrator may return either a single body
%   (struct) or several (struct array / cell), enabling the treatment ->
%   manipulation (1 -> N) split.
splitPackage = '';
if did2.convert.isV2Set(targetVersion)
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

function cache = outboundSchemaCache(cache)
% The cache the batch validates against: the caller's, else the shared one.
if isempty(cache)
    cache = did2.schema.cache.shared();
end
end

function body = renameOutboundBaseFields(body, targetVersion, sessionEdge)
%RENAMEOUTBOUNDBASEFIELDS did_v1 `base` field names -> their V_eta spellings.
%
%   ONE PLACE, ON THE WAY OUT, FOR EVERY BODY. This runs on each emitted body
%   immediately after ensureClassBlocks and before validation, which is the
%   only point in the pipeline that ALL documents pass through -- the ones a
%   migrator constructed, the ones a 1->N split produced, and the passthroughs
%   that no migrator touched at all.
%
%   ---------------------------------------------------------------------
%   WHY NOT AT THE 65 CONSTRUCTION SITES, AND WHY NOT IN universalRenames
%   ---------------------------------------------------------------------
%   The obvious version of this change is to rename the field wherever a
%   `base` block is built. That is 65+ sites, and it MISSES EVERY PASSTHROUGH:
%   a document with no migrator still carries a `base` block, still validates
%   against a V_eta tombstone, and would still be carrying the old field name.
%
%   The other obvious version is universalRenames, which every document also
%   passes through -- but that runs INBOUND, before the migrators. Renaming
%   there would break every migrator that reads `baseField(preBody,
%   'datestamp')`, and it would break them SILENTLY: the read returns empty,
%   the caller falls back to the sentinel, and the document validates carrying
%   a fabricated creation time. Nothing counts that. Doing it outbound means
%   migrators keep reading and writing did_v1 spelling internally and NOT ONE
%   of them needed to change.
%
%   THE FAILURE MODE IS LOUD BY CONSTRUCTION. If this function ever fails to
%   reach a body, that body keeps `base.datestamp` -- an undeclared field
%   under V_eta -- and quarantines. The dangerous direction (a silently
%   wrong timestamp) is not reachable from here.
%
%   STATUS: NOT VERIFIED BY EXECUTION -- no MATLAB in the authoring
%   environment.
%
%   `session_id` -> THE `session_id` EDGE, when SESSIONEDGE (the loaded `base`
%   declares the edge: did-schema V_eta_relation_inheritance_plan.md,
%   2026-10-20). The same argument as `datestamp`: every body, constructed or
%   passed through, carries the v1 field until here, and every migrator keeps
%   reading and writing it. The edge's target is the session (or dataset)
%   entity, whose base.id IS the session id (migrators_j.session re-ids the
%   session document to make that true), so the value moves unchanged. A body
%   with no field (already moved, or built on the edge shape) is left as it is,
%   so a batch pass may send its bodies back through here.
arguments
    body
    targetVersion (1,:) char
    sessionEdge (1,1) logical = false
end
if ~did2.convert.isV2Set(targetVersion)
    return;
end
if ~isfield(body, 'base') || ~isstruct(body.base) || ~isscalar(body.base)
    return;
end
if sessionEdge && isfield(body.base, 'session_id')
    body = moveSessionIdToEdge(body);
end
% `datestamp` -> `creation_timestamp`. `<noun>_<kind>` is the measured house
% style (13 `_name`, 11 `_time`, 10 `_type`, 5 `_id`; 0 bare participles in
% 472 field names), and the kind word is `_timestamp` rather than `_time`
% because all 22 existing `_time`/`_times` fields are NUMERIC -- offsets and
% durations in seconds, never wall-clock instants.
if isfield(body.base, 'datestamp')
    if ~isfield(body.base, 'creation_timestamp')
        body.base.creation_timestamp = body.base.datestamp;
    end
    body.base = rmfield(body.base, 'datestamp');
end
end

function body = moveSessionIdToEdge(body)
%MOVESESSIONIDTOEDGE `base.session_id` -> the `session_id` depends_on edge.
%   The field is the authority: a `session_id` edge already on the body is
%   replaced by it, not kept beside it (base declares the edge once, and an
%   epoch minted by did2.convert.epochMint carries one naming the session
%   document, which on this shape is the same id). An empty field is removed
%   and writes no edge -- the validator then reports the required edge as
%   missing, which is the honest outcome for a document with no session.
%
%   The other edges are left exactly as they are, in order and with their key
%   spelling; the new entry goes LAST and takes the spelling of the entries
%   beside it (`value` on a raw
%   migrator body, `document_id` after universalRenames), so a struct array
%   stays one struct array.
sid = char(body.base.session_id);
body.base = rmfield(body.base, 'session_id');
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    deps = struct('name', {}, 'document_id', {});
else
    deps = body.depends_on;
end
if iscell(deps)
    keep = true(1, numel(deps));
    for k = 1:numel(deps)
        keep(k) = ~(isstruct(deps{k}) && isfield(deps{k}, 'name') ...
            && strcmp(char(deps{k}.name), 'session_id'));
    end
    deps = deps(keep);
    if ~isempty(sid)
        deps = [reshape(deps, 1, []), {struct('name', 'session_id', 'document_id', sid)}];
    end
    body.depends_on = deps;
    return;
end
if isempty(deps)
    if ~isempty(sid)
        body.depends_on = struct('name', 'session_id', 'document_id', sid);
    else
        body.depends_on = struct('name', {}, 'document_id', {});
    end
    return;
end
names = fieldnames(deps);
key = 'document_id';
for candidate = {'document_id', 'value', 'id'}
    if any(strcmp(names, candidate{1}))
        key = candidate{1};
        break;
    end
end
for f = {'name', key}
    if ~any(strcmp(names, f{1}))
        [deps.(f{1})] = deal('');   % a shape with no such key gains it, empty
        names{end+1} = f{1}; %#ok<AGROW>
    end
end
deps = deps(~arrayfun(@(d) strcmp(char(d.name), 'session_id'), deps));
if isempty(sid)
    body.depends_on = deps;
    return;
end
entry = cell2struct(repmat({''}, numel(names), 1), names, 1);
entry = orderfields(entry, deps);
entry.name = 'session_id';
entry.(key) = sid;
body.depends_on = [reshape(deps, 1, []), entry];
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
% above it kept running the base migrators unconditionally. So under
% TargetVersion 'V_eta', +migrators/ngrid.m -- whose whole job is the
% earlier class-preserving reshape (data_dim -> dim_sizes, derive ndims, rmfield
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
    targetVersion = 'V_eta';
end
superPackage = '';
if did2.convert.isV2Set(targetVersion)
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
        % the v1 body as V1 wrote it: NaN / Infinity kept (jsonencodenan)
        text = jsonencode(rawBody, 'ConvertInfAndNaN', false);
    catch
        text = '';
    end
else
    text = '';
end
end

function [id, depNames, depIds] = sourceEdges(body)
%SOURCEEDGES A v1 source's id (base.id, or its legacy identity block's) and
%   its depends_on edges (did2.convert.v1read), for carryDependents.
id = '';
depNames = {};
depIds = {};
try
    b = did2.convert.v1read.readBase(body);
    if ischar(b.id); id = b.id; end
    deps = did2.convert.v1read.readDependsOn(body);
    for k = 1:numel(deps)
        if ischar(deps(k).document_id) && ~isempty(deps(k).document_id)
            depNames{end+1} = char(deps(k).name); %#ok<AGROW>
            depIds{end+1} = deps(k).document_id; %#ok<AGROW>
        end
    end
catch
end
end

function rows = carryRowsCited(details)
%CARRYROWSCITED The carry register rows ('carry-NNN') DETAILS cite, sorted.
rows = {};
for j = 1:numel(details)
    toks = regexp(char(details{j}), '\[(carry-\d{3})\]', 'tokens');
    for t = 1:numel(toks)
        rows{end+1} = toks{t}{1}; %#ok<AGROW>
    end
end
rows = unique(rows);
end

function carryOneEpochsWithElement(done, carried, withElement, cls, ids, ...
        depNames, depIds, carryRows)
%CARRYONEEPOCHSWITHELEMENT [global-clock oneepoch carried with its element]
%   (Decided by Jess Haley, 2026-10-30, did-schema
%   V_eta_go_forward_class_audit.md, "Q5 a"): "in the generic stage a
%   global-clock `oneepoch` is carried with its output element (carry-062 /
%   carry-063 / carry-064, which already carry every such element)".
%
%   migrators_j.oneepoch hands such a oneepoch back unchanged with a
%   `carried_with_element` note; the loop carried it (stamped did_v1, a
%   passthrough) without a `carried_as_v1` note, because a per-document
%   migrator cannot see how its element was carried. Here, once every source
%   and every dependent of a carried source is placed, each one gets its
%   `carried_as_v1` note: the `[carry-NNN]` rows its element's own carry
%   note cites (carryDependents' carry-064 for an element carried there).
%   An element that is not carried in this batch (not in it, or converted:
%   the decision says every such element is carried, so this is a finding,
%   not a reading) gives a note that says so and cites no row; the oneepoch
%   is carried all the same, since nothing converts it.
for k = reshape(find(done & carried & withElement), 1, [])
    elementId = '';
    j = find(strcmp(depNames{k}, 'element_id'), 1);
    if ~isempty(j)
        elementId = char(depIds{k}{j});
    end
    e = [];
    if ~isempty(elementId)
        e = find(done & strcmp(ids, elementId) & strcmp(cls, 'element'), 1);
    end
    if ~isempty(e) && carried(e) && ~isempty(carryRows{e})
        tags = strjoin(cellfun(@(r) ['[' r ']'], carryRows{e}, ...
            'UniformOutput', false), ' ');
        % carry-register: forwarded (the rows its output element's own carry
        % note cites, read from that note: the element rows of the register)
        did2.convert.reportNote('carried_as_v1', cls{k}, ids{k}, sprintf( ...
            ['%s a oneepoch on a global clock, carried with its output element ' ...
            '%s ([global-clock oneepoch carried with its element])'], tags, elementId));
    else
        if isempty(elementId)
            why = 'names no element_id';
        elseif isempty(e)
            why = sprintf('names element %s, which is not in this batch', elementId);
        elseif carried(e)
            why = sprintf('names element %s, whose carry note cites no register row', elementId);
        else
            why = sprintf('names element %s, which this batch does not carry', elementId);
        end
        % carry-register: none (the decision expects every such element to be
        % carried; one that is not is reported here, no row invented)
        did2.convert.reportNote('carried_as_v1', cls{k}, ids{k}, sprintf( ...
            ['a oneepoch on a global clock, not carried with its output element: ' ...
            'it %s ([global-clock oneepoch carried with its element])'], why));
    end
end
end

function [migrated, passthrough, names, counts, carried] = carryDependents(bodies, ...
        migrated, passthrough, names, counts, done, carried, raw, target, ...
        cls, ids, depNames, depIds, outs, renameClassNames)
%CARRYDEPENDENTS [dependents of a carried document carry] (Jess Haley,
%   2026-10-26, did-schema V_eta_go_forward_class_audit.md): "a document whose
%   edge points at a document carried as v1 (e.g. an element_epoch,
%   position_metadata or spike train of a carried element) is carried too,
%   down the chain, rather than converting with an edge to a v1 document"
%   (carry-064, any class).
%
%   After every source has been migrated: a CONVERTED source (not carried, not
%   quarantined, not already a V2 document) any of whose depends_on edges names
%   the id of a CARRIED source in this batch has its documents replaced by its
%   v1 source carried whole -- the raw document for a class read raw
%   (did2.convert.rawV1Classes), else the universalRenames output, as every
%   other carry -- stamped did_v1, recorded as a passthrough, and noted
%   `carried_as_v1` citing carry-064. Repeated until nothing changes, so a
%   chain carries to its end. A carried document outside this batch is not
%   seen. The notes the source's conversion left stay in the report.
%
%   NOT A v1 END STATE, so not followed: a document pass 1 carries only to hand
%   it to NDI's second pass, which converts it -- `stimulus_presentation`
%   (carry-045: "a retired class, decomposed by NDI's second pass") and
%   `daqmetadatareader_epochdata_ingested` (carry-046: "made an opaque_body of
%   the epoch's presentation by NDI's second pass"). An edge to one of them
%   does not end as "an edge to a v1 document", which is what the decision
%   prevents; following it would carry every stimulus response.
%   `control_stimulus_ids` is handed on the same way (carry-152, [control
%   records carried in pass 1], Jess Haley, 2026-10-30: "with
%   `stimulus_presentation`'s reason").
handedOn = {'stimulus_presentation', 'daqmetadatareader_epochdata_ingested', ...
    'control_stimulus_ids'};
isHandedOn = cellfun(@(c) ischar(c) && any(strcmp(c, handedOn)), cls);
carriedIds = ids(done & carried & ~isHandedOn);
carriedIds = carriedIds(~cellfun(@isempty, carriedIds));
if isempty(carriedIds)
    return;
end
drop = false(1, numel(migrated));
changed = true;
while changed
    changed = false;
    for k = reshape(find(done & ~carried & ~target), 1, [])
        j = find(ismember(depIds{k}, carriedIds), 1);
        if isempty(j)
            continue;
        end
        body = ensureStruct(bodies{k});
        if ~raw(k)
            body = did2.convert.universalRenames(body, 'RenameClassNames', renameClassNames);
        end
        if isfield(body, 'document_class') && isstruct(body.document_class)
            body.document_class.schema_version = 'did_v1';
        end
        for i = outs{k}
            [names, counts] = dropClassCounter(names, counts, migrated{i}.className());
        end
        drop(outs{k}) = true;
        migrated{end+1} = did2.document(body); %#ok<AGROW>
        drop(end+1) = false; %#ok<AGROW>
        [names, counts] = bumpClassCounter(names, counts, cls{k});
        % ONE RECORD PER SOURCE. A source the loop recorded as a passthrough
        % (a migrator handed it back unchanged, no carry note: an
        % ontologyLabel, an E. coli imageStack) and that is carried here had
        % two records, the first naming the did_v2-stamped body that is no
        % longer emitted; NDI's carryUnchangedAsV1 then counted the one
        % document twice (once changed_after_pass_one, once carried_as_v1).
        % The carry replaces that record.
        passthrough([passthrough.input_index] == k) = [];
        passthrough(end+1) = struct('input_index', k, 'id', ids{k}, ...
            'class_name', cls{k}, 'body', body); %#ok<AGROW>
        % carry-register: carry-064
        did2.convert.reportNote('carried_as_v1', cls{k}, ids{k}, sprintf( ...
            '[carry-064] needs_mapping: its %s edge names %s, which is carried as v1', ...
            depNames{k}{j}, depIds{k}{j}));
        carried(k) = true;
        if ~isempty(ids{k})
            carriedIds{end+1} = ids{k}; %#ok<AGROW>
        end
        changed = true;
    end
end
migrated = migrated(~drop);
end

function rep = carriedV1TemplateCheck(bodies, carried, done, cls, ids, validate)
%CARRIEDV1TEMPLATECHECK [carried v1 validates against NDI templates]: each
%   carried source checked against NDI-matlab's v1 template for its class.
%   Denominators first: carried_inspected, then checked / valid / invalid.
rep = struct('checked', false, 'reason', '', 'template_root', '', ...
    'template_count', 0, 'carried_inspected', nnz(carried & done), ...
    'valid', 0, 'invalid', 0, 'invalid_by_class', struct(), ...
    'problems_sample', {{}}, 'problem_ids_sample', {{}});
if ~validate
    rep.reason = 'NOT CHECKED: Validate is off';
    return;
end
try
    T = did2.schema.v1Templates();
catch err
    rep.reason = ['NOT CHECKED: the templates could not be read: ' err.message];
    return;
end
rep.template_root = T.root;
rep.template_count = T.count;
if ~T.present
    rep.reason = ['NOT CHECKED: no NDI v1 templates (set DID_NDI_TEMPLATE_PATH to ' ...
        'NDI-matlab src/ndi/ndi_common/database_documents at the locked main)'];
    return;
end
rep.checked = true;
for k = reshape(find(carried & done), 1, [])
    try
        r = did2.validate.v1Document(ensureStruct(bodies{k}), T);
        ok = r.ok;
        problems = r.problems;
    catch err
        ok = false;
        problems = {['unreadable: ' err.message]};
    end
    if ok
        rep.valid = rep.valid + 1;
        continue;
    end
    rep.invalid = rep.invalid + 1;
    f = matlab.lang.makeValidName(char(cls{k}));
    if isfield(rep.invalid_by_class, f)
        rep.invalid_by_class.(f) = rep.invalid_by_class.(f) + 1;
    else
        rep.invalid_by_class.(f) = 1;
    end
    if numel(rep.problems_sample) < 20
        rep.problems_sample{end+1} = strjoin(problems, '; ');
        rep.problem_ids_sample{end+1} = char(ids{k});
    end
end
end

function [migrated, passthrough, names, counts, carried] = carryUnrebuiltSessionLists( ...
        bodies, migrated, passthrough, names, counts, done, carried, raw, target, ...
        cls, ids, depIds, renameClassNames)
%CARRYUNREBUILTSESSIONLISTS [fit classes kept; session list rebuilt] (Decided
%   by Jess Haley, 2026-10-27, did-schema V_eta_go_forward_class_audit.md):
%   "`dataset_session_info` (still written by NDI-matlab main +dataset/dir.m,
%   +session/dir.m) is not retired and writes no V2 document: the round trip
%   rebuilds it from the session entities' `included_in` relations to the
%   dataset, and one that does not rebuild exactly is carried whole as v1".
%
%   migrators_j.dataset_session_info writes nothing. Here, after every source
%   has migrated, each such source's list is rebuilt from the batch: the
%   CONVERTED `session_in_a_dataset` sources of the same dataset (base.session_id),
%   in batch order, each one's v1 block -- what its own round trip rebuilds
%   from its membership relation (testRawV1RoundTripSession). The list must be
%   the v1 `dataset_session_info.dataset_session_info` exactly: the same
%   number of entries, in order, each equal field by field. Anything else --
%   a member missing, carried or quarantined, an extra member, another order,
%   another value -- carries the document whole as v1 (the v1 source for a raw
%   read, else the universalRenames output, as every other carry). The register
%   row is carry-118 (awaiting_home).
%
%   ITS ID. [a rebuilt document may lose its id] (Decided by Jess Haley,
%   2026-10-27, amending [every v1 id survives]): a list that rebuilds writes
%   no V2 document and so keeps no id, which is allowed only when no other
%   document references it; a list some source in the batch names by an edge
%   is carried whole as v1 instead.
isList = cellfun(@(c) ischar(c) && strcmp(c, 'dataset_session_info'), cls);
for k = reshape(find(done & ~carried & ~target & isList), 1, [])
    body = ensureStruct(bodies{k});
    entries = struct([]);
    if isfield(body, 'dataset_session_info') && isstruct(body.dataset_session_info) ...
            && isfield(body.dataset_session_info, 'dataset_session_info')
        entries = body.dataset_session_info.dataset_session_info;
    end
    datasetId = '';
    if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, 'session_id')
        datasetId = char(body.base.session_id);
    end
    rebuilt = {};
    for j = reshape(find(done & ~carried & ~target), 1, [])
        if ~strcmp(cls{j}, 'session_in_a_dataset')
            continue;
        end
        m = ensureStruct(bodies{j});
        if ~isfield(m, 'base') || ~isstruct(m.base) || ~isfield(m.base, 'session_id') ...
                || ~strcmp(char(m.base.session_id), datasetId) ...
                || ~isfield(m, 'session_in_a_dataset') || ~isstruct(m.session_in_a_dataset)
            continue;
        end
        rebuilt{end+1} = m.session_in_a_dataset; %#ok<AGROW>
    end
    why = '';
    if ~isstruct(entries) && ~isempty(entries)
        why = 'its list is not a struct array';
    elseif numel(entries) ~= numel(rebuilt)
        why = sprintf('%d entries; the converted memberships of dataset %s rebuild %d', ...
            numel(entries), datasetId, numel(rebuilt));
    else
        for e = 1:numel(entries)
            if ~isequaln(entries(e), rebuilt{e})
                why = sprintf('entry %d differs from the membership the batch rebuilds', e);
                break;
            end
        end
    end
    if isempty(why) && ~isempty(ids{k})
        for j = reshape(find(done), 1, [])
            if j ~= k && iscell(depIds{j}) && any(strcmp(depIds{j}, ids{k}))
                why = sprintf(['document %s references it, so its id must survive ' ...
                    '([a rebuilt document may lose its id])'], char(ids{j}));
                break;
            end
        end
    end
    if isempty(why)
        continue;
    end
    if ~raw(k)
        body = did2.convert.universalRenames(body, 'RenameClassNames', renameClassNames);
    end
    if isfield(body, 'document_class') && isstruct(body.document_class)
        body.document_class.schema_version = 'did_v1';
    end
    migrated{end+1} = did2.document(body); %#ok<AGROW>
    [names, counts] = bumpClassCounter(names, counts, cls{k});
    passthrough([passthrough.input_index] == k) = [];
    passthrough(end+1) = struct('input_index', k, 'id', ids{k}, ...
        'class_name', cls{k}, 'body', body); %#ok<AGROW>
    % carry-register: carry-118
    did2.convert.reportNote('carried_as_v1', cls{k}, ids{k}, sprintf( ...
        ['[carry-118] awaiting_home: the session list does not rebuild from the dataset''s ' ...
        'memberships: %s ([fit classes kept; session list rebuilt])'], why));
    carried(k) = true;
end
end

function [names, counts] = dropClassCounter(names, counts, name)
idx = find(strcmp(names, name), 1);
if ~isempty(idx) && counts(idx) > 0
    counts(idx) = counts(idx) - 1;
end
end

function [names, counts] = bumpClassCounter(names, counts, name)
idx = find(strcmp(names, name), 1);
if isempty(idx)
    names{end+1} = name;
    counts(end+1) = 1;
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
printEmittedNothing(result);
printDimensionTerms(result);
printStimulusControlEdges(result);
printTuningResponseVariable(result);
printMigrationNotes(result);
printLegacyNdiDocument(result);
printSilentLoss(result);
printQuarantine(result);
end

function [n, noNode] = dimensionTermCounts(body)
%DIMENSIONTERMCOUNTS The dimensions BODY writes (in its `data` and
%   `acquisition_epoch` blocks) and how many of them have a term with no node.
n = 0;
noNode = 0;
for b = {'data', 'acquisition_epoch'}
    if ~isfield(body, b{1}) || ~isstruct(body.(b{1})) || ~isscalar(body.(b{1})) ...
            || ~isfield(body.(b{1}), 'dimensions')
        continue;
    end
    d = body.(b{1}).dimensions;
    if iscell(d)
        d = d(cellfun(@isstruct, d));
    elseif isstruct(d)
        d = num2cell(d);
    else
        continue;
    end
    for k = 1:numel(d)
        n = n + 1;
        t = [];
        if isfield(d{k}, 'term'); t = d{k}.term; end
        if iscell(t) && ~isempty(t); t = t{1}; end
        node = '';
        if isstruct(t) && ~isempty(t) && isfield(t, 'node'); node = t(1).node; end
        if isempty(node) || (isstring(node) && strlength(node) == 0)
            noNode = noNode + 1;
        end
    end
end
end

function s = dimensionTermSummary(nDocs, classes, written, noNode)
%DIMENSIONTERMSUMMARY summary.dimension_terms: DENOMINATORS FIRST
%   (documents_inspected, dimensions_written), then without_node, then per
%   class {dimensions_written, without_node}. A class that writes no
%   dimension has no row; documents_inspected says how many were looked at.
byClass = struct();
for k = 1:numel(classes)
    byClass.(matlab.lang.makeValidName(classes{k})) = struct( ...
        'dimensions_written', written(k), 'without_node', noNode(k));
end
s = struct('documents_inspected', nDocs, ...
    'dimensions_written', sum(written), ...
    'without_node', sum(noNode), ...
    'by_class', byClass);
end

function printDimensionTerms(result)
%PRINTDIMENSIONTERMS [covariate details] 5.4: dimensions whose term has no node.
if ~isfield(result.summary, 'dimension_terms'); return; end
d = result.summary.dimension_terms;
fprintf(['  dimension terms: %d of %d dimension(s) written have a term with ' ...
    'no node (%d migrated document(s) inspected)\n'], d.without_node, ...
    d.dimensions_written, d.documents_inspected);
cls = fieldnames(d.by_class);
for j = 1:numel(cls)
    r = d.by_class.(cls{j});
    fprintf('      %-40s %d of %d\n', cls{j}, r.without_node, r.dimensions_written);
end
end

function printStimulusControlEdges(result)
%PRINTSTIMULUSCONTROLEDGES [covariate rules named] 6.4: the v1
%   `stimulus_control_id` edges the response migrators drop ([control as
%   covariate]), against the response documents they converted.
dropped = 0;
total = 0;
if isfield(result.summary, 'migration_notes') ...
        && isfield(result.summary.migration_notes, 'stimulus_control_id')
    n = result.summary.migration_notes.stimulus_control_id;
    total = n.count;
    hit = strcmp(n.distinct_details, 'dropped');
    if any(hit); dropped = n.distinct_detail_counts(hit); end
end
fprintf(['  stimulus_control_id edges dropped: %d of %d converted stimulus ' ...
    'response document(s)\n'], dropped, total);
end

function printTuningResponseVariable(result)
%PRINTTUNINGRESPONSEVARIABLE [response variable] / [dF/F as variable]: the
%   folded tuning documents (jCalculation, one 'tuning_response_variable' note
%   each), DENOMINATOR FIRST, then how many had `variable` set from v1
%   `response_units` and how many got the general term EMPTY:0000398
%   "neural response" because the source was empty or its spelling
%   unrecognised ([unstated response variable], 2026-10-23).
total = 0;
names = {'neural firing rate', 'dF/F', 'not stated'};
counts = zeros(1, numel(names));
other = 0;
if isfield(result.summary, 'migration_notes') ...
        && isfield(result.summary.migration_notes, 'tuning_response_variable')
    n = result.summary.migration_notes.tuning_response_variable;
    total = n.count;
    for j = 1:numel(names)
        hit = strcmp(n.distinct_details, names{j});
        if any(hit); counts(j) = n.distinct_detail_counts(hit); end
    end
    other = total - sum(counts);
end
fprintf(['  tuning response variable: %d folded tuning document(s); set from ' ...
    'response_units: %d (neural firing rate %d, dF/F %d); general term ' ...
    '"neural response": %d (source empty %d, spelling unrecognised %d)\n'], ...
    total, counts(1) + counts(2), counts(1), counts(2), counts(3) + other, ...
    counts(3), other);
end

function printMigrationNotes(result)
%PRINTMIGRATIONNOTES Notes migrators left (did2.convert.reportNote), per kind.
if ~isfield(result.summary, 'migration_notes'); return; end
notes = result.summary.migration_notes;
kinds = fieldnames(notes);
for k = 1:numel(kinds)
    n = notes.(kinds{k});
    fprintf('  migration note %s: %d document(s)\n', kinds{k}, n.count);
    cls = fieldnames(n.by_class);
    for j = 1:numel(cls)
        fprintf('      %-40s %d\n', cls{j}, n.by_class.(cls{j}));
    end
    % carries by carry register row (practice (d) of [migration reliability
    % practices], Jess Haley, 2026-10-26), denominator first: every carry,
    % then those citing a row and those citing none (reportNote 'collect')
    if isfield(n, 'register_rows')
        fprintf(['      by carry register row: %d carry note(s); citing a row %d; ' ...
            'citing no row %d\n'], n.count, n.notes_citing_a_row, ...
            n.notes_citing_no_row);
        for j = 1:numel(n.register_rows)
            fprintf('        %-38s %d\n', n.register_rows{j}, n.register_row_counts(j));
        end
    end
    % what the notes name (field_dropped: the field path), distinct, counted.
    % distinct_details is exact over every note; ids/details are a sample
    % (did2.convert.reportNote), so the sample is stated, never passed off
    % as the whole list.
    if isfield(n, 'distinct_details')
        [u, order] = sort(n.distinct_details);
        c = n.distinct_detail_counts(order);
        for j = 1:numel(u)
            fprintf('        %-38s %d\n', u{j}, c(j));
        end
    elseif isfield(n, 'details')
        d = n.details(~cellfun(@isempty, n.details));
        [u, ~, ix] = unique(d);
        for j = 1:numel(u)
            fprintf('        %-38s %d\n', u{j}, sum(ix == j));
        end
    end
    if isfield(n, 'sample_kept')
        fprintf('      ids held: %d of %d note(s) (a sample: the first %d per class)\n', ...
            n.sample_kept, n.count, n.sample_cap_per_class);
    end
end
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
    '(of %d; %d already at target, %d read raw v1, %d carried with no ' ...
    'migrator, %d never reached it)\n'], ...
    L.bodies_reaching_universal_renames, L.bodies_total, ...
    L.bodies_skipped_already_target, L.bodies_read_raw_v1, ...
    L.bodies_carried_no_migrator, L.bodies_unreached);
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
fprintf(['                    field names present: %d experiment_unique_reference, ' ...
    '%d document_unique_reference, %d type, %d database_version\n'], ...
    L.moved_carrying_experiment_unique_reference, ...
    L.moved_carrying_document_unique_reference, ...
    L.moved_carrying_type, L.moved_carrying_database_version);
% THE VINTAGE BREAKDOWN, denominator first. `moved_wholesale_no_base` on its own
% says nothing about whether anything broke: the 2020-05-19 vintage moves
% SOUNDLY and it is the longest-lived of the four.
fprintf('      vintage of the %d moved block(s), classified on the FIELD SET:\n', ...
    L.moved_vintage_bodies_classified);
fprintf('          %8d  2019-05 experiment_unique_reference/document_unique_reference  NO identity survives\n', ...
    L.moved_vintage_2019_05_unique_reference);
fprintf('          %8d  2019-11 experiment_id/document_id                              NO identity survives\n', ...
    L.moved_vintage_2019_11_experiment_document_id);
fprintf('          %8d  2019-12 experiment_id/id                                       `id` survives, session_id does NOT\n', ...
    L.moved_vintage_2019_12_experiment_id_and_id);
fprintf('          %8d  2020-05 session_id/id  (SOUND -- both identity fields land)\n', ...
    L.moved_vintage_2020_05_session_id_and_id);
fprintf('          %8d  UNKNOWN field set -- NOT rounded to the nearest vintage\n', ...
    L.moved_vintage_unknown);
fprintf('          %8d  UNREADABLE block (not a scalar struct; no field set to read)\n', ...
    L.moved_vintage_unreadable_block);
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

function printEmittedNothing(result)
%PRINTEMITTEDNOTHING Report-only: sources a migrator consumed into nothing.
%   Not a failure when the class is meant to fold away (a lightsheetZarrLevel
%   that holds no bytes); a count on any other class is the signal.
arguments
    result (1,1) struct
end

if ~isfield(result.summary, 'emitted_nothing_count'); return; end
if result.summary.emitted_nothing_count == 0; return; end
fprintf(['  emitted nothing (REPORT ONLY -- migrator consumed the source ' ...
         'and returned no document): %d\n'], result.summary.emitted_nothing_count);
tbl = result.summary.emitted_nothing_by_class;
names = fieldnames(tbl);
for k = 1:numel(names)
    fprintf('    %6d  %s\n', tbl.(names{k}), names{k});
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
