function tests = testReportVerdict
%TESTREPORTVERDICT The verdict block is the last thing a red run prints.
%
%   STATUS: written without local execution -- there is no MATLAB and no
%   Octave in the container these were authored in
%   (`command -v matlab octave octave-cli` returns nothing). CI is the first
%   execution. Do not read a green badge on the commit that introduced this
%   file as "the author ran it".
%
%   `did2.unittest.helpers.reportVerdict` exists because a red run used to end
%   with `1 test(s) failed` and no name, so every red run cost a full log
%   download and a scan of ~885 result rows. These tests pin the two
%   properties that make the log tail sufficient on its own:
%
%     * the failing test's NAME is printed, not just a count;
%     * a suite that selected NOTHING says so, because `sum([])` is 0 and the
%       old `assert(nFailed == 0)` was therefore true for an empty suite.
%
%   The helper is duck-typed on Name/Passed/Failed/Incomplete so these tests
%   can manufacture a failure without running a suite that really fails.

tests = functiontests(localfunctions);
end

% ====================== fixtures ======================================

function r = mkResults(names, failed, incomplete)
%MKRESULTS A struct array shaped like matlab.unittest.TestResult.
%   PASSED is derived rather than passed in, so a result cannot be built that
%   claims to have both passed and failed -- the fixture cannot express the
%   state the code is being asked to report on correctly.
if nargin < 3; incomplete = false(size(names)); end
r = struct('Name', {}, 'Passed', {}, 'Failed', {}, 'Incomplete', {});
for k = 1:numel(names)
    r(k).Name       = names{k};
    r(k).Failed     = logical(failed(k));
    r(k).Incomplete = logical(incomplete(k));
    r(k).Passed     = ~r(k).Failed && ~r(k).Incomplete;
end
end

% ====================== the denominator ===============================

function testTheDenominatorIsPrintedEvenWhenEverythingPassed(testCase)
% Rule 5: FIRST and UNCONDITIONALLY. A green run that prints nothing is
% indistinguishable from a green run that measured nothing.
r = mkResults({'a/one', 'a/two'}, [false false]);
out = evalc('did2.unittest.helpers.reportVerdict(r, ''green'');');
testCase.verifyTrue(contains(out, 'tests run'), ...
    'the denominator must be printed on the all-passed path too');
testCase.verifyTrue(contains(out, '2'), 'the denominator must carry the count');
end

function testTheCountsAreTheOnesReturned(testCase)
r = mkResults({'a/one', 'a/two', 'a/three'}, [false true false], ...
    [false false true]);
% `v` is predeclared so evalc ASSIGNS to an existing name rather than having
% to create one in a function workspace.
v = [];  %#ok<NASGU>
evalc('v = did2.unittest.helpers.reportVerdict(r, ''mixed'');');
testCase.verifyEqual(v.n_run, 3);
testCase.verifyEqual(v.n_failed, 1);
testCase.verifyEqual(v.n_incomplete, 1);
testCase.verifyEqual(v.n_passed, 1, ...
    'passed must exclude BOTH the failure and the incomplete');
end

% ====================== the name, which is the point ==================

function testTheFailingTestsNameIsPrinted(testCase)
% THE REASON THIS HELPER EXISTS. Without the name, a red run's log tail says
% only how many failed, and the name is a thousand rows up in table(results).
r = mkResults({'pkg.testA/passes', 'pkg.testB/theOneThatBroke'}, ...
    [false true]);
out = evalc('did2.unittest.helpers.reportVerdict(r, ''red'');');
testCase.verifyTrue(contains(out, 'pkg.testB/theOneThatBroke'), ...
    'the failing name must appear in the verdict block');
end

function testAPassingTestsNameIsNotPrintedInTheFailedList(testCase)
% Discrimination: a block that listed every name would "contain the failing
% name" while telling you nothing, and would pass the test above.
r = mkResults({'pkg.testA/passes', 'pkg.testB/theOneThatBroke'}, ...
    [false true]);
out = evalc('did2.unittest.helpers.reportVerdict(r, ''red'');');
tail = extractAfter(out, 'FAILED, by name');
testCase.verifyFalse(contains(tail, 'pkg.testA/passes'), ...
    'the failed list must not name tests that passed');
end

function testIncompleteIsListedSeparatelyFromFailed(testCase)
% A test that never ran to a verdict is a different fact from one that ran and
% disagreed. Folding them together is how a skipped gate reads as a passing one.
r = mkResults({'pkg.t/didNotRun'}, [false], [true]);
out = evalc('did2.unittest.helpers.reportVerdict(r, ''inc'');');
testCase.verifyTrue(contains(out, 'INCOMPLETE'), ...
    'incomplete results must be named under their own heading');
testCase.verifyFalse(contains(out, 'FAILED, by name'), ...
    'an incomplete test must not be reported as a failure');
end

% ====================== nothing ran is not a pass =====================

function testAnEmptySuiteSaysSoRatherThanPrintingAQuietZero(testCase)
% `sum([])` is 0, so `assert(nFailed == 0)` is TRUE for a suite that selected
% no tests. Every workflow filters its suite by NAME, so an upstream rename
% could empty the selection and the gate would go green having run nothing.
r = mkResults({}, []);
out = evalc('did2.unittest.helpers.reportVerdict(r, ''empty'');');
testCase.verifyTrue(contains(out, 'NOTHING RAN'), ...
    'an empty suite must announce itself, not report a clean zero');
end

function testAnEmptySuiteReportsZeroRunSoTheCallerCanAssertOnIt(testCase)
r = mkResults({}, []);
v = [];  %#ok<NASGU>
evalc('v = did2.unittest.helpers.reportVerdict(r, ''empty'');');
testCase.verifyEqual(v.n_run, 0);
testCase.verifyEqual(v.n_failed, 0, ...
    'zero failures on an empty suite is exactly the trap -- n_run is the guard');
end
