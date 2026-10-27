function tests = testV1ToV2Audits
% testV1ToV2Audits - did2.convert.v1_to_v2's `Audits` option.
%
%   The report-only census instruments (silentLoss, fileList,
%   timeReferenceFamilies) run by default, so migration runs and their
%   census are unchanged. 'Audits', false skips them for callers that
%   discard them, where they cost more than the conversion. Skipping must
%   not change the documents, and must not look like an empty -- clean --
%   census.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
did2.schema.cache.setSchemaPath(fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal'));
testCase.TestData.body = makeBody();
end

function teardownOnce(testCase)
arguments
    testCase (1,1) matlab.unittest.TestCase %#ok<INUSA> the fixture signature; only the singleton is reset
end

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

function testAV1BodyIsNotAtTheTarget(testCase)
b = makeBody();
b.document_class = rmfield(b.document_class, 'schema_version');
verifyFalse(testCase, did2.convert.isAlreadyTarget(b, 'V_eta'));
end

function testABlankDocumentIsAtTheTarget(testCase)
% did2.document.blank stamps the V2 stamp ('did_v2', did2.schema.v2Stamp), so
% a freshly built document is already at the target.
verifyTrue(testCase, did2.convert.isAlreadyTarget(makeBody(), 'V_eta'));
end

function body = makeBodyOf(className)
arguments
    className {mustBeText}
end

doc = did2.document.blank(className);
doc = doc.set('base.session_id', 'session-audits');
doc = doc.set('base.name', 'audits');
body = doc.toStruct();
end

function body = makeBody()
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', 'session-audits');
doc = doc.set('base.name', 'audits');
doc = doc.set('demoA.value', 'a1');
body = doc.toStruct();
end
