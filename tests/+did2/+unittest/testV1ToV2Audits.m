function tests = testV1ToV2Audits
% testV1ToV2Audits - did2.convert.v1_to_v2's `Audits` option.
%
%   The report-only census instruments (silentLoss, fileList,
%   timeReferenceFamilies) run by default, so migration runs and their
%   census are unchanged. 'Audits', false skips them for read paths that
%   discard them (NDI's applyReadNormalization), where they cost more than
%   the conversion. Skipping must not change the documents, and must not
%   look like an empty -- clean -- census.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
did2.schema.cache.setSchemaPath(fullfile(fileparts(thisDir), 'fixtures', 'V_delta'));
testCase.TestData.body = makeBody();
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function testAuditsRunByDefault(testCase)
out = did2.convert.v1_to_v2({testCase.TestData.body}, 'Validate', false);
for f = {'silent_loss', 'file_list_audit', 'time_reference_families'}
    verifyTrue(testCase, isfield(out, f{1}), f{1});
    verifyFalse(testCase, isfield(out.(f{1}), 'audit_skipped'), ...
        sprintf('%s ran by default', f{1}));
end
end

function testAuditsOffSkipsThemVisibly(testCase)
out = did2.convert.v1_to_v2({testCase.TestData.body}, 'Validate', false, 'Audits', false);
for f = {'silent_loss', 'file_list_audit', 'time_reference_families'}
    verifyEqual(testCase, out.(f{1}), struct('audit_skipped', true), ...
        sprintf('%s says it was skipped, not that it found nothing', f{1}));
end
end

function testAuditsOffChangesNoDocument(testCase)
a = did2.convert.v1_to_v2({testCase.TestData.body}, 'Validate', false);
b = did2.convert.v1_to_v2({testCase.TestData.body}, 'Validate', false, 'Audits', false);
verifyEqual(testCase, numel(b.migrated), numel(a.migrated));
verifyNotEmpty(testCase, b.migrated);
for k = 1:numel(a.migrated)
    verifyEqual(testCase, b.migrated{k}.toStruct(), a.migrated{k}.toStruct());
end
verifyEqual(testCase, numel(b.quarantine), numel(a.quarantine));
end

function body = makeBody()
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', 'session-audits');
doc = doc.set('base.name', 'audits');
doc = doc.set('demoA.value', 'a1');
body = doc.toStruct();
end
