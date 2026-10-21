function tests = testEntityRequires
%TESTENTITYREQUIRES did2.validate.entityRequires, the REPORT-ONLY census of
%   binding_registry_meta.json's entity_type_bindings `requires` (Jess Haley,
%   2026-10-21, "b"). Built from constructed entity bodies against a stub
%   registry, so it runs on any schema checkout.
tests = functiontests(localfunctions);
end

function testDenominatorFirstAndMissingCounted(testCase)
docs = {ent('e1', 'session', 'sess A', ''), ent('e2', 'session', '', ''), ...
        ent('e3', 'person', '', 'Ada'), ent('e4', 'person', '', ''), ...
        nonEntity('n1')};
rep = did2.validate.entityRequires(docs, 'SchemaCache', stubCache());
verifyEqual(testCase, rep.docs_inspected, 5);
verifyEqual(testCase, rep.entities_inspected, 4);
verifyEqual(testCase, rep.missing_total, 2);
s = row(rep, 'session', 'local_identifier');
verifyEqual(testCase, [s.inspected s.missing], [2 1]);
verifyEqual(testCase, s.missing_ids, {'e2'});
p = row(rep, 'person', 'name');
verifyEqual(testCase, [p.inspected p.missing], [2 1]);
verifyFalse(testCase, rep.registry_unavailable);
end

function testUntypedAndUnknownTypesAreCountedApart(testCase)
docs = {ent('e1', '', 'x', ''), ent('e2', 'spaceship', 'y', '')};
rep = did2.validate.entityRequires(docs, 'SchemaCache', stubCache());
verifyEqual(testCase, rep.entities_untyped, 1);
verifyEqual(testCase, rep.entities_type_without_row, 1);
verifyEqual(testCase, rep.missing_total, 0);
end

function testItRaisesNothingAndQuarantinesNothing(testCase)
% report-only: a batch of nothing but violations returns a report, no error
docs = {ent('e1', 'session', '', ''), ent('e2', 'session', '', '')};
rep = did2.validate.entityRequires(docs, 'SchemaCache', stubCache());
verifyEqual(testCase, rep.missing_total, 2);
end

% ---- fixtures -------------------------------------------------------------

function c = stubCache()
c = struct('bindingRegistry', struct('entity_type_bindings', ...
    struct('type', {'session', 'person'}, 'requires', {{'local_identifier'}, {'name'}})));
end

function b = ent(id, typ, lid, nm)
b = struct();
b.document_class = struct('class_name', 'entity', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 's', 'datestamp', '2024-01-01T00:00:00.000Z');
b.entity = struct('type', struct('node', '', 'name', typ), 'name', nm, ...
    'local_identifier', lid);
end

function b = nonEntity(id)
b = struct();
b.document_class = struct('class_name', 'chemical', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
b.base = struct('id', id);
end

function r = row(rep, t, f)
r = rep.by_type_field(strcmp({rep.by_type_field.entity_type}, t) ...
    & strcmp({rep.by_type_field.field}, f));
assert(isscalar(r), 'no single %s/%s row', t, f);
end
