function tests = testBuildNumericShapeReaders
%TESTBUILDNUMERICSHAPEREADERS The round-trip readers read both numeric shapes.
%
%   Step 1 of did-schema docs/plans/did_v2_numeric_shape_plan.md section 9
%   ([one shape for measured numbers], Jess Haley, 2026-11-17) has the code
%   that reads these numbers today read them through one helper
%   (did2.read.numeric, did2.read.canonical, and the +roundtrip private
%   helpers itemNumbers, itemSource, itemRegular, cellSource, cellReadings,
%   coefValue built on them), so that step 2 switches the writers without
%   touching a reader. Here a v1 document is rebuilt by a round-trip inverse
%   from the SAME statement built once in the old shape and once in the new
%   one (same id, same timestamp): the two rebuilt v1 documents, and what the
%   inverse reports, are identical.
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

function testAMeasurementReadsTheSameFromBothShapes(testCase)
g = did2.build.term('om:gram', 'gram');
id = struct('doc', did.ido.unique_id(), 'entity', did.ido.unique_id(), ...
    'tref', did.ido.unique_id());
out = cell(1, 2);
specs = cell(1, 2);
shapes = {'old', 'new'};
for k = 1:2
    v = did2.build.valueCell('mass', 25.1, 'SourceValue', 25.1, 'SourceUnit', g, ...
        'Shape', shapes{k});
    obs = statementOf(testCase, id, 'body weight', v, 'mass');
    [out{k}, specs{k}] = did2.convert.roundtrip.measurement({obs});
end
verifyEqual(testCase, out{1}.measurement.numeric_value, 25.1);
verifyEqual(testCase, out{2}, out{1});
verifyEqual(testCase, specs{2}.unplaced, specs{1}.unplaced);
end

function testAnElectrodeOffsetReadsTheSameFromBothShapes(testCase)
V = did2.build.term('om:volt', 'volt');
id = struct('doc', did.ido.unique_id(), 'entity', did.ido.unique_id(), ...
    'tref', did.ido.unique_id());
out = cell(1, 2);
specs = cell(1, 2);
shapes = {'old', 'new'};
for k = 1:2
    v = did2.build.valueCell('voltage', 0.005, 'SourceValue', 0.005, 'SourceUnit', V, ...
        'Shape', shapes{k});
    obs = statementOf(testCase, id, 'electrode offset voltage', v, 'voltage', ...
        did2.build.condition('temperature', 'Value', 22, 'Unit', 'degree Celsius', ...
            'Shape', shapes{k}));
    [out{k}, specs{k}] = did2.convert.roundtrip.electrode_offset_voltage({obs});
end
verifyEqual(testCase, out{1}.electrode_offset_voltage.offset, 0.005);
verifyEqual(testCase, out{1}.electrode_offset_voltage.temperature, 22);
verifyEqual(testCase, out{2}, out{1});
verifyEqual(testCase, specs{2}.unplaced, specs{1}.unplaced);
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
