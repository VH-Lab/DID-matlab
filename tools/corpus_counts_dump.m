function corpus_counts_dump(tc, corpusName, outDir)
%CORPUS_COUNTS_DUMP Scratch (branch claude/corpus-counts-1110 only; never for V2).
%   Runs the corpus exactly as testCorpus<NAME> does
%   (did2.unittest.helpers.runCorpusDiscovery: pass 1 and every batch pass),
%   then writes what tools/corpus_counts.py needs to count over:
%     OUTDIR/migrated.jsonl        one final document per line (did2.document.toJSON)
%     OUTDIR/source_outputs.json   result.source_outputs (v1 source -> output ids)
%     OUTDIR/v1_files.json         the v1 file names in input order (input_index)
%     OUTDIR/corpus_dir.txt        the folder the v1 files were read from
%   Decided by Jess Haley 2026-11-10 [two corpus counts]: run and report only.
if ~isfolder(outDir); mkdir(outDir); end
url = sprintf('https://ndi-programming-development.s3.us-east-1.amazonaws.com/%s.zip', corpusName);
% COUNTS_CORPUS_DIR: a local folder of v1 *.json (a shard of whole sessions,
% tools/shard_corpus.py) instead of the download.
[corpusDir, result] = did2.unittest.helpers.runCorpusDiscovery(tc, corpusName, url, corpusName, ...
    'AssertNoOrphans', false, 'CorpusDir', getenv('COUNTS_CORPUS_DIR'));
fprintf('COUNTS-DUMP corpus %s: corpusDir %s; migrated %d; quarantine %d; sources %d\n', ...
    corpusName, corpusDir, numel(result.migrated), numel(result.quarantine), ...
    numel(result.source_outputs));
% Soph tuning check (branch claude/soph-tuning-check-1111): every quarantine
% reason, by class, not only the top 15 runCorpusDiscovery prints.
try
    R = did2.unittest.helpers.topQuarantineReasons(result.quarantine);
    fprintf('SOPH-CHECK quarantine: %d entr(ies), %d distinct (class, reason)\n', ...
        numel(result.quarantine), numel(R));
    for k = 1:numel(R)
        fprintf('SOPH-CHECK  %6d  [%s] %s\n', R(k).count, R(k).class_name, R(k).reason);
    end
    writeText(fullfile(outDir, 'quarantine_reasons.json'), jsonencode(R));
catch e
    fprintf('SOPH-CHECK quarantine tally NOT printed: %s\n', e.message);
end
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
writeText(fullfile(outDir, 'v1_files.json'), jsonencode({files.name}));
writeText(fullfile(outDir, 'corpus_dir.txt'), corpusDir);
writeText(fullfile(outDir, 'source_outputs.json'), jsonencode(result.source_outputs));
% Counts 3 and 4 (Jess Haley, 2026-11-10, extending [two corpus counts]): the
% carries, as the run's migration report holds them.
if isfield(result, 'migration_report')
    writeText(fullfile(outDir, 'migration_report_pass1.json'), jsonencode(result.migration_report));
    fprintf('COUNTS-DUMP pass-1 migration report: %d carried_as_v1 entr(ies)\n', ...
        numel(result.migration_report.carried_as_v1));
else
    fprintf('COUNTS-DUMP result has no migration_report field\n');
end
try
    fin = did2.convert.migrationReport('collect', result.migrated);
    writeText(fullfile(outDir, 'migration_report_final.json'), jsonencode(fin));
    fprintf('COUNTS-DUMP final-batch migration report (collect now): %d carried_as_v1 entr(ies)\n', ...
        numel(fin.carried_as_v1));
catch e
    fprintf('COUNTS-DUMP final-batch migration report NOT collected: %s\n', e.message);
end
if isfield(result, 'summary') && isfield(result.summary, 'migration_notes')
    try
        writeText(fullfile(outDir, 'migration_notes.json'), jsonencode(result.summary.migration_notes));
    catch e
        fprintf('COUNTS-DUMP migration_notes NOT written: %s\n', e.message);
    end
end
fid = fopen(fullfile(outDir, 'migrated.jsonl'), 'w', 'n', 'UTF-8');
nFail = 0;
for k = 1:numel(result.migrated)
    d = result.migrated{k};
    try
        t = d.toJSON();
    catch e
        nFail = nFail + 1;
        t = jsonencode(d.toStruct(), 'ConvertInfAndNaN', false);
        if nFail <= 5
            fprintf('COUNTS-DUMP toJSON fell back to jsonencode: %s\n', e.message);
        end
    end
    t = strrep(t, newline, ' ');
    fprintf(fid, '%s\n', t);
end
fclose(fid);
fprintf('COUNTS-DUMP wrote %d migrated document(s) (%d via jsonencode fallback) to %s\n', ...
    numel(result.migrated), nFail, outDir);
end

function writeText(p, t)
fid = fopen(p, 'w', 'n', 'UTF-8'); fprintf(fid, '%s', t); fclose(fid);
end
