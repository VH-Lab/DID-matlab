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
%
%   STATUS of the 2026-08-11 additions (the "legacy identity block" section at
%   the end of this file): WRITTEN WITHOUT MATLAB OR OCTAVE AND NOT EXECUTED.
%   Neither is available in the environment they were written in, so CI is
%   their first run.

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

function testUniversalRenamesRenameClassNamesFalsePreservesClassName(testCase)
% When RenameClassNames=false the document_class.class_name and the
% matching top-level property block key are left untouched. This is
% the contract callers like NDI's applyReadNormalization rely on:
% their on-disk schemas still spell classnames in camelCase
% (e.g., demoNDI) and the legacy v1 validator compares the strings
% by exact match.
v1 = makeV1Skeleton('demoNDI');
v1.demoNDI = struct('value', 5);
out = did2.convert.universalRenames(v1, 'RenameClassNames', false);
verifyEqual(testCase, out.document_class.class_name, 'demoNDI');
verifyTrue(testCase, isfield(out, 'demoNDI'));
verifyFalse(testCase, isfield(out, 'demo_ndi'));
verifyEqual(testCase, out.demoNDI.value, 5);
% schema_version stamping still runs — that's the V_delta shape
% transformation the gate flip actually needs.
verifyEqual(testCase, out.document_class.schema_version, 'V_delta');
end

function testUniversalRenamesRenameClassNamesFalsePreservesSuperclassNames(testCase)
% Superclass entries that already carry a class_name keep its
% spelling. Entries that only carry a v1 `definition` path still
% have their class_name derived from the basename (that derivation
% is not a rename — it just surfaces the name v1 stored under a
% different key), but with no snake_case sweep applied.
v1 = makeV1Skeleton('demoNDIMock');
v1.demoNDIMock = struct();
v1.document_class.superclasses = struct( ...
    'class_name', {'base', 'mock', 'demoNDI'});
out = did2.convert.universalRenames(v1, 'RenameClassNames', false);
sc = out.document_class.superclasses;
verifyEqual(testCase, numel(sc), 3);
verifyEqual(testCase, sc(1).class_name, 'base');
verifyEqual(testCase, sc(2).class_name, 'mock');
verifyEqual(testCase, sc(3).class_name, 'demoNDI');
end

function testUniversalRenamesRenameClassNamesFalseDerivesSuperclassFromDefinition(testCase)
% definition-derived superclass names are still produced (the
% derivation is not a rename), but no snake_case sweep is applied
% to the result.
v1 = makeV1Skeleton('demoNDI');
v1.demoNDI = struct();
v1.document_class.superclasses = struct( ...
    'definition', {'$NDIDOCUMENTPATH/base.json', ...
                   '$NDIDOCUMENTPATH/data/demoNDIMock.json'});
out = did2.convert.universalRenames(v1, 'RenameClassNames', false);
sc = out.document_class.superclasses;
verifyEqual(testCase, sc(1).class_name, 'base');
verifyEqual(testCase, sc(2).class_name, 'demoNDIMock');
end

function testUniversalRenamesRenameClassNamesFalseSkipsBlockFieldRenames(testCase)
% Field names inside a class property block are part of the
% identifier sweep too: leaving them snake_cased while the schema
% still declares them in camelCase would trip the field validator.
% RenameClassNames=false preserves the camelCase field names.
v1 = makeV1Skeleton('demoNDI');
v1.demoNDI = struct('nativeRate', 20000, 'dataType', 'double');
out = did2.convert.universalRenames(v1, 'RenameClassNames', false);
verifyTrue(testCase, isfield(out.demoNDI, 'nativeRate'));
verifyTrue(testCase, isfield(out.demoNDI, 'dataType'));
verifyFalse(testCase, isfield(out.demoNDI, 'native_rate'));
verifyFalse(testCase, isfield(out.demoNDI, 'data_type'));
end

function testUniversalRenamesRenameClassNamesFalseStillRewritesDependsOn(testCase)
% depends_on rewrites are V_delta shape changes, not identifier
% renames, so they still run under RenameClassNames=false.
v1 = makeV1Skeleton('demoNDI');
v1.demoNDI = struct();
v1.depends_on = struct( ...
    'name',    {'subject_id'}, ...
    'id',      {'aabb1122ccdd3344_aaaa1111bbbb2222'}, ...
    'version', {'1'});
out = did2.convert.universalRenames(v1, 'RenameClassNames', false);
verifyEqual(testCase, out.depends_on(1).document_id, ...
    'aabb1122ccdd3344_aaaa1111bbbb2222');
verifyFalse(testCase, isfield(out.depends_on, 'id'));
verifyFalse(testCase, isfield(out.depends_on, 'version'));
end

function testUniversalRenamesRenameClassNamesFalseStillRewritesAppBlock(testCase)
% app.name -> app.app_name is a V_delta field rename to match
% V_delta's `app` schema declaration. It is not gated by
% RenameClassNames (it's a fixed-target rename, not an identifier
% sweep).
v1 = makeV1Skeleton('demoNDI');
v1.demoNDI = struct();
v1.app = struct('name', 'ndi', 'version', '1.0.0');
out = did2.convert.universalRenames(v1, 'RenameClassNames', false);
verifyEqual(testCase, out.app.app_name, 'ndi');
verifyEqual(testCase, out.app.app_version, '1.0.0');
verifyFalse(testCase, isfield(out.app, 'name'));
verifyFalse(testCase, isfield(out.app, 'version'));
end

function testV1ToV2RenameClassNamesFalseThreadsThrough(testCase)
% The dispatcher option threads down to universalRenames, so a
% caller that needs the legacy-name-preserving behaviour can pass
% it at the top level.
v1 = makeV1Skeleton('demoNDI');
v1.demoNDI = struct('value', 5);
result = did2.convert.v1_to_v2(v1, 'Validate', false, ...
    'RenameClassNames', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.className(), 'demoNDI');
verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_delta');
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


% ===================== the legacy identity block ===========================
%
% THE COUNTER, NOT THE REPAIR. did2.convert.universalRenames handles a
% pre-`base` v1 document by MOVING THE `ndi_document` BLOCK WHOLESALE into
% `base` -- renaming the container and doing nothing to the contents, on the
% one code path that exists precisely because the contents differ. The tests
% below PIN THAT BEHAVIOUR RATHER THAN FIX IT: the fix changes migrated
% identity and is a team decision (V_eta_OPEN_WORK.md, "a pre-`base` v1
% document cannot migrate"). What is new is that the arm is now COUNTED.
%
% The shapes, read from NDI origin/main history rather than described:
%   ndi_document.json, block `ndi_document`, added 4f1a2b801 (2019-05-05):
%     experiment_unique_reference, document_unique_reference,
%     name, type, datestamp, database_version                        SIX
%   base.json, block `base`, added 9783809c2 (2023-04-13), unchanged since:
%     id, session_id, name, datestamp                                FOUR

function v1 = make2019Body()
% The 2019 block, verbatim from ndi_document.json as added 4f1a2b801, with
% real values in place of the template's blanks.
v1 = struct();
v1.document_class = struct('class_name', 'projectvar');
v1.projectvar = struct('description', 'a legacy variable', 'data', 5);
v1.ndi_document = struct( ...
    'experiment_unique_reference', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'document_unique_reference',   'aabb1122ccdd3344_1122334455667788', ...
    'name',                        'legacy-doc', ...
    'type',                        'ndi_element', ...
    'datestamp',                   '2019-06-01T12:00:00.000Z', ...
    'database_version',            1);
end

function testLegacyReportIsReturnedWithItsDenominatorForEveryBody(testCase)
% DENOMINATOR FIRST AND UNCONDITIONALLY (Operating Rule 5). A body with no
% legacy block reports 1 inspected beside zeros -- never nothing at all.
v1 = makeV1Skeleton('treatment');
v1.treatment = struct();
[~, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.bodies_inspected, 1);
verifyEqual(testCase, report.ndi_document_block_seen, 0);
verifyEqual(testCase, report.moved_wholesale_no_base, 0);
verifyEqual(testCase, report.discarded_ndi_document_base_present, 0);
end

function testLegacyReportCountsTheWholesaleMoveArm(testCase)
v1 = make2019Body();
[out, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.ndi_document_block_seen, 1);
verifyEqual(testCase, report.moved_wholesale_no_base, 1);
verifyEqual(testCase, report.discarded_ndi_document_base_present, 0);
% The block moved. Behaviour UNCHANGED and pinned here on purpose.
verifyFalse(testCase, isfield(out, 'ndi_document'));
verifyTrue(testCase, isfield(out, 'base'));
end

function testLegacyReportCountsTheDiscardArmSeparately(testCase)
% The two arms are different facts and are never summed: this one drops a
% stale block beside a good `base`, and loses no identity.
v1 = makeV1Skeleton('treatment');
v1.treatment = struct();
v1.ndi_document = struct('name', 'jrclust.prm');
[out, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.ndi_document_block_seen, 1);
verifyEqual(testCase, report.discarded_ndi_document_base_present, 1);
verifyEqual(testCase, report.moved_wholesale_no_base, 0);
verifyEqual(testCase, out.base.id, 'aabb1122ccdd3344_1122334455667788');
end

function testLegacyReportMeasuresBothRequiredIdentityFieldsMissing(testCase)
% THE DEFECT, MEASURED. The 2019 block has neither `id` nor `session_id`, so
% the document it produces carries NO IDENTITY -- and would quarantine on
% `undeclaredField` before anyone noticed that.
v1 = make2019Body();
[out, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.moved_missing_id, 1);
verifyEqual(testCase, report.moved_missing_session_id, 1);
verifyFalse(testCase, isfield(out.base, 'id'));
verifyFalse(testCase, isfield(out.base, 'session_id'));
end

function testLegacyReportCountsTheFourUndeclaredFields(testCase)
% experiment_unique_reference, document_unique_reference, type,
% database_version -- four fields `base` does not declare, on one body.
v1 = make2019Body();
[~, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.moved_with_any_undeclared_field, 1);
verifyEqual(testCase, report.moved_undeclared_field_instances, 4);
end

function testLegacyReportDiscriminatesThe2019VintageFromThe2020One(testCase)
% An arm count alone cannot say whether anything is broken. NDI renamed the
% fields in stages -- experiment_unique_reference -> experiment_id
% (5d0b66d8f, 2019-11-04) -> session_id (e8c02831d, 2020-05-19), and
% document_unique_reference -> id, in the TEMPLATE, at f4f9d9450 (2019-12-16)
% -- so a 2020-vintage `ndi_document` block already spells `id`/`session_id`
% and the wholesale move is SOUND for it. Only the 2019 names mark the broken
% shape.
%
% THE COMMIT CITED HERE WAS 9dc6bfe15 (2019-12-20) AND THAT IS THE WRONG FILE.
% Positive evidence, not absence -- 9dc6bfe15 touches the MATLAB class and not
% the template:
%   $ git show 9dc6bfe15 --stat --format= --name-only | grep -i ndi_document
%   database/ndi_document.m
%   $ git log --all --follow -- ndi_common/database_documents/ndi_document.json
%   ... f4f9d9450 2019-12-16 ...     <- the revision that introduced `id`
% The field-set claim the test makes is unaffected; only the citation moved.
%
% THIS TEST IS NOW THE WEAK FORM. It reads FOUR single fields, and two of the
% four vintages differ from their neighbour by ONE field name, so no reading of
% these counters can name a vintage. The vintage classifier below supersedes it
% for that purpose; this stays because each single-field count is still a fact.
v1 = make2019Body();
[~, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.moved_carrying_experiment_unique_reference, 1);
verifyEqual(testCase, report.moved_carrying_document_unique_reference, 1);
verifyEqual(testCase, report.moved_carrying_type, 1);
verifyEqual(testCase, report.moved_carrying_database_version, 1);

v2020 = struct();
v2020.document_class = struct('class_name', 'treatment');
v2020.treatment = struct();
v2020.ndi_document = struct( ...
    'id',               'aabb1122ccdd3344_1122334455667788', ...
    'session_id',       'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',             'legacy-doc', ...
    'type',             '', ...
    'datestamp',        '2021-06-01T12:00:00.000Z', ...
    'database_version', 1);
[~, r2020] = did2.convert.universalRenames(v2020);
verifyEqual(testCase, r2020.moved_wholesale_no_base, 1);
verifyEqual(testCase, r2020.moved_missing_id, 0);
verifyEqual(testCase, r2020.moved_missing_session_id, 0);
verifyEqual(testCase, r2020.moved_carrying_experiment_unique_reference, 0);
verifyEqual(testCase, r2020.moved_carrying_document_unique_reference, 0);
% Still two fields with no home in `base`, and the counter says so.
verifyEqual(testCase, r2020.moved_undeclared_field_instances, 2);
end

function testLegacyDeclaredBaseFieldListMatchesTheSchema(testCase)
% countMovedBlock names `base`'s four declared fields inline because it runs
% with no schema cache in hand. This test is what keeps that list honest:
% it reads the SCHEMA and asserts the same four, so a field added to `base`
% fails here rather than silently inflating `moved_undeclared_field_instances`
% on every future run.
thisDir = fileparts(mfilename('fullpath'));
schemaFile = fullfile(fileparts(thisDir), 'fixtures', 'V_delta', 'base.json');
verifyTrue(testCase, isfile(schemaFile), ...
    sprintf('base schema fixture not found at %s', schemaFile));
schema = jsondecode(fileread(schemaFile));
declared = sort({schema.fields.name});
verifyEqual(testCase, declared, ...
    sort({'datestamp', 'id', 'name', 'session_id'}));
end

function testLegacyCountersReachTheBatchSummaryWithItsDenominator(testCase)
% The counter is useless if it stops at the per-body report. v1_to_v2 sums it
% into summary.legacy_ndi_document, which writeCorpusReport persists and
% tools/census_digest.py renders.
v1 = make2019Body();
clean = makeV1Skeleton('treatment');
clean.treatment = struct();
result = did2.convert.v1_to_v2({v1, clean}, 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 2);
verifyEqual(testCase, L.bodies_reaching_universal_renames, 2);
verifyEqual(testCase, L.bodies_skipped_already_target, 0);
verifyEqual(testCase, L.bodies_unreached, 0);
verifyEqual(testCase, L.ndi_document_block_seen, 1);
verifyEqual(testCase, L.moved_wholesale_no_base, 1);
verifyEqual(testCase, L.discarded_ndi_document_base_present, 0);
verifyEqual(testCase, L.moved_undeclared_field_instances, 4);
verifyEqual(testCase, L.moved_by_class.projectvar, 1);
end

function testLegacySummaryIsPresentAndZeroWhenNoBodyCarriesTheBlock(testCase)
% ALL-ZERO IS THE EXPECTED READING on every corpus we hold, and it has to be
% a PRINTED zero. Corpus run 31464483119 inspected 633,432 documents across 6
% corpora and quarantined 0, so no pre-`base` document is in the sample --
% a fact about the SAMPLE, not evidence none exist.
clean = makeV1Skeleton('treatment');
clean.treatment = struct();
result = did2.convert.v1_to_v2(clean, 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 1);
verifyEqual(testCase, L.bodies_reaching_universal_renames, 1);
verifyEqual(testCase, L.ndi_document_block_seen, 0);
verifyEqual(testCase, L.moved_wholesale_no_base, 0);
end

function testLegacyDenominatorSeparatesTheIdempotencyShortCircuit(testCase)
% A body already at the target skips universalRenames entirely, so it must
% NOT be counted as inspected. Without this, a re-run over migrated bodies
% would report every arm at 0 having looked at nothing.
already = makeV1Skeleton('treatment');
already.treatment = struct();
already.document_class.schema_version = 'V_delta';
result = did2.convert.v1_to_v2(already, 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 1);
verifyEqual(testCase, L.bodies_reaching_universal_renames, 0);
verifyEqual(testCase, L.bodies_skipped_already_target, 1);
verifyEqual(testCase, L.bodies_unreached, 0);
end


% ============== the vintage classifier on the wholesale-move arm ============
%
% WHY A CLASSIFIER AND NOT MORE SINGLE-FIELD COUNTERS. The `ndi_document` block
% did not have one shape and then another. It had FOUR, and two consecutive
% pairs of them differ by ONE FIELD NAME EACH -- `experiment_id` vs
% `session_id`, and `document_id` vs `id`. So no reading of any single field can
% name a vintage, and the vintages need DIFFERENT REPAIRS:
%
%   4f1a2b801  2019-05-05  experiment_unique_reference, document_unique_reference
%                          + name, type, datestamp, database_version
%                          -> moves with NO usable identity at all
%   5d0b66d8f  2019-11-04  experiment_id, document_id + the same four
%                          -> moves with NO usable identity at all
%   f4f9d9450  2019-12-16  experiment_id, id + the same four
%                          -> `id` lands, `session_id` does NOT
%   e8c02831d  2020-05-19  session_id, id + the same four
%                          -> BOTH LAND. THE MOVE IS SOUND.
%   6529ce7bf  2020-12-01  the SAME SIX NAMES, `id` and `session_id` swapped
%                          in the JSON -- a key reorder, NOT a fifth vintage
%   9783809c2  2023-04-13  ndi_document.json DELETED, base.json ADDED
%
% The 2020-05-19 vintage ran until 2023-04-13 -- nearly three years, the
% longest-lived of the four -- so the arm's most likely occupant migrates
% CORRECTLY, and only `type` and `database_version` arrive undeclared. A single
% `moved_wholesale_no_base` count mixes that with a document that loses its
% identity outright.
%
% THE FIXTURES ARE NDI's OWN BYTES. Every block below is loaded from
% tests/+did2/fixtures/ndi_document_vintages/<commit>.json, which is
% `git show <commit>:ndi_common/database_documents/ndi_document.json` verbatim
% (see that directory's README for the extraction commands). Nothing here is a
% hand-written plausible struct and nothing here is derived from a DID-side
% schema -- that is the distance_metadata failure, where a migrator written
% against an assumed nested shape passed a unit test built from the same
% assumption and quarantined ~2078 real documents.

function block = loadVintageBlock(testCase, commit)
% The `ndi_document` block as NDI shipped it at COMMIT, read from the bytes.
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_document_vintages', ...
    [commit '.json']);
verifyTrue(testCase, isfile(f), ...
    sprintf('vintage template fixture not found at %s', f));
tpl = jsondecode(fileread(f));
verifyTrue(testCase, isfield(tpl, 'ndi_document'), ...
    sprintf('%s carries no `ndi_document` block', f));
block = tpl.ndi_document;
end

function v1 = makeVintageBody(block)
% A minimal pre-`base` v1 body carrying BLOCK as its only identity. No `base`,
% which is what puts it on the wholesale-move arm.
v1 = struct();
v1.document_class = struct('class_name', 'projectvar');
v1.projectvar = struct('description', 'a legacy variable');
v1.ndi_document = block;
end

function names = vintageCounterNames()
names = { ...
    'moved_vintage_2019_05_unique_reference', ...
    'moved_vintage_2019_11_experiment_document_id', ...
    'moved_vintage_2019_12_experiment_id_and_id', ...
    'moved_vintage_2020_05_session_id_and_id', ...
    'moved_vintage_unknown', ...
    'moved_vintage_unreadable_block'};
end

function verifyExactlyOneBucket(testCase, report, expected)
% Every vintage bucket is checked, not only the expected one. Asserting the
% expected counter alone would pass a classifier that sets two.
names = vintageCounterNames();
verifyTrue(testCase, any(strcmp(expected, names)), ...
    sprintf('%s is not a vintage bucket', expected));
for k = 1:numel(names)
    want = double(strcmp(names{k}, expected));
    verifyEqual(testCase, report.(names{k}), want, ...
        sprintf('bucket %s: expected %d', names{k}, want));
end
verifyEqual(testCase, report.moved_vintage_bodies_classified, 1);
end

function testTheCheckedInTemplatesShowFourFieldSetsNotFive(testCase)
% A STRUCTURAL CLAIM ABOUT NDI's HISTORY, READ FROM THE BYTES rather than from
% the table the classifier uses -- so this cannot pass by agreeing with the
% code it is testing. Two facts:
%   (1) the four vintages are PAIRWISE DISTINCT as field sets, so the
%       classifier's first-match loop cannot be order-dependent;
%   (2) 6529ce7bf is the SAME SET as e8c02831d in a DIFFERENT ORDER, which is
%       why it is not a fifth vintage and why classifying on field ORDER would
%       split one vintage in two.
commits = {'4f1a2b801', '5d0b66d8f', 'f4f9d9450', 'e8c02831d'};
sets = cell(1, numel(commits));
for k = 1:numel(commits)
    sets{k} = sort(fieldnames(loadVintageBlock(testCase, commits{k}))');
    verifyEqual(testCase, numel(sets{k}), 6, ...
        sprintf('%s: expected a six-field block', commits{k}));
end
for a = 1:numel(sets)
    for b = (a+1):numel(sets)
        verifyFalse(testCase, isequal(sets{a}, sets{b}), ...
            sprintf('%s and %s have the same field set', ...
                commits{a}, commits{b}));
    end
end

% 6529ce7bf: the SAME SET in a DIFFERENT ORDER.
verifyEqual(testCase, sort(fieldnames(loadVintageBlock(testCase, '6529ce7bf'))'), ...
    sort(fieldnames(loadVintageBlock(testCase, 'e8c02831d'))'));

% The ORDER half is read from the BYTES, not from jsondecode's struct. Whether
% jsondecode preserves key order is a property of MATLAB, and this assertion is
% about a property of NDI's file -- reading it off the decoder would let a
% decoder change fail a test that is not about the decoder.
thisDir = fileparts(mfilename('fullpath'));
dirPath = fullfile(fileparts(thisDir), 'fixtures', 'ndi_document_vintages');
posn = @(commit, key) min(strfind(fileread( ...
    fullfile(dirPath, [commit '.json'])), key));
verifyTrue(testCase, posn('e8c02831d', '"session_id"') < posn('e8c02831d', '"id"'), ...
    'e8c02831d should spell session_id BEFORE id');
verifyTrue(testCase, posn('6529ce7bf', '"id"') < posn('6529ce7bf', '"session_id"'), ...
    ['6529ce7bf is checked in to prove field ORDER differs while the SET ' ...
     'does not; if it now spells session_id first, the fixture is wrong']);
end

function testTheFieldSetComparisonIsOrientationNormalised(testCase)
% A SILENT TOTAL FAILURE, GIVEN ITS OWN TEST BECAUSE THE PARTITION CANNOT SEE
% IT. countMovedBlock compares a block's sorted field set against
% legacyVintageTable's entries with `isequal`. `isequal` on cell arrays compares
% SIZE as well as contents, and `fieldnames` returns a COLUMN while a field list
% is naturally written as a ROW literal. If either side stops normalising with
% `(:)`, every vintage misses, EVERY body lands in `moved_vintage_unknown` --
% and the six buckets still sum to the arm, so
% testTheVintageBucketsPartitionTheArmAcrossABatch stays GREEN while the
% classifier has stopped classifying.
%
% (This is what GitHub code scanning alert 195 pointed at: the earlier
% `sort(names(:)')` was flagged as an unnecessary transpose. It was not
% unnecessary. Both sides are columns now, so there is no transpose to delete,
% but the normalisation is still the thing holding this together.)
%
% Two assertions, and the first pins the MATLAB behaviour the second depends on
% so a failure says WHICH assumption broke.
row = {'b', 'a'};
col = {'b'; 'a'};
verifyFalse(testCase, isequal(row, col), ...
    ['isequal is expected to be SIZE-sensitive on cell arrays; if a row and ' ...
     'a column now compare equal, the orientation hazard below is moot and ' ...
     'this test should be re-derived rather than deleted']);

block = loadVintageBlock(testCase, 'e8c02831d');
verifyEqual(testCase, size(fieldnames(block), 2), 1, ...
    'fieldnames is expected to return a COLUMN cell');
[~, report] = did2.convert.universalRenames(makeVintageBody(block));
verifyEqual(testCase, report.moved_vintage_2020_05_session_id_and_id, 1, ...
    ['a real vintage did not reach its bucket -- the most likely cause is ' ...
     'that one side of the field-set comparison stopped normalising ' ...
     'orientation with (:)']);
verifyEqual(testCase, report.moved_vintage_unknown, 0, ...
    'a KNOWN vintage was classified as unknown');
end

function testEachVintageLandsInItsOwnBucket(testCase)
cases = { ...
    '4f1a2b801', 'moved_vintage_2019_05_unique_reference'; ...
    '5d0b66d8f', 'moved_vintage_2019_11_experiment_document_id'; ...
    'f4f9d9450', 'moved_vintage_2019_12_experiment_id_and_id'; ...
    'e8c02831d', 'moved_vintage_2020_05_session_id_and_id'};
for k = 1:size(cases, 1)
    block = loadVintageBlock(testCase, cases{k, 1});
    [~, report] = did2.convert.universalRenames(makeVintageBody(block));
    verifyEqual(testCase, report.moved_wholesale_no_base, 1, ...
        sprintf('%s did not take the wholesale-move arm', cases{k, 1}));
    verifyExactlyOneBucket(testCase, report, cases{k, 2});
end
end

function testTheKeyReorderRevisionIsNotAFifthVintage(testCase)
% 6529ce7bf swaps `id` and `session_id` in the JSON and renames nothing. It IS
% the 2020-05-19 vintage, and a classifier reading field ORDER would report a
% shape NDI never introduced.
block = loadVintageBlock(testCase, '6529ce7bf');
[~, report] = did2.convert.universalRenames(makeVintageBody(block));
verifyExactlyOneBucket(testCase, report, ...
    'moved_vintage_2020_05_session_id_and_id');
end

function testTheVintageDecidesWhetherIdentitySurvivesTheMove(testCase)
% THE WHOLE POINT, and the reason a single arm count is not a measurement. Read
% together with the buckets: two vintages lose everything, one loses half, one
% loses nothing. Same arm, same count, three different repairs.
expect = { ...
    '4f1a2b801', 1, 1; ...   % missing id, missing session_id
    '5d0b66d8f', 1, 1; ...
    'f4f9d9450', 0, 1; ...   % `id` survives; `session_id` does not
    'e8c02831d', 0, 0};      % SOUND
for k = 1:size(expect, 1)
    block = loadVintageBlock(testCase, expect{k, 1});
    [out, report] = did2.convert.universalRenames(makeVintageBody(block));
    verifyEqual(testCase, report.moved_missing_id, expect{k, 2}, ...
        sprintf('%s: moved_missing_id', expect{k, 1}));
    verifyEqual(testCase, report.moved_missing_session_id, expect{k, 3}, ...
        sprintf('%s: moved_missing_session_id', expect{k, 1}));
    % Behaviour PINNED, NOT CHANGED: the block still moves wholesale.
    verifyFalse(testCase, isfield(out, 'ndi_document'));
    verifyTrue(testCase, isfield(out, 'base'));
end

% Even the sound vintage arrives with two fields `base` does not declare --
% base.json (9783809c2) is id/session_id/name/datestamp, with no `type` and no
% `database_version`.
block = loadVintageBlock(testCase, 'e8c02831d');
[~, sound] = did2.convert.universalRenames(makeVintageBody(block));
verifyEqual(testCase, sound.moved_undeclared_field_instances, 2);
end

function testAnUnrecognisedFieldSetIsNeverRoundedToTheNearestVintage(testCase)
% REAL CORPORA HOLD SHAPES THIS TABLE DOES NOT PREDICT -- hand edits, partial
% writes, mixtures. Naming the nearest known vintage for one of those is the
% assumed-shape error that produced the distance_metadata quarantines, so the
% bucket is EXPLICIT.
%
% Case 1: the 2020 set plus one extra field. The extra is not invented -- it is
% `hasbinaryfile`, which the 2018 `nsd_document` block really carried
% (f45bcc82c). A nearest-neighbour classifier would call this 2020-05.
block = loadVintageBlock(testCase, 'e8c02831d');
block.hasbinaryfile = 0;
[~, r1] = did2.convert.universalRenames(makeVintageBody(block));
verifyEqual(testCase, r1.moved_wholesale_no_base, 1);
verifyExactlyOneBucket(testCase, r1, 'moved_vintage_unknown');

% Case 2: the 2019-05 set with one field REMOVED. A subset test would call this
% 2019-05; set equality does not.
short = rmfield(loadVintageBlock(testCase, '4f1a2b801'), 'database_version');
[~, r2] = did2.convert.universalRenames(makeVintageBody(short));
verifyExactlyOneBucket(testCase, r2, 'moved_vintage_unknown');

% Case 3: a MIXTURE -- 2019-11's `experiment_id` beside 2020-05's `id`... which
% IS the 2019-12 vintage, so mix the other way: `session_id` beside
% `document_id`, a pairing NDI never shipped.
mixed = loadVintageBlock(testCase, 'e8c02831d');
mixed = rmfield(mixed, 'id');
mixed.document_id = '';
[~, r3] = did2.convert.universalRenames(makeVintageBody(mixed));
verifyExactlyOneBucket(testCase, r3, 'moved_vintage_unknown');

% Case 4: an EMPTY block. It has a field set -- the empty one -- and no vintage
% has that, so it is unknown rather than silently uncounted.
[~, r4] = did2.convert.universalRenames(makeVintageBody(struct()));
verifyExactlyOneBucket(testCase, r4, 'moved_vintage_unknown');
end

function testAnUnreadableBlockIsCountedRatherThanSkipped(testCase)
% A block that is not a scalar struct HAS no field set, so it cannot be
% classified -- but it DID reach the classifier, and skipping it would break the
% partition and read downstream as "nothing unusual here". That is the
% fold-a-refusal-into-silence failure this repository has now paid for twice.
v1 = struct();
v1.document_class = struct('class_name', 'projectvar');
v1.projectvar = struct('description', 'a legacy variable');
v1.ndi_document = struct('name', {'a', 'b'});   % 1x2, not scalar
[~, report] = did2.convert.universalRenames(v1);
verifyEqual(testCase, report.moved_wholesale_no_base, 1);
verifyExactlyOneBucket(testCase, report, 'moved_vintage_unreadable_block');
end

function testTheClassifierReportsItsOwnDenominatorAndItIsZeroOffTheArm(testCase)
% Rule 5. The denominator is how many bodies REACHED THE CLASSIFIER -- not the
% batch, and not the bodies carrying a block. A body on the DISCARD arm carries
% an `ndi_document` block and is never classified, and the two must not be
% confused.
clean = makeV1Skeleton('treatment');
clean.treatment = struct();
[~, r0] = did2.convert.universalRenames(clean);
verifyEqual(testCase, r0.moved_vintage_bodies_classified, 0);

discard = makeV1Skeleton('treatment');
discard.treatment = struct();
discard.ndi_document = loadVintageBlock(testCase, '4f1a2b801');
[~, rd] = did2.convert.universalRenames(discard);
verifyEqual(testCase, rd.ndi_document_block_seen, 1);
verifyEqual(testCase, rd.discarded_ndi_document_base_present, 1);
verifyEqual(testCase, rd.moved_wholesale_no_base, 0);
verifyEqual(testCase, rd.moved_vintage_bodies_classified, 0, ...
    'a discarded block was never classified and must not inflate the denominator');
names = vintageCounterNames();
for k = 1:numel(names)
    verifyEqual(testCase, rd.(names{k}), 0);
end
end

function testTheVintageBucketsPartitionTheArmAcrossABatch(testCase)
% THE PARTITION, ASSERTED. A body that falls through every bucket is exactly
% what this counter exists to catch, so the six buckets must sum to the number
% classified, which must equal the arm. Held here over a batch mixing all four
% vintages, the key-reorder revision, an unknown shape, an unreadable block, a
% body on the DISCARD arm and a body with no legacy block at all.
%
% v1_to_v2 raises did2:convert:legacyVintagePartitionBroken if the identity
% fails; this test also checks it by arithmetic so a failure names the numbers
% rather than only the error.
bodies = {};
for c = {'4f1a2b801', '5d0b66d8f', 'f4f9d9450', 'e8c02831d', '6529ce7bf'}
    bodies{end+1} = makeVintageBody(loadVintageBlock(testCase, c{1})); %#ok<AGROW>
end
odd = loadVintageBlock(testCase, 'e8c02831d');
odd.hasbinaryfile = 0;
bodies{end+1} = makeVintageBody(odd);

unreadable = makeVintageBody(struct());
unreadable.ndi_document = struct('name', {'a', 'b'});
bodies{end+1} = unreadable;

discard = makeV1Skeleton('treatment');
discard.treatment = struct();
discard.ndi_document = loadVintageBlock(testCase, '4f1a2b801');
bodies{end+1} = discard;

clean = makeV1Skeleton('treatment');
clean.treatment = struct();
bodies{end+1} = clean;

result = did2.convert.v1_to_v2(bodies, 'Validate', false);
L = result.summary.legacy_ndi_document;

verifyEqual(testCase, L.bodies_total, 9);
verifyEqual(testCase, L.bodies_reaching_universal_renames, 9);
verifyEqual(testCase, L.ndi_document_block_seen, 8);
verifyEqual(testCase, L.moved_wholesale_no_base, 7);
verifyEqual(testCase, L.discarded_ndi_document_base_present, 1);

names = vintageCounterNames();
total = 0;
for k = 1:numel(names)
    total = total + L.(names{k});
end
verifyEqual(testCase, total, L.moved_vintage_bodies_classified, ...
    'the vintage buckets do not sum to the bodies classified');
verifyEqual(testCase, L.moved_vintage_bodies_classified, ...
    L.moved_wholesale_no_base, ...
    'a body took the wholesale-move arm and never reached the classifier');
verifyEqual(testCase, total, 7);

% The composition, named. Five checked-in templates, four vintages: the
% key-reorder revision joins the 2020 bucket, which is why that one is 2.
verifyEqual(testCase, L.moved_vintage_2019_05_unique_reference, 1);
verifyEqual(testCase, L.moved_vintage_2019_11_experiment_document_id, 1);
verifyEqual(testCase, L.moved_vintage_2019_12_experiment_id_and_id, 1);
verifyEqual(testCase, L.moved_vintage_2020_05_session_id_and_id, 2);
verifyEqual(testCase, L.moved_vintage_unknown, 1);
verifyEqual(testCase, L.moved_vintage_unreadable_block, 1);

% ...and the identity outcome across those seven, which is the fact a single
% arm count destroys. Counted by hand from the fixture bytes:
%
%   4f1a2b801   no `id`, no `session_id`
%   5d0b66d8f   no `id`, no `session_id`
%   f4f9d9450   `id` lands, no `session_id`
%   e8c02831d   both land
%   6529ce7bf   both land
%   2020+hasbinaryfile (the `unknown` shape)   both land -- UNKNOWN IS NOT
%               THE SAME AS BROKEN, which is the second reason the bucket is
%               explicit rather than merged into a defect count
%   unreadable  neither counter fires
%
% THE UNREADABLE BLOCK CONTRIBUTES TO NEITHER, and that is deliberate and
% PRE-EXISTING: countMovedBlock returns before the identity checks when the
% block is not a scalar struct, because it cannot read a field set to say what
% is absent. It is not evidence the block HAS an id -- that is what the
% `moved_vintage_unreadable_block` bucket is for, and reading these two
% counters without it would understate the damage.
verifyEqual(testCase, L.moved_missing_id, 2);
verifyEqual(testCase, L.moved_missing_session_id, 3);
end

% ===========================================================================
% VERSION ORDERING AND THE REFUSAL
% ===========================================================================
% `isAlreadyTarget` compared schema_version to the target with strcmp, so a
% document NEWER than the target was indistinguishable from one OLDER, and both
% took the branch that runs the migrators. These pin the ordering and the
% refusal that replaced it.

function testABodyBeyondTheTargetIsNotConverted(testCase)
% THE BUG. A V_eta body normalised at TargetVersion V_delta -- which is what
% ndi.database.internal.applyReadNormalization does on EVERY read -- was pushed
% through universalRenames and the per-class migrators aimed at a version it
% had already passed.
v1 = makeV1Skeleton('treatment');
v1.document_class.schema_version = 'V_eta';
v1.treatment = struct('ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent');
r = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_delta');
verifyEmpty(testCase, r.quarantine, ...
    'a body beyond the target must not quarantine');
verifyNotEmpty(testCase, r.migrated, 'the body was dropped entirely');
verifyEqual(testCase, ...
    r.migrated{1}.toStruct().document_class.schema_version, 'V_eta', ...
    ['the body was converted BACKWARDS -- its version was rewritten to the ' ...
     'target it had already passed']);
end

function testABodyBelowTheTargetStillConverts(testCase)
% The counterpart, so the ordering fix cannot pass by refusing everything.
v1 = makeV1Skeleton('treatment');
v1.treatment = struct('ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent');
r = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_delta');
verifyNotEmpty(testCase, r.migrated);
verifyEqual(testCase, ...
    r.migrated{1}.toStruct().document_class.schema_version, 'V_delta');
end

function testAnUnknownSchemaVersionIsREFUSEDNotConverted(testCase)
% Team, 2026-08-14: "an unrecognized version shouldn't convert". A name this
% did2 does not know belongs to a document written by a NEWER one, and running
% the v1-era migrators over it would reshape fields whose meaning is unknown
% here. It quarantines with a named identifier instead.
v1 = makeV1Skeleton('treatment');
v1.document_class.schema_version = 'V_omega';
v1.treatment = struct('ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent');
r = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_delta');
verifyEmpty(testCase, r.migrated, ...
    'an unknown vintage was converted -- it must be refused');
verifyNotEmpty(testCase, r.quarantine, ...
    'an unknown vintage vanished silently instead of quarantining');
verifyEqual(testCase, r.quarantine(1).identifier, ...
    'did2:convert:unknownSchemaVersion');
end

function testAMissingSchemaVersionIsDidV1AndIsNotRefused(testCase)
% The distinction the refusal turns on. ABSENT is the ORIGIN of the line, not
% an unknown vintage -- collapsing the two would quarantine every real did_v1
% document in existence.
v1 = makeV1Skeleton('treatment');
verifyFalse(testCase, isfield(v1.document_class, 'schema_version'), ...
    'the fixture already declares a version; this test would prove nothing');
v1.treatment = struct('ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent');
r = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_delta');
verifyEmpty(testCase, r.quarantine, 'a did_v1 body was refused');
verifyNotEmpty(testCase, r.migrated);
end

function testTheVersionRankOrdersTheLineAndFlagsTheUnknown(testCase)
[r0, k0] = did2.convert.schemaVersionRank('');
[rd, kd] = did2.convert.schemaVersionRank('V_delta');
[re, ke] = did2.convert.schemaVersionRank('V_eta');
[rx, kx] = did2.convert.schemaVersionRank('V_omega');
verifyTrue(testCase, k0 && kd && ke);
verifyEqual(testCase, r0, 0, 'did_v1 is the origin of the line');
verifyTrue(testCase, rd < re, 'V_delta must rank before V_eta');
verifyFalse(testCase, kx, 'an unknown name must not be reported as known');
verifyTrue(testCase, isnan(rx), ...
    'an unknown name must not get rank 0 -- that is did_v1, "convert this"');
end
