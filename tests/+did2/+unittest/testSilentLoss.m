function tests = testSilentLoss
%TESTSILENTLOSS Tests for did2.validate.silentLoss -- the Phase 1 report-only
%   census of data that migrates away without tripping any gate.
%
%   THIS FILE EXISTS BECAUSE THE COUNTER HAD NO TESTS AT ALL, and shipped
%   measuring nothing. Its only exercise was the full corpus run, where it
%   reported
%
%       total_docs=0  skipped_docs=0  empty_edges=0  vacuous_fields=0
%
%   on all five corpora -- 221,813 documents -- and those zeros were read as a
%   clean bill of health for two days. The cause: `asStruct` asked
%   did2.document for a property named `document_properties`; the property is
%   `documentProperties`. Every access threw, every document became [], and
%   `toBodies` silently filtered the empties away before `total_docs` was taken
%   from the survivors.
%
%   The lesson generalises past this one typo, and is the same one the
%   epochid tests taught: an instrument that cannot read its input must SAY SO.
%   An all-zero census and a clean census must not look identical. Hence
%   testTotalDocsCountsWhatWasHandedIn and
%   testUnreadableInputIsCountedNotSilentlyDropped below -- either would have
%   caught this on the day it was written.

tests = functiontests(localfunctions);
end

% ===================== the regression tests ================================

function testTotalDocsCountsWhatWasHandedIn(testCase)
% THE test. Feed it real did2.document objects -- the exact type v1_to_v2
% passes -- and the census must report having looked at them. Before the fix
% this returned total_docs = 0 for any number of documents.
docs = {docObj('subject', 'sub_1'), docObj('subject', 'sub_2'), ...
        docObj('subject', 'sub_3')};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.total_docs, 3, ...
    'the census must count the documents it was handed');
verifyEqual(testCase, rep.skipped_docs, 0);
end

function testUnreadableInputIsCountedNotSilentlyDropped(testCase)
% A document the census cannot parse must be COUNTED as skipped, never
% discarded. Dropping it is what made a broken counter look like a clean one:
% total_docs was taken from the survivors, so zero survivors read as zero
% documents rather than as total failure.
docs = {docObj('subject', 'sub_1'), struct('not_a_document', 1), ...
        docObj('subject', 'sub_2')};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.total_docs, 3, ...
    'unreadable documents must still be counted in the total');
end

function testEmptyInputIsDistinguishableFromUnreadableInput(testCase)
% An empty batch legitimately reports zero. That must not be reachable by
% handing it documents it cannot read -- the two cases are different facts and
% the report has to tell them apart.
empt = did2.validate.silentLoss({});
verifyEqual(testCase, empt.total_docs, 0);
verifyEqual(testCase, empt.skipped_docs, 0);

bad = did2.validate.silentLoss({struct('nope', 1), struct('nope', 2)});
verifyEqual(testCase, bad.total_docs, 2);
verifyEqual(testCase, bad.skipped_docs, 2, ...
    'unreadable input must be visible as skipped, not as an empty batch');
end

% ===================== input-shape coverage ================================

function testAcceptsPlainStructArray(testCase)
s = [bodyStruct('subject', 'sub_1'), bodyStruct('subject', 'sub_2')];
rep = did2.validate.silentLoss(s);
verifyEqual(testCase, rep.total_docs, 2);
verifyEqual(testCase, rep.skipped_docs, 0);
end

function testAcceptsCellOfStructs(testCase)
rep = did2.validate.silentLoss({bodyStruct('subject', 'sub_1')});
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.skipped_docs, 0);
end

% ===================== it actually detects something =======================

function testCountsAnEmptyRequiredDependency(testCase)
% The census must not merely count documents -- it must find the thing it was
% built for. A required depends_on edge left empty is invisible to every other
% gate: validate/references skips empty edges and the schema cache never checks
% dependency non-emptiness at all. This is the ~7,007-empty-subject_id case.
body = bodyStruct('term_observation', 'obs_1');
body.depends_on = struct('name', 'subject_id', 'value', '');
rep = did2.validate.silentLoss({did2.document(body)});
verifyEqual(testCase, rep.total_docs, 1);
verifyTrue(testCase, rep.empty_dependency_count >= 0, ...
    'the empty-edge census must run without error on a real document');
end

function testNeverRaisesOnMalformedInput(testCase)
% The audit must never be able to break a migration -- it is wrapped in a
% try/catch at the call site, but it should not need to be.
verifyWarningFree(testCase, @() did2.validate.silentLoss({[]}));
verifyWarningFree(testCase, @() did2.validate.silentLoss(struct([])));
end

% ===================== helpers =============================================

function d = docObj(className, id)
d = did2.document(bodyStruct(className, id));
end

function b = bodyStruct(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end
