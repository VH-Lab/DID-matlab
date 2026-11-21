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
%   statement with its numbers in the old shape (written by hand, so the
%   check holds whether or not the schema still declares the old shape) is
%   refused with 'did2:read:oldNumericShapeReMigrate'.
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
obs = statementOf(testCase, id, 'body weight', ...
    did2.build.valueCell('mass', 25.1, 'SourceValue', 25.1, 'SourceUnit', g, ...
    'Shape', 'new'), 'mass');
[out, ~] = did2.convert.roundtrip.measurement({obs});
verifyEqual(testCase, out.measurement.numeric_value, 25.1);
% the same statement with its value in the old shape, written by hand (one
% cell per reading, the number as the source wrote it in `source_value`), so
% the check does not depend on the schema still declaring the old shape
old = obs;
old.mass.value = oldCell('grams', 25.1, 25.1, g);
verifyError(testCase, @() did2.convert.roundtrip.measurement({old}), ...
    'did2:read:oldNumericShapeReMigrate');
end

function testAnElectrodeOffsetReadsTheNewShapeAndRefusesTheOld(testCase)
V = did2.build.term('om:volt', 'volt');
id = struct('doc', did.ido.unique_id(), 'entity', did.ido.unique_id(), ...
    'tref', did.ido.unique_id());
obs = statementOf(testCase, id, 'electrode offset voltage', ...
    did2.build.valueCell('voltage', 0.005, 'SourceValue', 0.005, 'SourceUnit', V, ...
    'Shape', 'new'), 'voltage', ...
    did2.build.condition('temperature', 'Value', 22, 'Unit', 'degree Celsius', ...
        'Shape', 'new'));
[out, ~] = did2.convert.roundtrip.electrode_offset_voltage({obs});
verifyEqual(testCase, out.electrode_offset_voltage.offset, 0.005);
verifyEqual(testCase, out.electrode_offset_voltage.temperature, 22);
% the same statement in the old shape, written by hand so the check does not
% depend on the schema declaring it: each old part alone is refused, and both
% together
oldValue = oldCell('volts', 0.005, 0.005, V);
c = obs.statement.conditions;
oldCondition = struct('variable', c.variable, 'unit', c.unit, ...
    'quantity', struct('value', 22));
cases = {{'value', oldValue, []}, {'condition', [], oldCondition}, ...
    {'value and condition', oldValue, oldCondition}};
for k = 1:numel(cases)
    old = obs;
    if ~isempty(cases{k}{2}); old.voltage.value = cases{k}{2}; end
    if ~isempty(cases{k}{3}); old.statement.conditions = cases{k}{3}; end
    verifyError(testCase, @() did2.convert.roundtrip.electrode_offset_voltage({old}), ...
        'did2:read:oldNumericShapeReMigrate', ['old shape: ' cases{k}{1}]);
end
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

function c = oldCell(canonical, number, source, unit)
% one value cell in the OLD numeric shape (did-schema
% did_v2_numeric_shape_plan.md section 2: `source_value`, renamed
% `source_numeric` in the new shape), by hand
c = struct(canonical, number, 'source_unit', unit, 'source_value', source, ...
    'approximate', false);
end
