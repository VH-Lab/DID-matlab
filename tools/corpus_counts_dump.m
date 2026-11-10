function corpus_counts_dump(corpusName, outDir)
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
tc = matlab.unittest.TestCase.forInteractiveUse;
[corpusDir, result] = did2.unittest.helpers.runCorpusDiscovery(tc, corpusName, url, corpusName, ...
    'AssertNoOrphans', false);
fprintf('COUNTS-DUMP corpus %s: corpusDir %s; migrated %d; quarantine %d; sources %d\n', ...
    corpusName, corpusDir, numel(result.migrated), numel(result.quarantine), ...
    numel(result.source_outputs));
files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
writeText(fullfile(outDir, 'v1_files.json'), jsonencode({files.name}));
writeText(fullfile(outDir, 'corpus_dir.txt'), corpusDir);
writeText(fullfile(outDir, 'source_outputs.json'), jsonencode(result.source_outputs));
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
