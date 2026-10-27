function tests = testCarriedV1TemplateCheck
%TESTCARRIEDV1TEMPLATECHECK A document carried whole as v1 is checked against
%   NDI-matlab's v1 template for its class, not against did-schema tombstones.
%
%   Decided by Jess Haley, 2026-10-27 [carried v1 validates against NDI
%   templates] (did-schema V_eta_go_forward_class_audit.md). The templates here
%   are DID-matlab's verbatim copies of NDI-matlab's (locked main,
%   tests/+did2/fixtures/ndi_templates); the CI workflows point
%   DID_NDI_TEMPLATE_PATH at NDI-matlab's own folder at the locked main.
tests = functiontests(localfunctions);
end

function setup(testCase)
prev = getenv('DID_NDI_TEMPLATE_PATH');
testCase.addTeardown(@() setenv('DID_NDI_TEMPLATE_PATH', prev));
setenv('DID_NDI_TEMPLATE_PATH', templateRoot());
end

function testTheTemplatesAreReadWithTheirSuperclasses(testCase)
T = did2.schema.v1Templates(templateRoot());
verifyTrue(testCase, T.present);
verifyGreaterThan(testCase, T.count, 10, 'the denominator');
verifyTrue(testCase, isKey(T.byClass, 'subject'));
s = T.byClass('subject');
verifyTrue(testCase, isfield(s.blocks, 'subject'));
verifyTrue(testCase, isfield(s.blocks, 'base'), 'base merged in from its superclass');
verifyTrue(testCase, any(strcmp(s.blocks.base, 'session_id')));
end

function testAWriterShapedDocumentIsValidAndAnExtraFieldIsNot(testCase)
T = did2.schema.v1Templates(templateRoot());
v1 = subject('tc_subj_1', 'mouse_1');
r = did2.validate.v1Document(v1, T);
verifyTrue(testCase, r.checked);
verifyTrue(testCase, r.ok, strjoin(r.problems, '; '));
v1.subject.strain = 'C57BL/6';
r = did2.validate.v1Document(v1, T);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(contains(r.problems, 'subject.strain')), strjoin(r.problems, '; '));
v1 = subject('tc_subj_1', 'mouse_1');
v1.extra_block = struct('a', 1);
r = did2.validate.v1Document(v1, T);
verifyTrue(testCase, any(contains(r.problems, 'block extra_block')), strjoin(r.problems, '; '));
v1 = subject('tc_subj_1', 'mouse_1');
v1.document_class.class_name = 'no_such_class';
r = did2.validate.v1Document(v1, T);
verifyTrue(testCase, any(contains(r.problems, 'no NDI template')), strjoin(r.problems, '; '));
end

function testNoTemplatesIsNotCheckedNotValid(testCase)
T = did2.schema.v1Templates(fullfile(tempdir, 'did2-no-such-template-folder'));
verifyFalse(testCase, T.present);
r = did2.validate.v1Document(subject('tc_subj_1', 'mouse_1'), T);
verifyFalse(testCase, r.checked);
verifyFalse(testCase, r.ok, 'not checked is never valid');
end

function testV1ToV2ChecksEveryCarriedSourceAgainstItsTemplate(testCase)
% two carries: a subject with no local identifier (carry-033: a template
% shape, valid) and one holding a field outside the template (carry-100:
% invalid, as it is meant to be); one subject converts and is not checked
bodies = {subject('tc_subj_1', 'mouse_1'), subject('tc_subj_2', '')};
odd = subject('tc_subj_3', 'mouse_3');
odd.subject.strain = 'C57BL/6';
bodies{end+1} = odd;
out = did2.convert.v1_to_v2(bodies, 'Validate', true, 'TargetVersion', 'V_eta');
c = out.summary.carried_v1_template_check;
verifyTrue(testCase, c.checked, c.reason);
verifyEqual(testCase, c.carried_inspected, 2);
verifyEqual(testCase, c.valid, 1);
verifyEqual(testCase, c.invalid, 1);
verifyEqual(testCase, c.invalid_by_class.subject, 1);
verifyEqual(testCase, c.problem_ids_sample, {'tc_subj_3'});
verifyEmpty(testCase, out.quarantine, 'a carry the template refuses is counted, not quarantined');
% Validate off: not checked, and says so
out = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
verifyFalse(testCase, out.summary.carried_v1_template_check.checked);
verifyTrue(testCase, startsWith(out.summary.carried_v1_template_check.reason, 'NOT CHECKED'));
end

% ===================== fixtures =========================================

function root = templateRoot()
thisDir = fileparts(mfilename('fullpath'));
root = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates');
end

function v1 = subject(id, localId)
v1 = did2.unittest.helpers.ndiDocument('subject', 'Id', id, ...
    'SessionId', '41268b6f5c6a3d4e_00000000000000a1', 'Datestamp', '2024-06-01T12:00:00.000Z');
v1.subject.local_identifier = localId;
v1.subject.description = '';
v1 = jsondecode(jsonencode(v1));
end
