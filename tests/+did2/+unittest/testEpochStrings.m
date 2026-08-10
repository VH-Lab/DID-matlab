function tests = testEpochStrings
%TESTEPOCHSTRINGS The ONE epoch-string reader, pinned source by source, plus the
%   source-vs-migrated retention counter built on it.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   nothing in this file has been run. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion.
%
%   NEW FILE, deliberately. `testMigratorsJ.m` is owned by another session and is
%   not touched; `testEpochMint.m` pins the MINT's behaviour and every one of its
%   assertions must keep passing.
%
%   ---------------------------------------------------------------------
%   WHY EVERY SOURCE GETS ITS OWN TEST
%   ---------------------------------------------------------------------
%   There have been three epoch-string readers in this toolbox and each had a
%   different blind spot, none of which was visible from its output:
%
%     sourceCensus/epochIdOf   blocks named `epochid`/`epoch_id` ONLY. Its
%                              docstring claimed it also read
%                              `epochfiles_ingested`; it never has, and the
%                              claim survived until 2026-08-10. Corpus B's
%                              2,484 ingestion manifests contributed ZERO.
%     epochMint/epochStringOf  three sources, and blind to the stimulus-response
%                              family, which does not carry the `epochid`
%                              superclass at all.
%     each migrator            its own block, by hand.
%
%   A reader that silently omits a source produces a count that looks clean, and
%   the omission is invisible precisely because the number it produces is
%   plausible. So: one reader, and one test per source that FAILS if that source
%   stops being read. A test that exercised the reader through "some fixture with
%   an epoch id" would pass with four of the five sources deleted.
%
%   Run with:  results = runtests('did2.unittest.testEpochStrings');

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function v = valueOfSource(hits, source)
v = '';
for k = 1:numel(hits)
    if strcmp(hits(k).source, source); v = hits(k).value; return; end
end
end

function tf = hasSource(hits, source)
tf = any(strcmp({hits.source}, source));
end

function b = baseOnly(className, docId, sessionId)
b = struct();
b.document_class = struct('class_name', className, 'class_version', 1, ...
    'superclasses', struct('class_name', 'base', 'class_version', 1));
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', docId, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-03-23T13:47:40.237Z');
end

% ===================== one test per READ source ========================

function testSourceEpochidMixin(tc)
%   git show origin/main:src/ndi/ndi_common/database_documents/epochid.json
%      "epochid": { "epochid": "" }
%   15 NDI classes carry this superclass and 11+ live sites match
%   `epochid.epochid` by exact_string.
b = baseOnly('element_epoch', 'doc1', 'sess1');
b.epochid = struct('epochid', 't00003');
hits = did2.validate.epochStrings(b);
tc.verifyEqual(numel(hits), 1);
tc.verifyEqual(valueOfSource(hits, 'epochid'), 't00003');
end

function testSourceEpochidMixinUnderTheVEtaSpelling(tc)
% universalRenames rewrites the BLOCK name on some paths; both are accepted.
b = baseOnly('element_epoch', 'doc1', 'sess1');
b.epoch_id = struct('epoch_id', 't00003');
hits = did2.validate.epochStrings(b);
tc.verifyEqual(valueOfSource(hits, 'epochid'), 't00003');
end

function testSourceEpochfilesIngested(tc)
%   THE SOURCE THE CENSUS NEVER READ. It is a PLAIN CHAR FIELD inside the
%   class's own block, so a reader that visits blocks NAMED `epochid` cannot
%   reach it:
%
%   git show origin/main:src/ndi/ndi_common/database_documents/ingestion/epochfiles_ingested.json
%      "epochfiles_ingested": { "epoch_id": "", "epochprobemap": "", ... }
b = baseOnly('epochfiles_ingested', 'doc2', 'sess1');
b.epochfiles_ingested = struct('epoch_id', 't00070', 'epochprobemap', '');
hits = did2.validate.epochStrings(b);
tc.verifyEqual(numel(hits), 1);
tc.verifyEqual(valueOfSource(hits, 'epochfiles_ingested'), 't00070');
end

function testSourceParkedMethodParameters(tc)
% Parked by +migrators_j/private/jMethodParameters.m:120-127 precisely so a
% batch pass can collect it. Present only on MIGRATED bodies.
b = baseOnly('method_parameters', 'doc3', 'sess1');
b.method_parameters = struct('name', 'extraction', ...
    'method_parameters', struct('variable', {}, 'value', {}), ...
    'other', struct('epochid', 't00011'));
hits = did2.validate.epochStrings(b);
tc.verifyEqual(valueOfSource(hits, 'method_parameters'), 't00011');
end

function testSourceStimulusResponseElementEpochid(tc)
%   THE SOURCE THIS WHOLE CHANGE EXISTS FOR.
%
%   git show origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_response_scalar.json
%      "superclasses": [ base.json, stimulus_response.json ]        <- NO epochid
%   git show origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_response.json
%      "stimulus_response": { "stimulator_epochid": [], "element_epochid": [] }
%
%   So no `epochid` block exists on this family and both previous readers
%   returned nothing for every one of its documents.
b = baseOnly('stimulus_response_scalar', 'doc4', 'sess1');
b.stimulus_response = struct('stimulator_epochid', '', ...
    'element_epochid', 't00003');
hits = did2.validate.epochStrings(b);
tc.verifyEqual(numel(hits), 1);
tc.verifyEqual(valueOfSource(hits, 'stimulus_response.element_epochid'), 't00003');
end

function testSourceStimulusResponseStimulatorEpochid(tc)
b = baseOnly('stimulus_response_scalar', 'doc4', 'sess1');
b.stimulus_response = struct('stimulator_epochid', 't00009', ...
    'element_epochid', '');
hits = did2.validate.epochStrings(b);
tc.verifyEqual(valueOfSource(hits, 'stimulus_response.stimulator_epochid'), 't00009');
end

function testTheTwoStimulusEpochsAreBothReturnedAndNotConflated(tc)
%   THEY ARE TWO DIFFERENT EPOCHS, not two spellings of one. From the writer:
%
%   git show origin/main:src/ndi/+ndi/+app/+stimulus/tuning_response.m
%     :241-243  stim_timeref = ndi.time.timereference(ndi_stim_obj, ..., ...
%                   stim_doc.document_properties.epochid.epochid, 0);
%     :245-246  [..., ts_epoch_timeref, ...] = E.syncgraph.time_convert( ...
%                   stim_timeref, ..., ndi_timeseries_obj, ...
%                   ndi.time.clocktype('dev_local_time'));
%     :317-318  'stimulator_epochid', stim_doc...epochid.epochid, ...
%               'element_epochid',    ts_epoch_timeref.epoch
%
%   time_convert MAPS the stimulator's epoch onto the recording element's. A
%   reader returning one string would mint one of the two epochs and lose the
%   other -- the same single-answer assumption that made the census blind here.
b = baseOnly('stimulus_response_scalar', 'doc4', 'sess1');
b.stimulus_response = struct('stimulator_epochid', 't00009', ...
    'element_epochid', 't00003');
hits = did2.validate.epochStrings(b);
tc.verifyEqual(numel(hits), 2);
tc.verifyEqual(valueOfSource(hits, 'stimulus_response.element_epochid'), 't00003');
tc.verifyEqual(valueOfSource(hits, 'stimulus_response.stimulator_epochid'), 't00009');
end

% ===================== the DECLINED source =============================

function testSyncEndpointsAreDeclinedNotSilentlyMissed(tc)
% The sync endpoints are real epoch strings (5,316 documents in the last
% measured census) that this reader deliberately does not return. The point of
% the second output is that the gap is a NUMBER, not a silence: if someone later
% decides to read them, this test tells them exactly where they were parked.
b = baseOnly('syncrule_mapping', 'doc5', 'sess1');
b.syncrule_mapping = struct( ...
    'epochnode_a', struct('epoch_id', 't00003', 'epoch_clock', 'dev_local_time'), ...
    'epochnode_b', struct('epoch_id', 't00004', 'epoch_clock', 'dev_local_time'));
[hits, declined] = did2.validate.epochStrings(b);
tc.verifyEmpty(hits);
tc.verifyEqual(numel(declined), 2);
tc.verifyEqual(sort({declined.value}), {'t00003', 't00004'});
end

function testSyncEndpointsAreAlsoFoundAfterThe58Reshape(tc)
% +migrators_j/syncrule_mapping.m's passthrough nests the id one level down,
% under `time_reference`. Both shapes are recognised, so the declined count does
% not silently halve after pass 1.
b = baseOnly('syncrule_mapping', 'doc5', 'sess1');
node = struct('time_reference', ...
    struct('kind', 'epoch_bounded_reference', 'epoch_clock', 'dev_local_time', ...
           'epoch_id', 't00003'));
b.syncrule_mapping = struct('epochnode_a', node, 'epochnode_b', node);
[~, declined] = did2.validate.epochStrings(b);
tc.verifyEqual(numel(declined), 2);
end

% ===================== negative cases ==================================

function testAnEmptyStringIsNotAHit(tc)
% NDI writes `[]` into an unset template field, which jsondecode turns into an
% empty. "Present and empty" must not count as an epoch: a mint keyed on '' would
% fuse every unset document in a session into one epoch entity.
b = baseOnly('stimulus_response_scalar', 'doc6', 'sess1');
b.stimulus_response = struct('stimulator_epochid', '', 'element_epochid', '');
tc.verifyEmpty(did2.validate.epochStrings(b));
end

function testANonStructBodyReturnsEmptyRatherThanThrowing(tc)
tc.verifyEmpty(did2.validate.epochStrings([]));
tc.verifyEmpty(did2.validate.epochStrings('not a body'));
end

% ===================== the retention counter ===========================

function testRetentionDenominatorIsStatedEvenOnEmptyInput(tc)
% Rule 5: an instrument states its denominator FIRST and unconditionally, and
% "did not run" must be distinguishable from "ran and found nothing".
r = did2.validate.epochStringRetention({}, {});
tc.verifyTrue(r.ran);
tc.verifyEqual(r.v1_documents_inspected, 0);
tc.verifyEqual(r.v1_pairs, 0);
tc.verifyEqual(r.pairs_dropped, 0);
end

function testAPassedThroughDocumentDropsNothing(tc)
% The state the stimulus-response suppression produces: the document survives
% whole, so its epoch string is still readable on the migrated side.
v1 = baseOnly('stimulus_response_scalar', 'doc4', 'sess1');
v1.stimulus_response = struct('stimulator_epochid', 't00009', ...
    'element_epochid', 't00003');
r = did2.validate.epochStringRetention({v1}, {v1});
tc.verifyEqual(r.v1_pairs, 2);
tc.verifyEqual(r.retained_as_string, 2);
tc.verifyEqual(r.pairs_dropped, 0);
end

function testAFoldThatEatsTheFieldIsCaughtAndNamesItsClass(tc)
% THE DEFECT THIS INSTRUMENT EXISTS FOR. The migrated document is well-formed,
% complete by its own schema, and simply smaller than its input. silentLoss sees
% no empty edge, isFragment sees no fragment, and the vacuous-field check sees no
% blank -- because the field is not there at all.
v1 = baseOnly('stimulus_response_scalar', 'doc4', 'sess1');
v1.stimulus_response = struct('stimulator_epochid', '', ...
    'element_epochid', 't00003');
folded = baseOnly('harmonic_component_calculation', 'doc4', 'sess1');
r = did2.validate.epochStringRetention({v1}, {folded});
tc.verifyEqual(r.v1_pairs, 1);
tc.verifyEqual(r.retained_total, 0);
tc.verifyEqual(r.pairs_dropped, 1);
tc.verifyTrue(isfield(r.dropped_by_v1_class, 'stimulus_response_scalar'));
tc.verifyEqual(r.dropped_by_v1_class.stimulus_response_scalar, 1);
tc.verifyEqual(r.dropped_detail(1).epoch_string, 't00003');
end

function testAMintedEpochDocumentCountsAsRetained(tc)
% The other honest outcome: the string became a document. Matched on
% (base.session_id, epoch.local_identifier) -- exactly epochMint's key.
v1 = baseOnly('element_epoch', 'doc1', 'sess1');
v1.epochid = struct('epochid', 't00003');
folded = baseOnly('acquisition_epoch', 'doc1', 'sess1');
ep = baseOnly('epoch', 'epochdoc1', 'sess1');
ep.epoch = struct('local_identifier', 't00003');
r = did2.validate.epochStringRetention({v1}, {folded, ep});
tc.verifyEqual(r.epoch_documents_seen, 1);
tc.verifyEqual(r.retained_as_epoch_document, 1);
tc.verifyEqual(r.retained_as_string, 0);
tc.verifyEqual(r.pairs_dropped, 0);
end

function testTheKeyIsThePairSoACrossSessionReuseIsNotFalseRetention(tc)
% 142 of corpus B's 149 distinct epoch-id strings are carried by documents in
% more than one session. Counting distinct STRINGS would report this corpus fully
% retained while session 2's epoch had vanished.
a = baseOnly('element_epoch', 'docA', 'sess1');
a.epochid = struct('epochid', 't00070');
b = baseOnly('element_epoch', 'docB', 'sess2');
b.epochid = struct('epochid', 't00070');
kept = baseOnly('element_epoch', 'docA', 'sess1');
kept.epochid = struct('epochid', 't00070');
r = did2.validate.epochStringRetention({a, b}, {kept});
tc.verifyEqual(r.v1_pairs, 2);
tc.verifyEqual(r.pairs_dropped, 1);
tc.verifyEqual(r.dropped_detail(1).session_id, 'sess2');
end

function testDeclinedStringsAreExcludedFromTheDenominator(tc)
% A source the reader will not read must not inflate the retention rate NOR be
% counted as a drop. It is reported on its own line instead.
v1 = baseOnly('syncrule_mapping', 'doc5', 'sess1');
v1.syncrule_mapping = struct( ...
    'epochnode_a', struct('epoch_id', 't00003'), ...
    'epochnode_b', struct('epoch_id', 't00004'));
r = did2.validate.epochStringRetention({v1}, {});
tc.verifyEqual(r.v1_pairs, 0);
tc.verifyEqual(r.pairs_dropped, 0);
tc.verifyEqual(r.v1_declined, 2);
tc.verifyEqual(r.v1_declined_distinct, 2);
end

function testUnreadableDocumentsAreCountedNotDropped(tc)
% The silentLoss failure, one level up: a census that cannot read its input must
% say so rather than report a clean zero.
r = did2.validate.epochStringRetention({'{ not json'}, {});
tc.verifyEqual(r.v1_documents_inspected, 1);
tc.verifyEqual(r.v1_documents_unreadable, 1);
end
