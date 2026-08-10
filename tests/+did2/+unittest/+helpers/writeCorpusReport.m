function reportPath = writeCorpusReport(corpusName, result, reasons)
%WRITECORPUSREPORT Write a JSON discovery summary under corpus-reports/.
%
%   REPORTPATH = did2.unittest.helpers.writeCorpusReport(NAME, RESULT, REASONS)
%   writes <pwd>/corpus-reports/<NAME>-summary.json containing the
%   converter summary plus a top-quarantine-reasons table. The CI
%   workflow's upload-artifact step picks up everything under that
%   directory.

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

fid = fopen(reportPath, 'w');
if fid < 0
    error('did2:test:reportWriteFailed', ...
        'Could not open %s for writing.', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(report, 'PrettyPrint', true));
end
