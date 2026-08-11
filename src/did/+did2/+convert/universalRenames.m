function [postBody, report] = universalRenames(preBody, options)
%UNIVERSALRENAMES Apply did_v1 -> V_delta universal renames.
%
%   POSTBODY = did2.convert.universalRenames(PREBODY) returns a copy of
%   PREBODY with the cross-cutting transformations from
%   did-schema/schemas/V_delta/conversions/from_did_v1/_universal_renames.md
%   applied. Per-class migrators run after this pass and assume their
%   input is the semi-V_delta shape produced here.
%
%   POSTBODY = did2.convert.universalRenames(PREBODY, 'RenameClassNames', false)
%   skips the identifier-level snake_case sweep: document_class.class_name,
%   document_class.superclasses[i].class_name, top-level property-block
%   keys, and field names inside property blocks are left untouched.
%   Callers reading bodies whose schemas still spell identifiers in
%   the legacy (camelCase) form pass false so the body stays
%   schema-compatible while still gaining the V_delta shape
%   transformations (schema_version stamping, base reconciliation,
%   app block renames, depends_on rewrite). Default is true (full
%   V_delta normalisation).
%
%   Transformations applied:
%
%     - snake_case document_class.class_name (e.g., ontologyImage ->
%       ontology_image) and rename the matching top-level property
%       block key in lockstep. [gated by RenameClassNames]
%     - normalise document_class.superclasses[i] entries: derive
%       class_name from a v1 `definition` path when absent (the
%       basename of the path, stripped of `.json`), and snake_case
%       the result. [snake_case gated by RenameClassNames; the
%       derivation from definition runs unconditionally]
%     - field-level snake_case pass inside every class property block
%       (e.g., pyraview.nativeRate -> pyraview.native_rate,
%       pyraview.dataType -> pyraview.data_type). Only the *immediate*
%       field names of each block are renamed; nested struct values
%       (e.g., filter.parameters.sampleFrequency) are left alone for
%       per-class migrators to handle if needed. [gated by
%       RenameClassNames]
%     - rewrite depends_on entries to the V_delta (name,
%       document_id) shape. Accepts v1 (name, id [, version]) and
%       the earlier V_delta draft (name, value); precedence is
%       document_id > value > id when more than one is populated.
%       `version` is always dropped (V_delta does not support
%       per-document version branches). See did-schema#52 for the
%       V_delta-side rename rationale.
%     - rename `app.name` -> `app.app_name` and `app.version` ->
%       `app.app_version` on any document carrying a top-level `app`
%       block. V_delta's `app` schema names these fields with the
%       `app_` prefix; v1 carries the same data under the unprefixed
%       names. Documents whose v1 class did not include the `app`
%       superclass (most non-calc docs) are unaffected.
%     - reconcile legacy `ndi_document` block: pre-base v1 documents
%       carried document-identity fields under `ndi_document` rather
%       than `base`. If a v1 body has `ndi_document` but no `base`,
%       rename `ndi_document` -> `base`. If both are present, discard
%       `ndi_document` (base wins; ndi_document is stale).
%     - default document_class.schema_version to 'V_delta' when absent
%       so every migrated body self-identifies as V_delta-shaped. The
%       tag lives alongside class_name/class_version/superclasses on
%       document_class (it identifies the schema set, not a payload
%       field on any class) — never under `base`.
%
%   [POSTBODY, REPORT] = did2.convert.universalRenames(...) additionally
%   returns a per-body counter struct for the LEGACY IDENTITY BLOCK
%   reconciliation above. REPORT IS BUILT BEFORE A SINGLE FIELD IS READ and
%   is returned for every body, so a body with no `ndi_document` block
%   reports `bodies_inspected: 1` beside zeros rather than nothing at all
%   (Operating Rule 5: an instrument reports its denominator, first and
%   unconditionally). did2.convert.v1_to_v2 sums these into
%   `summary.legacy_ndi_document`, which reaches the per-corpus artifact via
%   did2.unittest.helpers.writeCorpusReport and the log via
%   tools/census_digest.py.
%
%   WHY THIS IS COUNTED AT ALL. The `ndi_document`-without-`base` arm exists
%   because the pre-`base` identity block DIFFERS from `base` -- and the arm
%   MOVES THE BLOCK WHOLESALE, renaming the container and doing nothing to
%   the contents. Read from NDI `origin/main` history rather than described:
%
%     ndi_document.json, block `ndi_document`, as added 4f1a2b801 (2019-05-05)
%       experiment_unique_reference, document_unique_reference,
%       name, type, datestamp, database_version                       SIX
%     base.json, block `base`, added 9783809c2 (2023-04-13) and unchanged
%     on origin/main; V_eta `base` declares the same four
%       id, session_id, name, datestamp                               FOUR
%
%   So a genuine 2019-vintage body arrives in `base` with FOUR undeclared
%   fields and BOTH required identity fields missing. `undeclaredField` is a
%   hard error (did2.schema.cache), so the document QUARANTINES -- and if it
%   did not, it would carry no identity at all. NOTHING COUNTED THAT, so a
%   real one quarantined with no line saying why. THE BEHAVIOUR IS UNCHANGED
%   HERE: this is the instrument, not the repair. The repair changes migrated
%   identity and is a team decision (V_eta_OPEN_WORK.md, "a pre-`base` v1
%   document cannot migrate").
%
%   The counters, and what each distinguishes:
%
%     bodies_inspected                        always 1 -- the denominator
%     ndi_document_block_seen                 a legacy block is present
%     moved_wholesale_no_base                 THE DEFECTIVE ARM: no `base`,
%                                             block renamed, contents untouched
%     discarded_ndi_document_base_present     the OTHER arm: `base` wins and
%                                             the legacy block is DISCARDED --
%                                             a different fact, never summed
%                                             with the one above
%     moved_missing_id / moved_missing_session_id
%                                             of the moved bodies, how many
%                                             land in `base` with a REQUIRED
%                                             field absent
%     moved_with_any_undeclared_field         moved bodies carrying at least
%                                             one field `base` does not declare
%     moved_undeclared_field_instances        those fields, counted
%     moved_carrying_experiment_unique_reference
%     moved_carrying_document_unique_reference
%     moved_carrying_type
%     moved_carrying_database_version         SINGLE-FIELD discriminators. Kept
%                                             because each is a fact on its own,
%                                             but see below: ONE FIELD CANNOT
%                                             NAME A VINTAGE.
%
%   THE VINTAGE CLASSIFIER (`moved_vintage_*`), and why one field is not enough.
%   The `ndi_document` block did not have one shape and then another. It had
%   FOUR, and two consecutive pairs of them differ by ONE FIELD NAME EACH --
%   `experiment_id` vs `session_id`, and `document_id` vs `id`. Re-read from NDI
%   origin/main rather than described (`git log --all --follow --
%   ndi_common/database_documents/ndi_document.json`, then `git show <c>:<path>`):
%
%     4f1a2b801  2019-05-05  experiment_unique_reference, document_unique_reference,
%                            name, type, datestamp, database_version
%     5d0b66d8f  2019-11-04  experiment_id, document_id,
%                            name, type, datestamp, database_version
%     f4f9d9450  2019-12-16  experiment_id, id,
%                            name, type, datestamp, database_version
%     e8c02831d  2020-05-19  session_id, id,
%                            name, type, datestamp, database_version
%     9783809c2  2023-04-13  ndi_document.json DELETED; base.json ADDED, with
%                            id, session_id, name, datestamp
%
%   6529ce7bf (2020-12-01) is NOT a fifth shape: it swaps the order of `id` and
%   `session_id` in the JSON and changes no field name, so as a FIELD SET it is
%   the 2020-05-19 vintage. That is exactly why the classifier compares SORTED
%   FIELD SETS and not field order or any single field.
%
%   THE CONSEQUENCE THIS EXISTS TO SIZE. From 2020-05-19 to 2023-04-13 -- nearly
%   three years, the longest-lived vintage -- the wholesale move lands IDENTITY
%   CORRECTLY (`id` and `session_id` are already spelled the way `base` spells
%   them) and only `type` + `database_version` arrive undeclared. Before
%   2019-12-16 the block has NEITHER identity field under a name `base` knows,
%   so the move produces a document missing both required fields. Those are
%   different defects wanting different repairs, and a single
%   `moved_wholesale_no_base` count mixes a sound migration with a broken one.
%
%     moved_vintage_bodies_classified         THE CLASSIFIER'S OWN DENOMINATOR:
%                                             bodies that reached it at all.
%     moved_vintage_2019_05_unique_reference  4f1a2b801 shape -- NO usable id,
%                                             NO usable session_id
%     moved_vintage_2019_11_experiment_document_id
%                                             5d0b66d8f shape -- same, under
%                                             different names
%     moved_vintage_2019_12_experiment_id_and_id
%                                             f4f9d9450 shape -- `id` lands,
%                                             `session_id` does not
%     moved_vintage_2020_05_session_id_and_id e8c02831d shape (incl. 6529ce7bf)
%                                             -- BOTH identity fields land
%     moved_vintage_unknown                   A FIELD SET THIS LIST DOES NOT
%                                             PREDICT. Never rounded to the
%                                             nearest vintage. Hand-edited
%                                             documents, partial writes and
%                                             mixtures are real, and forcing one
%                                             into a known bucket is the
%                                             assumed-shape error that produced
%                                             the distance_metadata quarantines.
%     moved_vintage_unreadable_block          the block is not a scalar struct,
%                                             so it HAS no field set. Counted
%                                             rather than skipped, so the
%                                             partition below still closes.
%
%   THE SIX BUCKETS PARTITION THE ARM: their sum equals
%   `moved_vintage_bodies_classified`, which equals `moved_wholesale_no_base`.
%   did2.unittest.testConvertV1ToV2 asserts that identity, because a body
%   falling through every bucket is the precise thing this counter exists to
%   catch.
%
%   Field-level renames that change identifiers (not just case) inside
%   a class's property block are class-specific (see the conversion
%   markdowns under did-schema's schemas/V_delta/conversions/from_did_v1/)
%   and are handled by per-class migrators, not here.
%
%   STATUS of the 2026-08-11 edit (the legacy-identity-block counters and
%   `countMovedBlock`): WRITTEN WITHOUT MATLAB OR OCTAVE AND NOT EXECUTED.
%   Neither is available in the environment it was written in, so CI is the
%   first run of this code. The Python half of the path
%   (tools/census_digest.py) IS covered and was run.
%
%   Throws did2:convert:missingDocumentClass when PREBODY has no
%   document_class.class_name. A body that throws produces NO report, so the
%   denominator v1_to_v2 keeps is incremented at the CALL SITE (bodies that
%   reached this function) rather than summed from the reports.

arguments
    preBody (1,1) struct
    options.RenameClassNames (1,1) logical = true
end

if ~isfield(preBody, 'document_class') ...
        || ~isstruct(preBody.document_class) ...
        || ~isfield(preBody.document_class, 'class_name')
    error('did2:convert:missingDocumentClass', ...
        'v1 body is missing document_class.class_name.');
end

% DENOMINATOR FIRST AND UNCONDITIONALLY (Operating Rule 5). Every counter
% below exists before any field of PREBODY is inspected, so "this body has no
% legacy identity block" prints zeros beside a 1, and never prints nothing.
report = struct( ...
    'bodies_inspected',                         1, ...
    'ndi_document_block_seen',                  0, ...
    'moved_wholesale_no_base',                  0, ...
    'discarded_ndi_document_base_present',      0, ...
    'moved_missing_id',                         0, ...
    'moved_missing_session_id',                 0, ...
    'moved_with_any_undeclared_field',          0, ...
    'moved_undeclared_field_instances',         0, ...
    'moved_carrying_experiment_unique_reference', 0, ...
    'moved_carrying_document_unique_reference', 0, ...
    'moved_carrying_type',                      0, ...
    'moved_carrying_database_version',          0, ...
    'moved_vintage_bodies_classified',          0, ...
    'moved_vintage_2019_05_unique_reference',   0, ...
    'moved_vintage_2019_11_experiment_document_id', 0, ...
    'moved_vintage_2019_12_experiment_id_and_id',   0, ...
    'moved_vintage_2020_05_session_id_and_id',      0, ...
    'moved_vintage_unknown',                    0, ...
    'moved_vintage_unreadable_block',           0);

postBody = preBody;

if options.RenameClassNames
    v1ClassName = char(postBody.document_class.class_name);
    v2ClassName = snakeCase(v1ClassName);
    v2ClassName = v1ToVDeltaClassName(v2ClassName);
    postBody.document_class.class_name = v2ClassName;
    if ~strcmp(v1ClassName, v2ClassName) && isfield(postBody, v1ClassName)
        postBody.(v2ClassName) = postBody.(v1ClassName);
        postBody = rmfield(postBody, v1ClassName);
    end
end

if isfield(postBody.document_class, 'superclasses') ...
        && isstruct(postBody.document_class.superclasses) ...
        && ~isempty(postBody.document_class.superclasses)
    postBody.document_class.superclasses = ...
        normaliseSuperclasses(postBody.document_class.superclasses, ...
            options.RenameClassNames);
end

if isfield(postBody, 'depends_on') ...
        && isstruct(postBody.depends_on) ...
        && ~isempty(postBody.depends_on)
    postBody.depends_on = renameDependsOnEntries(postBody.depends_on);
end

if options.RenameClassNames
    postBody = snakeCasePropertyBlocks(postBody);
end

if isfield(postBody, 'ndi_document')
    report.ndi_document_block_seen = 1;
    if isfield(postBody, 'base')
        % `base` wins; the legacy block is DISCARDED. Counted separately from
        % the arm below and NEVER summed with it -- discarding a stale block
        % beside a good `base` and moving a block that IS the only identity
        % are different facts, and one of them is the defect.
        report.discarded_ndi_document_base_present = 1;
        postBody = rmfield(postBody, 'ndi_document');
    else
        % THE DEFECTIVE ARM, MEASURED AND DELIBERATELY UNCHANGED. See the
        % header: the move is wholesale, so a 2019-vintage block lands in
        % `base` with four undeclared fields and no `id`/`session_id`.
        report.moved_wholesale_no_base = 1;
        report = countMovedBlock(report, postBody.ndi_document);
        postBody.base = postBody.ndi_document;
        postBody = rmfield(postBody, 'ndi_document');
    end
end

if isfield(postBody, 'app') && isstruct(postBody.app) ...
        && isscalar(postBody.app)
    postBody.app = renameAppBlockFields(postBody.app);
end

% Migrate a stale base.schema_version (left over from an earlier
% V_delta-draft migrator that stamped the tag on the base block) to
% document_class.schema_version, then default to 'V_delta' if absent.
% base.schema_version is not a declared V_delta field; leaving it on
% base would trip the strict-fields validator on the next write.
if isfield(postBody, 'base') && isstruct(postBody.base) ...
        && isscalar(postBody.base) ...
        && isfield(postBody.base, 'schema_version')
    if ~isfield(postBody.document_class, 'schema_version')
        postBody.document_class.schema_version = postBody.base.schema_version;
    end
    postBody.base = rmfield(postBody.base, 'schema_version');
end
if ~isfield(postBody.document_class, 'schema_version')
    postBody.document_class.schema_version = 'V_delta';
end
end

function report = countMovedBlock(report, block)
% Characterise the legacy identity block this pass is about to move WHOLESALE
% into `base`. Measurement only: nothing here changes the block, and nothing
% here validates it -- the validator does that later, and quarantines it.
%
% THE FOUR NAMES BELOW ARE `base`'s DECLARED FIELDS, and they are written out
% rather than read from a schema on purpose: this function runs deep inside a
% per-body rename pass with no schema cache in hand, and a counter that needed
% one would be skipped exactly where it is wanted. Read from NDI origin/main,
% src/ndi/ndi_common/database_documents/base.json, block `base`:
%     id, session_id, name, datestamp
% If `base` ever gains a field, this list is stale in the SAFE direction --
% it over-counts undeclared fields rather than under-counting them -- and
% did2.unittest.testConvertV1ToV2 pins the list against the V_eta schema.
declaredInBase = {'id', 'session_id', 'name', 'datestamp'};

% THE CLASSIFIER'S OWN DENOMINATOR, set before a single field is read, and set
% on EVERY path out of this function including the unreadable one. It is what
% the six `moved_vintage_*` buckets partition.
report.moved_vintage_bodies_classified = 1;

if ~isstruct(block) || ~isscalar(block)
    % Nothing readable to characterise: a block that is not a scalar struct has
    % no field set, so it cannot be classified -- but it DID reach the
    % classifier, and the arm counter above already fired. Counted in its own
    % bucket rather than skipped, because a skipped body breaks the partition
    % and reads downstream as "nothing unusual here". That is the fold-a-refusal
    % -into-silence failure this repository has now paid for twice.
    report.moved_vintage_unreadable_block = 1;
    return;
end

names = fieldnames(block);

if ~any(strcmp('id', names))
    report.moved_missing_id = 1;
end
if ~any(strcmp('session_id', names))
    report.moved_missing_session_id = 1;
end

undeclared = 0;
for k = 1:numel(names)
    if ~any(strcmp(names{k}, declaredInBase))
        undeclared = undeclared + 1;
    end
end
report.moved_undeclared_field_instances = undeclared;
report.moved_with_any_undeclared_field = double(undeclared > 0);

% The vintage discriminator. These four names are what the 2019 block carries
% and the 2020 one does not; without them a non-zero arm count cannot say
% whether anything is actually broken.
if any(strcmp('experiment_unique_reference', names))
    report.moved_carrying_experiment_unique_reference = 1;
end
if any(strcmp('document_unique_reference', names))
    report.moved_carrying_document_unique_reference = 1;
end
if any(strcmp('type', names))
    report.moved_carrying_type = 1;
end
if any(strcmp('database_version', names))
    report.moved_carrying_database_version = 1;
end

% THE VINTAGE CLASSIFIER. On the FIELD SET, never on a single field: two
% consecutive vintages differ only by `experiment_id` vs `session_id`, and
% another pair only by `document_id` vs `id`, so any one-field test collapses
% two shapes that need different repairs. See the function header for the git
% output the table is read from.
% ORIENTATION IS LOAD-BEARING, AND IT FAILS SILENTLY IF DROPPED. `isequal` on
% cell arrays is SIZE-sensitive -- a 6x1 and a 1x6 holding identical strings are
% not equal -- and `fieldnames` returns a COLUMN. So both sides are normalised
% to a column with `(:)` before `sort`: this side here, and `legacyVintageTable`
% for the table. Compare a column against the table's row literals and EVERY
% vintage misses, every body lands in `moved_vintage_unknown`, and the arm still
% partitions perfectly -- a classifier that has stopped classifying, wearing a
% green partition test. `testTheFieldSetComparisonIsOrientationNormalised` and
% `testEachVintageLandsInItsOwnBucket` are what go red instead.
%
% GitHub code scanning alert 195 flagged the earlier spelling of this line,
% `sort(names(:)')`, as "transposing the input to `sort` is often unnecessary".
% The transpose was NOT unnecessary -- it was half of this normalisation -- and
% deleting it was the failure above. It is gone now because BOTH sides moved to
% columns, which is the same normalisation without a transpose, not because the
% alert was right about the code being redundant.
[vintageCounters, vintageFieldSets] = legacyVintageTable();
if isempty(names)
    % An empty block HAS a field set -- the empty one -- and no vintage has
    % that. Written out rather than sorted because `sort` on an empty cell is
    % not worth relying on, and because "the block was empty" is a real shape
    % that must reach `unknown` rather than an error.
    sortedNames = cell(0, 1);
else
    sortedNames = sort(names(:));
end
matched = false;
for k = 1:numel(vintageCounters)
    if isequal(sortedNames, vintageFieldSets{k})
        report.(vintageCounters{k}) = 1;
        matched = true;
        break;
    end
end
if ~matched
    % EXPLICIT, NEVER ROUNDED TO THE NEAREST VINTAGE. A real corpus will hold
    % shapes this table does not predict -- hand edits, partial writes, the
    % 2018 `nsd_document` block (which carried a seventh field,
    % `hasbinaryfile`, at f45bcc82c) reaching here under a renamed key. Naming
    % the nearest known vintage for one of those is the assumed-shape error
    % that produced the distance_metadata quarantines.
    report.moved_vintage_unknown = 1;
end
end

function [counters, fieldSets] = legacyVintageTable()
%LEGACYVINTAGETABLE The four `ndi_document` block shapes, as NDI wrote them.
%
%   Each entry is a counter name and the SORTED field set of the block at that
%   vintage, transcribed from the NDI template at the commit named in the
%   counter and in did2.convert.universalRenames's header. The field sets are
%   pairwise distinct -- did2.unittest.testConvertV1ToV2 asserts that, so the
%   first-match loop above cannot become order-dependent if a fifth row is ever
%   added.
%
%   NOT INCLUDED, deliberately: 6529ce7bf (2020-12-01) reorders `id` and
%   `session_id` within the JSON and renames nothing, so it IS the 2020-05-19
%   field set; and f45bcc82c/7b080dca1 (2018) are the `nsd_document` block, a
%   different top-level key that cannot reach this arm. Anything shaped like
%   either but arriving here anyway lands in `moved_vintage_unknown`, which is
%   the correct answer.
counters = { ...
    'moved_vintage_2019_05_unique_reference', ...
    'moved_vintage_2019_11_experiment_document_id', ...
    'moved_vintage_2019_12_experiment_id_and_id', ...
    'moved_vintage_2020_05_session_id_and_id'};
raw = { ...
    {'experiment_unique_reference', 'document_unique_reference', ...
        'name', 'type', 'datestamp', 'database_version'}, ...
    {'experiment_id', 'document_id', ...
        'name', 'type', 'datestamp', 'database_version'}, ...
    {'experiment_id', 'id', ...
        'name', 'type', 'datestamp', 'database_version'}, ...
    {'session_id', 'id', ...
        'name', 'type', 'datestamp', 'database_version'}};
% COLUMNS, to match `fieldnames`. The rows above are written as row literals
% because that is how a field list reads; `(:)` turns each into the column the
% caller's `sort(names(:))` produces. `isequal` on cells compares SIZE as well
% as contents, so a row here and a column there is a total classification
% failure that no partition test can see -- see the caller's comment.
fieldSets = cell(size(raw));
for k = 1:numel(raw)
    fieldSets{k} = sort(raw{k}(:));
end
end

function block = renameAppBlockFields(block)
% V_delta `app` declares `app_name` and `app_version`; v1 carries the
% same data under `name` and `version`. Apply the rename whenever a
% v1 document ships an `app` block, regardless of its concrete class.
% (7 v1 classes in the 20211116 corpus carry an app block: every
% calculator class plus jrclust_clusters, neuron_extracellular,
% stimulus_presentation, control_stimulus_ids.)
if isfield(block, 'name') && ~isfield(block, 'app_name')
    block.app_name = block.name;
    block = rmfield(block, 'name');
elseif isfield(block, 'name')
    block = rmfield(block, 'name');
end
if isfield(block, 'version') && ~isfield(block, 'app_version')
    block.app_version = block.version;
    block = rmfield(block, 'version');
elseif isfield(block, 'version')
    block = rmfield(block, 'version');
end
end

function out = v1ToVDeltaClassName(name)
% Map v1 class names that drift from V_delta's underscore-separated
% canonical form. v1 occasionally drops the underscore between
% adjacent words in a calc class name (e.g., `contrasttuning_calc`
% instead of `contrast_tuning_calc`); V_delta keeps the
% underscored convention to match the NDI calculator class
% hierarchy (`ndi.calc.vis.contrast_tuning`, etc.). This rename
% pass bridges the two without forcing V_delta names to be
% inconsistent.
table = { ...
    'contrasttuning_calc',      'contrast_tuning_calc'; ...
    'contrastsensitivity_calc', 'contrast_sensitivity_calc'};
for k = 1:size(table, 1)
    if strcmp(name, table{k, 1})
        out = table{k, 2};
        return;
    end
end
out = name;
end

function out = maybeSnakeCase(name, doRename)
if doRename
    out = snakeCase(name);
else
    out = name;
end
end

function out = snakeCase(name)
% Acronym-aware snake_case.
%
% A run of two or more consecutive uppercase letters is treated as a
% single acronym and lowercased without internal underscores
% ('sensitivity_RBNS' -> 'sensitivity_rbns'; 'XMLParser' ->
% 'xml_parser'). The conventional camelCase boundary (lowercase
% followed by uppercase, or acronym followed by mixed-case word) is
% preserved.
%
% Specifically, an uppercase letter at position k inserts a `_`
% before its lowercased form if EITHER:
%   - the previous input char is not uppercase (classic camelCase
%     boundary, e.g., 'data' -> 'T'), OR
%   - the previous input char IS uppercase AND the next input char
%     is lowercase (acronym -> word transition, e.g., 'XML' -> 'P'
%     in 'XMLParser')
% otherwise the uppercase letter is appended without a separator
% (continuing an acronym, or sitting just after an existing `_`).
name = char(name);
n = numel(name);
if n == 0
    out = name;
    return;
end
result = lower(name(1));
for k = 2:n
    c = name(k);
    isUpper = c >= 'A' && c <= 'Z';
    if ~isUpper
        result = [result, c]; %#ok<AGROW>
        continue;
    end
    prev = name(k-1);
    prevUpper = prev >= 'A' && prev <= 'Z';
    nextLower = (k < n) && (name(k+1) >= 'a' && name(k+1) <= 'z');
    needSep = (~prevUpper || (prevUpper && nextLower)) ...
        && result(end) ~= '_';
    if needSep
        result = [result, '_', char(c + ('a' - 'A'))]; %#ok<AGROW>
    else
        result = [result, char(c + ('a' - 'A'))]; %#ok<AGROW>
    end
end
out = result;
end

function out = normaliseSuperclasses(sc, renameClassNames)
% Make sure each superclass entry has a class_name field, deriving it
% from a v1 `definition` path (e.g., $NDIDOCUMENTPATH/data/filter.json
% -> filter) when absent. When RENAMECLASSNAMES is true, snake_case
% any class_name found; when false, leave class_name spellings as-is
% (still derive from `definition` when class_name is absent — that
% derivation is not a rename, just a normalisation). Preserve the
% entry's other fields (`definition`, `class_version`,
% `property_list_name`, ...) so did.database/validate_doc_vs_schema
% can still walk the superclass chain via the path in `definition`.
if nargin < 2
    renameClassNames = true;
end
n = numel(sc);
% Collect each entry with its derived/normalised class_name, then
% rebuild a homogeneous struct array spanning the union of fields.
entries = cell(1, n);
for k = 1:n
    entry = sc(k);
    if isfield(entry, 'class_name') && ~isempty(entry.class_name)
        entry.class_name = maybeSnakeCase(char(entry.class_name), renameClassNames);
    elseif isfield(entry, 'definition') && ~isempty(entry.definition)
        entry.class_name = maybeSnakeCase( ...
            deriveClassNameFromDefinition(entry.definition), renameClassNames);
    else
        entry.class_name = '';
    end
    entries{k} = entry;
end
allFields = {};
for k = 1:n
    allFields = union(allFields, fieldnames(entries{k}), 'stable');
end
out = repmat(buildEmptyEntry(allFields), 1, max(n, 1));
if n == 0
    out = out([]);  % preserve empty when input was empty
    return;
end
for k = 1:n
    e = entries{k};
    for f = 1:numel(allFields)
        fn = allFields{f};
        if isfield(e, fn)
            out(k).(fn) = e.(fn);
        end
    end
end
end

function blank = buildEmptyEntry(fieldList)
blank = struct();
for f = 1:numel(fieldList)
    blank.(fieldList{f}) = [];
end
end

function name = deriveClassNameFromDefinition(definition)
[~, name, ~] = fileparts(char(definition));
end

function postBody = snakeCasePropertyBlocks(postBody)
% Rename top-level property-block keys to snake_case (so v1
% inherited blocks with camelCase names like `imageStack_parameters`
% match V_delta's snake-cased class names), and rename camelCase
% field names inside each block to snake_case. Structural keys
% (document_class, depends_on, file, files) are skipped.
skip = {'document_class', 'depends_on', 'file', 'files'};
topKeys = fieldnames(postBody);
% First pass: snake_case top-level block keys for any property
% block whose value is a struct. (The concrete-class block key has
% already been moved by the caller; this catches inherited blocks
% like the v1 `imageStack_parameters` parent of `imageStack`.)
for k = 1:numel(topKeys)
    key = topKeys{k};
    if any(strcmp(key, skip))
        continue;
    end
    value = postBody.(key);
    if ~isstruct(value) || ~isscalar(value)
        continue;
    end
    snakeKey = snakeCase(key);
    if ~strcmp(snakeKey, key)
        if isfield(postBody, snakeKey)
            % Snake-case form already exists; drop the camel
            % duplicate to avoid clobbering.
            postBody = rmfield(postBody, key);
        else
            postBody.(snakeKey) = value;
            postBody = rmfield(postBody, key);
        end
    end
end
% Second pass: snake_case the field names inside each property
% block.
topKeys = fieldnames(postBody);
for k = 1:numel(topKeys)
    key = topKeys{k};
    if any(strcmp(key, skip))
        continue;
    end
    value = postBody.(key);
    if ~isstruct(value) || ~isscalar(value)
        continue;
    end
    postBody.(key) = snakeCaseBlockFields(value);
end
end

function block = snakeCaseBlockFields(block)
fns = fieldnames(block);
for k = 1:numel(fns)
    fn = fns{k};
    sc = snakeCase(fn);
    if ~strcmp(fn, sc)
        if isfield(block, sc)
            % A snake_case field already exists; keep it and drop the
            % camelCase duplicate to avoid clobbering.
            block = rmfield(block, fn);
        else
            block.(sc) = block.(fn);
            block = rmfield(block, fn);
        end
    end
end
end

function out = renameDependsOnEntries(entries)
%RENAMEDEPENDSONENTRIES Migrate depends_on entries to the V_delta shape.
%
%   V_delta entries carry `name` and `document_id`. Accepts three
%   input shapes and normalises to V_delta:
%     - v1 (V_alpha): {name, id [, version]}        - id -> document_id
%     - old V_delta draft: {name, value}             - value -> document_id
%     - current V_delta: {name, document_id}         - identity
%
%   When multiple legacy keys are present (an in-flight migration
%   that already wrote a value but left the v1 id behind), the
%   precedence is: document_id wins if non-empty, else value,
%   else id. `version` is always dropped (V_delta does not
%   support per-document version branches).
out = entries;

hasId        = isfield(out, 'id');
hasValue     = isfield(out, 'value');
hasDocId     = isfield(out, 'document_id');

if ~hasId && ~hasValue && ~hasDocId
    return;
end

n = numel(out);
docIds = cell(1, n);
for k = 1:n
    if hasDocId && ~isempty(out(k).document_id)
        docIds{k} = out(k).document_id;
    elseif hasValue && ~isempty(out(k).value)
        docIds{k} = out(k).value;
    elseif hasId
        docIds{k} = out(k).id;
    else
        docIds{k} = '';
    end
end

% Drop the legacy keys so the struct array's field schema is
% exactly {name, document_id} after the migration.
if hasId
    out = rmfield(out, 'id');
end
if hasValue
    out = rmfield(out, 'value');
end
if isfield(out, 'version')
    out = rmfield(out, 'version');
end

for k = 1:n
    out(k).document_id = docIds{k};
end
end
