function tests = testBatchPassWiring
%TESTBATCHPASSWIRING Every batch post-pass is called from every call site.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   nothing in this file has been run. test-migrators-quick.yml is the first
%   thing that will have an opinion.
%
%   NEW FILE, deliberately: testMigratorsJ.m is owned by another session and is
%   not touched.
%
%   ---------------------------------------------------------------------
%   WHAT THIS FILE IS FOR
%   ---------------------------------------------------------------------
%   `did2.convert.resolveSessionAnchors` -- a fold over 127,719 documents --
%   was written, reviewed, given its own unit tests, and then called from
%   NOTHING for a day. No test failed, no corpus report said so, and no log
%   line was missing, because a pass that is never called produces no output to
%   be missing. `did2.convert.epochMint` was the near miss in the other
%   direction: wired everywhere, persisted into every corpus report, and not
%   rendered by the digest, so the number existed and no one could see it.
%
%   Both are the same defect -- WORK THAT LOOKS DONE BECAUSE NOTHING MEASURES
%   IT -- and neither is catchable by testing the pass itself. So this file
%   tests the WIRING, statically, by reading the call sites as text:
%
%     * every function in +did2/+convert whose first argument is a `result`
%       struct (i.e. a batch post-pass) is named in every DID-side call site;
%     * the guard around the two never-executed passes records a failure
%       loudly instead of swallowing it;
%     * a guarded failure leaves the batch in pass-1 form.
%
%   A STATIC SCAN IS THE POINT, not a shortcut. The alternative -- run each
%   harness and check the pass ran -- needs the corpora, which is the hour this
%   whole exercise exists to protect.
%
%   ---------------------------------------------------------------------
%   THE FOURTH CALL SITE IS IN ANOTHER REPOSITORY
%   ---------------------------------------------------------------------
%   `ndi.migrate.local` is the production second pass and lives in NDI-matlab.
%   It is REPORTED here, never asserted: NDI-matlab is not guaranteed to be
%   checked out beside DID-matlab, and a test that fails on a missing sibling
%   repo is a test people disable. When it is present the matrix prints, with
%   its denominator, so a divergence is visible in the log of the fast gate.
%
%   Run with:  results = runtests('did2.unittest.testBatchPassWiring');

tests = functiontests(localfunctions);
end

% ===================== the wiring matrix ===============================

function [passes, exempt] = batchPasses()
%BATCHPASSES Every batch post-pass in +did2/+convert, found by SIGNATURE.
%   A batch post-pass is a function whose first input is the `result` struct
%   that did2.convert.v1_to_v2 returns. Discovering them by signature rather
%   than from a hand-kept list is deliberate: a hand-kept list is exactly the
%   thing that would have gone stale the day resolveSessionAnchors was added,
%   which is the failure this file exists to catch.
%
%   EXEMPT is the subset whose source carries a header line consisting of the
%   token WIRING-EXEMPT, a colon, and a reason. (Written that way rather than
%   shown verbatim: a comment that spelled the marker out would exempt THIS
%   file's own examples, and a gate that disarms itself in its own
%   documentation is the recurring failure in miniature.)
%
%   Those are excluded from the gate below and PRINTED with their reason. This
%   escape hatch exists because leaving a pass unwired is sometimes RIGHT --
%   resolveSessionAnchors's author deliberately did not wire it, because they
%   could not run it and turning it on red-gates the corpus for everyone if it
%   is wrong. That judgement was correct and must stay available. What must NOT
%   stay available is leaving it unwired SILENTLY: the marker turns an omission
%   into a stated decision with a reason attached, which is the entire
%   difference between the two cases.
convertDir = fullfile(did.toolboxdir(), '+did2', '+convert');
files = dir(fullfile(convertDir, '*.m'));
passes = {};
exempt = struct('name', {}, 'reason', {});
for k = 1:numel(files)
    txt = fileread(fullfile(files(k).folder, files(k).name));
    lines = strsplit(txt, newline);
    if isempty(lines); continue; end
    sig = strtrim(lines{1});
    % `function result = name(result, ...)` or
    % `function [result, report] = name(result, ...)`
    tok = regexp(sig, '^function\s+(?:\[[^\]]*\]|\w+)\s*=\s*(\w+)\s*\(\s*result\b', ...
        'tokens', 'once');
    if isempty(tok); continue; end
    % 'lineanchors' + a required non-space after the colon: the marker must be
    % a comment line of its own with an actual reason on it. A bare mention in
    % running prose does not disarm the gate.
    why = regexp(txt, '^%\s*WIRING-EXEMPT:\s*(\S[^\n\r]*)$', ...
        'tokens', 'once', 'lineanchors');
    if ~isempty(why)
        exempt(end+1) = struct('name', tok{1}, ...
            'reason', strtrim(why{1})); %#ok<AGROW>
        continue;
    end
    passes{end+1} = tok{1}; %#ok<AGROW>
end
passes = sort(passes);
end

function sites = didCallSites()
%DIDCALLSITES The three DID-side harness entry points, as absolute paths.
here = fileparts(mfilename('fullpath'));            % tests/+did2/+unittest
sites = { ...
    'runCorpusDiscovery', fullfile(here, '+helpers', 'runCorpusDiscovery.m'); ...
    'testCorpusPRED',     fullfile(here, 'testCorpusPRED.m'); ...
    'testFixtureCorpus',  fullfile(here, 'testFixtureCorpus.m')};
end

function tf = callsPass(filePath, passName)
%CALLSPASS Does FILEPATH contain a CALL to did2.convert.<PASSNAME>?
%   Matches the qualified name followed by an opening parenthesis, so a mention
%   in a comment ("see also did2.convert.epochMint") does NOT count as a call.
%   That distinction matters: this package is heavily commented, and a test
%   that accepted prose would have passed all day yesterday on a pass nothing
%   called.
txt = fileread(filePath);
tf = ~isempty(regexp(txt, ...
    ['did2\.convert\.' regexptranslate('escape', passName) '\s*\('], 'once'));
end

function testEveryBatchPassIsCalledFromEveryDidSideCallSite(testCase)
% THE GATE. Denominator printed first and unconditionally: how many passes were
% discovered and how many call sites were read. A scan that found no passes
% must not read as "every pass is wired".
[passes, exempt] = batchPasses();
sites = didCallSites();
fprintf(['\n--- batch-pass wiring: %d pass(es) discovered in +did2/+convert ' ...
         '(%d gated, %d exempt), %d DID-side call site(s) read ---\n'], ...
    numel(passes) + numel(exempt), numel(passes), numel(exempt), ...
    size(sites, 1));
for e = 1:numel(exempt)
    fprintf('  %-26s EXEMPT FROM THE WIRING GATE -- reason: %s\n', ...
        exempt(e).name, exempt(e).reason);
end

verifyGreaterThanOrEqual(testCase, numel(passes) + numel(exempt), 4, ...
    ['fewer than 4 batch post-passes discovered -- the signature scan is ' ...
     'broken, and a broken scan reports perfect coverage']);

missing = {};
for p = 1:numel(passes)
    row = sprintf('  %-26s', passes{p});
    for s = 1:size(sites, 1)
        if callsPass(sites{s, 2}, passes{p})
            row = [row sprintf(' %-20s', 'CALLED')]; %#ok<AGROW>
        else
            row = [row sprintf(' %-20s', '-- NOT CALLED --')]; %#ok<AGROW>
            missing{end+1} = sprintf('%s is not called from %s', ...
                passes{p}, sites{s, 1}); %#ok<AGROW>
        end
    end
    fprintf('%s\n', row);
end
fprintf('  (columns: %s)\n', strjoin(sites(:, 1)', ', '));

verifyEmpty(testCase, missing, sprintf( ...
    ['a batch post-pass is not wired into every DID-side call site. A pass ' ...
     'wired into some sites and not others is worse than one wired nowhere: ' ...
     'the corpus goes green while another path does something else.\n  %s'], ...
    strjoin(missing, sprintf('\n  '))));
end

function testProductionCallSiteIsReportedNotAsserted(testCase)
% ndi.migrate.local, REPORT ONLY. Two of the four passes are ABSENT there
% today, and the two absences are NOT the same fact:
%
%   resolveDeferredBaths    NDI runs its own PRECISE replacement --
%                           ndi.migrate.internal.stimulusBathToBath names
%                           did2.convert.resolveDeferredBaths.makeBathVeta as
%                           the coarse version it supersedes (that file's own
%                           header, line 90). Deliberate.
%   resolveDatasetEntities  We did not find an NDI-side equivalent. THAT IS AN
%                           ABSENCE, NOT A FINDING -- it is reported here for a
%                           human to check, not concluded. If it is genuinely
%                           missing, the dataset dedup that every DID corpus
%                           run performs never happens in production.
%
% Asserting here would fail the fast gate on a sibling-repo layout, so this
% test only ever prints -- but it prints EVERY run, with the denominator, so a
% divergence cannot go unseen the way the unwired fold did.
repoRoot = fileparts(fileparts(did.toolboxdir()));   % <root>/src/did -> <root>
localPath = fullfile(fileparts(repoRoot), 'NDI-matlab', 'src', 'ndi', ...
    '+ndi', '+migrate', 'local.m');
passes = batchPasses();
fprintf('\n--- production call site (ndi.migrate.local), REPORT ONLY ---\n');
if ~isfile(localPath)
    fprintf(['  NDI-matlab not found at %s -- %d pass(es) UNCHECKED against ' ...
             'production.\n'], localPath, numel(passes));
    fprintf(['  This is "not looked at", NOT "wired correctly". Do not read ' ...
             'a silent gate as agreement.\n']);
    verifyTrue(testCase, true);   % report-only by construction
    return;
end
fprintf('  read: %s  (%d pass(es) checked)\n', localPath, numel(passes));
for p = 1:numel(passes)
    if callsPass(localPath, passes{p})
        fprintf('  %-26s CALLED\n', passes{p});
    else
        fprintf('  %-26s -- NOT CALLED -- (see this test''s header)\n', ...
            passes{p});
    end
end
verifyTrue(testCase, true);
end

% ===================== the guard =======================================
%
% Stand-in passes, written as named local functions rather than anonymous
% handles so the shapes stay explicit: one that behaves, one that throws, and
% one that returns cleanly WITHOUT attaching a report -- the third being the
% shape that looks like success and has measured nothing.

function r = okPass(r)
r.fake_report = struct('ran', true, 'n', 7);
end

function r = throwingPass(r) %#ok<INUSD>
error('did2:test:boom', 'deliberate failure');
end

function r = silentPass(r)
% Returns unchanged, attaching no report. Operating Rule 5's failure case.
end


function testGuardPassesTheResultThroughUnchangedOnSuccess(testCase)
r = struct('migrated', {{}}, 'quarantine', [], 'summary', struct('total', 0));
out = did2.unittest.helpers.runBatchPass(r, 'fake.pass', 'fake_report', ...
    @okPass);
verifyTrue(testCase, out.fake_report.ran);
verifyEqual(testCase, out.fake_report.n, 7);
% NOTHING extra is added on the success path: `pass_failed` must be ABSENT, so
% batchPassFailure's answer of '' is a read of the report rather than of a
% sentinel somebody could forget to clear.
verifyFalse(testCase, isfield(out.fake_report, 'pass_failed'));
verifyEmpty(testCase, ...
    did2.unittest.helpers.batchPassFailure(out, 'fake_report'));
end

function testGuardRecordsAThrowInsteadOfSwallowingIt(testCase)
r = struct('migrated', {{'a', 'b'}}, 'summary', struct('total', 2));
out = did2.unittest.helpers.runBatchPass(r, 'fake.pass', 'fake_report', ...
    @throwingPass);
% 1. The failure is ON the result, not lost.
verifyTrue(testCase, isfield(out, 'fake_report'));
verifyEqual(testCase, out.fake_report.pass_failed, 'deliberate failure');
verifyEqual(testCase, out.fake_report.pass_failed_identifier, 'did2:test:boom');
verifyFalse(testCase, out.fake_report.ran);
% 2. The batch is in PASS-1 FORM: untouched, not half-converted.
verifyEqual(testCase, out.migrated, {'a', 'b'});
verifyEqual(testCase, out.summary.total, 2);
% 3. NO zeroed counters. A failed pass that reported `anchors_folded: 0` would
%    be indistinguishable from a clean run that found nothing to fold, which is
%    the all-zeros-reads-as-clean failure these operating rules exist for.
verifyFalse(testCase, isfield(out.fake_report, 'anchors_folded'));
verifyFalse(testCase, isfield(out.fake_report, 'documents_inspected'));
% 4. The hard gates can see it.
verifyEqual(testCase, ...
    did2.unittest.helpers.batchPassFailure(out, 'fake_report'), ...
    'deliberate failure');
end

function testGuardTreatsAMissingReportAsAFailure(testCase)
% A pass that returns without attaching its report has produced no denominator.
% Operating Rule 5: that is not a clean run, it is an unmeasured one.
r = struct('migrated', {{}});
out = did2.unittest.helpers.runBatchPass(r, 'fake.pass', 'fake_report', ...
    @silentPass);
verifyTrue(testCase, isfield(out, 'fake_report'));
verifyNotEmpty(testCase, out.fake_report.pass_failed);
verifyEqual(testCase, out.fake_report.pass_failed_identifier, ...
    'did2:test:batchPassReportMissing');
verifyNotEmpty(testCase, ...
    did2.unittest.helpers.batchPassFailure(out, 'fake_report'));
end

% NOT TESTED HERE, AND SAID SO RATHER THAN LEFT AS A GAP: the empty-message
% branch of runBatchPass/failureReport. The gates detect a failure by finding a
% NON-EMPTY `pass_failed`, so a throw carrying an empty message would read as
% success everywhere downstream; runBatchPass substitutes a message for exactly
% that case. Writing a test for it needs a way to PRODUCE such a throw, and both
% candidates rest on MATLAB behaviour that cannot be checked in this container:
% `error(id, '')` is documented NOT to throw at all (so it would exercise the
% "output argument not assigned" error instead, with a non-empty message), and
% `throw(MException(id, ''))` depends on the constructor accepting an empty
% message. A test written on an unverified assumption about the harness is worse
% than no test -- it is the fixture-built-from-our-own-schema mistake. The
% defensive code stays because it costs nothing; the claim that it works is
% UNVERIFIED and belongs to whoever first runs this file.

function testBatchPassFailureIsSilentAboutRunsItDidNotObserve(testCase)
% An ABSENT field means the result never went through the guard (a bare call,
% e.g. testFixtureCorpus) -- and a bare call that failed already threw.
% Reporting absence as failure would be the absence-as-evidence error.
verifyEmpty(testCase, did2.unittest.helpers.batchPassFailure( ...
    struct('migrated', {{}}), 'fake_report'));
% A report with no `pass_failed` key at all (e.g. one written by an older
% build) is likewise not a failure.
verifyEmpty(testCase, did2.unittest.helpers.batchPassFailure( ...
    struct('fake_report', struct('ran', true)), 'fake_report'));
end

% ===================== the passes are no-ops off-target =================

function testBothNewPassesAreNoOpsOnANonVEtaTarget(testCase)
% Wiring a pass into a shared harness means it now runs on every target that
% harness supports. Both passes must return their input untouched -- with a
% denominator saying so -- when the target is not V_eta, or wiring them would
% change V_delta/V_zeta runs that nothing here re-verifies.
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));

[outA, repA] = did2.convert.epochMint(r, 'Validate', false, ...
    'TargetVersion', 'V_zeta');
verifyEqual(testCase, outA.migrated, {});
verifyFalse(testCase, repA.ran);
verifyEqual(testCase, repA.documents_inspected, 0);

[outB, repB] = did2.convert.resolveSessionAnchors(r, 'Validate', false, ...
    'TargetVersion', 'V_zeta');
verifyEqual(testCase, outB.migrated, {});
verifyFalse(testCase, repB.ran);
verifyEqual(testCase, repB.documents_inspected, 0);
end

function testBothNewPassesAttachADenominatorOnAnEmptyBatch(testCase)
% "Ran and found nothing" must be readable as such. An empty V_eta batch sets
% `ran` TRUE with every counter at 0 -- the opposite of the off-target case
% above, and the two must not print the same.
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));

[~, repA] = did2.convert.epochMint(r, 'Validate', false, ...
    'TargetVersion', 'V_eta');
verifyTrue(testCase, repA.ran);
verifyEqual(testCase, repA.epochs_minted, 0);

[~, repB] = did2.convert.resolveSessionAnchors(r, 'Validate', false, ...
    'TargetVersion', 'V_eta');
verifyTrue(testCase, repB.ran);
verifyEqual(testCase, repB.anchors_seen, 0);
verifyEqual(testCase, repB.refused_total, 0);
end
