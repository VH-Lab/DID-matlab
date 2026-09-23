function verdict = reportVerdict(results, label)
%REPORTVERDICT Print a readable verdict LAST, after the results table.
%   VERDICT = REPORTVERDICT(RESULTS, LABEL) prints a denominator and then the
%   NAME of every test that failed, and returns
%   `struct('n_run', ..., 'n_passed', ..., 'n_failed', ..., 'n_incomplete', ...)`.
%
%   ---------------------------------------------------------------------
%   WHY THIS EXISTS
%   ---------------------------------------------------------------------
%   Every workflow ended its MATLAB block with
%
%       disp(table(results));
%       nFailed = sum([results.Failed]);
%       assert(nFailed == 0, sprintf("%d test(s) failed", nFailed));
%
%   so a red run's LAST line is `1 test(s) failed` -- a count with no name.
%   The name is in `table(results)`, but that table is one row per test and
%   the failing row is wherever the alphabet put it. Finding the single
%   failure in run 31463987352 meant pulling the whole 2,875-line log and
%   scanning 885 rows for the one that did not read `true false false`.
%
%   That is a count without a denominator wearing different clothes, and this
%   repository has paid for that shape twice already: `silentLoss` printing
%   "0 empty edges" while reading nothing, and `census_digest.py` printing
%   NO CORPUS REPORTS FOUND and then exiting 0. A red run you cannot read
%   from the log tail costs a round trip every single time.
%
%   ---------------------------------------------------------------------
%   NOTHING RAN IS NOT A PASS
%   ---------------------------------------------------------------------
%   `assert(nFailed == 0)` is TRUE when the suite selected zero tests --
%   `sum([])` is 0. Every workflow here filters its suite by name
%   (`~contains(names, "testCorpus")`), so a rename upstream could empty the
%   selection and the gate would go green having run nothing. `n_run` is
%   reported first and unconditionally for that reason, and the caller is
%   expected to assert on it.
%
%   ---------------------------------------------------------------------
%   DUCK-TYPED ON PURPOSE
%   ---------------------------------------------------------------------
%   RESULTS may be a `matlab.unittest.TestResult` array or any struct array
%   carrying Name/Passed/Failed/Incomplete. That is what lets this be tested
%   without running a real suite to manufacture a failure.

if nargin < 2 || isempty(label); label = 'suite'; end
label = char(label);

verdict = struct('n_run', 0, 'n_passed', 0, 'n_failed', 0, 'n_incomplete', 0);
verdict.n_run = numel(results);

if verdict.n_run > 0
    verdict.n_passed     = sum([results.Passed]);
    verdict.n_failed     = sum([results.Failed]);
    verdict.n_incomplete = sum([results.Incomplete]);
end

% DENOMINATOR FIRST AND UNCONDITIONALLY (operating rule 5). Printed even when
% everything passed, so "green" and "green having run nothing" are different
% shapes in the log rather than the same silence.
fprintf('\n================ VERDICT: %s ================\n', label);
fprintf('  tests run     %6d\n', verdict.n_run);
fprintf('  passed        %6d\n', verdict.n_passed);
fprintf('  FAILED        %6d\n', verdict.n_failed);
fprintf('  incomplete    %6d\n', verdict.n_incomplete);

if verdict.n_run == 0
    fprintf(['\n  NOTHING RAN. A suite that selected no tests is not a pass --\n' ...
             '  it is a failure of the SELECTION. Check the suite filter before\n' ...
             '  reading this run as green.\n']);
end

if verdict.n_failed > 0
    fprintf('\n  FAILED, by name (%d):\n', verdict.n_failed);
    printNames(results, [results.Failed]);
end

% Incomplete is reported separately from failed and is NOT folded into it: a
% test that never ran is a different fact from one that ran and disagreed, and
% collapsing them is how a skipped gate reads as a passing one.
if verdict.n_incomplete > 0
    fprintf('\n  INCOMPLETE, by name (%d) -- these did NOT run to a verdict:\n', ...
        verdict.n_incomplete);
    printNames(results, [results.Incomplete]);
end

fprintf('================ end verdict: %s ================\n\n', label);
end

function printNames(results, mask)
%PRINTNAMES One line per selected result, in suite order.
idx = find(mask);
for k = 1:numel(idx)
    fprintf('    %s\n', char(results(idx(k)).Name));
end
end
