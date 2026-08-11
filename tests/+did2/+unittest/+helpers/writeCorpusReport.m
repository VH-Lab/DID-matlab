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

fid = fopen(reportPath, 'w');
if fid < 0
    error('did2:test:reportWriteFailed', ...
        'Could not open %s for writing.', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(report, 'PrettyPrint', true));
end
