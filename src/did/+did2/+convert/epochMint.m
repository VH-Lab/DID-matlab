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
            'datestamp',    baseField(b, 'datestamp'));
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
    if ~armings{a}.is_metadata_fold; continue; end
    if armingCarried(a)
        report.metadata_ingested_folds_emitted = ...
            report.metadata_ingested_folds_emitted + 1;
    else
        report.metadata_ingested_folds_withheld = ...
            report.metadata_ingested_folds_withheld + 1;
    end
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
    'name', 'migrated_epoch', 'datestamp', datestamp);
body.epoch = struct('local_identifier', epochString);
end

% ===================== the arming path =================================

function tbl = defaultArmingMigrators()
%DEFAULTARMINGMIGRATORS SOURCE CLASS -> the migrator this pass re-runs armed.
%   ONE ROW TODAY, and the reason there is only one is a SCHEMA fact, not an
%   omission: a migrator may be armed only once some class in its output can
%   legally hold the `epoch_id` edge, and the three migrators waiting on this
%   pass emit bodies whose classes do not declare it. Re-derived 2026-08-12 over
%   the built tree (247 JSON files, 241 with a document_class, deps read by JSON
%   path rather than by grep): exactly FOUR classes declare the dependency --
%   acquisition_metadata_file, ingestion_manifest, directed_relation,
%   method_parameters. `daqreader_epochdata_ingested`,
%   `daqreader_image_epochdata_ingested` and `stimulus_response_scalar` are not
%   among them. Adding a row here before that changes is caught by the
%   `undeclared_edge` refusal in armingIsSafe, which reads the schema.
tbl = struct( ...
    'daqmetadatareader_epochdata_ingested', ...
        @did2.convert.migrators_j.daqmetadatareader_epochdata_ingested);
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
