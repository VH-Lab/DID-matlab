function tests = testConvertV1ToV2
%TESTCONVERTV1TOV2 Smoke tests for the did2.convert v1->V_eta dispatcher.
%
%   Exercises the converter skeleton: the
%   dispatcher's input normalisation, the routing of each v1 class (there is
%   no rename pass and no identity fallback: [migrators read raw v1], [early
%   migration pieces fixed] (1)), quarantine semantics, and the
%   end-of-run summary table. Tests run with Validate=false so they do
%   not depend on the schema cache being able to resolve the V_eta
%   schemas at the test-runner working directory.
%
%   'V_eta' is the only and the default target.
%
%   Run with:
%       results = runtests('did2.unittest.testConvertV1ToV2');
%
%   The class each test uses is chosen for its route: `projectvar` has no
%   migrator and is carried whole as v1 (did2.convert.noMigratorCarryRows),
%   `subject` converts (did2.convert.rawV1Classes), and `unknown_class` has
%   no migrator and no recorded decision, so it quarantines.

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

function testAClassWithNoMigratorAndNoDecisionQuarantines(testCase)
% [early migration pieces fixed] (1) (Decided by Jess Haley, 2026-10-26): "a
% class with no migrator is a recorded decision, not an identity fallback". A
% class no route names is quarantined, named, and counted.
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.total, 1);
verifyEqual(testCase, result.summary.migrated_count, 0);
verifyEqual(testCase, result.summary.quarantine_count, 1);
verifyEqual(testCase, result.quarantine(1).identifier, 'did2:convert:noMigrator');
verifyEqual(testCase, result.quarantine(1).class_name, 'unknown_class');
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_no_migrator_quarantined, 1);
verifyEqual(testCase, L.bodies_unreached, 0);
end

function testDispatcherAcceptsJSONInput(testCase)
v1 = makeV1Skeleton('projectvar');
v1.projectvar = struct('foo', 'bar');
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
good = makeV1Skeleton('projectvar');
good.projectvar = struct();
bad = struct('not_a_doc', true);
result = did2.convert.v1_to_v2({good, bad}, 'Validate', false);
verifyEqual(testCase, result.summary.total, 2);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.quarantine_count, 1);
end

function testByClassTableCounts(testCase)
v1a = makeV1Skeleton('projectvar');
v1a.projectvar = struct('n', 1);
v1b = makeV1Skeleton('projectvar');
v1b.projectvar = struct('n', 2);
v1b.base.id = 'aabb1122ccdd3344_1122334455667799';
result = did2.convert.v1_to_v2({v1a, v1b}, 'Validate', false);
verifyEqual(testCase, result.summary.by_class.projectvar, 2);
end

function testCellArrayInputAccepted(testCase)
v1 = makeV1Skeleton('projectvar');
v1.projectvar = struct('foo', 'bar');
result = did2.convert.v1_to_v2({v1, v1, v1}, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 3);
end

function target = makeTargetSkeleton(className)
% Build a body that is already at the target: schema_version 'did_v2' stamped
% on document_class, snake-cased class name, depends_on uses
% `document_id` (not `id` or the earlier-draft `value`).
target = struct();
target.document_class = struct( ...
    'class_name',     className, ...
    'class_version',  '1.0.0', ...
    'superclasses',   struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
target.depends_on = struct('name', {}, 'document_id', {});
target.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'unit-test', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
end

function testShortCircuitOnAlreadyTargetBody(testCase)
% A body that already declares
% document_class.schema_version=='did_v2' skips the routing and
% the per-class migrators. The epochclocktimes block carries
% v1-shaped fields (clocktype, t0_t1); under the short-circuit those
% stay verbatim, and an unregistered class is not quarantined.
% ensureClassBlocks still runs (rebuilds the chain) and the body
% still becomes a did2.document.
target = makeTargetSkeleton('some_unregistered_class');
target.some_unregistered_class = struct('foo', 'bar');
target.epochclocktimes = struct('clocktype', 'dev_local_time', ...
    't0_t1', [0 1.5]);
target.document_class.superclasses = struct( ...
    'class_name', {'base', 'epochclocktimes'});
result = did2.convert.v1_to_v2(target, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.quarantine_count, 0);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('epochclocktimes.clocktype'), ...
    'dev_local_time');
verifyEqual(testCase, doc.get('epochclocktimes.t0_t1'), [0 1.5]);
verifyEqual(testCase, doc.get('document_class.schema_version'), 'did_v2');
% Per-class summary keys off the unchanged class_name.
verifyEqual(testCase, result.summary.by_class.some_unregistered_class, 1);
end

function testIdempotencyOfDoubleRun(testCase)
% Running v1_to_v2 twice on the same v1 body produces the same
% migrated output the second time as the first. The second pass hits
% the short-circuit because the first pass stamped schema_version.
v1 = makeSubject();
first = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEmpty(testCase, first.quarantine);
verifyEqual(testCase, first.summary.passthrough_count, 0, 'converted');
firstBodies = cellfun(@(d) d.toStruct(), first.migrated, 'UniformOutput', false);

second = did2.convert.v1_to_v2(firstBodies, 'Validate', false);
verifyEqual(testCase, second.summary.migrated_count, first.summary.migrated_count);
verifyEqual(testCase, second.summary.quarantine_count, 0);
verifyEqual(testCase, second.summary.legacy_ndi_document.bodies_skipped_already_target, ...
    numel(firstBodies));
for k = 1:numel(firstBodies)
    secondBody = second.migrated{k}.toStruct();
    verifyEqual(testCase, secondBody.document_class.schema_version, 'did_v2');
    verifyEqual(testCase, secondBody, firstBodies{k});
end
% a carried document is a v1 document: a second run carries it again, unchanged
pv = makeV1Skeleton('projectvar');
pv.projectvar = struct('foo', 'bar');
first = did2.convert.v1_to_v2(pv, 'Validate', false);
firstBody = first.migrated{1}.toStruct();
verifyEqual(testCase, firstBody.document_class.schema_version, 'did_v1');
second = did2.convert.v1_to_v2(firstBody, 'Validate', false);
verifyEqual(testCase, second.migrated{1}.toStruct(), firstBody);
end

function v1 = makeSubject()
% a v1 `subject` the raw-v1 migrator converts (as in
% testAV1NameTheEntityHoldsDoesNotCarry)
v1 = makeV1Skeleton('subject');
v1.subject = struct('local_identifier', 'mouse_42@lab', 'description', '');
v1.base.name = 'mouse_42@lab';
v1 = jsondecode(jsonencode(v1));
end

function testMixedBatchOfV1AndTargetBodies(testCase)
% A batch with both v1 bodies (routed) and V_eta bodies (short-circuit)
% migrates every document successfully. A v1 body is converted (stamped
% did_v2) or carried (stamped did_v1); a V2 body keeps its own stamp.
v1A = makeV1Skeleton('projectvar');
v1A.projectvar = struct('foo', 'bar_v1');
targetA = makeTargetSkeleton('unknown_class');
targetA.base.id = 'aabb1122ccdd3344_00000000000000a2';
targetA.unknown_class = struct('foo', 'bar_target');
v1B = makeSubject();
v1B.base.id = 'aabb1122ccdd3344_00000000000000b1';
targetB = makeTargetSkeleton('some_other_class');
targetB.base.id = 'aabb1122ccdd3344_00000000000000b2';
targetB.some_other_class = struct('n', 99);

result = did2.convert.v1_to_v2( ...
    {v1A, targetA, v1B, targetB}, 'Validate', false);

verifyEqual(testCase, result.summary.total, 4);
verifyEqual(testCase, result.summary.quarantine_count, 0);
verifyEqual(testCase, result.summary.by_class.projectvar, 1);
verifyEqual(testCase, result.summary.by_class.unknown_class, 1);
verifyEqual(testCase, result.summary.by_class.some_other_class, 1);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_skipped_already_target, 2);
verifyEqual(testCase, L.bodies_carried_no_migrator, 1);
verifyEqual(testCase, L.bodies_read_raw_v1, 1);
for k = 1:numel(result.migrated)
    doc = result.migrated{k};
    if strcmp(doc.className(), 'projectvar')
        verifyEqual(testCase, doc.get('document_class.schema_version'), 'did_v1');
    else
        verifyEqual(testCase, doc.get('document_class.schema_version'), 'did_v2');
    end
end
end

function testShortCircuitSkippedWhenSchemaVersionMissing(testCase)
% A body that lacks document_class.schema_version is routed even when it has
% no v1-only underscore markers. Guards against the "either condition is
% enough" reading that would silently skip bulk v1 corpora.
v1 = makeV1Skeleton('projectvar');
v1.projectvar = struct('foo', 'bar');
v1.depends_on = struct( ...
    'name', {'subject_id'}, ...
    'id',   {'aabb1122ccdd3344_aaaa1111bbbb2222'}, ...
    'version', {'1'});
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.legacy_ndi_document.bodies_skipped_already_target, 0);
verifyEqual(testCase, result.summary.legacy_ndi_document.bodies_carried_no_migrator, 1);
doc = result.migrated{1};
% carried whole as v1: stamped did_v1, and its depends_on is v1's own, as
% written (no rename pass rewrites it)
verifyEqual(testCase, doc.get('document_class.schema_version'), 'did_v1');
dependsOn = doc.toStruct().depends_on;
verifyEqual(testCase, dependsOn(1).id, 'aabb1122ccdd3344_aaaa1111bbbb2222');
verifyEqual(testCase, dependsOn(1).version, '1');
verifyFalse(testCase, isfield(dependsOn, 'document_id'));
end


function testALegacyBlockBesideBaseIsReadAsBase(testCase)
% [old ndi_document blocks carry] (Decided by Jess Haley, 2026-10-27), as
% amended by [ndi_document read as base] (Decided by Jess Haley, 2026-10-31,
% did-schema did_v2_go_forward_class_audit.md): the block is read as v1
% `base`. A block stating what `base` cannot hold (here `type`, outside
% base.json) carries the document under carry-100; one that only restates
% `base` does not carry it.
v1 = makeV1Skeleton('treatment');
v1.treatment = struct('ontologyName', 'NCIT:C0000', 'name', 'a drug', ...
    'numeric_value', [], 'string_value', '');
v1.ndi_document = struct('name', 'jrclust.prm');
v1 = jsondecode(jsonencode(v1));
% the raw path: a block with a field outside base.json carries, carry-100
typed = v1;
typed.ndi_document = struct('type', 'treatment');
result = did2.convert.v1_to_v2(typed, 'Validate', false);
verifyEmpty(testCase, result.quarantine);
assertEqual(testCase, numel(result.migrated), 1);
emitted = result.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1');
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, typed), 'the carry is not the v1 source');
d = result.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, ['[carry-100] malformed: outside the NDI template, ' ...
    'unplaced: ndi_document.type']), d);
verifyEqual(testCase, result.summary.legacy_ndi_document.ndi_document_block_seen, 1);
% the raw path: a block that restates `base` is `base`; it carries nothing
same = v1;
same.ndi_document = struct('id', v1.base.id);
result = did2.convert.v1_to_v2(same, 'Validate', false);
if isfield(result.summary.migration_notes, 'carried_as_v1')
    d = strjoin(cellstr(result.summary.migration_notes.carried_as_v1.distinct_details), ' || ');
    verifyFalse(testCase, contains(d, 'ndi_document'), d);
end
% an EMPTY block ([]) is no block ([empty ndi_document block is notation]):
% nothing to keep, the document converts or carries for its own reasons
v0 = v1;
v0.ndi_document = [];
result = did2.convert.v1_to_v2(v0, 'Validate', false);
if isfield(result.summary.migration_notes, 'carried_as_v1')
    d = strjoin(cellstr(result.summary.migration_notes.carried_as_v1.distinct_details), ' || ');
    verifyFalse(testCase, contains(d, 'ndi_document'), d);
end
end

function testAnEmptyLegacyBlockIsNotationAndTheDocumentConverts(testCase)
% [empty ndi_document block is notation] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): an empty `ndi_document: {}`
% beside `base` does not carry the document; it converts, and
% the round trip counts a missing block and an empty one as the same
v1 = did2.unittest.helpers.ndiDocument('subject', 'Id', 'aabb1122ccdd3344_00000000000000e1', ...
    'SessionId', 'aabb1122ccdd3344_9900aabbccddeeff', 'Datestamp', '2024-06-01T12:00:00.000Z');
v1.subject.local_identifier = 'mouse_9';
v1.subject.description = '';
v1.ndi_document = struct();
v1 = jsondecode(jsonencode(v1));
verifyTrue(testCase, isfield(v1, 'ndi_document'), 'the fixture keeps its {} block');
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEmpty(testCase, result.quarantine);
verifyEqual(testCase, result.summary.passthrough_count, 0, 'converted, not carried');
verifyEqual(testCase, result.summary.legacy_ndi_document.ndi_document_block_seen, 0, ...
    'an empty block is no block');
r = did2.convert.roundtrip.check(v1, result.migrated);
verifyFalse(testCase, any(strcmp({r.lost.path}, 'ndi_document')), 'a missing and an empty block are the same');
verifyTrue(testCase, r.ok, strjoin([{r.lost.path}, r.invented, r.unplaced], '; '));
% a block whose fields are all empty is empty too; one with a value carries
verifyTrue(testCase, did2.convert.isEmptyBlock(struct('name', '', 'id', [])));
verifyFalse(testCase, did2.convert.isEmptyBlock(struct('name', 'jrclust.prm')));
end


function testAStatementWithAV1NameIsCarriedAndCounted(testCase)
% [v1 name goes to the class's own name field] (Decided by Jess Haley,
% 2026-10-27, did-schema V_eta_go_forward_class_audit.md): "a statement with a
% non-empty v1 name is carried whole as v1 with a needs-home register row, and
% the number of such statements is counted in the next corpus run" (carry-106)
v1 = makeV1Skeleton('treatment');
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.treatment = struct('ontologyName', 'EMPTY:0000199', ...
    'name', 'treatment: grating direction-of-motion visual stimulation', ...
    'numeric_value', 6.5, 'string_value', '');
v1.base.name = 'a named treatment';
v1 = jsondecode(jsonencode(v1));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEmpty(testCase, result.quarantine);
verifyEqual(testCase, result.summary.passthrough_count, 1, 'carried');
emitted = result.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
notes = result.summary.migration_notes;
d = notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-106] awaiting_home: base.name "a named treatment"'), d);
verifyEqual(testCase, notes.v1_name_statement_carried.count, 1, 'the count');
verifyEqual(testCase, notes.v1_name_statement_carried.by_class.treatment, 1);
% the same treatment with no name converts, and counts nothing
v1.base.name = '';
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.passthrough_count, 0, 'converted');
verifyFalse(testCase, isfield(result.summary.migration_notes, 'v1_name_statement_carried'));
end

function testAV1NameTheEntityHoldsDoesNotCarry(testCase)
% the name written to the class's own name field ([v1 name is the entity
% name]) is kept: the document converts
v1 = makeV1Skeleton('subject');
v1.subject = struct('local_identifier', 'mouse_42@lab', 'description', '');
v1.base.name = 'mouse_42@lab';
v1 = jsondecode(jsonencode(v1));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEmpty(testCase, result.quarantine);
verifyEqual(testCase, result.summary.passthrough_count, 0, 'converted');
verifyEqual(testCase, char(result.migrated{1}.get('entity.name')), 'mouse_42@lab');
verifyFalse(testCase, isfield(result.summary, 'migration_notes') ...
    && isfield(result.summary.migration_notes, 'v1_name_not_kept'), ...
    'a name the entity holds is not counted as not kept');
end

function testTheRoutesReachTheBatchSummaryAndPartitionIt(testCase)
% Every body takes exactly one route, or fails before any; the routing table
% (summary.legacy_ndi_document, which writeCorpusReport persists and
% tools/census_digest.py renders) partitions the batch, denominator first.
tmpl = setTemplates(testCase);  %#ok<NASGU>
bodies = {makeSubject(), carriedProjectvar(), makeEnsemble(), ...
    parentOnly('epochid'), unknownClass(), '[1, 2]'};
already = makeTargetSkeleton('some_unregistered_class');
already.some_unregistered_class = struct();
bodies{end+1} = already;
result = did2.convert.v1_to_v2(bodies, 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 7);
verifyEqual(testCase, L.bodies_read_raw_v1, 1);
verifyEqual(testCase, L.bodies_carried_no_migrator, 1);
verifyEqual(testCase, L.bodies_handed_to_later_step, 1);
verifyEqual(testCase, L.bodies_carried_parent_only, 1);
verifyEqual(testCase, L.bodies_no_migrator_quarantined, 1);
verifyEqual(testCase, L.bodies_skipped_already_target, 1);
verifyEqual(testCase, L.bodies_unreached, 1, 'the JSON that is not an object');
verifyEqual(testCase, L.later_step_template_checked, 1);
verifyEqual(testCase, L.later_step_template_not_checked, 0);
verifyEqual(testCase, L.later_step_carried_malformed, 0);
end

function testTheRoutingTableIsPresentAndZeroWhenNoBodyTakesARoute(testCase)
% A zero row is a PRINTED zero: "no body took this route", never an absent
% counter.
result = did2.convert.v1_to_v2(makeSubject(), 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 1);
verifyEqual(testCase, L.bodies_read_raw_v1, 1);
for f = {'bodies_carried_no_migrator', 'bodies_handed_to_later_step', ...
        'bodies_carried_parent_only', 'bodies_no_migrator_quarantined', ...
        'bodies_unreached', 'ndi_document_block_seen'}
    verifyEqual(testCase, L.(f{1}), 0, f{1});
end
end

function testTheRoutingSeparatesTheIdempotencyShortCircuit(testCase)
% A body already at the target is not routed, so it must NOT be counted on a
% route. Without this, a re-run over migrated bodies would read as routed.
already = makeV1Skeleton('treatment');
already.treatment = struct();
already.document_class.schema_version = 'did_v2';
result = did2.convert.v1_to_v2(already, 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 1);
verifyEqual(testCase, L.bodies_read_raw_v1, 0);
verifyEqual(testCase, L.bodies_skipped_already_target, 1);
verifyEqual(testCase, L.bodies_unreached, 0);
end

% ===================== the routes without a migrator ========================
% [ensemble and generic_file keep their conversions], [ensemble and
% generic_file checked as v1], [last rename-pass classes] (Decided by Jess
% Haley, 2026-11-01, did-schema did_v2_go_forward_class_audit.md). The NDI
% templates are DID-matlab's verbatim copies of NDI-matlab's at the locked main
% (tests/+did2/fixtures/ndi_templates).

function testAnEnsembleIsCheckedAgainstItsTemplateAndHandedOnAsV1(testCase)
tmpl = setTemplates(testCase);  %#ok<NASGU>
v1 = makeEnsemble();
result = did2.convert.v1_to_v2(v1, 'Validate', true);
verifyEmpty(testCase, result.quarantine, 'never validated against V_eta');
assertEqual(testCase, numel(result.migrated), 1);
emitted = result.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1');
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'handed on unchanged, as v1 wrote it');
verifyEqual(testCase, result.summary.passthrough_count, 1, ...
    'recorded, so what the later step does not convert is stored as its v1 source');
verifyEqual(testCase, result.source_outputs(1).carried, false, 'not a carry');
verifyFalse(testCase, isfield(result.summary.migration_notes, 'carried_as_v1'));
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_handed_to_later_step, 1);
verifyEqual(testCase, L.later_step_template_checked, 1);
end

function testAGenericFileIsHandedOnAndAFieldOutsideItsTemplateCarries(testCase)
tmpl = setTemplates(testCase);  %#ok<NASGU>
v1 = makeGenericFile();
result = did2.convert.v1_to_v2(v1, 'Validate', true);
verifyEmpty(testCase, result.quarantine);
emitted = result.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1');
verifyEqual(testCase, emitted.generic_file.formatOntology, 'EDAM:format_3475', ...
    'the v1 spelling, unchanged');
verifyFalse(testCase, result.source_outputs(1).carried);
% a field the template does not define: carried whole, carry-100
odd = v1;
odd.generic_file.format_ontology = 'EDAM:format_3475';
result = did2.convert.v1_to_v2(odd, 'Validate', true);
verifyEmpty(testCase, result.quarantine);
verifyTrue(testCase, result.source_outputs(1).carried);
d = result.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-100] malformed: outside the NDI template: '), d);
verifyTrue(testCase, contains(d, 'generic_file.format_ontology'), d);
verifyEqual(testCase, result.summary.legacy_ndi_document.later_step_carried_malformed, 1);
end

function testAnEnsembleNeuronEdgeIsAWriterFieldNotMalformed(testCase)
% [writer fields over the template are template fields] (Jess Haley,
% 2026-10-27): NDI's ensemble writer adds `neuron_id_1`, `neuron_id_2`, ...,
% which ensemble.json does not declare
tmpl = setTemplates(testCase);  %#ok<NASGU>
v1 = makeEnsemble();
v1.depends_on(end+1) = struct('name', 'neuron_id_1', 'value', 'aabb1122ccdd3344_000000000000ee01');
v1.depends_on(end+1) = struct('name', 'neuron_id_2', 'value', 'aabb1122ccdd3344_000000000000ee02');
result = did2.convert.v1_to_v2(v1, 'Validate', true);
verifyEmpty(testCase, result.quarantine);
verifyFalse(testCase, result.source_outputs(1).carried);
verifyEqual(testCase, result.summary.legacy_ndi_document.later_step_carried_malformed, 0);
% an edge no writer writes is outside the template
v1.depends_on(end+1) = struct('name', 'stray_id', 'value', 'aabb1122ccdd3344_000000000000ee03');
result = did2.convert.v1_to_v2(v1, 'Validate', true);
verifyTrue(testCase, result.source_outputs(1).carried);
end

function testWithNoTemplateAHandedOnDocumentIsCountedNotChecked(testCase)
prev = getenv('DID_NDI_TEMPLATE_PATH');
prevNdi = getenv('NDI_MATLAB');
testCase.addTeardown(@() setenv('DID_NDI_TEMPLATE_PATH', prev));
testCase.addTeardown(@() setenv('NDI_MATLAB', prevNdi));
setenv('DID_NDI_TEMPLATE_PATH', '');
setenv('NDI_MATLAB', '');
result = did2.convert.v1_to_v2(makeEnsemble(), 'Validate', false);
L = result.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_handed_to_later_step, 1);
verifyEqual(testCase, L.later_step_template_checked, 0);
verifyEqual(testCase, L.later_step_template_not_checked, 1, 'NOT CHECKED, never read as valid');
end

function testASuperclassOnlyClassStandingAloneIsMalformed(testCase)
for c = {'app', 'calculator', 'epochid', 'stimulus_response', ...
        'stimulus_response_scalar_parameters'}
    v1 = parentOnly(c{1});
    result = did2.convert.v1_to_v2(v1, 'Validate', true);
    verifyEmpty(testCase, result.quarantine, c{1});
    verifyTrue(testCase, result.source_outputs(1).carried, c{1});
    emitted = result.migrated{1}.toStruct();
    verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1', c{1});
    d = result.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-100] malformed: '), d);
    verifyEqual(testCase, result.summary.legacy_ndi_document.bodies_carried_parent_only, 1, c{1});
end
end

function testTheTwoNdiCalcVisClassesWithNoV2ClassAreCarriedWhole(testCase)
% [last rename-pass classes]: "a v1 `hartley_reverse_correlation` or
% `reverse_correlation` is carried unchanged as v1, each with its own carry
% row" (rows added to did-schema with this change; '[carry-pending]' until
% they are on did-schema main)
for c = {'hartley_reverse_correlation', 'reverse_correlation'}
    v1 = makeV1Skeleton(c{1});
    v1.(c{1}) = struct('foo', 'bar');
    v1 = jsondecode(jsonencode(v1));
    result = did2.convert.v1_to_v2(v1, 'Validate', true);
    verifyEmpty(testCase, result.quarantine, c{1});
    verifyTrue(testCase, result.source_outputs(1).carried, c{1});
    emitted = result.migrated{1}.toStruct();
    emitted.document_class = rmfield(emitted.document_class, 'schema_version');
    verifyTrue(testCase, isequaln(emitted, v1), [c{1} ': the carry is not the v1 source']);
    verifyEqual(testCase, result.summary.legacy_ndi_document.bodies_carried_no_migrator, 1, c{1});
    verifyNotEmpty(testCase, did2.convert.noMigratorCarryRows(c{1}), c{1});
end
end

function restore = setTemplates(testCase)
prev = getenv('DID_NDI_TEMPLATE_PATH');
testCase.addTeardown(@() setenv('DID_NDI_TEMPLATE_PATH', prev));
thisDir = fileparts(mfilename('fullpath'));
setenv('DID_NDI_TEMPLATE_PATH', fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates'));
restore = prev;
end

function v1 = carriedProjectvar()
v1 = makeV1Skeleton('projectvar');
v1.base.id = 'aabb1122ccdd3344_00000000000000c1';
v1.projectvar = struct('foo', 'bar');
end

function v1 = unknownClass()
v1 = makeV1Skeleton('unknown_class');
v1.base.id = 'aabb1122ccdd3344_00000000000000c3';
v1.unknown_class = struct('foo', 'bar');
end

function v1 = parentOnly(className)
v1 = makeV1Skeleton(className);
v1.base.id = 'aabb1122ccdd3344_00000000000000c4';
v1.(className) = struct();
v1 = jsondecode(jsonencode(v1));
end

function v1 = makeEnsemble()
% NDI's ensemble writer (ndi.element.ensemble/buildMapDoc at the locked main)
v1 = struct();
v1.document_class = struct('definition', '$NDIDOCUMENTPATH/ensemble/ensemble.json', ...
    'validation', '$NDISCHEMAPATH/ensemble/ensemble_schema.json', ...
    'class_name', 'ensemble', 'property_list_name', 'ensemble', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json', ...
    '$NDIDOCUMENTPATH/epochid.json', '$NDIDOCUMENTPATH/app.json'}));
v1.depends_on = struct('name', {'element_id', 'element_epoch_id'}, ...
    'value', {'aabb1122ccdd3344_00000000000000d1', 'aabb1122ccdd3344_00000000000000d2'});
v1.files = struct('file_list', {{'neuron_names.txt'}});
v1.ensemble = struct('ensemble_name', 'e1', 'value_type', 'spikes', ...
    'value_description', '', 'num_neurons', 0, 'clocktype', 'dev_local_time');
v1.base = struct('id', 'aabb1122ccdd3344_00000000000000c2', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00001');
v1.app = struct('name', 'ndi.element.ensemble', 'version', '', 'url', '', ...
    'os', '', 'os_version', '', 'interpreter', '', 'interpreter_version', '');
v1 = jsondecode(jsonencode(v1));
end

function v1 = makeGenericFile()
v1 = struct();
v1.document_class = struct('definition', '$NDIDOCUMENTPATH/data/generic_file.json', ...
    'validation', '$NDISCHEMAPATH/data/generic_file_schema.json', ...
    'class_name', 'generic_file', 'property_list_name', 'generic_file', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json'}));
v1.depends_on = struct('name', {'document_id'}, 'value', {'aabb1122ccdd3344_00000000000000d3'});
v1.files = struct('file_list', {{'generic_file.ext'}});
v1.generic_file = struct('filename', 'plasmid.gb', 'formatOntology', 'EDAM:format_3475', ...
    'dateCreated', '', 'dateUpdated', '', 'checksum', '');
v1.base = struct('id', 'aabb1122ccdd3344_00000000000000c5', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1 = jsondecode(jsonencode(v1));
end


% ===========================================================================
% VERSION ORDERING AND THE REFUSAL
% ===========================================================================
% `isAlreadyTarget` compared schema_version to the target with strcmp, so a
% document NEWER than the target was indistinguishable from one OLDER, and both
% took the branch that runs the migrators. These pin the ordering and the
% refusal that replaced it.

function testABodyBelowTheTargetStillConverts(testCase)
% The counterpart of the short-circuit, so the ordering cannot pass by
% skipping everything. A body stamped with a known earlier name ('V_zeta')
% ranks below V_eta: it is routed (here to its migrator) and leaves stamped
% 'did_v2'.
v1 = makeSubject();
v1.document_class.schema_version = 'V_zeta';
r = did2.convert.v1_to_v2({v1}, 'Validate', false);
verifyEmpty(testCase, r.quarantine, 'a body below the target was refused');
verifyNotEmpty(testCase, r.migrated);
verifyEqual(testCase, ...
    r.migrated{1}.toStruct().document_class.schema_version, 'did_v2');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, 1, ...
    'a body below the target must be routed');
end

function testAnyOtherTargetIsRefused(testCase)
% V_eta is the only target. Asking for another (a made-up 'V_none', or an
% earlier name such as 'V_zeta') is an argument-validation error, not a silent
% fallback to V_eta.
v1 = makeV1Skeleton('unknown_class');
v1.unknown_class = struct('foo', 'bar');
for target = {'V_none', 'V_zeta'}
    verifyError(testCase, ...
        @() did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', target{1}), ...
        'MATLAB:validators:mustBeMember', target{1});
end
end

function testTheDefaultTargetIsVEta(testCase)
% A caller that names no target (did2.convert.fromV1Database, ndi.migrate.cloud)
% gets V_eta.
r = did2.convert.v1_to_v2({makeSubject()}, 'Validate', false);
verifyEqual(testCase, ...
    r.migrated{1}.toStruct().document_class.schema_version, 'did_v2');
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
r = did2.convert.v1_to_v2({v1}, 'Validate', false);
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
v1 = makeSubject();
verifyFalse(testCase, isfield(v1.document_class, 'schema_version'), ...
    'the fixture already declares a version; this test would prove nothing');
r = did2.convert.v1_to_v2({v1}, 'Validate', false);
verifyEmpty(testCase, r.quarantine, 'a did_v1 body was refused');
verifyNotEmpty(testCase, r.migrated);
end

function testTheVersionRankOrdersTheLineAndFlagsTheUnknown(testCase)
[r0, k0] = did2.convert.schemaVersionRank('');
[rd, kd] = did2.convert.schemaVersionRank('V_zeta');
[re, ke] = did2.convert.schemaVersionRank('did_v2');
[rx, kx] = did2.convert.schemaVersionRank('V_omega');
verifyTrue(testCase, k0 && kd && ke);
verifyEqual(testCase, r0, 0, 'did_v1 is the origin of the line');
verifyTrue(testCase, rd < re, 'V_zeta must rank before did_v2');
verifyFalse(testCase, kx, 'an unknown name must not be reported as known');
verifyTrue(testCase, isnan(rx), ...
    'an unknown name must not get rank 0 -- that is did_v1, "convert this"');
end
