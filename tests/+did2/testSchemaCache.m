function tests = testSchemaCache
% testSchemaCache - exercises did2.schema.cache against the in-repo
%   V_gamma fixtures at tests/+did2/fixtures/V_gamma/. Also covers
%   did2.document.blank() and did2.document.validate() end-to-end.
%
%   Documents in V_gamma use class-scoped property blocks (see
%   V_gamma_SPEC.md "JSON Format: Document Instances"): top-level
%   `_classname`, `_class_version`, `_superclasses`, `_depends_on`, plus
%   one property block per class in the chain. MATLAB stores the four
%   underscore-prefixed system keys as `x_<name>` (mirroring jsondecode);
%   class-block keys (`base`, `demoA`, ...) are plain MATLAB identifiers.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
fixtureDir = fullfile(fileparts(mfilename('fullpath')), 'fixtures', 'V_gamma');
did2.schema.cache.setSchemaPath(fixtureDir);
testCase.TestData.fixtureDir = fixtureDir;
testCase.TestData.cache = did2.schema.cache.shared();
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

% ---- schema-cache plumbing ----

function testSchemaPathPointsAtFixtures(testCase)
verifyTrue(testCase, isfolder(testCase.TestData.fixtureDir));
verifyEqual(testCase, testCase.TestData.cache.schemaPath, testCase.TestData.fixtureDir);
end

function testGetClassLoadsBase(testCase)
s = testCase.TestData.cache.getClass('base');
verifyTrue(testCase, isstruct(s));
end

function testGetClassMissingThrows(testCase)
verifyError(testCase, ...
    @() testCase.TestData.cache.getClass('not_a_real_class'), ...
    'did2:schema:missingClass');
end

function testCurieRegistryLoaded(testCase)
verifyTrue(testCase, isstruct(testCase.TestData.cache.curieRegistry));
verifyFalse(testCase, isempty(fieldnames(testCase.TestData.cache.curieRegistry)));
end

% ---- superclass chains ----

function testSuperclassesBaseIsRoot(testCase)
verifyEmpty(testCase, testCase.TestData.cache.superclasses('base'));
end

function testSuperclassesDemoAExtendsBase(testCase)
verifyEqual(testCase, testCase.TestData.cache.superclasses('demoA'), {'base'});
end

function testSuperclassesDemoBChain(testCase)
verifyEqual(testCase, testCase.TestData.cache.superclasses('demoB'), {'demoA', 'base'});
end

function testClassChainRootFirst(testCase)
verifyEqual(testCase, testCase.TestData.cache.classChain('demoB'), ...
    {'base', 'demoA', 'demoB'});
end

% ---- field-list resolution ----

function testOwnFieldsBaseHasFour(testCase)
own = testCase.TestData.cache.ownFields('base');
verifyEqual(testCase, numel(own), 4);
end

function testOwnFieldsDemoAHasOne(testCase)
own = testCase.TestData.cache.ownFields('demoA');
verifyEqual(testCase, numel(own), 1);
end

function testFieldsForTagsDeclaringClass(testCase)
tagged = testCase.TestData.cache.fieldsFor('demoB');
% base(4) + demoA(1) + demoB(1) = 6 entries
verifyEqual(testCase, numel(tagged), 6);
verifyEqual(testCase, tagged(1).declaringClass, 'base');
verifyEqual(testCase, tagged(4).declaringClass, 'base');
verifyEqual(testCase, tagged(5).declaringClass, 'demoA');
verifyEqual(testCase, tagged(6).declaringClass, 'demoB');
end

% ---- buildBlankDocument: top-level metadata ----

function testBuildBlankDocumentTopLevelMetadata(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoB');
verifyEqual(testCase, doc.x_classname, 'demoB');
verifyEqual(testCase, doc.x_class_version, '1.0.0');
verifyEqual(testCase, numel(doc.x_superclasses), 2);
verifyEqual(testCase, doc.x_superclasses(1).x_classname, 'demoA');
verifyEqual(testCase, doc.x_superclasses(2).x_classname, 'base');
end

function testBuildBlankDocumentEmptyDependsOn(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyTrue(testCase, isfield(doc, 'x_depends_on'));
verifyEmpty(testCase, doc.x_depends_on);
end

% ---- buildBlankDocument: class-scoped blocks ----

function testBuildBlankDocumentHasBaseBlock(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyTrue(testCase, isfield(doc, 'base'));
verifyTrue(testCase, isfield(doc.base, 'id'));
verifyTrue(testCase, isfield(doc.base, 'session_id'));
verifyTrue(testCase, isfield(doc.base, 'name'));
verifyTrue(testCase, isfield(doc.base, 'datestamp'));
end

function testBuildBlankDocumentHasConcreteBlock(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyTrue(testCase, isfield(doc, 'demoA'));
verifyTrue(testCase, isfield(doc.demoA, 'value'));
verifyEqual(testCase, doc.demoA.value, '');
end

function testBuildBlankDocumentAllChainBlocksPresent(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoB');
verifyTrue(testCase, isfield(doc, 'base'));
verifyTrue(testCase, isfield(doc, 'demoA'));
verifyTrue(testCase, isfield(doc, 'demoB'));
verifyTrue(testCase, isfield(doc.demoA, 'value'));
verifyTrue(testCase, isfield(doc.demoB, 'value_b'));
end

function testBuildBlankDocumentMintsIdInBaseBlock(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyEqual(testCase, numel(doc.base.id), 33);  % did_id format length
end

function testBuildBlankDocumentSetsDatestampInBaseBlock(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyEqual(testCase, doc.base.datestamp(1:2), '20');
verifyEqual(testCase, doc.base.datestamp(end), 'Z');
end

% ---- validateDocument ----

function testValidateBlankDocFailsOnEmptySessionId(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyError(testCase, ...
    @() testCase.TestData.cache.validateDocument(doc), ...
    'did2:validation:emptyField');
end

function testValidatePassesAfterFillingSessionId(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
testCase.TestData.cache.validateDocument(doc);
end

function testValidateCatchesMaxLength(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = repmat('a', 1, 300);
verifyError(testCase, ...
    @() testCase.TestData.cache.validateDocument(doc), ...
    'did2:validation:maxLength');
end

function testValidateAcceptsValueAtMaxLength(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = repmat('a', 1, 256);
testCase.TestData.cache.validateDocument(doc);
end

function testValidateCatchesTypeMismatch(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = 12345;
verifyError(testCase, ...
    @() testCase.TestData.cache.validateDocument(doc), ...
    'did2:validation:typeMismatch');
end

function testValidateMissingClassNameThrows(testCase)
doc = struct('base', struct('id', 'abc'));
verifyError(testCase, ...
    @() testCase.TestData.cache.validateDocument(doc), ...
    'did2:validation:missingClassName');
end

function testValidateMissingClassBlockThrows(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
doc = rmfield(doc, 'base');
verifyError(testCase, ...
    @() testCase.TestData.cache.validateDocument(doc), ...
    'did2:validation:missingClassBlock');
end

% ---- end-to-end through did2.document ----

function testDocumentBlankConvenience(testCase)
doc = did2.document.blank('demoA');
verifyEqual(testCase, doc.className(), 'demoA');
verifyEqual(testCase, doc.classVersion(), '1.0.0');
verifyEqual(testCase, numel(doc.get('base.id')), 33);
end

function testDocumentValidateRoundTrip(testCase)
doc = did2.document.blank('demoA');
doc.set('base.session_id', did.ido.unique_id());
doc.set('demoA.value', 'hello');
doc.validate();
end

function testDocumentToJSONRewritesUnderscoreKeys(testCase)
doc = did2.document.blank('demoA');
text = doc.toJSON();
verifyTrue(testCase, contains(text, '"_classname":"demoA"'));
verifyFalse(testCase, contains(text, '"x_classname"'));
doc2 = did2.document.fromJSON(text);
verifyEqual(testCase, doc2.className(), 'demoA');
verifyTrue(testCase, isfield(doc2.toStruct(), 'base'));
end
