function tests = testFragmentCensus
%TESTFRAGMENTCENSUS The FRAGMENT counter -- Phase 1.4, the third failure mode.
%
%   A migrator can fail in three ways, and until now only two were counted:
%
%     HOLLOW      emits documents with blank values -> did2.validate.silentLoss
%     PASSTHROUGH hands its input straight back      -> unconverted_by_class
%     FRAGMENT    drops the payload and emits ONLY its side documents -> NOTHING
%
%   A fragment is not hollow (no required field is blank) and not a passthrough
%   (output WAS produced), so both existing counters score it as a clean
%   migration. vmneuralresponseresiduals, simple_calc, fitcurve and vmspikefit
%   all failed exactly this way: each emitted a lone session_relative_reference
%   anchor while the measurement it existed to carry went nowhere, and every
%   gate stayed green. testHistoricalFragmentShapeIsCaught below reconstructs
%   that exact shape.

tests = functiontests(localfunctions);
end

% ===================== the detector fires ==================================

function testHistoricalFragmentShapeIsCaught(testCase)
% The real one. A migrator whose payload read fails emits only its session
% anchor. Before this counter existed, that scored as a successful migration:
% migrated_count went up by 1 and nothing was blank.
out = runOne(fragmentBody('vmneuralresponseresiduals'));
verifyEqual(testCase, out.summary.fragment_count, 1, ...
    'a migration emitting only a session anchor is a FRAGMENT');
verifyTrue(testCase, isfield(out.summary.fragment_by_class, ...
    'vmneuralresponseresiduals'));
end

function testRelationOnlyOutputIsAlsoAFragment(testCase)
% Scaffolding is not just time references. A migration that emits only a
% relation has likewise produced support for a statement it never made.
out = runOne(fragmentBody('simple_calc', 'directed_relation', 'relation'));
verifyEqual(testCase, out.summary.fragment_count, 1);
end

% ===================== the detector stays quiet ============================

function testRealMigrationIsNotAFragment(testCase)
% An observation PLUS its anchor is the normal shape. The anchor is
% scaffolding, the observation is not, so the migration is substantive.
body = sourceBody('electrode_offset_voltage');
body.electrode_offset_voltage = struct('offset', 0.005, 'temperature', 21);
body.depends_on = struct('name', 'probe_id', 'value', 'probe_1');
out = runOne(body);
verifyEqual(testCase, out.summary.fragment_count, 0, ...
    'an observation plus its anchor is a real migration, not a fragment');
end

function testPassthroughIsNotAFragment(testCase)
% A guarded passthrough emits the source document, which is substantive. It is
% already counted by unconverted_by_class and must NOT be double-counted here --
% the two modes are different diagnoses and mixing them would make both useless.
body = sourceBody('site2channelmap');
body.site2channelmap = struct('map', [1 2 3]);
out = runOne(body);
verifyEqual(testCase, out.summary.fragment_count, 0, ...
    'a passthrough is not a fragment -- it is counted as unconverted');
verifyTrue(testCase, out.summary.unconverted_count >= 1);
end

function testCounterIsPresentEvenWhenZero(testCase)
% The field must always exist. A counter that appears only when it fires cannot
% be distinguished from a counter that was never wired in -- which is exactly
% how the silent-loss census went two days reporting nothing while measuring
% nothing.
body = sourceBody('site2channelmap');
body.site2channelmap = struct('map', [1 2 3]);
out = runOne(body);
verifyTrue(testCase, isfield(out.summary, 'fragment_count'), ...
    'fragment_count must be reported even when it is zero');
verifyTrue(testCase, isfield(out.summary, 'fragment_by_class'));
end

% ===================== helpers =============================================

function out = runOne(body)
out = did2.convert.v1_to_v2({body}, 'TargetVersion', 'V_eta', ...
    'Validate', false, 'CheckReferences', false);
end

function b = sourceBody(className)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', [className '_1'], 'session_id', 'sess_1', ...
    'name', className, 'datestamp', '2024-06-01T12:00:00.000Z');
end

function b = fragmentBody(className, outClass, outSuper)
%FRAGMENTBODY A source document whose migrator will emit scaffolding only.
%   The payload field is deliberately absent, which is exactly how the real
%   failures arose: the migrator looked for a field the document does not have.
if nargin < 2; outClass = 'session_relative_reference'; end
if nargin < 3; outSuper = 'time_reference'; end
b = sourceBody(className);
b.(className) = struct();          % no payload -> scaffolding-only output
b.expected_scaffolding = struct('class_name', outClass, 'superclass', outSuper);
b = rmfield(b, 'expected_scaffolding');
end
