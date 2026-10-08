function tests = testFragmentCensus
%TESTFRAGMENTCENSUS The FRAGMENT detector -- Phase 1.4, the third failure mode.
%
%   A migrator can fail in three ways, and only two had a counter:
%
%     HOLLOW      emits documents with blank values -> did2.validate.silentLoss
%     PASSTHROUGH hands its input straight back      -> unconverted_by_class
%     FRAGMENT    drops the payload, emits only side documents -> THIS
%
%   ---------------------------------------------------------------------
%   WHY THESE TESTS ARE SYNTHETIC AND NOT END-TO-END
%   ---------------------------------------------------------------------
%   The first version of this file drove the detector through real migrators --
%   vmneuralresponseresiduals and simple_calc -- because those are two of the
%   four that historically fragmented. It failed in CI, correctly: BOTH ARE
%   GUARDED PASSTHROUGHS NOW. They were repaired a day earlier, so they no
%   longer fragment, and the tests were asserting behaviour that had been
%   deliberately removed.
%
%   That is worth keeping as a note rather than quietly fixing, because it is
%   the same error as the fixtures built from our own schema and the three tests
%   that pinned the epochid delete in place: the test was written from the STORY
%   of the bug instead of from the code as it stands.
%
%   It also showed the detector was in the wrong place. As a local function
%   inside v1_to_v2 it could only be exercised through a migrator that actually
%   fragments -- and every one that did has been fixed, so there was no honest
%   way to test it end to end. It now lives in did2.validate.isFragment, takes
%   bodies, and answers a question about them, so the cases can be written
%   directly and it keeps working after the last real fragment is gone.

tests = functiontests(localfunctions);
end

% ===================== the detector fires ==================================

function testAnchorOnlyOutputIsAFragment(testCase)
% The historical shape: a migrator whose payload read failed emitted a lone
% session anchor. Nothing is blank and output WAS produced, so neither other
% counter sees it.
verifyTrue(testCase, did2.validate.isFragment( ...
    {scaffold('session_relative_reference', 'time_reference')}));
end

function testRelationOnlyOutputIsAFragment(testCase)
% Scaffolding is not only time references. A migration emitting just a relation
% has likewise produced support for a statement it never made.
verifyTrue(testCase, did2.validate.isFragment( ...
    {scaffold('directed_relation', 'relation')}));
end

function testSeveralScaffoldsAreStillAFragment(testCase)
verifyTrue(testCase, did2.validate.isFragment({ ...
    scaffold('session_relative_reference', 'time_reference'), ...
    scaffold('directed_relation', 'relation')}));
end

function testSubclassOfScaffoldingIsRecognisedByChain(testCase)
% Structural, not name-based: a class nobody listed is still scaffolding if its
% declared chain says so. This is why the rule survives new subclasses.
verifyTrue(testCase, did2.validate.isFragment( ...
    {scaffold('some_future_reference', 'time_reference')}));
end

% ===================== the detector stays quiet ============================

function testObservationPlusAnchorIsNotAFragment(testCase)
% The normal shape. The anchor is scaffolding; the observation is not.
verifyFalse(testCase, did2.validate.isFragment({ ...
    substantive('voltage_observation', 'subject_observation'), ...
    scaffold('session_relative_reference', 'time_reference')}));
end

function testPassthroughIsNotAFragment(testCase)
% A guarded passthrough emits the source document, which is substantive. It is
% already counted by unconverted_by_class; double-counting it here would make
% both diagnoses useless, since they call for opposite responses.
verifyFalse(testCase, did2.validate.isFragment( ...
    {substantive('site2channelmap', 'base')}));
end

function testEmptyOutputIsNotAFragment(testCase)
% No output at all is a quarantine, not a fragment -- a different diagnosis
% with its own counter.
verifyFalse(testCase, did2.validate.isFragment({}));
end

function testMalformedBodyIsNotCalledScaffolding(testCase)
% Anything the detector cannot classify must count as substantive, so an
% unreadable body can never be mistaken for "only scaffolding was emitted".
% Erring the other way would invent fragments out of parse failures.
verifyFalse(testCase, did2.validate.isFragment({struct('nope', 1)}));
end

% ===================== wired into the summary ==============================

function testCounterIsReportedEvenWhenZero(testCase)
% The field must always exist. A counter that appears only when it fires cannot
% be told apart from one that was never wired in -- which is precisely how the
% silent-loss census spent two days reporting nothing while measuring nothing.
body = struct();
body.document_class = struct('class_name', 'site2channelmap', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 's2c_1', 'session_id', 'sess_1', 'name', 's2c', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.site2channelmap = struct('map', [1 2 3]);

out = did2.convert.v1_to_v2({body}, 'TargetVersion', 'V_eta', ...
    'Validate', false, 'CheckReferences', false);
verifyTrue(testCase, isfield(out.summary, 'fragment_count'), ...
    'fragment_count must be reported even when it is zero');
verifyTrue(testCase, isfield(out.summary, 'fragment_by_class'));
verifyEqual(testCase, out.summary.fragment_count, 0);
end

% ===================== helpers =============================================

function b = scaffold(className, superName)
b = bodyOf(className, superName);
end

function b = substantive(className, superName)
b = bodyOf(className, superName);
end

function b = bodyOf(className, superName)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {superName}, 'class_version', {'1.0.0'}));
b.base = struct('id', [className '_1'], 'session_id', 'sess_1', ...
    'name', className, 'datestamp', '2024-06-01T12:00:00.000Z');
end
