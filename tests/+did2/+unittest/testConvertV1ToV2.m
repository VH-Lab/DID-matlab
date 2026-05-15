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

function testUniversalRenamesSnakeCasesBlockFieldNames(testCase)
% camelCase field names inside a class property block become
% snake_case after the universal pass; already-snake fields are
% untouched.
v1 = makeV1Skeleton('pyraview');
v1.pyraview = struct( ...
    'label',         'high', ...
    'nativeRate',    20000, ...
    'nativeStartTime', 0, ...
    'channels',      16, ...
    'dataType',      'double', ...
    'decimationLevels', [100 10 10]);
out = did2.convert.universalRenames(v1);
verifyTrue(testCase, isfield(out.pyraview, 'native_rate'));
verifyTrue(testCase, isfield(out.pyraview, 'native_start_time'));
verifyTrue(testCase, isfield(out.pyraview, 'data_type'));
verifyTrue(testCase, isfield(out.pyraview, 'decimation_levels'));
verifyEqual(testCase, out.pyraview.label, 'high');
verifyEqual(testCase, out.pyraview.channels, 16);
verifyFalse(testCase, isfield(out.pyraview, 'nativeRate'));
verifyFalse(testCase, isfield(out.pyraview, 'dataType'));
end

function testUniversalRenamesDoesNotTouchStructuralKeys(testCase)
% document_class.class_name should still be snake_cased, but the
% structural top-level keys themselves (document_class, depends_on)
% should not be visited as property blocks.
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct();
v1.depends_on = struct( ...
    'name', {'subject_id'}, ...
    'value', {'abcdef0123456789_0123456789abcdef'});
out = did2.convert.universalRenames(v1);
verifyTrue(testCase, isfield(out, 'document_class'));
verifyTrue(testCase, isfield(out, 'depends_on'));
verifyEqual(testCase, out.depends_on(1).name, 'subject_id');
end

function testUniversalRenamesDerivesSuperclassNamesFromDefinition(testCase)
% v1 records superclasses as { definition: $NDIDOCUMENTPATH/foo.json
% }; universalRenames normalises that to { class_name: 'foo' }.
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct();
v1.document_class.superclasses = struct( ...
    'definition', {'$NDIDOCUMENTPATH/base.json', ...
                   '$NDIDOCUMENTPATH/data/filter.json'});
out = did2.convert.universalRenames(v1);
sc = out.document_class.superclasses;
verifyEqual(testCase, numel(sc), 2);
verifyEqual(testCase, sc(1).class_name, 'base');
verifyEqual(testCase, sc(2).class_name, 'filter');
end

function testDispatcherRunsSuperclassMigratorBeforeConcreteMigrator(testCase)
% A document whose superclasses include `epochclocktimes` should pick
% up the superclass migrator (split t0_t1 + rename clocktype). The
% concrete class is unregistered so the identity fallback runs after.
v1 = makeV1Skeleton('some_unregistered_class');
v1.some_unregistered_class = struct('foo', 'bar');
v1.epochclocktimes = struct('clocktype', 'dev_local_time', ...
    't0_t1', [0 1.5]);
v1.document_class.superclasses = struct( ...
    'class_name', {'base', 'epochclocktimes'});
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('epochclocktimes.epoch_clock'), ...
    'dev_local_time');
verifyEqual(testCase, doc.get('epochclocktimes.t0'), 0);
verifyEqual(testCase, doc.get('epochclocktimes.t1'), 1.5);
end
