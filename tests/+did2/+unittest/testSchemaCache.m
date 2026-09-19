function tests = testSchemaCache
% testSchemaCache - exercises did2.schema.cache against the in-repo
%   V_delta fixtures at tests/+did2/fixtures/V_delta/. Also covers
%   did2.document.blank() and did2.document.validate() end-to-end.
%
%   Run with:
%       results = runtests('did2.unittest.testSchemaCache');
%
%   Documents in V_delta use a top-level `document_class` header plus
%   class-scoped property blocks (see V_delta_SPEC.md "JSON Format:
%   Document Instances"). After V_delta's "drop underscore prefixes"
%   pass, every key in the wire shape is a valid MATLAB struct field
%   name, so `jsonencode`/`jsondecode` round-trip without any rewrite.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% Fixtures live at tests/+did2/fixtures/V_delta/. This file is at
% tests/+did2/+unittest/testSchemaCache.m, so the fixture directory is
% two `fileparts` levels above mfilename's directory.
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
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
verifyTrue(testCase, isfield(s, 'document_class'));
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

function testOwnFieldsDemoAHasFour(testCase)
% demoA declares: value (char) + axes/multiscales (structure) + tags
% (string). The latter three exist as open-shape declarations so
% testSqliteDb can set ad-hoc data on those keys without tripping the
% strict-fields validator.
own = testCase.TestData.cache.ownFields('demoA');
verifyEqual(testCase, numel(own), 4);
end

function testFieldsForTagsDeclaringClass(testCase)
tagged = testCase.TestData.cache.fieldsFor('demoB');
% base(4) + demoA(4) + demoB(1) = 9 entries
verifyEqual(testCase, numel(tagged), 9);
verifyEqual(testCase, tagged(1).declaringClass, 'base');
verifyEqual(testCase, tagged(4).declaringClass, 'base');
verifyEqual(testCase, tagged(5).declaringClass, 'demoA');
verifyEqual(testCase, tagged(8).declaringClass, 'demoA');
verifyEqual(testCase, tagged(9).declaringClass, 'demoB');
end

% ---- buildBlankDocument: document_class header ----

function testBuildBlankDocumentHeader(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoB');
verifyTrue(testCase, isfield(doc, 'document_class'));
verifyEqual(testCase, doc.document_class.class_name, 'demoB');
verifyEqual(testCase, doc.document_class.class_version, '1.0.0');
verifyEqual(testCase, numel(doc.document_class.superclasses), 2);
verifyEqual(testCase, doc.document_class.superclasses(1).class_name, 'demoA');
verifyEqual(testCase, doc.document_class.superclasses(2).class_name, 'base');
end

function testBuildBlankDocumentStampsSchemaVersion(testCase)
% Every blank V_delta document carries the schema-set tag on
% document_class (sibling of class_name/class_version/superclasses).
% Lets the v1->V_delta dispatcher's short-circuit recognise a freshly
% built blank as already-V_delta on a subsequent migration pass.
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyTrue(testCase, isfield(doc.document_class, 'schema_version'));
verifyEqual(testCase, doc.document_class.schema_version, 'V_delta');
verifyFalse(testCase, isfield(doc.base, 'schema_version'));
end

function testBuildBlankDocumentEmptyDependsOn(testCase)
doc = testCase.TestData.cache.buildBlankDocument('demoA');
verifyTrue(testCase, isfield(doc, 'depends_on'));
verifyEmpty(testCase, doc.depends_on);
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

function testValidateTruncatedSuperclassesChainThrows(testCase)
% V_gamma_SPEC "Validation checklist": the document_class.superclasses
% snapshot must match the schema-derived chain. demoB's chain is
% {demoA, base}; truncating to {demoA} must fail loudly so consumers
% (e.g., cloud classLineage) get a complete is-a transitive closure.
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoB');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = 'x';
doc.demoB.value_b = 'y';
% Sanity: blank doc validates first.
cache.validateDocument(doc);
truncated = doc;
truncated.document_class.superclasses = ...
    doc.document_class.superclasses(1);
verifyError(testCase, ...
    @() cache.validateDocument(truncated), ...
    'did2:validation:superclassesChainMismatch');
end

function testValidateReorderedSuperclassesChainThrows(testCase)
% Spec requires same order, not just same set.
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoB');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = 'x';
doc.demoB.value_b = 'y';
reordered = doc;
reordered.document_class.superclasses = ...
    doc.document_class.superclasses([2 1]);
verifyError(testCase, ...
    @() cache.validateDocument(reordered), ...
    'did2:validation:superclassesChainMismatch');
end

function testValidateMissingSuperclassesFieldThrows(testCase)
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = 'x';
doc.document_class = rmfield(doc.document_class, 'superclasses');
verifyError(testCase, ...
    @() cache.validateDocument(doc), ...
    'did2:validation:missingSuperclasses');
end

function testValidateBadSuperclassEntryThrows(testCase)
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = 'x';
doc.document_class.superclasses(1).class_name = '';
verifyError(testCase, ...
    @() cache.validateDocument(doc), ...
    'did2:validation:badSuperclassEntry');
end

function testValidateBaseAcceptsEmptySuperclasses(testCase)
% Spec: superclasses must be `[]` for base. buildBlankDocument cannot
% mint a `base` doc (`base` lacks the concrete declarations it needs),
% so build the smallest valid base doc by hand and confirm it passes.
cache = testCase.TestData.cache;
doc = struct();
doc.document_class = struct( ...
    'class_name',    'base', ...
    'class_version', '1.0.0', ...
    'superclasses',  []);
doc.depends_on = struct('name', {}, 'document_id', {});
doc.base = struct( ...
    'id',         did.ido.unique_id(), ...
    'session_id', did.ido.unique_id(), ...
    'name',       'rig_1', ...
    'datestamp',  '2026-01-01T00:00:00.000Z');
cache.validateDocument(doc);
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

function testDocumentToJSONRoundTrip(testCase)
% V_delta has no leading-underscore keys, so jsonencode/jsondecode is
% identity for any well-formed document. Confirm the wire shape uses
% the V_delta key names and re-parses to an equivalent document.
doc = did2.document.blank('demoA');
text = doc.toJSON();
verifyTrue(testCase, contains(text, '"document_class"'));
verifyTrue(testCase, contains(text, '"class_name":"demoA"'));
doc2 = did2.document.fromJSON(text);
verifyEqual(testCase, doc2.className(), 'demoA');
verifyTrue(testCase, isfield(doc2.toStruct(), 'base'));
verifyTrue(testCase, isfield(doc2.toStruct(), 'demoA'));
end

% ---- queryablePaths (step 4) ----

function testQueryablePathsListsBaseAndDemoScalars(testCase)
cache = testCase.TestData.cache;
cache.loadAllSchemas();
info = cache.queryablePaths();
paths = {info.scalar.path};
expected = {'base.datestamp', 'base.id', 'base.name', 'base.session_id', ...
    'demoA.value', 'demoB.value_b', 'demoC.value', 'demoFile.value'};
verifyEqual(testCase, sort(paths), expected);
end

function testQueryablePathsArrayListsDemoArraySubfields(testCase)
% The demoArray fixture declares an `axes` array-of-structure field
% with two queryable scalar sub-fields (`unit` and `size`).
cache = testCase.TestData.cache;
cache.loadAllSchemas();
info = cache.queryablePaths();
paths = sort({info.array.path});
verifyEqual(testCase, paths, ...
    {'demoArray.axes[*].size', 'demoArray.axes[*].unit'});
end

function testQueryablePathsArrayLeafMetadata(testCase)
cache = testCase.TestData.cache;
cache.loadAllSchemas();
info = cache.queryablePaths();
unitEntry = info.array(strcmp({info.array.path}, 'demoArray.axes[*].unit'));
verifyEqual(testCase, numel(unitEntry), 1);
verifyEqual(testCase, unitEntry.declaringClass, 'demoArray');
verifyEqual(testCase, unitEntry.parentField, 'axes');
verifyEqual(testCase, unitEntry.parentPath, 'demoArray.axes');
verifyEqual(testCase, unitEntry.subField, 'unit');
verifyEqual(testCase, unitEntry.type, 'char');
verifyEqual(testCase, unitEntry.affinity, 'TEXT');

sizeEntry = info.array(strcmp({info.array.path}, 'demoArray.axes[*].size'));
verifyEqual(testCase, sizeEntry.type, 'integer');
verifyEqual(testCase, sizeEntry.affinity, 'INTEGER');
end

function testQueryablePathsColumnNames(testCase)
cache = testCase.TestData.cache;
cache.loadAllSchemas();
info = cache.queryablePaths();
paths = {info.scalar.path};
columns = {info.scalar.column};
% Column convention: 'q_' + dot-path with '.' -> '_', always lowercase.
for k = 1:numel(paths)
    expected = ['q_' lower(strrep(paths{k}, '.', '_'))];
    verifyEqual(testCase, columns{k}, expected);
end
end

function testQueryablePathsAffinity(testCase)
cache = testCase.TestData.cache;
cache.loadAllSchemas();
info = cache.queryablePaths();
% All fixture queryable scalars are char/did_uid/timestamp => TEXT.
verifyTrue(testCase, all(strcmp({info.scalar.affinity}, 'TEXT')));
end

function testQueryablePathsArrayCountMatchesFixtures(testCase)
% The demo fixtures declare exactly two queryable array sub-fields,
% both on demoArray.axes (`unit` and `size`).
cache = testCase.TestData.cache;
cache.loadAllSchemas();
info = cache.queryablePaths();
verifyEqual(testCase, numel(info.array), 2);
end

function testLoadAllSchemasIsIdempotent(testCase)
cache = testCase.TestData.cache;
cache.loadAllSchemas();
n1 = numel(cache.queryablePaths().scalar);
cache.loadAllSchemas();
n2 = numel(cache.queryablePaths().scalar);
verifyEqual(testCase, n1, n2);
end

% ---- resolvePlacement (V_gamma_SPEC.md "Field placement") ----

function testResolvePlacementDefaultsToDeclaringClass(testCase)
% demoB extends base with one own field; no fixture uses placement,
% so every field is declaring_class-placed and every chain class
% contributes a body block.
cache = testCase.TestData.cache;
info = cache.resolvePlacement('demoB');
verifyEqual(testCase, info.chain, {'base', 'demoA', 'demoB'});
% All three classes contribute body blocks under default placement.
verifyEqual(testCase, sort(info.blocksContributed), sort({'base', 'demoA', 'demoB'}));
% Each field lands in its declaring class's block.
baseEntries  = info.fieldsByBlock('base');
demoAEntries = info.fieldsByBlock('demoA');
verifyTrue(testCase, all(strcmp({baseEntries.declaringClass}, 'base')));
verifyTrue(testCase, all(strcmp({demoAEntries.declaringClass}, 'demoA')));
verifyTrue(testCase, all(strcmp({baseEntries.placement}, 'declaring_class')));
end

function testResolvePlacementRoutesAbstractFieldOntoConcreteBlock(testCase)
% demoAbstractPlacement (abstract) declares shared_field with
% placement=concrete_class; demoPlaceConcrete extends it and adds
% own_field. Both fields should land in demoPlaceConcrete's block,
% and demoAbstractPlacement should not contribute a block.
cache = testCase.TestData.cache;
info = cache.resolvePlacement('demoPlaceConcrete');
verifyTrue(testCase, any(strcmp(info.blocksContributed, 'demoPlaceConcrete')));
verifyTrue(testCase, any(strcmp(info.blocksContributed, 'base')));
verifyFalse(testCase, any(strcmp(info.blocksContributed, 'demoAbstractPlacement')));
entries = info.fieldsByBlock('demoPlaceConcrete');
fieldNames = arrayfun(@(e) char(e.fieldDef.name), entries, 'UniformOutput', false);
declarings  = {entries.declaringClass};
placements  = {entries.placement};
verifyTrue(testCase, any(strcmp(fieldNames, 'shared_field')));
verifyTrue(testCase, any(strcmp(fieldNames, 'own_field')));
sharedIdx = find(strcmp(fieldNames, 'shared_field'), 1);
ownIdx    = find(strcmp(fieldNames, 'own_field'),    1);
verifyEqual(testCase, declarings{sharedIdx}, 'demoAbstractPlacement');
verifyEqual(testCase, placements{sharedIdx}, 'concrete_class');
verifyEqual(testCase, declarings{ownIdx},    'demoPlaceConcrete');
verifyEqual(testCase, placements{ownIdx},    'declaring_class');
end

function testResolvePlacementMixedAbstractStillContributesBlock(testCase)
% demoMixedPlacement (abstract) has one declaring_class field
% (stays_on_parent) and one concrete_class field (moves_to_child).
% It must still contribute a body block holding stays_on_parent.
% moves_to_child lands on the concrete demoMixedConcrete block.
cache = testCase.TestData.cache;
info = cache.resolvePlacement('demoMixedConcrete');
verifyTrue(testCase, any(strcmp(info.blocksContributed, 'demoMixedPlacement')));
verifyTrue(testCase, any(strcmp(info.blocksContributed, 'demoMixedConcrete')));
parentEntries = info.fieldsByBlock('demoMixedPlacement');
childEntries  = info.fieldsByBlock('demoMixedConcrete');
parentFieldNames = arrayfun(@(e) char(e.fieldDef.name), parentEntries, 'UniformOutput', false);
childFieldNames  = arrayfun(@(e) char(e.fieldDef.name), childEntries,  'UniformOutput', false);
verifyTrue(testCase,  any(strcmp(parentFieldNames, 'stays_on_parent')));
verifyFalse(testCase, any(strcmp(parentFieldNames, 'moves_to_child')));
verifyTrue(testCase,  any(strcmp(childFieldNames,  'moves_to_child')));
verifyTrue(testCase,  any(strcmp(childFieldNames,  'own_field')));
end

function testResolvePlacementRaisesOnSubclassRedeclaration(testCase)
% demoCollideConcrete declares a field whose name matches
% demoCollideAbstract's placement=concrete_class field. Both would
% land in demoCollideConcrete's block under the same name; this is
% a hard schema error (V_gamma_SPEC.md "Field placement").
cache = testCase.TestData.cache;
verifyError(testCase, ...
    @() cache.resolvePlacement('demoCollideConcrete'), ...
    'did2:schema:placementCollision');
end

function testResolvePlacementRaisesOnConcreteClassPlacement(testCase)
% demoBadConcrete is a concrete class declaring placement=concrete_class
% on one of its own fields; that's a schema error.
cache = testCase.TestData.cache;
verifyError(testCase, ...
    @() cache.resolvePlacement('demoBadConcrete'), ...
    'did2:schema:placementOnConcreteClass');
end

function testBuildBlankDocumentOmitsAbstractBlockWhenAllPlaced(testCase)
% demoPlaceConcrete inherits demoAbstractPlacement; abstract class
% has only placement=concrete_class fields, so its block does not
% appear on instance bodies.
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoPlaceConcrete');
verifyTrue(testCase,  isfield(doc, 'base'));
verifyTrue(testCase,  isfield(doc, 'demoPlaceConcrete'));
verifyFalse(testCase, isfield(doc, 'demoAbstractPlacement'));
% Both routed fields are present on the concrete block.
verifyTrue(testCase, isfield(doc.demoPlaceConcrete, 'shared_field'));
verifyTrue(testCase, isfield(doc.demoPlaceConcrete, 'own_field'));
end

function testValidateAcceptsConcretePlacedFieldOnLeafBlock(testCase)
% Build the blank doc, fill in the required base.session_id, validate.
% No errors expected even though shared_field comes from an abstract
% ancestor with placement=concrete_class.
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoPlaceConcrete');
doc.base.session_id = did.ido.unique_id();
cache.validateDocument(doc);
end

function testValidateRejectsPhantomAbstractBlock(testCase)
% Attach a `demoAbstractPlacement` block to a doc whose chain
% includes that abstract class — under the placement rule it should
% NOT have a body block — and verify the validator flags it as an
% undeclared top-level block.
cache = testCase.TestData.cache;
doc = cache.buildBlankDocument('demoPlaceConcrete');
doc.base.session_id = did.ido.unique_id();
doc.demoAbstractPlacement = struct();
verifyError(testCase, ...
    @() cache.validateDocument(doc), ...
    'did2:validation:undeclaredBlock');
end
