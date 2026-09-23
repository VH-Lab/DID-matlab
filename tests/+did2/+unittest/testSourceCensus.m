function tests = testSourceCensus
%TESTSOURCECENSUS Tests for did2.validate.sourceCensus -- the v1 SOURCE census
%   that answers the three questions the epoch, time-reference and
%   interaction-purpose builds are each blocked on measuring.
%
%   WHY THE FIRST TESTS ARE NOT ABOUT THE QUESTIONS. The instrument this one
%   sits beside (silentLoss) shipped with NO tests and measured NOTHING for two
%   days, on five corpora, while its zeros were quoted as evidence. So the
%   first three tests here check only that the census can SEE its input and
%   that an all-zero report cannot be produced by a broken read. A counter that
%   cannot distinguish "nothing found" from "nothing read" is worse than none.

tests = functiontests(localfunctions);
end

% ===================== can it see its input? ===============================

function testTotalDocsCountsWhatWasHandedIn(testCase)
docs = {body('session', 'sess_doc_1'), body('subject', 'sub_1')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.total_docs, 2, ...
    'the census must count the documents it was handed');
verifyEqual(testCase, rep.skipped_docs, 0);
end

function testUnreadableInputIsCountedNotSilentlyDropped(testCase)
rep = did2.validate.sourceCensus({'{ not json'});
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.skipped_docs, 1, ...
    'an unreadable document must be counted, never discarded');
end

function testAcceptsJsonTextAsWellAsStructs(testCase)
% The corpus tests read the corpus off disk as JSON TEXT and never decode it
% themselves, so a census that only accepted structs would measure nothing
% there while passing every struct-based test here.
b = body('session', 'sess_from_json');
rep = did2.validate.sourceCensus({jsonencode(b)});
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.skipped_docs, 0);
verifyEqual(testCase, rep.session_doc_count, 1);
end

% ===================== question 1: epoch id shape ==========================

function testEpochIdsAreBucketedByPrefix(testCase)
docs = { ...
    withEpoch(body('spikewaves', 'w1'), 'epoch_aaa'), ...
    withEpoch(body('spikewaves', 'w2'), 'epoch_aaa'), ...
    withEpoch(body('spikewaves', 'w3'), 'epoch_bbb'), ...
    withEpoch(body('spikewaves', 'w4'), 'whole_session_ref1'), ...
    withEpoch(body('spikewaves', 'w5'), 'something_else')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.docs_with_epoch_id, 5);
verifyEqual(testCase, rep.distinct_epoch_ids, 4);
verifyEqual(testCase, prefixRow(rep, 'epoch_').distinct_ids, 2);
verifyEqual(testCase, prefixRow(rep, 'epoch_').doc_count, 3);
verifyEqual(testCase, prefixRow(rep, 'whole_session_').doc_count, 1);
verifyEqual(testCase, prefixRow(rep, 'other').doc_count, 1);
end

function testManyElementsInOneRecordingEpochIsNotAHazard(testCase)
% THE MEASURE THIS TEST PINS DOWN. A first draft counted every id whose
% documents named more than one element as a fusion hazard -- which is the
% normal case for a recording epoch, and would have flagged nearly everything.
% Only the DETERMINISTIC ids fuse.
docs = { ...
    withElement(withEpoch(body('spikewaves', 'w1'), 'epoch_aaa'), 'el_1'), ...
    withElement(withEpoch(body('spikewaves', 'w2'), 'epoch_aaa'), 'el_2'), ...
    withElement(withEpoch(body('spikewaves', 'w3'), 'epoch_aaa'), 'el_3')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.synthetic_epoch_id_count, 0, ...
    'three elements sharing one recording epoch is normal, not a collision');
end

function testSyntheticEpochIdReportsItsFusionFactor(testCase)
docs = { ...
    withElement(withEpoch(body('spikewaves', 'w1'), 'whole_session_r'), 'el_1'), ...
    withElement(withEpoch(body('spikewaves', 'w2'), 'whole_session_r'), 'el_2'), ...
    withElement(withEpoch(body('spikewaves', 'w3'), 'epoch_real'), 'el_3')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.synthetic_epoch_id_count, 1);
verifyEqual(testCase, rep.synthetic_epoch_ids(1).epoch_id, 'whole_session_r');
verifyEqual(testCase, rep.synthetic_epoch_ids(1).distinct_elements, 2, ...
    'grouping on this id would fuse two per-element spans into one document');
end

function testOneEpochIdUnderTwoSessionsIsReported(testCase)
% Prefix-blind: a recording epoch belongs to one session, so this cannot be
% legitimate whatever the id looks like.
d1 = withEpoch(body('spikewaves', 'w1'), 'epoch_shared');
d2 = withEpoch(body('spikewaves', 'w2'), 'epoch_shared');
d2.base.session_id = 'sess_OTHER';
rep = did2.validate.sourceCensus({d1, d2});
verifyEqual(testCase, rep.cross_session_epoch_id_count, 1);
verifyEqual(testCase, rep.cross_session_epoch_ids{1}, 'epoch_shared');
end

% ===================== question 2: is there a session doc? =================

function testSessionDocumentsAreCountedSeparatelyFromSessionIds(testCase)
% The two numbers are reported side by side and NOT joined: whether a session
% document's base.id equals the base.session_id its siblings carry is not
% verified anywhere, so the census must not quietly assume it.
docs = {body('session', 'sess_doc'), body('subject', 'sub_1'), body('subject', 'sub_2')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.session_doc_count, 1);
verifyEqual(testCase, rep.distinct_session_ids, 1);
verifyEqual(testCase, rep.session_doc_ids{1}, 'sess_doc');
end

function testNoSessionDocumentIsReportedAsZeroNotAsAbsentField(testCase)
rep = did2.validate.sourceCensus({body('subject', 'sub_1')});
verifyEqual(testCase, rep.session_doc_count, 0);
verifyEqual(testCase, rep.distinct_session_ids, 1, ...
    'the documents still name a session even when no session document exists');
end

% ===================== question 3: approach coverage ======================

function testSubjectsPerApproachEpochIsDistributed(testCase)
% epoch A: two presentations naming two different stimulators -> 2 subjects
% epoch B: two presentations naming the SAME stimulator         -> 1 subject
docs = { ...
    withEpoch(body('openminds_stimulus', 'ap_1'), 'epoch_A'), ...
    withEpoch(body('openminds_stimulus', 'ap_2'), 'epoch_B'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p1'), 'epoch_A'), 'stim_1'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p2'), 'epoch_A'), 'stim_2'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p3'), 'epoch_B'), 'stim_9'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p4'), 'epoch_B'), 'stim_9')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.approach_doc_count, 2);
verifyEqual(testCase, rep.approach_epochs, 2);
verifyEqual(testCase, rep.approach_epochs_no_presentation, 0);
verifyEqual(testCase, nEpochsWith(rep, 1), 1);
verifyEqual(testCase, nEpochsWith(rep, 2), 1);
end

function testTheOtherSidesDenominatorIsReported(testCase)
% Corpus Dab reported 635 approaches and 635 approach epochs with NO
% presentation document -- every single one. That is either the real answer or a
% census that never saw a presentation, and the report as first shipped could not
% tell those apart. This file exists to stop exactly that, and shipped with it.
docs = { ...
    withEpoch(body('openminds_stimulus', 'ap_1'), 'epoch_A'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p1'), 'epoch_B'), 'stim_1'), ...
    body('stimulus_presentation', 'p2')};          % no epoch id at all
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.approach_epochs_no_presentation, 1);
verifyEqual(testCase, rep.presentation_doc_count, 2, ...
    'the census saw two presentations -- the zero above is about epochs, not sight');
verifyEqual(testCase, rep.presentation_docs_with_epoch, 1);
end

function testEmptyDistributionYieldsNoRowsAtAll(testCase)
% Dab's log printed one row with a BLANK subject count against 0 epochs, from a
% distribution that should have been empty. A phantom row in a report is a
% number someone will read.
docs = {withEpoch(body('openminds_stimulus', 'ap_1'), 'epoch_lonely')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, numel(rep.subjects_per_approach_epoch), 0, ...
    'no approach epoch has a presentation, so the distribution has NO rows');
end

function testApproachEpochWithNoPresentationIsCountedNotDropped(testCase)
docs = {withEpoch(body('openminds_stimulus', 'ap_1'), 'epoch_lonely')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.approach_doc_count, 1);
verifyEqual(testCase, rep.approach_epochs, 1);
verifyEqual(testCase, rep.approach_epochs_no_presentation, 1, ...
    'an approach whose epoch has no presentation must be visible, not absent');
end

function testCamelCaseClassNamesAreMatched(testCase)
% V_eta is snake_case and NDI is camelCase. `demo_ndi` was dispositioned DELETE
% off a grep against a repository that has never contained that string, so the
% class match here normalises both sides rather than picking a spelling.
docs = { ...
    withEpoch(body('openmindsStimulus', 'ap_1'), 'epoch_A'), ...
    withElement(withEpoch(body('stimulusPresentation', 'p1'), 'epoch_A'), 'stim_1')};
rep = did2.validate.sourceCensus(docs);
verifyEqual(testCase, rep.approach_doc_count, 1, ...
    'openmindsStimulus and openminds_stimulus are the same class');
verifyEqual(testCase, nEpochsWith(rep, 1), 1);
end

% ===================== it must never break a run ==========================

function testNeverRaisesOnMalformedInput(testCase)
verifyWarningFree(testCase, @() did2.validate.sourceCensus({}));
verifyWarningFree(testCase, @() did2.validate.sourceCensus({[]}));
verifyWarningFree(testCase, @() did2.validate.sourceCensus(struct([])));
verifyWarningFree(testCase, @() did2.validate.sourceCensus({struct('a', 1)}));
end

% ===================== helpers ============================================

function b = body(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end

function b = withEpoch(b, epochId)
b.epochid = struct('epochid', epochId);
end

function b = withElement(b, elementId)
b.depends_on = struct('name', 'stimulus_element_id', 'value', elementId);
end

function row = prefixRow(rep, prefix)
idx = find(strcmp({rep.epoch_id_by_prefix.prefix}, prefix), 1);
row = rep.epoch_id_by_prefix(idx);
end

function n = nEpochsWith(rep, nSubjects)
n = 0;
d = rep.subjects_per_approach_epoch;
idx = find([d.n_subjects] == nSubjects, 1);
if ~isempty(idx); n = d(idx).n_epochs; end
end

function testApproachAndPresentationEpochPrefixesAreReportedSeparately(testCase)
% THE DAB QUESTION. 635 approaches and 1,242 presentations that share NO epoch
% id, on two classes with the SAME `epochid` superclass and the SAME
% `stimulus_element_id` dependency. The pooled prefix histogram cannot say why:
% it mixes every class together. This is the per-class cross-tab that can.
bodies = { ...
    withEpoch(body('openminds_stimulus', 'ap_1'), 'epoch_AAA'), ...
    withEpoch(body('openminds_stimulus', 'ap_2'), 'epoch_BBB'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p1'), 't00001'), 'stim_1'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p2'), 't00002'), 'stim_2')};
r = did2.validate.sourceCensus(bodies);

% disjoint by construction -- and the ZERO is the finding, not the absence of one
verifyEqual(testCase, r.approach_presentation_shared_epochs, 0);

ap = prefixRow(r.approach_epoch_prefixes, 'epoch_');
verifyEqual(testCase, ap.n_distinct, 2);
verifyEqual(testCase, ap.n_docs, 2);
verifyEqual(testCase, prefixRow(r.approach_epoch_prefixes, 'other').n_docs, 0);

pr = prefixRow(r.presentation_epoch_prefixes, 'other');
verifyEqual(testCase, pr.n_distinct, 2);
verifyEqual(testCase, pr.n_docs, 2);
verifyEqual(testCase, prefixRow(r.presentation_epoch_prefixes, 'epoch_').n_docs, 0);
end

function testSharedEpochsAreCountedWhenTheyDoOverlap(testCase)
% The inverse case, so a hard-coded 0 could not pass the test above.
bodies = { ...
    withEpoch(body('openminds_stimulus', 'ap_1'), 'epoch_A'), ...
    withElement(withEpoch(body('stimulus_presentation', 'p1'), 'epoch_A'), 'stim_1')};
r = did2.validate.sourceCensus(bodies);
verifyEqual(testCase, r.approach_presentation_shared_epochs, 1);
end

function testEveryPrefixBucketPrintsEvenAtZero(testCase)
% Suppressing empty buckets would hide the answer: WHICH bucket is empty is
% the whole finding here.
r = did2.validate.sourceCensus({withEpoch(body('openminds_stimulus', 'a'), 'epoch_A')});
verifyEqual(testCase, numel(r.approach_epoch_prefixes), 3);
verifyEqual(testCase, {r.approach_epoch_prefixes.prefix}, ...
    {'epoch_', 'whole_session_', 'other'});
end

function testPrefixTallyFieldsSurviveAnEmptyCorpus(testCase)
% The denominator rule: an early return must still carry the fields, or a
% report that measured nothing looks structurally different from one that did.
r = did2.validate.sourceCensus({});
verifyTrue(testCase, isfield(r, 'approach_epoch_prefixes'));
verifyTrue(testCase, isfield(r, 'presentation_epoch_prefixes'));
verifyEqual(testCase, r.approach_presentation_shared_epochs, 0);
end

function row = prefixRow(tally, name)
row = tally(strcmp({tally.prefix}, name));
end

