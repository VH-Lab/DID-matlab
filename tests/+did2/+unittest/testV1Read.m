function tests = testV1Read
%TESTV1READ The raw-v1 reading helpers, did2.convert.v1read.*.
%
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): `depends_on`, the `base` and `app`
%   blocks and the stamp are read by shared helpers on the RAW v1 document,
%   not rewritten by a pass. Each helper is tested on the v1 shapes NDI writes
%   (templates at the locked NDI-matlab `main` 3cb19a8, copied into
%   tests/+did2/fixtures/ndi_templates) and on the older or already-renamed
%   shapes universalRenames used to fold together, and each is checked to
%   DROP NOTHING: what it cannot name it returns in `other` / `extra`.
tests = functiontests(localfunctions);
end

% ===================== readDependsOn ===================================

function testDependsOnReadsTheNdiValueShape(testCase)
body = struct('depends_on', struct('name', {'subject_id_1', 'subject_id_2'}, ...
    'value', {'m_1', 'm_2'}));
d = did2.convert.v1read.readDependsOn(body);
verifyEqual(testCase, numel(d), 2);
verifyEqual(testCase, {d.name}, {'subject_id_1', 'subject_id_2'});
verifyEqual(testCase, {d.document_id}, {'m_1', 'm_2'});
verifyEqual(testCase, {d.source_key}, {'value', 'value'});
verifyEqual(testCase, d(1).version, '');
verifyEmpty(testCase, fieldnames(d(1).other));
end

function testDependsOnKeepsTheVersionOfTheIdShape(testCase)
% the older {name, id, version} shape: universalRenames dropped `version`
body = struct('depends_on', struct('name', 'element_id', 'id', 'e_1', 'version', '2'));
d = did2.convert.v1read.readDependsOn(body);
verifyEqual(testCase, d.document_id, 'e_1');
verifyEqual(testCase, d.source_key, 'id');
verifyEqual(testCase, d.version, '2');
end

function testDependsOnReadsARenamedEntry(testCase)
body = struct('depends_on', struct('name', 'element_id', 'document_id', 'e_1'));
d = did2.convert.v1read.readDependsOn(body);
verifyEqual(testCase, d.document_id, 'e_1');
verifyEqual(testCase, d.source_key, 'document_id');
end

function testDependsOnKeepsAConflictingKey(testCase)
% `value` wins; an `id` that names a DIFFERENT document is kept in `other`
% (universalRenames reported it in carry-049 and discarded it); one that
% restates the winner is not repeated.
body = struct('depends_on', struct('name', {'a', 'b'}, 'value', {'x', 'y'}, ...
    'id', {'z', 'y'}));
d = did2.convert.v1read.readDependsOn(body);
verifyEqual(testCase, d(1).document_id, 'x');
verifyEqual(testCase, d(1).other, struct('id', 'z'));
verifyEmpty(testCase, fieldnames(d(2).other));
end

function testDependsOnKeepsAnUnknownKey(testCase)
body = struct('depends_on', struct('name', 'a', 'value', 'x', 'note', 'kept'));
d = did2.convert.v1read.readDependsOn(body);
verifyEqual(testCase, d.other, struct('note', 'kept'));
end

function testDependsOnFiltersByName(testCase)
body = struct('depends_on', struct('name', {'subject_id_1', 'session_id', 'subject_id'}, ...
    'value', {'m_1', 's', 'm_0'}));
d = did2.convert.v1read.readDependsOn(body, 'Name', '^subject_id(_\d+)?$');
verifyEqual(testCase, {d.document_id}, {'m_1', 'm_0'});
end

function testDependsOnReadsACellOfEntries(testCase)
% jsondecode gives a cell when the entries carry different keys
body = jsondecode('{"depends_on":[{"name":"a","value":"x"},{"name":"b","id":"y","version":3}]}');
verifyTrue(testCase, iscell(body.depends_on), 'fixture premise: a cell');
d = did2.convert.v1read.readDependsOn(body);
verifyEqual(testCase, {d.document_id}, {'x', 'y'});
verifyEqual(testCase, d(2).version, 3);
end

function testDependsOnAbsentOrEmptyIsAnEmptyList(testCase)
for body = {struct(), struct('depends_on', []), jsondecode('{"depends_on":[]}')}
    d = did2.convert.v1read.readDependsOn(body{1});
    verifyEmpty(testCase, d);
    verifyTrue(testCase, isfield(d, 'document_id'), 'the fields are there, even empty');
end
end

function testDependsOnRefusesAShapeV1NeverWrites(testCase)
verifyError(testCase, @() did2.convert.v1read.readDependsOn(struct('depends_on', 'x')), ...
    'did2:convert:v1read:badDependsOn');
end

% ===================== readBase ========================================

function testBaseReadsTheTemplateFields(testCase)
tpl = loadTemplate(testCase, 'base');
tpl.base.id = 'i_1';
tpl.base.session_id = 's_1';
tpl.base.name = 'n';
b = did2.convert.v1read.readBase(tpl);
verifyEqual(testCase, b.source, 'base');
verifyEqual(testCase, {b.id, b.session_id, b.name, b.datestamp}, ...
    {'i_1', 's_1', 'n', '2018-12-05T18:36:47.241Z'});
verifyEqual(testCase, sort(b.present), sort({'id', 'session_id', 'name', 'datestamp'}));
verifyEmpty(testCase, fieldnames(b.extra));
end

function testBaseKeepsAFieldOutsideTheTemplate(testCase)
body = struct('base', struct('id', 'i', 'schema_version', 'V_eta'));
b = did2.convert.v1read.readBase(body);
verifyEqual(testCase, b.extra, struct('schema_version', 'V_eta'));
verifyEqual(testCase, b.present, {'id'});
end

function testBaseReadsTheLegacyBlockWithoutMovingIt(testCase)
% the 2019-12 vintage: `id` read; `experiment_id`, `type`,
% `database_version` returned in `extra`, not renamed
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_document_vintages', 'f4f9d9450.json');
tpl = jsondecode(fileread(f));
b = did2.convert.v1read.readBase(tpl);
verifyEqual(testCase, b.source, 'ndi_document');
verifyTrue(testCase, isfield(b.extra, 'experiment_id'));
verifyTrue(testCase, isfield(b.extra, 'database_version'));
verifyFalse(testCase, isfield(tpl, 'base'), 'the body itself is not changed');
end

function testBaseKeepsALegacyBlockBesideBase(testCase)
body = struct('base', struct('id', 'i'), 'ndi_document', struct('id', 'old'));
b = did2.convert.v1read.readBase(body);
verifyEqual(testCase, b.source, 'base');
verifyEqual(testCase, b.legacy, struct('id', 'old'));
% [ndi_document read as base] (Decided by Jess Haley, 2026-10-31): two
% different non-empty ids are a conflict; base's value is the one read
verifyEqual(testCase, b.id, 'i');
verifyEqual(testCase, b.conflict, {'ndi_document.id'});
end

function testALegacyBlockBesideBaseIsReadAsBase(testCase)
% [ndi_document read as base] (Decided by Jess Haley, 2026-10-31, did-schema
% did_v2_go_forward_class_audit.md): what `base` leaves empty is read from the
% block; an equal value restates it; a field outside base.json's four is
% returned in legacy_extra
body = struct('base', struct('id', 'i', 'session_id', 's', 'name', ''), ...
    'ndi_document', struct('id', 'i', 'name', 'jrclust.prm', 'type', 'x'));
b = did2.convert.v1read.readBase(body);
verifyEqual(testCase, b.source, 'base');
verifyEqual(testCase, b.id, 'i');
verifyEqual(testCase, b.name, 'jrclust.prm');
verifyEmpty(testCase, b.conflict);
verifyEqual(testCase, b.legacy_extra, struct('type', 'x'));
% an empty block states nothing
b0 = did2.convert.v1read.readBase(struct('base', struct('id', 'i', 'name', ''), ...
    'ndi_document', struct('name', '')));
verifyEmpty(testCase, b0.name);
verifyEmpty(testCase, b0.conflict);
end

function testBaseOfABodyWithNoneIsEmpty(testCase)
b = did2.convert.v1read.readBase(struct('x', 1));
verifyEqual(testCase, b.source, '');
verifyEmpty(testCase, b.present);
end

% ===================== readApp =========================================

function testAppReadsTheTemplateFields(testCase)
tpl = loadTemplate(testCase, 'app');
tpl.app.name = 'ndi_calc';
tpl.app.version = 'abc123';
tpl.app.os = 'GLNXA64';
a = did2.convert.v1read.readApp(tpl);
verifyTrue(testCase, a.present);
verifyEqual(testCase, a.name, 'ndi_calc');
verifyEqual(testCase, a.version, 'abc123');
verifyEqual(testCase, a.os, 'GLNXA64');
verifyEqual(testCase, a.app_name, '');
verifyEmpty(testCase, a.conflicts);
verifyEmpty(testCase, fieldnames(a.extra));
end

function testAppKeepsBothSpellingsWhenTheyDiffer(testCase)
% universalRenames kept app_name and DROPPED name (carry-049); both are kept
body = struct('app', struct('name', 'v1name', 'app_name', 'v2name', ...
    'version', '1', 'app_version', '1'));
a = did2.convert.v1read.readApp(body);
verifyEqual(testCase, a.name, 'v1name');
verifyEqual(testCase, a.app_name, 'v2name');
verifyEqual(testCase, a.conflicts, {'name'});
end

function testAppAbsentIsNotPresent(testCase)
a = did2.convert.v1read.readApp(struct('base', struct()));
verifyFalse(testCase, a.present);
verifyEqual(testCase, a.name, '');
end

function testAppKeepsAFieldOutsideTheTemplate(testCase)
a = did2.convert.v1read.readApp(struct('app', struct('name', 'x', 'build', 7)));
verifyEqual(testCase, a.extra, struct('build', 7));
end

% ===================== readStamp =======================================

function testStampReadsTheNdiTemplateClass(testCase)
tpl = loadTemplate(testCase, 'subject');
s = did2.convert.v1read.readStamp(tpl);
verifyEqual(testCase, s.class_name, 'subject');
verifyEqual(testCase, s.superclasses, {'base'}, 'derived from the definition path');
verifyEqual(testCase, s.class_version, 1);
verifyEqual(testCase, s.property_list_name, 'subject');
verifyEqual(testCase, s.schema_version, '');
verifyTrue(testCase, s.is_v1, 'an unstamped document is v1');
verifyFalse(testCase, s.is_v2);
end

function testStampNeverSnakeCasesTheClassName(testCase)
body = struct('document_class', struct('class_name', 'ontologyImage'));
s = did2.convert.v1read.readStamp(body);
verifyEqual(testCase, s.class_name, 'ontologyImage');
end

function testStampReadsTheClassNameFromTheDefinition(testCase)
body = struct('document_class', struct('definition', '$NDIDOCUMENTPATH/subject_group.json'));
s = did2.convert.v1read.readStamp(body);
verifyEqual(testCase, s.class_name, 'subject_group');
end

function testStampReadsTheGenerationStamp(testCase)
v2 = struct('document_class', struct('class_name', 'entity', 'schema_version', 'did_v2'));
s = did2.convert.v1read.readStamp(v2);
verifyTrue(testCase, s.is_v2);
verifyFalse(testCase, s.is_v1);
v1 = struct('document_class', struct('class_name', 'subject', 'schema_version', 'did_v1'));
s = did2.convert.v1read.readStamp(v1);
verifyTrue(testCase, s.is_v1);
end

function testStampKeepsAnUnknownField(testCase)
body = struct('document_class', struct('class_name', 'x', 'note', 'kept'));
s = did2.convert.v1read.readStamp(body);
verifyEqual(testCase, s.extra, struct('note', 'kept'));
end

% ===================== helpers =========================================

function tpl = loadTemplate(testCase, name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
verifyTrue(testCase, isfile(f), sprintf('NDI template fixture not found at %s', f));
tpl = jsondecode(fileread(f));
end
