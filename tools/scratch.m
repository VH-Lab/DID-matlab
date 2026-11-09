%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 13b: WHERE THE TIME GOES (after the plain loop, e312a890) IN testCorpusB ON DID-matlab #428. Its
%   Test code run 42687589754 took 40 min for B (5 min on V2) and 100 min for
%   Dab (12 min), with every source clean. This runs testCorpusB under the
%   profiler and prints the 40 functions with the most total time and the 40
%   with the most self time, with their call counts.

import matlab.unittest.TestSuite;
import matlab.unittest.TestRunner;
suite = TestSuite.fromFile(fullfile('tests', '+did2', '+unittest', 'testCorpusB.m'));
profile clear;
profile on;
t0 = tic;
results = TestRunner.withTextOutput.run(suite);
profile off;
fprintf('\n==== PROBE 13 ====\n  testCorpusB: %d test(s), %d failed, %.1f s\n', ...
    numel(results), sum([results.Failed]), toc(t0));
info = profile('info');
ft = info.FunctionTable;
[~, o] = sort([ft.TotalTime], 'descend');
fprintf('  -- by total time --\n');
for k = o(1:min(40, numel(o)))
    fprintf('  %9.1f s total %9.1f s self %10d calls  %s\n', ft(k).TotalTime, ...
        ft(k).TotalTime - sum([ft(k).Children.TotalTime]), ft(k).NumCalls, ft(k).FunctionName);
end
self = arrayfun(@(f) f.TotalTime - sum([f.Children.TotalTime]), ft);
[~, o] = sort(self, 'descend');
fprintf('  -- by self time --\n');
for k = o(1:min(40, numel(o)))
    fprintf('  %9.1f s self %10d calls  %s\n', self(k), ft(k).NumCalls, ft(k).FunctionName);
end
