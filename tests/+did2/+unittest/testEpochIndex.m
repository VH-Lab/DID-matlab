function tests = testEpochIndex
%TESTEPOCHINDEX did2.convert.epochIndex -- the ONE (session, epoch-string) resolver.
%
%   STATUS: WRITTEN 2026-08-11 IN A CONTAINER WITH NO MATLAB AND NO OCTAVE
%   (`command -v matlab octave octave-cli` prints nothing and exits 1). NOTHING
%   IN THIS FILE HAS BEEN RUN HERE. test-migrators-quick.yml is its first
%   execution, and the CI run id is the only durable evidence that it passes.
%
%   WHAT IS UNDER TEST: the mechanism open item #60's item 2 asks for -- a
%   carrier's `epochid.epochid` STRING turned into the id of the `epoch`
%   DOCUMENT `did2.convert.epochMint` minted for it.
%
%   ---------------------------------------------------------------------
%   THE FIXTURES ARE BUILT FROM WHAT THE WRITER EMITS
%   ---------------------------------------------------------------------
%   Not from a template, and never from a DID-side schema -- that is the
%   ground-truth rule, and building fixtures from our own schema is what let the
%   `distance_metadata` migrator ship having never worked on a real document.
%   The did_v1 builders below are COPIED from
%   tests/+did2/+unittest/testEpochMint.m, where each already carries its
%   writer citation (`+ndi/+session/dir.m:138` for the session,
%   `+ndi/element.m:367-378` for the element_epoch). The rest name their writer
%   here:
%
%     epochid block          `epochid_struct.epochid = epoch_id;` then
%                            ndi.document(<class>,'epochid',epochid_struct)
%                            -- +ndi/+daq/metadatareader.m:135-136, and the same
%                            two lines at +daq/+reader/image.m:219 and
%                            +daq/+reader/mfdaq.m:788.
%     the two response       stimulus_response_struct = struct(
%     epoch strings              'stimulator_epochid', ...epochid.epochid,
%                                'element_epochid',    ts_epoch_timeref.epoch)
%                            -- +ndi/+app/+stimulus/tuning_response.m:317-318
%     the parked string      `method_parameters.other.epochid`, written by
%                            +migrators_j/private/jMethodParameters.m
%     the epoch document     what did2.convert.epochMint/mintEpoch builds:
%                            `epoch ⊂ entity`, dep `session_id` -> the session
%                            DOCUMENT's base.id, block {local_identifier}.
%
%   A MIGRATED carrier still spells its epoch string the did_v1 way. V_eta
%   RETAINS the `epochid` superclass -- schemas/V_eta/stable/epochid.json
%   declares one field, `epochid`, mustBeNonEmpty -- so a guarded passthrough
%   such as `spikewaves` or `stimulus_presentation` reaches the batch with its
%   block intact. That is why the carrier fixtures below are V_eta-tagged and
%   still carry `epochid.epochid`.
%
%   The epoch-id strings are the real ones: `t00001`, `t00070`. epochMint's
%   header records that `t00070` restarts in every session directory, which is
%   the whole reason the key is a pair.
%
%   ---------------------------------------------------------------------
%   THE FOUR TESTS THAT MUST FAIL AGAINST A BROKEN RESOLVER
%   ---------------------------------------------------------------------
%   A suite where every test still passes against a gutted implementation is the
%   defect this file is written against (an agent replaced a partition check
%   with `return true` and 76 tests stayed green, because every other test
%   asserted it on data where it held). These four cannot:
%
%     testTheSameStringInTwoSessionsDoesNotFuse
%         reddens if the key becomes the string alone
%     testHalfAKeyResolvesToNothingNotToAGuess
%         reddens if a missing half falls back to matching on the other
%     testAPairWithNoEpochDocumentIsCountedNotSilent
%         reddens if the not-found counter is dropped
%     testResolveStillActuallyResolves
%         reddens against ANY implementation that has stopped resolving --
%         it asserts specific ids came back, not merely that nothing threw
%
%   ---------------------------------------------------------------------
%   THE MUTATION MATRIX -- MEASURED IN CI, AND ITS OWN GAPS NAMED
%   ---------------------------------------------------------------------
%   A green suite proves nothing about a suite that cannot fail, and no MATLAB
%   exists in the authoring container, so each mutation was applied to
%   `epochIndex.m` and run through the quick gate. BASELINE, run 31527912537
%   (`4f3f664`):
%
%       tests run  1095   passed 1094   FAILED 1
%         testBatchPassWiring/testCrossRepoDivergenceIsExactlyTheCheckedInTable
%
%   THAT ONE FAILURE IS PRE-EXISTING AND IS NOT THIS FILE'S. NDI-matlab
%   `a4d786a27` (2026-08-11 19:18:57 +0000) added a call to
%   `ndi.migrate.internal.imagedEntitySubjects` in `+ndi/+migrate/local.m`, and
%   that pass has no row in `crossRepoDivergenceTable()`. It persisted across
%   `7cabb9b`, `4f3f664`, `dac46a3` and `b637d8e`, so every figure below is a
%   DELTA against 1 pre-existing failure, never against a clean baseline.
%
%       M1  key on the STRING ALONE          run 31528302237   RED, 2 tests
%             testTheSameStringInTwoSessionsDoesNotFuse
%             testTheIndexAgreesWithEpochMintOnItsOwnOutput
%       M2  resolve HALF A KEY (string-only  run 31528773790   RED, 1 test
%           fallback when the session id           testHalfAKeyResolvesToNothingNotToAGuess
%           is missing)
%
%   M1 reddening the ANTI-DRIFT test as well as the fusion test is the result
%   worth having: it is the test that pins this class's key to
%   `did2.convert.epochMint`'s, and it is the one that would catch the key
%   changing under either of them.
%
%   THREE MUTATIONS WERE PREPARED AND NOT RUN, and the reason is not that they
%   were expected to pass:
%
%       M3  drop the `refused_no_epoch_document` counter      NOT RUN
%       M4  `resolve` returns '' unconditionally              NOT RUN
%       M5  `classDeclaresEpochEdge` matches any dependency   NOT RUN
%
%   The only channel that can execute MATLAB here is a push, and pushing a
%   knowingly-broken file to the shared branch is a hazard already recorded as a
%   finding (DID-schema `V_eta_OPEN_WORK.md` rows 86(f) and 88(b), commit
%   `c2dea42`: a container restart during the window leaves the mutation as the
%   file's last word, and a commit was once stacked on a mutation before its
%   revert landed). M1 and M2 were run that way before the rule was pointed out;
%   M3-M5 were stopped. **`testResolveStillActuallyResolves` and
%   `testAPairWithNoEpochDocumentIsCountedNotSilent` and the three schema-guard
%   tests are therefore UNPROVEN, not proven.** Anyone with a MATLAB can run the
%   three swaps -- each is a single exact-string substitution and each is
%   spelled out in the commit that recorded this matrix.
%
%   ALERT 209 IS THE SAME HAZARD ARRIVING BY A ROUTE NOBODY LISTED. CodeQL
%   raised "input argument might be unused" on `epochIndex.m:641` --
%   `pairKey`'s `sessionId`. It is unused ONLY under M1 (`k = localIdentifier`);
%   at every unmutated revision it is read by
%   `sprintf('%d:%s|%s', numel(sessionId), sessionId, localIdentifier)`. The
%   quick gate uploads a SARIF artifact on every run, so a mutation pushed to a
%   shared branch does not merely risk being left behind -- it is INGESTED by
%   the org's scanner and comes back as an alert against the real file, after
%   the revert has landed.
%
%   Run with:  results = runtests('did2.unittest.testEpochIndex');
%
%   See also: did2.convert.epochIndex, did2.convert.epochMint,
%   did2.validate.epochStrings.
tests = functiontests(localfunctions);
end

% ===================== denominators =====================================

function testDidNotRunAndRanAndFoundNothingAreDifferentReadings(testCase)
% The `silentLoss` failure in miniature: an all-zero report that never read its
% input must not be indistinguishable from one that read an empty batch.
idx = did2.convert.epochIndex();
verifyFalse(testCase, idx.report.ran, ...
    'an index built from no source must report ran=false');
verifyTrue(testCase, idx.report.vacuous);
verifyEqual(testCase, idx.report.bodies_inspected, 0);

idx2 = did2.convert.epochIndex(struct('migrated', {{}}));
verifyTrue(testCase, idx2.report.ran, ...
    'an EMPTY BATCH ran -- it just found nothing; that is not "did not run"');
verifyTrue(testCase, idx2.report.vacuous);
verifyEqual(testCase, idx2.report.bodies_inspected, 0);
end

function testTheDenominatorCountsEveryDocumentIncludingTheUnreadable(testCase)
% Unreadable documents are COUNTED, never dropped. Dropping them is what made
% `total_docs` read 0 on all five corpora while 221,813 documents went by.
batch = {epochDoc('epoch_1', 'sess_A', 't00001'), 42, sessionDoc('sess_A')};
idx = did2.convert.epochIndex(batch);
verifyEqual(testCase, idx.report.bodies_inspected, 3);
verifyEqual(testCase, idx.report.bodies_unreadable, 1);
verifyEqual(testCase, idx.report.epoch_documents_seen, 1);
end

% ===================== THE KEY IS THE PAIR ==============================

function testTheSameStringInTwoSessionsDoesNotFuse(testCase)
% THE measurement this class exists for. Corpus run 31508009545: 51,173 epoch
% strings, 8,433 distinct (session, id) pairs, 2,344 epochs that the string key
% alone would have FUSED. In corpus B it is 142 of 149 distinct ids.
%
% MUTATION TARGET: key on the string alone. This test is the one that reddens.
batch = { ...
    sessionDoc('sess_A'), sessionDoc('sess_B'), ...
    epochDoc('epoch_A', 'sess_A', 't00070'), ...
    epochDoc('epoch_B', 'sess_B', 't00070')};
idx = did2.convert.epochIndex(batch);

verifyEqual(testCase, idx.report.epoch_documents_seen, 2);
verifyEqual(testCase, idx.report.pairs_indexed, 2, ...
    'two sessions reusing one epoch string are TWO epochs');
verifyEqual(testCase, idx.report.distinct_local_identifiers, 1);
verifyEqual(testCase, idx.report.pairs_minus_strings, 1, ...
    'pairs_minus_strings is the number of epochs a string key would have fused');

verifyEqual(testCase, idx.resolve('sess_A', 't00070'), 'epoch_A');
verifyEqual(testCase, idx.resolve('sess_B', 't00070'), 'epoch_B');
verifyNotEqual(testCase, idx.resolve('sess_A', 't00070'), ...
    idx.resolve('sess_B', 't00070'), ...
    'the two sessions must NOT resolve to one epoch -- that is a silent merge');
end

function testHalfAKeyResolvesToNothingNotToAGuess(testCase)
% Exactly ONE epoch is indexed, so a string-only fallback would have a unique
% answer to fall back TO. It must still refuse.
%
% MUTATION TARGET: resolve half a key.
batch = {sessionDoc('sess_A'), epochDoc('epoch_A', 'sess_A', 't00070')};
idx = did2.convert.epochIndex(batch);
verifyEqual(testCase, idx.report.pairs_indexed, 1);

[id1, why1] = idx.resolve('', 't00070');
verifyEmpty(testCase, id1, ...
    'no session id is half a key; the unique epoch is NOT the answer');
verifyEqual(testCase, why1, 'refused_no_session_id');

[id2, why2] = idx.resolve('sess_A', '');
verifyEmpty(testCase, id2);
verifyEqual(testCase, why2, 'refused_no_local_identifier');

verifyEqual(testCase, idx.report.refused_no_session_id, 1);
verifyEqual(testCase, idx.report.refused_no_local_identifier, 1);
verifyEqual(testCase, idx.report.refused_total, 2);
verifyEqual(testCase, idx.report.resolve_hits, 0);
end

function testAPairWithNoEpochDocumentIsCountedNotSilent(testCase)
% A miss must leave a number behind. A resolver that answers '' without saying
% so turns "the epoch was never minted" into "nothing to see here".
%
% MUTATION TARGET: drop the not-found counter.
batch = {sessionDoc('sess_A'), epochDoc('epoch_A', 'sess_A', 't00070')};
idx = did2.convert.epochIndex(batch);

[id, why] = idx.resolve('sess_A', 't99999');
verifyEmpty(testCase, id);
verifyEqual(testCase, why, 'refused_no_epoch_document');
verifyEqual(testCase, idx.report.refused_no_epoch_document, 1);
verifyEqual(testCase, idx.report.refused_total, 1);
verifyEqual(testCase, idx.report.resolve_calls, 1, ...
    'the denominator moves on a MISS too, or the hit rate is unreadable');
end

function testResolveStillActuallyResolves(testCase)
% THE ANTI-GUTTING TEST. Any implementation that has stopped resolving -- one
% that returns '' unconditionally, or indexes nothing -- fails here, whatever
% the refusal counters say.
batch = { ...
    sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00001'), ...
    epochDoc('epoch_C', 'sess_A', 't00002')};
idx = did2.convert.epochIndex(batch);
verifyEqual(testCase, idx.resolve('sess_A', 't00001'), 'epoch_A');
verifyEqual(testCase, idx.resolve('sess_A', 't00002'), 'epoch_C');
verifyEqual(testCase, idx.report.resolve_hits, 2);
verifyEqual(testCase, idx.report.refused_total, 0);
verifyFalse(testCase, idx.report.vacuous);
end

function testAPairClaimedByTwoEpochsIsRefusedNotGuessed(testCase)
% Guessing which of two documents is the referent is the quiet decision that
% produces a graph nobody can audit later. epochMint refuses the mirror-image
% case (`skipped_ambiguous_session`) for the same reason.
batch = { ...
    sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00070'), ...
    epochDoc('epoch_A_dup', 'sess_A', 't00070')};
idx = did2.convert.epochIndex(batch);
verifyEqual(testCase, idx.report.epoch_documents_seen, 2);
verifyEqual(testCase, idx.report.pairs_indexed, 1);
verifyEqual(testCase, idx.report.pairs_ambiguous, 1);

[id, why] = idx.resolve('sess_A', 't00070');
verifyEmpty(testCase, id);
verifyEqual(testCase, why, 'refused_ambiguous_epoch');
end

function testAnEpochThatCannotKeyItselfIsCounted(testCase)
% An epoch document with no `local_identifier` is an epoch nothing can ever
% anchor to. It is a defect in whatever minted it, and it must be a number.
noLid = epochDoc('epoch_X', 'sess_A', 't00070');
noLid.epoch = struct('local_identifier', '');
noSid = epochDoc('epoch_Y', '', 't00071');
idx = did2.convert.epochIndex({noLid, noSid});
verifyEqual(testCase, idx.report.epoch_documents_seen, 2);
verifyEqual(testCase, idx.report.epoch_documents_without_local_identifier, 1);
verifyEqual(testCase, idx.report.epoch_documents_without_session_id, 1);
verifyEqual(testCase, idx.report.pairs_indexed, 0);
verifyTrue(testCase, idx.report.vacuous);
end

% ===================== reading a BODY ===================================

function testTwoEpochStringsOnOneBodyAreNotInterchangeable(testCase)
% `stimulus_response.stimulator_epochid` is the STIMULATOR's epoch and
% `.element_epochid` is the RECORDING ELEMENT's, mapped onto each other by
% syncgraph.time_convert (tuning_response.m:245-246, :317-318). They are two
% DIFFERENT epochs. Reading "whichever string this body has" resolves to the
% wrong one roughly half the time, silently -- so the source is NAMED.
batch = { ...
    sessionDoc('sess_A'), ...
    epochDoc('epoch_stim', 'sess_A', 't00003'), ...
    epochDoc('epoch_elem', 'sess_A', 't00009')};
idx = did2.convert.epochIndex(batch);

body = responseBody('sess_A', 't00009', 't00003');   % element, stimulator
verifyEqual(testCase, ...
    idx.resolveBody(body, 'stimulus_response.element_epochid'), 'epoch_elem');
verifyEqual(testCase, ...
    idx.resolveBody(body, 'stimulus_response.stimulator_epochid'), 'epoch_stim');
end

function testAskingForASourceTheBodyLacksIsNOTTheSameAsNoEpochString(testCase)
% TWO DIFFERENT FACTS, TWO DIFFERENT COUNTERS. "this document has no epoch
% string" and "this document HAS one, just not from the source you named" have
% different owners: the first is a document with nothing to resolve, the second
% is the wrong-epoch hazard `sourceName` exists to prevent. Folding them into
% one counter makes the second read as the first, which is an absence standing
% in for a mismatch -- the failure mode this project's rules name first.
%
% The shape is real: `stimulus_response` carries `element_epochid` AND
% `stimulator_epochid` (tuning_response.m:317-318) and a document may populate
% only one.
idx = did2.convert.epochIndex({sessionDoc('sess_A'), ...
    epochDoc('epoch_elem', 'sess_A', 't00009')});
onlyElement = responseBody('sess_A', 't00009', '');

[idA, whyA] = idx.resolveBody(onlyElement, 'stimulus_response.stimulator_epochid');
verifyEmpty(testCase, idA);
verifyEqual(testCase, whyA, 'refused_source_not_present');
verifyEqual(testCase, idx.report.refused_source_not_present, 1);
verifyEqual(testCase, idx.report.refused_no_epoch_string, 0, ...
    'the document DOES carry an epoch string -- do not count it as having none');

% and the source it DOES carry still resolves.
verifyEqual(testCase, ...
    idx.resolveBody(onlyElement, 'stimulus_response.element_epochid'), ...
    'epoch_elem');
end

function testABodyWithNoEpochStringIsRefusedByName(testCase)
idx = did2.convert.epochIndex({sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00070')});
[id, why] = idx.resolveBody(sessionDoc('sess_A'));
verifyEmpty(testCase, id);
verifyEqual(testCase, why, 'refused_no_epoch_string');
verifyEqual(testCase, idx.report.refused_no_epoch_string, 1);
end

% ===================== IT NEVER INVENTS AN EDGE =========================

function testTheSchemaDecidesWhichClassesMayCarryTheEdge(testCase)
% Measured over the built V_eta set on 2026-08-11: exactly FOUR classes declare
% an `epoch_id` dependency, against NINETEEN did_v1 classes that inherit the
% `epochid` superclass. The list is read off the SCHEMA here, not kept in the
% file, so it cannot go stale the first time a class gains the edge.
requireSchemaCache(testCase);
idx = did2.convert.epochIndex();
for c = {'acquisition_metadata_file', 'ingestion_manifest', ...
         'directed_relation', 'method_parameters'}
    verifyTrue(testCase, idx.classDeclaresEpochEdge(c{1}), ...
        sprintf('%s declares epoch_id in the built V_eta set', c{1}));
end
% The carriers. Every one of these inherits `epochid` in did_v1 and NONE of
% them can hold the edge -- that gap IS open item #60's remaining schema work.
for c = {'spikewaves', 'stimulus_presentation', 'stimulus_parameter', ...
         'openminds_stimulus', 'oneepoch', 'pyraview', 'binnedspikeratevm', ...
         'daqreader_epochdata_ingested', 'epochfiles_ingested'}
    verifyFalse(testCase, idx.classDeclaresEpochEdge(c{1}), ...
        sprintf('%s must NOT be stampable -- it declares no epoch_id', c{1}));
end
verifyFalse(testCase, idx.classDeclaresEpochEdge('no_such_class_anywhere'), ...
    '"we could not check" must never authorise a write');
end

function testStampRefusesAClassThatDoesNotDeclareTheEdge(testCase)
% Stamping the fifteen carriers is not a smaller version of the rewire; it is
% the invented-edge pattern with the sign flipped, and
% +did2/+validate/references.m:90 skips empty edges so nothing would ever see
% it. The refusal is COUNTED.
requireSchemaCache(testCase);
idx = did2.convert.epochIndex({sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00070')});
before = carrierBody('spikewaves', 'sess_A', 't00070');
[after, why] = idx.stampEpochEdge(before);
verifyEqual(testCase, why, 'refused_class_does_not_declare');
verifyEqual(testCase, after, before, 'a refusal must leave the body untouched');
verifyEqual(testCase, idx.report.stamp_refused_class_does_not_declare, 1);
verifyEqual(testCase, idx.report.stamp_edges_written, 0);
end

function testStampWritesTheEdgeOnADeclaringClassAndOnlyOnce(testCase)
% `method_parameters` is the one class that declares the edge, is emitted by
% pass 1, and has the epoch string PARKED for exactly this moment:
% +migrators_j/private/jMethodParameters.m writes it to `other.epochid`.
requireSchemaCache(testCase);
idx = did2.convert.epochIndex({sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00070')});

[stamped, why] = idx.stampEpochEdge( ...
    methodParametersBody('sess_A', 't00070'), 'method_parameters');
verifyEmpty(testCase, why);
verifyEqual(testCase, depValue(stamped, 'epoch_id'), 'epoch_A');
verifyEqual(testCase, idx.report.stamp_edges_written, 1);

% FIND-OR-CREATE, NOT CREATE: ndi.migrate.local re-reads every document on a
% second pass over the same dataset, so a re-stamp must be a refusal.
[again, why2] = idx.stampEpochEdge(stamped, 'method_parameters');
verifyEqual(testCase, why2, 'refused_already_populated');
verifyEqual(testCase, again, stamped);
verifyEqual(testCase, idx.report.stamp_edges_written, 1);
verifyEqual(testCase, idx.report.stamp_refused_already_populated, 1);
end

function testStampRefusesWhenThePairDoesNotResolve(testCase)
% A declaring class whose epoch was never minted gets NOTHING, not an empty
% edge. `acquisition_metadata_file.epoch_id` and `ingestion_manifest.epoch_id`
% are both mustBeNonEmpty, and an empty one validates clean today.
requireSchemaCache(testCase);
idx = did2.convert.epochIndex({sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00070')});
before = methodParametersBody('sess_A', 't99999');
[after, why] = idx.stampEpochEdge(before, 'method_parameters');
verifyEqual(testCase, why, 'refused_no_epoch_document');
verifyEqual(testCase, after, before);
verifyEqual(testCase, idx.report.stamp_refused_unresolved, 1);
verifyEqual(testCase, idx.report.stamp_edges_written, 0);
end

% ===================== the 19 -> 4 gap, as a number =====================

function testCarrierScanCountsTheGapItRefusesToClose(testCase)
% The instrument form of open item #60's remaining schema work: how many
% documents carry an epoch string, and how many of them belong to a class that
% could hold the edge. It WRITES NOTHING.
requireSchemaCache(testCase);
batch = { ...
    sessionDoc('sess_A'), ...
    epochDoc('epoch_A', 'sess_A', 't00070'), ...
    carrierBody('spikewaves', 'sess_A', 't00070'), ...
    carrierBody('stimulus_presentation', 'sess_A', 't00070'), ...
    methodParametersBody('sess_A', 't00070')};   % the one that CAN hold it
idx = did2.convert.epochIndex(batch);
rep = idx.scanCarriers(batch);

verifyEqual(testCase, rep.carriers_inspected, 5, ...
    'the denominator is every document, not every carrier');
verifyEqual(testCase, rep.carriers_with_epoch_string, 3);
verifyEqual(testCase, rep.carriers_class_does_not_declare_edge, 2);
verifyEqual(testCase, rep.carriers_class_declares_edge, 1);
verifyEqual(testCase, rep.carriers_resolvable, 1);
verifyEqual(testCase, rep.carriers_unresolvable, 0);
% The classes are NAMED, so the schema work is read off a run.
verifyTrue(testCase, ...
    isfield(rep.carriers_by_class_without_edge, 'spikewaves'));
verifyTrue(testCase, ...
    isfield(rep.carriers_by_class_without_edge, 'stimulus_presentation'));
% and nothing was written.
verifyEqual(testCase, rep.stamp_edges_written, 0);
end

function testCarrierScanOnAPreMintBatchIsVacuousNotClean(testCase)
% did2.validate.silentLoss runs at v1_to_v2.m:382, i.e. PASS 1, so anything
% measured there sees a pre-mint world (commit 203c1f7). An index built before
% the mint reports zero -- and `vacuous` is what stops that zero being read as
% "the strings resolve fine".
batch = {carrierBody('spikewaves', 'sess_A', 't00070'), ...
         carrierBody('stimulus_presentation', 'sess_A', 't00070')};
idx = did2.convert.epochIndex(batch);
verifyTrue(testCase, idx.report.ran);
verifyTrue(testCase, idx.report.vacuous, ...
    'no epoch document indexed -- every resolve below is a tautology');
verifyEqual(testCase, idx.report.pairs_indexed, 0);
[id, why] = idx.resolve('sess_A', 't00070');
verifyEmpty(testCase, id);
verifyEqual(testCase, why, 'refused_no_epoch_document');
end

% ===================== the published index is cross-checked =============

function testThePublishedIndexIsComparedAgainstTheBatch(testCase)
% did2.convert.resolveValidIntervals deliberately reads the BATCH rather than
% `result.epoch_mint.epoch_index`, for a good reason it states. The cost is that
% nothing has ever checked the two against each other. This does.
result = struct( ...
    'migrated', {{sessionDoc('sess_A'), ...
                  epochDoc('epoch_A', 'sess_A', 't00001'), ...
                  epochDoc('epoch_B', 'sess_A', 't00002')}}, ...
    'epoch_mint', struct('epoch_index', ...
        struct('session_id', {'sess_A', 'sess_A', 'sess_A'}, ...
               'local_identifier', {'t00001', 't00002', 't00003'}, ...
               'epoch_document_id', {'epoch_A', 'WRONG_ID', 'epoch_ghost'})));
idx = did2.convert.epochIndex(result);
verifyTrue(testCase, idx.report.published_index_present);
verifyEqual(testCase, idx.report.published_index_rows, 3);
verifyEqual(testCase, idx.report.published_rows_agreeing, 1);
verifyEqual(testCase, idx.report.published_rows_disagreeing, 1, ...
    'a published row naming a different id than the batch is a DIVERGENCE');
verifyEqual(testCase, idx.report.published_rows_only_published, 1, ...
    'an epoch in the index but not in the batch never reached result.migrated');
verifyEqual(testCase, idx.report.published_rows_only_batch, 0);
% THE BATCH WINS. resolve answers from it, not from the published row.
verifyEqual(testCase, idx.resolve('sess_A', 't00002'), 'epoch_B');
end

function testAnAbsentPublishedIndexIsNotADivergence(testCase)
% Absence is not evidence. A result with no `epoch_mint` block (a bare v1_to_v2
% call) must report `published_index_present` FALSE and zero divergence, not
% zero divergence alone.
result = struct('migrated', {{epochDoc('epoch_A', 'sess_A', 't00001')}});
idx = did2.convert.epochIndex(result);
verifyFalse(testCase, idx.report.published_index_present);
verifyEqual(testCase, idx.report.published_index_rows, 0);
verifyEqual(testCase, idx.report.published_rows_disagreeing, 0);
verifyEqual(testCase, idx.report.pairs_indexed, 1);
end

% ===================== ANTI-DRIFT: pinned to epochMint ==================

function testTheIndexAgreesWithEpochMintOnItsOwnOutput(testCase)
% THE ANTI-DRIFT TEST, and the reason this class may exist alongside the three
% hand-rolled copies of the same lookup. `did2.convert.epochMint`,
% `did2.convert.resolveValidIntervals` and
% `did2.validate.epochStringRetention` each carry a local `pairKey` with the
% same body. If this class's key ever diverges from the mint's, every string
% would resolve to nothing while looking like a data problem.
%
% So: run the REAL mint on a two-session batch that reuses one epoch string,
% then resolve through this class and require the two to agree number for
% number. Validation is OFF for the same reason testEpochMint's harness turns
% it off -- it needs the assembled V_eta schema set on DID_SCHEMA_PATH.
v1 = { ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    sessionBody('sd_B', 'sess_B', 'ts_2009'), ...
    elementEpochBody('ee_1', 'sess_A', 't00070', 'el_1'), ...
    elementEpochBody('ee_2', 'sess_B', 't00070', 'el_2'), ...
    elementEpochBody('ee_3', 'sess_A', 't00071', 'el_1')};
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
[out, mintReport] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');

verifyEqual(testCase, mintReport.epochs_minted, 3, ...
    'two sessions x t00070 plus one t00071 is THREE epochs, not two');
verifyEqual(testCase, mintReport.distinct_epoch_id_strings, 2);
verifyEqual(testCase, mintReport.pairs_minus_strings, 1);

idx = did2.convert.epochIndex(out);
verifyEqual(testCase, idx.report.pairs_indexed, mintReport.epochs_minted, ...
    'the index must find every epoch the mint minted');
verifyEqual(testCase, idx.report.pairs_minus_strings, ...
    mintReport.pairs_minus_strings, ...
    'the two fusion measurements are the same measurement');
verifyEqual(testCase, idx.report.published_rows_disagreeing, 0, ...
    'a disagreement here means the two pairKeys have drifted apart');
verifyEqual(testCase, idx.report.published_rows_only_published, 0);
verifyEqual(testCase, idx.report.published_rows_only_batch, 0);
verifyEqual(testCase, idx.report.published_index_rows, 3);

% and every pair the mint saw resolves through this class.
a = idx.resolve('sess_A', 't00070');
b = idx.resolve('sess_B', 't00070');
c = idx.resolve('sess_A', 't00071');
verifyNotEmpty(testCase, a);
verifyNotEmpty(testCase, b);
verifyNotEmpty(testCase, c);
verifyNotEqual(testCase, a, b, ...
    'one epoch string in two sessions must still be two epoch documents');
verifyEqual(testCase, idx.report.refused_total, 0);
end

% ===================== fixtures =========================================

function b = etaBody(className, superChain, id, sessionId, blockName, block, deps)
%ETABODY A migrated (V_eta-tagged) body. Same builder shape as
%   testValidIntervalDecompose's, with the session id lifted to a parameter
%   because everything here turns on two sessions being different.
b = struct();
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(superChain)
    supers(end+1) = struct('class_name', superChain{k}, ...
        'class_version', '1.0.0'); %#ok<AGROW>
end
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_eta');
if isempty(deps)
    b.depends_on = struct('name', {}, 'value', {});
else
    b.depends_on = deps;
end
b.base = struct('id', id, 'session_id', sessionId, 'name', 'fixture', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
if ~isempty(blockName)
    b.(blockName) = block;
end
end

function id = sessionDocIdFor(sessionId)
%SESSIONDOCIDFOR The session DOCUMENT's base.id -- NOT the base.session_id its
%   siblings carry. ndi.document.m:57 mints base.id from a fresh ndi.ido();
%   +ndi/session.m:215 sets base.session_id from session.id() separately. The
%   two are visibly different strings here so a test that confused them would
%   fail rather than pass by coincidence.
id = ['sd_' sessionId];
end

function b = sessionDoc(sessionId)
b = etaBody('session', {'entity'}, sessionDocIdFor(sessionId), sessionId, ...
    'session', struct('reference', 'fixture_session'), []);
end

function b = epochDoc(id, sessionId, localIdentifier)
%EPOCHDOC What did2.convert.epochMint/mintEpoch builds, field for field.
b = etaBody('epoch', {'entity'}, id, sessionId, 'epoch', ...
    struct('local_identifier', localIdentifier), ...
    struct('name', {'session_id'}, 'value', {sessionDocIdFor(sessionId)}));
end

function b = carrierBody(className, sessionId, epochString)
%CARRIERBODY A migrated GUARDED PASSTHROUGH still carrying its did_v1 epoch id.
%   The `epochid` block survives migration verbatim: V_eta retains the class
%   (schemas/V_eta/stable/epochid.json, one field `epochid`, mustBeNonEmpty) and
%   both `spikewaves` and `stimulus_presentation` keep it in their superclass
%   chain. The v1 shape is `epochid_struct.epochid = epoch_id`
%   (+ndi/+daq/metadatareader.m:135).
b = etaBody(className, {'base', 'epochid'}, ...
    [className '_' sessionId '_' epochString], sessionId, ...
    'epochid', struct('epochid', epochString), []);
end

function b = responseBody(sessionId, elementEpoch, stimulatorEpoch)
%RESPONSEBODY +ndi/+app/+stimulus/tuning_response.m:317-318. The class does NOT
%   carry the `epochid` superclass -- its template superclasses are base +
%   stimulus_response -- which is why these two strings were invisible to every
%   epoch reader until did2.validate.epochStrings.
b = etaBody('stimulus_response_scalar', {'base', 'stimulus_response'}, ...
    ['resp_' sessionId], sessionId, 'stimulus_response', ...
    struct('element_epochid', elementEpoch, ...
           'stimulator_epochid', stimulatorEpoch), []);
end

function b = methodParametersBody(sessionId, epochString)
%METHODPARAMETERSBODY The PARKED string.
%   +migrators_j/private/jMethodParameters.m writes the v1 `epochid.epochid`
%   into `method_parameters.other.epochid` precisely so a batch pass can collect
%   it once the epoch documents exist.
b = etaBody('method_parameters', {'base'}, ...
    ['mp_' sessionId '_' epochString], sessionId, 'method_parameters', ...
    struct('other', struct('epochid', epochString)), []);
end

% ---- did_v1 bodies, COPIED from tests/+did2/+unittest/testEpochMint.m ----
% Kept identical rather than re-derived: those two builders already carry their
% writer citations, and a second, differently-shaped `element_epoch` fixture in
% the same suite is a second chance for the two to disagree about what a did_v1
% document looks like.

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 `session` document. WRITER +ndi/+session/dir.m:138.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/session.json', ...
    'validation',         '$NDISCHEMAPATH/session.json', ...
    'class_name',         'session', ...
    'property_list_name', 'session', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', reference);
end

function v1 = elementEpochBody(docId, sessionId, epochId, elementId)
%ELEMENTEPOCHBODY A did_v1 `element_epoch` body. WRITER +ndi/element.m:367-378.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/element_epoch.json', ...
    'validation',         '$NDISCHEMAPATH/element_epoch_schema.json', ...
    'class_name',         'element_epoch', ...
    'property_list_name', 'element_epoch', ...
    'class_version',      1, ...
    'superclasses',       [ struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
                            struct('definition', '$NDIDOCUMENTPATH/epochid.json')]);
v1.depends_on = struct('name', 'element_id', 'value', elementId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochid = struct('epochid', epochId);
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0, 452.709856]);
end

% ===================== helpers ==========================================

function v = depValue(b, name)
%DEPVALUE Read an edge off a body STRUCT, accepting both key spellings.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if ~strcmp(char(deps(k).name), name); continue; end
    for key = {'value', 'document_id', 'id'}
        if isfield(deps(k), key{1}) && ~isempty(deps(k).(key{1}))
            v = char(deps(k).(key{1}));
            return;
        end
    end
end
end

function requireSchemaCache(testCase)
%REQUIRESCHEMACACHE Skip LOUDLY when the built V_eta set is not on the path.
%   The guard tests read the `epoch_id` declaration off the SCHEMA, so without
%   it they would assert nothing and pass. A skip is "did not look", NOT "the
%   guard holds", and it has to say so.
ok = false;
try
    c = did2.schema.cache.shared();
    c.getClass('method_parameters');
    ok = true;
catch
    ok = false;
end
if ~ok
    assumeFail(testCase, ['no readable schema cache (DID_SCHEMA_PATH unset?) ' ...
        '-- this test reads the epoch_id declaration off the BUILT V_eta set. ' ...
        'SKIPPED here means "did not look", not "the guard holds".']);
end
end
