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
% The DID-only counterpart to ndi.migrate's dataset-aware second pass.
if strcmp(options.TargetVersion, 'V_eta')
    result = did2.convert.resolveDatasetEntities(result, ...
        'Validate', true, 'TargetVersion', options.TargetVersion);

    % Mint the `epoch` entities did_v1 never had, one per distinct
    % (base.session_id, epoch-id string) -- the PAIR, because an
    % `epochid.epochid` string is reused across sessions (142 of B's 149
    % distinct ids, sourceCensus run 31415147934), so keying on the string
    % alone would FUSE epochs from different sessions. A find-or-create over
    % the whole corpus, which no single-document migrator can do; its report
    % rides on `result.epoch_mint` and is persisted by writeCorpusReport.
    [result, ~] = did2.convert.epochMint(result, ...
        'Validate', true, 'TargetVersion', options.TargetVersion);
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
