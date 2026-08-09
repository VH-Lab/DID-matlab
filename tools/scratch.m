%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   TO USE IT: replace the body below with whatever you need to SEE, then push.
%   A push touching this file runs it and prints to the workflow log; it gates
%   nothing and exits 0 even on a throw, so an error reports its identifier,
%   message and stack rather than a bare red X.
%
%   IT KEEPS PAYING FOR ITSELF.
%     probe 2/3  #63's family counter was reverted once as "undiagnosable" on
%                the strength of a pass/fail result. Probe 2 showed the
%                detection logic was RIGHT; probe 3 showed the counts were
%                computed and then never assigned to the report.
%     probe 5    printed MATLAB's empty shapes instead of guessing at them:
%                unique([]) is 0-by-1, so `for n = unique([])` iterates ONCE.
%                That is where a phantom row in the corpus census came from.
%
%   PROBE 6 (current): testCorpusPRED just gained a writeCorpusReport call so
%   the PRED gate stops being invisible to the census. There is no local MATLAB
%   here and the corpus workflow costs an hour, so CHECK rather than assume:
%   does the edited file parse, and do the two helpers it now calls resolve?

addpath(genpath('src'));
addpath(genpath('tests'));

fprintf('--- probe 6: PRED census wiring ---\n');

f = fullfile('tests', '+did2', '+unittest', 'testCorpusPRED.m');
fprintf('checkcode %s:\n', f);
msgs = checkcode(f, '-struct');
fprintf('  %d message(s)\n', numel(msgs));
for k = 1:numel(msgs)
    fprintf('  line %4d: %s\n', msgs(k).line, msgs(k).message);
end

for name = {'did2.unittest.helpers.topQuarantineReasons', ...
            'did2.unittest.helpers.writeCorpusReport', ...
            'did2.validate.sourceCensus'}
    fprintf('%-48s -> %s\n', name{1}, which(name{1}));
end

% The report writer's own round trip, on a synthetic result of the shape
% v1_to_v2 returns. If this writes and re-reads, the PRED call site will too.
tmp = tempname();
mkdir(tmp);
old = cd(tmp);
restore = onCleanup(@() cd(old));
result = struct();
result.summary = struct('total', 3, 'migrated_count', 4, ...
    'quarantine_count', 0, 'by_class', struct('subject', 3));
result.quarantine = struct('class_name', {}, 'reason', {});
result.source_census = struct('total_docs', 3, 'skipped_docs', 0);
reasons = did2.unittest.helpers.topQuarantineReasons(result.quarantine);
p = did2.unittest.helpers.writeCorpusReport('PROBE', result, reasons);
fprintf('wrote %s (%d bytes)\n', p, numel(fileread(p)));
disp(jsondecode(fileread(p)));
