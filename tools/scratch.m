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
%     probe 5    printed MATLAB's empty shapes instead of guessing at them.
%     probe 6    checked the testCorpusPRED census wiring in 2 minutes instead
%                of assuming it across a 70-minute corpus run.
%
%   PROBE 7 (current): the image_stack guard turned two CI jobs red with
%   "2 test(s) failed" and no visible diagnostic -- the results table is
%   alphabetical and the failures scrolled past the log tail. Print the actual
%   failure text rather than guessing at it.

addpath(genpath('src'));
addpath(genpath('tests'));

import matlab.unittest.TestSuite;
import matlab.unittest.TestRunner;

fprintf('--- probe 7: image_stack guard failures ---\n');
fprintf('DID_SCHEMA_PATH = %s\n', getenv('DID_SCHEMA_PATH'));

suite = TestSuite.fromFile(fullfile('tests', '+did2', '+unittest', 'testMigratorsJ.m'));
names = string({suite.Name});
sel = contains(names, 'ImageStack');
fprintf('image_stack tests in the suite: %d\n', sum(sel));
for n = names(sel); fprintf('   %s\n', n); end

r = TestRunner.withNoPlugins().run(suite(sel));
for k = 1:numel(r)
    fprintf('\n=== %s : %s ===\n', r(k).Name, string(matlab.lang.OnOffSwitchState(r(k).Passed)));
    if r(k).Passed; continue; end
    d = r(k).Details;
    if isfield(d, 'DiagnosticRecord')
        for j = 1:numel(d.DiagnosticRecord)
            rec = d.DiagnosticRecord(j);
            fprintf('  event      : %s\n', rec.Event);
            if ~isempty(rec.TestDiagnosticResult)
                fprintf('  test diag  : %s\n', strjoin(cellstr(rec.TestDiagnosticResult), ' | '));
            end
            if ~isempty(rec.FrameworkDiagnosticResult)
                txt = strjoin(cellstr(rec.FrameworkDiagnosticResult), newline);
                fprintf('  framework  : %s\n', txt);
            end
            if isprop(rec, 'Report') || isfield(rec, 'Report')
                fprintf('  report     :\n%s\n', rec.Report);
            end
        end
    end
end
