function reportPath = writeCorpusReport(corpusName, result, reasons)
%WRITECORPUSREPORT Write a JSON discovery summary under corpus-reports/.
%
%   REPORTPATH = did2.unittest.helpers.writeCorpusReport(NAME, RESULT, REASONS)
%   writes <pwd>/corpus-reports/<NAME>-summary.json containing the
%   converter summary plus a top-quarantine-reasons table. The CI
%   workflow's upload-artifact step picks up everything under that
%   directory.
%
%   STATUS of the 2026-08-10 edit (`session_anchor_fold`): WRITTEN WITHOUT
%   MATLAB and NOT EXECUTED. `tools/census_digest.py` renders the new key and
%   IS tested (tools/test_census_digest.py), so the Python half of the path is
%   covered; the MATLAB half is not.
%
%   STATUS of the 2026-08-11 edit (`legacy_ndi_document`): THE SAME, and said
%   again rather than assumed. Written with NO MATLAB and NO OCTAVE available,
%   NOT EXECUTED; CI is its first run. tools/census_digest.py renders the new
%   key and IS tested (TestLegacyNdiDocumentBlock in
%   tools/test_census_digest.py, run green), so the Python half is covered and
%   the MATLAB half is not.

reportDir = fullfile(pwd, 'corpus-reports');
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end
reportPath = fullfile(reportDir, [corpusName '-summary.json']);

report = struct( ...
    'corpus',            corpusName, ...
    'generated_at',      char(datetime('now', 'TimeZone', 'UTC', ...
                            'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'total',             result.summary.total, ...
    'migrated_count',    result.summary.migrated_count, ...
    'quarantine_count',  result.summary.quarantine_count, ...
    'by_class',          result.summary.by_class, ...
    'quarantine_reasons', reasons);

% Phase 1 report-only census (V_eta_ground_truth_plan.md): data that migrates
% away without tripping any gate. Persisted in the uploaded artifact so the
% count is reviewable per corpus without re-reading a 2.5-hour log.
if isfield(result, 'silent_loss')
    report.silent_loss = result.silent_loss;
end
if isfield(result.summary, 'unconverted_count')
    report.unconverted_count = result.summary.unconverted_count;
    report.unconverted_by_class = result.summary.unconverted_by_class;
end
% The FRAGMENT census: migrations that emitted only scaffolding and dropped the
% payload. The third failure mode, and the one nothing could see before.
if isfield(result.summary, 'fragment_count')
    report.fragment_count = result.summary.fragment_count;
    report.fragment_by_class = result.summary.fragment_by_class;
end
% THE LEGACY IDENTITY BLOCK (`ndi_document` -> `base`). Persisted for the same
% reason as the two censuses above, plus one that is specific to it: this
% counter is expected to read ZERO on every corpus we hold, and the zero is the
% deliverable. Corpus run 31464483119 inspected 633,432 documents across 6
% corpora and quarantined 0, so no pre-`base` document is in the sample -- and
% per the standing rule that is a fact about the SAMPLE and not evidence none
% exist. Until a run reports a non-zero `moved_wholesale_no_base`, the size of
% the defect is UNMEASURED rather than zero, and only a persisted zero makes
% that distinction survive past the log.
%
% READ `bodies_reaching_universal_renames` BEFORE ANY OTHER NUMBER HERE. It is
% the denominator, and it is NOT `total`: the idempotency short-circuit skips
% the pass entirely, so a re-run over already-migrated bodies would report
% every arm at 0 with nothing having been inspected. `bodies_total`,
% `bodies_skipped_already_target` and `bodies_unreached` account for the gap.
%
% READ `moved_wholesale_no_base` WITH THE `moved_vintage_*` BUCKETS BESIDE IT.
% The `ndi_document` block had FOUR shapes over its life, not one, and which
% one a body carries is what decides whether the wholesale move was sound:
% the 2020-05-19 vintage (e8c02831d, and the longest-lived of the four -- it ran
% until base.json replaced it at 9783809c2, 2023-04-13) already spells
% `id`/`session_id`, so identity lands CORRECTLY and only `type` +
% `database_version` arrive undeclared; the two 2019 vintages land with no
% usable identity at all. `moved_vintage_bodies_classified` is the classifier's
% denominator and the six buckets partition it, `unknown` and
% `unreadable_block` included -- a shape the table does not predict is NEVER
% rounded to the nearest vintage.
%
% The `moved_carrying_*` counters remain, and remain useful as single facts,
% but they cannot NAME a vintage: two consecutive pairs of shapes differ by one
% field name each (`experiment_id` vs `session_id`, `document_id` vs `id`).
if isfield(result, 'summary') && isfield(result.summary, 'legacy_ndi_document')
    report.legacy_ndi_document = result.summary.legacy_ndi_document;
end

% The V1 SOURCE census: three pre-build measurements that exist nowhere else
% (epoch-id shape and its grouping hazard, session-document presence,
% stimulation-approach coverage). Persisted rather than left in the log, because
% each of these blocks a build and will be read weeks after the run.
if isfield(result, 'source_census')
    report.source_census = result.source_census;
end
% The EPOCH MINT (#60): how many `epoch` entities were minted, and -- more
% useful -- every refusal, counted. `pairs_minus_strings` is the number of
% epochs that keying on the id STRING instead of the (session, id) PAIR would
% have destroyed by fusion. Denominator-first by construction; persisted here
% because a builder that reports only what it built is the counter this project
% keeps getting burned by.
if isfield(result, 'epoch_mint')
    report.epoch_mint = result.epoch_mint;
end
% The SESSION ANCHOR FOLD (#65): session_relative_reference (107,308 documents)
% + session_bounded_reference (20,411) -> `relative_reference`, base.id
% preserved. Persisted for the same reason as epoch_mint, plus one specific to
% this pass: `refused_total` IS HALF THE DELETION GATE for the six retiring
% reference classes (the other half is 0 surviving session_*_reference in
% by_class, which this file already writes). Deleting a class whose documents
% still exist is the epochfiles_ingested regression, which cost 2,484
% quarantines -- so the evidence for that deletion has to be in the artifact,
% not in a log somebody has to still have open.
%
% `pass_failed` rides in the same struct when the guard
% (did2.unittest.helpers.runBatchPass) caught a throw. It is written here
% UNCONDITIONALLY with whatever the pass left, so a failed pass is a field in
% the report rather than an absence -- a report that simply omitted the pass
% would be indistinguishable from a run where it was never wired, which is the
% exact condition this whole change exists to end.
if isfield(result, 'session_anchor_fold')
    report.session_anchor_fold = result.session_anchor_fold;
end
% THE RESPONSE-PARAMETERS FOLD (#61): the resolver half of the signed
% stimulus-response model -- the five run knobs inlined onto the
% `harmonic_component_calculation` leaf, the `method_parameters_id` edge
% dropped. Persisted for two reasons beyond symmetry with the two above.
%
% (1) `parameters_documents_unreferenced_after` IS THE VERIFY-BEFORE-DELETE
%     GATE the plan requires before the
%     `stimulus_response_scalar_parameters_basic` documents may be deleted
%     (11,440 of them over five corpora at the plan's last count, run #257 /
%     0458dae -- a sample, and the number this pass reports is the one to use). The
%     ensemble fold got the same gate. Evidence for a deletion has to survive in
%     the artifact, not in a log somebody has to still have open -- and it is
%     evidence, not authorisation: the corpora are a sample.
% (2) `leaves_seen` beside `suppressed_responses_seen` is the ONLY place a
%     reader can tell "this corpus has no responses" from "pass 1's epoch gate
%     suppressed every fold and #60 is what opens it". A report that carried one
%     without the other would be the all-zeros-reads-as-clean failure again.
%
% Written UNCONDITIONALLY with whatever the pass left, `pass_failed` included,
% so a failed pass is a field rather than an absence.
if isfield(result, 'response_parameters_fold')
    report.response_parameters_fold = result.response_parameters_fold;
end

% did2.convert.resolveLawnPlateSubjects -- the E. coli lawn/plate subject tiers,
% their `member_of` join and the (experiment, plate, patch) identifier (team,
% 2026-08-11). Persisted for the reasons the passes above are, plus three that
% are specific to it:
% (1) FOUR STATES THAT MUST NOT BE SUMMED. "no E. coli tables in this corpus",
%     "row present, no values at all", "row present, values this tier cannot
%     type" and "row present, measurements, subject minted" are separate
%     findings, and the team asked specifically to see the second and third if
%     they are ever non-zero -- it would mean the expectation that both tiers
%     are populated does not hold for some population.
% (2) `unclassified_rows_in_those_sessions` is the SPELLING CANARY. The pass
%     matches columns by a normalised term token because `ndi.ontology.lookup`
%     cannot be evaluated where the pass was written. Zeros beside a zero
%     unclassified count is "nothing here"; zeros beside a large one is "the
%     token rule is wrong". Only the artifact keeps the pair together.
% (3) `local_identifier_collisions_within_batch` is the measured form of the
%     directive's own premise, that the (experiment, plate, patch) combo is
%     unique. Evidence for the team, not authorisation for the pass.
% Written UNCONDITIONALLY with whatever the pass left, `pass_failed` included,
% so a failed pass is a field rather than an absence.
if isfield(result, 'lawn_plate_subjects')
    report.lawn_plate_subjects = result.lawn_plate_subjects;
end

% `generic_file_fold` (TEAM DECISION 2026-08-11). PERSISTED FOR THE SAME
% REASON AS ITS SIBLINGS, and with one reading instruction attached: all six
% corpora held ZERO `generic_file` documents at run 31327383671, so the
% EXPECTED artifact line is `generic_files_seen: 0` with every other counter 0
% beside it. That is a fact about the SAMPLE (the class is written by the Babu
% converter, for datasets that are not in the gate) and NOT evidence the fold
% works or does not. The line worth looking at is a non-zero
% `generic_files_seen` with `files_folded` below it; `refused_no_label`,
% `refused_ambiguous_label`, `refused_no_document_id` and
% `refused_referent_not_in_batch` then say which reason, and
% `date_fields_dropped` counts a loss the model has not yet closed.
% `epochMint`'s near miss is the thing this line prevents: a pass wired
% everywhere, persisted nowhere, whose number existed and could not be seen.
if isfield(result, 'generic_file_fold')
    report.generic_file_fold = result.generic_file_fold;
end

% `openminds_citations` (TEAM DECISION 2026-08-11, "Do B"). PERSISTED FOR THE
% SAME REASON AS ITS SIBLINGS, with three reading instructions attached:
%
% (1) THE DENOMINATOR IS `openminds_documents_seen` BESIDE
%     `openminds_components_seen`. Every counter at 0 with those two at 0 means
%     "this corpus holds no openMINDS graph" -- true of 5 of the 6 corpora at
%     the last measurement (run 31441923369: 8 `openminds` documents in total,
%     all of them in JH). That is a fact about the SAMPLE and NOT evidence the
%     assembler works or does not.
% (2) `components_withheld` IS THE ORPHAN GUARD SPEAKING, and it is a FINDING
%     rather than a passthrough statistic. Consumption is all-or-none per
%     connected component, so a withheld component means some planned document
%     would have been left referenced by a survivor. `withheld_reasons` names
%     which component and why. `components_planned` = consumed + withheld +
%     reverted_on_validation; the three are never summed into one number,
%     because "refused for safety" and "blew up in validation" are different
%     answers.
% (3) THE `..._consumed_without_a_home` COUNTERS ARE A MEASURED LOSS, not
%     bookkeeping. Contribution role documents, SemanticDataType and technique
%     sit inside the planned set (leaving them would dangle an edge) and the
%     entity tier has nowhere to put their content, so they are consumed and
%     counted. `affiliations_beyond_first_dropped` is the size of an OPEN team
%     question that metadata_editor's header already records.
%
% `epochMint`'s near miss is what this block exists to prevent, and this pass
% reproduced it exactly: it was wired at all four call sites and persisted
% nowhere, so its numbers would have reached the log and not the artifact.
% Caught by tools/test_batch_pass_wiring.py, which is the instrument working.
if isfield(result, 'openminds_citations')
    report.openminds_citations = result.openminds_citations;
end

% `valid_interval_decompose` (TEAM DECISION 2026-08-11: `valid_interval` becomes
% a boolean-valued `subject_statement`). PERSISTED FOR THE SAME REASON AS ITS
% SIBLINGS -- and for this pass the reason is not generic. THE WHOLE CLASS
% EXISTS SO THAT "THIS STRETCH IS BAD DATA" IS SAYABLE: did_v1 encoded validity
% in the CLASS NAME, so invalidity was expressible only as absence, and
% markgarbage's own author wrote the gap down (markgarbage.m:40). A pass that
% measures that repair and whose counters nobody can read reproduces the same
% defect one level up. Four reading instructions:
%
% (1) THE DENOMINATOR IS `sources_seen` BESIDE `epoch_documents_seen`. Every
%     counter at 0 with `sources_seen` at 0 means "this corpus holds no
%     markgarbage documents" -- true of all six at run 31327383671. That is a
%     fact about the SAMPLE and NOT evidence the decompose works or does not.
%     `sources_seen` non-zero with `intervals_decomposed` at 0 is the line worth
%     looking at; the eight `refused_*` counters then say which reason.
% (2) THAT ZERO IS ALSO HAZARD 1 LOOKING CORRECT. `ndi.app.markgarbage` is
%     OPT-IN, so no document means the whole epoch is good data
%     (markgarbage.m:172-176). A corpus with no sources MUST come out with
%     `statements_emitted: 0` rather than with every epoch reclassified as
%     unknown -- and no other instrument here can tell those two apart, because
%     both are 0 quarantine and 0 orphans.
% (3) `sources_fully_decomposed` IS A DELETION GATE, not a statistic. The
%     `valid_interval` tombstone may be retired only when every source is fully
%     decomposed AND `refused_total` is 0. The pass ADDS and never removes, so
%     until then both representations coexist on purpose -- verify before
%     delete, the rule `epochfiles_ingested` cost 2,484 quarantines for breaking.
% (4) `split_anchor_intervals` IS A PREDICTION UNDER TEST and
%     `inheritance_candidates` IS AN OPEN TEAM QUESTION WITH A SIZE. The first
%     should stay 0 (CHANGE 5 measured that every markvalidinterval call site
%     passes one reference for both ends); the second counts the subjects NDI's
%     `underlying_element` fallback serves, which is the number the inheritance
%     decision needs and which nothing else in this repo computes.
%
% Written UNCONDITIONALLY with whatever the pass left, `pass_failed` included,
% so a failed pass is a field rather than an absence.
if isfield(result, 'valid_interval_decompose')
    report.valid_interval_decompose = result.valid_interval_decompose;
end

fid = fopen(reportPath, 'w');
if fid < 0
    error('did2:test:reportWriteFailed', ...
        'Could not open %s for writing.', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(report, 'PrettyPrint', true));
end
