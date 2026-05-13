function tests = testConvertV1ToV2
%TESTCONVERTV1TOV2 Smoke tests for the did2.convert v1->V_delta dispatcher.
%
%   Exercises the converter skeleton (PLAN.md §9.6 sub-step 6a): the
%   dispatcher's input normalisation, the universal-rename pass, the
%   identity-migrator fallback, quarantine semantics, and the
%   end-of-run summary table. Tests run with Validate=false so they do
%   not depend on the schema cache being able to resolve V_delta
%   schemas at the test-runner working directory.
%
%   Run with:
%       results = runtests('did2.unittest.testConvertV1ToV2');

tests = functiontests(localfunctions);
end

function v1Body = makeV1Skeleton(className)
v1Body = struct();
v1Body.document_class = struct( ...
    'class_name',    className, ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
v1Body.depends_on = struct('name', {}, 'value', {});
v1Body.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'unit-test', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
end

function testUniversalRenamesSetsSchemaVersion(testCase)
v1 = makeV1Skeleton('treatment');
v1.treatment = struct('ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent');
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.base.schema_version, 'V_delta');
end

function testUniversalRenamesLeavesExistingSchemaVersionAlone(testCase)
v1 = makeV1Skeleton('treatment');
v1.base.schema_version = 'did_v1';
v1.treatment = struct();
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.base.schema_version, 'did_v1');
end

function testUniversalRenamesSnakeCasesCamelClassName(testCase)
v1 = makeV1Skeleton('ontologyImage');
v1.ontologyImage = struct('ontology_name', 'allen_ccf_v3:12345', ...
    'ontology_region', 'primary visual cortex');
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.document_class.class_name, 'ontology_image');
verifyTrue(testCase, isfield(out, 'ontology_image'));
verifyFalse(testCase, isfield(out, 'ontologyImage'));
end

function testUniversalRenamesPromotesDependsOnIdToValue(testCase)
v1 = makeV1Skeleton('treatment');
v1.depends_on = struct( ...
    'name',    {'subject_id', 'protocol_id'}, ...
    'id',      {'aabb1122ccdd3344_aaaa1111bbbb2222', ''}, ...
    'version', {'1', '1'});
v1.treatment = struct();
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.depends_on(1).value, 'aabb1122ccdd3344_aaaa1111bbbb2222');
verifyEqual(testCase, out.depends_on(2).value, '');
verifyFalse(testCase, isfield(out.depends_on, 'id'));
verifyFalse(testCase, isfield(out.depends_on, 'version'));
end

function testUniversalRenamesPreservesExistingDependsOnValue(testCase)
v1 = makeV1Skeleton('treatment');
v1.depends_on = struct( ...
    'name',  {'subject_id'}, ...
    'id',    {'fallback_id'}, ...
    'value', {'existing_value'});
v1.treatment = struct();
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.depends_on(1).value, 'existing_value');
end

function testIdentityMigratorPassthrough(testCase)
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
out = did2.convert.migrators.identity( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.unknown_class.foo, 'bar');
end

function testDispatcherIdentityFallback(testCase)
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.total, 1);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.quarantine_count, 0);
doc = result.migrated{1};
verifyEqual(testCase, doc.className(), 'unknown_class');
verifyEqual(testCase, doc.get('unknown_class.foo'), 'bar');
end

function testDispatcherAcceptsJSONInput(testCase)
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
jsonText = jsonencode(v1);
result = did2.convert.v1_to_v2({jsonText}, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
end

function testQuarantineCapturesInvalidInput(testCase)
bad = struct('not_a_doc', true);
result = did2.convert.v1_to_v2(bad, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 0);
verifyEqual(testCase, result.summary.quarantine_count, 1);
verifyEqual(testCase, result.quarantine(1).class_name, '<unknown>');
verifyTrue(testCase, ~isempty(result.quarantine(1).failed_at));
end

function testQuarantineAlongsideMigrated(testCase)
good = makeV1Skeleton('unknown_class');
good.unknown_class = struct();
bad = struct('not_a_doc', true);
result = did2.convert.v1_to_v2({good, bad}, 'Validate', false);
verifyEqual(testCase, result.summary.total, 2);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.quarantine_count, 1);
end

function testByClassTableCounts(testCase)
v1a = makeV1Skeleton('unknown_class');
v1a.unknown_class = struct('n', 1);
v1b = makeV1Skeleton('unknown_class');
v1b.unknown_class = struct('n', 2);
result = did2.convert.v1_to_v2({v1a, v1b}, 'Validate', false);
verifyEqual(testCase, result.summary.by_class.unknown_class, 2);
end

function testCellArrayInputAccepted(testCase)
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
result = did2.convert.v1_to_v2({v1, v1, v1}, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 3);
end
