function report = mutationProbe(subs, testFiles)
%MUTATIONPROBE Prove a test catches the bug it was written for, ON THE RUNNER.
%
%   MUTATIONPROBE(SUBS, TESTFILES) applies one-line substitutions to the
%   CHECKED-OUT COPY on the CI runner, runs the named test files, prints the
%   verdict, and restores every file from memory. The runner's checkout is
%   disposable, so nothing mutated is ever committed, pushed, or seen by another
%   session.
%
%   SUBS       struct array with fields `file`, `old`, `new` (all char).
%   TESTFILES  char or cellstr of test files to run under the mutation.
%
%   WHY THIS EXISTS, AND WHY IT IS NOT A SCRATCH BRANCH.
%
%   A test written from the same premise as the code cannot catch the code, so
%   this project requires every new test to be shown FAILING against the bug it
%   describes. For Python that is a local loop: copy the file aside, mutate,
%   run, restore, `md5sum -c`. For MATLAB it was impossible -- these containers
%   have no MATLAB, so the only way to execute anything is to push, and pushing
%   a mutation to the shared branch is recorded three times over in DID-schema
%   `V_eta_OPEN_WORK.md` rows 86(f), 88(b), 90 and 91 as costing:
%
%     * a container restart leaving the mutation as the file's last word,
%     * another session stacking a commit on the broken tip,
%     * and -- after the revert had landed and the tip was clean -- code
%       scanning ingesting the SARIF from the mutated run and returning alerts
%       against the real file, costing a full investigation each time.
%
%   A throwaway branch was the obvious alternative and it is worse: `git push
%   --delete` returns HTTP 403 with these credentials, so every such branch is
%   permanent litter (17+ are already stranded across three repos), and code
%   scanning reads it just the same.
%
%   The disposable thing was always the RUNNER, not the branch. The mutation
%   lives in `tools/scratch.m` -- an instruction to substitute -- and never in
%   the source file, so the branch only ever carries working code while the
%   mutated tree exists for ninety seconds inside one job and is destroyed with
%   it. `.github/workflows/matlab-scratch.yml` already provides that job: it
%   runs on a push touching `tools/scratch.m`, gates nothing, and exits 0 even
%   on a throw so an error reports its text rather than a bare red X.
%
%   USAGE, from tools/scratch.m:
%
%       subs = struct( ...
%           'file', 'src/did/+did2/+convert/epochIndex.m', ...
%           'old',  'k = sprintf(''%d:%s|%s'', numel(sessionId), sessionId, localIdentifier);', ...
%           'new',  'k = localIdentifier;');
%       tools.mutationProbe(subs, 'tests/+did2/+unittest/testEpochIndex.m');
%
%   READ THE RESULT THE RIGHT WAY ROUND. A mutation that leaves the suite GREEN
%   is the finding: it means no test covers the behaviour that was broken. A
%   mutation that turns it RED tells you which tests are load-bearing, and the
%   named failures are the evidence that they are.
%
%   EVERY SUBSTITUTION MUST MATCH EXACTLY ONCE. A pattern matching zero times is
%   not the mutation you think you applied, and one matching twice mutates a
%   site you did not read. Either aborts the probe before a single test runs,
%   because a green suite under a mutation that never applied is the most
%   convincing wrong answer this harness could produce.

arguments
    subs (1,:) struct
    testFiles
end

if ischar(testFiles) || isstring(testFiles)
    testFiles = cellstr(testFiles);
end

% DENOMINATOR FIRST AND UNCONDITIONALLY (operating rule 5), before any file is
% touched, so a probe that aborts still says what it was going to do.
fprintf('\n=============== MUTATION PROBE ===============\n');
fprintf('  DENOMINATOR: %d substitution(s) requested, %d test file(s) named\n', ...
    numel(subs), numel(testFiles));
for k = 1:numel(subs)
    fprintf('    [%d] %s\n', k, subs(k).file);
end

originals = cell(1, numel(subs));
applied = false(1, numel(subs));

% ---- apply, refusing anything ambiguous -------------------------------------
for k = 1:numel(subs)
    f = subs(k).file;
    if ~isfile(f)
        error('did2:mutationProbe:noSuchFile', ...
            'substitution %d names %s, which does not exist', k, f);
    end
    txt = fileread(f);
    originals{k} = txt;
    n = numel(strfind(txt, subs(k).old));
    if n ~= 1
        restoreAll(subs, originals, applied);
        error('did2:mutationProbe:patternNotUnique', ...
            ['substitution %d matched %d time(s) in %s, expected exactly 1. ' ...
             'A pattern that matches 0 times means the mutation never ' ...
             'applied and a green suite proves nothing; 2 or more means it ' ...
             'also changed a site you did not read.'], k, n, f);
    end
    fid = fopen(f, 'w');
    fwrite(fid, strrep(txt, subs(k).old, subs(k).new));
    fclose(fid);
    applied(k) = true;
    fprintf('  APPLIED [%d] %s\n', k, f);
end

% ---- run --------------------------------------------------------------------
nRun = 0; nFailed = 0; failedNames = {};
try
    import matlab.unittest.TestSuite;
    import matlab.unittest.TestRunner;
    suite = TestSuite.empty;
    for k = 1:numel(testFiles)
        suite = [suite, TestSuite.fromFile(testFiles{k})]; %#ok<AGROW>
    end
    results = TestRunner.withTextOutput.run(suite);
    nRun = numel(results);
    nFailed = sum([results.Failed]);
    failedNames = {results([results.Failed]).Name};
catch runErr
    % A throw here is a fact about the mutation, not a reason to leave the tree
    % dirty. Restore first, report second.
    restoreAll(subs, originals, applied);
    fprintf(2, '  THE RUN ITSELF THREW: %s\n  %s\n', ...
        runErr.identifier, runErr.message);
    report = struct('ran', false, 'n_run', 0, 'n_failed', 0, ...
        'failed', {{}}, 'restored', true);
    return;
end

restoreAll(subs, originals, applied);

fprintf('\n  UNDER THE MUTATION: %d run, %d FAILED\n', nRun, nFailed);
for k = 1:numel(failedNames)
    fprintf('    RED  %s\n', failedNames{k});
end
if nFailed == 0
    fprintf(['  *** THE SUITE STAYED GREEN. That is the finding: no test in\n' ...
             '  *** the named file(s) covers the behaviour this mutation\n' ...
             '  *** broke. It is NOT a pass.\n']);
end
fprintf('  files restored: %d of %d\n', sum(applied), numel(subs));
fprintf('==============================================\n\n');

report = struct('ran', true, 'n_run', nRun, 'n_failed', nFailed, ...
    'failed', {failedNames}, 'restored', true);
end

% -----------------------------------------------------------------------------
function restoreAll(subs, originals, applied)
%RESTOREALL Put every mutated file back, byte for byte, from memory.
%   Belt and braces: the runner's checkout is thrown away regardless, but a
%   probe that leaves the tree mutated would make a SECOND probe in the same
%   job read a file nobody wrote.
for k = 1:numel(subs)
    if ~applied(k) || isempty(originals{k}); continue; end
    fid = fopen(subs(k).file, 'w');
    fwrite(fid, originals{k});
    fclose(fid);
end
end
