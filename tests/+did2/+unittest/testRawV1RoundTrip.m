function tests = testRawV1RoundTrip
%TESTRAWV1ROUNDTRIP The classes switched to raw v1, and their round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md):
%     [migrators read raw v1]            a migrator reads v1 exactly as v1
%                                        defines it; migrators switch one at a
%                                        time (did2.convert.rawV1Classes)
%     [migration reliability practices]  (a) a round-trip check per class:
%                                        each converted document is migrated
%                                        back to v1 and compared with its
%                                        source (did2.convert.roundtrip.check)
%
%   The v1 documents here are built from NDI's templates at the locked
%   NDI-matlab `main` (3cb19a8; tests/+did2/fixtures/ndi_templates) in the
%   shapes NDI's writers give them, and pass through jsonencode/jsondecode, the
%   shape a corpus delivers:
%     subject        ndi.subject.newdocument (base.name = local_identifier)
%                    +NDIMaker/subjectMaker  (base.name left '')
%     subject_group  +babu/import (empty block, base.name '', members by
%                    add_dependency_value_n -> subject_id_1..N)
%   plus the DID-side shape with `group_name` the subject_group migrator reads.
%
%   Each round trip must report ok: every v1 leaf matched, restated (a value
%   that can only have been one of a stated few), not set (empty), or exempt
%   (the v1 document_class beyond its class name), and nothing lost, invented
%   or unplaced. Two tests break a document ON PURPOSE and require the round
%   trip to say so: a check that cannot fail proves nothing.
tests = functiontests(localfunctions);
end

% ===================== the switch ======================================

function testEverySwitchedClassHasAMigratorAndAnInverse(testCase)
names = did2.convert.rawV1Classes();
verifyNotEmpty(testCase, names);
for k = 1:numel(names)
    verifyNotEmpty(testCase, which(['did2.convert.migrators_j.' names{k}]), ...
        sprintf('%s is switched to raw v1 but has no +migrators_j migrator', names{k}));
    verifyNotEmpty(testCase, which(['did2.convert.roundtrip.' names{k}]), ...
        sprintf('%s is switched to raw v1 but has no round-trip inverse', names{k}));
end
end

function testASwitchedClassSkipsUniversalRenames(testCase)
% the denominator: a raw body is counted as read raw, not as reaching the pass
% and not as unreached; a class not on the list still reaches the pass
other = struct();
other.document_class = struct('class_name', 'unknown_class', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
other.depends_on = struct('name', {}, 'value', {});
other.base = struct('id', 'uc_1', 'session_id', 'sess_1', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
other.unknown_class = struct('foo', 'bar');
r = runRaw({ndiSubject('mouse_42', '', 'mouse_42'), other});
L = r.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_total, 2);
verifyEqual(testCase, L.bodies_read_raw_v1, 1);
verifyEqual(testCase, L.bodies_reaching_universal_renames, 1);
verifyEqual(testCase, L.bodies_unreached, 0);

r = did2.convert.v1_to_v2({ndiSubject('mouse_42', '', 'mouse_42')}, ...
    'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, 0, ...
    'RawV1Classes {} runs every class as before the switch');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_reaching_universal_renames, 1);
end

function testTheSwitchChangesNoConvertedDocument(testCase)
% "keep behaviour identical": every CONVERTED document the raw path emits is
% the one the universalRenames path emitted (ids are deterministic, practice
% (b), and every fixture states its datestamp)
fixtures = {ndiSubject('mouse_42@lab', 'a mouse', 'mouse_42@lab'), ...
    ndiSubject('mouse_43', '', ''), namedGroup({'m_1', 'm_2', 'm_3'})};
for k = 1:numel(fixtures)
    raw = runRaw(fixtures{k});
    old = did2.convert.v1_to_v2(fixtures{k}, 'Validate', false, ...
        'TargetVersion', 'V_eta', 'RawV1Classes', {});
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated));
    verifyEmpty(testCase, raw.quarantine);
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        verifyTrue(testCase, isequaln(raw.migrated{j}.toStruct(), old.migrated{j}.toStruct()), ...
            sprintf('fixture %d, document %d differs between the raw and the renamed path', k, j));
    end
end
end

% ===================== subject =========================================

function testNdiSubjectWriterShapeRoundTrips(testCase)
v1 = ndiSubject('mouse_42@lab', 'a C57 mouse', 'mouse_42@lab');
out = runRaw(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.summary.quarantine_count, 0);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r);
verifyFalse(testCase, r.carried);
% every field NDI's templates declare is accounted for, by name
accounted = [r.matched, r.restated, r.not_set];
for p = {'base.id', 'base.session_id', 'base.name', 'base.datestamp', ...
        'subject.local_identifier', 'subject.description', 'document_class.class_name'}
    verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
        sprintf('template field %s is not accounted for', p{1}));
end
end

function testSubjectMakerShapeRoundTrips(testCase)
% +NDIMaker/subjectMaker leaves base.name at the template's ''
v1 = ndiSubject('mouse_43', '', '');
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyRoundTrip(testCase, r);
verifyTrue(testCase, any(strcmp('base.name', [r.restated, r.not_set])));
end

function testADifferingBaseNameIsReportedLost(testCase)
% OPEN (a team decision): a v1 subject whose base.name is neither '' nor its
% local identifier. No NDI writer at the locked `main` writes one; V2 does not
% keep base.name (#73 item 54), so the value is not recoverable and the round
% trip must say so. Today the migrator converts it anyway.
v1 = ndiSubject('mouse_44', '', 'Mouse forty-four');
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'base.name'});
end

function testAFieldOutsideTheTemplateIsReportedLost(testCase)
% the round trip fails on ANY dropped field: a subject field NDI's template
% does not declare is read by nothing, and the check names it
v1 = ndiSubject('mouse_45', '', 'mouse_45');
v1.subject.strain = 'C57BL/6J';
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp('subject.strain', {r.lost.path})));
end

function testASubjectWithNoLocalIdIsCarriedUntouched(testCase)
% carry-033: the carry is the RAW v1 source, stamped did_v1, nothing renamed
v1 = ndiSubject('', '', '');
out = runRaw(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, numel(out.passthrough), 1);
emitted = out.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1');
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carried body is not the untouched v1 source');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
verifyRoundTrip(testCase, r);
end

% ===================== subject_group ===================================

function testBabuShapedGroupIsCarriedAndRoundTrips(testCase)
% NDI's template block is empty: the group states no name, carry-034
v1 = babuGroup({'m_1', 'm_2', 'm_3'});
out = runRaw(v1);
verifyEqual(testCase, numel(out.migrated), 1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
verifyRoundTrip(testCase, r);
% the members are read from the v1 spelling, untouched
emitted = out.migrated{1}.toStruct();
verifyEqual(testCase, {emitted.depends_on.value}, {'m_1', 'm_2', 'm_3'});
end

function testNamedGroupRoundTripsWithItsMembers(testCase)
v1 = namedGroup({'m_1', 'm_2', 'm_3'});
out = runRaw(v1);
verifyEqual(testCase, numel(out.migrated), 4, 'the group and three member_of edges');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r);
verifyFalse(testCase, r.carried);
end

function testADroppedMemberEdgeIsReportedLost(testCase)
v1 = namedGroup({'m_1', 'm_2', 'm_3'});
out = runRaw(v1);
kept = out.migrated;
for k = numel(kept):-1:1
    if strcmp(kept{k}.className(), 'directed_relation')
        kept(k) = [];
        break;
    end
end
r = did2.convert.roundtrip.check(v1, kept);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(startsWith({r.lost.path}, 'depends_on(3)')));
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = ndiSubject('mouse_46', '', 'mouse_46');
out = runRaw(v1);
extra = runRaw(namedGroup({'m_9'})).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function verifyRoundTrip(testCase, r)
verifyGreaterThan(testCase, r.fields_inspected, 0, 'the round trip inspected nothing');
lost = '';
if ~isempty(r.lost)
    lost = strjoin({r.lost.path}, ', ');
end
verifyEmpty(testCase, r.lost, ['lost: ' lost]);
verifyEmpty(testCase, r.invented, ['invented: ' strjoin(r.invented, ', ')]);
verifyEmpty(testCase, r.unplaced, ['unplaced: ' strjoin(r.unplaced, '; ')]);
verifyTrue(testCase, r.ok);
end

function v1 = ndiSubject(localId, description, baseName)
% ndi.subject.newdocument / subjectMaker: subject.json over base.json
tpl = loadTemplate('subject');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.base = baseTpl.base;
v1.base.id = '41268b6f5c6a3d4e_c0d1a9e2b3f4a5b6';
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.name = baseName;
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.subject = tpl.subject;
v1.subject.local_identifier = localId;
v1.subject.description = description;
v1 = jsondecode(jsonencode(v1));
end

function v1 = babuGroup(memberIds)
% +babu/import: ndi.document('subject_group') + session.newdocument(), then
% add_dependency_value_n('subject_id', ...) per member
tpl = loadTemplate('subject_group');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = struct('name', {}, 'value', {});
for k = 1:numel(memberIds)
    v1.depends_on(k) = struct('name', sprintf('subject_id_%d', k), 'value', memberIds{k});
end
v1.base = baseTpl.base;
v1.base.id = '41268b6f5c6a3d4e_aa00000000000001';
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.subject_group = tpl.subject_group;
v1 = jsondecode(jsonencode(v1));
end

function v1 = namedGroup(memberIds)
% the DID-side shape the subject_group migrator converts: a group_name
v1 = babuGroup(memberIds);
v1.base.name = 'cohortB';
v1.subject_group = struct('group_name', 'cohortB', 'description', 'the treated cohort');
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
