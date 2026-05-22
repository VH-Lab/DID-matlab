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
v1Body.depends_on = struct('name', {}, 'document_id', {});
v1Body.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'unit-test', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
end

function testUniversalRenamesSetsSchemaVersion(testCase)
% Every v1 body picks up `document_class.schema_version = 'V_delta'`
% so the next dispatcher pass takes the short-circuit. The tag lives
% in document_class (set-version metadata, sibling of class_name /
% class_version / superclasses), never on the base block.
v1 = makeV1Skeleton('treatment');
v1.treatment = struct('ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent');
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.document_class.schema_version, 'V_delta');
verifyFalse(testCase, isfield(out.base, 'schema_version'));
end

function testUniversalRenamesLeavesExistingSchemaVersionAlone(testCase)
% A body that already declares its document_class.schema_version
% (e.g., a partial-migration holding state tagged 'did_v1') is left
% as-is. The migrator only defaults when the tag is absent.
v1 = makeV1Skeleton('treatment');
v1.document_class.schema_version = 'did_v1';
v1.treatment = struct();
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.document_class.schema_version, 'did_v1');
end

function testUniversalRenamesMigratesStaleBaseSchemaVersion(testCase)
% Bodies emitted by an earlier V_delta-draft migrator that stamped
% the tag on base get migrated forward: base.schema_version is moved
% to document_class.schema_version and stripped from base. Without
% this, the strict-fields validator would reject base.schema_version
% as an undeclared field on the next write.
v1 = makeV1Skeleton('treatment');
v1.treatment = struct();
v1.base.schema_version = 'V_delta';
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.document_class.schema_version, 'V_delta');
verifyFalse(testCase, isfield(out.base, 'schema_version'));
end

function testUniversalRenamesDiscardsNdiDocumentWhenBasePresent(testCase)
v1 = makeV1Skeleton('treatment');
v1.treatment = struct();
v1.ndi_document = struct('name', 'jrclust.prm');
out = did2.convert.universalRenames(v1);
verifyFalse(testCase, isfield(out, 'ndi_document'));
verifyEqual(testCase, out.base.id, 'aabb1122ccdd3344_1122334455667788');
end

function testUniversalRenamesPromotesNdiDocumentWhenBaseMissing(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'treatment');
v1.treatment = struct();
v1.ndi_document = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'legacy-doc', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
out = did2.convert.universalRenames(v1);
verifyFalse(testCase, isfield(out, 'ndi_document'));
verifyTrue(testCase, isfield(out, 'base'));
verifyEqual(testCase, out.base.id, 'aabb1122ccdd3344_1122334455667788');
verifyEqual(testCase, out.document_class.schema_version, 'V_delta');
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

function testUniversalRenamesPromotesDependsOnIdToDocumentId(testCase)
v1 = makeV1Skeleton('treatment');
v1.depends_on = struct( ...
    'name',    {'subject_id', 'protocol_id'}, ...
    'id',      {'aabb1122ccdd3344_aaaa1111bbbb2222', ''}, ...
    'version', {'1', '1'});
v1.treatment = struct();
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.depends_on(1).document_id, 'aabb1122ccdd3344_aaaa1111bbbb2222');
verifyEqual(testCase, out.depends_on(2).document_id, '');
verifyFalse(testCase, isfield(out.depends_on, 'id'));
verifyFalse(testCase, isfield(out.depends_on, 'value'));
verifyFalse(testCase, isfield(out.depends_on, 'version'));
end

function testUniversalRenamesPreservesExistingDependsOnDocumentId(testCase)
% Earlier V_delta drafts used `value`; the rename treats that as a
% synonym so already-migrated bodies don't lose information when
% re-run.
v1 = makeV1Skeleton('treatment');
v1.depends_on = struct( ...
    'name',  {'subject_id'}, ...
    'id',    {'fallback_id'}, ...
    'value', {'existing_value'});
v1.treatment = struct();
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.depends_on(1).document_id, 'existing_value');
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
    'name',        {'subject_id'}, ...
    'document_id', {'abcdef0123456789_0123456789abcdef'});
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

function vDelta = makeVDeltaSkeleton(className)
% Build a body that is already V_delta-shaped: schema_version stamped
% on document_class, snake-cased class name, depends_on uses
% `document_id` (not `id` or the earlier-draft `value`).
vDelta = struct();
vDelta.document_class = struct( ...
    'class_name',     className, ...
    'class_version',  '1.0.0', ...
    'superclasses',   struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'), ...
    'schema_version', 'V_delta');
vDelta.depends_on = struct('name', {}, 'document_id', {});
vDelta.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'unit-test', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
end

function testShortCircuitOnAlreadyVDeltaBody(testCase)
% A body that already declares
% document_class.schema_version=='V_delta' skips universalRenames and
% the per-class migrators. The epochclocktimes block carries
% v1-shaped fields (clocktype, t0_t1); under the short-circuit those
% stay verbatim because the superclass migrator never runs.
% ensureClassBlocks still runs (rebuilds the chain) and the body
% still becomes a did2.document.
vDelta = makeVDeltaSkeleton('some_unregistered_class');
vDelta.some_unregistered_class = struct('foo', 'bar');
vDelta.epochclocktimes = struct('clocktype', 'dev_local_time', ...
    't0_t1', [0 1.5]);
vDelta.document_class.superclasses = struct( ...
    'class_name', {'base', 'epochclocktimes'});
result = did2.convert.v1_to_v2(vDelta, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.quarantine_count, 0);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('epochclocktimes.clocktype'), ...
    'dev_local_time');
verifyEqual(testCase, doc.get('epochclocktimes.t0_t1'), [0 1.5]);
verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_delta');
% Per-class summary keys off the unchanged class_name.
verifyEqual(testCase, result.summary.by_class.some_unregistered_class, 1);
end

function testIdempotencyOfDoubleRun(testCase)
% Running v1_to_v2 twice on the same v1 body produces the same
% migrated output the second time as the first. The second pass hits
% the short-circuit because the first pass stamped schema_version.
v1 = makeV1Skeleton('some_unregistered_class');
v1.some_unregistered_class = struct('foo', 'bar');
v1.epochclocktimes = struct('clocktype', 'dev_local_time', ...
    't0_t1', [0 1.5]);
v1.document_class.superclasses = struct( ...
    'class_name', {'base', 'epochclocktimes'});

first = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, first.summary.migrated_count, 1);
firstBody = first.migrated{1}.toStruct();

second = did2.convert.v1_to_v2(firstBody, 'Validate', false);
verifyEqual(testCase, second.summary.migrated_count, 1);
verifyEqual(testCase, second.summary.quarantine_count, 0);
secondBody = second.migrated{1}.toStruct();

verifyEqual(testCase, secondBody.document_class.schema_version, 'V_delta');
verifyEqual(testCase, secondBody.epochclocktimes.epoch_clock, ...
    'dev_local_time');
verifyEqual(testCase, secondBody.epochclocktimes.t0, 0);
verifyEqual(testCase, secondBody.epochclocktimes.t1, 1.5);
verifyEqual(testCase, secondBody, firstBody);
end

function testMixedBatchOfV1AndVDeltaBodies(testCase)
% A batch with both v1 bodies (need full migration) and V_delta
% bodies (short-circuit) migrates every document successfully.
v1A = makeV1Skeleton('unknown_class');
v1A.unknown_class = struct('foo', 'bar_v1');
vDeltaA = makeVDeltaSkeleton('unknown_class');
vDeltaA.unknown_class = struct('foo', 'bar_vdelta');
v1B = makeV1Skeleton('some_other_class');
v1B.some_other_class = struct('n', 42);
vDeltaB = makeVDeltaSkeleton('some_other_class');
vDeltaB.some_other_class = struct('n', 99);

result = did2.convert.v1_to_v2( ...
    {v1A, vDeltaA, v1B, vDeltaB}, 'Validate', false);

verifyEqual(testCase, result.summary.total, 4);
verifyEqual(testCase, result.summary.migrated_count, 4);
verifyEqual(testCase, result.summary.quarantine_count, 0);
verifyEqual(testCase, result.summary.by_class.unknown_class, 2);
verifyEqual(testCase, result.summary.by_class.some_other_class, 2);
% Every migrated doc carries the V_delta schema_version stamp on
% document_class (v1 bodies pick it up from universalRenames;
% V_delta bodies kept their own).
for k = 1:numel(result.migrated)
    doc = result.migrated{k};
    verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_delta');
end
end

function testShortCircuitSkippedWhenSchemaVersionMissing(testCase)
% A body that lacks document_class.schema_version takes the full
% pipeline even when it has no v1-only underscore markers. Guards
% against the "either condition is enough" reading that would
% silently skip bulk v1 corpora.
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
% v1-shaped depends_on: carries `id`, no `document_id` —
% universalRenames promotes id->document_id, drops the legacy keys.
v1.depends_on = struct( ...
    'name', {'subject_id'}, ...
    'id',   {'aabb1122ccdd3344_aaaa1111bbbb2222'}, ...
    'version', {'1'});
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
% universalRenames ran: schema_version got stamped on document_class.
verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_delta');
% universalRenames ran: depends_on(1).id was promoted to
% .document_id, and the legacy id/version keys were dropped.
dependsOn = doc.toStruct().depends_on;
verifyEqual(testCase, dependsOn(1).document_id, ...
    'aabb1122ccdd3344_aaaa1111bbbb2222');
verifyFalse(testCase, isfield(dependsOn, 'id'));
verifyFalse(testCase, isfield(dependsOn, 'value'));
verifyFalse(testCase, isfield(dependsOn, 'version'));
end

