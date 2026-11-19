function tests = testBuildNumericShapeReaders
%TESTBUILDNUMERICSHAPEREADERS The round-trip readers read the new numeric shape only.
%
%   Step 1 of did-schema docs/plans/did_v2_numeric_shape_plan.md section 9
%   ([one shape for measured numbers], Jess Haley, 2026-11-17) has the code
%   that reads these numbers read them through one helper (did2.read.numeric,
%   did2.read.canonical, and the +roundtrip private helpers itemNumbers,
%   itemSource, itemRegular, cellSource, cellReadings, coefValue built on
%   them). Step 4 ([no migrated database is kept], Jess Haley, 2026-11-19)
%   drops the old shape from them. Here a v1 document is rebuilt by a
%   round-trip inverse from a statement built in the new shape, and the SAME
%   statement built in the old shape (same id, same timestamp) is refused
%   with 'did2:read:oldNumericShapeReMigrate'.
%
%   UNVERIFIED: written without MATLAB; test-builder.yml runs it.
%
%   Run with:  results = runtests('did2.unittest.testBuildNumericShapeReaders');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping numeric shape reader tests');
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
cache = did2.schema.cache.shared();
if ~cache.hasClass('voltage') || ~cache.hasClass('mass')
    assumeFail(testCase, sprintf('the loaded schema (%s) has no voltage or mass class.', ...
        cache.schemaPath));
end
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testAMeasurementReadsTheNewShapeAndRefusesTheOld(testCase)
g = did2.build.term('om:gram', 'gram');
id = struct('doc', did.ido.unique_id(), 'entity', did.ido.unique_id(), ...
    'tref', did.ido.unique_id());
obsIn = @(shape) statementOf(testCase, id, 'body weight', ...
    did2.build.valueCell('mass', 25.1, 'SourceValue', 25.1, 'SourceUnit', g, ...
    'Shape', shape), 'mass');
[out, ~] = did2.convert.roundtrip.measurement({obsIn('new')});
verifyEqual(testCase, out.measurement.numeric_value, 25.1);
verifyError(testCase, @() did2.convert.roundtrip.measurement({obsIn('old')}), ...
    'did2:read:oldNumericShapeReMigrate');
end

function testAnElectrodeOffsetReadsTheNewShapeAndRefusesTheOld(testCase)
V = did2.build.term('om:volt', 'volt');
id = struct('doc', did.ido.unique_id(), 'entity', did.ido.unique_id(), ...
    'tref', did.ido.unique_id());
obsIn = @(shape) statementOf(testCase, id, 'electrode offset voltage', ...
    did2.build.valueCell('voltage', 0.005, 'SourceValue', 0.005, 'SourceUnit', V, ...
    'Shape', shape), 'voltage', ...
    did2.build.condition('temperature', 'Value', 22, 'Unit', 'degree Celsius', ...
        'Shape', shape));
[out, ~] = did2.convert.roundtrip.electrode_offset_voltage({obsIn('new')});
verifyEqual(testCase, out.electrode_offset_voltage.offset, 0.005);
verifyEqual(testCase, out.electrode_offset_voltage.temperature, 22);
verifyError(testCase, @() did2.convert.roundtrip.electrode_offset_voltage({obsIn('old')}), ...
    'did2:read:oldNumericShapeReMigrate');
end

% ===================== helpers ==============================================

function doc = statementOf(testCase, id, variable, value, kind, conditions)
% the same statement whatever the shape: every id and the timestamp fixed
if nargin < 6
    conditions = [];
end
doc = did2.build.statement('observation', id.entity, variable, value, ...
    'Conditions', conditions, 'TimeReferenceIds', {id.tref}, ...
    'Id', id.doc, 'CreationTimestamp', '2026-11-17T00:00:00.000Z', ...
    'SessionId', testCase.TestData.sid, 'ValueKind', kind);
end
