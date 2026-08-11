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
result = did2.convert.resolveDeferredBaths(result, ...
    'Validate', true, 'TargetVersion', options.TargetVersion);

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

    result = did2.convert.resolveDatasetEntities(result, ...
        'Validate', true, 'TargetVersion', options.TargetVersion);

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

    % TEAM DECISION 2026-08-11: `valid_interval` becomes a boolean-valued
    % `subject_statement`. This decomposes each v1 document's interval ARRAY
    % into one `validity_observation` per interval (the element-subject as
    % `subject_id`, the v1 array position as `sequence`) plus the
    % `relative_reference` each is anchored to.
    %
    % ORDER: LAST, AND ITS DEPENDENCE ON epochMint IS REAL, unlike the "they
    % commute" notes above. It anchors to the `epoch` DOCUMENTS epochMint
    % appends -- read out of `result.migrated`, so it behaves the same whether
    % they were minted this run or were already there -- and run BEFORE
    % epochMint it would refuse every interval with `refused_no_epoch_document`
    % and change nothing. Nothing else reads or writes `valid_interval`,
    % `validity_observation` or `relative_reference` in a way that conflicts:
    % resolveSessionAnchors rewrites only the two session_*_reference classes.
    %
    % IT ADDS AND NEVER REMOVES. The `valid_interval` source document stays in
    % the batch under its own tombstone, so a wrong decomposition loses nothing
    % and `sources_fully_decomposed` MEASURES the deletion gate instead of
    % pre-empting it.
    %
    % READ ITS ZEROS WITH `sources_seen` BESIDE THEM. All six corpora held ZERO
    % `valid_interval` documents at run 31327383671, so all-zero is the EXPECTED
    % reading and says nothing about whether the decompose works. AND THAT IS
    % ALSO WHAT HAZARD 1 LOOKS LIKE WHEN IT IS HANDLED CORRECTLY: markgarbage is
    % opt-in, absence means "all of this is good data", and a corpus with no
    % source documents must come out with no validity statements rather than
    % with every epoch reclassified as unknown. A non-zero `sources_seen` beside
    % `intervals_decomposed` at 0 is the interesting line; `refused_*` then says
    % which reason.
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
% THREE PASSES ARE DELIBERATELY NOT IN THIS LIST, and saying so is the point --
% an omission nobody wrote down is the thing this whole file exists to stop.
% `response_parameters_fold`, `lawn_plate_subjects` and `openminds_citations`
% are all new and have NEVER BEEN EXECUTED, and making a throw fatal for an unexecuted pass
% red-gates the corpus for everyone on a first run. That is the same judgement
% resolveSessionAnchors's author made when they left it unwired, and it is
% correct while it is STATED: printBatchPasses above prints
% `*** FAILED: <message>` for either of them, so a throw is visible in the log
% of every corpus run rather than silent. Move them into this list once a real
% corpus run has reported them green.
for passField = {'epoch_mint', 'session_anchor_fold'}
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
refRep = [];
try
    refRep = did2.validate.references(result.migrated);
catch refReportErr
    fprintf('reference report skipped: %s\n', refReportErr.message);
end
if ~isempty(refRep)
    fprintf('\n--- reference integrity (%s): %d orphan(s) of %d edges ---\n', ...
        corpusName, refRep.orphan_count, refRep.edges_examined);
    [orphNames, orphCounts] = aggregateOrphans(refRep.orphans);
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
printFileListAudit(result);
printSourceCensus(result);
printBatchPasses(result);
fprintf('top quarantine reasons:\n');
for k = 1:min(numel(reasons), 15)
    fprintf('  %5d  [%s] %s\n', reasons(k).count, ...
        reasons(k).class_name, reasons(k).reason);
end
end

function [names, counts] = aggregateOrphans(orphans)
%AGGREGATEORPHANS Count dangling edges by "doc_class.edge_name", desc.
names = {};
counts = [];
for k = 1:numel(orphans)
    key = sprintf('%s.%s', orphans(k).doc_class, orphans(k).edge_name);
    idx = find(strcmp(names, key), 1);
    if isempty(idx)
        names{end+1} = key;  %#ok<AGROW>
        counts(end+1) = 1;   %#ok<AGROW>
    else
        counts(idx) = counts(idx) + 1;
    end
end
if ~isempty(counts)
    [counts, order] = sort(counts, 'descend');
    names = names(order);
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
expected = { ...
    'openminds_citations',      'did2.convert.resolveOpenmindsCitations'; ...
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
            % THE DIRECTIVE'S OWN PREMISE, MEASURED. The team states the
            % (experiment, plate, patch) combo is unique; this is the number
            % that confirms or refutes it on real data. It is evidence for them,
            % never authorisation for the pass to choose another scheme.
            fprintf(['      identifiers: %d collision(s) among the handles ' ...
                     'this pass formed, %d fell back to the document id; ' ...
                     '%d document(s) appended, %d source row(s) left in ' ...
                     'place (NOT consumed)\n'], ...
                numGet(rep, 'local_identifier_collisions_within_batch'), ...
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
