function [result, report] = resolveLawnPlateSubjects(result, options)
%RESOLVELAWNPLATESUBJECTS Mint the bacterial LAWN and PLATE subject tiers, join
%   them with `member_of`, and give every patch subject the (experiment, plate,
%   patch) identifier the team asked for.
%
%   [RESULT, REPORT] = did2.convert.resolveLawnPlateSubjects(RESULT) takes the
%   struct did2.convert.v1_to_v2 returns (after the sibling post-passes) and
%   implements the team decisions of 2026-08-11. REPORT is also attached as
%   RESULT.lawn_plate_subjects, so a caller that ignores the second output still
%   carries the measurement.
%
%   STATUS: WRITTEN 2026-08-11 IN A CONTAINER WITH NO MATLAB, and still edited
%   from one -- `command -v matlab octave octave-cli` finds nothing here, so no
%   line of this file has ever been run in this session. It HAS now been run by
%   CI: test-migrators-quick.yml run 31496276388 (job 93794725787, head
%   76f835ad) executed all 15 tests of testLawnPlateSubjects and reported
%   927/929 with exactly two failures, both of them in this file's canary.
%   That run is the only execution evidence this header may claim, and it
%   PREDATES the collision split added 2026-08-11: `splitCollisions` and the
%   four new report fields have NEVER BEEN RUN ANYWHERE at the time of writing.
%   Treat them as UNPROVEN until a CI run says otherwise.
%
%   WHAT IT FOUND, AND WHY THE PYTHON HARNESS COULD NOT.
%   `sessions_with_lawn_plate_tables` was assigned `liveSessions.Count`, which
%   is UINT64 while the field is declared double in the denominator block below
%   and every other field of the report is a double. It is now cast (see the
%   note at the assignment). tools/dev/lawn_plate_mutation_harness.py reported
%   BASELINE 14/14 across this exact case because it transliterates the counter
%   as `len(live)` -- a Python int -- so the transliteration cannot see a
%   MATLAB type at all. A transliteration is not a run, and this is what that
%   sentence costs: the harness is blind to type, arity and MATLAB semantics by
%   construction, and any defect living there reaches CI untouched. Said in the
%   header rather than only in a commit message because a header is what the
%   next reader sees.
%
%   ---------------------------------------------------------------------
%   THE DECISIONS THIS FILE IMPLEMENTS -- IT IS NOT MAKING ANY
%   ---------------------------------------------------------------------
%   V_eta_OPEN_WORK.md, "TEAM DECISION 2026-08-11 -- the E. coli lawns and
%   plates are subjects, in two tiers", jess@walthamdatascience.com, verbatim:
%
%       "Yes, each lawn can be a subject and a plate of lawns is another
%        subject where each lawn is a member of it"
%
%           lawn  (a bacterial patch)  -> subject
%           plate (a plate of lawns)   -> subject, the GROUP
%           lawn --member_of--> plate
%
%   The refinement of the same day, verbatim:
%
%       "It's only necessary to make all subjects if we take measurements of
%        both which I think in most cases is true"
%
%   -- so the two tiers are CONDITIONAL ON THE DATA, not structural. A tier's
%   subject is minted only where that tier actually has something measured about
%   it; a subject with nothing attached is the hollow document
%   did2.validate.isFragment exists to catch, and this pass must not manufacture
%   them. Where only one tier is minted there is no `member_of` to emit -- BOTH
%   ENDS MUST EXIST -- and the withholding is COUNTED, by tier.
%
%   And the identifier directive of the same day, verbatim:
%
%       "each experiment #, plate #, and patch # combo should be unique and
%        should dictate the local identifier for all patches. None should be
%        labeled just patch #"
%
%   -- so a patch subject's `local_identifier` is the TRIPLE, every component
%   read from a source row and none synthesised. A component that cannot be read
%   is a subject that cannot be named, and `subject.local_identifier` is
%   REQUIRED, so the mint is REFUSED and counted rather than made partial.
%
%   NO TEAM-SIGN-OFF LINE IS ADDED ANYWHERE BY THIS CHANGE. The governing plan
%   document still needs the team's signature and the board will keep rendering
%   the family as awaiting review until that line exists.
%
%   ---------------------------------------------------------------------
%   THE IDENTIFIER, AND WHY THE SAME JOIN PRODUCES IT
%   ---------------------------------------------------------------------
%   NDI origin/main +setup/+conv/+haley/doImport.m, Step 8 (lines 714-723):
%
%       plateVariables  keyed plateID           14 cols   expID, plateID, ...
%       imageVariables  keyed {plateID,imageID}  4 cols   plateID, imageID, ...
%       patchVariables  keyed {imageID,patchID} 10 cols   imageID, patchID, ...
%
%   The patch row carries NEITHER `plateID` NOR `expID`. So the triple is not
%   available to any single-document migrator, and it is produced by the SAME
%   two-hop chain the membership needs:
%
%       patch --imageID--> image row --plateID--> plate row --> expID
%
%   Shapes emitted (one convention, used by both tiers and by the C. elegans
%   relabel below):
%
%       plate        exp/<expID>/plate/<plateID>
%       patch/lawn   exp/<expID>/plate/<plateID>/patch/<patchID>
%
%   FALLBACK, ONE PLACE ONLY, AND IT IS NAMED RATHER THAN SILENT. The C. elegans
%   patch geometry table (doImport.m:290-292) carries `plateID` and `patchID`
%   but NOT `expID` -- it never had one -- so where the plate -> expID hop does
%   not resolve for those, the pair `plate/<plateID>/patch/<patchID>` stands.
%   That still satisfies "none should be labeled just patch #", and the count is
%   reported (`celegans_patch_subjects_refused_no_exp_id`) rather than absorbed.
%   Those subjects CANNOT be refused: the C. elegans encounter relation names
%   each one as its `parent` (20,411 of them), so withholding the subject would
%   trade a naming problem for a gating orphan failure. E. coli LAWN subjects
%   are new and nothing points at them, so there the refusal is real.
%
%   THE COMBO IS ASSERTED UNIQUE BY THE TEAM, AND THIS PASS MEASURES IT INSTEAD
%   OF ASSUMING IT. `expID` and `plateID` are only offset by `expType*1000` in
%   the C. elegans session (doImport.m:165-166) and NOT in the E. coli one
%   (:728-729), and `expType` is 0 for `foragingConcentration` -- so a
%   cross-session collision is arithmetically possible. The identifier is built
%   exactly as directed and the collision is REPORTED, never acted on. A zero is
%   the directive confirmed on real data; a non-zero is a fact the team needs,
%   and neither is something this file may decide on its own.
%
%   ONE COUNTER COULD NOT ANSWER THE QUESTION THAT WAS ASKED OF IT, WHICH IS WHY
%   THERE ARE NOW THREE. Corpus run 31522068566 reported
%
%       *** 6414 HANDLE COLLISION(S) across the run. The team's
%       *** (experiment, plate, patch) uniqueness directive is refuted
%       *** on real data.
%
%   all of them in JH, and the team's reply was "Is it not within-session
%   unique? That's what matters." NOTHING IN THAT RUN COULD ANSWER IT. The
%   counter is `local_identifier_collisions_within_batch` -- BATCH, not session
%   -- and a batch spans both Haley sessions, which is exactly the arithmetic
%   the paragraph above describes. "Refuted" was therefore a claim the
%   instrument could not support: a collision between two DIFFERENT sessions
%   refutes nothing, because every index in this pass is keyed by
%   `base.session_id` (see "BOTH HOPS ARE SESSION-SCOPED" below) and so is
%   NDI's own subject resolver (see the join-key note further down). The batch
%   total is now SPLIT, and the split is exact by construction rather than by a
%   reader's subtraction:
%
%       local_identifier_handles_formed        <- DENOMINATOR, unconditional
%       local_identifier_handles_distinct      <- DENOMINATOR
%       local_identifier_collisions_within_batch    == formed - distinct
%         = _within_session                    the same handle twice inside ONE
%                                              base.session_id. THESE ARE THE
%                                              ONES THAT WOULD REFUTE IT.
%         + _across_sessions_only              the same handle in N distinct
%                                              sessions and never twice in one.
%                                              THESE DO NOT.
%         + _unclassifiable_no_session_id      a colliding occurrence carrying
%                                              no session id, so neither of the
%                                              above can be said of it. COUNTED
%                                              AND NAMED, never folded into
%                                              either.
%
%   splitCollisions() below carries the per-handle arithmetic and the proof that
%   the three sum to the total for every shape of input.
%
%   THE THIRD BUCKET CANNOT FIRE TODAY, AND IT IS COUNTED ANYWAY. Both sites
%   that FORM a handle refuse a session-less row before the formation -- the
%   tier mint at "question 2" and the C. elegans relabel -- so
%   `_unclassifiable_no_session_id` is structurally 0 in this file as written.
%   That is an UNTESTED zero, not a clean one, and it is written down as such
%   for the same reason the digest says so of edge-family uniqueness. The bucket
%   exists so that relaxing either refusal appears as a number rather than as a
%   silent reclassification into one of the two buckets that carry meaning.
%
%   ---------------------------------------------------------------------
%   WHY IT IS A BATCH POST-PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   Both the membership and the identifier need documents a single-document
%   migrator cannot see, and they need only documents ALREADY IN THE MIGRATED
%   BATCH -- no session, no database, no file bytes -- which is the same
%   criterion that put `epochMint` and `resolveSessionAnchors` DID-side.
%
%   An NDI-side pass would also be INVISIBLE to the corpus gate:
%   runCorpusDiscovery runs five passes and zero `ndi.migrate.*`, so it would
%   report the same counts whether the work succeeded, no-opped or threw.
%
%   THE FOURTH CALL SITE IS NOT WIRED, AND THAT IS A GAP, NOT A DECISION.
%   `ndi.migrate.local` is the production second pass and lives in NDI-matlab.
%   The three DID-side sites (runCorpusDiscovery, testCorpusPRED,
%   testFixtureCorpus) are wired and are what testBatchPassWiring.m and
%   tools/test_batch_pass_wiring.py assert; testBatchPassWiring REPORTS the NDI
%   site rather than asserting it, for the separate reason that NDI-matlab need
%   not be checked out beside DID-matlab. Until the call is added there, THE
%   CORPUS GATE AND PRODUCTION DIVERGE on this pass -- the corpus will show the
%   tiers and the real migration will not. That is exactly the failure the
%   wiring gate was built for, so it is written here rather than left to be
%   discovered.
%
%   CORRECTION. This paragraph said NDI-matlab was "READ-ONLY" in this session
%   and that the call needed "someone with write access". BOTH WERE FALSE, and
%   the direction is the one this project's operating rules warn about: it
%   turned a piece of work that could be finished into someone else's problem.
%   NDI-matlab is one of the four repositories this work develops in, it is
%   checked out on the same branch as the rest, and it was COMMITTED AND PUSHED
%   TO twice on the night this file was written:
%
%       $ git -C /home/user/NDI-matlab rev-parse --abbrev-ref HEAD
%       claude/v-eta-migration-plan-35jj1z
%       $ git -C /home/user/NDI-matlab log --oneline -2
%       afa1c5ca2 Correct a made-up denominator in the note I just wrote
%       5a6508644 Both migrate-assembler failures were stale tests, not broken code
%
%   The gap this paragraph describes is real and still open. What was wrong is
%   only the reason given for not closing it.
%
%   ---------------------------------------------------------------------
%   IT IS ADDITIVE, EXCEPT FOR ONE FIELD ON ONE CLASS
%   ---------------------------------------------------------------------
%   The three E. coli `ontology_table_row` documents pass through pass 1
%   untouched (the guard in +migrators_j/ontology_table_row.m: a real
%   `ontologyTableRow` declares only `document_id`, so `resolvedSubject` finds
%   nothing and the row is carried whole). THIS PASS LEAVES THEM EXACTLY THERE
%   and only APPENDS subjects, observations and relations.
%
%   The one exception is `subject.local_identifier` on the C. elegans patch
%   subjects pass 1 mints, which this pass rewrites in place with the id
%   PRESERVED.
%
%   "A HUMAN HANDLE, NOT A JOIN KEY" IS TRUE DID-SIDE AND FALSE NDI-SIDE, AND
%   THIS PARAGRAPH USED TO SAY ONLY THE FIRST HALF -- in the reassuring
%   direction, because it made a rewrite sound consequence-free. CHECKED
%   2026-08-11.
%
%     DENOMINATOR (a first draft of this paragraph got it wrong in exactly the
%     way this project keeps paying for -- it quoted a TOTAL as if it were the
%     non-comment count, and the total moves whenever this file is edited, so
%     the command is given instead of a bare number):
%
%         $ grep -rn local_identifier --include=*.m src | wc -l
%         100          across 20 files      <- DID-matlab
%         $ grep -rn local_identifier --include=*.m . | wc -l
%         125          in 929 .m files      <- NDI-matlab, 24 of which
%                                              mention `subject.local_identifier`
%
%     DID-SIDE THE OLD CLAIM HOLDS. SEVEN sites READ the field out of a
%     document; the other occurrences write it, name it in a report key, or
%     discuss it in a comment. FIVE of the seven read `<doc>.epoch` and key on
%     the PAIR (base.session_id, epoch.local_identifier) -- epochMint.m:337,
%     epochIndex.m:520-521 and :593, resolveValidIntervals.m:461,
%     epochStringRetention.m:265-266. The remaining TWO are the only
%     subject-side reads in the repository and NEITHER resolves anything:
%     migrators_j/subject.m:17-18 reads the field and writes it straight back
%     normalised, and this file's relabel reads back its own handle.
%     `base.id` is the key and `+did2/+validate/references.m` resolves every
%     edge through it.
%
%     NDI-SIDE IT IS NOT TRUE, AND THE RESOLVER ERRORS RATHER THAN DEGRADES:
%
%         ndi.subject.does_subjectstring_match_session_document
%             (NDI-matlab +ndi/subject.m:130-172) takes a handle and returns a
%             document id, and at :169-170
%                 elseif numel(subject_doc)>1
%                     error(['More than one subject doc matches..should only
%                            be 1!']);
%             It is reached from ndi.element.m:59, the element -> subject
%             attribution path.
%         Seven more sites query the field directly -- subjectMaker.m:379,
%             +conv/+gluckman/binepochprobemap.m:24, +conv/+marder/
%             smrepochprobemap.m:24, abfepochprobemap.m:39,
%             abfprobetable2probemap.m:63, demo.m:11, +mock/+fun/clear.m:16 --
%             subjectMaker.m:249-250 does find-or-create by strcmp on it, and
%             treatmentMaker.m:60 builds a MAP from handle to document id.
%
%   THAT IS WHY within/across IS THE RIGHT CUT AND NOT A CONVENIENT ONE.
%   `ndi.session.database_search` ANDs in
%   `ndi.query('base.session_id','exact_string',session.id())`
%   (NDI-matlab +ndi/session.m:328-329), so the erroring resolver above sees ONE
%   SESSION and a cross-session duplicate is invisible to it;
%   `ndi.dataset.database_search` (+ndi/dataset.m:670-677) concatenates over
%   every linked session and does not. A within-session collision therefore
%   breaks a live NDI resolver; a cross-session-only collision breaks it only
%   for a caller resolving through the DATASET -- and doImport.m:868-878 puts
%   both Haley sessions in one `ndi.dataset.dir`. Which of those the team cares
%   about is THEIR call; this file measures both and decides neither.
%
%   ONE CONSEQUENCE THE OLD SENTENCE RULED OUT: because NDI does resolve
%   subjects by handle, the relabel changes what an NDI-side query for the OLD
%   pair handle finds. Named here rather than left implied. The relabel is still
%   safe DID-side, where nothing resolves a subject through the handle, and the
%   pass rewrites only subjects this same migration minted, in the same batch.
%
%   Two consequences of the additive shape, stated rather than discovered:
%
%     * NO COLUMN CAN BE LOST. The enumeration below types 4 plate measures and
%       8 lawn measures; every other column -- the strain document-id string,
%       the five timestamps, the peptone flag, the labels -- stays on the source
%       row, which is still there. A partial enumeration is safe here in a way
%       it is not inside a migrator that REPLACES its input, which is the defect
%       that cost `applyPatchGeometryMap` its 7th column.
%     * THE TYPED MEASURES ARE THEREFORE STORED TWICE, once as an observation
%       and once in the source row's `data` block. That is the same state
%       `resolveResponseParameters` accepts: it leaves 11,440 documents in place
%       and MEASURES the deletion gate instead of pre-empting it. Consuming the
%       source rows is a separate verify-before-delete step and is NOT done
%       here. `source_rows_left_in_place` names the number.
%
%   ---------------------------------------------------------------------
%   HOW A COLUMN IS FOUND WITHOUT GUESSING ITS shortName
%   ---------------------------------------------------------------------
%   The `data` keys of an `ontologyTableRow` are `shortName(term)`
%   (tableDocMaker.m:208, `data.(variableNames{i})`, where `variableNames{i}` is
%   the 6th output of `ndi.ontology.lookup`). `ndi.ontology.lookup` lives in
%   ndi-ontology-matlab, which is NOT checked out in this session, so those
%   strings cannot be evaluated here -- and inventing them is exactly the
%   failure mode this project has already paid for twice.
%
%   So no spelling is guessed. Every column is looked up by a NORMALISED TOKEN
%   -- lowercased, with every non-alphanumeric character removed -- and the
%   token is taken from the TERM LABEL in +haley/tableDoc_dictionary.json,
%   which IS readable. Both the column's `key` (the shortName) and its `name`
%   (the term name) are normalised and compared, so either channel resolving is
%   enough, and the report says WHICH channel did it
%   (`columns_resolved_by_key` / `columns_resolved_by_term_name`).
%
%   The rule this rests on -- shortName is the term label with punctuation and
%   spaces removed -- is not assumed; it is confirmed by every corpus-proven
%   spelling already in the tree, and testLawnPlateSubjects pins all five:
%
%       BacterialPatchIdentifier          "bacterial patch identifier"
%       BacterialOD600TargetAtSeeding     "bacterial OD600 (target) at seeding"
%       BacterialPatchCenter_XCoordinate  "bacterial patch center: X coordinate"
%       BacterialColonyFormingUnitsCFUMeasurement
%                       "bacterial colony forming units (CFU) measurement"
%       CElegansBehavioralAssay_EncounterIdentifier
%                       "C. elegans behavioral assay: encounter identifier"
%
%   THE SPELLING CANARY. If the rule is wrong anyway, this pass would find no
%   rows and report all zeros -- the all-zeros-reads-as-clean failure. So it
%   also reports `unclassified_rows_in_those_sessions`: every
%   `ontology_table_row` living in a session where at least one lawn/plate/image
%   table WAS recognised, that matched no signature. Zero rows recognised
%   anywhere reads as "no E. coli tables in this corpus"; rows recognised beside
%   a large unclassified count reads as "the token rule is wrong". Those two
%   used to be one silence.
%
%   ---------------------------------------------------------------------
%   THE SIX TABLES, AND WHY THE SIGNATURES CANNOT COLLIDE
%   ---------------------------------------------------------------------
%       LAWN  = has imageID  AND patchID  AND NOT plateID
%       IMAGE = has imageID  AND plateID  AND NOT patchID
%       PLATE = has plateID  AND (timePoured OR timePouredColdRoom)
%                              AND NOT imageID
%       EXPID SOURCE (index only, no tier) = has plateID AND expID
%
%   `timePoured` / `timePouredColdRoom` appear at exactly ONE line of the whole
%   881-line writer -- doImport.m:715, inside plateVariables -- so they are the
%   discriminator that separates the E. coli PLATE table from the two C. elegans
%   plate tables, which also carry plateID + OD600 + CFU and would otherwise
%   match. That is the misfire that made every C. elegans cultivation plate a
%   bacterial patch (commit 112bcf1), so the clause excludes them positively
%   rather than hoping the sets are disjoint:
%
%       A cultivation plate (celegans, 22 cols) plateID patchID expID  no poured
%       B behaviour plate   (celegans, 21 cols) plateID         expID  no poured
%       C patch geometry    (celegans,  8 cols) plateID patchID        no imageID
%       8A plate            (ecoli,    14 cols) plateID         expID  POURED
%       8C image            (ecoli,     4 cols) plateID imageID
%       8D patch/lawn       (ecoli,    10 cols)         imageID patchID
%
%   C never reaches this pass as a row: `isPatchGeometryTable` consumes it in
%   pass 1 (it arrives here as the SUBJECT that map minted, which is what the
%   relabel below operates on), and it could not match anyway. 8D does NOT trip
%   `isPatchGeometryTable` either -- that predicate requires
%   BacterialOD600TargetAtSeeding and the E. coli patch table has no OD600
%   column at all (doImport.m:720-723).
%
%   A and B both feed the expID index; their `plateID` ranges do not overlap
%   (:185 adds a further +900 to the cultivation plates), and where two rows DO
%   claim one (session, plateID) the index accepts them only if they AGREE on
%   expID and refuses as ambiguous otherwise.
%
%   ---------------------------------------------------------------------
%   BOTH HOPS ARE SESSION-SCOPED, AND THAT IS NOT DEFENSIVENESS
%   ---------------------------------------------------------------------
%   `plateID` COLLIDES across the two Haley sessions -- doImport.m:166 adds
%   `expType*1000` and :729 does not -- and both sessions land in ONE
%   `ndi.dataset.dir` (doImport.m:868-878). An unscoped join would attach
%   C. elegans data to E. coli lawns and look entirely plausible doing it. So
%   every index key is `base.session_id` + the local id, and a row with NO
%   session id is REFUSED rather than joined globally. Note this is separate
%   from the identifier question: the patch collision the triple fixes is
%   INTRA-session (between plates within one session), so session scoping would
%   not have rescued it and the triple does not remove the need for scoping.
%
%   ---------------------------------------------------------------------
%   WHAT IT DOES NOT DO
%   ---------------------------------------------------------------------
%     * NO STRAIN EDGE. `bacteriaStrain` is a document-id STRING sitting in
%       `data` (doImport.m:734), not an edge -- no Haley
%       `table2ontologyTableRowDocs` call passes `dependencyVariable`, so every
%       row's `depends_on` is `[{document_id, ""}]`. Minting `strain_id` from it
%       is a second edge whose resolvability nobody has verified, the shape that
%       turned `distance_metadata` from a quiet passthrough into a GATING orphan
%       failure. Out of scope by the decision's own constraint 4.
%     * NO TIME REFERENCE. `time_reference_#` is OPTIONAL on subject_interaction
%       and these are static properties with no per-reading time, so no anchor
%       is minted. This DIVERGES from `applyPatchGeometryMap`, which mints a
%       `session_relative_reference` carrying `relation:'during'` and no times.
%       The divergence is deliberate: a reference with no times is precisely the
%       hollow document V_eta_time_reference_model_plan.md's "NO TIMES => NO
%       REFERENCE" rule names. Pass-1 code is not changed on that point.
%     * NO IMAGE SUBJECT. An image is not a subject; the image rows are read as
%       the JOIN TABLE they are and are left exactly as pass 1 emitted them.
%     * NO EDGE IT CANNOT RESOLVE. Every `member_of` is emitted only after BOTH
%       endpoint subjects have been minted AND have survived validation into
%       `migrated`. A refusal is a no-op; a dangling edge is a gating orphan.
%
%   Options (name-value), mirroring the sibling passes:
%     Validate       (1,1 logical, default true)  validate the new bodies
%     SchemaCache    ([] or a did2.schema.cache)  override the shared cache
%     TargetVersion  (1,:) char, default 'V_eta'  no-op on other targets
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveResponseParameters,
%   did2.convert.epochMint, did2.convert.resolveSessionAnchors,
%   did2.convert.migrators_j.ontology_table_row.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% DENOMINATOR FIRST, and unconditionally. Every field exists before a single
% document is read, so "did not run" (ran == false) and "ran and found nothing"
% (ran == true, counters 0) are different readings of the same struct rather
% than the same reading. Operating Rule 5.
report = struct( ...
    ... % --- what was looked at at all
    'documents_inspected',                       0, ...
    'documents_unreadable',                      0, ...
    'ontology_table_rows_seen',                  0, ...
    ... % --- what was recognised (all zero means "no E. coli tables here")
    'plate_rows_seen',                           0, ...
    'image_rows_seen',                           0, ...
    'lawn_rows_seen',                            0, ...
    'exp_id_source_rows_seen',                   0, ...
    'sessions_with_lawn_plate_tables',           0, ...
    'unclassified_rows_in_those_sessions',       0, ...
    'columns_resolved_by_key',                   0, ...
    'columns_resolved_by_term_name',             0, ...
    ... % --- tier 1: the plate. THREE distinct states, never summed.
    'plate_rows_with_measurements',              0, ...
    'plate_rows_with_values_but_none_emittable', 0, ...
    'plate_rows_with_no_values_at_all',          0, ...
    'plate_rows_refused_no_session_id',          0, ...
    'plate_rows_refused_no_plate_key',           0, ...
    'plate_rows_refused_no_exp_id',              0, ...
    'plate_subjects_minted',                     0, ...
    'plate_observations_emitted',                0, ...
    ... % --- tier 2: the lawn. Same three states, plus the triple's refusals.
    'lawn_rows_with_measurements',               0, ...
    'lawn_rows_with_values_but_none_emittable',  0, ...
    'lawn_rows_with_no_values_at_all',           0, ...
    'lawn_rows_refused_no_session_id',           0, ...
    'lawn_rows_refused_no_identity_keys',        0, ...
    'lawn_subjects_minted',                      0, ...
    'lawn_observations_emitted',                 0, ...
    ... % --- the two-hop chain, which produces BOTH the triple and the group
    'chains_attempted',                          0, ...
    'chains_resolved',                           0, ...
    'refused_no_image_row',                      0, ...
    'refused_image_row_ambiguous',               0, ...
    'refused_image_row_has_no_plate_key',        0, ...
    'refused_no_plate_row',                      0, ...
    'refused_plate_row_ambiguous',               0, ...
    'refused_lawn_no_exp_id',                    0, ...
    'member_of_relations_emitted',               0, ...
    'withheld_plate_tier_not_minted',            0, ...
    'withheld_lawn_tier_not_minted',             0, ...
    'refused_total',                             0, ...
    ... % --- the C. elegans patch relabel (directive 2: "none just patch #")
    'celegans_patch_subjects_seen',              0, ...
    'celegans_patch_subjects_relabelled',        0, ...
    'celegans_patch_subjects_already_triple',    0, ...
    'celegans_patch_subjects_refused_no_exp_id', 0, ...
    'celegans_patch_subjects_refused_ambiguous_exp_id', 0, ...
    'celegans_patch_subjects_unparseable_handle', 0, ...
    'celegans_patch_relabel_quarantined',        0, ...
    ... % --- identity health. DENOMINATORS BEFORE THE FINDING, and the three
    ... % collision buckets sum to the batch total by construction, never by a
    ... % reader's subtraction. See "ONE COUNTER COULD NOT ANSWER THE QUESTION"
    ... % in the header for why one number was not enough.
    'local_identifier_fallback_to_document_id',  0, ...
    'local_identifier_handles_formed',           0, ...
    'local_identifier_handles_distinct',         0, ...
    'local_identifier_collisions_within_batch',  0, ...
    'local_identifier_collisions_within_session', 0, ...
    'local_identifier_collisions_across_sessions_only', 0, ...
    'local_identifier_collisions_unclassifiable_no_session_id', 0, ...
    ... % --- what landed
    'subjects_quarantined',                      0, ...
    'statements_quarantined',                    0, ...
    'documents_appended',                        0, ...
    'source_rows_left_in_place',                 0, ...
    'ran',                                       false);
result.lawn_plate_subjects = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % subject v3.0.0 + the observation leaves exist only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.lawn_plate_subjects = report;
    return;
end
report.ran = true;

ROW = 'ontology_table_row';

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ---------------------------------------------
% A document this cannot read is COUNTED, never dropped.
bodies  = cell(1, n);
classes = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k}  = b;
        classes{k} = classNameOf(b);
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- classify every ontology_table_row -------------------------------------
% kind: 0 unclassified, 1 plate, 2 image, 3 lawn
kinds     = zeros(1, n);
hasExpSrc = false(1, n);
colsOf    = cell(1, n);
sessions  = repmat({''}, 1, n);
byKeyTotal = 0; byNameTotal = 0;
for k = 1:n
    if ~strcmp(classes{k}, ROW); continue; end
    report.ontology_table_rows_seen = report.ontology_table_rows_seen + 1;
    b = bodies{k};
    if ~isstruct(b) || ~isfield(b, ROW) || ~isstruct(b.(ROW)); continue; end
    [cols, byKey, byName] = extractColumns(b.(ROW));
    byKeyTotal = byKeyTotal + byKey;
    byNameTotal = byNameTotal + byName;
    colsOf{k}   = cols;
    sessions{k} = baseField(b, 'session_id');
    kinds(k)    = classifyTable(cols);
    hasExpSrc(k) = ~isempty(colByToken(cols, TOK_PLATE_ID())) ...
        && ~isempty(colByToken(cols, TOK_EXP_ID()));
end
report.columns_resolved_by_key = byKeyTotal;
report.columns_resolved_by_term_name = byNameTotal;
report.plate_rows_seen = sum(kinds == 1);
report.image_rows_seen = sum(kinds == 2);
report.lawn_rows_seen  = sum(kinds == 3);
report.exp_id_source_rows_seen = sum(hasExpSrc);
report.source_rows_left_in_place = report.plate_rows_seen ...
    + report.image_rows_seen + report.lawn_rows_seen;

% --- THE SPELLING CANARY ---------------------------------------------------
% Sessions in which at least one of the three tables was recognised, and how
% many ontology_table_row documents in those same sessions matched nothing. A
% large unclassified count beside a small recognised one is what a wrong token
% rule looks like; both counts zero is "this corpus has no E. coli tables".
liveSessions = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:n
    if kinds(k) > 0 && ~isempty(sessions{k}); liveSessions(sessions{k}) = true; end
end
% double(), and it is not cosmetic -- `containers.Map.Count` returns UINT64.
% Every other field of this report is a double, so without the cast the struct
% is mixed-type and encodes inconsistently (the reason silentLoss.m:871-875
% casts at the boundary), and uint64 arithmetic SATURATES, so any later
% subtraction against this denominator could never go negative -- an instrument
% whose broken case is indistinguishable from "nothing to report", which is the
% one thing this canary exists to prevent. epochMint.m:368-378 records the same
% defect and adds the detail that found it here too: it "made verifyEqual fail
% on class rather than value".
report.sessions_with_lawn_plate_tables = double(liveSessions.Count);
for k = 1:n
    if ~strcmp(classes{k}, ROW); continue; end
    if kinds(k) > 0; continue; end
    if ~isempty(sessions{k}) && isKey(liveSessions, sessions{k})
        report.unclassified_rows_in_those_sessions = ...
            report.unclassified_rows_in_those_sessions + 1;
    end
end

% --- index the image rows: (session, imageID) -> plateID -------------------
% A duplicate key is NOT resolved by taking the first: two image rows claiming
% one (session, imageID) means the join is ambiguous, and an ambiguous join is
% how a plausible-looking wrong attribution gets made.
imagePlate = containers.Map('KeyType', 'char', 'ValueType', 'any');
imageCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if kinds(k) ~= 2 || isempty(sessions{k}); continue; end
    imageId = colVal(colsOf{k}, TOK_IMAGE_ID());
    if isempty(imageId); continue; end
    key = joinKey(sessions{k}, imageId);
    if isKey(imageCount, key)
        imageCount(key) = imageCount(key) + 1;
    else
        imageCount(key) = 1;
        imagePlate(key) = colVal(colsOf{k}, TOK_PLATE_ID());
    end
end

% --- index the E. coli plate rows: (session, plateID) -> how many -----------
% A COUNT, not a row index: the only questions asked of it are "does the plate
% row exist" and "is it unique". Storing the index too would be a field nothing
% reads, and a counter nobody reads is how a wrong one survives.
plateCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if kinds(k) ~= 1 || isempty(sessions{k}); continue; end
    plateId = colVal(colsOf{k}, TOK_PLATE_ID());
    if isempty(plateId); continue; end
    key = joinKey(sessions{k}, plateId);
    if isKey(plateCount, key)
        plateCount(key) = plateCount(key) + 1;
    else
        plateCount(key) = 1;
    end
end

% --- index expID: (session, plateID) -> expID, from ANY row carrying both ---
% Both C. elegans plate tables and the E. coli plate table qualify. Two rows on
% one key that AGREE cost nothing; two that DISAGREE make the experiment number
% unknowable and are marked ambiguous rather than resolved by order of arrival.
expByPlate  = containers.Map('KeyType', 'char', 'ValueType', 'any');
expAmbiguous = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:n
    if ~hasExpSrc(k) || isempty(sessions{k}); continue; end
    plateId = colVal(colsOf{k}, TOK_PLATE_ID());
    expId   = colVal(colsOf{k}, TOK_EXP_ID());
    if isempty(plateId) || isempty(expId); continue; end
    key = joinKey(sessions{k}, plateId);
    if isKey(expByPlate, key)
        if ~strcmp(expByPlate(key), expId); expAmbiguous(key) = true; end
    else
        expByPlate(key) = expId;
    end
end

% ==========================================================================
% STAGE A -- decide which subjects are WARRANTED and NAMEABLE, and build them.
% ==========================================================================
% Two independent questions, asked in this order and counted separately:
%   1. is the tier warranted?  -- does the ROW carry a measurement this tier can
%      type. The test is on the row's VALUES, never on the table's schema: all
%      14 plate columns and all 10 patch columns exist by construction, and
%      whether a given row HAS values is a per-document fact only checkable
%      here. And it is "at least one EMITTABLE typed observation", not "at least
%      one non-empty column": a row carrying only a logical flag has a value
%      this tier cannot represent, and minting a subject for it would produce
%      exactly the empty subject the refinement forbids. That case is counted
%      separately rather than absorbed into "no values".
%   2. can it be NAMED? -- the identifier directive. No component is invented,
%      so a hop that does not resolve REFUSES the mint.

subjectBodies = {};
subjectMeta   = struct('idx', {}, 'kind', {}, 'docId', {}, 'sessionId', {}, ...
                       'plateKey', {});
pendingObs    = {};
% PARALLEL ARRAYS, one entry per handle this pass FORMS. The session id travels
% beside the handle because the question the team asked -- "is it not
% within-session unique?" -- cannot be answered from the handle list alone, and
% recovering the session by re-reading the batch afterwards would be a second
% join with its own failure modes.
formedHandles  = {};
formedSessions = {};

for k = 1:n
    kind = kinds(k);
    if kind ~= 1 && kind ~= 3; continue; end
    cols = colsOf{k};

    if kind == 1
        idTokens = {TOK_PLATE_ID()};
        measures = plateMeasures();
    else
        idTokens = {TOK_IMAGE_ID(), TOK_PATCH_ID()};
        measures = lawnMeasures();
    end

    % ---- question 1: is the tier warranted -------------------------------
    obs = {};
    for m = 1:size(measures, 1)
        c = colByToken(cols, measures{m, 1});
        if isempty(c); continue; end
        [ok, num] = scalarNumber(c{1}.value);
        if ~ok; continue; end
        obs{end+1} = {measures{m, 2}, measures{m, 3}, ...
            variableTerm(c{1}), num}; %#ok<AGROW>
    end
    if isempty(obs)
        % THE THREE STATES, KEPT APART. "row present, no values at all" and
        % "row present, values this tier cannot type" are different findings and
        % the team asked for the first one specifically.
        anyValue = rowHasAnyValue(cols, idTokens);
        if kind == 1 && anyValue
            report.plate_rows_with_values_but_none_emittable = ...
                report.plate_rows_with_values_but_none_emittable + 1;
        elseif kind == 1
            report.plate_rows_with_no_values_at_all = ...
                report.plate_rows_with_no_values_at_all + 1;
        elseif anyValue
            report.lawn_rows_with_values_but_none_emittable = ...
                report.lawn_rows_with_values_but_none_emittable + 1;
        else
            report.lawn_rows_with_no_values_at_all = ...
                report.lawn_rows_with_no_values_at_all + 1;
        end
        continue;
    end
    if kind == 1
        report.plate_rows_with_measurements = report.plate_rows_with_measurements + 1;
    else
        report.lawn_rows_with_measurements = report.lawn_rows_with_measurements + 1;
    end

    % ---- question 2: can it be named -------------------------------------
    if isempty(sessions{k})
        if kind == 1
            report.plate_rows_refused_no_session_id = ...
                report.plate_rows_refused_no_session_id + 1;
        else
            report.lawn_rows_refused_no_session_id = ...
                report.lawn_rows_refused_no_session_id + 1;
        end
        continue;
    end
    idVals = cell(1, numel(idTokens));
    haveIds = true;
    for c = 1:numel(idTokens)
        idVals{c} = colVal(cols, idTokens{c});
        if isempty(idVals{c}); haveIds = false; end
    end
    if ~haveIds
        if kind == 1
            report.plate_rows_refused_no_plate_key = ...
                report.plate_rows_refused_no_plate_key + 1;
        else
            report.lawn_rows_refused_no_identity_keys = ...
                report.lawn_rows_refused_no_identity_keys + 1;
        end
        continue;
    end

    if kind == 1
        plateId = idVals{1};
        plateKey = joinKey(sessions{k}, plateId);
        expId = lookupExp(expByPlate, expAmbiguous, plateKey);
        if isempty(expId)
            % The E. coli plate row carries `expID` itself (doImport.m:714), so
            % this fires only on a row that lost it. No component is invented.
            report.plate_rows_refused_no_exp_id = ...
                report.plate_rows_refused_no_exp_id + 1;
            continue;
        end
        localId = plateHandle(expId, plateId);
        description = 'bacterial plate (a plate of lawns)';
    else
        % THE TWO-HOP CHAIN, which produces the triple AND the group. Refusals
        % are per-hop so a failure says WHICH hop.
        report.chains_attempted = report.chains_attempted + 1;
        imageKey = joinKey(sessions{k}, idVals{1});
        if ~isKey(imageCount, imageKey)
            report.refused_no_image_row = report.refused_no_image_row + 1;
            continue;
        end
        if imageCount(imageKey) > 1
            report.refused_image_row_ambiguous = report.refused_image_row_ambiguous + 1;
            continue;
        end
        plateId = imagePlate(imageKey);
        if isempty(plateId)
            report.refused_image_row_has_no_plate_key = ...
                report.refused_image_row_has_no_plate_key + 1;
            continue;
        end
        plateKey = joinKey(sessions{k}, plateId);
        if ~isKey(plateCount, plateKey)
            report.refused_no_plate_row = report.refused_no_plate_row + 1;
            continue;
        end
        if plateCount(plateKey) > 1
            report.refused_plate_row_ambiguous = report.refused_plate_row_ambiguous + 1;
            continue;
        end
        expId = lookupExp(expByPlate, expAmbiguous, plateKey);
        if isempty(expId)
            report.refused_lawn_no_exp_id = report.refused_lawn_no_exp_id + 1;
            continue;
        end
        report.chains_resolved = report.chains_resolved + 1;
        localId = patchHandle(expId, plateId, idVals{2});
        description = 'bacterial lawn (a bacterial patch)';
    end

    body = makeSubject(bodies{k}, localId, description);
    if numel(localId) > 256
        % maxLength 256 on subject.local_identifier. Falling back to the id
        % keeps uniqueness; truncating would destroy the very thing the
        % qualification exists to provide.
        body.subject.local_identifier = body.base.id;
        report.local_identifier_fallback_to_document_id = ...
            report.local_identifier_fallback_to_document_id + 1;
    else
        formedHandles{end+1}  = localId;      %#ok<AGROW>
        % NON-EMPTY BY CONSTRUCTION HERE: the "question 2" guard above refuses a
        % row with no `base.session_id` before it can reach a mint. Recorded
        % rather than asserted, so that relaxing that guard shows up in
        % `local_identifier_collisions_unclassifiable_no_session_id` instead of
        % being silently counted as a cross-session collision.
        formedSessions{end+1} = sessions{k};  %#ok<AGROW>
    end

    subjectBodies{end+1} = body; %#ok<AGROW>
    subjectMeta(end+1) = struct('idx', k, 'kind', kind, ...
        'docId', body.base.id, 'sessionId', sessions{k}, ...
        'plateKey', plateKey); %#ok<AGROW>
    pendingObs{end+1} = obs; %#ok<AGROW>
end

% A lawn row that was never minted has no member end, so its edge is withheld
% too. Counted from the lawn side so the two tiers stay separable, which is what
% the refinement asked for.
report.withheld_lawn_tier_not_minted = ...
    report.lawn_rows_with_values_but_none_emittable ...
    + report.lawn_rows_with_no_values_at_all;

% ==========================================================================
% STAGE B -- the C. elegans patch relabel (directive 2).
% ==========================================================================
% `applyPatchGeometryMap` mints these in pass 1 with the PAIR
% `plate/<plateID>/patch/<patchID>`, which is all a single-document migrator can
% form: that table has no `expID` column (doImport.m:290-292). This upgrades
% them to the triple where the plate -> expID hop resolves, id PRESERVED.
% Identified by the handle SHAPE plus the description pass 1 writes, so an
% unrelated subject can never be caught by it.
relabelBodies = {};
relabelIds = {};
for k = 1:n
    if ~strcmp(classes{k}, 'subject'); continue; end
    b = bodies{k};
    handle = subjectField(b, 'local_identifier');
    if ~strcmp(subjectField(b, 'description'), patchDescription()); continue; end
    report.celegans_patch_subjects_seen = report.celegans_patch_subjects_seen + 1;
    if strncmp(handle, 'exp/', 4)
        report.celegans_patch_subjects_already_triple = ...
            report.celegans_patch_subjects_already_triple + 1;
        continue;
    end
    [okParse, plateId, patchId] = parsePairHandle(handle);
    if ~okParse
        report.celegans_patch_subjects_unparseable_handle = ...
            report.celegans_patch_subjects_unparseable_handle + 1;
        continue;
    end
    sid = baseField(b, 'session_id');
    key = joinKey(sid, plateId);
    if isKey(expAmbiguous, key)
        report.celegans_patch_subjects_refused_ambiguous_exp_id = ...
            report.celegans_patch_subjects_refused_ambiguous_exp_id + 1;
        continue;
    end
    if isempty(sid) || ~isKey(expByPlate, key)
        % The pair stands. It still is not "just patch #", and the count says
        % how many did not make it to the triple.
        report.celegans_patch_subjects_refused_no_exp_id = ...
            report.celegans_patch_subjects_refused_no_exp_id + 1;
        continue;
    end
    newHandle = patchHandle(expByPlate(key), plateId, patchId);
    if numel(newHandle) > 256
        report.local_identifier_fallback_to_document_id = ...
            report.local_identifier_fallback_to_document_id + 1;
        continue;
    end
    b.subject.local_identifier = newHandle;
    relabelBodies{end+1} = b; %#ok<AGROW>
    relabelIds{end+1} = baseField(b, 'id'); %#ok<AGROW>
    formedHandles{end+1}  = newHandle; %#ok<AGROW>
    % Also non-empty by construction: the `isempty(sid)` arm above leaves the
    % pair standing and counts it, so a session-less subject never reaches here.
    formedSessions{end+1} = sid; %#ok<AGROW>
end

% THE COMBO THE TEAM ASSERTS IS UNIQUE, MEASURED RATHER THAN ASSUMED -- AND
% MEASURED AT THE GRAIN THE QUESTION WAS ASKED AT. The single batch-wide number
% this used to report could not distinguish "two patches in one session share a
% handle" (which refutes the directive) from "the two Haley sessions each hold
% one patch with the same handle" (which does not, because every index in this
% pass and every NDI subject resolver reached through a SESSION is already
% scoped by `base.session_id`). Both denominators and all three buckets, from
% one walk over the formed handles.
collisions = splitCollisions(formedHandles, formedSessions);
report.local_identifier_handles_formed   = collisions.formed;
report.local_identifier_handles_distinct = collisions.distinct;
report.local_identifier_collisions_within_batch  = collisions.total;
report.local_identifier_collisions_within_session = collisions.within_session;
report.local_identifier_collisions_across_sessions_only = ...
    collisions.across_sessions_only;
report.local_identifier_collisions_unclassifiable_no_session_id = ...
    collisions.unclassifiable;

if ~isempty(relabelBodies)
    [survivedR, quarantinedR] = validateBodies(relabelBodies, options);
    report.celegans_patch_relabel_quarantined = numel(quarantinedR);
    if ~isempty(quarantinedR)
        result = appendQuarantine(result, quarantinedR);
    end
    idToPos = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for k = 1:n
        id = baseField(bodies{k}, 'id');
        if ~isempty(id) && ~isKey(idToPos, id); idToPos(id) = k; end
    end
    for j = 1:numel(relabelIds)
        id = relabelIds{j};
        if isempty(id) || ~isKey(survivedR, id) || ~isKey(idToPos, id); continue; end
        docs{idToPos(id)} = survivedR(id);
        report.celegans_patch_subjects_relabelled = ...
            report.celegans_patch_subjects_relabelled + 1;
    end
end

if isempty(subjectBodies)
    report.refused_total = totalRefusals(report);
    result.migrated = docs;
    result.lawn_plate_subjects = report;
    return;
end

% ==========================================================================
% STAGE C -- validate the new subjects.
% ==========================================================================
% The bodies carry schema_version == TargetVersion, so v1_to_v2 short-circuits
% them (isAlreadyTarget) to ensureClassBlocks + validate. A subject that cannot
% validate lands in `quarantine` and NOTHING that points at it is emitted --
% which is why the subjects go first and everything with an edge goes second.
[survivedA, quarantinedA] = validateBodies(subjectBodies, options);
report.subjects_quarantined = numel(quarantinedA);
if ~isempty(quarantinedA)
    result = appendQuarantine(result, quarantinedA);
end

liveSubject = containers.Map('KeyType', 'char', 'ValueType', 'double');
appended = {};
for j = 1:numel(subjectMeta)
    id = subjectMeta(j).docId;
    if ~isKey(survivedA, id); continue; end
    liveSubject(id) = j;
    appended{end+1} = survivedA(id); %#ok<AGROW>
    if subjectMeta(j).kind == 1
        report.plate_subjects_minted = report.plate_subjects_minted + 1;
    else
        report.lawn_subjects_minted = report.lawn_subjects_minted + 1;
    end
end

% (session, plateID) -> the surviving plate subject's document id
plateSubjectId = containers.Map('KeyType', 'char', 'ValueType', 'char');
for j = 1:numel(subjectMeta)
    if subjectMeta(j).kind ~= 1; continue; end
    if ~isKey(liveSubject, subjectMeta(j).docId); continue; end
    plateSubjectId(subjectMeta(j).plateKey) = subjectMeta(j).docId;
end

% ==========================================================================
% STAGE D -- the observations and the member_of edges.
% ==========================================================================
% Everything built here carries an EDGE, so it is built only for subjects that
% actually landed. An observation whose subject quarantined would be a gating
% orphan; a `member_of` whose parent was never minted would be the same. Both
% are refused and counted instead.
statementBodies = {};
statementKind = [];      % 1 plate observation, 3 lawn observation, 0 relation
for j = 1:numel(subjectMeta)
    if ~isKey(liveSubject, subjectMeta(j).docId); continue; end
    obs = pendingObs{j};
    for i = 1:numel(obs)
        entry = obs{i};
        statementBodies{end+1} = makeObservation(bodies{subjectMeta(j).idx}, ...
            entry{1}, entry{2}, entry{3}, entry{4}, subjectMeta(j).docId); %#ok<AGROW>
        statementKind(end+1) = subjectMeta(j).kind; %#ok<AGROW>
    end
end
for j = 1:numel(subjectMeta)
    if subjectMeta(j).kind ~= 3; continue; end
    if ~isKey(liveSubject, subjectMeta(j).docId); continue; end
    plateKey = subjectMeta(j).plateKey;
    if ~isKey(plateSubjectId, plateKey)
        % The chain resolved -- the lawn could not have been minted otherwise --
        % so the plate ROW exists. The plate tier simply had nothing measured
        % about it, so no group subject was warranted. BOTH ENDS MUST EXIST, so
        % no relation, and the withholding is named by tier.
        report.withheld_plate_tier_not_minted = ...
            report.withheld_plate_tier_not_minted + 1;
        continue;
    end
    statementBodies{end+1} = makeMemberOf(bodies{subjectMeta(j).idx}, ...
        subjectMeta(j).docId, plateSubjectId(plateKey)); %#ok<AGROW>
    statementKind(end+1) = 0; %#ok<AGROW>
end

if ~isempty(statementBodies)
    [survivedB, quarantinedB] = validateBodies(statementBodies, options);
    report.statements_quarantined = numel(quarantinedB);
    if ~isempty(quarantinedB)
        result = appendQuarantine(result, quarantinedB);
    end
    % COUNTED FROM WHAT LANDED, never from what was intended: a body that
    % quarantined contributed nothing and must not appear in a total.
    for i = 1:numel(statementBodies)
        id = statementBodies{i}.base.id;
        if ~isKey(survivedB, id); continue; end
        appended{end+1} = survivedB(id); %#ok<AGROW>
        switch statementKind(i)
            case 1
                report.plate_observations_emitted = ...
                    report.plate_observations_emitted + 1;
            case 3
                report.lawn_observations_emitted = ...
                    report.lawn_observations_emitted + 1;
            otherwise
                report.member_of_relations_emitted = ...
                    report.member_of_relations_emitted + 1;
        end
    end
end

report.refused_total = totalRefusals(report);

result.migrated = [docs, appended];
report.documents_appended = numel(appended);
result.summary = recountSummary(result);
result.lawn_plate_subjects = report;
end

% ===================== the token vocabulary ================================
%
% Each token is the TERM LABEL from +haley/tableDoc_dictionary.json, normalised
% (lowercase, non-alphanumerics removed). See the header for why a token and not
% a shortName. Written as functions rather than a constant struct so a typo is a
% MATLAB error at the call site rather than a silently missing field.

function t = TOK_PLATE_ID()
t = 'bacterialplateidentifier';
end

function t = TOK_PATCH_ID()
t = 'bacterialpatchidentifier';
end

function t = TOK_IMAGE_ID()
t = 'microscopyimageidentifier';
end

function t = TOK_EXP_ID()
t = 'experimentsessionidentifier';
end

function t = TOK_POURED()
t = 'agarplatepouringtimestamp';
end

function t = TOK_POURED_COLD()
t = 'agarplatecoldstoragetimestamp';
end

function d = patchDescription()
%PATCHDESCRIPTION The description makePatchSubject writes in pass 1. Kept in one
%   place because the relabel below identifies its targets by it; if pass 1's
%   wording changes and this does not, the relabel silently stops finding them,
%   and testLawnPlateSubjects pins the pair.
d = 'bacterial patch';
end

function m = plateMeasures()
%PLATEMEASURES {token, leafClass, shapeClass} for the E. coli plate row.
%
%   CFU is a CONCENTRATION, not a count, and that is the writer's own arithmetic
%   rather than a preference: doImport.m:157 converts it to "CFU/mL of OD600 = 1
%   solution (standard)" -- an explicit per-volume normalisation. Both OD600
%   columns follow the precedent already in the tree (applyPatchGeometryMap maps
%   BacterialOD600TargetAtSeeding to concentration_observation).
%
%   The other TEN plate columns -- expID, the two labels, peptoneFlag, the five
%   timestamps and the strain document-id string -- are NOT typed here. They are
%   not lost: this pass is additive and the source row still carries every one
%   of them. A boolean leaf and a date leaf for this tier are separate
%   decisions, not something to invent inside a join.
m = {
    'bacterialod600measurement',                'concentration_observation', 'concentration'
    'bacterialod600targetatseeding',            'concentration_observation', 'concentration'
    'bacterialcolonyformingunitscfumeasurement','concentration_observation', 'concentration'
    'bacterialpatchvolume',                     'volume_observation',        'volume'};
end

function m = lawnMeasures()
%LAWNMEASURES {token, leafClass, shapeClass} for the E. coli patch/lawn row.
%
%   Radius -> length and circularity -> score follow applyPatchGeometryMap
%   exactly. The six fluorescence columns are dimensionless arbitrary units, and
%   D8 gives V_eta exactly one home for those -- `intensity_observation`, "J's
%   one dimensionless numeric; NO generic escape hatch". `borderCenterRatio` is
%   a ratio of two of them, so it goes there too rather than to `score`, which
%   carries a scale with a minimum and a maximum a ratio does not have.
m = {
    'bacterialpatchradius',                          'length_observation',    'length'
    'bacterialpatchcircularity',                     'score_observation',     'score'
    'bacterialpatchborderpeakfluorescenceintensity', 'intensity_observation', 'intensity'
    'bacterialpatchborderedgefluorescenceintensity', 'intensity_observation', 'intensity'
    'bacterialpatchborderfluorescenceamplitude',     'intensity_observation', 'intensity'
    'bacterialpatchmeanfluorescenceamplitude',       'intensity_observation', 'intensity'
    'bacterialpatchcenterfluorescenceamplitude',     'intensity_observation', 'intensity'
    'bacterialpatchbordertocenterfluorescenceratio', 'intensity_observation', 'intensity'};
end

function t = knownTokens()
%KNOWNTOKENS Every token this pass looks for. The `name` channel is consulted
%   ONLY for these, so an unrelated column can never be re-tokenised into one.
pm = plateMeasures();
lm = lawnMeasures();
t = [{TOK_PLATE_ID(), TOK_PATCH_ID(), TOK_IMAGE_ID(), TOK_EXP_ID(), ...
      TOK_POURED(), TOK_POURED_COLD()}, ...
     reshape(pm(:, 1), 1, []), reshape(lm(:, 1), 1, [])];
end

% ===================== identifiers =========================================

function h = plateHandle(expId, plateId)
h = sprintf('exp/%s/plate/%s', char(expId), char(plateId));
end

function h = patchHandle(expId, plateId, patchId)
%PATCHHANDLE The team's triple, in one place so the two tiers and the C. elegans
%   relabel cannot ship two spellings of one identifier in a single dataset.
h = sprintf('exp/%s/plate/%s/patch/%s', char(expId), char(plateId), char(patchId));
end

function [ok, plateId, patchId] = parsePairHandle(handle)
%PARSEPAIRHANDLE Read back the PAIR handle pass 1 writes --
%   `plate/<plateID>/patch/<patchID>`, built by `jPatchLocalId` in
%   +migrators_j/ontology_table_row.m, which is all a single-document migrator
%   can form because the C. elegans patch geometry table has no `expID` column
%   (doImport.m:290-292). Strict: anything else is reported as unparseable
%   rather than half-matched.
ok = false; plateId = ''; patchId = '';
if isempty(handle) || ~ischar(handle); return; end
tok = regexp(handle, '^plate/([^/]+)/patch/([^/]+)$', 'tokens', 'once');
if isempty(tok); return; end
ok = true; plateId = tok{1}; patchId = tok{2};
end

function expId = lookupExp(expByPlate, expAmbiguous, plateKey)
expId = '';
if isempty(plateKey); return; end
if isKey(expAmbiguous, plateKey); return; end
if isKey(expByPlate, plateKey); expId = expByPlate(plateKey); end
end

function tally = splitCollisions(handles, sessionIds)
%SPLITCOLLISIONS How many of the handles this pass formed are not distinct, and
%   -- the question the single number could not answer -- WHETHER THE
%   DUPLICATES SHARE A SESSION.
%
%   Reported, never acted on: the team asserts the combo is unique and this pass
%   implements the directive either way. A non-zero here is evidence for them,
%   not authorisation for this file to pick a different scheme.
%
%   RETURNS, denominators first (Rule 5):
%       formed               handles formed at all
%       distinct             how many of them are distinct
%       total                formed - distinct, the OLD counter, unchanged
%       within_session       excess sharing one `base.session_id`
%       across_sessions_only excess arising only BETWEEN sessions
%       unclassifiable       excess involving an occurrence with no session id
%
%   THE THREE ALWAYS SUM TO `total`, and they do so because `unclassifiable` is
%   computed as the REMAINDER rather than from a formula of its own. Per
%   distinct handle with n occurrences, of which m carry a non-empty session id
%   spread over k distinct sessions:
%
%       excess = n - 1
%       within = m - k                 (duplicates inside a single session)
%       across = max(k - 1, 0)         (one per extra session it appears in)
%       unclas = excess - within - across
%
%   which works out to the number of session-less occurrences when any
%   occurrence carries a session, and to that number minus one when none does.
%   Writing it as a remainder is what makes "a bucket quietly absorbed the
%   others" impossible rather than merely unlikely; testLawnPlateSubjects pins
%   the identity itself, not only the numbers.
%
%   A note on the scope of the denominator, because it is narrower than "every
%   subject handle in the batch": these are the handles THIS PASS forms -- the
%   plate/lawn mints and the C. elegans relabels. A pair handle left standing by
%   `celegans_patch_subjects_refused_no_exp_id` was formed by pass 1 and is not
%   counted here.
tally = struct('formed', numel(handles), 'distinct', 0, 'total', 0, ...
    'within_session', 0, 'across_sessions_only', 0, 'unclassifiable', 0);
if isempty(handles); return; end

% One record per distinct handle: how many times it was formed, in which
% sessions, and how many times with no session id at all.
byHandle = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(handles)
    h = handles{k};
    s = '';
    if k <= numel(sessionIds) && ~isempty(sessionIds{k}); s = char(sessionIds{k}); end
    if isKey(byHandle, h)
        rec = byHandle(h);
    else
        rec = struct('n', 0, 'sessions', {{}}, 'counts', []);
    end
    rec.n = rec.n + 1;
    if ~isempty(s)
        idx = find(strcmp(rec.sessions, s), 1);
        if isempty(idx)
            rec.sessions{end+1} = s;
            rec.counts(end+1) = 1;
        else
            rec.counts(idx) = rec.counts(idx) + 1;
        end
    end
    byHandle(h) = rec;
end

% `.Count`, NOT numel(): numel() on a containers.Map is 1 (it is a scalar
% object), and double() because Count is UINT64 while every field of this
% report is a double -- the defect epochMint.m:368-378 and the canary above
% both record, arriving here for the third time.
tally.distinct = double(byHandle.Count);
tally.total = tally.formed - tally.distinct;

names = keys(byHandle);
for i = 1:numel(names)
    rec = byHandle(names{i});
    nSessions = numel(rec.sessions);        % k: distinct non-empty sessions
    nWithSession = sum(rec.counts);         % m: occurrences carrying one
    excess = rec.n - 1;
    within = nWithSession - nSessions;
    across = max(nSessions - 1, 0);
    tally.within_session = tally.within_session + within;
    tally.across_sessions_only = tally.across_sessions_only + across;
    % THE REMAINDER, not a formula. This is what makes the three a partition
    % rather than three counters that happen to agree today.
    tally.unclassifiable = tally.unclassifiable + (excess - within - across);
end
end

% ===================== classification ======================================

function kind = classifyTable(cols)
%CLASSIFYTABLE 0 unclassified, 1 E. coli plate, 2 E. coli image, 3 E. coli lawn.
%   See the header for the 6-table disjointness argument. Each clause states
%   both what must be present AND what must be absent, because the two C.
%   elegans plate tables carry plateID + OD600 + CFU and would otherwise match
%   the plate arm -- the misfire of commit 112bcf1, one table over.
kind = 0;
hasPlate = ~isempty(colByToken(cols, TOK_PLATE_ID()));
hasPatch = ~isempty(colByToken(cols, TOK_PATCH_ID()));
hasImage = ~isempty(colByToken(cols, TOK_IMAGE_ID()));
hasPoured = ~isempty(colByToken(cols, TOK_POURED())) ...
    || ~isempty(colByToken(cols, TOK_POURED_COLD()));
if hasImage && hasPatch && ~hasPlate
    kind = 3;
elseif hasImage && hasPlate && ~hasPatch
    kind = 2;
elseif hasPlate && hasPoured && ~hasImage
    kind = 1;
end
end

function tf = rowHasAnyValue(cols, idTokens)
%ROWHASANYVALUE Does any NON-IDENTITY column of this row carry a value?
%   The identity columns are excluded because a row consisting only of its own
%   key says nothing about the thing it names, and calling that "has values"
%   would collapse the two states the refinement asked to keep apart.
tf = false;
for i = 1:numel(cols)
    if any(strcmp(cols{i}.token, idTokens)); continue; end
    v = cols{i}.value;
    if isempty(v); continue; end
    if isnumeric(v) && all(isnan(v(:))); continue; end
    tf = true;
    return;
end
end

% ===================== body builders =======================================

function body = makeSubject(srcBody, localId, description)
%MAKESUBJECT A bare V_eta subject with a FRESH id.
%   Mirrors makePatchSubject in +migrators_j/ontology_table_row.m except for the
%   id: that one PRESERVES the source id because the encounter relation names
%   the row as its parent. Here the source row is NOT consumed -- it stays in
%   the batch -- so preserving would put two documents on one id.
body = struct();
body.document_class = struct('class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', {}, 'value', {});
body.base = freshBase(srcBody, 'migrated_lawn_plate_subject');
body.subject = struct('local_identifier', char(localId), ...
    'description', description);
end

function body = makeObservation(srcBody, leafClass, shapeClass, variable, num, subjectId)
%MAKEOBSERVATION One typed observation of one subject.
%   The value shapes mirror makeEncObs in +migrators_j/ontology_table_row.m,
%   which is corpus-proven. NO `time_reference_1` edge: it is optional on
%   subject_interaction and there is no time to put in one -- see the header.
body = struct();
body.document_class = struct('class_name', leafClass, 'class_version', '1.0.0', ...
    'superclasses', supersOf({'subject_observation', shapeClass}), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', 'subject_id', 'value', subjectId);
body.base = freshBase(srcBody, 'migrated_lawn_plate_measure');
body.subject_statement   = struct('variable', variable, 'storage_mode', 'inline');
body.subject_interaction = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
body.subject_observation = struct();
if strcmp(shapeClass, 'score')
    body.score = struct('value', struct('value', double(num), ...
        'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false));
else
    body.(shapeClass) = struct('value', ...
        struct('source_unit', '', 'source_value', double(num), ...
        'approximate', false));
end
end

function rel = makeMemberOf(srcBody, lawnId, plateId)
%MAKEMEMBEROF lawn --member_of--> plate.
%   `member_of` is NOT a new relation: binding_registry_meta.json already
%   carries it as RO:0002350 on `directed_relation`, child_role "the member",
%   parent_role "the group", child_types and parent_types both `subject` --
%   which is exactly this pair -- and the signed ensemble decision uses the same
%   relation for group membership.
%
%   NO `time_reference_#` and NO `epoch_id`: both are optional, and a lawn's
%   membership of its plate is a standing structural fact, not an event.
%   `method` is left empty for the reason the schema itself gives ("Empty for
%   standing structural relations (part_of, member_of)").
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', 'superclasses', supersOf({'relation'}), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', lawnId), ...     % the member: the lawn
    struct('name', 'parent', 'value', plateId)];       % the group: the plate
rel.base = freshBase(srcBody, 'migrated_lawn_plate_membership');
rel.directed_relation = struct('relation', ...
    struct('node', 'RO:0002350', 'name', 'member_of'));
end

function supers = supersOf(chain)
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
end

function base = freshBase(srcBody, name)
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isstruct(srcBody) && isfield(srcBody, 'base') && isstruct(srcBody.base)
    if isfield(srcBody.base, 'session_id'); sessionId = srcBody.base.session_id; end
    if isfield(srcBody.base, 'datestamp') && ~isempty(srcBody.base.datestamp)
        ds = srcBody.base.datestamp;
    end
end
base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end

% ===================== column reading ======================================

function [cols, byKey, byName] = extractColumns(block)
%EXTRACTCOLUMNS Normalise an ontology_table_row block to a cell of column
%   structs {key, name, node, value, token}.
%
%   TOKEN is the normalised handle this pass matches on: the column's `key`
%   (shortName) normalised, or -- when that resolves to nothing this pass knows
%   -- the column's `name` (the term name) normalised. Both are recorded so the
%   report can say which channel is load-bearing on real data; if a corpus ever
%   reports every column resolved by NAME, the shortName rule in the header is
%   wrong and the log says so.
cols = {}; byKey = 0; byName = 0;
if ~isstruct(block) || ~isfield(block, 'variable_names'); return; end
vars  = splitCSV(charField(block, 'variable_names'));
names = splitCSV(charField(block, 'names'));
nodes = splitCSV(charField(block, 'ontology_nodes'));
data = struct();
if isfield(block, 'data') && isstruct(block.data); data = block.data; end
known = knownTokens();
for i = 1:numel(vars)
    key = vars{i};
    nm = ''; nd = '';
    if i <= numel(names); nm = names{i}; end
    if i <= numel(nodes); nd = nodes{i}; end
    val = [];
    if ~isempty(key) && isfield(data, key); val = data.(key); end
    tokKey  = normaliseToken(key);
    tokName = normaliseToken(nm);
    token = tokKey;
    if any(strcmp(tokKey, known))
        byKey = byKey + 1;
    elseif any(strcmp(tokName, known))
        token = tokName;
        byName = byName + 1;
    end
    cols{end+1} = struct('key', key, 'name', nm, 'node', nd, ...
        'value', val, 'token', token); %#ok<AGROW>
end
end

function out = normaliseToken(s)
%NORMALISETOKEN Lowercase, and drop every character that is not a-z or 0-9.
%   This is what makes "BacterialPatchCenter_XCoordinate" and "bacterial patch
%   center: X coordinate" the SAME handle, which is the whole reason this pass
%   does not have to guess a shortName. See the header for the five
%   corpus-proven pairs that confirm the rule.
out = '';
if isempty(s); return; end
if isstring(s); s = char(s); end
if ~ischar(s); return; end
s = lower(s);
keep = (s >= 'a' & s <= 'z') | (s >= '0' & s <= '9');
out = s(keep);
end

function c = colByToken(cols, token)
c = {};
for i = 1:numel(cols)
    if strcmp(cols{i}.token, token); c = cols(i); return; end
end
end

function v = colVal(cols, token)
v = '';
c = colByToken(cols, token);
if isempty(c); return; end
x = c{1}.value;
if ischar(x); v = x;
elseif isstring(x) && isscalar(x); v = char(x);
elseif isnumeric(x) && isscalar(x) && ~isnan(x); v = num2str(x); end
end

function term = variableTerm(col)
%VARIABLETERM The statement's `variable`, which is REQUIRED and mustBeNonEmpty.
%   The column's real ontology node is used when it has one -- dropping it would
%   be a loss, and the per-table maps in pass 1 pass '' only because they were
%   written before the node was threaded through. `name` falls back to the key
%   and then to the token, so the term can never be entirely blank.
node = ''; name = '';
if isfield(col, 'node') && ischar(col.node); node = col.node; end
if isfield(col, 'name') && ischar(col.name); name = col.name; end
if isempty(name) && isfield(col, 'key') && ischar(col.key); name = col.key; end
if isempty(name); name = col.token; end
term = struct('node', node, 'name', name);
end

function [ok, num] = scalarNumber(x)
%SCALARNUMBER A value this tier can put in a typed observation.
%   Scalar, numeric (or a char that parses as one), finite. A logical is NOT
%   accepted: there is no boolean leaf, and a `1` recorded as an intensity would
%   assert a measurement nobody made. A vector is not accepted either -- it
%   wants a sampled_body. Both cases keep the value on the source row, which is
%   still there, and are counted as `*_with_values_but_none_emittable`.
ok = false; num = [];
if isempty(x); return; end
if islogical(x); return; end
if isnumeric(x)
    if ~isscalar(x); return; end
    if isnan(x) || isinf(x); return; end
    ok = true; num = double(x); return;
end
if isstring(x) && isscalar(x); x = char(x); end
if ischar(x)
    v = str2double(x);
    if ~isnan(v) && ~isinf(v); ok = true; num = v; end
end
end

function parts = splitCSV(s)
parts = {};
if isempty(s); return; end
parts = strsplit(char(s), ',');
for k = 1:numel(parts); parts{k} = strtrim(parts{k}); end
end

% ===================== batch plumbing ======================================

function [survived, quarantined] = validateBodies(newBodies, options)
%VALIDATEBODIES Push bodies through v1_to_v2 and return what survived, by id.
%   SURVIVED is a containers.Map from base.id to the produced did2.document, so
%   a caller can ask "did THIS body land" rather than matching on position -- a
%   quarantined body leaves no slot, and the id is the one thing this pass
%   guarantees is unchanged.
out = did2.convert.v1_to_v2(newBodies, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);
survived = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(out.migrated)
    try
        survived(char(out.migrated{k}.get('base.id'))) = out.migrated{k};
    catch
    end
end
quarantined = out.quarantine;
end

function result = appendQuarantine(result, quarantined)
if isfield(result, 'quarantine') && ~isempty(result.quarantine)
    result.quarantine = [result.quarantine, quarantined];
else
    result.quarantine = quarantined;
end
end

function total = totalRefusals(report)
total = report.plate_rows_refused_no_session_id ...
    + report.plate_rows_refused_no_plate_key ...
    + report.plate_rows_refused_no_exp_id ...
    + report.lawn_rows_refused_no_session_id ...
    + report.lawn_rows_refused_no_identity_keys ...
    + report.refused_no_image_row ...
    + report.refused_image_row_ambiguous ...
    + report.refused_image_row_has_no_plate_key ...
    + report.refused_no_plate_row ...
    + report.refused_plate_row_ambiguous ...
    + report.refused_lawn_no_exp_id;
end

function k = joinKey(sessionId, localId)
%JOINKEY Session-scoped. `plateID` collides across the two Haley sessions
%   (doImport.m:166 adds expType*1000, :729 does not) and both land in ONE
%   ndi.dataset.dir, so an unscoped key would attach C. elegans data to E. coli
%   lawns. The separator is a character neither an NDI id nor a %.4i label
%   contains.
k = [char(sessionId) '|' char(localId)];
end

function summary = recountSummary(result)
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

% ===================== readers =============================================

function cn = classNameOf(b)
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function v = baseField(b, name)
v = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, name)
    x = b.base.(name);
    if ischar(x) || isstring(x); v = char(x); end
end
end

function v = subjectField(b, name)
v = '';
if isstruct(b) && isfield(b, 'subject') && isstruct(b.subject) ...
        && isscalar(b.subject) && isfield(b.subject, name)
    x = b.subject.(name);
    if ischar(x); v = x; elseif isstring(x) && isscalar(x); v = char(x); end
end
end

function v = charField(block, name)
v = '';
if isstruct(block) && isfield(block, name)
    x = block.(name);
    if ischar(x); v = x; elseif isstring(x) && isscalar(x); v = char(x); end
end
end
