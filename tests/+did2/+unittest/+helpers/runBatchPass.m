function result = runBatchPass(result, passName, reportField, fn)
%RUNBATCHPASS Run one batch post-pass so a failure cannot take the report down.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB;
%   nothing in this file has been run. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion.
%
%   RESULT = did2.unittest.helpers.runBatchPass(RESULT, PASSNAME, REPORTFIELD,
%   FN) calls FN(RESULT) -- one of the batch post-passes in did2.convert -- and
%   guarantees that RESULT comes back usable whatever FN does.
%
%   ---------------------------------------------------------------------
%   WHY A GUARD HERE AT ALL, WHEN THE SIBLING CALLS ARE BARE
%   ---------------------------------------------------------------------
%   Not because a failing pass should be tolerated. Because of WHERE the throw
%   lands. In `runCorpusDiscovery` the post-passes run at lines ~63-90 and
%   `writeCorpusReport` runs at ~line 103. An uncaught error between those two
%   points does not merely turn the corpus red -- it means NO
%   `<corpus>-summary.json` IS EVER WRITTEN, so an hour of wall-clock across six
%   parallel jobs produces no census, no by_class survivor counts, no
%   silent-loss table, and no evidence about the very pass that failed. That is
%   run #256 (two largest corpora lost to one exception in a digest) and run #3
%   (six corpora, zero reports, exit 0) in a third costume.
%
%   So the rule this helper encodes is narrow and stated:
%
%       GUARD A PASS WHOSE THROW WOULD DESTROY AN ARTIFACT THE RUN EXISTS TO
%       PRODUCE. CALL BARE WHERE IT WOULD NOT.
%
%   `testFixtureCorpus` writes no report and is the ~2-minute fast gate, so it
%   calls the passes BARE on purpose: there the raw stack trace is strictly more
%   informative than a captured message, and there is nothing to lose. The two
%   report-writing sites (`runCorpusDiscovery`, `testCorpusPRED`) route through
%   here.
%
%   ---------------------------------------------------------------------
%   A GUARD THAT IS QUIET IS THE DEFECT, NOT THE FIX
%   ---------------------------------------------------------------------
%   `silentLoss` printed "0 empty edges" for two days while reading nothing, and
%   the digest above it repeated the omission. A try/catch that swallows is the
%   same machine. So a caught failure is made loud in FOUR places, and the
%   caller is expected to use the fourth:
%
%     1. stderr, immediately, with the identifier and the full stack.
%     2. RESULT.<REPORTFIELD>.pass_failed -- a non-empty message. Because the
%        field is written HERE, "the pass threw" and "the pass never ran" are
%        distinguishable from the report alone (`ran` is false and
%        `pass_failed` is set, versus the field being absent entirely).
%     3. `writeCorpusReport` persists that field into the artifact, and
%        `tools/census_digest.py` renders `pass_failed` as a *** banner.
%     4. `batchPassFailure(RESULT, FIELD)` -- the message a HARD gate asserts
%        is empty, so PRED goes red on a failed pass AFTER its report is on
%        disk.
%
%   A pass that returns without attaching its report struct is treated as a
%   failure too. Every pass in did2.convert assigns its report to RESULT
%   unconditionally, before reading a single document, precisely so a
%   denominator always exists; one that did not would be an instrument with no
%   denominator, which is the thing Operating Rule 5 forbids.
%
%   ---------------------------------------------------------------------
%   WHAT "LEFT IN PASS-1 FORM" MEANS, EXACTLY
%   ---------------------------------------------------------------------
%   `did2.document` is a HANDLE class, so "the caller's copy is untouched" is
%   not free -- it holds for these passes because neither mutates an existing
%   document in place. `epochMint` and `resolveSessionAnchors` both read via
%   `toStruct()`, build NEW bodies as plain structs, hand them to
%   `did2.convert.v1_to_v2` (which constructs fresh objects) and REPLACE cell
%   entries. No setter is called on a document already in RESULT.migrated.
%   A future pass that mutates in place would break that guarantee and must not
%   use this helper without re-establishing it.
%
%   INPUTS
%     RESULT       the struct returned by did2.convert.v1_to_v2
%     PASSNAME     char, for the message: e.g. 'did2.convert.epochMint'
%     REPORTFIELD  char, the field the pass attaches its report to on RESULT
%                  (e.g. 'epoch_mint', 'session_anchor_fold')
%     FN           function handle taking RESULT and returning RESULT
%
%   See also: did2.unittest.helpers.batchPassFailure,
%   did2.unittest.helpers.writeCorpusReport, did2.convert.epochMint,
%   did2.convert.resolveSessionAnchors.

arguments
    result (1,1) struct
    passName (1,:) char
    reportField (1,:) char
    fn (1,1) function_handle
end

try
    result = fn(result);
catch ME
    fprintf(2, '\n');
    fprintf(2, '*** BATCH POST-PASS FAILED: %s\n', passName);
    fprintf(2, '***   message:    %s\n', ME.message);
    fprintf(2, '***   identifier: %s\n', ME.identifier);
    for k = 1:numel(ME.stack)
        fprintf(2, '***   at %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    fprintf(2, ['***   the documents it would have changed are LEFT IN THEIR ' ...
        'PASS-1 FORM.\n']);
    fprintf(2, ['***   recorded in the corpus report as `%s.pass_failed`; the ' ...
        'hard gates assert on it.\n\n'], reportField);
    result.(reportField) = failureReport(passName, ME.message, ME.identifier);
    return;
end

if ~isfield(result, reportField)
    % NOT a tolerated shape. Every did2.convert batch pass assigns its report to
    % RESULT before it reads anything, so an absent field means the pass
    % returned by a path that skipped its own denominator. Reporting that as a
    % failure is the whole of Operating Rule 5: a pass with no denominator has
    % not measured anything, however clean its return looked.
    msg = sprintf(['%s returned without attaching a `%s` report struct; ' ...
        'it produced no denominator, so nothing it did can be read.'], ...
        passName, reportField);
    fprintf(2, '\n*** BATCH POST-PASS REPORTED NOTHING: %s\n***   %s\n\n', ...
        passName, msg);
    result.(reportField) = failureReport(passName, msg, ...
        'did2:test:batchPassReportMissing');
end
end

% ===================== helpers =========================================

function rep = failureReport(passName, message, identifier)
%FAILUREREPORT The struct a failed pass leaves behind.
%   DENOMINATOR-SHAPED even in failure: `ran` is false and the counts are
%   absent rather than zero, so a reader cannot mistake a crash for a clean
%   pass that found nothing. A zeroed count table would be exactly the
%   all-zeros-reads-as-clean failure that produced these operating rules.
% AN EMPTY MESSAGE WOULD MAKE THE FAILURE INVISIBLE. `batchPassFailure` reports
% a failure by returning a NON-EMPTY message, so an error thrown with an empty
% message -- `error('some:id', '')`, or a rethrown MException built that way --
% would sail through every gate downstream while the pass had in fact died. The
% substitution below is not cosmetic: it is the difference between a red gate
% and a silent one, and "the failure had no message" is itself the finding.
% UNVERIFIED AND FLAGGED: no test covers this branch, because producing an
% empty-message throw needs MATLAB behaviour this container cannot check --
% `error(id, '')` is documented not to throw at all, and
% `throw(MException(id, ''))` depends on the constructor accepting an empty
% message. testBatchPassWiring.m records that gap in place of a test written on
% a guess.
if isempty(char(message))
    message = sprintf( ...
        '%s threw with an EMPTY message (identifier: %s)', passName, ...
        emptyAs(identifier, '<none>'));
end
rep = struct( ...
    'pass',                  passName, ...
    'pass_failed',           char(message), ...
    'pass_failed_identifier', char(identifier), ...
    'ran',                   false);
end

function v = emptyAs(x, dflt)
v = char(x);
if isempty(v); v = dflt; end
end
