function tests = testReportNote
%TESTREPORTNOTE did2.convert.reportNote: exact counts, a capped id sample, and
%   mark / truncate dropping a quarantined body's notes exactly.
%
%   The notes used to be kept one by one (notes(end+1)); on a corpus with ~69k
%   calculators that is quadratic. Counts, per-class counts and per-DETAIL
%   counts must stay exact; only ids/details are a sample, and the summary
%   must say so (sample_kept, sampled, sample_cap_per_class).
tests = functiontests(localfunctions);
end

function teardown(~)
did2.convert.reportNote('reset');
end

function testCountsStayExactPastTheCap(testCase)
did2.convert.reportNote('reset');
nA = 57; nB = 3;
for k = 1:nA
    did2.convert.reportNote('field_dropped', 'class_a', sprintf('a%03d', k), ...
        sprintf('blk.f%d', mod(k, 4)));
end
for k = 1:nB
    did2.convert.reportNote('field_dropped', 'class_b', sprintf('b%03d', k), '');
end
s = did2.convert.reportNote('collect');
n = s.field_dropped;
cap = n.sample_cap_per_class;
verifyEqual(testCase, n.count, nA + nB, 'the count is every note');
verifyEqual(testCase, n.by_class.class_a, nA);
verifyEqual(testCase, n.by_class.class_b, nB);
verifyEqual(testCase, n.sample_kept, min(nA, cap) + min(nB, cap));
verifyEqual(testCase, numel(n.ids), n.sample_kept);
verifyEqual(testCase, numel(n.details), n.sample_kept);
verifyTrue(testCase, n.sampled, 'more notes than the sample holds: sampled must say so');
% the sample is the FIRST notes of each class, in recorded order
verifyEqual(testCase, n.ids(1:cap), arrayfun(@(k) sprintf('a%03d', k), 1:cap, ...
    'UniformOutput', false));
verifyEqual(testCase, n.ids(cap+1:end), {'b001', 'b002', 'b003'});
% per-DETAIL counts are exact over all notes; empty details are not listed
verifyEqual(testCase, sort(n.distinct_details), {'blk.f0', 'blk.f1', 'blk.f2', 'blk.f3'});
verifyEqual(testCase, sum(n.distinct_detail_counts), nA);
[~, i1] = ismember('blk.f1', n.distinct_details);
verifyEqual(testCase, n.distinct_detail_counts(i1), numel(1:4:nA));
end

function testUnderTheCapNothingIsSampledAway(testCase)
did2.convert.reportNote('reset');
did2.convert.reportNote('route_unknown', 'treatment', 'tr_01');
did2.convert.reportNote('route_unknown', 'treatment', 'tr_02', 'x');
s = did2.convert.reportNote('collect');
n = s.route_unknown;
verifyEqual(testCase, n.ids, {'tr_01', 'tr_02'});
verifyEqual(testCase, n.details, {'', 'x'});
verifyFalse(testCase, n.sampled);
verifyEqual(testCase, n.distinct_details, {'x'});
verifyEqual(testCase, n.distinct_detail_counts, 1);
end

function testTruncateDropsTheNotesSinceTheMark(testCase)
% v1_to_v2: mark before each body, truncate to it when the body is quarantined
did2.convert.reportNote('reset');
m0 = did2.convert.reportNote('mark');
did2.convert.reportNote('field_dropped', 'c', 'kept_1', 'p.q');
m1 = did2.convert.reportNote('mark');
verifyEqual(testCase, m0, 0);
verifyEqual(testCase, m1, 1, 'mark is the number recorded so far');
did2.convert.reportNote('field_dropped', 'c', 'dropped_1', 'p.r');
did2.convert.reportNote('other_kind', 'c', 'dropped_2');
did2.convert.reportNote('truncate', m1);
m2 = did2.convert.reportNote('mark');
verifyEqual(testCase, m2, 1, 'the truncated notes are gone');
did2.convert.reportNote('field_dropped', 'c', 'kept_2', 'p.q');
s = did2.convert.reportNote('collect');
verifyEqual(testCase, fieldnames(s), {'field_dropped'}, ...
    'a kind recorded only by a truncated body must not appear');
verifyEqual(testCase, s.field_dropped.count, 2);
verifyEqual(testCase, s.field_dropped.ids, {'kept_1', 'kept_2'});
verifyEqual(testCase, s.field_dropped.distinct_details, {'p.q'});
verifyEqual(testCase, s.field_dropped.distinct_detail_counts, 2);
% truncating to a count at or past what is recorded changes nothing
did2.convert.reportNote('truncate', 99);
s2 = did2.convert.reportNote('collect');
verifyEqual(testCase, s2.field_dropped.count, 2);
end

function testTruncateBeforeTheLastMarkRefuses(testCase)
did2.convert.reportNote('reset');
did2.convert.reportNote('k', 'c', 'i1');
did2.convert.reportNote('mark');
verifyError(testCase, @() did2.convert.reportNote('truncate', 0), ...
    'did2:convert:reportNote:truncateBeforeMark');
end

function testNoNotesCollectsAnEmptyStruct(testCase)
did2.convert.reportNote('reset');
s = did2.convert.reportNote('collect');
verifyTrue(testCase, isstruct(s) && isempty(fieldnames(s)));
end
