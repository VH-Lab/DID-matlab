function bodies = image_stack(preBody)
%IMAGE_STACK Brainstorm-J migrator: did_v1 image_stack -> a body-backed
%   image_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   image_stack / image_stack_parameters are a pre-Brainstorm-I standalone image
%   document (a file-backed pixel blob + geometry bundle tied to a subject). It
%   is the main did_v1 class exercising J's new storage model (§C.4; 7,007 docs
%   in the JH corpus). Strict J has NO imageseries_observation class (§A.9): the
%   discoverable subject-side view is a plain `subject_observation` data-type
%   leaf whose value is body-backed --
%
%       image_observation   the spine handle: subject_id, a shared time anchor, a
%                           placeholder `subject_statement.variable` (the observed
%                           quantity is the linked ontology label, set by a
%                           second-pass join -- see V_eta_discovery_notes.md; NOT
%                           the file format), the inline image geometry on the
%                           `image` mixin, and `storage_mode: body` (so the
%                           statement carries no sample_time -- the cadence lives
%                           in the body, D1/§A.7). The prose `label` and the
%                           `format_ontology` file-type are dropped as derivable.
%       sampled_body        the DIGITAL frames: datum (kind/dtype/unit/shape) +
%                           sample_time (t0/dt/n) + the carried pixel bytes;
%                           `statement` -> the image_observation it belongs to.
%       session_relative_reference   the ordinal 'during' anchor (a v1 image
%                           stack carries a bare timestamp+clocktype, not a DAQ
%                           epoch -- the same honest fallback the treatment fold
%                           uses).
%
%   1 -> 3. The V_zeta `_i` fold also minted an element / element_epoch /
%   daqreader / ingested-frames quartet; in J the element_epoch + ingested pair
%   collapses into the one `sampled_body`, and the NDI-side imaging element /
%   daqreader infrastructure is left to the NDI second pass (D2: pass-1 migrators
%   populate no individuated element referent).
%
%   NOTE: image_observation and the *_body classes are `draft` in V_eta -- the
%   broader imageseries/dataseries/timeseries_observation branch this supersedes
%   is retired with the NDI-side ingest work, not here.
%
%   STATUS 2026-08-11 (second edit of the day) -- the `document_id` edge is now
%   CARRIED on the fold arm, as `ontology_table_row_id`. NOTHING IN THIS REPO
%   WAS EXECUTED for it: the session that made it has neither MATLAB nor Octave,
%   so neither testMigratorsJ nor any corpus was run locally. Every claim below
%   is read out of NDI `origin/main`, this repo's sources, the did-schema
%   working tree, or `git log`, and the commands are named inline so each one is
%   re-runnable. CI is the gate, and the carry was PROVEN there by mutation,
%   one mutation per run, on throwaway branches:
%
%       CONTROL     31463389188  259d4ca  SUCCESS   (this code, unmutated)
%       MUTATION A  31463723277  305bf07  FAILURE   carry deleted ->
%           2 FAILED of 885 RUN
%           testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot
%           testImageStackDocumentIdReferentSurvivesTheBatch
%       MUTATION B  31463724722  b03a411  FAILURE   carry made UNCONDITIONAL
%           (a blank edge when the source has none) ->
%           2 FAILED of 885 RUN
%           testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank
%           testImageStackBlankDocumentIdIsOmittedNotCarriedThrough
%
%   Both directions are covered, which is the point of two mutations rather
%   than one: A proves the tests see the carry, B proves they see the
%   CONDITION. The throwaway branches are claude/v-eta-imgstack-carry-mut-a
%   and -mut-b in BOTH repos (did-schema needs a same-named branch because
%   test-migrators-quick.yml checks the schema set out by ref name); they are
%   not deletable with these credentials and want cleaning up by hand.
%
%   ---------------------------------------------------------------------
%   THE `document_id` EDGE WAS DROPPED ON THE FOLD ARM. IT IS NOT ANY MORE.
%   ---------------------------------------------------------------------
%   The original header said, verbatim: "The legacy `document_id` dependency (a
%   corpus reference-integrity orphan) is dropped." THE REFERENT RESOLVES TODAY.
%   Three facts, each read from a writer rather than inferred from a search that
%   came back empty:
%
%   1. THE REFERENT IS AN `ontologyTableRow` DOCUMENT, not a loose id.
%      +setup/+conv/+haley/doImport.m:233-237 builds the behaviour-plate rows
%      with `tableDocMaker.table2ontologyTableRowDocs`, which constructs
%      `ndi.document('ontologyTableRow', ...)` (tableDocMaker.m:221), and takes
%      their `.id` into `plate_id`; the four subject-carrying imageStack sites
%      (:430, :464, :480, :499) set `document_id` to exactly that id. For the
%      behaviour arm that row IS the plate, carrying its OD600 / CFU / lawn
%      volume / arena covariates (behaviorPlateVariables, doImport.m:101-106).
%
%   2. AN `ontologyTableRow` NEVER CARRIES A `subject_id`. `tableDocMaker` has
%      exactly one `set_dependency_value` call in the whole file and it is
%      `document_id` (tableDocMaker.m:231) -- and not one of doImport.m's NINE
%      `table2ontologyTableRowDocs` calls (200, 234, 295, 351, 533, 688, 741,
%      757, 855) even passes `dependencyVariable`, the option that would reach
%      it. So the guard in +migrators_j/ontology_table_row.m --
%      `isempty(resolvedSubject(preBody))` -- fires and the row PASSES THROUGH
%      (`bodies = {preBody}`) with `base.id` untouched.
%
%   3. EVERY OTHER PATH OF THAT MIGRATOR PRESERVES THE ID TOO. All five of its
%      return points end in `preserveSourceId` or in `{preBody}`, so whichever
%      table a row belongs to -- encounter map, patch-geometry map, per-column
%      fan-out, or either passthrough -- the source id survives on exactly one
%      emitted body. `testOntologyTableRowPreservesSourceIdOnFirstBody` and
%      `testEncounterMapPreservesSourceId` already gate that.
%
%   TIMELINE, which is the whole story:
%
%       $ git log -1 --format='%ad %h %s' --date=short 1207c10
%       2026-07-10 1207c10 Add J image_stack migrator: body-backed ...
%       $ git log -1 --format='%ad %h %s' --date=short ef58c15
%       2026-07-29 ef58c15 ontology_table_row: preserve the source id on ...
%
%   The justification was written on 2026-07-10 and the mechanism that
%   invalidates it landed on 2026-07-29. It was true when written and has been
%   stale for the nineteen days since. It is NOT re-derivable from a corpus run:
%   the edge is dropped, so it can neither orphan nor be counted, and a green
%   orphan gate says nothing about it either way.
%
%   WHY WAS THE EDGE STILL DROPPED AFTER THAT? BECAUSE THERE WAS NOWHERE TO PUT
%   IT. `image_observation` and its seven ancestors -- subject_observation,
%   subject_interaction, subject_statement, base, image, data_type, data --
%   declared SIX `depends_on` slots between them: subject_id, time_reference_#,
%   instrument_id, software_id, method_parameters_id, derived_from_#. Not one
%   of them means "the metadata row that gives this image its data context".
%   `derived_from_#` is the near miss and it is wrong twice over: it is typed
%   to `subject_statement` (the row migrates to an `ontology_table_row`), and
%   it asserts COMPUTATION, which this is not.
%
%   THE SLOT LANDED (did-schema 6cf31f2, 2026-08-11), so the carry is built:
%
%       $ python3 -c "import json;print(json.load(open( \
%           'schemas/V_eta/draft/image_observation.json'))['depends_on'])"
%       [{'name': 'ontology_table_row_id', 'mustBeNonEmpty': False,
%         'must_refer_to_document_class': 'ontology_table_row', ...}]
%
%   The name is not invented: `stable/ontology_image.json` already declared
%   exactly that edge for the identical relationship.
%
%   THE CARRY IS CONDITIONAL, and that is the load-bearing part. There are
%   EIGHT `ndi.document('imageStack'...)` sites on NDI origin/main, not seven --
%   `git grep -n "ndi\.document('imageStack'" origin/main -- '*.m'` returns
%   doImport.m:421,461,477,496,789,811,827 AND +setup/+conv/+babu/import.m:474.
%   THREE populations, not two, and the fold arm sees TWO of them:
%
%       haley behaviour  doImport.m 421/461/477/496  document_id AND subject_id
%                        -> FOLD ARM, edge present, carried.
%       haley E. coli    doImport.m 789/811/827      document_id only
%                        -> GUARD ARM, passes through intact, keeps the edge
%                           under its did_v1 name (the tombstone declares it).
%       babu             import.m:474                subject_id only, NO
%                        document_id (import.m:478-479) -> FOLD ARM, nothing
%                        to carry, and the ENTRY IS OMITTED rather than
%                        emitted blank.
%
%   OMITTED, NOT BLANK. A blank edge is the invented-empty-edge pattern that
%   put 7,233 documents in the census, and the RequiredDependencies gate is
%   armed. `dependencyValue` returns '' both when the edge is absent and when
%   it is present-and-empty, so both shapes take the same (omitting) branch.
%
%   THE REFERENT IS TYPED CORRECTLY, both fold-arm populations checked against
%   the writer: `dataTable.plate_id{p}` (behaviour, doImport.m:430) is the id
%   of an `ontologyTableRow` built by `table2ontologyTableRowDocs` at
%   doImport.m:234-236, so the schema's `must_refer_to_document_class:
%   ontology_table_row` holds. (The E. coli sites name `imageTable.image_id`,
%   doImport.m:757-759 -- also an ontologyTableRow -- but they never reach here.)
%
%   THE ORPHAN RISK, STATED PLAINLY. In a FULL migration the referent is in the
%   batch: fact 2 above shows the row passes through with its id, and the
%   already-live guard-arm `document_id` edges are the same shape and the same
%   corpus (JH) at 0 orphans. In a DISCOVERY-MODE SUBSET the referent need not
%   be present, and +did2/+validate/references.m reports an orphan for an edge
%   naming a document that is neither in the batch nor in the database --
%   jSessionAnchor's note about exactly this is CORRECT and is not being
%   overridden here. That risk is accepted for the same reason it is accepted
%   for `subject_id` and for the guard arm's own `document_id`: the alternative
%   is losing the edge, and a subset batch orphans on every edge it does not
%   contain, not just this one.
%
%   testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot pins the
%   carry (it is the INVERSION of testImageStackFoldDropsDocumentIdForWantOfASlot,
%   which asserted the drop and could not be left standing).
%   testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank pins the babu
%   population. testImageStackDocumentIdReferentSurvivesTheBatch now runs the
%   REAL emitted edge through did2.validate.references instead of a probe.

arguments
    preBody (1,1) struct
end

TV = 'V_eta';
params = getBlock(preBody, 'image_stack_parameters');

subjectId = dependencyValue(preBody, 'subject_id');

% ---------------------------------------------------------------------
% THE GUARD: NO SUBJECT => NO OBSERVATION. Pass the document through.
% ---------------------------------------------------------------------
% NDI's own writer leaves this edge empty. Of the seven
% `ndi.document('imageStack'...)` sites in +setup/+conv/+haley/doImport.m, four
% set `subject_id` from a subjectGroup_id (421, 461, 477, 496) and THREE set
% only `document_id` (789, 811, 827 -- the image / mask / closest-patch loop).
% So those documents genuinely have no subject, and this migrator used to copy
% that emptiness into a REQUIRED edge: 4,563 JH documents became
% `image_observation`s about nobody, invisible to every gate because
% +did2/+validate/references.m:90 skips empty edges.
%
% Passing through is only safe because `image_stack` and
% `image_stack_parameters` were taken BACK OUT of _DELETE_PHASE8 for exactly
% this, and restated from the NDI template so the passthrough validates. Do not
% re-delete them without re-checking this branch -- deleting a tombstone ahead
% of its migrator is what put 2,484 corpus-B documents in quarantine.
%
% THE SUBJECT IS **NOT** RECOVERABLE. This comment said the opposite until
% 2026-08-10 and sketched the join to do it; following that sketch would have
% INVENTED subjects rather than recovered them. The correction, with evidence:
%
% The subject-carrying imageStacks and the subject-less ones are in DIFFERENT
% SESSIONS. `doImport.m:46-49` builds two:
%
%     SessionRef = {'haley_2025_Celegans'; 'haley_2025_Ecoli'};
%
% Sites 421/461/477/496 (which DO set subject_id) are Step 5, under
% `session = sessions{1}`. Sites 789/811/827 (which do not) are Step 8, which
% opens with `session = sessions{2}` at line 694. The LAST mention of a subject
% anywhere in that 881-line file is line 689 -- two lines before Step 8 starts.
% The E. coli session mints no subject, no subject_group and no subject_id at
% all, because the imaged object is a bacterial lawn on an agar plate and the
% source never asserts a subject for it.
%
% So "the OTHER imageStacks" are C. elegans behaviour plates in another
% session. Joining to them does not recover a subject; it attaches worms to
% bacteria. And the join is not merely empty, it is ACTIVELY UNSAFE, because
% the two plateID string spaces collide:
%
%     doImport.m:166 (celegans)  plateID = num2str(plateNum + expType*1000,'%.4i')
%     doImport.m:729 (ecoli)     plateID = num2str(plateNum,'%.4i')
%
% With expType == 0 both emit '0001', '0002', ... over the same range, and only
% `base.session_id` tells them apart. A plateID join that forgot to scope by
% session would silently mis-attribute every one of them.
%
% `ndi.migrate.internal.ontologyLabelSubjects.m:59-63` had already recorded
% this ("the images are of bacterial patches on plates and that session has no
% subject"); this file contradicted it, and this file was wrong.
%
% WHAT WOULD ACTUALLY WORK is a modelling call, not a migration operation:
% mint a subject for the E. coli PLATE. Its row already carries plateID for
% identity, a `bacteriaStrain` edge to an openMINDS Strain document
% (doImport.m:734), and OD600/CFU/volume covariates. Then the chain
% image -> image row -> plateID -> plate row -> plate-subject is traversable
% ENTIRELY WITHIN session 2, with no cross-session join. Until the team makes
% that call, the guarded passthrough below is the whole answer and loses
% nothing.
if isempty(subjectId)
    bodies = {preBody};
    return;
end

sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
stackId   = baseField(preBody, 'id', did.ido.unique_id());

% format_ontology is the FILE TYPE (an NCIT file-format CURIE like TIFF / MP4).
% It is NOT the observed quantity, and it is NOT stored: a file's container format
% is derivable from the bytes themselves (and the short form already rides on
% image.image_format), so an ontology term for it would be a redundant projection.
dataType = getCharField(params, 'data_type');
dimOrder = firstNonEmpty(getCharField(params, 'dimension_order'), 'YXCZT');
dimSize  = numVec(getField(params, 'dimension_size'));
[clockName, t0] = clockFromParams(params);
numFrames = frameCount(dimOrder, dimSize);

anchorId = did.ido.unique_id();

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
% PASS-1 HANDLE, NOT AN UNMIGRATED CLASS. The signed model retires this class in
% favour of `relative_reference`, but the same plan makes the change impossible
% here: `relative_to` is REQUIRED and is not fillable in pass 1 (this body holds
% base.session_id; the edge needs the session DOCUMENT's base.id). Emitting the
% new class with an empty required edge would be ~106k husks that validate clean.
% did2.convert.resolveSessionAnchors folds it in a batch pass, id PRESERVED. Full
% reasoning in +migrators_j/private/jSessionAnchor.m; the seam is pinned by
% tests/+did2/+unittest/testSessionAnchorEmitterContract.m.
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});   % session rides on base
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable, body-backed image_observation ------------------------
obs = struct();
obs.document_class = classBlock('image_observation', {'subject_observation', 'image'}, TV);
% THE EDGE SET IS REBUILT FROM SCRATCH HERE, so every edge the source carried
% has to be carried DELIBERATELY -- that rebuild is what silently lost the
% source `document_id` between 2026-07-10 and today. These two are
% unconditional: the guard above guarantees a subject, and the anchor is minted
% a few lines up.
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];

% ---- the source `document_id` -> `ontology_table_row_id` --------------------
% CONDITIONAL BY CONSTRUCTION. Two of NDI's three imageStack populations reach
% this arm and only one of them has the edge: haley behaviour sets BOTH
% document_id and subject_id (doImport.m:429-432), babu sets subject_id alone
% (import.m:478-479). When it is absent the ENTRY IS OMITTED -- never emitted
% blank, because a declared-but-empty edge is the invented-empty-edge pattern
% and the RequiredDependencies gate is armed. `dependencyValue` returns '' for
% "absent" AND for "present but empty", so both land on the omit branch.
%
% The referent is an `ontologyTableRow` document (doImport.m:234-236 builds the
% behaviour plate rows through table2ontologyTableRowDocs and :430 takes their
% id), which matches the slot's must_refer_to_document_class. It survives
% migration with `base.id` untouched -- see fact 3 in the header -- so in a full
% migration the edge resolves. See the header for the discovery-mode caveat.
tableRowId = dependencyValue(preBody, 'document_id');
if ~isempty(tableRowId)
    obs.depends_on(end+1) = struct('name', 'ontology_table_row_id', ...
        'value', tableRowId);
end
% The source `label` is NOT carried: it is a templated prose *definition* of the
% image type (e.g. "A video recording capturing the behavior of C. elegans...")
% -- i.e. the definition of the modality ontology term that already rides on
% subject_statement.variable (from format_ontology). Storing it per-document
% would duplicate the ontology term's definition; it is reconstructable as a
% projection. base.name is a short generic name.
obs.base = struct('id', stackId, 'session_id', sessionId, ...
    'name', 'migrated_image', 'datestamp', datestamp);
% storage_mode: body -> the value is in the sampled_body; the statement carries
% no sample_time (the body owns the cadence).
% variable is the OBSERVED QUANTITY. On the source that is the linked ontology
% label (via the image's document_id), not the file format -- resolving it is a
% second-pass cross-document join (discovery; see V_eta_discovery_notes.md). A
% non-empty placeholder is emitted here so the statement validates; the second
% pass replaces it with the label's ontology term.
% `datum_type` on the STATEMENT (signed sec.5), normalised. NOTE the source
% here is `firstNonEmpty(dataType, 'uint16')` a few lines up -- a silent default
% the plan calls out by name -- so a document with no recorded type reports
% source 'uint16' rather than nothing. That defect is untouched here, and now at
% least the SOURCE spelling reaches the document so the corpus can be queried
% for how often the default fired.
[datumType, sourceDatumType] = jDatumType(dataType);
obs.subject_statement = struct('variable', struct('node', '', 'name', 'image'), ...
    'datum_type', datumType, ...
    'source_datum_type', sourceDatumType, ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
% The raster CELL: one `value` slot holding the pixels plus the descriptors needed to
% interpret them (image now matches the single-`value` convention every other data_type
% follows -- the descriptors ride inside the cell, as `source_unit` does beside
% `source_value` in a dimensioned cell). R6 decision 4 is unchanged: dtype is NOT
% recoverable from an inline matrix, so it is always explicit -- just one level in.
% dtype from the v1 data_type; axes from dimension_order/size/scale (recovers the N-D
% calibration the old x/y_resolution lost); pixels empty (they live in the sampled_body,
% storage_mode:body).
% NOTE: wrap the axes struct-array in a 1x1 cell so struct() ASSIGNS it as a field (a
% non-scalar struct value would otherwise distribute the cell into an array), and assign
% the cell onto obs.image in its own statement for the same reason.
imageCell = struct( ...
    'pixels', [], ...
    'dtype', firstNonEmpty(dataType, 'uint16'), ...
    'axes', {imageAxes(dimOrder, dimSize, params)}, ...
    'color_model', otTerm(''), ...
    'channels', {{}});
obs.image = struct();
obs.image.value = imageCell;

% ---- the sampled_body holding the digital frames ----------------------------
body = jSampledBody(stackId, sessionId, datestamp, 'migrated_image_frames', ...
    struct('regular', true, ...
        't0', durationComposite(t0), 'dt', durationComposite(frameDt(clockName)), ...
        'n', numFrames));
% carry the pixel bytes over verbatim as the body's frames (universal renames
% leave file/files untouched; this doc owns the digital bytes now).
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end

bodies = {obs, body, anchor};
end

% ===================== geometry / clock builders ===========================

function r = axisResolution(params, axisChar)
%AXISRESOLUTION The scale (spacing) of the named spatial axis, 0 if absent.
r = 0.0;
order = getCharField(params, 'dimension_order');
scale = numVec(getField(params, 'dimension_scale'));
idx = strfind(upper(order), upper(axisChar));
if ~isempty(idx) && idx(1) <= numel(scale)
    r = scale(idx(1));
end
end

function [clockName, t0] = clockFromParams(params)
clockName = getCharField(params, 'clocktype');
if isempty(clockName); clockName = 'no_time'; end
t0 = 0.0;
ts = getField(params, 'timestamp');
if ~isempty(ts) && isnumeric(ts) && isscalar(ts); t0 = double(ts); end
end

function dt = frameDt(clockName)
%FRAMEDT A unit frame spacing for a clocked stack; 0 for a clockless still.
if strcmp(clockName, 'no_time'); dt = 0.0; else; dt = 1.0; end
end

function n = frameCount(dimOrder, dimSize)
n = 1;
for i = 1:min(numel(dimOrder), numel(dimSize))
    c = upper(dimOrder(i));
    if (c == 'T' || c == 'Z') && dimSize(i) > 0
        n = n * dimSize(i);
    end
end
end

% ===================== small helpers =======================================

function dc = classBlock(name, supers, tv)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', tv);
end

function c = durationComposite(seconds)
c = struct('source_unit', 's', 'source_value', double(seconds), 'approximate', false);
end

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(bodyStruct, name)
v = [];
if isfield(bodyStruct, name); v = bodyStruct.(name); end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v = numVec(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); return; end
if ischar(x) || (isstring(x) && isscalar(x))
    parts = strsplit(char(x), {',', ' '});
    for k = 1:numel(parts)
        nn = str2double(parts{k});
        if ~isnan(nn); v(end+1) = nn; end %#ok<AGROW>
    end
end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            elseif isfield(d, 'id') && ~isempty(d.id)
                v = char(d.id);
            end
            return;
        end
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

function ax = imageAxes(dimOrder, dimSize, params)
%IMAGEAXES One signed axis entry per dimension, from the v1 N-D calibration.
%
%   REWRITTEN 2026-08-14 FOR THE SIGNED AXIS ENTRY (DID-schema TEAM-SIGN-OFF
%   [data_body] + AMENDMENT 1, addendum sec.5 "ALL THREE AXES DECLARATIONS FOLD
%   INTO THE ONE ENTRY"). The old shape {name, length, spacing, unit} no longer
%   exists. It was the WEAKEST of the three that folded: no regularity flag at
%   all, so it declared a `spacing` with no way to say whether spacing was even
%   meaningful, and no `origin`, so it could not say where an axis starts.
%
%   LOCKSTEP. `variable` and `n` are mustBeNonEmpty in the new entry, so a cell
%   written in the old shape quarantines outright. This is the only live writer
%   of `image.value.axes` in the V_eta path.
%
%   THE MAPPING:
%       name    -> variable.name   the v1 label, VERBATIM (see below)
%       length  -> n
%       spacing -> spacing.value + .source_value
%       unit    -> source_unit     (per-axis now, rather than one shared value)
%
%   THE LABEL IS CARRIED VERBATIM AND IS NOT TRANSLATED, deliberately. It would
%   read better as `space_y`/`channel`/`time` -- the old `kind` field on the
%   OTHER two axes declarations enumerated exactly that vocabulary -- but this
%   declaration never had a `kind`, so translating would be INVENTING the
%   semantic rather than moving it. 'Z' is the case that decides it: depth in a
%   confocal stack, section index in a serial reconstruction, and v1 does not
%   say which. A wrong map is a silent semantic error; a bare label is merely
%   thin. Binding these to real terms is #32, which also fills `node` -- empty
%   here for the same reason it is empty everywhere else today.
%
%   TWO ARMS, BECAUSE AN UNCALIBRATED AXIS IS NOT A CALIBRATED ONE WITH ZERO
%   SPACING. The old code emitted `spacing: 0` when v1 recorded no resolution,
%   which says every pixel sits at the same position -- false, and now sayable
%   as what it is:
%       resolution known -> a PHYSICAL axis: origin 0 (the raster's own corner,
%                           which is what a per-pixel spacing is measured from),
%                           spacing = the v1 scale, source_unit = the v1 unit.
%       no resolution    -> an INDEX axis: origin 1, spacing 1, no unit. The
%                           same convention jNgridBody uses for MATLAB's default
%                           1-based index vector.
%   Both arms are `regular`, so `origin` is always populated -- the entry
%   requires it exactly when regular, and both arms are.
%
%   `origin` IS THE ONE FIELD v1 DOES NOT SUPPLY, AND THE CONVENTION ABOVE IS
%   STATED RATHER THAN DERIVED. v1 records extent and scale, never an anchor,
%   and the entry requires an origin whenever regular, so something must be
%   written. 0-at-the-corner for a calibrated axis and 1 for an index axis are
%   the conventional readings, not measurements -- worth a team look if a
%   dataset ever anchors a stack somewhere else.
%
%   NO UNIT CONVERSION IS PERFORMED, and `unit` is left blank while
%   `source_unit` carries the v1 spelling. That follows every other dimensioned
%   emission in this package -- treatment.m writes source_unit 'celsius',
%   virus_injection.m writes 'dilution', jMeasurementFold writes '' -- none of
%   which converts. Canonicalising 'micrometer' to metres would need a
%   conversion table this package does not have, and a wrong factor is a silent
%   1e6 error.
%
%   `dimension_scale_units` IS A PER-AXIS LIST AND IS NOW SPLIT. THE OLD CODE
%   ASSIGNED THE WHOLE STRING TO EVERY AXIS. v1 writes it comma-separated,
%   positionally aligned with `dimension_order` -- 'YXT' pairs with
%   'micrometer,micrometer,second' -- so the old per-axis `unit` field was filled
%   with 'micrometer,micrometer,second' on all three axes, saying the time axis
%   is measured in micrometres AND seconds AND micrometres. The old shape had
%   the slot and filled it wrongly; splitting is part of the fold rather than a
%   separate repair, because the entry that made `source_unit` per-axis is what
%   makes the joined string obviously wrong.
%
%   A SHORT LIST IS NOT PADDED AND A LONG ONE IS NOT TRUNCATED-WITH-A-GUESS: an
%   axis past the end of the list gets '', which is what an axis with no
%   recorded unit already gets.
ax = struct('variable', {}, 'n', {}, 'regular', {}, 'origin', {}, ...
    'spacing', {}, 'source_unit', {});
unitList = splitScaleUnits(getCharField(params, 'dimension_scale_units'));
n = numel(dimOrder);
for k = 1:n
    nm = dimOrder(k);
    len = 0;
    if k <= numel(dimSize); len = dimSize(k); end
    sp = axisResolution(params, nm);
    axisUnit = '';
    if k <= numel(unitList); axisUnit = unitList{k}; end
    if sp ~= 0
        originValue  = 0;      % the raster's own corner
        spacingValue = sp;
    else
        originValue  = 1;      % MATLAB's default index vector
        spacingValue = 1;
        axisUnit     = '';     % an index axis has no unit
    end
    ax(end+1) = struct( ...
        'variable',    jOntologyTerm('', nm), ...
        'n',           len, ...
        'regular',     true, ...
        'origin',      struct('value', originValue, 'source_value', originValue), ...
        'spacing',     struct('value', spacingValue, 'source_value', spacingValue), ...
        'source_unit', axisUnit); %#ok<AGROW>
end
end

function u = splitScaleUnits(raw)
%SPLITSCALEUNITS v1's comma-separated per-axis unit list -> a cell of char.
%   '' yields an empty cell, so every axis falls through to ''. Whitespace
%   around a separator is trimmed: the field is hand-entered in the converters,
%   and 'micrometer, second' must not become ' second'.
u = {};
if isempty(raw); return; end
parts = strsplit(char(raw), ',');
u = cell(1, numel(parts));
for k = 1:numel(parts)
    u{k} = strtrim(parts{k});
end
end
