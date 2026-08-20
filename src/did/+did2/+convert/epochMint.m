function [result, report] = epochMint(result, options)
%EPOCHMINT Mint one `epoch` entity per distinct (session, epoch-id string).
%
%   STATUS: WRITTEN 2026-08-10, EXTENDED 2026-08-11 (the ingested-metadata
%   fold), NEVER EXECUTED HERE. This container has no MATLAB -- `command -v
%   matlab octave octave-cli` prints nothing and exits 1 -- so not one line
%   below has been run in this environment. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion
%   about it, and the CI run ids are the only durable evidence.
%
%   [RESULT, REPORT] = did2.convert.epochMint(RESULT) takes the struct returned
%   by did2.convert.v1_to_v2 (after resolveDeferredBaths / resolveDatasetEntities)
%   and mints the `epoch` documents that did_v1 never had. REPORT is also
%   attached to RESULT as `RESULT.epoch_mint`, so a caller that ignores the
%   second output still carries the measurement.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: epochid, daqmetadatareader_epochdata_ingested,
%       acquisition_epoch, stimulus_response_scalar, syncrule_mapping
%   BATCH-PASS-EMITS: epochid -> document: epoch
%   BATCH-PASS-EMITS: acquisition_epoch -> document: relative_reference
%   BATCH-PASS-EMITS: daqmetadatareader_epochdata_ingested -> nothing: the loop
%       at :727 only STAMPS the `epoch_id` edge onto the body and re-runs the
%       ARMED per-class migrator. The `acquisition_metadata_file` document is
%       minted there, in +migrators_j, and is credited to that migrator -- not
%       to this pass. Declaring it here would count one emission twice.
%   BATCH-PASS-EMITS: stimulus_response_scalar -> nothing: SAME REASON, exactly.
%       The second armed loop stamps the `epoch_id` edge and re-runs
%       +migrators_j/stimulus_response_scalar; the
%       `harmonic_component_calculation` leaf and its anchor are minted THERE
%       and are already credited to that migrator, whose rung 3 reads `yes` on
%       the ladder today. Declaring them here would count one emission twice --
%       which is the failure the `-> nothing` form exists to prevent, and is
%       why arming a migrator is NOT the same shape as `acquisition_epoch`
%       below, where this pass mints the document itself.
%   BATCH-PASS-EMITS: syncrule_mapping -> nothing: SAME REASON, the third time.
%       The third armed loop stamps `epoch_id_1` / `epoch_id_2` onto the
%       passed-through mapping and re-runs +migrators_j/syncrule_mapping; the
%       `clock_alignment` and its two `relative_reference` endpoints are minted
%       THERE, in +migrators_j, and credited to that migrator. Declaring them
%       here would count one emission twice.
%
%   `acquisition_epoch` ADDED 2026-08-17, and it was a REAL OMISSION, not a
%   tidy-up. The #60 OPTION A loop below reads `acquisition_epoch` bodies (see
%   `if ~strcmp(rows(k).class_name, 'acquisition_epoch')`) and mints one
%   `relative_reference` per distinct clock onto `epoch.time_reference_#`. That
%   is a consumption and an emission the declaration did not state, so
%   DID-schema's completion ladder could not credit it: `element_epoch` read
%   stage 1 and `epochclocktimes` read rung 3 = `no` while the work was
%   shipping. Same shape as the `jSoftwareFromApp` mis-score fixed the same day,
%   one channel over -- and the same direction, understating what is built.
%
%   THE NAME IS THE MIGRATED ONE ON PURPOSE. This pass runs AFTER the per-class
%   migrators, so the batch carries `acquisition_epoch`, never the did_v1
%   `element_epoch` it was renamed from. `resolveLawnPlateSubjects` declares
%   `ontology_table_row` for the same reason. Whether DID-schema's ledger can
%   JOIN that name to the `element_epoch` row is a question about the ledger,
%   not about this sentence: both rows currently carry `veta_class = None`, so
%   the join may not reach them. Declaring what the code does is right either
%   way; a declaration bent to fit a matcher would be the reassuring direction.
%
%   `epochid` is the did_v1 MIXIN, and it is the class this pass dissolves: the
%   string was only ever a way to find the epoch, and the epoch now has a
%   document. The string is read through did2.validate.epochStrings, whose
%   other two sources -- `epochfiles_ingested` and `method_parameters` -- are
%   NOT declared as consumed: this pass reads a string off them and rewrites
%   neither. `epochfiles_ingested` already carries `epoch` in the ledger's
%   `second_pass` column for the same emission.
%   ---------------------------------------------------------------------
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A BATCH PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   A single-document migrator cannot do this, and the reason is not
%   convenience. Minting one epoch per distinct epoch id is a FIND-OR-CREATE
%   over the whole corpus: several documents share one epoch (corpus B carries
%   1,239 `element_epoch` documents over 149 distinct epoch-id strings), so a
%   per-document mint would emit one `epoch` per REFERENCING DOCUMENT -- N
%   duplicate entities for one recording. `+migrators_j/private/jEpochDocId.m`
%   is the seam that has been holding the line: it answers '' for every did_v1
%   document by construction and says so in its own header, so nothing emits an
%   `epoch_id` edge it cannot fill.
%
%   This file is the DID-side counterpart of ndi.migrate.internal.pathSPromotion
%   (a corpus-wide find-or-create keyed on (animal, site)); it sits beside
%   did2.convert.resolveDatasetEntities and resolveDeferredBaths, which are the
%   batch-level post-passes already in this package.
%
%   ---------------------------------------------------------------------
%   THE KEY IS THE PAIR (base.session_id, epoch-id string). NEVER THE STRING.
%   ---------------------------------------------------------------------
%   MEASURED, corpus run 31415147934 (`02854c7`, 2026-08-10) --
%   did2.validate.sourceCensus over 6 corpora, 221,827 v1 documents, 0
%   unreadable:
%
%                 synthetic (whole_session_) ids   ids spanning >1 session
%       20211116              0                             0
%       B                     0                           142   (of 149 distinct)
%       Dab                   0                           142   (of 1754 distinct)
%       JH                    0                             0
%       PRED                  0                             0
%       Soph                  0                            12   (of 18 distinct)
%
%   V_eta_epoch_plan.md predicted ONE hazard -- the synthetic
%   `whole_session_<reference>` id, minted per ELEMENT by
%   ndi.element.oneepoch.m:42 -- and it measures ZERO everywhere. The hazard the
%   data actually has is a DIFFERENT one: an `epochid.epochid` string is REUSED
%   ACROSS SESSIONS (`t00070` restarts in every session directory). In corpus B
%   that is 142 of 149 distinct ids -- almost the whole corpus. Grouping on the
%   string alone would FUSE epochs belonging to different sessions, which is a
%   silent merge of recordings from different animals.
%
%   So the mint key is the PAIR, and `pairs_minus_strings` in the report is the
%   number of epochs that keying on the string alone would have destroyed.
%
%   ---------------------------------------------------------------------
%   WHAT IT REFUSES TO DO, AND WHY EACH REFUSAL IS COUNTED
%   ---------------------------------------------------------------------
%   `epoch.session_id` is REQUIRED (mustBeNonEmpty). An `epoch` minted with that
%   edge empty would, until #37, VALIDATE CLEAN --
%   +did2/+validate/references.m:90 short-circuits on an empty documentId,
%   correctly, because an edge naming no document cannot dangle and that
%   function is the ORPHAN check -- and would rebuild the invented-empty-edge
%   pattern under the repair's own name. With #37's
%   did2.schema.cache.strictMode('RequiredDependencies') it stops being silent
%   and becomes a quarantine instead. Either way the answer is the same: do not
%   emit it. So:
%
%     * a document with no `base.session_id`               -> no mint, counted
%     * a session id with no `session` DOCUMENT in the batch -> no mint, counted
%     * a session id with SEVERAL session documents        -> no mint, counted
%
%   The third is not hypothetical caution: guessing which of two session
%   documents is the referent is exactly the kind of quiet decision that
%   produces a wrong graph nobody can audit later.
%
%   `epoch.session_id` points at the session DOCUMENT's `base.id`, which is NOT
%   the `base.session_id` its siblings carry: `ndi.document.m:57` mints
%   `base.id` from a fresh `ndi.ido()`, and `ndi.session.m:215`
%   (`newdocument`) sets `base.session_id` from `session.id()` separately. The
%   pass therefore INDEXES the session documents rather than assuming the two
%   strings are equal.
%
%   ---------------------------------------------------------------------
%   THE SYNTHETIC IDS ARE SKIPPED -- AND THAT IS AN UNSIGNED DECISION
%   ---------------------------------------------------------------------
%   `whole_session_<reference>` names a span nothing recorded as one epoch
%   (ndi.element.oneepoch.m:42). V_eta_epoch_plan.md's fork A1 -- CHOSEN by the
%   team 2026-08-10, NOT SIGNED -- says no `epoch` entity is minted for it,
%   because that would make `epoch` mean both a recording and a derived
%   aggregate. This pass implements the refusal (a refusal cannot fuse anything)
%   and COUNTS it as `skipped_synthetic`. It measures 0 in all six corpora, so
%   it changes nothing today; if the team signs the other way, delete the guard
%   and the count tells you exactly what it was suppressing.
%
%   ---------------------------------------------------------------------
%   WHAT IT DOES NOT BUILD
%   ---------------------------------------------------------------------
%   The `epochid`-carrying classes are NOT rewired to an `epoch_id` edge here.
%   They cannot be: only a handful of V_eta classes declare an `epoch_id`
%   DEPENDENCY at all. Measured over the built schema set -- and a plain grep
%   for the name will NOT show this, because it also matches
%   `epochfiles_ingested`'s `epoch_id` FIELD, which is a char string and not an
%   edge:
%
%   THE COUNT ON THIS BLOCK SAID **THREE**, AND THE DENOMINATOR SAID 245. BOTH
%   WERE STALE, AND STALE IN THE UNDER-REPORTING DIRECTION -- the list omitted
%   `directed_relation`, which is precisely the ONE class the 2026-08-10
%   amendment to the #60 sign-off names as the place a direct edge BELONGS
%   ("a direct `epoch_id` edge is added ONLY where the epoch is the document's
%   own content (`directed_relation`)"). A rewire planned off this block would
%   have read its own affirmative case as absent. Re-measured 2026-08-11 against
%   the built tree, deps distinguished from fields by JSON path, not by grep:
%
%     DENOMINATOR: 247 built schema files read
%       dep    acquisition_metadata_file   depends_on.1.name
%       dep    directed_relation           depends_on.3.name   <- WAS MISSING
%       dep    ingestion_manifest          depends_on.1.name
%       dep    method_parameters           depends_on.2.name
%       field  epochfiles_ingested         fields.0.name       <- char, NOT an edge
%       field  syncrule_mapping            fields.{2,3}...     <- char, NOT an edge
%
%   `syncrule_mapping` is the second field-not-edge case and it is NESTED (inside
%   the two `epochnode` blocks), so a top-level-only sweep misses it as well.
%
%   `did2.convert.epochIndex`'s own header derives the same FOUR independently
%   and states the carrier side as NINETEEN did_v1 classes (15 declaring
%   `epochid` directly, plus daqreader_image_/mfdaq_epochdata_ingested, oneepoch
%   and pyraview transitively). The "15" in the first line of this block is the
%   DIRECT-declaration count only; it is not the number of epoch-scoped v1
%   classes.
%
%   -- and two of the four are not emitted by pass 1. Stamping an edge a class
%   does not declare is the invented-edge pattern with the sign flipped. The
%   rewire needs its own schema increment (declaring `epoch_id` on those
%   classes) and is a separate line in #60.
%
%   AMENDED 2026-08-11 -- ONE OF THOSE FOUR IS NOW FILLED HERE, and the
%   sentence above is why it took a fold rather than a stamp. Read it as
%   written: `acquisition_metadata_file` DECLARES the edge and is simply not
%   EMITTED by pass 1, and it is not emitted for exactly one reason -- its
%   migrator is guarded on an epoch document that did not exist when pass 1
%   ran. This function is the moment one does. So the loop "arm the
%   ingested-metadata fold" below stamps the edge onto the passed-through
%   `daqmetadatareader_epochdata_ingested` body and re-runs
%   +migrators_j/daqmetadatareader_epochdata_ingested, which is the handoff
%   +migrators_j/private/jEpochDocId.m documents in its own header. Nothing
%   about the paragraph above is relaxed: no edge is stamped on a class that
%   does not declare it, and `ingestion_manifest` -- the other of the three --
%   is still NOT folded, for the `epochprobemap` reason recorded two paragraphs
%   down and unchanged.
%
%   `method_parameters` IS filled, because it is the one class that declares the
%   edge, is emitted by pass 1, and has the epoch string parked for exactly this
%   moment: `+migrators_j/private/jMethodParameters.m:112-119` writes the string
%   to `other.epochid` when jEpochDocId answers ''. Filling the edge and
%   removing the parked string is one fact moving to one place.
%
%   `epochfiles_ingested` is NOT folded to `ingestion_manifest` here either,
%   although #60 signs that rename: `ingestion_manifest` declares no
%   `epochprobemap`, and the probemap is the per-epoch subject attribution
%   (non-empty on 2,484 of 2,484 corpus-B documents). Folding today would drop
%   it. Its epoch id IS read as a mint key, so the epochs exist for the fold the
%   day it can be done losslessly.
%
%   ---------------------------------------------------------------------
%   THE ARMING PATH IS NOW 1 -> N. IT WAS 1 -> 1 UNTIL 2026-08-12.
%   ---------------------------------------------------------------------
%   THREE migrators are waiting on this pass to stamp `epoch_id` onto their
%   pre-body, and each says so in its own header. All three were re-checked
%   2026-08-12 by reading the armed branch, and all three return MORE THAN ONE
%   BODY there:
%
%     +migrators_j/stimulus_response_scalar.m:287,307-310
%         `bodies = jCalculation(...)` -> {leaf, anchor[, software]}
%         (jCalculation.m:118-121), then the armed `if ~isempty(epochDocId)`
%         branch REPLACES bodies{2} with `epochAnchor`'s relative_reference and
%         retargets the leaf's `time_reference_1` onto it.
%     +migrators_j/daqreader_epochdata_ingested.m:105
%         `bodies = [{preBody}, refs]` -- jEpochClockReferences mints ONE
%         relative_reference PER epochtable entry.
%     +migrators_j/daqreader_image_epochdata_ingested.m:103   same, same helper.
%
%   The two assertions this pass USED to rest on were, verbatim:
%
%     :641   if iscell(folded) && isscalar(folded); folded = folded{1}; end
%     :689   "v1_to_v2 preserves input order and this batch is 1 -> 1 throughout"
%
%   Reusing them for any of the three would have DROPPED the minted references
%   and left `time_reference_1` pointing at a document not in the batch -- an
%   ORPHAN, which the digest prints no counter for (open item #95). Both are
%   gone. The arming path now takes whatever cell of bodies a migrator returns,
%   carries body 1 back into the slot the source occupied and APPENDS bodies
%   2..N to the batch, and it is ATOMIC PER CALL: if any body of one call fails
%   to come back out of the re-fold, NONE of that call's bodies are carried and
%   the original passthrough stays. That is what makes the orphan unreachable
%   rather than merely unlikely -- a surviving primary can never reference a
%   sibling that quarantined, because they live or die together.
%
%   THREE MORE THINGS THE CARRY REFUSES, each counted, none of them hypothetical:
%
%     * a primary body that does NOT preserve `base.id`. Replacing docs{k} with
%       a differently-identified document deletes the original id from the batch
%       and every inbound reference to it dangles -- the 11,448-orphan
%       dissolution failure recorded in CLAUDE.md, arriving through a fold.
%     * a returned body carrying `epoch_id` whose CLASS does not declare that
%       dependency. This is the invented-edge pattern with the sign flipped and
%       NOTHING ELSE CATCHES IT: cache.m:761 lists `depends_on` wholesale in
%       `allowedTop`, so an undeclared edge NAME validates clean. The schema is
%       the authority, read through did2.convert.epochIndex/classDeclaresEpochEdge.
%     * an arming whose epoch document did not survive validation.
%
%   THE COUNTER THAT WOULD HAVE CAUGHT THE ORIGINAL BUG. `arming_bodies_offered`
%   is the denominator -- every body every armed migrator handed back --
%   `arming_bodies_carried` is how many reached `result.migrated`, and
%   `arming_bodies_dropped` is the difference, split by named reason. A body a
%   migrator mints and this pass discards is now a number instead of a silence.
%   `arming_vacuous` is TRUE when no arming call was made at all, so a run with
%   nothing to arm cannot read as a run that armed everything. And
%   `arming_max_bodies_per_call` is the 1 -> N witness: it reads 1 while
%   `daqmetadatareader_epochdata_ingested` is the only armed migrator, and the
%   day a class declares the edge it reads what that migrator returned.
%
%   THE 1 -> N PATH IS EXERCISED, NOT MERELY WRITTEN. Nothing in production
%   returns more than one body on an armed branch today (see the schema block
%   below), so `ArmingMigrators` exists as a name-value override for exactly one
%   purpose: to let a test drive a real N-body return through the real
%   registration and carry code. It defaults to the production table. An
%   untested 1 -> N path would be this file's own recurring error -- machinery
%   whose zero is a property of never having run.
%
%   AND FOR THE TWO daqreader ARMS THERE IS A SECOND, SEPARATE BLOCKER, which is
%   a SCHEMA question and not this function's to answer. `jEpochDocId` reads the
%   edge off the BODY, and unlike the metadata fold -- whose stamped body is
%   immediately converted to `acquisition_metadata_file`, a class that DOES
%   declare `epoch_id`, so the stamp never persists -- these two arms RETURN THE
%   PRE-BODY in `bodies`. A stamped `epoch_id` would therefore PERSIST on a
%   `daqreader_epochdata_ingested` document, and neither class declares the
%   dependency:
%
%     DENOMINATOR: 247 JSON files under schemas/V_eta, 241 with a document_class
%       (RE-DERIVED 2026-08-12; deps read by JSON path, not by grep)
%       epoch_id DEPENDENCY declared by 4: acquisition_metadata_file (required),
%         ingestion_manifest (required), directed_relation (optional),
%         method_parameters (optional)
%       daqreader_epochdata_ingested        depends_on: [daqreader_id]
%       daqreader_image_epochdata_ingested  depends_on: [daqreader_id]
%       stimulus_response_scalar            does NOT declare it either
%
%   So their armed branches are DEAD on real data today, reachable only by
%   fixtures that hand-add the edge (testMigratorsJIngested.m's `withEpochEdge`,
%   whose comment already calls it "the `epoch_id` edge #60's epoch pass will
%   add"). Declaring it is a V_eta increment and, per the 2026-08-10 amendment to
%   the #60 sign-off, an extension of what that signature names -- TEAM's call,
%   not this pass's. If it is taken it must be OPTIONAL: this pass cannot always
%   resolve an epoch (synthetic ids are skipped, and a pair may have no session
%   document or an ambiguous one), and `RequiredDependencies` is ARMED, so a
%   required edge that cannot be filled QUARANTINES rather than sitting empty.
%
%   THE ORDER HAS NOW REVERSED, and that is the only part of this block that
%   changed on 2026-08-12. The rebuild machinery is no longer the blocker; the
%   schema increment is the whole of what is left, for two of the three. The
%   arming table below is the one place a fourth row would be added, and the
%   `undeclared_edge` refusal is what stops a row being added before its class
%   declares the edge -- it reads the schema, so it cannot go stale the way a
%   list kept here would.
%
%   `stimulus_response_scalar` is the one whose stamp would NOT persist --
%   jCalculation.m:82-92 builds the leaf's `deps` by NAMING the edges it carries
%   and never copies `preBody.depends_on` wholesale, so the transient
%   `epoch_id` does not reach the emitted leaf. Whether that makes it armable
%   without a schema increment is a question about the SOURCE tombstone, not
%   about this machinery, and it is not answered here.
%
%   NOTHING BELOW HAS BEEN EXECUTED IN THIS CONTAINER. It has no MATLAB and no
%   Octave -- `command -v matlab octave octave-cli` prints nothing and exits 1
%   (re-checked 2026-08-12) -- so the quick gate is the first thing that will
%   have an opinion about the 1 -> N path, and the CI run ids are the only
%   durable evidence.
%
%   ---------------------------------------------------------------------
%   THE EPOCH-STRING READER MOVED OUT, AND WIDENED (2026-08-10)
%   ---------------------------------------------------------------------
%   The local `epochStringOf` is GONE. It read three sources and was blind to a
%   fourth and a fifth: `stimulus_response_scalar` does not carry the `epochid`
%   superclass (its template superclasses are base + stimulus_response), so its
%   two epoch strings -- `stimulus_response.element_epochid` and
%   `.stimulator_epochid` -- were invisible to this pass AND to
%   did2.validate.sourceCensus. The reader is now did2.validate.epochStrings,
%   which names every source it reads AND every source it declines, so an
%   omission is a number in `strings_by_source` / `strings_declined` rather than
%   a silence. That matters here specifically: an epoch this pass does not mint
%   is an epoch nothing can anchor to, and
%   +migrators_j/stimulus_response_scalar.m now SUPPRESSES its fold rather than
%   drop the string, so the suppression only lifts once these epochs exist.
%
%   The mint loop therefore iterates EVERY string a document carries, not the
%   first: the stimulator's epoch and the recording element's epoch are two
%   different epochs joined by syncgraph.time_convert, not two spellings of one.
%
%   Options (name-value), mirroring the sibling passes:
%     Validate       (1,1 logical, default true)  validate minted/changed bodies
%     SchemaCache    ([] or a did2.schema.cache)  override the shared cache
%     TargetVersion  (1,:) char, default 'V_eta'  no-op on other targets
%     ArmingMigrators ([] or struct)              source class -> migrator
%                    handle. [] means the production table (one row today).
%                    Exists so the 1 -> N carry can be DRIVEN by a test; see
%                    the arming block above.
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveDatasetEntities,
%   did2.convert.resolveDeferredBaths, did2.validate.sourceCensus,
%   did2.convert.migrators_j.private.jEpochDocId.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
    options.ArmingMigrators = []
end
armingMigrators = options.ArmingMigrators;
if isempty(armingMigrators)
    armingMigrators = defaultArmingMigrators();
end

% DENOMINATOR FIRST, and unconditionally. Every field below is defined before a
% single document is read, so "did not run" and "ran and found nothing" are
% different readings of the same struct rather than the same reading.
report = struct( ...
    'documents_inspected',            0, ...
    'documents_unreadable',           0, ...
    'documents_with_epoch_id',        0, ...
    'epoch_strings_read',             0, ...
    'strings_by_source', struct('source', {}, 'documents', {}, ...
                                'distinct_strings', {}), ...
    'strings_declined',               0, ...
    'strings_declined_distinct',      0, ...
    'session_documents_seen',         0, ...
    'distinct_epoch_id_strings',      0, ...
    'distinct_session_epoch_pairs',   0, ...
    'pairs_minus_strings',            0, ...
    'epochs_found_existing',          0, ...
    'epochs_minted',                  0, ...
    'skipped_synthetic',              0, ...
    'skipped_no_session_id',          0, ...
    'skipped_no_session_document',    0, ...
    'skipped_ambiguous_session',      0, ...
    'method_parameters_seen',         0, ...
    'method_parameters_edges_filled', 0, ...
    'method_parameters_unresolved',   0, ...
    'method_parameters_epoch_not_in_batch', 0, ...
    ...
    ... % THE ARMING DENOMINATOR AND WHAT BECAME OF IT. `..._offered` counts
    ... % every body every armed migrator handed back; `..._carried` counts the
    ... % ones that reached result.migrated; `..._dropped` is the difference and
    ... % equals the sum of the five named reasons below it. A body minted by a
    ... % migrator and discarded here is the defect this instrument exists for --
    ... % it would have left `time_reference_1` pointing outside the batch, and
    ... % the corpus digest prints no orphan counter (open item #95).
    'arming_calls',                        0, ...
    'arming_bodies_offered',               0, ...
    'arming_bodies_carried',               0, ...
    'arming_bodies_dropped',               0, ...
    'arming_bodies_dropped_declined',      0, ...
    'arming_bodies_dropped_id_not_preserved',   0, ...
    'arming_bodies_dropped_undeclared_edge',    0, ...
    'arming_bodies_dropped_not_rebuilt',   0, ...
    'arming_bodies_dropped_epoch_lost',    0, ...
    'arming_extra_bodies_offered',         0, ...
    'arming_extra_bodies_carried',         0, ...
    'arming_calls_returning_multiple',     0, ...
    'arming_max_bodies_per_call',          0, ...
    'arming_edge_declaration_unchecked',   0, ...
    'arming_vacuous',                   true, ...
    'epoch_index_report',      did2.convert.epochIndex.blankReport(), ...
    ... % #60 OPTION A -- acquisition_epoch's clocks become the epoch's own
    ... % time_reference_# family. `..._sources_seen` is the DENOMINATOR: how
    ... % many acquisition_epoch documents this pass looked at, whether or not
    ... % any produced a reference. `..._vacuous` is TRUE when the batch held
    ... % none at all, so a run with nothing to do cannot read as a run that
    ... % did everything -- every zero under it is then a zero over a zero.
    'epoch_extent_sources_seen',           0, ...
    'epoch_extent_clocks_read',            0, ...
    'epoch_extent_references_emitted',     0, ...
    ... % emitted MINUS survived: a reference built and validated but dropped by
    ... % the re-fold, which would leave the epoch's edge dangling. Optional edges
    ... % do not fail validation, so without this counter the loss is silent.
    'epoch_extent_references_lost',        0, ...
    'epoch_extent_epochs_given_extent',    0, ...
    'epoch_extent_refused_no_epoch_string', 0, ...
    'epoch_extent_refused_no_clocks',      0, ...
    'epoch_extent_refused_no_epoch_document', 0, ...
    'epoch_extent_refused_no_session_document', 0, ...
    'epoch_extent_skipped_no_time',        0, ...
    'epoch_extent_duplicate_clock',        0, ...
    'epoch_extent_conflicting_clock',      0, ...
    'epoch_extent_vacuous',             true, ...
    'metadata_ingested_seen',              0, ...
    'metadata_ingested_already_folded',    0, ...
    'metadata_ingested_edges_stamped',     0, ...
    'metadata_ingested_folds_emitted',     0, ...
    'metadata_ingested_folds_withheld',    0, ...
    'metadata_refused_no_epoch_string',    0, ...
    'metadata_refused_no_epoch_document',  0, ...
    'metadata_refused_migrator_declined',  0, ...
    'metadata_refused_unsafe_output',      0, ...
    'metadata_refused_total',              0, ...
    'metadata_fold_vacuous',               true, ...
    ... % THE SECOND ARMED FOLD (#60, 2026-08-17) -- `stimulus_response_scalar`.
    ... % A PARALLEL COUNTER SET rather than a widened `metadata_*` one: the two
    ... % folds refuse for the same REASONS and over different DENOMINATORS, and
    ... % one shared counter would make "273 responses had no epoch document"
    ... % indistinguishable from "59 metadata readers did". The vocabulary is
    ... % deliberately identical name-for-name so the two can be read side by
    ... % side, and tests/+did2/+unittest/testEpochMintResponseArming.m asserts
    ... % that correspondence rather than trusting it to survive editing.
    'response_scalar_seen',                0, ...
    'response_scalar_already_folded',      0, ...
    'response_scalar_edges_stamped',       0, ...
    'response_scalar_folds_emitted',       0, ...
    'response_scalar_folds_withheld',      0, ...
    'response_refused_no_epoch_string',    0, ...
    'response_refused_no_epoch_document',  0, ...
    'response_refused_migrator_declined',  0, ...
    'response_refused_unsafe_output',      0, ...
    'response_refused_total',              0, ...
    'response_fold_vacuous',               true, ...
    ... % THE THIRD ARMED FOLD (#60) -- `syncrule_mapping`. A PARALLEL COUNTER
    ... % SET, name-for-name with the other two, for the same reason: the three
    ... % folds refuse for the same REASONS over different DENOMINATORS, and one
    ... % shared counter would make "273 responses had no epoch document"
    ... % indistinguishable from "2,484 sync mappings did". The vocabulary is
    ... % identical so the three can be read side by side;
    ... % tests/+did2/+unittest/testEpochMintResponseArming.m asserts that
    ... % correspondence rather than trusting it to survive editing. This fold
    ... % stamps TWO endpoint edges (epoch_id_1 / epoch_id_2) per source, one per
    ... % epochnode, and its migrator's branch 1 emits clock_alignment + two
    ... % relative_reference bodies; `edges_stamped` counts the source documents
    ... % whose BOTH endpoints resolved, not the individual edges.
    'syncrule_seen',                       0, ...
    'syncrule_already_folded',             0, ...
    'syncrule_edges_stamped',              0, ...
    'syncrule_folds_emitted',              0, ...
    'syncrule_folds_withheld',             0, ...
    'syncrule_refused_no_epoch_string',    0, ...
    'syncrule_refused_no_epoch_document',  0, ...
    'syncrule_refused_migrator_declined',  0, ...
    'syncrule_refused_unsafe_output',      0, ...
    'syncrule_refused_total',              0, ...
    'syncrule_fold_vacuous',               true, ...
    ... % ==================================================================
    ... % #2 "MEASURE FIRST" (team decision 2026-08-20) -- REPORT-ONLY.
    ... % Two numbers the epochprobemap-decomposition decision needs, taken off
    ... % the batch this pass already reads and CHANGING NOTHING: no document is
    ... % minted, folded or edge-stamped from any counter below. It is the same
    ... % stance as `pairs_minus_strings` and `strings_by_source` above -- an
    ... % observation, not a conversion. See measureIngestionProbemap.
    ... %
    ... % MEASUREMENT 1 -- PROBES-PER-EPOCH. `epochfiles_ingested.epochprobemap`
    ... % is the tab-delimited serialize() of an ndi.epoch.epochprobemap_daqsystem
    ... % array (NDI origin/main +ndi/+epoch/epochprobemap_daqsystem.m:136-168):
    ... % a header line `name<TAB>reference<TAB>type<TAB>devicestring<TAB>
    ... % subjectstring` then ONE line per probe. The probe-row count is the fold's
    ... % 1 -> N fan-out. `probemap_vacuous` LEADS the group, for the reason every
    ... % other _vacuous flag in this report does: a corpus with no
    ... % epochfiles_ingested document makes every number below it a zero over a
    ... % zero denominator, and must not read as a corpus where the fold found
    ... % nothing to fan out.
    'probemap_vacuous',                    true, ...
    'probemap_documents_seen',             0, ...
    'probemap_nonempty',                   0, ...
    'probemap_empty',                      0, ...
    'probemap_char_shape',                 0, ...
    'probemap_struct_shape',               0, ...
    'probemap_unrecognized_header',        0, ...
    'probemap_probe_rows_total',           0, ...
    'probemap_docs_with_rows',             0, ...
    'probemap_docs_zero_rows',             0, ...
    'probemap_probe_rows_min',             0, ...
    'probemap_probe_rows_max',             0, ...
    ... % The full per-count tally {probe_rows, documents}. A struct array, not a
    ... % scalar -- rendered by a dedicated block in tools/census_digest.py and
    ... % listed in test_batch_pass_wiring.NOT_RENDERED_YET, exactly as
    ... % `strings_by_source` is.
    'probemap_rows_by_count', struct('probe_rows', {}, 'documents', {}), ...
    ... %
    ... % MEASUREMENT 2 -- #30-OBSERVATION OVERLAP. The question the team asked is
    ... % "would minting a per-epoch observation from the probemap DUPLICATE a #30
    ... % recording-observation that already covers the same (subject, epoch)".
    ... % What is COMPUTABLE at this hook and what is NOT is stated in the header
    ... % of measureIngestionProbemap; the short version is that a #30 observation
    ... % (base.name == 'migrated_recording_observation', from jRecordingObservation)
    ... % carries a SESSION anchor, never an epoch one, so the per-EPOCH overlap is
    ... % 0 by construction (recording_obs_epoch_scoped) and the answerable overlap
    ... % is at the (session, subject) level.
    'overlap_vacuous',                     true, ...
    'recording_obs_seen',                  0, ...
    'recording_obs_session_scoped',        0, ...
    'recording_obs_epoch_scoped',          0, ...
    'recording_obs_anchor_unresolved',     0, ...
    'probemap_subject_attributions',       0, ...
    'probemap_distinct_subject_strings',   0, ...
    'probemap_subject_strings_matched',    0, ...
    'probemap_subject_strings_unmatched',  0, ...
    'probemap_epoch_subject_covered',      0, ...
    'probemap_epoch_subject_uncovered',    0, ...
    'mint_quarantined',               0, ...
    'ran',                            false, ...
    'epoch_index', struct('session_id', {}, 'local_identifier', {}, ...
                          'epoch_document_id', {}));
result.epoch_mint = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % `epoch` exists only in V_eta; other targets are untouched.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.epoch_mint = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once into a flat row -----------------------------
% A document this cannot read is COUNTED, never dropped. An all-zero report
% that could not read its input must not be indistinguishable from a clean one:
% that is the silentLoss failure, and it cost two days.
% `epochValues{k}` / `epochSources{k}` are CELL ROWS held beside `rows` rather
% than inside it: a struct array field cannot hold a cell without the
% struct('f', {{c}}) double-brace, and that trap has already produced one
% silently-empty reader in this package. `rows(k).epoch_string` is kept as the
% FIRST string only, for the code paths that want a single answer.
rows = struct('class_name', {}, 'epoch_string', {}, 'session_id', {}, ...
              'doc_id', {}, 'datestamp', {});
bodies = cell(1, n);
epochValues  = cell(1, n);
epochSources = cell(1, n);
declinedValues = {};
for k = 1:n
    epochValues{k}  = {};
    epochSources{k} = {};
    try
        b = docs{k}.toStruct();
        bodies{k} = b;
        [hits, declined] = did2.validate.epochStrings(b);
        epochValues{k}  = {hits.value};
        epochSources{k} = {hits.source};
        if ~isempty(declined)
            declinedValues = [declinedValues, {declined.value}]; %#ok<AGROW>
        end
        first = '';
        if ~isempty(hits); first = hits(1).value; end
        rows(k) = struct( ...
            'class_name',   classNameOf(b), ...
            'epoch_string', first, ...
            'session_id',   baseField(b, 'session_id'), ...
            'doc_id',       baseField(b, 'id'), ...
            'datestamp',    creationTime(b));
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        rows(k) = struct('class_name', '', 'epoch_string', '', ...
            'session_id', '', 'doc_id', '', 'datestamp', '');
    end
end

allStrings = [epochValues{:}];
report.epoch_strings_read = numel(allStrings);
hasEpoch = ~cellfun(@isempty, epochValues);
report.documents_with_epoch_id = sum(hasEpoch);
if isempty(allStrings)
    report.distinct_epoch_id_strings = 0;
else
    report.distinct_epoch_id_strings = numel(unique(allStrings));
end
% PER-SOURCE, so a source that contributes nothing is visibly a zero rather than
% an absence. This is the whole point of consolidating onto one reader: the
% stimulus-response rows below were invisible to every previous counter.
report.strings_by_source = perSourceCounts(epochValues, epochSources);
report.strings_declined = numel(declinedValues);
if isempty(declinedValues)
    report.strings_declined_distinct = 0;
else
    report.strings_declined_distinct = numel(unique(declinedValues));
end

% --- #2 "measure first": probemap fan-out + #30 overlap (REPORT-ONLY) ------
% Computed HERE, off the snapshots `rows` / `bodies` taken at the top of this
% function, so it reads the batch as it ARRIVED -- before this pass mints any
% epoch, stamps any edge or folds anything. It writes only `report.*` fields and
% returns nothing to the batch, so every later return path carries the numbers
% and none of them changes a document. See measureIngestionProbemap.
report = measureIngestionProbemap(report, rows, bodies, n);

% --- index the session documents ------------------------------------------
% base.session_id -> the session document's base.id, plus a count so a session
% id claimed by two documents is refused rather than guessed at.
sessionDocId = containers.Map('KeyType', 'char', 'ValueType', 'char');
sessionDocCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~strcmp(rows(k).class_name, 'session'); continue; end
    report.session_documents_seen = report.session_documents_seen + 1;
    sid = rows(k).session_id;
    if isempty(sid) || isempty(rows(k).doc_id); continue; end
    if isKey(sessionDocCount, sid)
        sessionDocCount(sid) = sessionDocCount(sid) + 1;
    else
        sessionDocCount(sid) = 1;
        sessionDocId(sid) = rows(k).doc_id;
    end
end

% --- FIND, then create ----------------------------------------------------
% Seed the index from the `epoch` documents ALREADY in the batch. Without this
% the pass is not idempotent, and ndi.migrate.local documents itself as
% idempotent: re-running on a dataset that already has a <target>.sqlite reads
% every document back and runs the second pass again, so every re-run would mint
% a second `epoch` for the same (session, id) pair while the source documents
% still carry their `epochid` string. A find-or-create that only creates is a
% duplicate factory.
epochIdByKey = containers.Map('KeyType', 'char', 'ValueType', 'char');
% The epochs that were ALREADY in the batch. They are never rebuilt, so they
% cannot fail validation here and are alive unconditionally -- which is exactly
% what the carry decision below needs to know, and what it must not confuse
% with "absent from out.migrated".
foundExistingIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
indexRows = struct('session_id', {}, 'local_identifier', {}, ...
                   'epoch_document_id', {});
for k = 1:n
    if ~strcmp(rows(k).class_name, 'epoch'); continue; end
    lid = '';
    if isfield(bodies{k}, 'epoch') && isstruct(bodies{k}.epoch)
        lid = charField(bodies{k}.epoch, {'local_identifier'});
    end
    if isempty(lid) || isempty(rows(k).doc_id); continue; end
    existingKey = pairKey(rows(k).session_id, lid);
    if isKey(epochIdByKey, existingKey); continue; end
    epochIdByKey(existingKey) = rows(k).doc_id;
    foundExistingIds(rows(k).doc_id) = true;
    report.epochs_found_existing = report.epochs_found_existing + 1;
    indexRows(end+1) = struct('session_id', rows(k).session_id, ...
        'local_identifier', lid, 'epoch_document_id', rows(k).doc_id); %#ok<AGROW>
end

% --- mint one epoch per distinct (session, epoch string) ------------------
% ONE DOCUMENT MAY CARRY SEVERAL EPOCH STRINGS, and they may name DIFFERENT
% epochs: `stimulus_response.stimulator_epochid` is the STIMULATOR's epoch and
% `element_epochid` is the RECORDING ELEMENT's, mapped onto each other by
% syncgraph.time_convert (tuning_response.m:245-246). Taking only the first
% would mint one of the two and silently lose the other, which is the same
% single-answer assumption that made the census blind to this family in the
% first place. So the loop is over every hit, not over `rows(k).epoch_string`.
refusedKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');
minted = {};
for k = 1:n
    sid = rows(k).session_id;
    for j = 1:numel(epochValues{k})
        es = epochValues{k}{j};
        if isempty(es); continue; end
        key = pairKey(sid, es);
        if isKey(epochIdByKey, key) || isKey(refusedKeys, key)
            continue;   % find-or-create: this pair already has its answer
        end
        if startsWith(es, 'whole_session_')
            refusedKeys(key) = true;
            report.skipped_synthetic = report.skipped_synthetic + 1;
            continue;
        end
        if isempty(sid)
            refusedKeys(key) = true;
            report.skipped_no_session_id = report.skipped_no_session_id + 1;
            continue;
        end
        if ~isKey(sessionDocId, sid)
            refusedKeys(key) = true;
            report.skipped_no_session_document = ...
                report.skipped_no_session_document + 1;
            continue;
        end
        if sessionDocCount(sid) > 1
            refusedKeys(key) = true;
            report.skipped_ambiguous_session = ...
                report.skipped_ambiguous_session + 1;
            continue;
        end
        body = mintEpoch(es, sid, sessionDocId(sid), rows(k).datestamp);
        epochIdByKey(key) = body.base.id;
        minted{end+1} = body; %#ok<AGROW>
        indexRows(end+1) = struct('session_id', sid, 'local_identifier', es, ...
            'epoch_document_id', body.base.id); %#ok<AGROW>
    end
end

% --- #60 OPTION A: the epoch carries its own extents ------------------------
% TEAM DECISION (jess, in session, 2026-08-14), answering the one thing the #60
% signature left open. The signature says "acquisition_epoch dissolves and its
% clocks become relative_reference documents" and does NOT say who HOLDS them.
% Two readings were possible and only one survives the class going away:
%
%   (a) CHOSEN. The `epoch` holds them -- `epoch.time_reference_#` -> one
%       `relative_reference` per clock -- and each reference's `relative_to`
%       points at the SESSION. Non-circular, and it is the only option that
%       still stands when acquisition_epoch is gone. The team's words:
%       "A. Acquisition_epoch won't exist."
%   (b) REJECTED. acquisition_epoch keeps holding them, pointing at the epoch
%       (the shape `daqreader_epochdata_ingested` uses). Consistent with that
%       precedent, but it keeps a dissolving class load-bearing.
%
% WHY `relative_to` IS THE SESSION AND NOT THE EPOCH. Under (a) the holder IS
% the epoch, so anchoring to the epoch would make the document point at its own
% holder -- a self-reference that says nothing. The session is the referent the
% extent is actually measured against, and #51 established a session document
% exists in every corpus (run 31327383671, all six), so the required
% `relative_to` can always be filled. A reference that cannot be anchored is
% NOT emitted: `RequiredDependencies` is armed, so an empty required edge
% quarantines rather than sitting silently, and that is the correct outcome.
%
% THE INLINE `clocks` BLOCK IS DELIBERATELY LEFT IN PLACE. This pass ADDS the
% references and removes nothing, which is row #60's own rule -- "Nothing may
% be deleted until the corpus proves the fold" -- and the discipline that the
% 2,484 corpus-B quarantines were the price of skipping. Clearing the block is
% a follow-up gated on a corpus run, not on a decision. Until then the fact is
% stored twice, which is #69's defect and is the LESSER of the two evils here,
% recorded rather than glossed.
%
% ONE REFERENCE PER CLOCK, AND THE UNIQUENESS IS ALREADY DECLARED. `epoch.json`
% carries `referent_unique_by: {time_reference_#, value.clock}` -- so several
% acquisition_epoch documents sharing one epoch (the normal case: corpus B has
% 1,239 element_epoch documents over 149 epoch strings) must not each add their
% own copy of the same clock. Duplicates are counted and dropped; a duplicate
% that DISAGREES about t0/t1 is counted separately and still dropped, because
% picking a winner would be inventing a fact neither source states.
clocksByKey = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:n
    if ~strcmp(rows(k).class_name, 'acquisition_epoch'); continue; end
    report.epoch_extent_sources_seen = report.epoch_extent_sources_seen + 1;
    % The `epochid` MIXIN string specifically -- acquisition_epoch's chain is
    % {base, epochid}, the same shape the metadata fold reads. Taking
    % "whichever string this body has" is the error the loops above avoid.
    es = valueForSource(epochValues{k}, epochSources{k}, 'epochid');
    if isempty(es)
        report.epoch_extent_refused_no_epoch_string = ...
            report.epoch_extent_refused_no_epoch_string + 1;
        continue;
    end
    entries = acquisitionEpochClocks(bodies{k});
    if isempty(entries)
        report.epoch_extent_refused_no_clocks = ...
            report.epoch_extent_refused_no_clocks + 1;
        continue;
    end
    report.epoch_extent_clocks_read = ...
        report.epoch_extent_clocks_read + numel(entries);
    key = pairKey(rows(k).session_id, es);
    if isKey(clocksByKey, key)
        clocksByKey(key) = [clocksByKey(key), entries];
    else
        clocksByKey(key) = entries;
    end
end
report.epoch_extent_vacuous = (report.epoch_extent_sources_seen == 0);

% `.Count`, NOT `numel`: numel() on a containers.Map returns 1 (it is a scalar
% handle object), so a count written that way reads 1 forever regardless of what
% is in the map. A denominator that cannot move is worse than no denominator.
% double(), and it is not cosmetic. `containers.Map.Count` returns UINT64, and
% uint64 arithmetic SATURATES: `pairs - strings` below could never go negative,
% so a day when the string count exceeded the pair count -- which would mean the
% reader or the key is broken -- would report a reassuring 0 instead of a
% negative number. An instrument whose error case is indistinguishable from
% "nothing to report" is the defect this whole pass exists to avoid. It also
% made verifyEqual fail on class rather than value, which is how it was found.
report.distinct_session_epoch_pairs = ...
    double(epochIdByKey.Count) + double(refusedKeys.Count);
% THE MEASUREMENT THIS PASS EXISTS FOR, restated as a number the report carries.
% Keying on the id STRING alone would produce `distinct_epoch_id_strings`
% groups; keying on the PAIR produces `distinct_session_epoch_pairs`. The
% difference is the number of epochs that the string key would have FUSED --
% 142 of 149 distinct ids in corpus B, measured, not predicted.
report.pairs_minus_strings = ...
    report.distinct_session_epoch_pairs - report.distinct_epoch_id_strings;

% --- fill the ONE declared, fillable epoch edge ---------------------------
changedIdx = [];
% The primary body whose id must come back out of the re-fold for `changedIdx(j)`
% to be replaced. Kept EXPLICITLY rather than taken from `rows(...).doc_id`,
% because a fold that does not preserve the id would otherwise match nothing,
% leave the original in place and report nothing -- a silent no-op. The carry
% loop refuses such a fold out loud instead, and this array is what lets it.
changedPrimaryId = {};
% Which armed call, if any, produced the body at changedIdx(j). Index into
% `armings`; 0 for a plain in-place edge fill (method_parameters) that no
% migrator was involved in.
changedArming = [];
% One entry per armed migrator CALL, not per body: {index, primary_id,
% extra_ids, body_count, epoch_id, is_metadata_fold}. The CALL is the unit
% because the carry decision is all-or-nothing across it.
armings = {};
extraBodies = {};    % bodies 2..N of every armed call, awaiting the re-fold

% THE IDS ARE TRACKED SEPARATELY, AND THAT IS THE WHOLE BUG FROM 68a1900.
% Putting a body in `extraBodies` gets it VALIDATED (it joins `rebuildIn`) and
% does NOT get it EMITTED: the append-back loop below is driven entirely by
% `armings{a}.extra_ids`, so a body with no arming entry is built, validated and
% then dropped on the floor -- the exact failure the comment above that loop
% names. The epoch meanwhile kept the `time_reference_#` edge pointing at it, so
% the result was a dangling reference. CI caught all three tests; this list and
% the append loop after the mint are the repair.
extentRefIds = {};
for m = 1:numel(minted)
    epochBody = minted{m};
    key = pairKey(epochBody.base.session_id, epochBody.epoch.local_identifier);
    if ~isKey(clocksByKey, key); continue; end
    sessionDocumentId = depValueOf(epochBody, 'session_id');
    if isempty(sessionDocumentId)
        % Cannot happen through mintEpoch, which sets it unconditionally --
        % asserted rather than assumed, because a silently unanchored
        % reference is the invented-empty-edge pattern.
        report.epoch_extent_refused_no_session_document = ...
            report.epoch_extent_refused_no_session_document + 1;
        continue;
    end
    [refs, stats] = epochExtentReferences(clocksByKey(key), ...
        sessionDocumentId, epochBody.base.session_id, creationTime(epochBody));
    report.epoch_extent_skipped_no_time = ...
        report.epoch_extent_skipped_no_time + stats.no_time;
    report.epoch_extent_duplicate_clock = ...
        report.epoch_extent_duplicate_clock + stats.duplicate;
    report.epoch_extent_conflicting_clock = ...
        report.epoch_extent_conflicting_clock + stats.conflicting;
    if isempty(refs); continue; end
    for r = 1:numel(refs)
        epochBody = setDep(epochBody, sprintf('time_reference_%d', r), ...
            refs{r}.base.id);
        % TWO LISTS, TWO JOBS. `extraBodies` gets the body VALIDATED (it joins
        % rebuildIn); `extentRefIds` gets it EMITTED (the append loop after the
        % mint). Using only the first is what dropped them in 68a1900.
        extraBodies{end+1} = refs{r}; %#ok<AGROW>
        extentRefIds{end+1} = refs{r}.base.id; %#ok<AGROW>
    end
    % Code scanning flags this line as "variable appears to change size on
    % every loop iteration" (alert 218). FALSE POSITIVE, verified by reading
    % rather than assumed -- the same check jEpochClockReferences records for
    % alerts 170 and 171. `minted` is indexed by `m` over `1:numel(minted)`, so
    % this OVERWRITES an existing cell and cannot grow it; the only growth in
    % this loop is `extraBodies{end+1}` two lines up, which carries the
    % house-style AGROW pragma. Preallocating here would mean preallocating a
    % cell that is already exactly the right size.
    minted{m} = epochBody;
    report.epoch_extent_references_emitted = ...
        report.epoch_extent_references_emitted + numel(refs);
    report.epoch_extent_epochs_given_extent = ...
        report.epoch_extent_epochs_given_extent + 1;
end

% The epoch-edge declaration check reads the SCHEMA (epochIndex, which walks the
% superclass chain and answers false when it cannot look). It is consulted only
% when the caller asked for validation: `Validate=false` says the caller has
% turned schema checking off for this call, and a guard whose verdict depended
% on whether a schema path happened to be configured would make a silent
% configuration difference change the DATA. The skips are counted, not assumed.
edgeIndex = did2.convert.epochIndex([], 'SchemaCache', options.SchemaCache);
checkEdgeDeclaration = options.Validate;
% class name -> 1 declares / 0 does not / -1 could not be checked. See
% declaresEpochEdge for why the third value cannot be recovered from
% epochIndex's counters alone.
edgeMemo = containers.Map('KeyType', 'char', 'ValueType', 'double');
% NOTE the `is_metadata_fold` flag on each `armings` entry, which replaced a
% parallel `metadataFoldIdx` array. The reason for recording it at all is
% unchanged: after the rebuild the body in `docs{k}` may be either the folded
% document or the original passthrough (whichever survived), so asking "what
% class is it now" cannot tell an emitted fold from a withheld one -- which is
% precisely the number to report.
for k = 1:n
    if ~strcmp(rows(k).class_name, 'method_parameters'); continue; end
    report.method_parameters_seen = report.method_parameters_seen + 1;
    if ~isempty(depValueOf(bodies{k}, 'epoch_id'))
        continue;   % already filled (a re-run); find-or-create, not create
    end
    % The PARKED string specifically, not "whichever string this body has".
    % jMethodParameters:120-127 writes it to `other.epochid`, and the removal
    % below removes exactly that field -- reading a different source here would
    % fill the edge from one fact and delete another.
    es = valueForSource(epochValues{k}, epochSources{k}, 'method_parameters');
    if isempty(es); continue; end
    key = pairKey(rows(k).session_id, es);
    if ~isKey(epochIdByKey, key)
        report.method_parameters_unresolved = ...
            report.method_parameters_unresolved + 1;
        continue;
    end
    b = bodies{k};
    b = setDep(b, 'epoch_id', epochIdByKey(key));
    % The parked string leaves in the same step the edge arrives. Leaving both
    % would store one fact twice with nothing saying which is authoritative --
    % the defect open item #69 exists for.
    if isfield(b, 'method_parameters') && isstruct(b.method_parameters) ...
            && isfield(b.method_parameters, 'other') ...
            && isstruct(b.method_parameters.other) ...
            && isfield(b.method_parameters.other, 'epochid')
        b.method_parameters.other = rmfield(b.method_parameters.other, 'epochid');
    end
    bodies{k} = b;
    changedIdx(end+1)      = k;                %#ok<AGROW>
    changedPrimaryId{end+1} = rows(k).doc_id;  %#ok<AGROW>
    changedArming(end+1)   = 0;                %#ok<AGROW>
    report.method_parameters_edges_filled = ...
        report.method_parameters_edges_filled + 1;
end

% --- arm the ingested-metadata fold ---------------------------------------
% `daqmetadatareader_epochdata_ingested` -> `acquisition_metadata_file`, the
% TEAM-SIGNED fold (V_eta_ingested_payload_findings.md, TEAM-SIGN-OFF [daq
% ingested payloads], jess@walthamdatascience.com / 2026-08-08: "ONE new class,
% `acquisition_metadata_file`").
%
% THIS IS NOT A SECOND FOLD IMPLEMENTATION. The fold lives in
% +migrators_j/daqmetadatareader_epochdata_ingested.m and is called here
% unchanged. All this loop does is STAMP THE `epoch_id` EDGE the migrator is
% guarded on -- which is the handoff its own guard names in as many words:
%
%   +migrators_j/private/jEpochDocId.m
%     "The day the epoch pass stamps an `epoch_id` edge, these migrators
%      convert with no further change; the tests drive both branches."
%
% So the arming is one assignment, the fold stays under the tests that already
% pin it (testMigratorsJIngested's metadata block), and there is exactly one
% place that knows what an `acquisition_metadata_file` looks like.
%
% WHY HERE AND NOT IN A NEW BATCH PASS. Three reasons, in order of weight:
%
%   1. This pass already owns the exact half that was missing. Its own header
%      says the rewire is blocked because only a handful of V_eta classes
%      declare an `epoch_id` DEPENDENCY at all -- FOUR, re-measured 2026-08-11;
%      this sentence quoted the header's stale "THREE" and is corrected with it
%      -- and two of the four are not emitted by pass 1.
%      `acquisition_metadata_file` is one of those four. It is not
%      emitted by pass 1 for ONE reason -- no epoch document existed when the
%      migrator ran -- and this is the function, and the moment, at which one
%      does. `method_parameters` above is the same operation on the one class
%      that needed no fold to reach its edge.
%   2. A new pass could not be wired on both sides from here. The gate in
%      tests/+did2/+unittest/testBatchPassWiring.m requires every batch
%      post-pass to be called from all three DID harnesses AND from
%      ndi.migrate.local, which is in NDI-matlab -- a repository this session
%      has READ access to and no more. The escape hatch (a crossRepoDivergence
%      row) exists for divergences that are INTENDED; "the author could not
%      write the other repository" is not one, and taking it would convert a
%      real gap into an approved one, which that file names as the worse
%      failure. epochMint is already called from all four sites.
%   3. Ordering is already correct and already load-bearing. The stamp must
%      follow the mint, and the mint is above.
%
% NOTHING CAN BE LOST HERE, and that is a property of the rebuild path below
% rather than a claim about this loop. EVERY body an armed migrator returns is
% pushed through did2.convert.v1_to_v2 -- body 1 alongside the other changed
% bodies, bodies 2..N alongside the mints -- and the carry decision is ALL OR
% NOTHING per call: unless every one of them came back out, `docs{k}` keeps the
% ORIGINAL passthrough document (valid under its own restored source tombstone)
% and the extras are not appended. Whatever quarantined still lands in
% `result.quarantine`, which is a 0-quarantine gate failure and the correct
% volume for a builder that emitted an invalid document.
%
% "NOTHING CAN BE LOST" IS NOW A MEASURED CLAIM RATHER THAN AN ARGUMENT.
% `arming_bodies_offered` minus `arming_bodies_carried` is the number of bodies
% this loop discarded, split by named reason, and it is the counter whose
% absence let the 1 -> 1 assumption stand unexamined.
%
% VACUITY IS REPORTED, NOT INFERRED FROM ZEROS. `metadata_fold_vacuous` is TRUE
% when this batch held no source documents at all, so a run with nothing to do
% cannot read as a run that did everything. Every `metadata_*` zero below it is
% then a zero over a zero denominator.
for k = 1:n
    if strcmp(rows(k).class_name, 'acquisition_metadata_file')
        % A re-run. find-or-create, not create: ndi.migrate.local re-reads
        % every document on a second pass over the same dataset.
        report.metadata_ingested_already_folded = ...
            report.metadata_ingested_already_folded + 1;
        continue;
    end
    if ~strcmp(rows(k).class_name, 'daqmetadatareader_epochdata_ingested')
        continue;
    end
    report.metadata_ingested_seen = report.metadata_ingested_seen + 1;
    % The `epochid` MIXIN string specifically. Reading "whichever string this
    % body has" is the error epochMint already avoids one loop up: a document
    % may carry several, and they may name different epochs.
    es = valueForSource(epochValues{k}, epochSources{k}, 'epochid');
    if isempty(es)
        report.metadata_refused_no_epoch_string = ...
            report.metadata_refused_no_epoch_string + 1;
        continue;
    end
    key = pairKey(rows(k).session_id, es);
    if ~isKey(epochIdByKey, key)
        % Refused above (synthetic id / no session id / no session document /
        % ambiguous session), or the mint quarantined. Either way there is no
        % epoch to point at, and `acquisition_metadata_file.epoch_id` is
        % REQUIRED -- emitting it empty is the invented-empty-edge pattern,
        % which +did2/+validate/references.m:90 would let through clean.
        report.metadata_refused_no_epoch_document = ...
            report.metadata_refused_no_epoch_document + 1;
        continue;
    end
    b = setDep(bodies{k}, 'epoch_id', epochIdByKey(key));
    report.metadata_ingested_edges_stamped = ...
        report.metadata_ingested_edges_stamped + 1;
    % 1 -> N FROM HERE DOWN. The migrator's return is taken as a CELL OF BODIES
    % -- the same contract v1_to_v2/normaliseMigratorOutput applies to every
    % split migrator -- and not as one body that happens to be wrapped.
    migrator = armingMigratorFor(armingMigrators, ...
        'daqmetadatareader_epochdata_ingested');
    offered = normaliseArmingOutput(migrator(b));
    nOffered = numel(offered);
    report.arming_calls          = report.arming_calls + 1;
    report.arming_bodies_offered = report.arming_bodies_offered + nOffered;
    report.arming_extra_bodies_offered = ...
        report.arming_extra_bodies_offered + max(0, nOffered - 1);
    if nOffered > report.arming_max_bodies_per_call
        report.arming_max_bodies_per_call = nOffered;
    end
    if nOffered > 1
        report.arming_calls_returning_multiple = ...
            report.arming_calls_returning_multiple + 1;
    end
    [safe, why, unchecked] = armingIsSafe(offered, ...
        'acquisition_metadata_file', rows(k).doc_id, ...
        checkEdgeDeclaration, edgeIndex, edgeMemo);
    report.arming_edge_declaration_unchecked = ...
        report.arming_edge_declaration_unchecked + unchecked;
    if ~safe
        switch why
            case 'declined'
                % The migrator's OTHER guards -- no reader edge, no bytes --
                % fired and it returned the source. It is the authority on
                % whether the fold is safe; this loop only supplies the epoch.
                % The stamped edge is dropped with the body, so the passthrough
                % is byte-identical to no-op.
                report.metadata_refused_migrator_declined = ...
                    report.metadata_refused_migrator_declined + 1;
                report.arming_bodies_dropped_declined = ...
                    report.arming_bodies_dropped_declined + nOffered;
            case 'id_not_preserved'
                report.metadata_refused_unsafe_output = ...
                    report.metadata_refused_unsafe_output + 1;
                report.arming_bodies_dropped_id_not_preserved = ...
                    report.arming_bodies_dropped_id_not_preserved + nOffered;
            case 'undeclared_edge'
                report.metadata_refused_unsafe_output = ...
                    report.metadata_refused_unsafe_output + 1;
                report.arming_bodies_dropped_undeclared_edge = ...
                    report.arming_bodies_dropped_undeclared_edge + nOffered;
            otherwise
                % UNREACHABLE by construction -- armingIsSafe returns one of
                % the three above -- and it ERRORS rather than folding into a
                % neighbouring counter, because a refusal counted under the
                % wrong name is worse than a loud stop. runCorpusDiscovery
                % records this on `epoch_mint.pass_failed` and leaves every
                % document in its pass-1 form.
                error('did2:convert:epochMint:unknownRefusal', ...
                    ['armingIsSafe returned refusal "%s", which no counter ' ...
                     'names. Add the counter; do not widen an existing ' ...
                     'one.'], why);
        end
        % A REFUSED FOLD IS A WITHHELD FOLD, and this line is why CI went red
        % on the commit that introduced the refusals. The withheld tally runs
        % over `armings` (see the carry loop), and a refusal `continue`s BEFORE
        % the `armings{end+1}` append below -- so a fold refused here was
        % counted in `metadata_refused_*` and in `arming_bodies_dropped_*` and
        % then vanished from the emitted/withheld pair, which is the split a
        % reader uses to ask "did every source document get folded?".
        %
        % `metadata_ingested_seen` counts the sources; emitted + withheld is
        % what it is meant to be reconciled against. Leaving refusals out makes
        % that sum quietly short -- a source seen, not emitted, and not
        % withheld either. Same shape as the counters this file already
        % records: not a wrong number, a MISSING one, which reads as "nothing
        % happened" rather than "we refused".
        %
        % Every arming in this loop is the metadata fold (`is_metadata_fold` is
        % set unconditionally below), so no guard is needed here; if a second
        % fold kind is ever armed in this loop, this line needs the same flag
        % the append uses.
        report.metadata_ingested_folds_withheld = ...
            report.metadata_ingested_folds_withheld + 1;
        continue;
    end
    % Body 1 takes the source document's slot; bodies 2..N are NEW documents
    % and are appended to the batch after the re-fold. Neither is carried
    % unless ALL of them come back out of it -- see the carry loop.
    bodies{k} = offered{1};
    extraIds  = cell(1, nOffered - 1);
    for e = 2:nOffered
        extraBodies{end+1} = offered{e};        %#ok<AGROW>
        extraIds{e-1}      = baseIdOf(offered{e});
    end
    armEntry = struct();
    armEntry.index            = k;
    armEntry.primary_id       = baseIdOf(offered{1});
    armEntry.extra_ids        = extraIds;
    armEntry.body_count       = nOffered;
    armEntry.epoch_id         = epochIdByKey(key);
    armEntry.is_metadata_fold = true;
    % Set here too, and NOT left absent: `armings` entries are asked for this
    % field by the carry loop, and a struct set whose members disagree about
    % which fields exist makes the read an ERROR rather than a false.
    armEntry.is_response_fold = false;
    armEntry.is_syncrule_fold = false;
    armings{end+1} = armEntry;                      %#ok<AGROW>
    changedIdx(end+1)       = k;                    %#ok<AGROW>
    changedPrimaryId{end+1} = armEntry.primary_id;  %#ok<AGROW>
    changedArming(end+1)    = numel(armings);       %#ok<AGROW>
end
% ===========================================================================
% THE SECOND ARMED FOLD -- `stimulus_response_scalar` (#60, 2026-08-17)
% ===========================================================================
% WHY A SEPARATE LOOP AND NOT A ROW IN THE ONE ABOVE. The table
% (`defaultArmingMigrators`) generalises; the LOOP does not. The metadata block
% hard-codes four things this fold differs on:
%
%     source class    daqmetadatareader_epochdata_ingested  vs stimulus_response_scalar
%     epoch string    the `epochid` MIXIN                   vs `stimulus_response.element_epochid`
%     primary class   acquisition_metadata_file             vs harmonic_component_calculation
%     counters        metadata_*                            vs response_*
%
% Unifying the two would be the better end state and is OWED -- but it means
% editing a corpus-green path that cannot be executed in the authoring
% environment, and this repository's own rule is that a change you cannot run
% is a guess. The duplication is therefore DELIBERATE and TEMPORARY: unify once
% this fold is corpus-proven, and until then
% testEpochMintResponseArming/testTheTwoArmedFoldsShareARefusalVocabulary keeps
% the two from drifting.
%
% WHY THIS FAMILY NEEDS NO SCHEMA INCREMENT, unlike the two daqreader arms.
% Derived in +migrators_j/stimulus_response_scalar.m's own header by ENUMERATING
% every `depends_on` write on the fold path: the leaf's edges are set BY NAME
% (jCarrySubject, jCalculation, this migrator's setDep calls) and nothing copies
% `preBody.depends_on` wholesale, so the transient `epoch_id` stamped below
% CANNOT reach either emitted body. `armingIsSafe`'s `undeclared_edge` refusal
% therefore cannot fire on a FOLDED document. It can and should fire on a
% GUARDED one -- those return `{preBody}`, which does carry the stamp -- and
% that refusal leaves the document exactly as it is today.
%
% THE GATE THIS OPENS. Branch 2 of that migrator is live on every did_v1
% document because `jEpochDocId` answers '' by construction; stamping the edge
% is what lets branch 1 take over, with no change in the migrator. Measured on
% 20211116: `stimulus_response.element_epochid` is populated on 273 of 273
% documents over 11 distinct values, and the mint already SEES that source
% (did2.validate.epochStrings reads it), so the epochs those anchors need exist.
for k = 1:n
    if strcmp(rows(k).class_name, 'harmonic_component_calculation')
        % A re-run -- find-or-create, as the metadata block above.
        report.response_scalar_already_folded = ...
            report.response_scalar_already_folded + 1;
        continue;
    end
    if ~strcmp(rows(k).class_name, 'stimulus_response_scalar'); continue; end
    report.response_scalar_seen = report.response_scalar_seen + 1;
    % `element_epochid` SPECIFICALLY, never "whichever string this body has".
    % The class carries TWO (`stimulus_response.stimulator_epochid` as well) and
    % they name different epochs -- the stimulator's and the element's. The
    % caller anchoring a RESPONSE wants the element's, which is what
    % did2.validate.epochStrings' own header records at :87.
    es = valueForSource(epochValues{k}, epochSources{k}, ...
        'stimulus_response.element_epochid');
    if isempty(es)
        report.response_refused_no_epoch_string = ...
            report.response_refused_no_epoch_string + 1;
        continue;
    end
    key = pairKey(rows(k).session_id, es);
    if ~isKey(epochIdByKey, key)
        report.response_refused_no_epoch_document = ...
            report.response_refused_no_epoch_document + 1;
        continue;
    end
    b = setDep(bodies{k}, 'epoch_id', epochIdByKey(key));
    report.response_scalar_edges_stamped = ...
        report.response_scalar_edges_stamped + 1;
    migrator = armingMigratorFor(armingMigrators, 'stimulus_response_scalar');
    offered = normaliseArmingOutput(migrator(b));
    nOffered = numel(offered);
    report.arming_calls          = report.arming_calls + 1;
    report.arming_bodies_offered = report.arming_bodies_offered + nOffered;
    report.arming_extra_bodies_offered = ...
        report.arming_extra_bodies_offered + max(0, nOffered - 1);
    if nOffered > report.arming_max_bodies_per_call
        report.arming_max_bodies_per_call = nOffered;
    end
    if nOffered > 1
        report.arming_calls_returning_multiple = ...
            report.arming_calls_returning_multiple + 1;
    end
    [safe, why, unchecked] = armingIsSafe(offered, ...
        'harmonic_component_calculation', rows(k).doc_id, ...
        checkEdgeDeclaration, edgeIndex, edgeMemo);
    report.arming_edge_declaration_unchecked = ...
        report.arming_edge_declaration_unchecked + unchecked;
    if ~safe
        switch why
            case 'declined'
                % The migrator's OTHER guards fired -- no `element_id`, an
                % unparseable `response_type`, or no `responses.response_real`.
                % It is the authority; this loop only supplies the epoch.
                report.response_refused_migrator_declined = ...
                    report.response_refused_migrator_declined + 1;
                report.arming_bodies_dropped_declined = ...
                    report.arming_bodies_dropped_declined + nOffered;
            case 'id_not_preserved'
                report.response_refused_unsafe_output = ...
                    report.response_refused_unsafe_output + 1;
                report.arming_bodies_dropped_id_not_preserved = ...
                    report.arming_bodies_dropped_id_not_preserved + nOffered;
            case 'undeclared_edge'
                report.response_refused_unsafe_output = ...
                    report.response_refused_unsafe_output + 1;
                report.arming_bodies_dropped_undeclared_edge = ...
                    report.arming_bodies_dropped_undeclared_edge + nOffered;
            otherwise
                error('did2:convert:epochMint:unknownRefusal', ...
                    ['armingIsSafe returned refusal "%s", which no counter ' ...
                     'names. Add the counter; do not widen an existing ' ...
                     'one.'], why);
        end
        % SAME REASON AS THE METADATA BLOCK: a refusal `continue`s before the
        % `armings{end+1}` append, so without this line a refused fold would be
        % counted in `response_refused_*` and then vanish from the
        % emitted/withheld pair that `response_scalar_seen` is reconciled
        % against -- a source seen, not emitted, not withheld either.
        report.response_scalar_folds_withheld = ...
            report.response_scalar_folds_withheld + 1;
        continue;
    end
    bodies{k} = offered{1};
    extraIds  = cell(1, nOffered - 1);
    for e = 2:nOffered
        extraBodies{end+1} = offered{e};        %#ok<AGROW>
        extraIds{e-1}      = baseIdOf(offered{e});
    end
    armEntry = struct();
    armEntry.index            = k;
    armEntry.primary_id       = baseIdOf(offered{1});
    armEntry.extra_ids        = extraIds;
    armEntry.body_count       = nOffered;
    armEntry.epoch_id         = epochIdByKey(key);
    % BOTH FLAGS ON EVERY ENTRY. The carry loop filters on
    % `is_metadata_fold`; adding a second kind without giving the first kind's
    % entries the new field would make `armings` a struct set with
    % inconsistent fields, and asking for a missing field is an error rather
    % than a false. Set explicitly on both sides.
    armEntry.is_metadata_fold = false;
    armEntry.is_response_fold = true;
    armEntry.is_syncrule_fold = false;
    armings{end+1} = armEntry;                      %#ok<AGROW>
    changedIdx(end+1)       = k;                    %#ok<AGROW>
    changedPrimaryId{end+1} = armEntry.primary_id;  %#ok<AGROW>
    changedArming(end+1)    = numel(armings);       %#ok<AGROW>
end
% ===========================================================================
% THE THIRD ARMED FOLD -- `syncrule_mapping` (#60, the clock-alignment endpoints)
% ===========================================================================
% WHY A SEPARATE LOOP, AGAIN. Same reasoning as the response block above -- the
% table generalises, the loop does not -- and this fold differs on FOUR things
% AND a fifth the other two do not have:
%
%     source class    stimulus_response_scalar   vs syncrule_mapping
%     epoch string    element_epochid (ONE)      vs TWO, one per endpoint node
%     primary class   harmonic_component_calculation vs clock_alignment
%     counters        response_*                 vs syncrule_*
%     edges stamped   ONE (epoch_id)             vs TWO (epoch_id_1, epoch_id_2)
%
% THE TWO ENDPOINTS. A did_v1 syncrule_mapping relates the clocks of TWO epochs
% (epochnode_a / epochnode_b). Branch 1 of its migrator is gated on BOTH endpoint
% epoch documents existing (syncrule_mapping.m/epochDocIds reads `epoch_id_1` and
% `epoch_id_2`), so this loop must resolve two (session, string) pairs and stamp
% two edges. Either endpoint unresolved => no fold, for the same reason the other
% folds refuse a single missing epoch: relative_reference.relative_to is REQUIRED,
% and a clock_alignment naming a reference whose referent is empty is the
% invented-empty-edge pattern the sync cluster's sign-off REMOVED (the phantom
% `epochid`, 5,316 documents, 100% empty).
%
% THE EPOCH STRINGS ARE THE ENDPOINTS' OWN, and they are NOT minted by this
% document. did2.validate.epochStrings returns the syncrule endpoints in its
% DECLINED bucket, not HITS, so the mint loop above never made an epoch from
% them; the endpoint epochs exist only because the element_epoch / ingested
% documents that share those strings minted them. If nothing else in the batch
% carried the string, `epochIdByKey` has no entry and this loop refuses -- which
% is correct: there is no epoch to anchor to.
for k = 1:n
    if strcmp(rows(k).class_name, 'clock_alignment')
        % A re-run -- find-or-create, as the two folds above. The armed branch
        % emitted a clock_alignment last time; do not re-fold it.
        report.syncrule_already_folded = report.syncrule_already_folded + 1;
        continue;
    end
    if ~strcmp(rows(k).class_name, 'syncrule_mapping'); continue; end
    report.syncrule_seen = report.syncrule_seen + 1;
    % BOTH endpoint strings, read off the (possibly reshaped) passthrough body.
    [esA, esB] = syncEndpointEpochStrings(bodies{k});
    if isempty(esA) || isempty(esB)
        report.syncrule_refused_no_epoch_string = ...
            report.syncrule_refused_no_epoch_string + 1;
        continue;
    end
    % SAME session key the mint used: rows(k).session_id (this document's
    % base.session_id), paired with each endpoint's epoch string.
    keyA = pairKey(rows(k).session_id, esA);
    keyB = pairKey(rows(k).session_id, esB);
    if ~isKey(epochIdByKey, keyA) || ~isKey(epochIdByKey, keyB)
        report.syncrule_refused_no_epoch_document = ...
            report.syncrule_refused_no_epoch_document + 1;
        continue;
    end
    b = setDep(bodies{k}, 'epoch_id_1', epochIdByKey(keyA));
    b = setDep(b, 'epoch_id_2', epochIdByKey(keyB));
    report.syncrule_edges_stamped = report.syncrule_edges_stamped + 1;
    migrator = armingMigratorFor(armingMigrators, 'syncrule_mapping');
    offered = normaliseArmingOutput(migrator(b));
    nOffered = numel(offered);
    report.arming_calls          = report.arming_calls + 1;
    report.arming_bodies_offered = report.arming_bodies_offered + nOffered;
    report.arming_extra_bodies_offered = ...
        report.arming_extra_bodies_offered + max(0, nOffered - 1);
    if nOffered > report.arming_max_bodies_per_call
        report.arming_max_bodies_per_call = nOffered;
    end
    if nOffered > 1
        report.arming_calls_returning_multiple = ...
            report.arming_calls_returning_multiple + 1;
    end
    % Primary is `clock_alignment`: jClockAlignmentBodies preserves base.id from
    % the source (align.base.id <- preBody.base.id), so id-preservation holds and
    % the syncgraph_id / syncrule_id edges into it still resolve.
    [safe, why, unchecked] = armingIsSafe(offered, ...
        'clock_alignment', rows(k).doc_id, ...
        checkEdgeDeclaration, edgeIndex, edgeMemo);
    report.arming_edge_declaration_unchecked = ...
        report.arming_edge_declaration_unchecked + unchecked;
    if ~safe
        switch why
            case 'declined'
                % The migrator's OTHER guards fired -- no polynomial, a 'no_time'
                % clock, a non-finite extent, or a missing syncgraph_id /
                % syncrule_id -- and branch 1 returned {} so branch 2 handed back
                % the passthrough (class syncrule_mapping, not clock_alignment).
                % It is the authority; this loop only supplies the epochs. The
                % stamped edges are dropped with the body, so the passthrough is
                % byte-identical to no-op.
                report.syncrule_refused_migrator_declined = ...
                    report.syncrule_refused_migrator_declined + 1;
                report.arming_bodies_dropped_declined = ...
                    report.arming_bodies_dropped_declined + nOffered;
            case 'id_not_preserved'
                report.syncrule_refused_unsafe_output = ...
                    report.syncrule_refused_unsafe_output + 1;
                report.arming_bodies_dropped_id_not_preserved = ...
                    report.arming_bodies_dropped_id_not_preserved + nOffered;
            case 'undeclared_edge'
                report.syncrule_refused_unsafe_output = ...
                    report.syncrule_refused_unsafe_output + 1;
                report.arming_bodies_dropped_undeclared_edge = ...
                    report.arming_bodies_dropped_undeclared_edge + nOffered;
            otherwise
                error('did2:convert:epochMint:unknownRefusal', ...
                    ['armingIsSafe returned refusal "%s", which no counter ' ...
                     'names. Add the counter; do not widen an existing ' ...
                     'one.'], why);
        end
        % SAME REASON AS THE OTHER TWO BLOCKS: a refusal `continue`s before the
        % `armings{end+1}` append, so without this line a refused fold would be
        % counted in `syncrule_refused_*` and then vanish from the
        % emitted/withheld pair that `syncrule_seen` is reconciled against.
        report.syncrule_folds_withheld = report.syncrule_folds_withheld + 1;
        continue;
    end
    bodies{k} = offered{1};
    extraIds  = cell(1, nOffered - 1);
    for e = 2:nOffered
        extraBodies{end+1} = offered{e};        %#ok<AGROW>
        extraIds{e-1}      = baseIdOf(offered{e});
    end
    armEntry = struct();
    armEntry.index            = k;
    armEntry.primary_id       = baseIdOf(offered{1});
    armEntry.extra_ids        = extraIds;
    armEntry.body_count       = nOffered;
    % ENDPOINT A represents "an armed epoch is in the batch" for the carry loop's
    % epoch-lost guard. One epoch_id per arming entry, and endpoint A is chosen
    % arbitrarily: if endpoint B's epoch quarantined the run already fails the
    % 0-quarantine gate, exactly as the existing single-epoch tolerance assumes.
    armEntry.epoch_id         = epochIdByKey(keyA);
    armEntry.is_metadata_fold = false;
    armEntry.is_response_fold = false;
    armEntry.is_syncrule_fold = true;
    armings{end+1} = armEntry;                      %#ok<AGROW>
    changedIdx(end+1)       = k;                    %#ok<AGROW>
    changedPrimaryId{end+1} = armEntry.primary_id;  %#ok<AGROW>
    changedArming(end+1)    = numel(armings);       %#ok<AGROW>
end

report.arming_vacuous = (report.arming_calls == 0);
report.metadata_refused_total = report.metadata_refused_no_epoch_string ...
    + report.metadata_refused_no_epoch_document ...
    + report.metadata_refused_migrator_declined ...
    + report.metadata_refused_unsafe_output;
report.metadata_fold_vacuous = (report.metadata_ingested_seen == 0);
report.response_refused_total = report.response_refused_no_epoch_string ...
    + report.response_refused_no_epoch_document ...
    + report.response_refused_migrator_declined ...
    + report.response_refused_unsafe_output;
report.response_fold_vacuous = (report.response_scalar_seen == 0);
report.syncrule_refused_total = report.syncrule_refused_no_epoch_string ...
    + report.syncrule_refused_no_epoch_document ...
    + report.syncrule_refused_migrator_declined ...
    + report.syncrule_refused_unsafe_output;
report.syncrule_fold_vacuous = (report.syncrule_seen == 0);

report.epochs_minted = numel(minted);
report.epoch_index = indexRows;
if isempty(minted) && isempty(changedIdx)
    % Nothing to re-fold. Every body an armed migrator offered was refused
    % before this point, so all of them are dropped and the arithmetic must say
    % so rather than reading 0 dropped over an unstated denominator.
    report.arming_bodies_dropped = report.arming_bodies_offered;
    report.epoch_index_report = edgeIndex.report;
    result.epoch_mint = report;
    return;
end

% --- pad + validate, through the same door every other pass uses ----------
% The bodies are tagged schema_version == TargetVersion, so v1_to_v2
% short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate. A body
% that cannot validate lands in `quarantine` and is NOT emitted -- loudly, on a
% 0-quarantine gate, which is the correct volume for a builder that produced an
% invalid document.
% `extraBodies` -- bodies 2..N of every armed call -- go through the SAME door.
% They are new documents, so they are appended rather than replacing anything,
% but they must be validated exactly like a mint: an unvalidated extra is a
% document nobody checked, referenced by a document that did validate.
rebuildIn = [bodies(changedIdx), extraBodies, minted];
out = did2.convert.v1_to_v2(rebuildIn, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);

report.mint_quarantined = numel(out.quarantine);
if ~isempty(out.quarantine)
    if isfield(result, 'quarantine') && ~isempty(result.quarantine)
        result.quarantine = [result.quarantine, out.quarantine];
    else
        result.quarantine = out.quarantine;
    end
end

% POSITION IS NO LONGER USABLE AND THE OLD COMMENT SAYING IT WAS IS GONE. It
% read "this batch is 1 -> 1 throughout", which was true only while the single
% armed migrator returned one body; an armed call returning N puts N entries
% into `rebuildIn` for one entry of `changedIdx`. Matching is on base.id, which
% was already the fallback and is now the only rule.
producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(out.migrated)
    try
        producedById(char(out.migrated{k}.get('base.id'))) = k;
    catch
        % a produced body with no readable id cannot be matched; it is still
        % counted in out.migrated and appended below if it is a mint.
    end
end

% --- decide each armed call, ALL OR NOTHING -------------------------------
% An armed migrator's bodies reference each other -- the leaf's
% `time_reference_1` names the anchor it minted alongside it -- so carrying the
% primary while an extra quarantined would emit a document pointing at one that
% is not in the batch. That is an ORPHAN, and the corpus digest prints no orphan
% counter (open item #95), so nothing downstream would say so. They live or die
% together, and the refusal is COUNTED in whole bodies so `offered - carried`
% closes.
armingCarried = false(1, numel(armings));
for a = 1:numel(armings)
    ar = armings{a};
    alive = ~isempty(ar.primary_id) && isKey(producedById, ar.primary_id);
    for e = 1:numel(ar.extra_ids)
        alive = alive && ~isempty(ar.extra_ids{e}) ...
            && isKey(producedById, ar.extra_ids{e});
    end
    if ~alive
        report.arming_bodies_dropped_not_rebuilt = ...
            report.arming_bodies_dropped_not_rebuilt + ar.body_count;
        continue;
    end
    % The epoch this call was armed FOR must itself be in the batch. A minted
    % epoch that failed validation is not a document anything may point at, and
    % `acquisition_metadata_file.epoch_id` is REQUIRED, so carrying the fold
    % anyway would emit a required edge naming a document nobody can resolve.
    if ~isempty(ar.epoch_id) && ~isKey(producedById, ar.epoch_id) ...
            && ~isKey(foundExistingIds, ar.epoch_id)
        report.arming_bodies_dropped_epoch_lost = ...
            report.arming_bodies_dropped_epoch_lost + ar.body_count;
        continue;
    end
    armingCarried(a) = true;
end

for j = 1:numel(changedIdx)
    armIdx = changedArming(j);
    if armIdx > 0 && ~armingCarried(armIdx)
        continue;   % refused: docs{k} keeps the ORIGINAL passthrough document
    end
    id = changedPrimaryId{j};
    if isempty(id) || ~isKey(producedById, id); continue; end
    docs{changedIdx(j)} = out.migrated{producedById(id)};
    if armIdx > 0
        report.arming_bodies_carried = report.arming_bodies_carried + 1;
    elseif ~isempty(rows(changedIdx(j)).class_name) ...
            && strcmp(rows(changedIdx(j)).class_name, 'method_parameters')
        % MEASURED, NOT REPAIRED, and deliberately so. `method_parameters.epoch_id`
        % is OPTIONAL, so an epoch that quarantined leaves this body carrying an
        % edge to a document not in the batch -- an orphan. That path predates
        % this rebuild and changing it would change a current result, so it is
        % counted here and left for the team. It is reachable only when a mint
        % quarantined, which is already a 0-quarantine gate failure.
        eid = depValueOf(bodies{changedIdx(j)}, 'epoch_id');
        if ~isempty(eid) && ~isKey(producedById, eid) ...
                && ~isKey(foundExistingIds, eid)
            report.method_parameters_epoch_not_in_batch = ...
                report.method_parameters_epoch_not_in_batch + 1;
        end
    end
end

% --- append bodies 2..N of every carried call -----------------------------
% THE HALF THAT DID NOT EXIST BEFORE. Without this loop an armed migrator's
% minted references are built, validated, and then dropped on the floor.
for a = 1:numel(armings)
    if ~armingCarried(a); continue; end
    ar = armings{a};
    for e = 1:numel(ar.extra_ids)
        docs{end+1} = out.migrated{producedById(ar.extra_ids{e})}; %#ok<AGROW>
        report.arming_extra_bodies_carried = ...
            report.arming_extra_bodies_carried + 1;
        report.arming_bodies_carried = report.arming_bodies_carried + 1;
    end
end
report.arming_bodies_dropped = ...
    report.arming_bodies_offered - report.arming_bodies_carried;

% THE FOLD'S OWN DENOMINATOR, split by what actually landed. A fold that
% quarantined leaves `docs{k}` holding the ORIGINAL passthrough document, so
% nothing is lost -- but nothing was gained either, and the two must not print
% the same. `withheld` is the count of documents that stayed did_v1 despite
% having an epoch to point at, and it is exactly the number a 0-quarantine gate
% failure should be read against. Read off the CARRY DECISION rather than off
% `producedById` alone: a fold whose primary validated but whose sibling did not
% is withheld, and asking only whether the primary came back would call it
% emitted.
for a = 1:numel(armings)
    if armings{a}.is_metadata_fold
        if armingCarried(a)
            report.metadata_ingested_folds_emitted = ...
                report.metadata_ingested_folds_emitted + 1;
        else
            report.metadata_ingested_folds_withheld = ...
                report.metadata_ingested_folds_withheld + 1;
        end
    elseif armings{a}.is_response_fold
        % THE SAME READ FOR THE SECOND FOLD, and for the same stated reason:
        % after the rebuild `docs{k}` holds either the folded document or the
        % original passthrough, so the CLASS cannot tell an emitted fold from a
        % withheld one. The carry decision can.
        if armingCarried(a)
            report.response_scalar_folds_emitted = ...
                report.response_scalar_folds_emitted + 1;
        else
            report.response_scalar_folds_withheld = ...
                report.response_scalar_folds_withheld + 1;
        end
    elseif armings{a}.is_syncrule_fold
        % THE SAME READ FOR THE THIRD FOLD. A carried call means the
        % clock_alignment (and its two relative_reference endpoints) reached the
        % batch; a withheld one means the syncrule_mapping passthrough stayed.
        if armingCarried(a)
            report.syncrule_folds_emitted = ...
                report.syncrule_folds_emitted + 1;
        else
            report.syncrule_folds_withheld = ...
                report.syncrule_folds_withheld + 1;
        end
    end
    % NO `else` BRANCH, DELIBERATELY: a FOURTH fold kind added without a reader
    % here would be silently uncounted, so the invariant is asserted in
    % testEpochMintResponseArming rather than guessed at with a catch-all that
    % would attribute it to whichever counter came last.
end
mintedIds = cellfun(@(b) b.base.id, minted, 'UniformOutput', false);
emitted = 0;
for j = 1:numel(mintedIds)
    if isKey(producedById, mintedIds{j})
        docs{end+1} = out.migrated{producedById(mintedIds{j})}; %#ok<AGROW>
        emitted = emitted + 1;
    end
end
report.epochs_minted = emitted;

% --- append the epoch-extent references (#60 option A) ---------------------
% Same shape as the mint append directly above, and for the same reason: a
% document that survived the re-fold must be EMITTED, not merely validated.
% A reference that did NOT survive is counted rather than passed over --
% `time_reference_#` is optional (min_count 0), so a dangling edge does not fail
% validation and would otherwise be silent. The corpus gate is 0-quarantine, so
% any loss here already fails the run loudly; this counter says WHICH loss.
for j = 1:numel(extentRefIds)
    if isKey(producedById, extentRefIds{j})
        docs{end+1} = out.migrated{producedById(extentRefIds{j})}; %#ok<AGROW>
    else
        report.epoch_extent_references_lost = ...
            report.epoch_extent_references_lost + 1;
    end
end
% Keep the index honest: an epoch that did not survive validation is not an
% epoch anything may point at. Entries that were FOUND (already in the batch)
% were never rebuilt, so they are kept unconditionally; only the minted ones are
% filtered on whether they came back out of the re-fold.
if emitted < numel(mintedIds)
    mintedSet = containers.Map(mintedIds, num2cell(1:numel(mintedIds)));
    keep = true(1, numel(indexRows));
    for j = 1:numel(indexRows)
        eid = indexRows(j).epoch_document_id;
        if isKey(mintedSet, eid) && ~isKey(producedById, eid)
            keep(j) = false;
        end
    end
    report.epoch_index = indexRows(keep);
end

result.migrated = docs;
result.summary = recountSummary(result);
% The schema authority's own counters, carried out with the report so
% `arming_edge_declaration_unchecked` can be read against WHY it could not look:
% `schema_lookups_unavailable` (no cache at all) and `schema_lookups_failed`
% (the chain lookup threw) are different problems with different owners.
report.epoch_index_report = edgeIndex.report;
result.epoch_mint = report;
end

% ===================== builders ========================================

function body = mintEpoch(epochString, sessionId, sessionDocumentId, datestamp)
%MINTEPOCH One `epoch ⊂ entity` body.
%   `local_identifier` is declared ON epoch and REQUIRED (build_v_eta.py's #60
%   block): `entity` deliberately declares none so a child can ADD it as
%   required, the same reason `subject` does. The v1 epoch string IS that
%   handle -- 30 live NDI sites match it by exact_string.
%
%   NO `time_reference_#` and NO `instrument_id` are emitted. Both are optional,
%   and neither can be populated from the epoch string alone: the per-clock
%   extents live in `daqreader_epochdata_ingested.epochtable` and the recording
%   device needs the daq graph (#59). An edge emitted empty is the defect, not a
%   placeholder.
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
body = struct();
body.document_class = struct( ...
    'class_name',     'epoch', ...
    'class_version',  '1.0.0', ...
    'superclasses',   struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', 'session_id', 'value', sessionDocumentId);
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_epoch', 'creation_timestamp', datestamp);
body.epoch = struct('local_identifier', epochString);
end

% ===================== the arming path =================================

function tbl = defaultArmingMigrators()
%DEFAULTARMINGMIGRATORS SOURCE CLASS -> the migrator this pass re-runs armed.
%   THREE ROWS. It said TWO ROWS until `syncrule_mapping` was armed (#60, the
%   clock-alignment endpoints), and read ONE ROW before that -- each superseded
%   count kept in the note that withdrew it (HISTORICAL-BUILD-CLAIM). An earlier
%   paragraph said "ONE ROW TODAY, and the reason there is only one is a SCHEMA
%   fact" and listed `stimulus_response_scalar` among the classes that could not
%   be armed. THAT REASONING WAS SOUND FOR THE TWO daqreader ARMS AND WRONG FOR
%   THIS ONE, and the distinction is worth stating because it is not visible
%   from the schema alone.
%
%   THE `syncrule_mapping` ROW is the same shape as `stimulus_response_scalar`:
%   its armed branch 1 (jClockAlignmentBodies) emits a `clock_alignment` plus two
%   `relative_reference` bodies whose edges are set BY NAME -- it never copies
%   `preBody.depends_on`, so the transient `epoch_id_1` / `epoch_id_2` this pass
%   stamps CANNOT reach an emitted body, and `armingIsSafe`'s `undeclared_edge`
%   refusal therefore cannot fire on a FOLDED document. It DOES fire on the
%   branch-2 passthrough (which returns the stamped body), leaving it exactly as
%   it is today. Unlike the other folds this one stamps TWO endpoint edges (one
%   per epochnode) rather than one, because a mapping anchors two epochs.
%
%   WHAT THE SCHEMA SAYS, re-derived 2026-08-17 over the built tree (249 JSON
%   files, 243 with a document_class, deps read by JSON path rather than by
%   grep): exactly FOUR classes declare an `epoch_id` dependency --
%   acquisition_metadata_file, ingestion_manifest, directed_relation,
%   method_parameters. Unchanged from the 2026-08-12 reading, and
%   `harmonic_component_calculation` is NOT among them.
%
%   WHY THAT DOES NOT BLOCK THIS ROW. The refusal exists to stop a body being
%   PERSISTED with an `epoch_id` its class does not declare. The two daqreader
%   arms RETURN THE STAMPED PRE-BODY, so for them the schema is decisive. The
%   stimulus_response_scalar FOLD does not: it emits a leaf and an anchor whose
%   edges are set BY NAME and never copies `preBody.depends_on` wholesale, so
%   the stamp cannot reach either emitted body. Derived by enumerating every
%   `depends_on` write on that path in +migrators_j/stimulus_response_scalar.m's
%   own header, which states the conclusion and explicitly declines to act on
%   it: "Adding a row to epochMint's arming table is #60's build and that
%   file's owner's call; nothing here arms anything."
%
%   THE GUARD STILL COVERS THE OTHER HALF. That migrator's four guard paths
%   return `{preBody}`, which DOES carry the stamp, on a class that does not
%   declare the edge -- so `armingIsSafe` refuses them as `undeclared_edge` and
%   the document keeps the passthrough it has today. The refusal is not being
%   worked around; it is doing exactly its job on the arm where it applies.
%
%   Adding a row for either daqreader arm before its schema increment lands is
%   still caught by that refusal, which reads the schema rather than this list.
tbl = struct( ...
    'daqmetadatareader_epochdata_ingested', ...
        @did2.convert.migrators_j.daqmetadatareader_epochdata_ingested, ...
    'stimulus_response_scalar', ...
        @did2.convert.migrators_j.stimulus_response_scalar, ...
    'syncrule_mapping', ...
        @did2.convert.migrators_j.syncrule_mapping);
end

function fcn = armingMigratorFor(tbl, sourceClass)
%ARMINGMIGRATORFOR The handle for one source class, or an error.
%   ERRORS rather than falling back to the production migrator. A caller that
%   overrode the table meant to override it, and quietly running the real
%   migrator instead would make a test that thinks it is driving the 1 -> N path
%   pass while driving the 1 -> 1 one -- a green result from machinery that
%   never ran, which is this file's own recurring failure.
if ~isstruct(tbl) || ~isfield(tbl, sourceClass)
    error('did2:convert:epochMint:noArmingMigrator', ...
        ['ArmingMigrators carries no entry for "%s". The table must name ' ...
         'every source class this pass arms.'], sourceClass);
end
fcn = tbl.(sourceClass);
end

function bodies = normaliseArmingOutput(out)
%NORMALISEARMINGOUTPUT A migrator's return as a CELL OF BODIES, N >= 0.
%   Same contract as did2.convert.v1_to_v2/normaliseMigratorOutput -- a struct
%   array is N bodies, a cell is N bodies, a scalar struct is one -- so an armed
%   re-run reads a migrator's output exactly the way pass 1 does. The old code
%   here unwrapped a 1-cell and treated everything else as a failure, which is
%   why a 1 -> N migrator would have lost every body after the first.
%   An unrecognised return is EMPTY, not an error: the caller reports it as a
%   refusal and keeps the passthrough, which is the safe reading of "the
%   migrator did not give me documents".
if iscell(out)
    bodies = out(:)';
elseif isstruct(out)
    bodies = cell(1, numel(out));
    for k = 1:numel(out)
        bodies{k} = out(k);
    end
else
    bodies = {};
end
end

function [declares, checkable] = declaresEpochEdge(edgeIndex, memo, className)
%DECLARESEPOCHEDGE Does CLASSNAME declare `epoch_id`, and could we even look?
%   did2.convert.epochIndex/classDeclaresEpochEdge answers FALSE for both "no"
%   and "could not check", which is right for a writer guard and wrong for a
%   caller that must tell them apart. It does keep the two apart in its report,
%   so the delta on `schema_lookups_unavailable + schema_lookups_failed` is the
%   discriminator -- but ONLY ON THE FIRST CALL for a class: the `failed` branch
%   MEMOISES its false (epochIndex.m:333), so the counter never moves again and
%   a second look would read "the schema said no". Hence this memo, which
%   records -1 for uncheckable and is consulted before the delta ever is.
declares  = false;
checkable = true;
if isempty(className)
    return;     % a body with no class name cannot be checked against a schema
end
if isKey(memo, className)
    v = memo(className);
    checkable = (v >= 0);
    declares  = (v == 1);
    return;
end
before = edgeIndex.report.schema_lookups_unavailable ...
    + edgeIndex.report.schema_lookups_failed;
tf = edgeIndex.classDeclaresEpochEdge(className);
after = edgeIndex.report.schema_lookups_unavailable ...
    + edgeIndex.report.schema_lookups_failed;
if after > before
    checkable = false;
    memo(className) = -1;
    return;
end
declares = tf;
memo(className) = double(tf);
end

function [safe, why, unchecked] = armingIsSafe(offered, primaryClass, ...
        originalId, checkDeclaration, edgeIndex, edgeMemo)
%ARMINGISSAFE May this armed call's bodies be carried into the batch?
%   Returns SAFE false plus a named WHY, and UNCHECKED counts the bodies whose
%   edge declaration could not be consulted (see the caller for when that is).
%
%   THE THREE REFUSALS, in the order they are asked:
%     declined          the migrator's own guards fired and it did not produce
%                       the target class. It is the authority on that.
%     id_not_preserved  the primary does not carry the source's `base.id`.
%                       Replacing docs{k} with it would delete that id from the
%                       batch and dangle every inbound reference -- the
%                       11,448-orphan dissolution failure, arriving as a fold.
%     undeclared_edge   some returned body would PERSIST an `epoch_id` on a
%                       class that does not declare it. Nothing else catches
%                       this: did2.schema.cache:761 puts `depends_on` in
%                       `allowedTop` wholesale, so an undeclared edge NAME
%                       validates clean. This is the guard that keeps the two
%                       daqreader arms -- which return their stamped pre-body --
%                       from being armed before their schema increment lands.
safe = false;
why  = '';
unchecked = 0;
if isempty(offered)
    why = 'declined';
    return;
end
primary = offered{1};
if ~isstruct(primary) || ~isscalar(primary) ...
        || ~strcmp(classNameOf(primary), primaryClass)
    why = 'declined';
    return;
end
if ~strcmp(baseIdOf(primary), originalId)
    why = 'id_not_preserved';
    return;
end
for k = 1:numel(offered)
    b = offered{k};
    if ~isstruct(b) || ~isscalar(b)
        why = 'declined';
        return;
    end
    if isempty(depValueOf(b, 'epoch_id')); continue; end
    if ~checkDeclaration
        unchecked = unchecked + 1;
        continue;
    end
    % "THE SCHEMA SAID NO" AND "THE SCHEMA COULD NOT BE CONSULTED" ARE NOT THE
    % SAME ANSWER. Refusing on the second would make the fold depend on whether
    % a schema path happened to resolve -- a configuration difference changing
    % the DATA. A lookup that could not be made is counted as UNCHECKED and does
    % not refuse; only a schema that answered NO refuses.
    [declares, checkable] = declaresEpochEdge(edgeIndex, edgeMemo, classNameOf(b));
    if ~checkable
        unchecked = unchecked + 1;
        continue;
    end
    if ~declares
        why = 'undeclared_edge';
        return;
    end
end
safe = true;
end

% ===================== readers =========================================

function id = baseIdOf(b)
%BASEIDOF `base.id` off a body STRUCT, '' when it has none.
id = '';
if ~isstruct(b) || ~isscalar(b); return; end
id = baseField(b, 'id');
end

function k = pairKey(sessionId, epochString)
%PAIRKEY The mint key -- DELEGATED, no longer a copy.
%   This was the FIRST of four byte-identical hand-rolled copies
%   (did2.convert.resolveValidIntervals/pairKey,
%   did2.validate.epochStringRetention/pairKey, and
%   did2.convert.epochIndex.pairKey, whose header calls itself "the ONE
%   implementation any NEW consumer must use" and records the removal of the
%   other three as follow-up). This is that follow-up, for one of them: the
%   body is gone and the call goes to the shared static. A key that differs
%   between the writer and the reader resolves to nothing while looking like a
%   data problem, and four copies is four chances for that.
k = did2.convert.epochIndex.pairKey(sessionId, epochString);
end

function cn = classNameOf(b)
cn = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

% EPOCHSTRINGOF -- DELETED 2026-08-10. It was the SECOND of three epoch-string
% readers in this toolbox, each with a different blind spot, and its own was the
% stimulus-response family: `stimulus_response_scalar` does NOT carry the
% `epochid` superclass (template superclasses are base + stimulus_response), so
% neither of its two epoch strings could ever be seen here. The reader now lives
% in did2.validate.epochStrings, which NAMES every source it reads and every
% source it declines, and is pinned source-by-source by
% tests/+did2/+unittest/testEpochStrings.m.

function v = valueForSource(values, sources, wanted)
%VALUEFORSOURCE The epoch string a NAMED reader source contributed, '' if none.
v = '';
for k = 1:numel(sources)
    if strcmp(sources{k}, wanted)
        v = values{k};
        return;
    end
end
end

function [esA, esB] = syncEndpointEpochStrings(body)
%SYNCENDPOINTEPOCHSTRINGS The two endpoint epoch-id strings of a syncrule_mapping.
%   Reads them off a (possibly reshaped) `syncrule_mapping` body. did_v1 stores
%   each endpoint's id flat at `epochnode_a.epoch_id`; +migrators_j/syncrule_mapping.m's
%   #58 passthrough reshape nests it under `epochnode_a.time_reference.epoch_id`.
%   Try the reshaped location first, then the flat one, with the camelCase
%   fallbacks the nested-read rule calls for (universalRenames snake_cases only
%   the IMMEDIATE fields of a property block, so these deeper fields keep raw v1
%   casing on a body that never went through it). Returns ('', '') when the block
%   or a node is absent. Same declined-source read as did2.validate.epochStrings,
%   split per-endpoint because the mapping's own gate needs one answer per node.
esA = '';
esB = '';
if ~isstruct(body) || ~isscalar(body) ...
        || ~isfield(body, 'syncrule_mapping') || ~isstruct(body.syncrule_mapping) ...
        || ~isscalar(body.syncrule_mapping)
    return;
end
sm = body.syncrule_mapping;
esA = endpointEpochString(sm, {'epochnode_a', 'epochNodeA'});
esB = endpointEpochString(sm, {'epochnode_b', 'epochNodeB'});
end

function es = endpointEpochString(sm, nodeNames)
%ENDPOINTEPOCHSTRING One endpoint's epoch-id string, '' if the node is absent.
es = '';
node = [];
for j = 1:numel(nodeNames)
    if isfield(sm, nodeNames{j}) && isstruct(sm.(nodeNames{j})) ...
            && isscalar(sm.(nodeNames{j}))
        node = sm.(nodeNames{j});
        break;
    end
end
if isempty(node); return; end
% the #58 passthrough reshape nests it one level down, under time_reference
for trName = {'time_reference', 'timeReference'}
    if isfield(node, trName{1}) && isstruct(node.(trName{1})) ...
            && isscalar(node.(trName{1}))
        es = charField(node.(trName{1}), {'epoch_id', 'epochId', 'epochID', 'epochid'});
        if ~isempty(es); return; end
    end
end
% a raw did_v1 (unreshaped) body carries it flat on the node
es = charField(node, {'epoch_id', 'epochId', 'epochID', 'epochid'});
end

function rowsOut = perSourceCounts(epochValues, epochSources)
%PERSOURCECOUNTS {source, documents, distinct_strings} for every source SEEN.
%   Sources with no hits do not appear -- the reader's own header is the list of
%   what exists, and a caller comparing the two learns which sources this batch
%   simply has no documents for.
%   Plain parallel arrays, NOT a containers.Map. The source list is bounded by
%   the reader's own header (six today), so a linear scan costs nothing -- and
%   `map(key) = {}` on a ValueType 'any' Map is the kind of construct that reads
%   as an initialisation and can behave as a deletion. Not worth the risk in a
%   counter whose whole purpose is to be believed.
rowsOut = struct('source', {}, 'documents', {}, 'distinct_strings', {});
order     = {};
docCounts = [];
valLists  = {};
for k = 1:numel(epochSources)
    seenHere = {};
    for j = 1:numel(epochSources{k})
        s = epochSources{k}{j};
        idx = find(strcmp(order, s), 1);
        if isempty(idx)
            order{end+1}     = s;    %#ok<AGROW>
            docCounts(end+1) = 0;    %#ok<AGROW>
            valLists{end+1}  = {};   %#ok<AGROW>
            idx = numel(order);
        end
        if ~any(strcmp(seenHere, s))
            docCounts(idx) = docCounts(idx) + 1;
            seenHere{end+1} = s; %#ok<AGROW>
        end
        valLists{idx}{end+1} = epochValues{k}{j};
    end
end
for k = 1:numel(order)
    rowsOut(end+1) = struct('source', order{k}, ...
        'documents', docCounts(k), ...
        'distinct_strings', numel(unique(valLists{k}))); %#ok<AGROW>
end
end

% ===================== #2 "measure first" instrument ===================

function report = measureIngestionProbemap(report, rows, bodies, n)
%MEASUREINGESTIONPROBEMAP #2 "measure first" (team, 2026-08-20). REPORT-ONLY.
%
%   Fills the `probemap_*`, `recording_obs_*` and `overlap_*` fields of REPORT
%   and CHANGES NOTHING ELSE. It mints no document, folds nothing and stamps no
%   edge -- it reads the snapshots `rows` / `bodies` this pass already took of
%   the incoming batch and counts. Same stance as `pairs_minus_strings`: an
%   observation, not a conversion. The two numbers it produces are the inputs to
%   the `epochfiles_ingested.epochprobemap` decomposition decision (#60 option B,
%   still open), so they are gathered on the next corpus run BEFORE the fold is
%   designed rather than after.
%
%   ---------------------------------------------------------------------
%   MEASUREMENT 1 -- PROBES-PER-EPOCH (the fold's 1 -> N fan-out)
%   ---------------------------------------------------------------------
%   `epochfiles_ingested` is a guarded PASSTHROUGH (+migrators_j/epochfiles_ingested.m),
%   so it reaches this batch as a did_v1 body whose block `epochfiles_ingested`
%   carries `{epoch_id, epochprobemap, files}`. `epochprobemap` is the char
%   serialize() of an ndi.epoch.epochprobemap_daqsystem array. CONFIRMED from the
%   writer, NDI origin/main src/ndi/+ndi/+epoch/epochprobemap_daqsystem.m
%   serialize() (:136-168):
%
%       s = '';                              % header line, then one line/probe
%       fn = {'name','reference','type','devicestring','subjectstring'};
%       <join fn by sprintf('\t')>, sprintf('\n')      % HEADER, tab-delimited
%       for each probe:  <join the 5 field values by '\t'>, sprintf('\n')
%
%   so the shape is a HEADER line `name<TAB>reference<TAB>type<TAB>devicestring
%   <TAB>subjectstring` then ONE '\n'-terminated line per probe. `reference` is
%   int2str'd; every other column is the raw string. The PROBE-ROW COUNT is the
%   data-line count (all lines after the header). Note an EMPTY probemap object
%   still serialises to the header line alone -- a non-empty string with ZERO
%   data rows -- which is why `probemap_docs_zero_rows` is counted apart from
%   `probemap_empty` (an absent / '' field).
%
%   PARSED DEFENSIVELY. carryProbeMap (+migrators_j/syncrule_mapping.m:194-253)
%   records that the field is USUALLY a char but CAN be a struct, and the
%   template default is '' -- so `probemap_empty`, `probemap_struct_shape` and
%   `probemap_char_shape` partition the seen documents, and only the char shape
%   is parsed for rows (a struct cannot be counted without the writer's
%   serialize(), and guessing would be the distance_metadata wrong-shape bug).
%   `probemap_unrecognized_header` flags a char whose first line is NOT the
%   5-column header the writer always emits; on that anomaly every non-empty line
%   is counted as a probe row rather than silently dropping a real one.
%
%   ---------------------------------------------------------------------
%   MEASUREMENT 2 -- #30-OBSERVATION OVERLAP: WHAT IS AND IS NOT COMPUTABLE HERE
%   ---------------------------------------------------------------------
%   The decision is "mint NEW per-epoch observations from the probemap" vs
%   "attach the probemap's attribution to the #30 recording-observations that
%   already exist". The literal question -- would a per-epoch probemap
%   observation DUPLICATE a #30 observation of the same (subject, EPOCH) -- has a
%   structural answer that this instrument makes explicit rather than assumes:
%
%     A #30 recording-observation (+migrators_j/private/jRecordingObservation.m,
%     driven from +migrators_j/element.m:144-148) is emitted ONE PER ELEMENT with
%     a SESSION 'during' anchor -- jSessionAnchor(preBody,'during'), a
%     `session_relative_reference` -- NEVER an epoch anchor. Its own header says
%     so: "one observation per element is emitted, with the shared session
%     'during' anchor -- coarse but true. Per-epoch observations are the second
%     pass" (:108-118). This pass runs BEFORE resolveSessionAnchors
%     (runCorpusDiscovery.m: epoch_mint at :171, session_anchor_fold at :208), so
%     the anchor is still class `session_relative_reference` when read here.
%
%   So `recording_obs_epoch_scoped` is expected 0 -- there is NO per-epoch #30
%   observation for a per-epoch probemap observation to duplicate -- and that 0
%   is MEASURED (by resolving each observation's `time_reference_1` to the class
%   of the document it points at) rather than asserted, so a future epoch-scoped
%   observation would move it. The `recording_obs_*` block is the fully reliable
%   half: it needs no name join, only edge resolution within the batch.
%
%   WHAT IS COMPUTABLE at the (session, SUBJECT) level, and how reliably: for
%   each (session, subjectstring) the probemap attributes, does a #30
%   recording-observation already exist on that subject in that session? The join
%   is subjectstring (probemap column 5, a v1 subject local identifier) ->
%   migrated `subject` document (matched on `subject.local_identifier`) ->
%   `subject_id` edge of a #30 observation. That join's RELIABILITY is itself
%   reported -- `probemap_subject_strings_matched` / `_unmatched` is its
%   denominator -- so an unreliable match on real data is a visible number, never
%   a silent 0. `_covered` / `_uncovered` are the (session, subject) overlap over
%   the MATCHED strings only.
%
%   WHAT IS NOT COMPUTABLE HERE, stated so the gap has a shape: the true
%   per-(subject, EPOCH) overlap, because #30 carries no epoch to compare the
%   probemap's epoch against. It is not a stage limitation this hook could fix by
%   moving -- no DID-side pass emits an epoch-scoped recording-observation today
%   (that is the deferred #30 second pass) -- so the epoch-level overlap is 0
%   everywhere by construction, which `recording_obs_epoch_scoped` records.
%
%   `overlap_vacuous` is TRUE when the batch holds no epochfiles_ingested
%   document OR no #30 observation, so an all-zero overlap block cannot be read
%   as "measured and empty" when it is "nothing to compare".

report.probemap_documents_seen = 0;   % re-assigned below; declared for clarity

% ---- pre-pass: index classes, subjects and #30 observations --------------
% id -> class name (resolving a time_reference edge to its target's class), and
% subject document local_identifier <-> id (the probemap join key). Built from
% the same `rows` / `bodies` snapshots, so nothing is read twice off a document.
classById        = containers.Map('KeyType', 'char', 'ValueType', 'char');
bodyById         = containers.Map('KeyType', 'char', 'ValueType', 'any');
subjectLocalById = containers.Map('KeyType', 'char', 'ValueType', 'char');
subjectIdByLocal = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:n
    id = rows(k).doc_id;
    cn = rows(k).class_name;
    if isempty(id); continue; end
    if ~isempty(cn) && ~isKey(classById, id); classById(id) = cn; end
    if ~isKey(bodyById, id) && isstruct(bodies{k}); bodyById(id) = bodies{k}; end
    if strcmp(cn, 'subject') && isstruct(bodies{k}) ...
            && isfield(bodies{k}, 'subject') && isstruct(bodies{k}.subject)
        lid = charField(bodies{k}.subject, {'local_identifier'});
        if ~isempty(lid)
            if ~isKey(subjectLocalById, id);  subjectLocalById(id) = lid; end
            if ~isKey(subjectIdByLocal, lid); subjectIdByLocal(lid) = id; end
        end
    end
end

% (session, subject-local-id) -> a #30 recording-observation covers it. The
% marker is the assembler's OWN base.name stamp, set at exactly one site
% (jRecordingObservation.m: obs.base.name = 'migrated_recording_observation'),
% so it needs no modality-class list to maintain and is precisely the set the
% overlap question is about.
coveredSubjectSession = containers.Map('KeyType', 'char', 'ValueType', 'logical');
recSeen = 0; recSession = 0; recEpoch = 0; recUnresolved = 0;
for k = 1:n
    if ~isRecordingObservation(bodies{k}); continue; end
    recSeen = recSeen + 1;
    trId = depValueOf(bodies{k}, 'time_reference_1');
    if isempty(trId) || ~isKey(classById, trId)
        recUnresolved = recUnresolved + 1;
    elseif any(strcmp(classById(trId), ...
            {'session_relative_reference', 'session_bounded_reference'}))
        recSession = recSession + 1;
    elseif isKey(bodyById, trId) ...
            && referenceIsEpochScoped(bodyById(trId), classById)
        recEpoch = recEpoch + 1;
    else
        % an absolute_reference, or a relative_reference anchored to a session
        % DOCUMENT -- neither is epoch-scoped.
        recSession = recSession + 1;
    end
    subjId = depValueOf(bodies{k}, 'subject_id');
    if isempty(subjId) || ~isKey(subjectLocalById, subjId); continue; end
    coveredSubjectSession(pairKey(rows(k).session_id, ...
        subjectLocalById(subjId))) = true;
end
report.recording_obs_seen              = recSeen;
report.recording_obs_session_scoped    = recSession;
report.recording_obs_epoch_scoped      = recEpoch;
report.recording_obs_anchor_unresolved = recUnresolved;

% ---- the probemap loop ---------------------------------------------------
countTally          = containers.Map('KeyType', 'double', 'ValueType', 'double');
distinctSubjStrings = containers.Map('KeyType', 'char',   'ValueType', 'logical');
coveredPairs        = containers.Map('KeyType', 'char',   'ValueType', 'logical');
uncoveredPairs      = containers.Map('KeyType', 'char',   'ValueType', 'logical');
docsSeen = 0; nonEmpty = 0; emptyN = 0; charN = 0; nonCharN = 0;
unrecHeader = 0; rowsTotal = 0; docsWithRows = 0; docsZeroRows = 0;
rowMin = Inf; rowMax = 0; attributions = 0;
for k = 1:n
    if ~strcmp(rows(k).class_name, 'epochfiles_ingested'); continue; end
    docsSeen = docsSeen + 1;
    pm = probemapField(bodies{k});
    if isempty(pm)
        emptyN = emptyN + 1;
        continue;
    end
    nonEmpty = nonEmpty + 1;
    if ~(ischar(pm) || (isstring(pm) && isscalar(pm)))
        % a struct (the shape carryProbeMap notes) or any other non-char value.
        % Not parseable for rows without the writer's serialize(); counted apart
        % rather than guessed at.
        nonCharN = nonCharN + 1;
        continue;
    end
    charN = charN + 1;
    [nrows, subjStrings, recognized] = parseProbemap(char(pm));
    if ~recognized; unrecHeader = unrecHeader + 1; end
    rowsTotal = rowsTotal + nrows;
    if nrows == 0
        docsZeroRows = docsZeroRows + 1;
    else
        docsWithRows = docsWithRows + 1;
        if nrows < rowMin; rowMin = nrows; end
        if nrows > rowMax; rowMax = nrows; end
    end
    if isKey(countTally, nrows)
        countTally(nrows) = countTally(nrows) + 1;
    else
        countTally(nrows) = 1;
    end
    % (session, subject) overlap. Distinct subjectstrings PER DOCUMENT feed the
    % attribution count; matched/covered are resolved against the pre-pass maps.
    sess = rows(k).session_id;
    perDocSeen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for s = 1:numel(subjStrings)
        ss = subjStrings{s};
        if isempty(ss); continue; end
        if ~isKey(perDocSeen, ss)
            perDocSeen(ss) = true;
            attributions = attributions + 1;
        end
        distinctSubjStrings(ss) = true;
        if ~isempty(sess) && isKey(subjectIdByLocal, ss)
            pk = pairKey(sess, ss);
            if isKey(coveredSubjectSession, pk)
                coveredPairs(pk) = true;
            else
                uncoveredPairs(pk) = true;
            end
        end
    end
end

report.probemap_documents_seen      = docsSeen;
report.probemap_vacuous             = (docsSeen == 0);
report.probemap_nonempty            = nonEmpty;
report.probemap_empty               = emptyN;
report.probemap_char_shape          = charN;
report.probemap_struct_shape        = nonCharN;
report.probemap_unrecognized_header = unrecHeader;
report.probemap_probe_rows_total    = rowsTotal;
report.probemap_docs_with_rows      = docsWithRows;
report.probemap_docs_zero_rows      = docsZeroRows;
if isfinite(rowMin)
    report.probemap_probe_rows_min = rowMin;
else
    report.probemap_probe_rows_min = 0;   % no document carried a probe row
end
report.probemap_probe_rows_max      = rowMax;
report.probemap_rows_by_count       = tallyToStruct(countTally);

report.probemap_subject_attributions     = attributions;
nDistinct = double(distinctSubjStrings.Count);
report.probemap_distinct_subject_strings = nDistinct;
matched = 0;
ssKeys = distinctSubjStrings.keys;
for i = 1:numel(ssKeys)
    if isKey(subjectIdByLocal, ssKeys{i}); matched = matched + 1; end
end
report.probemap_subject_strings_matched   = matched;
report.probemap_subject_strings_unmatched = nDistinct - matched;
report.probemap_epoch_subject_covered     = double(coveredPairs.Count);
report.probemap_epoch_subject_uncovered   = double(uncoveredPairs.Count);
report.overlap_vacuous = (docsSeen == 0) || (recSeen == 0);
end

function v = probemapField(body)
%PROBEMAPFIELD The raw `epochprobemap` value off a migrated epochfiles_ingested
%   body, [] when the block or field is absent or the value is empty ('').
%   Snake-first with a camelCase fallback, per the standing nested-read rule.
v = [];
if ~isstruct(body) || ~isfield(body, 'epochfiles_ingested') ...
        || ~isstruct(body.epochfiles_ingested) ...
        || ~isscalar(body.epochfiles_ingested)
    return;
end
blk = body.epochfiles_ingested;
for name = {'epochprobemap', 'epochProbeMap'}
    f = name{1};
    if isfield(blk, f) && ~isempty(blk.(f))
        v = blk.(f);
        return;
    end
end
end

function [nrows, subjStrings, recognized] = parseProbemap(s)
%PARSEPROBEMAP Probe-row count + per-row subjectstring of a serialize() char.
%   The writer (NDI epochprobemap_daqsystem.serialize) emits a 5-column
%   tab-delimited HEADER line then one '\n'-terminated line per probe. Returns
%   NROWS (data-line count), SUBJSTRINGS (column 5 of each data line) and
%   RECOGNIZED (was the first line the expected header). On an unrecognised
%   header every non-empty line is counted as a probe row, so a real row is
%   never dropped to a mis-detected header; the anomaly is flagged instead.
nrows = 0;
subjStrings = {};
recognized = false;
s = char(s);
tab = sprintf('\t');
nl  = sprintf('\n');
% CollapseDelimiters false so an empty column keeps its position; the trailing
% '\n' after every line is stripped by the non-empty filter below.
lines = strsplit(s, nl, 'CollapseDelimiters', false);
keep = {};
for i = 1:numel(lines)
    if ~isempty(strtrim(lines{i})); keep{end+1} = lines{i}; end %#ok<AGROW>
end
if isempty(keep); return; end
expected = {'name', 'reference', 'type', 'devicestring', 'subjectstring'};
hfields = strsplit(keep{1}, tab, 'CollapseDelimiters', false);
recognized = numel(hfields) == numel(expected) ...
    && all(cellfun(@(a, b) strcmpi(strtrim(a), b), hfields, expected));
if recognized
    dataLines = keep(2:end);
else
    dataLines = keep;
end
nrows = numel(dataLines);
subjStrings = cell(1, nrows);
for i = 1:nrows
    cols = strsplit(dataLines{i}, tab, 'CollapseDelimiters', false);
    if numel(cols) >= 5
        subjStrings{i} = strtrim(cols{5});
    else
        subjStrings{i} = '';
    end
end
end

function tf = isRecordingObservation(body)
%ISRECORDINGOBSERVATION True for a #30 observation, by its assembler's own stamp.
%   jRecordingObservation sets obs.base.name = 'migrated_recording_observation'
%   at exactly one site; matching on it needs no modality-class list and cannot
%   drift as modalities are added.
tf = false;
if ~isstruct(body) || ~isfield(body, 'base') || ~isstruct(body.base) ...
        || ~isfield(body.base, 'name')
    return;
end
tf = strcmp(char(body.base.name), 'migrated_recording_observation');
end

function tf = referenceIsEpochScoped(refBody, classById)
%REFERENCEISEPOCHSCOPED True when a reference document's `relative_to` names an
%   `epoch`. Used only for reference classes other than the session anchors the
%   switch already handles -- a robustness path, expected never to fire today.
tf = false;
if ~isstruct(refBody); return; end
target = depValueOf(refBody, 'relative_to');
if isempty(target); return; end
tf = isKey(classById, target) && strcmp(classById(target), 'epoch');
end

function s = tallyToStruct(m)
%TALLYTOSTRUCT A containers.Map(probe_rows -> documents) as a sorted struct array.
s = struct('probe_rows', {}, 'documents', {});
if m.Count == 0; return; end
ks = sort(cell2mat(m.keys));
for i = 1:numel(ks)
    s(end+1) = struct('probe_rows', ks(i), 'documents', m(ks(i))); %#ok<AGROW>
end
end

function v = depValueOf(b, name)
%DEPVALUEOF The value of one depends_on entry on a body STRUCT, '' when absent
%   OR present-and-empty. Tolerant of both key spellings, same precedence as
%   +did2/+validate/references.m.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps)
    items = deps(:)';
elseif isstruct(deps)
    items = num2cell(deps(:)');
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        if isfield(d, key{1})
            x = d.(key{1});
            if (ischar(x) || isstring(x)) && ~isempty(char(x)); v = char(x); end
        end
        if ~isempty(v); return; end
    end
    return;
end
end

function v = charField(s, names)
v = '';
for k = 1:numel(names)
    if ~isfield(s, names{k}); continue; end
    x = s.(names{k});
    if (ischar(x) || isstring(x)) && ~isempty(char(x)); v = char(x); return; end
end
end

function v = baseField(b, name)
v = '';
if ~isfield(b, 'base') || ~isstruct(b.base) || ~isfield(b.base, name); return; end
x = b.base.(name);
if ischar(x) || isstring(x); v = char(x); end
end

function b = setDep(b, name, value)
%SETDEP Add or overwrite one depends_on entry on a body STRUCT.
%   The pipeline uses two spellings at different stages -- a body that has been
%   through universalRenames carries `document_id`, one a migrator built carries
%   `value` -- and +did2/+validate/references.m reads either. So an EXISTING
%   entry is updated in whichever keys it already has, and a NEW entry is given
%   the same key set as its neighbours (a struct array cannot hold two field
%   sets). On an empty `depends_on` the shape is `value`, matching the minted
%   bodies in ndi.migrate.internal.pathSPromotion, which is the proven path
%   through the v1_to_v2 re-fold.
entry = struct('name', name, 'value', value);
if ~isfield(b, 'depends_on') || isempty(b.depends_on)
    b.depends_on = entry;
    return;
end
deps = b.depends_on;
if iscell(deps)
    for k = 1:numel(deps)
        if isstruct(deps{k}) && isfield(deps{k}, 'name') ...
                && strcmp(char(deps{k}.name), name)
            deps{k} = entry; b.depends_on = deps; return;
        end
    end
    deps{end+1} = entry;
    b.depends_on = deps;
    return;
end
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
        if isfield(deps, 'value');       deps(k).value = value; end
        if isfield(deps, 'document_id'); deps(k).document_id = value; end
        b.depends_on = deps;
        return;
    end
end
% Append: the existing array's field set decides which keys the new entry may
% carry, because a struct array cannot hold two different field sets.
fn = fieldnames(deps);
newEntry = struct();
for k = 1:numel(fn)
    switch fn{k}
        case 'name';        newEntry.name = name;
        case 'value';       newEntry.value = value;
        case 'document_id'; newEntry.document_id = value;
        otherwise;          newEntry.(fn{k}) = '';
    end
end
if ~isfield(newEntry, 'name'); newEntry.name = name; end
b.depends_on = [deps(:)', newEntry];
end

function summary = recountSummary(result)
%RECOUNTSUMMARY Same contract as resolveDatasetEntities' local copy.
summary = struct();
if isfield(result, 'summary') && isstruct(result.summary); summary = result.summary; end
summary.migrated_count = numel(result.migrated);
if isfield(result, 'quarantine'); summary.quarantine_count = numel(result.quarantine); end
byClass = struct();
for k = 1:numel(result.migrated)
    fieldName = matlab.lang.makeValidName(result.migrated{k}.className());
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end

function entries = acquisitionEpochClocks(body)
%ACQUISITIONEPOCHCLOCKS The `clocks` struct array, as a cell of {name,t0,t1}.
%
%   The block is REQUIRED on acquisition_epoch and its three sub-fields are all
%   mustBeNonEmpty, so a valid document always has them -- but this pass runs
%   over a batch that may include bodies from a partial or re-run migration, so
%   the shape is READ rather than assumed. A missing block yields {}, which the
%   caller counts as `refused_no_clocks` rather than treating as zero clocks.
%
%   NOT snake_case-fallback'd: `clocks` is an IMMEDIATE field of the property
%   block, so universalRenames has already normalised it. The camelCase fallback
%   rule applies one level down, which is why jEpochClockReferences needs it for
%   `epochtable.epochclock` and this does not.
entries = {};
if ~isstruct(body) || ~isfield(body, 'acquisition_epoch') ...
        || ~isstruct(body.acquisition_epoch) ...
        || ~isfield(body.acquisition_epoch, 'clocks')
    return;
end
c = body.acquisition_epoch.clocks;
if ~isstruct(c); return; end
for k = 1:numel(c)
    e = struct('name', '', 't0', NaN, 't1', NaN);
    if isfield(c(k), 'name'); e.name = char(c(k).name); end
    if isfield(c(k), 't0') && isscalar(c(k).t0); e.t0 = double(c(k).t0); end
    if isfield(c(k), 't1') && isscalar(c(k).t1); e.t1 = double(c(k).t1); end
    entries{end+1} = e; %#ok<AGROW>
end
end

function [refs, stats] = epochExtentReferences(entries, sessionDocumentId, ...
    sessionId, datestamp)
%EPOCHEXTENTREFERENCES One `relative_reference` per DISTINCT clock of an epoch.
%
%   #60 option A. Each reference is anchored to the SESSION, not to the epoch --
%   the epoch is the HOLDER (`epoch.time_reference_#`), so anchoring to it would
%   point a document at its own holder.
%
%   THE TARGET SHAPE IS jEpochClockReferences', DELIBERATELY, FIELD FOR FIELD:
%   class_version 2.0.0 over `time_reference` 4.0.0, `relative_to` the only
%   edge, and `value = {clock, start, duration}` with the EXTENT stored as a
%   duration rather than a raw end time (CHANGE 1 of the time model -- `end` is
%   exactly recoverable as start + duration, and storing it separately lets the
%   anchor's uncertainty contaminate the span's).
%
%   THIS IS NOT A SECOND IMPLEMENTATION OF THAT HELPER, and the distinction
%   matters because "two implementations that disagree is worse than one that is
%   missing" is a rule this project states out loud. jEpochClockReferences reads
%   a DIFFERENT SOURCE -- `daqreader_epochdata_ingested.epochtable`, a cell of
%   clock names beside a 2xN matrix -- and it lives in +migrators_j/private/,
%   which MATLAB makes unreachable from this folder. What is shared is the
%   TARGET, and five batch passes already construct relative_reference bodies
%   locally for the same reason.
%
%   `relation` IS OMITTED, as there: it carries the qualitative Allen relation
%   used when there is NO metric offset, and here the offsets are the content.
%
%   NO TIMES => NO REFERENCE. A clock with no finite t0/t1, or the `no_time`
%   sentinel, produces nothing rather than a NaN-valued document -- the hollow
%   document silentLoss and isFragment exist to catch.
refs = {};
stats = struct('no_time', 0, 'duplicate', 0, 'conflicting', 0);
seen = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(entries)
    e = entries{k};
    if isempty(e.name) || strcmp(e.name, 'no_time') ...
            || ~isfinite(e.t0) || ~isfinite(e.t1)
        stats.no_time = stats.no_time + 1;
        continue;
    end
    if isKey(seen, e.name)
        % `epoch.json` declares referent_unique_by {time_reference_#,
        % value.clock}, so a second copy of one clock would violate the rule
        % the schema already states. Several acquisition_epoch documents
        % sharing one epoch is the NORMAL case, not an anomaly.
        prior = seen(e.name);
        if prior.t0 ~= e.t0 || prior.t1 ~= e.t1
            % Two sources disagree about the same clock's extent. Neither is
            % authoritative and picking one would invent a fact -- counted
            % separately from a harmless duplicate, and still dropped.
            stats.conflicting = stats.conflicting + 1;
        else
            stats.duplicate = stats.duplicate + 1;
        end
        continue;
    end
    seen(e.name) = e;
    ref = struct();
    ref.document_class = struct('class_name', 'relative_reference', ...
        'class_version', '2.0.0', ...
        'superclasses', struct('class_name', 'time_reference', ...
            'class_version', '4.0.0'), ...
        'schema_version', 'V_eta');
    ref.depends_on = struct('name', {'relative_to'}, 'value', {sessionDocumentId});
    ref.base = struct('id', did.ido.unique_id(), ...
        'session_id', sessionId, ...
        'name', 'migrated_epoch_extent', ...
        'creation_timestamp', datestamp);
    ref.relative_reference = struct('value', struct( ...
        'clock',    struct('node', '', 'name', e.name), ...
        'start',    extentDuration(e.t0), ...
        'duration', extentDuration(e.t1 - e.t0)));
    refs{end+1} = ref; %#ok<AGROW>
end
end

function c = extentDuration(seconds)
%EXTENTDURATION A V_eta `duration` cell. `source_unit` is 's' because the v1
%   clocks block stores seconds -- stated, not converted, per the standing rule
%   that the source's own unit is carried verbatim beside the canonical value.
c = struct('seconds', double(seconds), 'source_unit', 's', ...
    'source_value', double(seconds), 'approximate', false);
end

function ts = creationTime(body)
%CREATIONTIME The document's creation time, EITHER VINTAGE.
%   V_eta renamed `base.datestamp` -> `base.creation_timestamp` (did-schema,
%   signed 2026-08-13) and the rename is applied OUTBOUND, inside
%   did2.convert.v1_to_v2 (renameOutboundBaseFields, v1_to_v2.m:272). Every
%   batch post-pass runs AFTER that, so the bodies reaching this file carry
%   the NEW key while a pre-migration body carries the old one.
%
%   Reading only `datestamp` returned '' on every migrated document and the
%   caller then substituted a default -- a WRONG timestamp on a valid-looking
%   document, which no gate would ever flag. That is the quiet half of the
%   same rename whose loud half stopped the database write dead
%   (did2.database.sqlitedb/requireCreationTimestamp).
%
%   Returns '' when neither key is present, so callers keep their own
%   fallback rather than having one imposed here.
ts = '';
if ~isstruct(body) || ~isfield(body, 'base') || ~isstruct(body.base)
    return;
end
for name = {'creation_timestamp', 'datestamp'}
    f = name{1};
    if isfield(body.base, f) && ~isempty(body.base.(f))
        ts = body.base.(f);
        return;
    end
end
end
