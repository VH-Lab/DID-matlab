function tests = testDocumentStamps
%TESTDOCUMENTSTAMPS The document stamps 'did_v1' and 'did_v2', read everywhere.
%
%   Decided by Jess Haley, 2026-10-25 [document stamps] (did-schema
%   V_eta_go_forward_class_audit.md): a v1 document's
%   document_class.schema_version is 'did_v1' and a V2 document's is
%   'did_v2' (it is 'V_eta' today). THIS STAGE: readers accept both 'V_eta'
%   and 'did_v2' as V2, and 'did_v1' (or no stamp) as v1; writers still
%   stamp 'V_eta'. 'V_eta' acceptance is transitional ([V_eta stamp not
%   accepted], same date): it is one entry of did2.schema.v2Stamps.
%
%   Also pins the pass-1 passthrough record ([passthrough stays v1: how]):
%   v1_to_v2 records each v1 document no migrator changed, so the caller
%   running the whole pipeline (ndi.migrate.local) can stamp it 'did_v1'.
%
%   Run with:
%       results = runtests('did2.unittest.testDocumentStamps');

tests = functiontests(localfunctions);
end

function testTheV2StampsAreOneList(testCase)
v2 = did2.schema.v2Stamps();
verifyTrue(testCase, iscellstr(v2));
verifyTrue(testCase, ismember('did_v2', v2), 'did_v2 is the V2 stamp');
verifyFalse(testCase, ismember('did_v1', v2));
verifyFalse(testCase, ismember('', v2));
end

function testTheRankPlacesBothNewStamps(testCase)
[r1, k1] = did2.convert.schemaVersionRank('did_v1');
[r0, k0] = did2.convert.schemaVersionRank('');
[r2, k2] = did2.convert.schemaVersionRank('did_v2');
[re, ke] = did2.convert.schemaVersionRank('V_eta');
verifyTrue(testCase, k1 && k0 && k2 && ke, ...
    'did_v1, did_v2, V_eta and the empty name must all be known');
verifyEqual(testCase, r1, 0, 'did_v1 is v1: rank 0, like the empty name');
verifyEqual(testCase, r1, r0);
verifyEqual(testCase, r2, re, 'did_v2 is the generation V_eta stamps today');
[~, kx] = did2.convert.schemaVersionRank('did_v3');
verifyFalse(testCase, kx, 'an unknown name stays unknown');
end

function testIsV2Stamp(testCase)
verifyTrue(testCase, did2.schema.isV2Stamp('V_eta'));
verifyTrue(testCase, did2.schema.isV2Stamp('did_v2'));
verifyTrue(testCase, did2.schema.isV2Stamp("did_v2"));
verifyFalse(testCase, did2.schema.isV2Stamp('did_v1'));
verifyFalse(testCase, did2.schema.isV2Stamp(''));
verifyFalse(testCase, did2.schema.isV2Stamp('V_zeta'), 'a brainstorm name is not V2');
verifyFalse(testCase, did2.schema.isV2Stamp('V_omega'));
verifyTrue(testCase, did2.schema.isV2Stamp(bodyStamped('did_v2')));
verifyTrue(testCase, did2.schema.isV2Stamp(did2.document(bodyStamped('V_eta'))));
verifyFalse(testCase, did2.schema.isV2Stamp(bodyStamped('')));
verifyFalse(testCase, did2.schema.isV2Stamp(bodyUnstamped()));
end

function testIsV1Stamp(testCase)
verifyTrue(testCase, did2.schema.isV1Stamp('did_v1'));
verifyTrue(testCase, did2.schema.isV1Stamp(''), 'no stamp is v1, as today');
verifyTrue(testCase, did2.schema.isV1Stamp(bodyUnstamped()));
verifyTrue(testCase, did2.schema.isV1Stamp(bodyStamped('did_v1')));
verifyFalse(testCase, did2.schema.isV1Stamp('V_eta'));
verifyFalse(testCase, did2.schema.isV1Stamp('did_v2'));
verifyFalse(testCase, did2.schema.isV1Stamp('V_zeta'));
verifyFalse(testCase, did2.schema.isV1Stamp('V_omega'));
% Explicit: the stamp must be present
verifyTrue(testCase, did2.schema.isV1Stamp('did_v1', 'Explicit', true));
verifyFalse(testCase, did2.schema.isV1Stamp('', 'Explicit', true));
verifyFalse(testCase, did2.schema.isV1Stamp(bodyUnstamped(), 'Explicit', true));
end

function testStampOf(testCase)
verifyEqual(testCase, did2.schema.stampOf(bodyStamped('did_v2')), 'did_v2');
verifyEqual(testCase, did2.schema.stampOf(bodyStamped("V_eta")), 'V_eta');
verifyEqual(testCase, did2.schema.stampOf(bodyUnstamped()), '');
verifyEqual(testCase, did2.schema.stampOf(42), '');
end

function testADidV2BodyIsAlreadyTarget(testCase)
verifyTrue(testCase, did2.convert.isAlreadyTarget(bodyStamped('did_v2'), 'V_eta'));
verifyTrue(testCase, did2.convert.isAlreadyTarget(bodyStamped('V_eta'), 'V_eta'));
verifyFalse(testCase, did2.convert.isAlreadyTarget(bodyStamped('did_v1'), 'V_eta'));
end

function testARerunNeverQuarantinesTheNewStamps(testCase)
% A re-run over documents carrying either new stamp converts (did_v1) or
% short-circuits (did_v2); neither is refused as an unknown vintage.
for sv = {'did_v1', 'did_v2'}
    b = bodyStamped(sv{1});
    b.unknown_class = struct('foo', 'bar');
    r = did2.convert.v1_to_v2({b}, 'Validate', false);
    verifyEmpty(testCase, r.quarantine, sprintf('%s was quarantined', sv{1}));
    verifyNumElements(testCase, r.migrated, 1);
end
end

function testADidV2BodyShortCircuits(testCase)
b = bodyStamped('did_v2');
b.unknown_class = struct('foo', 'bar');
r = did2.convert.v1_to_v2({b}, 'Validate', false);
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_skipped_already_target, 1);
end

function testPassOneRecordsAPassthrough(testCase)
% unknown_class has no migrator (identity): recorded, with its position, id
% and the body pass 1 emitted.
b = bodyUnstamped();
b.unknown_class = struct('foo', 'bar');
r = did2.convert.v1_to_v2({b}, 'Validate', false);
verifyNumElements(testCase, r.passthrough, 1);
verifyEqual(testCase, r.summary.passthrough_count, 1);
verifyEqual(testCase, r.passthrough(1).input_index, 1);
verifyEqual(testCase, r.passthrough(1).id, b.base.id);
verifyEqual(testCase, r.passthrough(1).class_name, 'unknown_class');
verifyTrue(testCase, isequaln(r.passthrough(1).body, r.migrated{1}.toStruct()), ...
    'the recorded body must be the body pass 1 emitted');
% writers still stamp 'V_eta' at this stage
verifyEqual(testCase, r.migrated{1}.toStruct().document_class.schema_version, 'V_eta');
end

function testPassOneDoesNotRecordAShortCircuit(testCase)
% A body already at the target took no migrator: not a passthrough.
b = bodyStamped('V_eta');
b.unknown_class = struct('foo', 'bar');
r = did2.convert.v1_to_v2({b}, 'Validate', false);
verifyEmpty(testCase, r.passthrough);
verifyEqual(testCase, r.summary.passthrough_count, 0);
end

% ---- fixtures ----

function b = bodyUnstamped()
b = struct();
b.document_class = struct( ...
    'class_name',    'unknown_class', ...
    'class_version', '1.0.0', ...
    'superclasses',  struct('class_name', 'base', 'class_version', '1.0.0'));
b.depends_on = struct('name', {}, 'document_id', {});
b.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'unit-test', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
end

function b = bodyStamped(sv)
b = bodyUnstamped();
b.document_class.schema_version = sv;
end
