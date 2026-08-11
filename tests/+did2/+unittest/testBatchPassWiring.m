function tests = testBatchPassWiring
%TESTBATCHPASSWIRING Every batch post-pass is called from every call site.
%
%   STATUS: WRITTEN 2026-08-10, EXTENDED 2026-08-11, NEVER EXECUTED. This
%   container has no MATLAB and no Octave -- `command -v matlab octave
%   octave-cli` prints nothing and exits 1 -- so not one line of this file has
%   been run, here or anywhere. test-migrators-quick.yml is the first thing
%   that will have an opinion. Nothing below may be read as "verified".
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
%   A test that FAILS because a sibling repository is missing is a test people
%   disable, and that reasoning still holds -- so a missing NDI-matlab is a
%   SKIP, never a failure and never a silent pass. The skip prints its
%   denominator and names the exact path it could not read, because "not
%   looked at" and "wired correctly" must not print the same.
%
%   WHAT CHANGED 2026-08-11: the cross-repo half used to be REPORT-ONLY, and
%   report-only was not enough. Re-derived here rather than quoted:
%
%       $ grep -o "ndi\.migrate\.internal\.[A-Za-z_]*\s*(" \
%             ../NDI-matlab/src/ndi/+ndi/+migrate/local.m \
%         | tr -d ' (' | sort -u | wc -l
%       10
%
%   Ten NDI-only passes printed beside three overlapping ones is a matrix with
%   ten divergent rows, and a matrix with ten divergent rows is how nobody
%   notices row eleven. `did2.convert.resolveDatasetEntities` WAS row eleven:
%   built, unit-tested, run by all three DID call sites, called by production
%   from nothing for a day, and found by accident. So the divergence is now
%   ENUMERATED IN THIS FILE, one row per pass, each with a written reason, and
%   gated BOTH WAYS:
%
%     * a divergence with NO row FAILS -- that is row eleven, caught;
%     * a ROW THAT NO LONGER DIVERGES ALSO FAILS. An exemption that outlives
%       its reason is not a smaller version of the defect, it is the defect
%       with a blessing on it: it converts a real gap into an approved one and
%       stops anybody looking. It is the same shape as the six plan documents
%       whose headers claimed "NO TEAM-SIGN-OFF LINE" hundreds of lines above
%       the sign-off they carried.
%
%   ---------------------------------------------------------------------
%   WHY THE TABLE IS NOT THE `WIRING-EXEMPT` MARKER
%   ---------------------------------------------------------------------
%   The DID-side escape hatch is a marker line in the PASS'S OWN SOURCE. That
%   idiom was considered for the cross-repo table and rejected on three
%   counts, none of them stylistic:
%
%   1. TEN OF THE ELEVEN ROWS ARE FILES THIS REPOSITORY DOES NOT OWN. They are
%      `ndi.migrate.internal.*` functions in NDI-matlab. A DID-side gate that
%      required a marker inside another repository's sources would be
%      unsatisfiable from here, and would break the moment NDI-matlab is
%      absent -- which is the case this file must SKIP through, not fail on.
%      They are also not batch post-passes by signature (`bodyResolver` takes
%      `bodies`, `stimulusBathToBath` takes `v1Body`), so `batchPasses` never
%      sees them and there is no scan to hang a marker off.
%   2. THE TWO MARKERS ANSWER DIFFERENT QUESTIONS AND MUST NOT SUBSTITUTE FOR
%      EACH OTHER. `WIRING-EXEMPT` says "this pass is deliberately wired
%      NOWHERE". A divergence row says "this pass IS wired, on exactly ONE
%      side, deliberately". Reusing one marker for both would mean that
%      exempting a pass from the DID gate silently also granted it a
%      cross-repo pass -- one marker disarming two gates, which is this
%      project's recurring failure in miniature.
%   3. THE STALE-ROW CHECK NEEDS A LIST IT CAN ITERATE. A marker distributed
%      across source files can only be examined when its file is scanned, so a
%      marker on a function that has been DELETED leaves nothing to read and
%      nothing to notice. A checked-in table can be walked row by row and each
%      row required to still name a live divergence. The whole second half of
%      this gate is impossible with a distributed marker.
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
% RESOLVED FROM THIS FILE, NOT FROM did.toolboxdir(). The first version asked
% did.toolboxdir(), and CI found ZERO passes where a local scan found four:
%
%     run 31440976289 (2f7f1a4), job 93625421827
%       fewer than 4 batch post-passes discovered -- the signature scan is
%       broken, and a broken scan reports perfect coverage
%           Actual Value: 0    Minimum Value (Inclusive): 4
%
% `did.toolboxdir()` reports where the LOADED `did` package lives, and the
% corpus/quick jobs run `matbox.installRequirements`, which can put another
% copy of the toolbox on the path ahead of the checkout. The scan then walks a
% directory belonging to a different revision -- or to no `+did2/+convert` at
% all -- while the test believes it inspected this one.
%
% `didCallSites` below already resolves from `mfilename('fullpath')` for
% exactly this reason. Doing the same here keeps both halves of the gate
% reading ONE checkout: comparing passes found in tree A against call sites
% read in tree B is not a coverage measurement, it is two unrelated facts.
here = fileparts(mfilename('fullpath'));   % <root>/tests/+did2/+unittest
repoRoot = fileparts(fileparts(fileparts(here)));   % -> +did2 -> tests -> <root>
convertDir = fullfile(repoRoot, 'src', 'did', '+did2', '+convert');
files = dir(fullfile(convertDir, '*.m'));
% The denominator the assertion below rests on is the FILE COUNT, and zero
% files is indistinguishable from zero matches once the loop has run. Say which
% one happened, and say where we looked, so a wrong path cannot read as a
% correctly-scanned empty package.
fprintf('  scan root: %s (%d .m file(s))\n', convertDir, numel(files));
if isempty(files)
    fprintf(['  NO .m FILES THERE -- the path is wrong, or the package moved. ' ...
             'This is "did not look", not "found nothing".\n']);
end
passes = {};
exempt = struct('name', {}, 'reason', {});
unmatched = {};
for k = 1:numel(files)
    txt = fileread(fullfile(files(k).folder, files(k).name));
    lines = strsplit(txt, newline);
    if isempty(lines); continue; end
    sig = strtrim(lines{1});
    % `function result = name(result, ...)` or
    % `function [result, report] = name(result, ...)`
    passName = batchPassName(sig);
    if isempty(passName)
        unmatched{end+1} = sprintf('%-32s %s', files(k).name, sig); %#ok<AGROW>
        continue;
    end
    tok = {passName};
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
% SELF-DIAGNOSIS. When the scan finds nothing, print every first line it
% rejected. The previous version printed only the verdict, so "0 passes" gave
% no way to tell a broken matcher from a package with no passes in it, and it
% cost a CI round per guess.
if isempty(passes) && isempty(exempt)
    fprintf('  0 matched. Rejected first lines (%d):\n', numel(unmatched));
    for u = 1:numel(unmatched)
        fprintf('    %s\n', unmatched{u});
    end
end
end

function name = batchPassName(sig)
%BATCHPASSNAME The function name in SIG, when SIG is a batch post-pass.
%   A batch post-pass is `function <out> = <name>(result, ...)` -- its first
%   argument is the `result` struct did2.convert.v1_to_v2 returns.
%
%   PLAIN STRING PARSING, DELIBERATELY. This was one regex,
%
%       '^function\s+(?:\[[^\]]*\]|\w+)\s*=\s*(\w+)\s*\(\s*result\b'
%
%   and it matched FOUR files when simulated and ZERO in CI -- run 31441482517,
%   with the scan root already verified correct and 9 .m files found, so the
%   path was right and the pattern was wrong. Which construct differs between
%   engines is not worth another CI round to discover: `\b`, `(?:...)` and the
%   escaped `]` inside a bracket expression are all candidates. strfind and
%   strtrim have no dialect, so the question stops being askable.
name = '';
sig = strtrim(sig);
if ~strncmp(sig, 'function', 8); return; end
eqPos = strfind(sig, '=');
opPos = strfind(sig, '(');
clPos = strfind(sig, ')');
if isempty(eqPos) || isempty(opPos) || isempty(clPos); return; end
eqPos = eqPos(1); opPos = opPos(1);
if opPos < eqPos; return; end       % `function name(...)`, no output argument
cand = strtrim(sig(eqPos+1:opPos-1));
if ~isvarname(cand); return; end    % isvarname does the identifier check for us
args = strsplit(sig(opPos+1:clPos(end)-1), ',');
if isempty(args) || ~strcmp(strtrim(args{1}), 'result'); return; end
name = cand;
end

function sites = didCallSites()
%DIDCALLSITES The three DID-side harness entry points, as absolute paths.
here = fileparts(mfilename('fullpath'));            % tests/+did2/+unittest
sites = { ...
    'runCorpusDiscovery', fullfile(here, '+helpers', 'runCorpusDiscovery.m'); ...
    'testCorpusPRED',     fullfile(here, 'testCorpusPRED.m'); ...
    'testFixtureCorpus',  fullfile(here, 'testFixtureCorpus.m')};
end

function p = ndiLocalPath()
%NDILOCALPATH The production call site, by ONE explicit mechanism.
%   <this repo root>/NDI-matlab/src/ndi/+ndi/+migrate/local.m -- and nothing
%   else is tried. There is no search list, no fallback and no environment
%   override, deliberately.
%
%   ONE MECHANISM BECAUSE THE LAST LOOKUP RESOLVED TO THE WRONG COPY. This
%   test asked `did.toolboxdir()` until 2026-08-11, and `did.toolboxdir()`
%   reports where the LOADED `did` package lives -- which the quick and corpus
%   jobs can put somewhere else entirely, because `matbox.installRequirements`
%   may place another copy of the toolbox on the path ahead of the checkout.
%   The same mistake already cost this file a CI round on its own side
%   (run 31440976289: ZERO passes found where a local scan found four). A
%   lookup with two candidates can silently pick the wrong one and still print
%   a confident matrix; a lookup with one candidate can only succeed or say
%   which path it tried.
%
%   REPO-ROOT-RELATIVE, WHICH IS THE PATTERN did-schema ALREADY USES. Five
%   workflows check `Waltham-Data-Science/did-schema` out with
%   `path: did-schema`, i.e. INSIDE the workspace, and the steps then read
%   `did-schema/tools/...` relative to the repo root.
%   `actions/checkout` cannot write above GITHUB_WORKSPACE, so a
%   TRUE sibling (`../NDI-matlab`) is not available to CI at all and picking
%   it would have guaranteed the gate never fires -- a test that always skips
%   is the silent pass this file exists to prevent, wearing a skip's clothes.
%   test-migrators-quick.yml now checks NDI-matlab out at `path: NDI-matlab`
%   on the same pattern.
%
%   The cost is stated rather than hidden: a developer whose NDI-matlab sits
%   BESIDE DID-matlab gets a SKIP, not a run. That is the correct failure
%   direction (skip, loudly, naming the path) and it is what the message says
%   to fix.
%
%   Resolved from `mfilename('fullpath')` for the same reason `didCallSites`
%   and `batchPasses` are: comparing passes found in tree A against call sites
%   read in tree B is not a coverage measurement, it is two unrelated facts.
here = fileparts(mfilename('fullpath'));            % <root>/tests/+did2/+unittest
repoRoot = fileparts(fileparts(fileparts(here)));   % -> +did2 -> tests -> <root>
p = fullfile(repoRoot, 'NDI-matlab', 'src', 'ndi', '+ndi', '+migrate', ...
    'local.m');
end

function names = namesCalledWithPrefix(txt, prefix)
%NAMESCALLEDWITHPREFIX Distinct identifiers CALLED as <PREFIX><name>( in TXT.
%   A CALL, not a mention: the identifier must be followed (after optional
%   whitespace) by an opening parenthesis. That distinction is the whole
%   reason this function exists rather than a bare `strfind`.
%   `ndi.migrate.local` NAMES `did2.convert.resolveDeferredBaths` in FIVE
%   comments (:306 :310 :359 :362 :630) and CALLS it nowhere, so a scan that
%   accepted prose would report that pass as wired in production and the
%   central row of the divergence table would evaporate.
%
%   It also rejects a longer qualified name: after `did2.convert.` the text
%   `readers.sqliteV1(` yields the identifier `readers` followed by `.`, and
%   `resolveDeferredBaths.makeBathVeta"` yields `resolveDeferredBaths`
%   followed by `.`. Neither is a call to the thing it starts with, and both
%   occur in local.m.
%
%   PLAIN STRING PARSING, for the reason batchPassName gives: a regex here was
%   simulated green and ran ZERO in CI, and `strfind` has no dialect.
names = {};
ok = ['abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' ...
      '0123456789' '_'];
starts = strfind(txt, prefix);
for k = 1:numel(starts)
    i = starts(k) + numel(prefix);
    j = i;
    while j <= numel(txt) && any(txt(j) == ok)
        j = j + 1;
    end
    if j == i; continue; end        % nothing after the dot
    cand = txt(i:j-1);
    % skip spaces/tabs, then demand an opening parenthesis
    while j <= numel(txt) && (txt(j) == ' ' || txt(j) == sprintf('\t'))
        j = j + 1;
    end
    if j > numel(txt) || txt(j) ~= '('; continue; end
    names{end+1} = cand; %#ok<AGROW>
end
if isempty(names)
    names = {};
else
    names = unique(names);
end
end

function tbl = crossRepoDivergenceTable()
%CROSSREPODIVERGENCETABLE The passes that run on ONE side only, with reasons.
%   Columns: pass name | the side it runs on ('DID' or 'NDI') | why that is
%   correct. Each row is a claim that this divergence is INTENDED. The gate
%   below fails on a divergence with no row AND on a row with no divergence,
%   so this table cannot quietly grow into a list of things nobody looks at.
%
%   'DID' = called by did2.unittest.helpers.runCorpusDiscovery and not by
%   ndi.migrate.local. 'NDI' = the other way round. Membership is MEASURED
%   from the two sources every run, never read from here.
rows = { ...
% ---------------------------------------------------------------------------
% DID-side only
% ---------------------------------------------------------------------------
'resolveDeferredBaths', 'DID', ...
    ['NDI runs a PRECISE replacement that says so in its own words. ' ...
     'ndi.migrate.internal.stimulusBathToBath:157 -- "This is the ' ...
     'LIVE-session counterpart of the coarse ' ...
     'did2.convert.resolveDeferredBaths.makeBathVeta". The DID pass anchors ' ...
     'the resolved bath session-relatively because a corpus has no live ' ...
     'session; the NDI assembler keeps the epoch-precise anchor. Running ' ...
     'the coarse pass in production would re-resolve what the precise one ' ...
     'already did. POSITIVE evidence, not an absence.']; ...
% ---------------------------------------------------------------------------
% NDI-side only. ALL TEN share one structural reason -- they are
% `ndi.migrate.internal.*` functions, so the DID corpus harness cannot call
% them without DID-matlab depending on NDI-matlab, which is the dependency
% direction this whole migration is built to avoid. That reason is NOT
% written ten times: what each row states is the SPECIFIC thing the DID gate
% therefore does not measure, because "we cannot call it" is an explanation of
% the mechanism and not of the cost.
% ---------------------------------------------------------------------------
'bodyResolver', 'NDI', ...
    ['Not a transform at all: an INDEX over the raw v1 bodies ' ...
     '(session/element lookups) that the per-body deferral assemblers ' ...
     'consume. Nothing is migrated by it, so there is no DID-side output ' ...
     'that could differ. Listed rather than filtered out because a filter ' ...
     'for "things that are not really passes" is a judgement that would ' ...
     'have to be re-made, silently, for every future entry.']; ...
'stimulusBathToBath', 'NDI', ...
    ['The live-session bath assembler, per document, invoked from step (1). ' ...
     'It is the counterpart named in the resolveDeferredBaths row above -- ' ...
     'the same divergence seen from the other side, which is why both ends ' ...
     'appear here rather than one.']; ...
'stimulusPresentationToManipulation', 'NDI', ...
    ['Needs the RECORDING GRAPH -- the animal subject and the trial series ' ...
     'are only reachable with the whole session in hand. The DID corpus ' ...
     'harness holds documents, not a session, so it cannot assemble the ' ...
     'body-backed visual_grating_manipulation and its sampled_body.']; ...
'ontologyRowSubjects', 'NDI', ...
    ['Resolves an ontologyTableRow subject against the migrated-id graph and ' ...
     'then RE-FOLDS the row through did2.convert.v1_to_v2 so pass 1 fans it ' ...
     'out. The DID gate measures the passthrough count instead. COST: the ' ...
     '~20,583 rows this converts in production stay passthroughs in every ' ...
     'corpus report, so the corpus never exercises the fan-out.']; ...
'ontologyLabelSubjects', 'NDI', ...
    ['Follows an ontology_label one hop (imageStack -> image_observation -> ' ...
     'subject_id) through the migrated-id graph. COST: ~7,007 JH labels ' ...
     'become term_observations in production and stay passthroughs in the ' ...
     'corpus report.']; ...
'pathSPromotion', 'NDI', ...
    ['Promotes attributed anatomical loci to Path-S part-subjects using the ' ...
     'corpus-wide subject graph. COST: the DID corpus report counts loci ' ...
     'that production has already promoted, so the two pipelines disagree ' ...
     'about how many subjects a dataset has.']; ...
'ensembleMembership', 'NDI', ...
    ['Turns each `ensemble` MAP document into member_of edges. It must READ ' ...
     'THE BYTES of neuron_names.txt to map column index -> neuron subject, ' ...
     'and a single-doc migrator carries files without reading them ' ...
     '(confirmed via pyraview). The corpus harness has the file, not the ' ...
     'session that resolves the ids.']; ...
'strainAssembly', 'NDI', ...
    ['Assembles unattached openMINDS Strain documents into `strain` ' ...
     'entities, consuming their Species / GeneticStrainType FRAGMENTS. ' ...
     'COST: those fragments -- exactly what did2.validate.isFragment ' ...
     'exists to find -- are still present when the corpus census counts ' ...
     'them, and absent in production.']; ...
'epochAnchorFold', 'NDI', ...
    ['Folds `epoch_bounded_reference` into `relative_reference`. The DID ' ...
     'gate has NOTHING TO FOLD, and that is a fact about the input rather ' ...
     'than a limitation: stimulusBathToBath is the only site in either ' ...
     'repository that mints that class, and it is NDI-side. ' ...
     'local.m states it verbatim -- "Lives NDI-side because the class it ' ...
     'folds is minted NDI-side; the DID gate has nothing to fold."']; ...
'softwareDedup', 'NDI', ...
    ['Merges duplicate `software` entities on (session_id, name, version) ' ...
     'and retargets inbound edges BY TARGET ID (one of the seven is called ' ...
     '`reader_id`, not `software_id`). COST: every corpus report counts one ' ...
     '`software` entity per consuming document -- production does not, so ' ...
     'the entity totals the two pipelines produce are not comparable.']; ...
};
tbl = struct('name', rows(:, 1), 'side', rows(:, 2), 'reason', rows(:, 3));
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
% ndi.migrate.local, REPORT ONLY -- the DID-side passes, one line each.
%
% THIS TEST IS NO LONGER THE ONLY THING WATCHING THE FOURTH CALL SITE, and its
% header used to name two absences as the whole story. Both have since been
% closed: resolveDatasetEntities was wired 2026-08-10 (it was the one this
% file's report caught), and resolveResponseParameters + resolveLawnPlateSubjects
% were wired 2026-08-11. The ASSERTING gate is
% testCrossRepoDivergenceIsExactlyTheCheckedInTable below; this test is kept,
% unweakened and still report-only, because a printed per-pass line is what a
% human reads out of a log tail and the gate prints a set-difference.
%
% The only change to its body is the LOOKUP: it asked `did.toolboxdir()`,
% which reports where the LOADED `did` package lives and can resolve to a
% MatBox-installed copy of another revision. See ndiLocalPath.
localPath = ndiLocalPath();
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

function testCrossRepoDivergenceIsExactlyTheCheckedInTable(testCase)
% THE CROSS-REPO GATE. Read this file's "THE FOURTH CALL SITE IS IN ANOTHER
% REPOSITORY" header for why it exists and why the table is not the
% WIRING-EXEMPT marker.
%
% DENOMINATORS FIRST AND UNCONDITIONALLY, before anything can go wrong:
% how many passes were discovered here, how many rows are checked in, and
% which file is about to be read. A gate whose scan is broken must not be able
% to print a clean set-difference over two empty sets.
[passes, exempt] = batchPasses();
allPasses = [passes(:)', {exempt.name}];
tbl = crossRepoDivergenceTable();
localPath = ndiLocalPath();
here = fileparts(mfilename('fullpath'));
discoveryPath = fullfile(here, '+helpers', 'runCorpusDiscovery.m');

fprintf('\n--- cross-repo divergence gate ---\n');
fprintf(['  DENOMINATOR: %d pass(es) discovered in +did2/+convert ' ...
         '(%d gated, %d exempt); %d checked-in divergence row(s); ' ...
         '2 sources read.\n'], ...
    numel(allPasses), numel(passes), numel(exempt), numel(tbl));
fprintf('  DID side : %s\n', discoveryPath);
fprintf('  NDI side : %s\n', localPath);

% ---------------- the loud skip ----------------------------------------
% NDI-matlab absent is NOT a failure (a test that red-gates on a missing
% sibling gets disabled, and then nothing watches production at all) and it is
% NOT a pass either. It is a skip that names the path, so "we did not look" is
% never readable as "they agree".
if ~isfile(localPath)
    fprintf(2, ['  SKIPPED -- NDI-matlab is not at that path. %d pass(es) ' ...
                'and %d divergence row(s) went UNCHECKED against ' ...
                'production.\n'], numel(allPasses), numel(tbl));
    fprintf(2, ['  This is "did not look", NOT "wired correctly". CI checks ' ...
                'NDI-matlab out at <repo>/NDI-matlab in ' ...
                'test-migrators-quick.yml; if this skipped there, that step ' ...
                'is missing or its ref did not resolve.\n']);
    assumeTrue(testCase, false, sprintf( ...
        ['ndi.migrate.local not readable at %s -- cross-repo divergence ' ...
         'UNCHECKED (skip, not agreement)'], localPath));
    return;
end

% ---------------- measure both sides, dynamically ----------------------
% Nothing here is read out of the table. The table is only ever compared
% against what these two scans find, so a pass that lands tonight moves the
% measurement and the table has to catch up -- never the reverse.
ndiText = fileread(localPath);

didSide = {};
for p = 1:numel(allPasses)
    if callsPass(discoveryPath, allPasses{p})
        didSide{end+1} = allPasses{p}; %#ok<AGROW>
    end
end
% A `did2.convert.` name in local.m counts only if it is one of the passes
% discovered by signature: local.m also calls did2.convert.v1_to_v2, which is
% the migrator entry point rather than a batch post-pass.
ndiDidPasses = intersect(namesCalledWithPrefix(ndiText, 'did2.convert.'), ...
    allPasses);
ndiInternal = namesCalledWithPrefix(ndiText, 'ndi.migrate.internal.');
ndiSide = union(ndiDidPasses(:)', ndiInternal(:)');

overlap = intersect(didSide, ndiSide);
didOnly = setdiff(didSide, ndiSide);
ndiOnly = setdiff(ndiSide, didSide);

fprintf(['  MEASURED: DID side runs %d, NDI side runs %d ' ...
         '(%d did2.convert + %d ndi.migrate.internal), OVERLAP %d, ' ...
         'DIVERGENT %d (%d DID-only + %d NDI-only).\n'], ...
    numel(didSide), numel(ndiSide), numel(ndiDidPasses), ...
    numel(ndiInternal), numel(overlap), ...
    numel(didOnly) + numel(ndiOnly), numel(didOnly), numel(ndiOnly));

everyName = union(didSide, ndiSide);
for k = 1:numel(everyName)
    fprintf('  %-38s %-12s %-12s\n', everyName{k}, ...
        onOff(any(strcmp(everyName{k}, didSide))), ...
        onOff(any(strcmp(everyName{k}, ndiSide))));
end
fprintf('  (columns: runCorpusDiscovery, ndi.migrate.local)\n');

% A broken read of local.m makes every DID pass look DID-only AND every table
% row look stale, so it cannot pass -- but it would fail with a wall of
% irrelevant names. Say the real thing first.
verifyGreaterThanOrEqual(testCase, numel(ndiSide), 4, sprintf( ...
    ['fewer than 4 passes found in %s -- the NDI-side scan is broken, and ' ...
     'a broken scan turns every row of the divergence table into a false ' ...
     'claim in both directions at once'], localPath));

% ---------------- gate 1: a divergence with no row ---------------------
observedName = [didOnly(:)', ndiOnly(:)'];
observedSide = [repmat({'DID'}, 1, numel(didOnly)), ...
                repmat({'NDI'}, 1, numel(ndiOnly))];
tblName = {tbl.name};
tblSide = {tbl.side};

unexplained = {};
for k = 1:numel(observedName)
    hit = strcmp(observedName{k}, tblName) & strcmp(observedSide{k}, tblSide);
    if ~any(hit)
        unexplained{end+1} = sprintf('%s runs on the %s side ONLY', ...
            observedName{k}, observedSide{k}); %#ok<AGROW>
    end
end
verifyEmpty(testCase, unexplained, sprintf( ...
    ['a pass runs on ONE side only and has no row in ' ...
     'crossRepoDivergenceTable. Either wire it into the other side, or add ' ...
     'a row saying WHY it belongs on one -- an unexplained divergence is ' ...
     'how did2.convert.resolveDatasetEntities sat unwired in production ' ...
     'for a day while every gate was green.\n  %s'], ...
    strjoin(unexplained, sprintf('\n  '))));

% ---------------- gate 2: a row that no longer diverges ----------------
% This half is not symmetry for its own sake. A row whose reason has expired
% still reads as a decision somebody made, so it stops the next person
% looking -- it converts a real gap into a blessed one. Same defect as the
% plan-document headers that claimed no sign-off while carrying one.
stale = {};
for r = 1:numel(tbl)
    hit = strcmp(tbl(r).name, observedName) & strcmp(tbl(r).side, observedSide);
    if any(hit); continue; end
    if any(strcmp(tbl(r).name, overlap))
        why = 'it now runs on BOTH sides';
    elseif any(strcmp(tbl(r).name, everyName))
        why = 'it now runs on the OTHER side';
    else
        why = 'it runs on NEITHER side (deleted, renamed, or unwired)';
    end
    stale{end+1} = sprintf('%s (listed %s-only): %s', ...
        tbl(r).name, tbl(r).side, why); %#ok<AGROW>
end
verifyEmpty(testCase, stale, sprintf( ...
    ['a row of crossRepoDivergenceTable no longer describes a divergence. ' ...
     'DELETE IT. An exemption that outlives its reason is not a smaller ' ...
     'version of the defect -- it is the defect with a blessing on it.\n  %s'], ...
    strjoin(stale, sprintf('\n  '))));
end

function s = onOff(tf)
if tf
    s = 'RUNS';
else
    s = '--';
end
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
