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

fid = fopen(reportPath, 'w');
if fid < 0
    error('did2:test:reportWriteFailed', ...
        'Could not open %s for writing.', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(report, 'PrettyPrint', true));
end
