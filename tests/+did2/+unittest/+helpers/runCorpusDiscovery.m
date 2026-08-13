function corpusDir = runCorpusDiscovery(testCase, corpusName, corpusURL, innerDir, options)
%RUNCORPUSDISCOVERY Shared driver for v1 corpus discovery-mode tests.
%
%   CORPUSDIR = did2.unittest.helpers.runCorpusDiscovery(TESTCASE, CORPUSNAME,
%       CORPUSURL, INNERDIR) is the body of each per-corpus discovery
%   test. It handles the schema-path probe + override, downloads and
%   caches the corpus zip, runs every contained v1 document through
%   did2.convert.v1_to_v2 with Validate=true, writes the per-run
%   summary JSON under corpus-reports/<CORPUSNAME>-summary.json, and
%   prints a stdout summary that the CI log captures.
%
%   The test that calls this function is responsible for any
%   pre-call gating (e.g., env-var guards), and for the schema-path
%   teardown via did2.unittest.helpers.restoreSchemaPath.
%
%   Returns the corpus directory it walked, so callers can layer
%   extra assertions on top if they want.
%
%   This is **discovery mode**: nothing is asserted about the
%   migrated_count / quarantine_count split; the report is the
%   deliverable.
%
%   STATUS of the 2026-08-11 epoch-string retention edit: THE SAME, and said
%   again rather than assumed. WRITTEN WITHOUT MATLAB and NOT EXECUTED --
%   `command -v matlab octave octave-cli` exits 1 in the container it was
%   written in. What IS proven is the static wiring
%   (tools/test_batch_pass_wiring.py::test_the_epoch_string_retention_instrument_is_wired_end_to_end,
%   run green here) and the counter's own unit tests in testEpochStrings.m,
%   which the quick gate runs. What is UNPROVEN is this file's
%   `printEpochStringRetention` body: NO gate available here executes
%   runCorpusDiscovery, so its first run is a real corpus run. That is why the
%   call to it is guarded below.
%
%   STATUS of the 2026-08-10 batch-post-pass wiring edit: WRITTEN WITHOUT
%   MATLAB. The container this was edited in has no MATLAB, so the new
%   `runBatchPass` guard, the `resolveSessionAnchors` call and `printBatchPasses`
%   have NOT been executed. test-migrators-quick.yml is the first thing that
%   will have an opinion; testFixtureCorpus exercises the same post-pass
%   sequence in ~2 minutes and should be read before any full corpus run.

arguments
    testCase
    corpusName (1,:) char
    corpusURL  (1,:) char
    innerDir   (1,:) char
    options.TargetVersion (1,:) char = 'V_eta'
    % V_eta (Brainstorm J) is the migration/validation target. Orphan-freeness
    % is a HARD GATE once a target migrates the whole corpus orphan-free. The
    % full V_eta run now does: every corpus (20211116, B, Dab, JH, Soph)
    % migrates with 0 orphans of >900k edges after the per-table maps (JH patch
    % subject) and the bath -> dose_manipulation retarget, so the sweep is
    % asserted again -- a migrator change that reintroduces an orphan fails the
    % corpus test instead of only logging it.
    options.AssertNoOrphans (1,1) logical = true
end

did2.unittest.helpers.installSchemaPath(testCase, sprintf('skipping %s corpus test', corpusName));

cacheName = ['did2-corpus-' innerDir];
corpusDir = did2.unittest.helpers.ensureCorpus(corpusURL, cacheName, innerDir);

files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
verifyGreaterThan(testCase, numel(files), 0, ...
    sprintf('No JSON files found under %s', corpusDir));

bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end

result = did2.convert.v1_to_v2(bodies, 'Validate', true, ...
    'TargetVersion', options.TargetVersion);

% Coarse, DID-only second pass: resolve the stimulus_baths the per-document
% converter deferred (needsSessionContext), using the migrated element docs
% already in this batch for subject_id + a session_relative anchor. This is
% the standalone/corpus counterpart to ndi.migrate.local's precise
% (epoch-bounded) resolution; without a live NDI session it is the honest
% best. A stimulus_bath whose element is not in the corpus stays quarantined.
%
% GUARDED 2026-08-11, and it is a repair rather than a precaution. This pass
% runs FIRST and moves documents from `quarantine` into `migrated`; until it
% acquired a report (`deferred_bath_resolution`) its per-bath failures were
% swallowed by a bare `catch` whose body was two comment lines, so "resolved
% every deferred bath" and "resolved none, every element missing" were the same
% reading of every corpus run -- run 31522068566 included. It runs BEFORE
% writeCorpusReport, so a throw here costs the corpus its entire census, which
% is why every sibling below is guarded; it is in the FATAL pass list after the
% report write, so a throw still turns the run red.
result = did2.unittest.helpers.runBatchPass(result, ...
    'did2.convert.resolveDeferredBaths', 'deferred_bath_resolution', ...
    @(r) did2.convert.resolveDeferredBaths(r, ...
        'Validate', true, 'TargetVersion', options.TargetVersion));

% Finalize the dataset entity layer (V_eta): dedup the `dataset` entities that
% the dataset-level containers each mint on the shared dataset id (richest wins,
% so the metadata_editor dataset beats the bare stubs), and drop best-effort
% session-membership edges whose linked member session is not in this batch.
%
% THIS LINE USED TO READ "the DID-only counterpart to ndi.migrate's
% dataset-aware second pass", and there was no such pass: ndi.migrate.local
% never called this, and named it once, in a comment about where epochMint
% lives (local.m). So the sentence asserted a production behaviour from the
% existence of the DID one, and for as long as it stood the corpus gate was
% green on a dedup + prune the real migration path did not perform. STATUS:
% ndi.migrate.local now calls this same function as V_eta second-pass step
% (4b) -- WIRED 2026-08-10, NOT EXECUTED (no MATLAB available). Not a
% counterpart: the SAME code, which is what keeps the two pipelines one.
if strcmp(options.TargetVersion, 'V_eta')
    % TEAM DECISION 2026-08-11 ("Do B"): assemble the openMINDS dataset
    % CITATION graph into the entity tier -- the same six classes
    % metadata_editor emits, read from the independent openMINDS store. It is
    % ADDITIVE: the graph holds only a DOI for a related publication while the
    % editor blob carries title/DOI/PMID/PMCID, 0 of 6 corpora carry both, and
    % neither store dominates, so the editor path is not replaced or weakened.
    %
    % ORDER: FIRST in this block, BEFORE resolveDatasetEntities, and that is
    % load-bearing rather than cosmetic. The dedup below keeps the RICHEST
    % `dataset` entity per id; the one minted here is keyed on the same dataset
    % id as the `dataset_remote` / `session_in_a_dataset` / `dataset_session_info`
    % stubs and carries the real names, so it wins that ranking -- but only if
    % it is in the batch when the ranking runs.
    %
    % READ ITS ZEROS WITH `openminds_documents_seen` BESIDE THEM. Every counter
    % at 0 with 0 openminds documents means "this corpus holds no openMINDS
    % graph", which was true of 5 of 6 corpora at the last measurement (run
    % 31441923369: 8 openminds documents, all in JH). Zeros beside a NON-ZERO
    % `components_withheld` mean the orphan guard refused the work, which is a
    % finding; the reason strings say which component and why.
    %
    % GUARDED for the same reason as the passes below: writeCorpusReport is
    % ~230 lines on and an uncaught error here costs the corpus its entire
    % census for a run that already spent an hour. A failure leaves every
    % document in its pass-1 form, which is the state the corpus is green in.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.resolveOpenmindsCitations', 'openminds_citations', ...
        @(r) did2.convert.resolveOpenmindsCitations(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % GUARDED 2026-08-11, for the same reason as its siblings and one of its
    % own: THIS PASS DELETES DOCUMENTS. Both of its `keep(k) = false` sites --
    % the poorer of duplicate `dataset` entities, and every
    % `migrated_session_membership` edge whose child is absent from the batch
    % -- fed `result.migrated = docs(keep)` while nothing counted either. Its
    % report (`dataset_entity_resolution`) keeps the two reasons apart, because
    % a dedup loses nothing and a discarded membership edge loses a statement.
    % In the FATAL pass list after the report write: the guard is here to save
    % the artifact, not to excuse a throw.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.resolveDatasetEntities', 'dataset_entity_resolution', ...
        @(r) did2.convert.resolveDatasetEntities(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % Mint the `epoch` entities did_v1 never had, one per distinct
    % (base.session_id, epoch-id string) -- the PAIR, because an
    % `epochid.epochid` string is reused across sessions (142 of B's 149
    % distinct ids, sourceCensus run 31415147934), so keying on the string
    % alone would FUSE epochs from different sessions. A find-or-create over
    % the whole corpus, which no single-document migrator can do; its report
    % rides on `result.epoch_mint` and is persisted by writeCorpusReport.
    %
    % GUARDED (2026-08-10). Not because a failure is tolerable, but because of
    % WHERE it would land: writeCorpusReport is ~30 lines below, so an uncaught
    % error here costs the corpus its ENTIRE census -- by_class survivors,
    % silent-loss table, source census, the lot -- for a run that already spent
    % an hour. did2.unittest.helpers.runBatchPass records the failure on
    % `result.epoch_mint.pass_failed`, prints it to stderr with the stack, and
    % leaves every document in its pass-1 form. See that file for the rule.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.epochMint', 'epoch_mint', ...
        @(r) did2.convert.epochMint(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % #65: fold `session_relative_reference` (107,308 documents) and
    % `session_bounded_reference` (20,411) into `relative_reference`, base.id
    % PRESERVED, anchored to the SESSION DOCUMENT. A pass-1 migrator cannot do
    % this: it holds `base.session_id`, and the REQUIRED `relative_to` edge
    % needs the session document's `base.id`, which NDI mints separately
    % (+ndi/document.m:57-58 vs +ndi/session.m:215). Mapping one to the other
    % is a corpus-wide index, so it is a batch pass.
    %
    % ORDER. It runs AFTER epochMint, and that order is NOT forced by today's
    % code -- said plainly rather than dressed up. Both passes index `session`
    % documents by (base.session_id -> base.id); neither writes what the other
    % reads (epochMint appends `epoch` documents and fills
    % method_parameters.epoch_id; this pass rewrites only the two
    % session_*_reference classes), and no post-pass in this file removes a
    % `session` document -- resolveDatasetEntities drops only duplicate
    % `dataset` entities and unresolvable membership relations
    % (resolveDatasetEntities.m:55,62-63,73-77), resolveDeferredBaths only
    % appends (resolveDeferredBaths.m:84), epochMint only appends. So the two
    % commute on this corpus. The order is chosen for three reasons that are
    % not correctness: it is IDENTICAL to ndi.migrate.local's, so the corpus
    % gate and production cannot silently diverge; this pass is strictly
    % 1 -> 1, so running it last makes its `documents_inspected` denominator
    % equal the report's final migrated_count; and if a later revision ever
    % anchors a reference to an `epoch` document (the plan's chains terminate
    % at an acquisition_epoch, a session, or an absolute_reference) the
    % dependency will point this way, not the other.
    %
    % GUARDED for the same reason as epochMint above, and with more cause: this
    % pass has NEVER been executed and it moves 127,719 documents on a
    % 0-quarantine, 0-orphan gate. A failure leaves the anchors exactly as
    % pass 1 emitted them -- which is the state the corpus is green in today --
    % and is recorded on `result.session_anchor_fold.pass_failed`.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.resolveSessionAnchors', 'session_anchor_fold', ...
        @(r) did2.convert.resolveSessionAnchors(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % #61, the RESOLVER half of the signed stimulus-response fold: inline the
    % five run knobs from `stimulus_response_scalar_parameters_basic` onto the
    % `harmonic_component_calculation` leaf's `subject_interaction.
    % method_parameters` and drop the `method_parameters_id` edge (the schema's
    % own rule: the inline field OR the edge, NEVER BOTH). A pass-1 migrator
    % cannot do it -- the six values live on a DIFFERENT document and a
    % single-document migrator cannot follow the edge -- which is why the plan's
    % BUILD section reads "one migrator plus one resolver pass".
    %
    % ORDER: last, and it commutes with all three passes above. It reads only
    % `harmonic_component_calculation` and `stimulus_response_scalar_parameters_basic`
    % documents; epochMint appends `epoch` documents and fills the
    % `method_parameters` CLASS's epoch edge (a different thing from the inline
    % `method_parameters` FIELD this pass writes), resolveSessionAnchors rewrites
    % only the two session_*_reference classes, and resolveDatasetEntities drops
    % only duplicate `dataset` entities and unresolvable membership relations.
    % Running last makes its `documents_inspected` denominator equal the final
    % migrated count, same as the pass above.
    %
    % IT DELETES NOTHING. The parameters documents (11,440 over five corpora at
    % the plan's last count -- run #257 / 0458dae, a SAMPLE) stay until a corpus
    % verify-before-delete says they may go; this pass MEASURES that gate
    % (`parameters_documents_unreferenced_after`) instead of pre-empting it.
    %
    % GUARDED for the same reason as the two above, and expect its counters to
    % read `leaves_seen: 0` beside a NON-ZERO `suppressed_responses_seen` until
    % #60 stamps the `epoch_id` edge -- that pair is the difference between
    % "nothing to do" and "blocked upstream", and the report prints both.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.resolveResponseParameters', 'response_parameters_fold', ...
        @(r) did2.convert.resolveResponseParameters(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % TEAM DECISION 2026-08-11: the E. coli lawns and plates are subjects, in
    % two tiers, with `lawn --member_of--> plate`; a tier is minted only where
    % it has something measured about it; and a patch subject's
    % `local_identifier` is the (experiment, plate, patch) triple. All three
    % need documents a single-document migrator cannot see -- the patch row
    % keys on `imageID`, not `plateID` (doImport.m:720), so both the membership
    % and the identifier come off the SAME two-hop chain
    % patch -> image -> plate.
    %
    % ORDER: last, and it commutes with all four passes above. It reads
    % `ontology_table_row` and `subject` documents; epochMint appends `epoch`
    % documents, resolveSessionAnchors rewrites only the two session_*_reference
    % classes, resolveResponseParameters touches only the two stimulus-response
    % classes, and resolveDatasetEntities drops only duplicate `dataset`
    % entities and unresolvable membership relations -- none of which this pass
    % reads or writes. Running last makes `documents_inspected` the denominator
    % of the batch as every other pass left it.
    %
    % READ ITS ZEROS WITH `unclassified_rows_in_those_sessions` BESIDE THEM.
    % Every counter at 0 with 0 recognised rows is "this corpus holds no E. coli
    % tables", which is true of five of the six corpora. Zeros beside a non-zero
    % unclassified count would mean the column-token rule is wrong. The pass
    % prints both; do not read one without the other.
    %
    % GUARDED for the same reason as the three above: writeCorpusReport is
    % ~30 lines below and an uncaught error here costs the corpus its entire
    % census for a run that already spent an hour. A failure leaves every
    % document in its pass-1 form, which is the state the corpus is green in.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.resolveLawnPlateSubjects', 'lawn_plate_subjects', ...
        @(r) did2.convert.resolveLawnPlateSubjects(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % TEAM DECISION 2026-08-11: `generic_file` folds to an `opaque_body` + a
    % statement whose `variable` comes from the SIBLING ontologyLabel. Batch,
    % not per-document, for the reason the pass's header gives: the `variable`
    % is in another document, so nothing single-doc can reach it.
    %
    % ORDER: last, and it commutes with all five above. It reads only
    % `generic_file` and `ontology_label` documents and writes only a
    % `term_observation` (on the source's own id) plus a new `opaque_body`;
    % none of the five reads or writes either class.
    %
    % READ ITS ZEROS WITH `generic_files_seen` BESIDE THEM. All six corpora
    % held ZERO `generic_file` documents at run 31327383671, so all-zero is the
    % EXPECTED reading here and says nothing about whether the fold works --
    % this class is written by the Babu converter for datasets that are not in
    % the gate. A non-zero `generic_files_seen` with `files_folded` at 0 is the
    % interesting line; `refused_*` then says which reason.
    %
    % GUARDED like its four siblings: writeCorpusReport is ~30 lines below and
    % an uncaught throw here costs the run its whole census.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.foldGenericFiles', 'generic_file_fold', ...
        @(r) did2.convert.foldGenericFiles(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));

    % DORMANT BY TEAM DECISION 2026-08-12. It is still WIRED and still RUNS --
    % as a CENSUS. It emits nothing.
    %
    % The team chose the ARRAY model (ONE statement per source document holding
    % an ARRAY of booleans against a TIME AXIS) and chose to WAIT for `axes[]`
    % (DID-schema OPEN_WORK #45 -> #32) rather than ship the 1->N
    % one-statement-per-interval decomposition as an interim step. The
    % decomposition code is preserved behind `options.Decompose`, default
    % FALSE; nothing here passes it.
    %
    % WHY IT IS STILL IN THE CHAIN. `sources_seen` and `intervals_seen` are the
    % only measurement anyone has of how much `valid_interval` data is waiting
    % on `axes[]`. Unwiring the pass would replace that number with a silence,
    % and a silence reads as a zero -- which is the whole reason this file
    % prints denominators at all.
    %
    % ORDER: LAST, unchanged. Its dependence on epochMint is REAL for the
    % ARMED path (it anchors to the `epoch` DOCUMENTS epochMint appends), and
    % keeping it last means re-arming it later needs no reordering. Nothing
    % else reads or writes `valid_interval`, `logical_observation` or
    % `relative_reference` in a way that conflicts: resolveSessionAnchors
    % rewrites only the two session_*_reference classes.
    %
    % IT ADDS AND NEVER REMOVES -- and while dormant it adds nothing at all.
    % The `valid_interval` source document stays in the batch under its own v1
    % tombstone, which is where these documents live until the array model is
    % built.
    %
    % READ ITS ZEROS WITH `sources_seen` BESIDE THEM. Every emission counter is
    % now 0 BY DECISION, so the ONLY informative lines are `sources_seen` and
    % `intervals_seen`. All six corpora held ZERO `valid_interval` documents at
    % run 31327383671, so even those are expected to be 0 -- a statement about
    % the SAMPLE, not about the pass. A non-zero `sources_seen` is the line
    % worth looking at: it is deferred work with a size.
    %
    % GUARDED like its six siblings: writeCorpusReport is below and an uncaught
    % throw here costs the run its whole census.
    result = did2.unittest.helpers.runBatchPass(result, ...
        'did2.convert.resolveValidIntervals', 'valid_interval_decompose', ...
        @(r) did2.convert.resolveValidIntervals(r, ...
            'Validate', true, 'TargetVersion', options.TargetVersion));
end

% Census of the V1 SOURCE bodies -- the only instrument here that reads the
% INPUT rather than the output. Three separate open items each say a build must
% not proceed until something is MEASURED on real data, and none of those
% numbers exists anywhere: whether grouping on `epochid.epochid` would fuse
% distinct epochs, whether a `session` document is present to be the referent of
% a required `relative_to`, and whether one stimulation approach covers several
% interactions. All three are properties of the v1 documents, so they are read
% here, where the corpus is in hand, rather than inferred later from class
% totals. Best-effort: the migration summary is the primary deliverable and a
% census failure must not mask it.
try
    result.source_census = did2.validate.sourceCensus(bodies);
catch censusErr
    result.source_census = struct('audit_failed', censusErr.message);
end

% THE EPOCH-STRING RETENTION MEASUREMENT. did2.validate.epochStringRetention was
% written 2026-08-10 and, until this line, was called from TESTS ONLY -- 8
% executable call sites, 7 in testEpochStrings.m and 1 in
% testStimulusResponseEpochGuard.m, 0 in src/ and 0 in tools/. A validator that
% has never run on real data is a validator whose value nobody knows. This is
% the first time it sees a corpus.
%
% REPORT-ONLY, AND DELIBERATELY SO. It raises nothing, gates nothing, and is not
% in the fatal post-pass list below. Nothing has measured how big the drop is,
% so arming anything on it would be the mistake
% did2.schema.cache.strictMode('BindingConformance') is deliberately not making:
% you do not gate on a number before you have the number.
%
% ---------------------------------------------------------------------------
% WHERE IT RUNS, AND WHY HERE RATHER THAN BESIDE silentLoss
% ---------------------------------------------------------------------------
% did2.validate.silentLoss is called EXACTLY ONCE, at v1_to_v2.m:382, INSIDE
% PASS 1 -- before any batch post-pass in this file exists to have run. That is
% why its `0 epoch document(s) in this batch` has been a tautology (DID-matlab
% 203c1f7, V_eta_OPEN_WORK.md #86a): epochMint appends the `epoch` documents
% AFTER silentLoss has already counted, so silentLoss cannot see one by
% construction and its zero says nothing about the corpus.
%
% This call is placed AFTER every batch post-pass, and that choice is what the
% number means:
%
%   * A PASS-1 NUMBER would answer "which migrators drop the string", and it
%     would count every pair epochMint turned into an `epoch` document as a
%     DROP -- because at that point no `epoch` document has been minted. The
%     instrument's own `retained_as_epoch_document` would be structurally 0,
%     which is the silentLoss tautology reproduced in a second instrument.
%   * A POST-PASS NUMBER, this one, answers "did the epoch string survive the
%     migration AS SHIPPED" -- retained because a document still spells it out,
%     OR retained because it became an `epoch` entity. That is the question the
%     drop matters for.
%
% THE TWO ARE NOT THE SAME NUMBER AND MUST NOT BE QUOTED AS ONE. What this
% placement CANNOT do is attribute a surviving drop to pass 1 versus a post-pass:
% `dropped_by_v1_class` names the v1 class that carried the string, not the
% stage that lost it. Separating those needs a SECOND call sited at pass-1
% output, which is deliberately not added here -- one number, sited once, with
% its meaning written down, rather than two numbers nobody can tell apart.
%
% WHAT IT CANNOT SEE, so the zeros are readable:
%   * a pair is RETAINED if ANY migrated document carries it. A class that drops
%     its own string shows up only when it was the SOLE carrier of that pair in
%     the whole corpus.
%   * a QUARANTINED source is not in result.migrated, so its pairs count as
%     dropped unless another document carries them. That is the honest reading
%     (a quarantined document migrated nothing) but it is a different cause from
%     a migrator that ate the field.
%   * `syncrule_mapping`'s endpoint strings are DECLINED by
%     did2.validate.epochStrings and are excluded from the denominator; they are
%     reported on their own line rather than folded in.
%   * a pre-`base` legacy document whose session id has not landed on `base` yet
%     keys as (empty session, string) on the v1 side and (real session, string)
%     on the migrated side -- a FALSE drop. `legacy_ndi_document` reports 0 such
%     documents in all six corpora, so this is a named risk, not a live one.
%
% Best-effort like the census above it: the migration summary is the primary
% deliverable and an instrument failure must not mask it.
try
    result.epoch_string_retention = did2.validate.epochStringRetention( ...
        bodies, result.migrated);
catch retentionErr
    result.epoch_string_retention = struct('audit_failed', retentionErr.message);
end

% REFERENCE-INTEGRITY SWEEP -- COMPUTED HERE, AND THE POSITION IS THE WHOLE
% POINT OF THIS BLOCK. It used to run ~65 lines BELOW writeCorpusReport, which
% meant the number existed, was asserted, and could never reach the artifact
% the digest reads. The corpus gate is quoted everywhere in this project as
% "0 quarantine + 0 orphans"; `quarantine_count` has been persisted since the
% report was written and `orphan_count` never has, so EVERY "0 quarantine +
% 0 orphans" ever quoted from a digest has quoted one measurement and one
% silence (V_eta_OPEN_WORK.md #101). The assert stays where it was, below --
% only the COMPUTATION moved up, so the gate's behaviour is unchanged and the
% figure now also lands in <corpus>-summary.json.
%
% STILL BEST-EFFORT, for the reason every instrument above it is: writeCorpusReport
% is the next statement, and an uncaught throw here would cost the corpus its
% entire census to protect a counter. The catch is deliberately NOT widened to
% the assert -- that stays outside, below, so a real orphan still fails the job.
%
% A FAILED SWEEP AND A CORPUS THAT NEVER SWEPT MUST NOT RENDER ALIKE. If the
% validator throws we persist the block anyway, carrying `audit_failed` and no
% counts; a corpus that never calls the validator (testCorpusPRED does not)
% persists no block at all. The digest tells those two apart and prints both as
% NOT MEASURED rather than as 0 -- an absent count is never summed as a zero.
refRep = [];
refErrMsg = '';
try
    refRep = did2.validate.references(result.migrated);
catch refReportErr
    refErrMsg = refReportErr.message;
    fprintf('reference report skipped: %s\n', refErrMsg);
end
% MOVED to +helpers/referenceIntegrityBlock.m 2026-08-13, unchanged, when
% testCorpusPRED became a second caller. One implementation of "how an orphan
% sweep is recorded", so the two call sites cannot drift into reporting the
% same fact two ways.
result.reference_integrity = ...
    did2.unittest.helpers.referenceIntegrityBlock(refRep, refErrMsg);

reasons = did2.unittest.helpers.topQuarantineReasons(result.quarantine);
reportPath = did2.unittest.helpers.writeCorpusReport(corpusName, result, reasons);

% THE REPORT IS NOW ON DISK, so a guarded post-pass failure can be made FATAL
% without costing the run its census. This is the second half of the guard and
% the half that matters: runBatchPass exists to protect the ARTIFACT, not to
% excuse the failure. Without this line a pass that threw would leave a green
% discovery run whose documents are silently in pass-1 form -- a pass that
% quietly does nothing, which is the defect this project keeps paying for.
% verifyThat is non-fatal in a function-based test, so the summary below still
% prints and the orphan gate below still runs.
% FIVE PASSES ARE DELIBERATELY NOT IN THIS LIST, and saying so is the point --
% an omission nobody wrote down is the thing this whole file exists to stop.
% THIS COUNT SAID "THREE" AND WAS WRONG WHILE SAYING SO, which is the failure in
% miniature: it named `response_parameters_fold`, `lawn_plate_subjects` and
% `openminds_citations` while `generic_file_fold` was already unlisted too, and
% `valid_interval_decompose` has since joined them. A hand-kept enumeration
% beside a hand-kept count drifts the moment a pass lands; the enumeration is
% the load-bearing half, so it is now complete:
%   response_parameters_fold, lawn_plate_subjects, openminds_citations,
%   generic_file_fold, valid_interval_decompose
% -- all new, all NEVER EXECUTED, and making a throw fatal for an unexecuted pass
% red-gates the corpus for everyone on a first run. That is the same judgement
% resolveSessionAnchors's author made when they left it unwired, and it is
% correct while it is STATED: printBatchPasses above prints
% `*** FAILED: <message>` for either of them, so a throw is visible in the log
% of every corpus run rather than silent. Move them into this list once a real
% corpus run has reported them green.
% `deferred_bath_resolution` and `dataset_entity_resolution` ARE in the list,
% and the reason is the opposite of the five above: both have run on every
% corpus for months as BARE calls, where a throw was already fatal. Guarding
% them 2026-08-11 saved the artifact; leaving them out of this list would have
% quietly DOWNGRADED two hard failures into log lines, which is a regression
% wearing the costume of a safety improvement.
for passField = {'deferred_bath_resolution', 'dataset_entity_resolution', ...
                 'epoch_mint', 'session_anchor_fold'}
    failMsg = did2.unittest.helpers.batchPassFailure(result, passField{1});
    verifyEmpty(testCase, failMsg, sprintf( ...
        ['%s: batch post-pass `%s` FAILED and its documents are in pass-1 ' ...
         'form: %s (the corpus report at %s was still written, and records ' ...
         'this under %s.pass_failed)'], ...
        corpusName, passField{1}, failMsg, reportPath, passField{1}));
end

% Per-term routing inventory (best-effort): makes the heuristic
% treatment / ontology_table_row routing auditable against real corpus
% terms so the authoritative per-term tables can be curated. Never let it
% break the discovery run -- the summary is the primary deliverable.
try
    did2.unittest.helpers.writeRoutingReport(corpusName, result.migrated);
catch routingErr
    fprintf('routing report skipped: %s\n', routingErr.message);
end

% Reference-integrity sweep: after the 1->N splits and class folds, every
% depends_on edge in the migrated batch must resolve to a document in that
% batch. Orphans = dangling references the migration would introduce (e.g. a
% split that didn't preserve a referenced id, or a ref to a
% deferred/quarantined doc). As of the V_zeta line every corpus migrates
% orphan-free, so this is now a HARD GATE (AssertNoOrphans, default true): a
% migrator change that reintroduces an orphan fails the corpus test instead of
% only logging it. Building the report is still best-effort (a failure to run
% the validator must not mask the migrated/quarantine signal), but the
% resulting orphan_count is asserted below, outside the catch.
%
% THE COMPUTATION MOVED ABOVE writeCorpusReport so the count reaches the
% artifact; `refRep` is the SAME struct this block always asserted on, and this
% site is unchanged apart from no longer computing it. Deliberately NOT
% recomputed here: two sweeps could disagree, and then the number in the report
% and the number in the gate would be different numbers wearing one name.
if ~isempty(refRep)
    fprintf('\n--- reference integrity (%s): %d orphan(s) of %d edges ---\n', ...
        corpusName, refRep.orphan_count, refRep.edges_examined);
    [orphNames, orphCounts] = ...
        did2.unittest.helpers.aggregateOrphans(refRep.orphans);
    for i = 1:numel(orphNames)
        fprintf('  %6d  %s\n', orphCounts(i), orphNames{i});
    end
    if options.AssertNoOrphans
        breakdown = '';
        for i = 1:numel(orphNames)
            breakdown = sprintf('%s\n  %d  %s', breakdown, orphCounts(i), orphNames{i});
        end
        verifyEqual(testCase, refRep.orphan_count, 0, sprintf( ...
            ['%s: migration introduced %d orphan depends_on edge(s) ', ...
             '(dangling references) of %d examined:%s'], ...
            corpusName, refRep.orphan_count, refRep.edges_examined, breakdown));
    end
end

fprintf('\n=== Corpus %s discovery summary (target %s) ===\n', ...
    corpusName, options.TargetVersion);
fprintf('total:            %d\n', result.summary.total);
fprintf('migrated_count:   %d\n', result.summary.migrated_count);
fprintf('quarantine_count: %d\n', result.summary.quarantine_count);
fprintf('report:           %s\n', reportPath);
printUnconvertedCensus(result);
printFragmentCensus(result);
printSilentLossCensus(result);
% GUARDED, and for the same reason did2.unittest.helpers.runBatchPass guards a
% post-pass: this printout is NEW CODE THAT NO GATE AVAILABLE TO ITS AUTHOR
% COULD EXECUTE (no MATLAB in the container; test-migrators-quick.yml does not
% run runCorpusDiscovery), and a throw here would turn a corpus job RED after it
% had already spent an hour and written a correct report. The guard protects the
% RUN, not the defect: the failure is PRINTED with its message, so a broken
% printout is a visible line in the log rather than an absence. The other
% print helpers around it are unguarded because they have run.
try
    printEpochStringRetention(result);
catch retentionPrintErr
    fprintf(['epoch-string retention: THE PRINTOUT FAILED (%s). The block IS ' ...
             'in the corpus report on disk under `epoch_string_retention`; ' ...
             'only this rendering broke.\n'], retentionPrintErr.message);
end
printFileListAudit(result);
printSourceCensus(result);
printBatchPasses(result);
fprintf('top quarantine reasons:\n');
for k = 1:min(numel(reasons), 15)
    fprintf('  %5d  [%s] %s\n', reasons(k).count, ...
        reasons(k).class_name, reasons(k).reason);
end
end


function printFragmentCensus(result)
%PRINTFRAGMENTCENSUS Phase 1 report-only: migrations that emitted ONLY
%   scaffolding (a time reference or a relation) and dropped the payload.
%   Neither silentLoss nor the unconverted counter can see this: nothing is
%   blank and output WAS produced.
if ~isfield(result.summary, 'fragment_count'); return; end
fprintf('fragments (REPORT ONLY): %d migration(s) emitted only scaffolding\n', ...
    result.summary.fragment_count);
if result.summary.fragment_count > 0
    tbl = result.summary.fragment_by_class;
    names = fieldnames(tbl);
    counts = zeros(1, numel(names));
    for k = 1:numel(names); counts(k) = tbl.(names{k}); end
    [counts, order] = sort(counts, 'descend');
    for k = 1:min(numel(names), 20)
        fprintf('    %6d  %s\n', counts(k), names{order(k)});
    end
end
end


function printSilentLossCensus(result)
%PRINTSILENTLOSSCENSUS Phase 1 report-only census (V_eta_ground_truth_plan.md).
%   Data that migrates away without tripping any gate: required depends_on
%   edges left empty, and required fields present but all-blank. NOT a
%   failure -- this is the count that ranks the migrator repair work.
if ~isfield(result, 'silent_loss'); return; end
sl = result.silent_loss;
if isfield(sl, 'audit_failed')
    fprintf('silent-loss audit: FAILED (%s)\n', sl.audit_failed);
    return;
end
fprintf('silent-loss (REPORT ONLY): %d empty required edge(s), %d vacuous required field(s)\n', ...
    sl.empty_dependency_count, sl.vacuous_field_count);
if sl.empty_dependency_count > 0
    fprintf('  top empty required edges:\n');
    for k = 1:min(numel(sl.empty_required_dependency), 20)
        e = sl.empty_required_dependency(k);
        fprintf('    %6d  %s.%s\n', e.count, e.class_name, e.edge_name);
    end
end
if sl.vacuous_field_count > 0
    fprintf('  top vacuous required fields:\n');
    for k = 1:min(numel(sl.vacuous_required_field), 20)
        f = sl.vacuous_required_field(k);
        fprintf('    %6d  %s / %s.%s\n', f.count, f.class_name, f.block, f.field_name);
    end
end
end


function printEpochStringRetention(result)
%PRINTEPOCHSTRINGRETENTION Did a did_v1 epoch-id string survive the migration?
%
%   REPORT ONLY. The first real-data reading of did2.validate.epochStringRetention,
%   which until this run was called from tests only.
%
%   DENOMINATORS FIRST AND UNCONDITIONALLY, in the order Rule 5 asks for: how
%   many documents went in, how many CLASSES were inspected, how many documents
%   carried an epoch string on the way in, and how many distinct (session,
%   string) pairs that came to -- BEFORE the retained/dropped split, and before
%   any per-class figure.
%
%   AND EVERY PER-CLASS LINE CARRIES ITS OWN DENOMINATOR. `0 dropped` and
%   `0 of 0 inspected` read identically and only one of them is good news:
%   `generic_file_fold` and `valid_interval_decompose` each processed ZERO
%   source documents in the last run and that was nearly read as a pass. The two
%   classes whose migrators drop the string by construction -- `vmspikefit` and
%   `pyraview`, both of which build new bodies and never copy the block -- are
%   named explicitly and print a line whether or not the corpus holds one, so
%   "absent from this corpus" is never rendered as "measured and clean".
if ~isfield(result, 'epoch_string_retention'); return; end
r = result.epoch_string_retention;
if isfield(r, 'audit_failed')
    fprintf('epoch-string retention: FAILED (%s)\n', r.audit_failed);
    return;
end
if ~isfield(r, 'ran') || ~r.ran
    fprintf(['epoch-string retention: DID NOT RUN (the instrument returned ' ...
             'before reading anything -- not the same as a clean zero)\n']);
    return;
end
fprintf(['\n--- epoch-string retention (REPORT ONLY): %d v1 document(s) ' ...
         'inspected (%d unreadable), %d migrated document(s) inspected ' ...
         '(%d unreadable) ---\n'], ...
    r.v1_documents_inspected, r.v1_documents_unreadable, ...
    r.migrated_documents_inspected, r.migrated_documents_unreadable);
fprintf(['  v1 side: %d class(es) inspected, %d of them carried an epoch ' ...
         'string; %d document(s) carried one, %d string(s) read, %d ' ...
         'distinct (session,string) pair(s)  <- THE DENOMINATOR\n'], ...
    r.v1_classes_inspected, r.v1_classes_with_string, ...
    r.v1_documents_with_string, r.v1_strings_read, r.v1_pairs);
for k = 1:numel(r.v1_by_source)
    s = r.v1_by_source(k);
    fprintf('      %-38s %6d doc(s)  %6d distinct string(s)\n', ...
        s.source, s.documents, s.distinct_strings);
end
% NOT in the denominator above, and said so rather than left out: a source this
% reader declines cannot inflate the retention rate, and must not be forgotten.
fprintf(['      declined (syncrule_mapping endpoints, out of scope by ' ...
         'design): %d hit(s), %d distinct -- EXCLUDED from the denominator\n'], ...
    r.v1_declined, r.v1_declined_distinct);
if r.v1_pairs == 0
    % Rule 5 in the log rather than left to the reader. Every number below is
    % 0 out of 0, and 0 of 0 is "did not look", not "nothing was dropped".
    fprintf(['  0 of 0 pair(s) inspected -- NO v1 DOCUMENT IN THIS CORPUS ' ...
             'CARRIED AN EPOCH STRING. Every figure below is VACUOUS, not ' ...
             'clean.\n']);
end
fprintf(['  retained: %d of %d pair(s)  (%d still spelled out on a migrated ' ...
         'document, %d as a minted `epoch` document; %d `epoch` document(s) ' ...
         'seen in the batch)\n'], ...
    r.retained_total, r.v1_pairs, r.retained_as_string, ...
    r.retained_as_epoch_document, r.epoch_documents_seen);
fprintf('  DROPPED:  %d of %d pair(s)\n', r.pairs_dropped, r.v1_pairs);
% The per-class table. Its `dropped` column counts a dropped pair against EVERY
% class that carried it, so it does not sum to `pairs_dropped` above -- stated
% here rather than left for someone to add up and mistrust.
fprintf(['  by v1 class (dropped / pairs carried; a pair carried by two ' ...
         'classes is counted against both):\n']);
if isempty(r.v1_by_class)
    fprintf('      (no class carried an epoch string -- see the 0-of-0 line above)\n');
end
for k = 1:numel(r.v1_by_class)
    c = r.v1_by_class(k);
    fprintf('      %-42s %6d dropped of %6d pair(s) carried, %6d doc(s)\n', ...
        c.class_name, c.pairs_dropped, c.distinct_pairs, c.documents_with_string);
end
% CROSS-CHECK, not decoration. `dropped_by_v1_class` (a struct keyed by mangled
% class name) and the `pairs_dropped` column above are two derivations of one
% fact, computed in two loops. They are locked together here for the same reason
% v1_to_v2 locks the silent-loss census against the quarantine rollup: when two
% paired implementations disagree about a class, that disagreement IS the
% signal, and nothing else in the pipeline would ever surface it.
nNamed = numel(fieldnames(r.dropped_by_v1_class));
nWithDrops = 0;
for k = 1:numel(r.v1_by_class)
    if r.v1_by_class(k).pairs_dropped > 0; nWithDrops = nWithDrops + 1; end
end
if nNamed ~= nWithDrops
    fprintf(['      *** the two per-class derivations DISAGREE: ' ...
             'dropped_by_v1_class names %d class(es), the table above shows ' ...
             '%d with a non-zero drop. One of them has drifted.\n'], ...
        nNamed, nWithDrops);
else
    fprintf('      (%d class(es) with a non-zero drop; both derivations agree)\n', ...
        nNamed);
end
% THE TWO CLASSES THE 19-CLASS SURVEY SAYS DROP THE STRING BY CONSTRUCTION.
% Printed whether or not this corpus holds one, because absence and cleanliness
% are the reading this whole function exists to keep apart. Verified against the
% migrators at 32166b8: +migrators_j/vmspikefit.m and +migrators_j/pyraview.m
% both build NEW bodies (a score_observation / a voltage_observation plus
% bodies, an anchor, a software or filter document) and never return preBody, so
% the `epochid` block has no successor in their output.
for want = {'vmspikefit', 'pyraview'}
    row = [];
    for k = 1:numel(r.v1_by_class)
        if strcmp(r.v1_by_class(k).class_name, want{1})
            row = r.v1_by_class(k); break;
        end
    end
    if isempty(row)
        fprintf(['      %-42s 0 of 0 INSPECTED -- this corpus holds no such ' ...
                 'document carrying an epoch string. NOT a measured zero.\n'], ...
            want{1});
    else
        fprintf(['      %-42s MEASURED: %d dropped of %d pair(s) carried\n'], ...
            want{1}, row.pairs_dropped, row.distinct_pairs);
    end
end
for k = 1:min(numel(r.dropped_detail), 10)
    d = r.dropped_detail(k);
    fprintf('        e.g. session %s / epoch "%s" (carried by: %s)\n', ...
        d.session_id, d.epoch_string, strjoin(d.v1_classes, ', '));
end
end


function printFileListAudit(result)
%PRINTFILELISTAUDIT #64, report-only: files a class DECLARES that the document
%   does not carry (the direction that loses data), and files carried that the
%   class does not declare. Neither trips any existing gate.
if ~isfield(result, 'file_list_audit'); return; end
fl = result.file_list_audit;
if isfield(fl, 'audit_failed')
    fprintf('file-list audit: FAILED (%s)\n', fl.audit_failed);
    return;
end
fprintf(['file-list (REPORT ONLY): %d document(s) inspected, %d carrying files; ' ...
         '%d declared-but-absent, %d present-but-undeclared\n'], ...
    fl.total_docs, fl.docs_with_files, ...
    fl.declared_absent_count, fl.present_undeclared_count);
if fl.declared_absent_count > 0
    fprintf('  declared by the class, ABSENT from the document:\n');
    for k = 1:min(numel(fl.declared_but_absent), 20)
        e = fl.declared_but_absent(k);
        fprintf('    %6d  %s / %s\n', e.count, e.class_name, e.file_name);
    end
end
if fl.present_undeclared_count > 0
    fprintf('  carried by the document, DECLARED NOWHERE:\n');
    for k = 1:min(numel(fl.present_but_undeclared), 20)
        e = fl.present_but_undeclared(k);
        fprintf('    %6d  %s / %s\n', e.count, e.class_name, e.file_name);
    end
end
end


function printUnconvertedCensus(result)
%PRINTUNCONVERTEDCENSUS Phase 1 report-only: documents that came out of the
%   migration UNCONVERTED -- the migrator handed its input straight back.
%
%   Not a failure, and not always wrong: a class deferred to the NDI second
%   pass is SUPPOSED to appear here. The signal is a class that is meant to
%   convert showing a high count, which means its migrator is looking for
%   fields the real documents do not have and silently falling through. Those
%   documents are counted in migrated_count today, because nothing errored.
if ~isfield(result.summary, 'unconverted_count'); return; end
fprintf('unconverted (REPORT ONLY): %d document(s) returned unchanged by their migrator\n', ...
    result.summary.unconverted_count);
if result.summary.unconverted_count == 0; return; end
tbl = result.summary.unconverted_by_class;
names = fieldnames(tbl);
counts = zeros(1, numel(names));
for k = 1:numel(names); counts(k) = tbl.(names{k}); end
[counts, order] = sort(counts, 'descend');
fprintf('  by class (deferred-by-design classes are expected here):\n');
for k = 1:min(numel(names), 25)
    fprintf('    %6d  %s\n', counts(k), names{order(k)});
end
end


function printBatchPasses(result)
%PRINTBATCHPASSES Did the batch post-passes run, and what did each measure?
%
%   DENOMINATOR FIRST, and the denominator here is the LIST OF PASSES ITSELF.
%   Each expected pass prints a line whether or not its report is present, so
%   "the pass ran and changed nothing" and "the pass was never wired into this
%   call site" are different lines rather than the same silence. That
%   distinction is the entire subject of this change: `resolveSessionAnchors`
%   sat unwired for a day and no corpus log said so, because a pass that is not
%   called prints nothing anywhere.
%
%   THIS TABLE IS HAND-KEPT AND CANNOT DISAGREE WITH THE COMPOSED CHAIN.
%   Deriving it inside MATLAB would mean reading this file's own text at run
%   time -- an instrument that measures its own source is worse than the
%   disagreement it prevents. So the disagreement is made UNCOMMITTABLE
%   instead, in BOTH directions, from tools/test_batch_pass_wiring.py (fast
%   gate, under a second, no MATLAB needed):
%
%     * every did2.convert pass routed through runBatchPass in THIS FILE must
%       appear here      -> test_every_pass_is_printed_by_the_discovery_run
%     * every row here must BE a runBatchPass call in THIS FILE, same report
%       field and same function name, with no extra rows
%                        -> test_the_printed_table_is_exactly_the_composed_chain
%     * the printed headline must be `size(expected, 1)`, never a literal
%                        -> test_the_printed_pass_count_is_derived_from_the_table
%
%   The count below is derived from the table, the table is pinned to the
%   chain, and the pair cannot drift without a red gate. It printed
%   "7 expected" while this file composed 9 for as long as only the first of
%   those three checks existed.
expected = { ...
    'deferred_bath_resolution',  'did2.convert.resolveDeferredBaths'; ...
    'openminds_citations',      'did2.convert.resolveOpenmindsCitations'; ...
    'dataset_entity_resolution', 'did2.convert.resolveDatasetEntities'; ...
    'epoch_mint',               'did2.convert.epochMint'; ...
    'session_anchor_fold',      'did2.convert.resolveSessionAnchors'; ...
    'response_parameters_fold', 'did2.convert.resolveResponseParameters'; ...
    'lawn_plate_subjects',      'did2.convert.resolveLawnPlateSubjects'; ...
    'generic_file_fold',        'did2.convert.foldGenericFiles'; ...
    'valid_interval_decompose', 'did2.convert.resolveValidIntervals'};
fprintf('\n--- batch post-passes (%d expected) ---\n', size(expected, 1));
for k = 1:size(expected, 1)
    field = expected{k, 1};
    name  = expected{k, 2};
    if ~isfield(result, field)
        fprintf('  %-34s NOT WIRED INTO THIS RUN (no `%s` on the result)\n', ...
            name, field);
        continue;
    end
    rep = result.(field);
    if isfield(rep, 'pass_failed') && ~isempty(rep.pass_failed)
        fprintf('  %-34s *** FAILED: %s\n', name, rep.pass_failed);
        continue;
    end
    if isfield(rep, 'ran') && ~rep.ran
        fprintf(['  %-34s did not run (non-V_eta target, or an empty ' ...
                 'batch)\n'], name);
        continue;
    end
    switch field
        case 'deferred_bath_resolution'
            % THE DENOMINATOR IS `quarantine_inspected`, and the pair to read
            % is it beside `deferred_baths_seen`. 0 baths seen out of a large
            % quarantine means this corpus deferred none -- a fact about the
            % input. 0 seen out of 0 means there was no quarantine at all.
            % Those printed identically until 2026-08-11, along with "every
            % bath resolved" and "every bath failed", because the per-bath
            % handler was a bare `catch` with a two-line comment for a body.
            fprintf(['  %-34s %d quarantine entr(ies) inspected, %d ' ...
                     'deferred bath(s) seen\n'], name, ...
                numGet(rep, 'quarantine_inspected'), ...
                numGet(rep, 'deferred_baths_seen'));
            fprintf(['      index: %d migrated doc(s) read -> %d element(s), ' ...
                     '%d lineage edge(s); %d unreadable\n'], ...
                numGet(rep, 'migrated_indexed'), ...
                numGet(rep, 'elements_indexed'), ...
                numGet(rep, 'lineage_edges_indexed'), ...
                numGet(rep, 'index_documents_unreadable'));
            fprintf(['      resolved %d bath(s) -> %d assembled body(ies) -> ' ...
                     '%d document(s) appended, %d quarantined on ' ...
                     're-validation; quarantine %d -> %d\n'], ...
                numGet(rep, 'baths_resolved'), ...
                numGet(rep, 'bodies_assembled'), ...
                numGet(rep, 'documents_appended'), ...
                numGet(rep, 'assembled_bodies_quarantined'), ...
                numGet(rep, 'quarantine_before'), ...
                numGet(rep, 'quarantine_after'));
            % REFUSALS BY CAUSE, NEVER SUMMED INTO ONE. Only
            % `element-not-in-batch` is the designed best-effort outcome; the
            % other four are defects, and the last one is a defect this pass
            % did not anticipate.
            fprintf(['      refused %d: %d element-not-in-batch (the ' ...
                     'designed case), %d unreadable-body, %d ' ...
                     'no-stimulus_element_id, %d assembly-failed, %d ' ...
                     'UNEXPECTED\n'], ...
                numGet(rep, 'refused_total'), ...
                numGet(rep, 'refused_element_not_in_batch'), ...
                numGet(rep, 'refused_body_unreadable'), ...
                numGet(rep, 'refused_no_stimulus_element_id'), ...
                numGet(rep, 'refused_bath_assembly_failed'), ...
                numGet(rep, 'refused_unexpected_error'));
            if isfield(rep, 'unexpected_error_reasons') ...
                    && ~isempty(rep.unexpected_error_reasons)
                for w = 1:numel(rep.unexpected_error_reasons)
                    fprintf('        UNEXPECTED: %s\n', ...
                        rep.unexpected_error_reasons{w});
                end
            end
            if numGet(rep, 'deferred_baths_seen') == 0
                fprintf(['      (0 deferred baths of %d quarantine entr(ies) ' ...
                         '-- the lines above are VACUOUS, not clean)\n'], ...
                    numGet(rep, 'quarantine_inspected'));
            end
        case 'dataset_entity_resolution'
            fprintf(['  %-34s inspected %d doc(s), %d unreadable; %d ' ...
                     '`dataset` entit(ies) over %d distinct id(s)\n'], name, ...
                numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'), ...
                numGet(rep, 'dataset_entities_seen'), ...
                numGet(rep, 'distinct_dataset_ids'));
            % THE TWO DELETION REASONS, ON SEPARATE LINES AND NEVER ADDED UP.
            % A dedup keeps the content under the same base.id; a discarded
            % membership edge is a `session -part_of-> dataset` statement that
            % no longer exists anywhere. One total would let the second hide
            % inside the first.
            fprintf(['      dedup: %d poorer duplicate(s) dropped (%d of them ' ...
                     'a TIE, kept by file order alone)\n'], ...
                numGet(rep, 'duplicates_dropped_poorer_richness'), ...
                numGet(rep, 'duplicate_ties_incumbent_kept'));
            fprintf(['      membership edges: %d seen -> %d kept, %d dropped ' ...
                     '(child absent from batch), %d dropped (no child edge ' ...
                     'at all)\n'], ...
                numGet(rep, 'membership_relations_seen'), ...
                numGet(rep, 'membership_kept_child_present'), ...
                numGet(rep, 'membership_dropped_child_absent'), ...
                numGet(rep, 'membership_dropped_no_child_edge'));
            % THE ARITHMETIC CHECK. `documents_removed` is read off the keep
            % mask, not off the reasons, so a removal with no stated cause
            % shows up here instead of being reconciled away.
            fprintf(['      migrated %d -> %d; %d document(s) removed, %d of ' ...
                     'them UNATTRIBUTED (must be 0)\n'], ...
                numGet(rep, 'migrated_before'), ...
                numGet(rep, 'migrated_after'), ...
                numGet(rep, 'documents_removed'), ...
                numGet(rep, 'documents_removed_unattributed'));
            if numGet(rep, 'documents_unreadable') > 0
                % The prune decides on ABSENCE from an index built by reading
                % base.id, so an unreadable document is a hole in that index.
                fprintf(['      (%d unreadable document(s): ' ...
                         '`child absent from batch` is an UPPER BOUND this ' ...
                         'run, not a measurement)\n'], ...
                    numGet(rep, 'documents_unreadable'));
            end
            if numGet(rep, 'dataset_entities_seen') == 0 ...
                    && numGet(rep, 'membership_relations_seen') == 0
                fprintf(['      (0 dataset entities and 0 membership edges ' ...
                         'of %d document(s) -- nothing for this pass to do ' ...
                         'here, which is not the same as nothing to do)\n'], ...
                    numGet(rep, 'documents_inspected'));
            end
        case 'epoch_mint'
            fprintf(['  %-34s inspected %d doc(s), %d unreadable; %d session ' ...
                     'doc(s)\n'], name, numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'), ...
                numGet(rep, 'session_documents_seen'));
            fprintf(['      epochs: %d minted, %d already present; %d distinct ' ...
                     '(session,id) pair(s) vs %d distinct id string(s) ' ...
                     '[fusion avoided: %d]\n'], ...
                numGet(rep, 'epochs_minted'), ...
                numGet(rep, 'epochs_found_existing'), ...
                numGet(rep, 'distinct_session_epoch_pairs'), ...
                numGet(rep, 'distinct_epoch_id_strings'), ...
                numGet(rep, 'pairs_minus_strings'));
            fprintf(['      refused: %d synthetic, %d no-session-id, %d ' ...
                     'no-session-doc, %d ambiguous-session; %d quarantined\n'], ...
                numGet(rep, 'skipped_synthetic'), ...
                numGet(rep, 'skipped_no_session_id'), ...
                numGet(rep, 'skipped_no_session_document'), ...
                numGet(rep, 'skipped_ambiguous_session'), ...
                numGet(rep, 'mint_quarantined'));
            fprintf('      method_parameters: %d seen, %d edge(s) filled, %d unresolved\n', ...
                numGet(rep, 'method_parameters_seen'), ...
                numGet(rep, 'method_parameters_edges_filled'), ...
                numGet(rep, 'method_parameters_unresolved'));
        case 'session_anchor_fold'
            fprintf(['  %-34s inspected %d doc(s), %d unreadable; %d session ' ...
                     'doc(s)\n'], name, numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'), ...
                numGet(rep, 'session_documents_seen'));
            fprintf(['      anchors: %d seen (%d relative, %d bounded) -> %d ' ...
                     'folded to relative_reference; %d quarantined\n'], ...
                numGet(rep, 'anchors_seen'), numGet(rep, 'anchors_relative'), ...
                numGet(rep, 'anchors_bounded'), numGet(rep, 'anchors_folded'), ...
                numGet(rep, 'fold_quarantined'));
            % THE DELETION GATE, printed every run. The six retiring reference
            % classes may leave V_eta only when refused_total is 0 AND no
            % session_*_reference survives in by_class. Printing the refusal
            % breakdown unconditionally means the answer is in the log of every
            % corpus run rather than in an artifact somebody has to download.
            fprintf(['      refused %d: %d no-session-id, %d no-session-doc, ' ...
                     '%d ambiguous-session, %d ambiguous-relation, %d ' ...
                     'unknown-relation, %d negative-extent\n'], ...
                numGet(rep, 'refused_total'), ...
                numGet(rep, 'refused_no_session_id'), ...
                numGet(rep, 'refused_no_session_document'), ...
                numGet(rep, 'refused_ambiguous_session'), ...
                numGet(rep, 'refused_ambiguous_relation'), ...
                numGet(rep, 'refused_unknown_relation'), ...
                numGet(rep, 'refused_negative_extent'));
            % THE BOUNDED EXTENT, ON ITS OWN LINE AND WITH ITS OWN DENOMINATOR
            % FIRST. `anchors_folded` cannot distinguish "folded carrying its
            % window" from "folded having lost it" -- 20,411 documents took the
            % second path while every counter above read clean. The three
            % extent refusals are part of `refused_total` printed above; these
            % are what make that total legible.
            fprintf(['      bounded extents: %d examined (%d had a start, ' ...
                     '%d had an end) -> %d window(s), %d start-only, %d ' ...
                     'none stated; %d blank cell(s)\n'], ...
                numGet(rep, 'bounded_extents_examined'), ...
                numGet(rep, 'bounded_with_start_field'), ...
                numGet(rep, 'bounded_with_end_field'), ...
                numGet(rep, 'bounded_window_carried'), ...
                numGet(rep, 'bounded_start_only_carried'), ...
                numGet(rep, 'bounded_no_window_stated'), ...
                numGet(rep, 'bounded_blank_extent_cells'));
            fprintf(['      extent refusals: %d unreadable-unit, %d ' ...
                     'malformed-cell, %d end-without-start\n'], ...
                numGet(rep, 'refused_unreadable_extent_unit'), ...
                numGet(rep, 'refused_malformed_extent'), ...
                numGet(rep, 'refused_extent_without_start'));
            if numGet(rep, 'bounded_extents_examined') == 0
                % Rule 5, said in the log rather than left to the reader: the
                % two lines above are all zeros in this case, and all zeros
                % here means the instrument saw nothing, not that nothing
                % was dropped.
                fprintf(['      (0 bounded extents examined -- the two lines ' ...
                         'above are VACUOUS, not clean)\n']);
            end
            if numGet(rep, 'refused_total') == 0 && numGet(rep, 'anchors_seen') > 0
                fprintf(['      every anchor folded -- half of the deletion ' ...
                         'gate for the 6 retiring reference classes is met ' ...
                         'for this corpus (the other half is 0 surviving ' ...
                         'session_*_reference in by_class)\n']);
            end
        case 'response_parameters_fold'
            fprintf('  %-34s inspected %d doc(s), %d unreadable\n', name, ...
                numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'));
            % THE TWO NUMBERS THAT MUST BE READ TOGETHER. `leaves_seen: 0` on
            % its own is "nothing to inline"; `leaves_seen: 0` beside a non-zero
            % `suppressed_responses_seen` is "pass 1's epoch gate is still shut
            % and #60 is what opens it". They used to be one silence.
            fprintf(['      leaves: %d seen (%d with the edge, %d without); ' ...
                     '%d v1 response(s) STILL SUPPRESSED by the epoch gate\n'], ...
                numGet(rep, 'leaves_seen'), numGet(rep, 'leaves_with_edge'), ...
                numGet(rep, 'leaves_without_edge'), ...
                numGet(rep, 'suppressed_responses_seen'));
            fprintf(['      inlined %d leaf/leaves (%d field value(s) copied); ' ...
                     'harmonic %d checked, %d uncheckable; %d quarantined\n'], ...
                numGet(rep, 'inlined'), numGet(rep, 'fields_copied'), ...
                numGet(rep, 'harmonic_checked'), ...
                numGet(rep, 'harmonic_uncheckable'), ...
                numGet(rep, 'fold_quarantined'));
            fprintf(['      refused %d: %d not-in-batch, %d ambiguous, %d ' ...
                     'wrong-class, %d no-fields, %d inline-present, %d ' ...
                     'harmonic-mismatch\n'], ...
                numGet(rep, 'refused_total'), ...
                numGet(rep, 'refused_not_in_batch'), ...
                numGet(rep, 'refused_ambiguous'), ...
                numGet(rep, 'refused_wrong_class'), ...
                numGet(rep, 'refused_no_fields'), ...
                numGet(rep, 'refused_inline_present'), ...
                numGet(rep, 'refused_harmonic_mismatch'));
            % THE VERIFY-BEFORE-DELETE EVIDENCE, printed every run for the same
            % reason the anchor fold prints its refusals: the plan requires this
            % measurement before the parameters documents may go, and it
            % belongs in the log rather than in an artifact somebody must still
            % have. It is EVIDENCE, never authorisation -- the corpora are a
            % sample.
            fprintf(['      parameters documents: %d seen, %d still ' ...
                     'referenced, %d unreferenced; %d deleted (this pass ' ...
                     'never deletes)\n'], ...
                numGet(rep, 'parameters_documents_seen'), ...
                numGet(rep, 'parameters_documents_referenced_after'), ...
                numGet(rep, 'parameters_documents_unreferenced_after'), ...
                numGet(rep, 'parameters_documents_deleted'));
        case 'lawn_plate_subjects'
            fprintf(['  %-34s inspected %d doc(s), %d unreadable; %d ' ...
                     'ontology_table_row(s)\n'], name, ...
                numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'), ...
                numGet(rep, 'ontology_table_rows_seen'));
            % THE FOUR STATES THE TEAM ASKED TO KEEP APART, ON ONE LINE EACH.
            % "no E. coli tables in this corpus" is rows_seen == 0 with
            % sessions == 0. "the token rule is wrong" is rows_seen small beside
            % a large unclassified count. They are not summable and are not
            % summed.
            fprintf(['      tables: %d plate, %d image, %d lawn row(s) in %d ' ...
                     'session(s); %d unclassified row(s) IN THOSE SESSIONS ' ...
                     '(a large number here means the column-token rule is ' ...
                     'wrong, not that there is nothing to do)\n'], ...
                numGet(rep, 'plate_rows_seen'), numGet(rep, 'image_rows_seen'), ...
                numGet(rep, 'lawn_rows_seen'), ...
                numGet(rep, 'sessions_with_lawn_plate_tables'), ...
                numGet(rep, 'unclassified_rows_in_those_sessions'));
            fprintf('      columns resolved: %d by key, %d by term name\n', ...
                numGet(rep, 'columns_resolved_by_key'), ...
                numGet(rep, 'columns_resolved_by_term_name'));
            fprintf(['      plate tier: %d row(s) with measurements, %d with ' ...
                     'values but none emittable, %d with no values at all -> ' ...
                     '%d subject(s), %d observation(s)\n'], ...
                numGet(rep, 'plate_rows_with_measurements'), ...
                numGet(rep, 'plate_rows_with_values_but_none_emittable'), ...
                numGet(rep, 'plate_rows_with_no_values_at_all'), ...
                numGet(rep, 'plate_subjects_minted'), ...
                numGet(rep, 'plate_observations_emitted'));
            fprintf(['      lawn tier:  %d row(s) with measurements, %d with ' ...
                     'values but none emittable, %d with no values at all -> ' ...
                     '%d subject(s), %d observation(s)\n'], ...
                numGet(rep, 'lawn_rows_with_measurements'), ...
                numGet(rep, 'lawn_rows_with_values_but_none_emittable'), ...
                numGet(rep, 'lawn_rows_with_no_values_at_all'), ...
                numGet(rep, 'lawn_subjects_minted'), ...
                numGet(rep, 'lawn_observations_emitted'));
            fprintf(['      chain: %d attempted, %d resolved -> %d ' ...
                     'member_of edge(s); withheld %d (plate tier not minted), ' ...
                     '%d (lawn tier not minted)\n'], ...
                numGet(rep, 'chains_attempted'), numGet(rep, 'chains_resolved'), ...
                numGet(rep, 'member_of_relations_emitted'), ...
                numGet(rep, 'withheld_plate_tier_not_minted'), ...
                numGet(rep, 'withheld_lawn_tier_not_minted'));
            fprintf(['      refused %d: %d no-session-id, %d no-identity-key, ' ...
                     '%d no-image-row, %d image-ambiguous, %d image-no-plate, ' ...
                     '%d no-plate-row, %d plate-ambiguous, %d no-exp-id\n'], ...
                numGet(rep, 'refused_total'), ...
                numGet(rep, 'plate_rows_refused_no_session_id') ...
                    + numGet(rep, 'lawn_rows_refused_no_session_id'), ...
                numGet(rep, 'plate_rows_refused_no_plate_key') ...
                    + numGet(rep, 'lawn_rows_refused_no_identity_keys'), ...
                numGet(rep, 'refused_no_image_row'), ...
                numGet(rep, 'refused_image_row_ambiguous'), ...
                numGet(rep, 'refused_image_row_has_no_plate_key'), ...
                numGet(rep, 'refused_no_plate_row'), ...
                numGet(rep, 'refused_plate_row_ambiguous'), ...
                numGet(rep, 'plate_rows_refused_no_exp_id') ...
                    + numGet(rep, 'refused_lawn_no_exp_id'));
            % THE C. ELEGANS RELABEL, printed separately because it is a
            % DIFFERENT population from the E. coli tiers above and summing the
            % two would hide which one moved.
            fprintf(['      C. elegans patch subjects: %d seen, %d relabelled ' ...
                     'to the triple, %d already triple, %d left as a pair (no ' ...
                     'exp id), %d ambiguous exp id, %d unparseable handle; ' ...
                     '%d quarantined\n'], ...
                numGet(rep, 'celegans_patch_subjects_seen'), ...
                numGet(rep, 'celegans_patch_subjects_relabelled'), ...
                numGet(rep, 'celegans_patch_subjects_already_triple'), ...
                numGet(rep, 'celegans_patch_subjects_refused_no_exp_id'), ...
                numGet(rep, 'celegans_patch_subjects_refused_ambiguous_exp_id'), ...
                numGet(rep, 'celegans_patch_subjects_unparseable_handle'), ...
                numGet(rep, 'celegans_patch_relabel_quarantined'));
            % THE DIRECTIVE'S OWN PREMISE, MEASURED -- AND SPLIT, BECAUSE THE
            % TOTAL ALONE CANNOT ANSWER THE QUESTION THE TEAM ASKED. They asked
            % "is it not within-session unique? That's what matters", and the
            % batch total cannot tell them: a batch spans sessions.
            %
            % The distinction is load-bearing, not cosmetic.
            % `ndi.subject.does_subjectstring_match_session_document` resolves a
            % subject BY this handle and raises a hard error on more than one
            % match (`+ndi/subject.m:169-170`), reached from `+ndi/element.m:59`.
            % Its search is session-scoped (`session.m:328-329`) while
            % `ndi.dataset.database_search` is not, and both Haley sessions
            % share one `ndi.dataset.dir`. So a WITHIN-session collision breaks
            % a live NDI resolver; a cross-session-only one breaks it only for a
            % caller resolving through the dataset.
            %
            % Evidence for the team, never authorisation for the pass to choose
            % another scheme.
            fprintf(['      identifiers: %d handle(s) formed, %d distinct; ' ...
                     '%d collision(s) = %d WITHIN-session (these refute the ' ...
                     'directive) + %d across-sessions-only (these do not) + ' ...
                     '%d unclassifiable; %d fell back to the document id; ' ...
                     '%d document(s) appended, %d source row(s) left in ' ...
                     'place (NOT consumed)\n'], ...
                numGet(rep, 'local_identifier_handles_formed'), ...
                numGet(rep, 'local_identifier_handles_distinct'), ...
                numGet(rep, 'local_identifier_collisions_within_batch'), ...
                numGet(rep, 'local_identifier_collisions_within_session'), ...
                numGet(rep, 'local_identifier_collisions_across_sessions_only'), ...
                numGet(rep, 'local_identifier_collisions_unclassifiable_no_session_id'), ...
                numGet(rep, 'local_identifier_fallback_to_document_id'), ...
                numGet(rep, 'documents_appended'), ...
                numGet(rep, 'source_rows_left_in_place'));
        case 'openminds_citations'
            fprintf(['  %-34s inspected %d doc(s), %d unreadable; %d ' ...
                     'openminds doc(s) in %d component(s)\n'], name, ...
                numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'), ...
                numGet(rep, 'openminds_documents_seen'), ...
                numGet(rep, 'openminds_components_seen'));
            % THE ALL-OR-NONE DECISION, ONE LINE, WITH ITS THREE OUTCOMES KEPT
            % APART. planned == consumed + withheld + reverted; a non-zero
            % `withheld` is the ORPHAN GUARD refusing, and it is a finding, not
            % a passthrough statistic. `components_without_dataset_version` is
            % the strain family and anything else with no citation root -- it
            % is left untouched by design, not skipped by accident.
            fprintf(['      roots: %d DatasetVersion(s), %d superseded by a ' ...
                     'newer one; %d component(s) with no DatasetVersion ' ...
                     '(left untouched)\n'], ...
                numGet(rep, 'dataset_versions_seen'), ...
                numGet(rep, 'dataset_versions_superseded_by_newer'), ...
                numGet(rep, 'components_without_dataset_version'));
            fprintf(['      decision: %d planned -> %d consumed, %d WITHHELD ' ...
                     '(orphan guard), %d reverted on validation; %d source ' ...
                     'doc(s) consumed, %d body(ies) quarantined\n'], ...
                numGet(rep, 'components_planned'), ...
                numGet(rep, 'components_consumed'), ...
                numGet(rep, 'components_withheld'), ...
                numGet(rep, 'components_reverted_on_validation'), ...
                numGet(rep, 'documents_consumed'), ...
                numGet(rep, 'bodies_quarantined'));
            if isfield(rep, 'withheld_reasons') && ~isempty(rep.withheld_reasons)
                for w = 1:numel(rep.withheld_reasons)
                    fprintf('        WITHHELD: %s\n', rep.withheld_reasons{w});
                end
            end
            fprintf(['      emitted: %d dataset, %d person (%d id-preserved), ' ...
                     '%d organization (%d id-preserved), %d funding, ' ...
                     '%d publication, %d web_resource, %d relation(s); ' ...
                     '%d document(s) appended\n'], ...
                numGet(rep, 'datasets_emitted'), ...
                numGet(rep, 'persons_emitted'), ...
                numGet(rep, 'persons_id_preserved'), ...
                numGet(rep, 'organizations_emitted'), ...
                numGet(rep, 'organizations_id_preserved'), ...
                numGet(rep, 'funding_emitted'), ...
                numGet(rep, 'publications_emitted'), ...
                numGet(rep, 'web_resources_emitted'), ...
                numGet(rep, 'relations_emitted'), ...
                numGet(rep, 'documents_appended'));
            % THE BIMODAL FIELD, SPLIT. A single total would hide which shape
            % `fullDocumentation` arrived in, and the two are read differently.
            fprintf(['      fullDocumentation: %d from a WebResource IRI, ' ...
                     '%d from a DOI identifier; %d publication(s) skipped ' ...
                     'for having no DOI; %d empty funding slot(s) skipped\n'], ...
                numGet(rep, 'web_resources_from_iri'), ...
                numGet(rep, 'web_resources_from_doi'), ...
                numGet(rep, 'publications_without_doi_skipped'), ...
                numGet(rep, 'funding_slots_empty_skipped'));
            % CONSUMED WITH NOWHERE TO PUT IT. Real loss, with a number on it
            % rather than a shrug. Author ORDER survives as `sequence`; the
            % role does not, because `person` has no role field.
            fprintf(['      consumed without a home: %d Contribution role ' ...
                     'doc(s), %d SemanticDataType, %d technique; %d second-' ...
                     'or-later affiliation(s) dropped. experimental_approach: ' ...
                     '%d term(s) emitted\n'], ...
                numGet(rep, 'contribution_documents_consumed_without_a_home'), ...
                numGet(rep, 'data_type_documents_consumed_without_a_home'), ...
                numGet(rep, 'technique_documents_consumed_without_a_home'), ...
                numGet(rep, 'affiliations_beyond_first_dropped'), ...
                numGet(rep, 'experimental_approach_terms_emitted'));
        case 'valid_interval_decompose'
            fprintf(['  %-34s inspected %d doc(s), %d unreadable; %d ' ...
                     'valid_interval source(s), %d epoch document(s) to ' ...
                     'anchor to\n'], name, ...
                numGet(rep, 'documents_inspected'), ...
                numGet(rep, 'documents_unreadable'), ...
                numGet(rep, 'sources_seen'), ...
                numGet(rep, 'epoch_documents_seen'));
            % `sources_seen` AT 0 IS THE EXPECTED READING and is not evidence
            % about the decompose: markgarbage is opt-in and no tested corpus
            % has ever held one of these. It IS evidence about hazard 1 --
            % 0 sources must produce 0 statements, because absence means "all
            % of this is good data" and must keep meaning that.
            fprintf(['      %d interval(s) seen -> %d decomposed; %d ' ...
                     'statement(s) + %d reference(s) emitted; %d split-anchor ' ...
                     'interval(s)\n'], ...
                numGet(rep, 'intervals_seen'), ...
                numGet(rep, 'intervals_decomposed'), ...
                numGet(rep, 'statements_emitted'), ...
                numGet(rep, 'references_emitted'), ...
                numGet(rep, 'split_anchor_intervals'));
            % THE DELETION GATE, printed as a gate and not as a statistic. The
            % `valid_interval` tombstone may be retired only when every source
            % is fully decomposed and refused_total is 0 -- verify before
            % delete, the epochfiles_ingested rule.
            fprintf(['      deletion gate: %d source(s) FULLY decomposed, ' ...
                     '%d partly, refused_total %d\n'], ...
                numGet(rep, 'sources_fully_decomposed'), ...
                numGet(rep, 'sources_partly_decomposed'), ...
                numGet(rep, 'refused_total'));
            fprintf(['      refused: %d no element_id, %d no intervals, ' ...
                     '%d no anchor block, %d no epoch string, %d no epoch ' ...
                     'document, %d ambiguous epoch, %d no clock, %d ' ...
                     'non-finite times, %d negative extent\n'], ...
                numGet(rep, 'refused_no_element_id'), ...
                numGet(rep, 'refused_no_intervals'), ...
                numGet(rep, 'refused_no_anchor_block'), ...
                numGet(rep, 'refused_no_epoch_string'), ...
                numGet(rep, 'refused_no_epoch_document'), ...
                numGet(rep, 'refused_ambiguous_epoch'), ...
                numGet(rep, 'refused_no_clock'), ...
                numGet(rep, 'refused_non_finite_times'), ...
                numGet(rep, 'refused_negative_extent'));
            % HAZARD 3, REPORT-ONLY. `inheritance_candidates` is how many
            % subjects hold a `derived_from` edge to an element this pass wrote
            % statements for -- the population NDI's `underlying_element`
            % fallback serves. NOTHING is emitted for them; the team has not
            % decided between re-deriving and materialising, and this number is
            % so the decision has a size attached.
            fprintf(['      OPEN (not decided): %d inheritance candidate(s) ' ...
                     '(derived_from an element with statements); %d source(s) ' ...
                     'carried an `app` block that stays on the source; %d ' ...
                     'staged ontology node(s)\n'], ...
                numGet(rep, 'inheritance_candidates'), ...
                numGet(rep, 'sources_with_app_block'), ...
                numGet(rep, 'staged_ontology_nodes'));
            fprintf(['      %d reference(s) quarantined, %d statement(s) ' ...
                     'quarantined, %d statement(s) WITHHELD for a lost ' ...
                     'anchor; %d document(s) appended\n'], ...
                numGet(rep, 'references_quarantined'), ...
                numGet(rep, 'statements_quarantined'), ...
                numGet(rep, 'statements_withheld_lost_anchor'), ...
                numGet(rep, 'documents_appended'));
    end
end
end

function v = numGet(rep, name)
%NUMGET One numeric field off a report struct, NaN when it is not there.
%   NaN rather than 0 on purpose: a missing counter must not print as a
%   measured zero.
v = NaN;
if isstruct(rep) && isfield(rep, name)
    x = rep.(name);
    if isnumeric(x) && isscalar(x); v = double(x); end
end
end


function printSourceCensus(result)
%PRINTSOURCECENSUS The V1 SOURCE census: the three pre-build measurements.
%   Report-only, and deliberately verbose about its DENOMINATOR first -- a
%   count without one is not evidence, which is the lesson from a census that
%   printed zeros while reading nothing for two days.
if ~isfield(result, 'source_census'); return; end
sc = result.source_census;
if isfield(sc, 'audit_failed')
    fprintf('source census: FAILED (%s)\n', sc.audit_failed);
    return;
end
fprintf(['\n--- v1 SOURCE census (REPORT ONLY): %d document(s) read, ' ...
         '%d unreadable ---\n'], sc.total_docs, sc.skipped_docs);

fprintf('  epoch ids: %d document(s) carry one, %d distinct\n', ...
    sc.docs_with_epoch_id, sc.distinct_epoch_ids);
for k = 1:numel(sc.epoch_id_by_prefix)
    e = sc.epoch_id_by_prefix(k);
    fprintf('      %-16s %6d distinct  %8d doc(s)\n', ...
        e.prefix, e.distinct_ids, e.doc_count);
end
fprintf('    grouping hazard: %d synthetic (whole_session_) id(s); %d id(s) span >1 session\n', ...
    sc.synthetic_epoch_id_count, sc.cross_session_epoch_id_count);
for k = 1:min(numel(sc.synthetic_epoch_ids), 10)
    s = sc.synthetic_epoch_ids(k);
    fprintf('      would fuse %3d element span(s): %s (%d doc(s), %d class(es))\n', ...
        s.distinct_elements, s.epoch_id, s.doc_count, s.distinct_classes);
end

fprintf('  session documents: %d   (distinct base.session_id values: %d)\n', ...
    sc.session_doc_count, sc.distinct_session_ids);
if sc.session_doc_count == 0
    fprintf('      NONE -- a required `relative_to` would have no referent here\n');
end

fprintf('  stimulation approaches: %d document(s) over %d epoch(s)\n', ...
    sc.approach_doc_count, sc.approach_epochs);
% BOTH SIDES' DENOMINATORS. Dab reported 635 approaches, 635 epochs, and 635 of
% those epochs carrying NO presentation -- a result that cannot be read at all
% without knowing whether this census saw any presentations to begin with.
if isfield(sc, 'presentation_doc_count')
    fprintf('      stimulus_presentation documents seen: %d (%d carry an epoch id)\n', ...
        sc.presentation_doc_count, sc.presentation_docs_with_epoch);
end
% WHY THE TWO SIDES DO NOT MEET. Printed whenever either side exists, because
% the interesting case is precisely the one where both are non-zero and the
% overlap is not -- Dab. The pooled prefix histogram above cannot answer it: it
% mixes every class together.
if sc.approach_doc_count > 0 || sc.presentation_doc_count > 0
    if isfield(sc, 'approach_presentation_shared_epochs')
        fprintf('      epoch ids carried by BOTH classes: %d\n', ...
            sc.approach_presentation_shared_epochs);
    end
    printPrefixTally('      approach epoch ids', sc, 'approach_epoch_prefixes');
    printPrefixTally('      presentation epoch ids', sc, 'presentation_epoch_prefixes');
end

if sc.approach_doc_count > 0
    fprintf('      distinct subjects per approach epoch:\n');
    if isempty(sc.subjects_per_approach_epoch)
        fprintf('        (none -- no approach epoch had a presentation)\n');
    end
    for k = 1:numel(sc.subjects_per_approach_epoch)
        d = sc.subjects_per_approach_epoch(k);
        fprintf('        %3d subject(s): %6d epoch(s)\n', d.n_subjects, d.n_epochs);
    end
    fprintf('        %6d approach epoch(s) with NO presentation document\n', ...
        sc.approach_epochs_no_presentation);
end
end

function printPrefixTally(label, sc, field)
%PRINTPREFIXTALLY One class's epoch-id prefix breakdown, buckets always shown.
%   Every bucket prints even at zero: which bucket is EMPTY is the finding here,
%   so suppressing zeros would hide the answer.
if ~isfield(sc, field); return; end
t = sc.(field);
fprintf('%s:\n', label);
if isempty(t)
    fprintf('        (no epoch ids on this class)\n');
    return;
end
for k = 1:numel(t)
    fprintf('        %-16s %4d distinct  %6d doc(s)\n', ...
        t(k).prefix, t(k).n_distinct, t(k).n_docs);
end
end
