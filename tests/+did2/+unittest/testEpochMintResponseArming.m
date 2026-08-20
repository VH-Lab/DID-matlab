function tests = testEpochMintResponseArming
%TESTEPOCHMINTRESPONSEARMING The SECOND armed fold in did2.convert.epochMint.
%
%   #60, 2026-08-17. `stimulus_response_scalar` is now armed: the pass stamps
%   an `epoch_id` edge onto the pre-body and re-runs the per-class migrator, so
%   its branch 1 takes over from the passthrough that has been live on every
%   did_v1 document since the guard was written.
%
%   ---------------------------------------------------------------------
%   WHAT THIS FILE TESTS, AND WHAT IT DELIBERATELY DOES NOT
%   ---------------------------------------------------------------------
%   These are STRUCTURAL assertions read off epochMint.m's own source, in the
%   same idiom testBatchPassWiring uses on runCorpusDiscovery. That is a
%   deliberate choice and the reason is worth stating rather than leaving as an
%   apparent gap:
%
%   The BEHAVIOUR -- does a real stimulus_response_scalar with a real epoch
%   document fold? -- is already covered twice, and neither cover is here.
%   `testStimulusResponseEpochGuard` drives branch 1 directly by pre-stamping
%   the edge (`withEpochEdge`), asserting the leaf, the id preservation, the
%   relative_reference anchor and the retired session anchor. And the corpus
%   run exercises the whole path over 273 real documents, which is a stronger
%   fixture than any this file could build. A third fixture asserting the same
%   shape from a different construction is how two tests drift into disagreeing.
%
%   What is NOT covered anywhere else, and is what this file exists for, is the
%   COUPLING between the two armed folds. They are separate loops by design --
%   see epochMint.m's "WHY A SEPARATE LOOP AND NOT A ROW IN THE ONE ABOVE" --
%   and that duplication is safe only while the two stay in step. Nothing else
%   checks that.
%
%   STATUS: NEVER RUN when written. There is no MATLAB in the authoring
%   environment, so every assertion below is unexecuted; treat a first green run
%   as the evidence, not this header. The assertions are text reads rather than
%   fixture drives precisely because that is the kind this author can get right
%   without executing it -- three behavioural drafts written blind failed CI on
%   the same day this was written.

tests = functiontests(localfunctions);
end

% ===================== the arming table ================================

function testBothArmedFoldsAreInTheDefaultTable(testCase)
% The table is a local function, so this reads the source. A row missing here
% does not fail loudly at runtime -- the loop simply never finds a document to
% arm, and every counter reads a legitimate-looking zero.
src = epochMintSource();
verifyTrue(testCase, contains(src, ...
    '''daqmetadatareader_epochdata_ingested'', ...'), ...
    'the metadata row left defaultArmingMigrators');
verifyTrue(testCase, contains(src, '''stimulus_response_scalar'', ...'), ...
    'the stimulus_response_scalar row is not in defaultArmingMigrators');
verifyTrue(testCase, contains(src, '''syncrule_mapping'', ...'), ...
    'the syncrule_mapping row is not in defaultArmingMigrators');
end

function testTheHeaderStatesTheRowCountItActuallyCarries(testCase)
% The header asserted "ONE ROW TODAY, and the reason there is only one is a
% SCHEMA fact" and listed stimulus_response_scalar among the classes that could
% not be armed. Leaving that standing beside a second row is exactly the stale
% claim this project keeps paying for -- a reader would conclude the row was
% added in error and remove it.
%
% ASSERTED POSITIVELY, and the first draft got this backwards. It asserted the
% string "ONE ROW TODAY" appears NOWHERE, which fails against this repository's
% own correction style: a superseded claim is QUOTED inside the note that
% withdraws it, never silently deleted (the HISTORICAL-BUILD-CLAIM convention).
% The old wording is therefore still in the file, correctly, and what must hold
% is that the CURRENT claim leads.
% UPDATED for the THIRD row (syncrule_mapping, #60). The count moved TWO -> THREE
% and the header now leads with 'THREE ROWS.'; the superseded 'TWO ROWS' is kept
% inside the note that withdrew it (HISTORICAL-BUILD-CLAIM), so what must hold is
% that the CURRENT count leads.
src = epochMintSource();
verifyTrue(testCase, contains(src, 'THREE ROWS.'), ...
    'defaultArmingMigrators does not state the row count it carries');
end

% ===================== the coupling between the two folds ==============

function testTheTwoArmedFoldsShareARefusalVocabulary(testCase)
% THE INVARIANT THE DUPLICATION RESTS ON. The two loops refuse for the same
% reasons over different denominators, and they are readable side by side only
% while their counter names correspond suffix-for-suffix. A refusal added to
% one and not the other is a silent hole: the fold refuses, and the number
% lands nowhere.
% EXTENDED to the THIRD fold (syncrule_mapping, #60). The invariant was the two
% armed folds sharing a refusal vocabulary; there are now three, and all three
% must agree suffix-for-suffix or a refusal added to one lands nowhere in another.
src = epochMintSource();
metaSuffixes = counterSuffixes(src, 'metadata_refused_');
respSuffixes = counterSuffixes(src, 'response_refused_');
syncSuffixes = counterSuffixes(src, 'syncrule_refused_');

verifyNotEmpty(testCase, metaSuffixes, ...
    'no metadata_refused_* counters found -- the scan is broken, and a broken scan makes this test vacuous');
verifyEqual(testCase, sort(respSuffixes), sort(metaSuffixes), sprintf( ...
    ['the two armed folds have drifted apart.\n' ...
     '  metadata_refused_*: %s\n' ...
     '  response_refused_*: %s'], ...
    strjoin(sort(metaSuffixes), ', '), strjoin(sort(respSuffixes), ', ')));
verifyEqual(testCase, sort(syncSuffixes), sort(metaSuffixes), sprintf( ...
    ['the syncrule fold has drifted from the other two.\n' ...
     '  metadata_refused_*: %s\n' ...
     '  syncrule_refused_*: %s'], ...
    strjoin(sort(metaSuffixes), ', '), strjoin(sort(syncSuffixes), ', ')));
end

function testTheTwoArmedFoldsShareAProgressVocabulary(testCase)
% Same rule for the non-refusal counters. `seen` / `already_folded` /
% `edges_stamped` / `folds_emitted` / `folds_withheld` are the pair a reader
% reconciles ("did every source document get folded?"), and the reconciliation
% only works if both folds report the same five.
src = epochMintSource();
for want = {'seen', 'already_folded', 'edges_stamped', ...
            'folds_emitted', 'folds_withheld'}
    w = want{1};
    verifyTrue(testCase, contains(src, ['metadata_ingested_' w]) ...
        || contains(src, ['metadata_' w]), ...
        sprintf('the metadata fold has no `%s` counter', w));
    verifyTrue(testCase, contains(src, ['response_scalar_' w]), ...
        sprintf('the response fold has no `%s` counter', w));
    verifyTrue(testCase, contains(src, ['syncrule_' w]), ...
        sprintf('the syncrule fold has no `%s` counter', w));
end
end

function testEveryFoldKindSetsEveryFlag(testCase)
% `armings` is a struct set and the carry loop asks every entry for ALL flags.
% An entry missing one makes that read an ERROR, not a false -- so every flag
% assignment must appear once per arming block. There are now THREE blocks
% (metadata, response, syncrule), each setting all three flags, so each flag
% name appears exactly three times.
src = epochMintSource();
nMeta = numel(strfind(src, 'armEntry.is_metadata_fold ='));
nResp = numel(strfind(src, 'armEntry.is_response_fold ='));
nSync = numel(strfind(src, 'armEntry.is_syncrule_fold ='));
verifyEqual(testCase, nMeta, 3, ...
    'expected all three arming blocks to set is_metadata_fold');
verifyEqual(testCase, nResp, 3, ...
    'expected all three arming blocks to set is_response_fold');
verifyEqual(testCase, nSync, 3, ...
    'expected all three arming blocks to set is_syncrule_fold');
end

function testEveryFoldFlagHasACarryReader(testCase)
% A fold kind with no reader in the carry loop is counted as neither emitted
% nor withheld -- a source seen and then vanishing from the pair it is meant to
% reconcile against. That is the MISSING-number failure this file's neighbours
% already record, so it is asserted rather than trusted.
src = epochMintSource();
verifyTrue(testCase, contains(src, 'response_scalar_folds_emitted'), ...
    'the response fold has no emitted reader in the carry loop');
verifyTrue(testCase, contains(src, 'syncrule_folds_emitted'), ...
    'the syncrule fold has no emitted reader in the carry loop');
verifyTrue(testCase, contains(src, 'if armings{a}.is_metadata_fold'), ...
    'the carry loop no longer branches on is_metadata_fold');
verifyTrue(testCase, contains(src, 'elseif armings{a}.is_response_fold'), ...
    'the carry loop does not read is_response_fold');
verifyTrue(testCase, contains(src, 'elseif armings{a}.is_syncrule_fold'), ...
    'the carry loop does not read is_syncrule_fold');
end

% ===================== the string source, which is not the mixin =======

function testTheResponseFoldReadsElementEpochidAndNotTheMixin(testCase)
% The class carries TWO epoch strings and they name DIFFERENT epochs -- the
% recording element's and the stimulator's. Reading "whichever string this body
% has" would anchor a response to the stimulator's epoch, which is the error
% epochMint's own metadata loop warns about one block up.
% ASSERTED ON THE CALL, NOT ON THE ABSENCE OF THE OTHER NAME. The first draft
% of this test asserted that `'stimulus_response.stimulator_epochid'` appears
% nowhere in the file. It does appear -- three times, in comments explaining
% precisely why it is NOT the one to read -- and the draft only passed because
% those mentions use backticks while the assertion searched for single quotes.
% A test that turns on comment punctuation is not testing the code.
src = epochMintSource();
verifyTrue(testCase, ...
    contains(src, '''stimulus_response.element_epochid'');'), ...
    ['the response fold''s valueForSource call does not name ' ...
     'element_epochid -- the recording element''s epoch is the one a ' ...
     'RESPONSE anchors to']);
end

function testTheResponseFoldExpectsTheCalculationLeafAsItsPrimary(testCase)
% armingIsSafe refuses as `declined` when offered{1} is not this class, so a
% wrong primary here would read as "the migrator declined" on every document --
% a refusal counter ticking for a reason that is not true.
src = epochMintSource();
verifyTrue(testCase, contains(src, '''harmonic_component_calculation'''), ...
    'the response fold does not name harmonic_component_calculation as its primary');
end

% ===================== readers =========================================

function src = epochMintSource()
%EPOCHMINTSOURCE epochMint.m as TEXT.
%   Resolved from mfilename('fullpath') rather than from `which`, for the
%   reason testBatchPassWiring gives at length: a path lookup with two
%   candidates can resolve to a MatBox-installed copy of another revision and
%   still print a confident result.
here = fileparts(mfilename('fullpath'));            % <root>/tests/+did2/+unittest
repoRoot = fileparts(fileparts(fileparts(here)));   % -> +did2 -> tests -> <root>
p = fullfile(repoRoot, 'src', 'did', '+did2', '+convert', 'epochMint.m');
assert(isfile(p), 'epochMint.m not found at %s', p);
src = fileread(p);
end

function out = counterSuffixes(src, prefix)
%COUNTERSUFFIXES The distinct `<prefix><suffix>` names appearing in SRC.
%   Plain scanning, no regexp: this file's neighbours record a regexp that
%   simulated green and matched ZERO in CI, and a suffix set that silently
%   comes back empty would make the comparison above pass over two empties.
out = {};
ok = ['abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_'];
starts = strfind(src, prefix);
for k = 1:numel(starts)
    i = starts(k) + numel(prefix);
    j = i;
    while j <= numel(src) && any(src(j) == ok)
        j = j + 1;
    end
    if j == i; continue; end
    cand = src(i:j-1);
    if ~any(strcmp(out, cand))
        out{end+1} = cand; %#ok<AGROW>
    end
end
end
