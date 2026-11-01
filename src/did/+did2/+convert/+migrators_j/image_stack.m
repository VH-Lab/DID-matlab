function bodies = image_stack(preBody)
%IMAGE_STACK Brainstorm-J migrator: did_v1 image_stack -> a body-backed
%   `observation` with value kind `intensity` (a mask or label map is carried
%   as v1) + a sampled_body (+ the shared session
%   anchor).
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
%                           in the body, D1/§A.7). The `format_ontology`
%                           file-type (an `image`'s `format`) and an `image`'s
%                           `compression` go on the body's `format` and
%                           `compression` ([image file details placed], Jess
%                           Haley, 2026-10-26; dropped as derivable before).
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
%
%   ---------------------------------------------------------------------
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27)
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md). A v1 `imageStack` reaches this migrator
%   exactly as NDI wrote it (imageStack.json + imageStack_parameters.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8): the `imageStack` and
%   `imageStack_parameters` blocks, `formatOntology`, edges in v1's `value`
%   key. No universalRenames and no superclass migrator run on it, so:
%     - what universalRenames would have DISCARDED (a depends_on `version` or
%       second id, an `ndi_document` beside `base`, `formatOntology` beside a
%       different `format_ontology`, an `imageStack` / `imageStack_parameters`
%       block beside a different snake_case twin) carries the document,
%       carry-100, as the renamed path carried it ([renames carry is
%       temporary]);
%     - the superclass migrator's work (+super/image_stack_parameters: a
%       non-scalar, non-empty char or non-numeric `timestamp` is refused) is
%       done here by calling it on the parameters block, so the same documents
%       quarantine with the same identifiers; its other job, stripping an
%       empty `timestamp` so a passthrough validates under the `image_stack`
%       tombstone, has no raw counterpart (a raw passthrough is the untouched v1
%       source, which V_eta keeps no schema for under the name `imageStack`);
%     - identity is read through jRawBody (a legacy-only `ndi_document`);
%     - every carry or passthrough returns PREBODY, the untouched v1 source.
%   A v1 `image` (did2.convert.migrators_j.image hands it here) reads RAW v1
%   too since 2026-10-30 (rawV1Classes): the same checks run on it, with its
%   own blocks (`image`, `imageStack_parameters`). A body already spelled the
%   renamed way (class `image_stack`, or an `image` with only an
%   `image_stack_parameters` block, as the deleted rename pass wrote them) may
%   still arrive; every read below takes either spelling, and the raw checks
%   find nothing to carry on a renamed body. Carry notes keep the class names
%   they had ('image_stack', 'image'). The round trips are
%   did2.convert.roundtrip.imageStack and did2.convert.roundtrip.image
%   (testRawV1RoundTripImage).

arguments
    preBody (1,1) struct
end

srcClass = classNameOf(preBody);
% a v1 `imageStack` or `image` is read raw (did2.convert.rawV1Classes); the
% checks below find nothing on an `image` that arrives renamed
isRaw = any(strcmp(srcClass, {'imageStack', 'image'}));
noteClass = 'image_stack';
if strcmp(srcClass, 'image')
    noteClass = 'image';
end
if isRaw
    if strcmp(srcClass, 'image')
        % the `image` block's fields (label, format, compression) are snake_case
        % already: no twin for the pass to discard there
        collision = jResponseRenameCollisions(preBody, cell(0, 3));
        collision = [collision, blockTwins(preBody, ...
            {'imageStack_parameters', 'image_stack_parameters'})];
    else
        collision = jResponseRenameCollisions(preBody, ...
            {'imageStack', 'formatOntology', 'format_ontology'});
        collision = [collision, blockTwins(preBody, ...
            {'imageStack', 'image_stack'; 'imageStack_parameters', 'image_stack_parameters'})];
    end
    if ~isempty(collision)
        % carry-register: carry-100 (a rename-era clash: [rename clashes are malformed])
        did2.convert.reportNote('carried_as_v1', noteClass, ...
            baseField(preBody, 'id', ''), ['[carry-100] malformed: outside the NDI template, unplaced: ' ...
            strjoin(collision, ', ')]);
        bodies = {preBody};
        return;
    end
    % the superclass migrator's refusals, on the raw block (see the header)
    did2.convert.migrators_j.super.image_stack_parameters(struct( ...
        'image_stack_parameters', getBlockAny(preBody, ...
        {'imageStack_parameters', 'image_stack_parameters'})));
end
params = getBlockAny(preBody, {'imageStack_parameters', 'image_stack_parameters'});
stackBlk = getBlockAny(preBody, {'imageStack', 'image_stack'});
% [image collection carried until a writer] (Decided by Jess Haley,
% 2026-10-30, did-schema V_eta_go_forward_class_audit.md): NDI has an
% `imageCollection` template but no writer of `imageCollection_id` at the
% locked NDI main, "so a v1 image with a non-empty `imageCollection_id` is
% carried whole as v1, `malformed` (input no writer produces), and no group is
% designed." It narrows [image file details placed]'s `member_of` part (which
% an awaiting_home register row, cited here before). Checked before the subject, so
% a subject-less image naming a collection is noted too, not passed through
% silently. A v1 `image` (migrators_j.image routes it here) and a v1
% imageStack both carry it.
if ~isempty(firstNonEmpty(dependencyValue(preBody, 'imageCollection_id'), ...
        dependencyValue(preBody, 'image_collection_id')))
    % carry-register: carry-153
    did2.convert.reportNote('carried_as_v1', noteClass, ...
        baseField(preBody, 'id', ''), ['[carry-153] malformed: depends_on ' ...
        'imageCollection_id, which no NDI writer writes ' ...
        '([image collection carried until a writer])']);
    bodies = {preBody};
    return;
end
subjectId = dependencyValue(preBody, 'subject_id');
if isempty(subjectId)
    bodies = {preBody};
    return;
end
% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): #88 gives the
% observation no edge for the v1 `document_id` (the ontologyTableRow this image
% belongs to), so a stack that names one cannot be placed whole. It is carried
% whole as v1, for the dataset's map, rather than folded without the edge.
% [image stack link needs mapping] (Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): for a v1 imageStack the edge is carried
% `needs_mapping`: what it means varies by writer, so each dataset says what it
% means (carry-052). A v1 `image` naming one stays `unplaced` (carry-067): the
% decision covers imageStack only.
tableRowId = dependencyValue(preBody, 'document_id');
if ~isempty(tableRowId)
    why = 'unplaced: depends_on document_id';
    if ~strcmp(classNameOf(preBody), 'image')
        why = ['needs_mapping: depends_on document_id (what the edge means ' ...
            'is decided by each dataset)'];
    end
    % carry-register: carry-052 (imageStack), carry-067 (a v1 image)
    did2.convert.reportNote('carried_as_v1', 'image_stack', ...
        baseField(preBody, 'id', ''), [carryRowOf(preBody, '[carry-067] ', '[carry-052] ') ...
        why]);
    bodies = {preBody};
    return;
end
% [image file details placed] (Jess Haley, 2026-10-26): the four details a v1
% image / imageStack dropped. `format` and `compression` go on the body (below).
% The `imageCollection_id` edge is carried above (carry-153). `data_limits` is left unwritten when it is its data type's range
% ([intmin intmax], [0 1] for logical: recoverable from the datum type,
% [lossless means round trip]); a range that differs becomes a body condition
% with variable EMPTY:0000402 "value range" ([census terms] T3), its value the
% [minimum maximum] pair.
unplaced = {};
limits = getField(params, 'data_limits');
bodyConditions = [];
if ~isempty(limits) && ~isTypeRange(limits, getCharField(params, 'data_type'))
    if isnumeric(limits) && numel(limits) == 2 && all(isfinite(double(limits(:))))
        bodyConditions = did2.build.condition( ...
            did2.convert.registeredTerm('EMPTY:0000402', 'value range'), ...
            'Matrix', double(limits(:)'));
    else
        unplaced{end+1} = [carryRowOf(preBody, '[carry-011] ', '[carry-012] ') ...
            'image_stack_parameters.data_limits (not a [minimum maximum] pair)'];
    end
end
if ~isempty(unplaced)
    % carry-register: carry-011 carry-012 (the items above)
    did2.convert.reportNote('carried_as_v1', noteClass, ...
        baseField(preBody, 'id', ''), ['unplaced: ' strjoin(unplaced, ', ')]);
    bodies = {preBody};
    return;
end

% ---- did-schema #88: what the raster IS (#73 review item 51, decided
% 2026-09-25): "a raster goes by what its pixels measure, keyed [y, x,
% (channel)]: JH's microscopy images -> intensity_observation, its masks /
% closest-patch maps -> label_calculation, chosen from the document's label".
% BUILT 2026-10-22: a mask or a map is a `calculation` with the `label`
% value kind (its pixels are identifiers local to the image), body-backed by
% the same sampled_body and keys as an intensity image. NDI's Haley writer
% (+setup/+conv/+haley/doImport.m, the arena and bacteria masks) records no
% software and no input, so the calculation carries neither: did-schema
% fd83a6c makes calculation.software_id optional ([calculation-software-
% optional], Proposed (not decided), built ahead of decision at Jess Haley's
% instruction) -- nothing is invented. An `app` block, if a document ever has
% one, is carried as the software.
%
% 2026-10-22, Decided by Jess Haley [migrated masks are logical] (did-schema
% V_eta_go_forward_class_audit.md): "a migrated v1 imageStack mask is a
% calculation with the `logical` value kind (one per mask, 1 = inside), its
% variable the region it marks, as the native Haley import writes masks ...;
% no method, because none is recorded. Replaces the label value kind and the
% 'pixel label' variable."
%
% THE REGION WORDS LEFT (Decided by Jess Haley, 2026-10-26 [dataset-specific
% logic leaves the generic migration], [one correct reading]): the region a mask
% marks was read from Haley label words ("arena", "bacteria" / "lawn",
% "reference mark") and named as the Haley V2 import names it
% (ndi.setup.conv.haley.geometryDocuments). No rule that holds for every dataset
% reads a region from a label, so a mask is carried whole as v1, naming its V2
% home and what decides it. A MAP (each pixel an identifier, EMPTY:0000132) is
% recognised by label words too, so it is carried the same way ([one-reading
% quick answers] (Q3), Jess Haley, 2026-10-26: "mask or map detection" chosen
% from label words carries as needs_mapping).
%
% [Haley mask words leave the generic stage] (Decided by Jess Haley, 2026-10-30,
% did-schema V_eta_go_forward_class_audit.md): the region words ("arena",
% "bacteria" / "lawn", "reference mark") belong to the Haley V2 import's map;
% "the generic stage carries a mask whose region it cannot read". The generic
% stage keeps mask-vs-map detection (generic: the label says "mask", or says
% each pixel is an identifier / a label map) and reads no region, so a label
% that reads as a MASK (and not as a map) is carried citing carry-154; a map,
% or a label reading as both, is carried citing carry-025 as before.
label = getCharField(stackBlk, 'label');
if isMaskOrMap(label)
    if isMask(label) && ~isMap(label)
        why = ['needs_mapping: a mask whose region the generic stage cannot ' ...
            'read (calculation, logical, of the region it marks) ' ...
            '([Haley mask words leave the generic stage])'];
        tag = carryRowOf(preBody, '', '[carry-154] ');
    else
        why = ['needs_mapping: calculation (logical ' ...
            'mask | label map) or observation (intensity); decided by what the ' ...
            'image''s pixels are, in its dataset'];
        tag = carryRowOf(preBody, '', '[carry-025] ');
    end
    % carry-register: carry-154 carry-025 (imageStack; the register has no
    %   row for image)
    did2.convert.reportNote('carried_as_v1', noteClass, ...
        baseField(preBody, 'id', ''), [tag why]);
    bodies = {preBody};
    return;
end

% the identity a raw body states, a legacy-only `ndi_document` read into `base`
% (jRawBody; universalRenames' wholesale move did this on the renamed path)
src = preBody;
if isRaw
    src = jRawBody(preBody, srcClass);
end
stackId   = baseField(src, 'id', did.ido.unique_id());
dataType = getCharField(params, 'data_type');
% [no invented values] (Jess Haley, 2026-10-25): a dimension order or data type
% the source does not state is not assumed. No order means no honest key, so
% the document passes through as v1; no data type leaves datum_type empty
% (optional in the schema: "not stated").
dimOrder = getCharField(params, 'dimension_order');
dimSize  = numVec(getField(params, 'dimension_size'));
if isempty(dimOrder) || numel(dimSize) < numel(dimOrder)
    bodies = {preBody};   % no extent for a dimension: no honest key
    return;
end
% [axis letters derive from labels] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): `dimension_order` is not stored;
% the round trip derives each letter from the dimension's label through a fixed
% table (did2.convert.axisLetter). A stack whose labels (or, with none, its
% letters) do not map one-to-one onto its v1 letters is carried whole as v1.
% The register row(s): carry-114.
axisWhy = axisLettersMismatch(dimOrder, splitScaleUnits(getCharField(params, 'dimension_labels')));
if ~isempty(axisWhy)
    % carry-register: carry-114
    did2.convert.reportNote('carried_as_v1', noteClass, baseField(preBody, 'id', ''), ...
        sprintf('[carry-114] awaiting_home: %s ([axis letters derive from labels])', axisWhy));
    bodies = {preBody};
    return;
end

% the acquisition time ([acquisition time on its clock], below)
[anchor, conds, needsInfo] = acquisitionTime(src, params, noteClass);
[datumType, sourceDatumType] = jDatumType(dataType);
extra = {};
software = {};
% the statement's notes: an imageStack's `label`; for a v1 `image`, its own
% block's `label`, as v1 wrote it, when it is not empty ([image label goes to
% the observation's notes] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): "a non-empty v1 `image.label` is written
% to the image observation's `notes`; `data_body` gains no field")
notes = label;
if strcmp(srcClass, 'image')
    notes = getCharField(getBlock(preBody, 'image'), 'label');
    if isempty(strtrim(notes))
        notes = '';
    end
end
obs = jStatement(src, 'observation', subjectId, ...
    jLabel('image intensity'), [], ...
    'DataBody', true, 'DatumType', datumType, 'SourceDatumType', sourceDatumType, ...
    'Conditions', conds, 'Notes', notes, 'NeedsInfo', needsInfo, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', stackId, extra{:}, 'ValueKind', 'intensity');
% DATUM ORDER 'F': the stack is a MATLAB array in the source's dimension order,
% column-major (a judgment call, recorded in the port report).
o = jOpts(src, 'DatumOrder', 'F');
% the file's format and compression ([image file details placed]): an
% imageStack's `formatOntology`, an image's `format` and `compression`
imageBlk = getBlock(preBody, 'image');
fileFormat = firstNonEmpty(getCharField(stackBlk, 'format_ontology'), ...
    getCharField(stackBlk, 'formatOntology'), ...
    getCharField(imageBlk, 'format'));
if ~isempty(strtrim(fileFormat))
    o = [o, {'Format', formatOf(strtrim(fileFormat))}];
end
compression = getCharField(imageBlk, 'compression');
if ~isempty(strtrim(compression))
    % the v1 codec name; the builder writes it as the schema declares
    % `compression` (a char, or the {term, parameters} block once did-schema
    % declares it: [compression block and empty levels], Jess Haley,
    % 2026-10-26; did2.build.compression)
    o = [o, {'Compression', compression}];
end
[dims, covs] = imageAxes(dimOrder, dimSize, params);
if ~isempty(bodyConditions)
    o = [o, {'Conditions', bodyConditions}];
end
% [image stack name goes to notes] (Decided by Jess Haley, 2026-10-27, as
% amended by [v1 name goes to the class's own name field]): a non-empty v1
% base.name is written to the data body's free text, `notes` ([one
% free-text field: notes]), as v1 wrote it
stackName = jBaseName(preBody);
if ~isempty(stackName)
    o = [o, {'Notes', stackName}];
end
body = did2.build.sampledBody(stackId, dims, 'Covariates', covs, o{:});
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end
bodies = [{obs, body, anchor}, software];
end

function [anchor, conds, needsInfo] = acquisitionTime(src, params, noteClass)
%ACQUISITIONTIME The observation's time reference and, on a clock that is not
%   UTC, its acquisition-time condition.
%
%   [acquisition time on its clock] (Decided by Jess Haley, 2026-10-30, did-schema
%   V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G28): a v1 image stack's
%   acquisition time (`timestamp`, a MATLAB datenum on the clock `clocktype`)
%   leaves the label it was written in ("acquisition timestamp (<clock>)"):
%     * on a UTC clock (utc, approx_utc) it IS the observation's time
%       reference: an absolute_time_reference holding the UTC instant
%       ([UTC acquisition time is absolute], Decided by Jess Haley,
%       2026-10-31, did-schema did_v2_go_forward_class_audit.md;
%       docs/V2_PLAN.md G65: "That should be an absolute time reference"):
%       start.utc is the datenum read as a UTC date and time (ISO 8601, to
%       the millisecond), start.source_value the datenum as v1 wrote it
%       (%.17g, so the round trip reads back the same number). It was a
%       relative_time_reference to the session, start = datenum x 86400 s,
%       copied from jTreatmentAnchor's global-clock transfer time, until
%       then. approx_utc is the same instant with a 5 s clock_tolerance
%       (NDI +ndi/+time/clocktype.m: "within 5 seconds"), as
%       jEpochClockReferences and epochMint de-encode it. A datenum no
%       ISO-8601 instant can hold (before year 0000 or after 9999) cannot
%       be converted either, and is written as on a clock that is not UTC
%       (below), its needs_info reason saying so.
%     * on any other clock the datenum cannot be converted without assuming
%       UTC: the observation keeps its "during the session" anchor, on the
%       stack's clock where V2 has that clock (dev_local_time,
%       dev_global_time, exp_global_time; approx_ as a 5 s clock_tolerance),
%       and a condition with the variable AFO:AFR_0001158 "acquisition time"
%       ([afo prefix registered]) keeps the datenum as its `source_value`
%       (source unit day); the canonical `quantity.value` is left out and
%       named in base.needs_info ([missing facts are needs info]), with a
%       `needs_info` report note. A clock V2 does not have (none, no_time,
%       inherited, any other name) is named, as v1 wrote it, in that entry's
%       reason, so the round trip can read it back.
%   With no finite scalar `timestamp` there is no acquisition time: the
%   "during the session" anchor alone, as before.
conds = [];
needsInfo = struct('field', {}, 'reason', {});
ts = getField(params, 'timestamp');
if ~(isnumeric(ts) && isscalar(ts) && isfinite(ts))
    anchor = jSessionAnchor(src, 'during');
    return;
end
ts = double(ts);
raw = strtrim(getCharField(params, 'clocktype'));
[clk, tol] = v2Clock(raw);
day = struct('node', 'om:day', 'name', 'day');
clockOpts = {};
if ~isempty(clk)
    clockOpts = {'Clock', clk};
    if tol > 0
        clockOpts = [clockOpts, {'ClockTolerance', tol}];
    end
end
why = 'which is not a UTC clock: it cannot be converted without assuming UTC';
if strcmp(clk, 'utc')
    utc = utcInstant(ts);
    if ~isempty(utc)
        extra = {};
        if tol > 0
            extra = {'ClockTolerance', tol};
        end
        o = jOpts(src, 'SourceValue', sprintf('%.17g', ts), 'Approximate', false, extra{:});
        anchor = did2.build.absoluteTimeReference(utc, o{:});
        return;
    end
    why = 'which no ISO-8601 UTC instant can hold (a year outside 0000-9999)';
end
anchor = jSessionAnchor(src, 'during', clockOpts{:});
conds = did2.build.composite('statement', 'conditions', struct( ...
    'variable', did2.convert.registeredTerm('AFO:AFR_0001158', 'acquisition time'), ...
    'source_unit', day, ...
    'quantity', struct('source_value', sprintf('%.17g', ts))));
if isempty(raw)
    onClock = 'on no named clock';
else
    onClock = sprintf('on clock ''%s''', raw);
end
needsInfo = struct('field', 'statement.conditions(1).quantity.value', ...
    'reason', sprintf(['v1 states the acquisition time as a MATLAB datenum %s, ' ...
    '%s ([acquisition time on its clock])'], onClock, why));
did2.convert.reportNote('needs_info', noteClass, baseField(src, 'id', ''), ...
    needsInfo.field);
end

function utc = utcInstant(days)
%UTCINSTANT The ISO-8601 UTC instant ('yyyy-MM-ddTHH:mm:ss.SSSZ') of a MATLAB
%   datenum read on a UTC clock, rounded to the millisecond (the datenum
%   itself is kept as start.source_value); '' when no such instant has a
%   four-digit year (datenum 1 is 0000-01-01, 3652060 is 10000-01-01).
utc = '';
if ~(days >= 1 && days < 3652060)
    return;
end
whole = floor(days);
d = datetime(whole, 'ConvertFrom', 'datenum', 'TimeZone', 'UTC') ...
    + milliseconds(round((days - whole) * 86400000));
d.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
utc = char(d);
if isempty(regexp(utc, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$', 'once'))
    utc = '';
end
end

function [clk, tol] = v2Clock(raw)
%V2CLOCK The V2 clock (relative_time_reference.value.clock) a v1 clocktype
%   names, and the clock_tolerance in seconds its approx_ prefix states; ''
%   for a clocktype V2 has no clock for (none, no_time, inherited, other).
clk = '';
tol = 0;
switch raw
    case {'utc', 'dev_local_time', 'dev_global_time', 'exp_global_time'}
        clk = raw;
    case {'approx_utc', 'approx_dev_global_time', 'approx_exp_global_time'}
        clk = raw(numel('approx_') + 1:end);
        tol = 5;
end
end

function why = axisLettersMismatch(dimOrder, labels)
%AXISLETTERSMISMATCH '' when each axis's label (its letter where the stack has
%   no label for it) maps to that axis's v1 letter through did2.convert.axisLetter
%   and no letter repeats, else why not.
why = '';
dimOrder = upper(char(dimOrder));
if numel(unique(dimOrder)) ~= numel(dimOrder)
    why = sprintf('dimension_order "%s" repeats a letter', dimOrder);
    return;
end
for k = 1:numel(dimOrder)
    nm = dimOrder(k);
    if k <= numel(labels) && ~isempty(labels{k})
        nm = labels{k};
    end
    if ~strcmp(did2.convert.axisLetter(nm), dimOrder(k))
        why = sprintf('axis %d (%s) is labelled "%s", which does not derive the letter', ...
            k, dimOrder(k), nm);
        return;
    end
end
if numel(labels) > numel(dimOrder) && any(~cellfun(@isempty, labels(numel(dimOrder) + 1:end)))
    why = sprintf('%d dimension_labels for the %d letters of "%s"', numel(labels), ...
        numel(dimOrder), dimOrder);
end
end

function tf = isTypeRange(limits, dataType)
%ISTYPERANGE True when LIMITS is exactly DATATYPE's range: [intmin intmax] of
%   an integer class, [0 1] for logical -- how every NDI main writer sets it
%   (babu import.m, haley doImport.m). Any other type has no range rule here.
tf = false;
if ~isnumeric(limits) && ~islogical(limits)
    return;
end
limits = double(limits(:)');
cls = lower(strtrim(char(dataType)));
switch cls
    case {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}
        range = double([intmin(cls) intmax(cls)]);
    case {'logical', 'bool'}
        range = [0 1];
    otherwise
        return;
end
tf = isequal(limits, range);
end

function tag = carryRowOf(b, imageRow, imageStackRow)
%CARRYROWOF The carry register row tag for this document's v1 class ([carry
%   register], Jess Haley, 2026-10-26, did-schema
%   schemas/V_eta_carry_register.json): IMAGEROW for a v1 `image` (which
%   migrators_j.image routes here), IMAGESTACKROW otherwise. '' where the
%   register has no row for that class.
if strcmp(classNameOf(b), 'image')
    tag = imageRow;
else
    tag = imageStackRow;
end
end

function nm = classNameOf(b)
nm = 'image_stack';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name') && ~isempty(b.document_class.class_name)
    nm = char(b.document_class.class_name);
end
end

function tf = isMaskOrMap(label)
tf = isMask(label) || isMap(label);
end

function tf = isMask(label)
%ISMASK The label calls the image a mask. Generic: no region is read from it
%   ([Haley mask words leave the generic stage]).
tf = contains(lower(label), 'mask');
end

function tf = isMap(label)
%ISMAP The label says each pixel is an identifier (a label map).
l = lower(label);
tf = contains(l, 'each pixel''s value is the identifier') || contains(l, 'label map');
end

function [dims, covs] = imageAxes(dimOrder, dimSize, params)
% One dimension per stack axis, its positions (origin + spacing) a covariate
% along it (data_body AMENDMENT 6; the former keys).
% Each axis term is the registry's where it holds the axis's node (x, y, z,
% t: did2.convert.axisTerm, [migrator writes the registry spelling], Jess
% Haley, 2026-10-26); any other axis is written by name, as before.
unitList = splitScaleUnits(getCharField(params, 'dimension_scale_units'));
names = splitScaleUnits(getCharField(params, 'dimension_labels'));
entries = {};
for k = 1:numel(dimOrder)
    nm = lower(dimOrder(k));
    if k <= numel(names) && ~isempty(names{k}); nm = names{k}; end
    sp = axisResolution(params, dimOrder(k));
    if sp ~= 0
        u = '';
        if k <= numel(unitList); u = unitList{k}; end
        entries{end+1} = jAxis(did2.convert.axisTerm(nm), dimSize(k), ...
            'source_unit', u, ...
            'origin',  struct('value', 0, 'source_value', 0), ...
            'spacing', struct('value', sp, 'source_value', sp)); %#ok<AGROW>
    else
        % no recorded scale: only the dimension's positions, so a bare
        % dimension (Jess Haley 2026-10-22, 6.2a and "yes" to 1..n; origin 1 +
        % spacing 1 until then). A recorded scale, even 1, is kept above.
        entries{end+1} = jAxis(did2.convert.axisTerm(nm), dimSize(k)); %#ok<AGROW>
    end
end
[dims, covs] = jDimCov(entries);
end

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

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function b = getBlockAny(bodyStruct, names)
%GETBLOCKANY The first of NAMES the body holds as a block: the raw v1 spelling
%   (`imageStack_parameters`) or the renamed one (`image_stack_parameters`, a
%   v1 `image` or a body already renamed). A raw body holding both with
%   different values was carried (blockTwins) before this is read.
b = struct();
for k = 1:numel(names)
    if isfield(bodyStruct, names{k}) && isstruct(bodyStruct.(names{k}))
        b = bodyStruct.(names{k});
        return;
    end
end
end

function c = blockTwins(bodyStruct, pairs)
%BLOCKTWINS Each {CAMEL, SNAKE} row of PAIRS whose two blocks are both present
%   with different values: universalRenames kept SNAKE and discarded CAMEL.
c = {};
for k = 1:size(pairs, 1)
    if isfield(bodyStruct, pairs{k, 1}) && isfield(bodyStruct, pairs{k, 2}) ...
            && ~isequaln(bodyStruct.(pairs{k, 1}), bodyStruct.(pairs{k, 2}))
        c{end+1} = pairs{k, 1}; %#ok<AGROW>
    end
end
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

function f = formatOf(text)
%FORMATOF The file format as the term registry writes it ([migrator writes the
%   registry spelling], Jess Haley, 2026-10-26). A CURIE stays a CURIE
%   (did2.build.formatTerm names and spells it); a NAME the registry holds,
%   ignoring case, is written with the registry's node and label ('tiff' ->
%   EDAM:format_3591 'TIFF'); any other name is written as given.
f = text;
if ~isempty(regexp(text, '^[A-Za-z][A-Za-z0-9_.-]*:[^\s/]+$', 'once'))
    return;
end
t = did2.convert.registeredTerm('', text);
if ~isempty(t.node)
    f = t;
end
end
