function tests = testBuildRetiredClasses
%TESTBUILDRETIREDCLASSES did2.build refuses a new document of a retired class.
%
%   Decided by Jess Haley, 2026-10-24 [V2 builder refuses retired] (did-schema
%   V_eta_go_forward_class_audit.md): "did2.build refuses to create a new
%   document of a class whose disposition is retire, naming its replacement
%   where one is recorded; reading v1 and the generic migration are not
%   affected."
%
%   The list of retired classes is did-schema's class_disposition_meta.json.
%   These tests write a fixture of it into a copy of the schema in
%   DID_SCHEMA_PATH, so they do not depend on whether did-schema ships it yet.
%
%   Example:
%       results = runtests('did2.unittest.testBuildRetiredClasses');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build retired-class tests');
% the fixture builds an entity typed by a bare name; the term registry is
% tested elsewhere (testBuildTermRegistry)
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
testCase.TestData.schemaPath = did2.schema.cache.shared().schemaPath;
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the index ============================================

function testTheIndexReadsTheRetiredList(testCase)
meta = jsondecode(['{"retired": [' ...
    '{"class_name": "old_a", "replaced_by": ["new_a"], "decision": "doc.md [tag a]"}, ' ...
    '{"class_name": "old_b", "replaced_by": [], "decision": ""}, ' ...
    '{"class_name": "old_c", "replaced_by": ["new_c1", "new_c2"], "decision": "doc.md [tag c]"}]}']);
ix = did2.schema.retiredIndex(meta);
verifyTrue(testCase, ix.present);
verifyEqual(testCase, ix.count, 3);
a = ix.byName('old_a');
verifyEqual(testCase, a.replaced_by, {'new_a'});
verifyEqual(testCase, a.decision, 'doc.md [tag a]');
b = ix.byName('old_b');
verifyEqual(testCase, b.replaced_by, {});
verifyEqual(testCase, b.decision, '');
c = ix.byName('old_c');
verifyEqual(testCase, c.replaced_by, {'new_c1', 'new_c2'});
verifyFalse(testCase, isKey(ix.byName, 'new_a'));
end

function testTheIndexToleratesAnEmptyList(testCase)
ix = did2.schema.retiredIndex(jsondecode('{"retired": []}'));
verifyTrue(testCase, ix.present);
verifyEqual(testCase, ix.count, 0);
verifyEqual(testCase, ix.byName.Count, uint64(0));
end

function testNoFileRetiresNothing(testCase)
ix = did2.schema.retiredIndex(struct('title', 'not a disposition file'));
verifyFalse(testCase, ix.present);
verifyEqual(testCase, ix.count, 0);
end

% ===================== the builder ==========================================

function testARetiredClassIsRefusedNamingItsReplacement(testCase)
[cls, fields] = entitySpec();
useFixture(testCase, sprintf(['{"retired": [{"class_name": "%s", ' ...
    '"replaced_by": ["a_replacement"], "decision": "fixture.md [fixture tag]"}]}'], cls));
prev = did2.schema.cache.strictMode('RetiredClasses', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('RetiredClasses', prev));
try
    did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
    verifyFail(testCase, 'a retired class was built');
catch err
    verifyEqual(testCase, err.identifier, 'did2:build:retiredClass');
    verifySubstring(testCase, err.message, ['"' cls '"']);
    verifySubstring(testCase, err.message, 'a_replacement');
    verifySubstring(testCase, err.message, 'fixture.md [fixture tag]');
end
end

function testARetiredClassWithNoReplacementSaysSo(testCase)
[cls, fields] = entitySpec();
useFixture(testCase, sprintf(['{"retired": [{"class_name": "%s", ' ...
    '"replaced_by": [], "decision": ""}]}'], cls));
prev = did2.schema.cache.strictMode('RetiredClasses', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('RetiredClasses', prev));
try
    did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
    verifyFail(testCase, 'a retired class was built');
catch err
    verifyEqual(testCase, err.identifier, 'did2:build:retiredClass');
    verifySubstring(testCase, err.message, 'no replacement is recorded');
end
end

function testModeOffAllowsARetiredClass(testCase)
[cls, fields] = entitySpec();
useFixture(testCase, sprintf(['{"retired": [{"class_name": "%s", ' ...
    '"replaced_by": ["a_replacement"], "decision": "fixture.md [fixture tag]"}]}'], cls));
prev = did2.schema.cache.strictMode('RetiredClasses', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('RetiredClasses', prev));
doc = did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
end

function testAClassNotListedIsBuilt(testCase)
[cls, fields] = entitySpec();
useFixture(testCase, ['{"retired": [{"class_name": "a_class_nobody_builds", ' ...
    '"replaced_by": [], "decision": ""}]}']);
prev = did2.schema.cache.strictMode('RetiredClasses', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('RetiredClasses', prev));
doc = did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
end

function testAnEmptyListRefusesNothing(testCase)
[cls, fields] = entitySpec();
useFixture(testCase, '{"retired": []}');
prev = did2.schema.cache.strictMode('RetiredClasses', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('RetiredClasses', prev));
doc = did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
end

function testAnAbsentFileRefusesNothing(testCase)
[cls, fields] = entitySpec();
useFixture(testCase, '');   % '' = remove the file from the copied schema
prev = did2.schema.cache.strictMode('RetiredClasses', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('RetiredClasses', prev));
verifyEqual(testCase, fieldnames(did2.schema.cache.shared().classDisposition), cell(0, 1));
doc = did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
end

% ===================== helpers ==============================================

function useFixture(testCase, metaText)
% Copy the schema set to a temporary folder, write METATEXT as its
% class_disposition_meta.json ('' removes the file), and load it.
arguments
    testCase
    metaText (1,:) char
end
src = testCase.TestData.schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
copyfile(fullfile(src, '*.json'), tmp);
metaFile = fullfile(tmp, 'class_disposition_meta.json');
if isfile(metaFile)
    delete(metaFile);
end
if ~isempty(metaText)
    fid = fopen(metaFile, 'w');
    fwrite(fid, metaText);
    fclose(fid);
end
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
end

function [cls, fields] = entitySpec()
% an entity as the schema in use builds one (see testBuild/subjectSpec)
if did2.schema.cache.shared().hasClass('subject')
    cls = 'subject';
    fields = struct('local_identifier', 'm1');
else
    cls = 'entity';
    fields = struct('type', did2.build.term('', 'organism'), 'local_identifier', 'm1');
end
end
