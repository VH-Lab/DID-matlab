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
%
%   STATUS of the 2026-08-12 edit (`reference_integrity`): THE SAME AGAIN, and
%   said again rather than inherited from the two paragraphs above it. Written
%   with NO MATLAB and NO OCTAVE in the container (`command -v matlab`,
%   `octave`, `octave-cli` all exit 1), NOT EXECUTED; CI is its first run. The
%   Python half IS covered and was run green: tools/census_digest.py renders
%   the key and TestReferenceIntegrity in tools/test_census_digest.py exercises
%   the clean, orphans-found, not-measured, audit-failed and truncated-sample
%   cases. The MATLAB half -- that runCorpusDiscovery puts the block on
%   `result` in this shape -- is unexecuted.

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

% THE SECOND HALF OF THE HEADLINE CORPUS GATE, PERSISTED FOR THE FIRST TIME.
% The gate is quoted everywhere in this project as "0 quarantine + 0 orphans".
% `quarantine_count` is four lines above and has been in this report since it
% was written; the orphan half was computed by `did2.validate.references`,
% hard-asserted by runCorpusDiscovery, and then DROPPED -- the validator ran
% ~65 lines AFTER this function, so the figure reached the runner's log and
% died there, and no digest has ever rendered it (V_eta_OPEN_WORK.md #101).
% This file's own comment at the valid_interval block says "both are 0
% quarantine and 0 orphans" while the second of those two fields was not
% written. So every "0 quarantine + 0 orphans" quoted from a digest has quoted
% one measurement and one silence.
%
% WRITTEN AS A BLOCK, NOT A BARE COUNT, and the extra fields are not padding:
% `edges_examined` is the denominator that makes the zero readable. A run where
% every edge resolved and a run where no edge was examined both print
% `orphan_count: 0`, and nothing else in this report can tell them apart.
%
% AN ORPHAN IS NOT AN EMPTY EDGE. `+did2/+validate/references.m:90` SKIPS an
% edge whose document_id is empty, which is why `mustBeNonEmpty` on a
% depends_on is decorative -- so `silent_loss`'s empty-required-edge census
% below and this counter answer different questions and neither may ever be
% quoted for the other.
%
% ABSENT IS NOT ZERO: written only when runCorpusDiscovery put it there.
% `testCorpusPRED` never calls `did2.validate.references` at all, so PRED's
% report carries no such key and the digest prints it as NOT MEASURED rather
% than summing a zero it does not have. That gap is stated, not closed here.
if isfield(result, 'reference_integrity')
    report.reference_integrity = result.reference_integrity;
end
% Phase 1 report-only census (V_eta_ground_truth_plan.md): data that migrates
% away without tripping any gate. Persisted in the uploaded artifact so the
% count is reviewable per corpus without re-reading a 2.5-hour log.
if isfield(result, 'silent_loss')
    report.silent_loss = result.silent_loss;
end
% #52 EVIDENCE (report-only): the per-statement time-reference COUNT
% DISTRIBUTION and, for the multi-reference ones, the SHAPES. Persisted for the
% same reason as the censuses around it -- the team decision it feeds is about
% what a bare `_1`/`_2` index means, and that call has to rest on measured
% instances rather than on a function signature someone read.
%
% READ `headline` FIRST -- it carries every denominator in one line. Then read
% `reference_census_vacuous` and `shape_census_vacuous` BEFORE any count: this
% block is EXPECTED to come back with an empty shape table, and an empty shape
% table has two completely different meanings. "No statement carries a second
% reference" is a result; "no statement could have carried one" is not. The two
% vacuity flags and their `_reason` strings are what keep them apart, and they
% are the reason this is persisted as a block rather than as a number.
%
% NOT YET RENDERED BY tools/census_digest.py. The digest is owned elsewhere and
% is deliberately not edited here; until it reads this key, the block is in the
% artifact JSON and not in the end-of-log census.
if isfield(result, 'time_reference_families')
    report.time_reference_families = result.time_reference_families;
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
% EPOCH-STRING RETENTION: did a did_v1 epoch-id string survive the migration,
% either still spelled out on a migrated document or as a minted `epoch` entity?
% Persisted because until this run the instrument had never executed on real
% data at all -- called from tests only, 0 call sites in src/ and 0 in tools/ --
% so this is the FIRST measurement of a loss the plan documents have been
% reasoning about without a number.
%
% READING INSTRUCTIONS, and they are not generic:
%
% (1) THE DENOMINATOR IS `v1_pairs`, and `v1_classes_inspected` beside
%     `v1_classes_with_string` is the class-level one. `pairs_dropped: 0` with
%     `v1_pairs: 0` means NO v1 DOCUMENT IN THIS CORPUS CARRIED AN EPOCH STRING
%     -- vacuous, not clean. Those two readings print identically without the
%     denominator, which is the whole reason this block exists as a block.
% (2) `v1_by_class` IS WHERE "0 of 0" LIVES. `vmspikefit` and `pyraview` drop
%     the string by construction (both migrators build new bodies and never copy
%     the `epochid` block), so their ABSENCE from this table is "no such
%     document in this corpus", NOT "the drop is fixed". The discovery log
%     prints a line for both either way; the artifact keeps the table so the
%     same distinction survives past the log.
% (3) `retained_as_epoch_document` IS ONLY MEANINGFUL BECAUSE OF WHERE THE
%     INSTRUMENT IS CALLED. It runs AFTER every batch post-pass, so `epochMint`
%     has already minted. Sited beside `silentLoss` (v1_to_v2.m:382, pass 1) it
%     would be structurally 0 -- the same tautology recorded in 203c1f7 and
%     V_eta_OPEN_WORK.md #86a. A pass-1 number and this number answer different
%     questions and must never be quoted as one.
% (4) `v1_declined` IS EXCLUDED FROM THE DENOMINATOR ON PURPOSE
%     (`syncrule_mapping`'s endpoint strings). It is carried so the gap is a
%     number rather than a silence.
%
% NOT YET RENDERED BY tools/census_digest.py -- the same state
% `time_reference_families` above is in, and named here for the same reason.
% The digest is owned elsewhere and is deliberately not edited from here; until
% it reads this key the block is in the artifact JSON and not in the
% end-of-log census. That is a DEBT with a direction, not a design.
if isfield(result, 'epoch_string_retention')
    report.epoch_string_retention = result.epoch_string_retention;
end
% THE POST-MINT EPOCH CHAIN (#60, #86a). A SECOND `epoch_association` block,
% from a second silentLoss call sited after every batch post-pass, so that
% `REACH AN EPOCH` is measured on a batch that can actually contain an `epoch`.
% The pass-1 block stays exactly where it is under `silent_loss` and the two
% are NEVER summed or substituted: the pass-1 epoch counts are 0 BY
% CONSTRUCTION (epochMint appends afterwards), which is why the digest prints
% them under "FIGURES MEASURED PRE-MINT -- NOT COMMENSURABLE".
if isfield(result, 'epoch_association_post_pass')
    report.epoch_association_post_pass = result.epoch_association_post_pass;
end
% `deferred_bath_resolution` -- the FIRST pass in the chain, and the last one
% to acquire a report (2026-08-11). PERSISTED BECAUSE IT SWALLOWED ITS OWN
% FAILURES: the per-bath handler was a bare `catch` whose body was two comment
% lines, so an unreadable body, a missing `stimulus_element_id`, a genuinely
% absent element and an outright bug all produced the identical outcome --
% document stays quarantined, nothing counted. "Resolved every deferred bath"
% and "resolved none, every element missing from the batch" have therefore been
% the same reading of every corpus run to date, run 31522068566 (green)
% included. The pass is not a no-op: it moves documents from
% `quarantine` into `migrated`.
%
% WHICH ZERO YOU ARE LOOKING AT: `quarantine_inspected` is the denominator and
% `deferred_baths_seen` is the one that decides the reading. 0 seen out of a
% large quarantine means this corpus deferred no bath (a fact about the input);
% 0 seen out of 0 means there was no quarantine at all. `refused_*` splits the
% five causes and MUST NOT be summed into one -- only
% `refused_element_not_in_batch` is the designed best-effort outcome; a
% non-zero `refused_unexpected_error` is a defect, and
% `unexpected_error_reasons` names one entry per distinct identifier.
if isfield(result, 'deferred_bath_resolution')
    report.deferred_bath_resolution = result.deferred_bath_resolution;
end
% `dataset_entity_resolution` -- PERSISTED BECAUSE THIS PASS DELETES DOCUMENTS
% AND, UNTIL 2026-08-11, COUNTED NEITHER DELETION. Both `keep(k) = false` sites
% feed `result.migrated = docs(keep)`, and the only number that survived them
% (`migrated_count`) is taken AFTER the removal -- so how many documents it
% dropped in any past run is UNRECOVERABLE from the artifacts. That is why this
% block exists rather than a log line.
%
% THE TWO DELETION REASONS ARE DIFFERENT FACTS AND MUST NEVER BE SUMMED.
% `duplicates_dropped_poorer_richness` is a dedup -- the content survives on
% the richer twin under the SAME base.id, nothing dangles.
% `membership_dropped_child_absent` is a `session -part_of-> dataset` statement
% discarded outright. A combined total would let the second hide inside the
% first. `membership_dropped_no_child_edge` is a THIRD fact that used to hide
% inside the second (an edge naming no child is a migrator defect, not a linked
% session).
%
% READ `documents_removed_unattributed` AS A GATE, NOT A STATISTIC: it is the
% keep-mask count minus the three named reasons, so anything but 0 means a
% document was removed by a path that does not say why. And read
% `documents_unreadable` BEFORE `membership_dropped_child_absent` -- the prune
% decides on absence from an id index, so an unreadable document makes that
% count an upper bound rather than a measurement.
if isfield(result, 'dataset_entity_resolution')
    report.dataset_entity_resolution = result.dataset_entity_resolution;
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

% `valid_interval_decompose` -- DORMANT BY TEAM DECISION 2026-08-12. The pass
% RUNS and EMITS NOTHING: the agreed model is ONE statement holding an ARRAY of
% booleans against a TIME AXIS, and it waits on `axes[]` (DID-schema OPEN_WORK
% #45 -> #32) rather than shipping the 1->N decomposition as an interim.
%
% SO ONLY TWO OF ITS COUNTERS ARE INFORMATIVE NOW, and they are the reason the
% block is still persisted: `sources_seen` and `intervals_seen` are the only
% measurement anyone has of how much `valid_interval` data is waiting on that
% build. `dormant` is TRUE and every emission counter is 0 BY DECISION.
% Reading instructions (1)-(4) below describe the ARMED path and are kept for
% when it is re-armed; (1) applies unchanged today.
%
% PERSISTED FOR THE SAME REASON AS ITS SIBLINGS -- and for this pass the reason
% is not generic. THE WHOLE CLASS EXISTS SO THAT "THIS STRETCH IS BAD DATA" IS
% SAYABLE: did_v1 encoded validity in the CLASS NAME, so invalidity was
% expressible only as absence, and markgarbage's own author wrote the gap down
% (markgarbage.m:40). A pass that measures that repair and whose counters
% nobody can read reproduces the same defect one level up. Four reading
% instructions:
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
