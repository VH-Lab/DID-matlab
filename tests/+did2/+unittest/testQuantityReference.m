function tests = testQuantityReference
%TESTQUANTITYREFERENCE A nested field that names its value class, and a wrongly shaped quantity.
%
%   Decided by Jess Haley, 2026-10-27 [quantity reference type] (did-schema
%   V_eta_go_forward_class_audit.md; did-schema #66 as rescoped 2026-10-21):
%   "a nested quantity field names its value class and the validator expands
%   that class's cell (all value classes, including count, score, gain, ph)
%   ... #66 is done when the hand-copied cells in chemical, formulation, dose
%   and frequency_filter are gone and a wrongly shaped quantity fails
%   validation." Build pending: DID-matlab (validator, did2.build), then
%   did-schema (remove the copied cells, derived list).
%
%   THE DECLARATION. A field names its value class in its `type` (it already
%   does: chemical.value.concentration is `type: "concentration"`), and the
%   reference form simply omits `fields` (#66 sec. 6: "looks up the cell
%   shape ... no inline fields block is required"; did_schema_meta.json
%   requires `fields` only for `type: "structure"`). BOTH FORMS are accepted:
%   a field that still carries its hand-copied `fields` is read as written,
%   so did-schema can drop the copies after this lands (CLAUDE.md sec. 3).
%
%   THE CANONICAL (Decided by Jess Haley, 2026-10-30 [canonical absent only
%   as needs info]): a cell of a one-canonical class stating a unit and a
%   finite source_value but no canonical fails unless the document's
%   needs_info names it (testA*Canonical*). NOT TESTED, BECAUSE NOT BUILT:
%   a cell with no unit, and a cell with several canonicals (concentration:
%   "exactly one", G38): DID-matlab's own writers (neuron_extracellular,
%   jMeasurementFold, resolveDeferredBaths, virus_injection's dilution)
%   write those with no canonical today (did2.schema.cache
%   validateQuantityCells' header).
%
%   Each test points the shared schema cache at a throwaway directory (the
%   pattern of testBuildSourceUnit): a `value` root, three value classes
%   (`length`, `concentration`, `count`), a `mixture` value class whose cell
%   holds references and one hand-copied cell, and an `oddities` class whose
%   field types name no value class.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   CI is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testQuantityReference');

tests = functiontests(localfunctions);
end

function setup(testCase)
testCase.TestData.dirs = {};
testCase.TestData.prevShape = did2.schema.cache.strictMode('QuantityShape');
useFixture(testCase);
end

function teardown(testCase)
did2.schema.cache.strictMode('QuantityShape', testCase.TestData.prevShape);
did2.schema.cache.resetSingleton();
for k = 1:numel(testCase.TestData.dirs)
    if isfolder(testCase.TestData.dirs{k})
        rmdir(testCase.TestData.dirs{k}, 's');
    end
end
end

% ---- the switch -----------------------------------------------------------------

function testQuantityShapeIsArmedByDefault(testCase)
s = did2.schema.cache.strictMode('-reset');
if isempty(getenv('DID_ENFORCE_QUANTITY_SHAPE'))
    verifyTrue(testCase, s.QuantityShape, ...
        'the decision says a wrongly shaped quantity FAILS validation');
end
end

% ---- expansion: the reference form reads as the copied form ---------------------

function testAReferenceTakesItsClassCell(testCase)
c = did2.schema.cache.shared();
value = subDef(c.getClass('mixture').fields, 'value');
strength = subDef(value.fields, 'strength');
verifyTrue(testCase, isfield(strength, 'fields'), ...
    'a field typed concentration with no fields of its own gets the cell');
verifyEqual(testCase, defNames(strength.fields), defNames(cellOf(c, 'concentration')));
n = subDef(value.fields, 'n');
verifyEqual(testCase, defNames(n.fields), {'count', 'approximate'}, ...
    'count is a value class too (the decision: "all value classes")');
end

function testAReferenceInsideAnArrayIsExpanded(testCase)
c = did2.schema.cache.shared();
value = subDef(c.getClass('mixture').fields, 'value');
items = subDef(value.fields, 'items');
amount = subDef(items.fields, 'amount');
verifyEqual(testCase, defNames(amount.fields), defNames(cellOf(c, 'length')));
end

function testAHandCopiedCellIsReadAsWritten(testCase)
c = did2.schema.cache.shared();
value = subDef(c.getClass('mixture').fields, 'value');
copied = subDef(value.fields, 'copied');
molar = subDef(copied.fields, 'molar');
verifyEqual(testCase, char(molar.documentation), 'copied by hand', ...
    'a field that declares its own fields is not replaced');
end

function testAClassOwnValueIsNotItsOwnReference(testCase)
c = did2.schema.cache.shared();
v = subDef(c.getClass('length').fields, 'value');
verifyEqual(testCase, defNames(v.fields), ...
    {'meters', 'source_unit', 'source_value', 'approximate', 'tolerance'});
end

function testATypeNamingNoValueClassIsLeftAlone(testCase)
c = did2.schema.cache.shared();
f = c.getClass('oddities').fields;
verifyFalse(testCase, isfield(subDef(f, 'reading'), 'fields'), ...
    'voltage has no class in this schema, so nothing is expanded');
verifyFalse(testCase, isfield(subDef(f, 'other'), 'fields'), ...
    'notvalue is a class but not a value class');
verifyFalse(testCase, c.namesValueClass('notvalue'));
verifyFalse(testCase, c.namesValueClass('double'));
verifyTrue(testCase, c.namesValueClass('count'));
end

function testQueryablePathsDescendAReference(testCase)
c = did2.schema.cache.shared();
c.loadAllSchemas();
info = c.queryablePaths();
paths = {info.scalar.path};
verifyTrue(testCase, any(strcmp(paths, 'mixture.value.strength.molar')));
verifyFalse(testCase, any(strcmp(paths, 'mixture.value.strength')), ...
    'a reference is a cell, not one opaque leaf');
end

% ---- validation: well shaped passes, in both forms ------------------------------

function testWellShapedQuantitiesValidate(testCase)
doc = mixtureDoc();
doc.mixture.value.strength = struct('molar', 0.001, 'source_value', 1, ...
    'source_unit', struct('node', 'om:millimolar', 'name', 'millimolar'), ...
    'approximate', false);
doc.mixture.value.copied = struct('molar', 0.002, 'source_value', 2);
doc.mixture.value.items = struct('amount', {struct('meters', 0.1), ...
    struct('meters', 0.2, 'tolerance', struct('minus', 0, 'plus', 0.01))});
doc.mixture.value.n = struct('count', 3, 'approximate', false);
did2.schema.cache.shared().validateDocument(doc);
end

function testATopLevelCellValidates(testCase) %#ok<INUSD>
doc = lengthDoc();
doc.length.value = struct('meters', {0.1, 0.2}, 'source_value', {100, 200});
did2.schema.cache.shared().validateDocument(doc);
end

% ---- validation: a wrongly shaped quantity fails --------------------------------

function testAnUndeclaredFieldInAReferenceFails(testCase)
doc = mixtureDoc();
doc.mixture.value.strength = struct('millimolar', 1);
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
end

function testAnUndeclaredFieldInAHandCopiedCellFails(testCase)
doc = mixtureDoc();
doc.mixture.value.copied = struct('molar', 0.002, 'millimolar', 2);
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
end

function testAWrongTypeInACellFails(testCase)
doc = mixtureDoc();
doc.mixture.value.strength = struct('molar', 'one molar');
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
doc = mixtureDoc();
doc.mixture.value.n = struct('count', 2.5);
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape', 'a count is an integer');
end

function testACellThatIsNotAStructFails(testCase)
doc = mixtureDoc();
doc.mixture.value.strength = 0.001;
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
end

function testSeveralValuesInOneSlotFail(testCase)
doc = mixtureDoc();
doc.mixture.value.strength = struct('molar', [0.001 0.002]);
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
end

function testAWrongCellInAnArrayElementFails(testCase)
doc = mixtureDoc();
doc.mixture.value.items = {struct('amount', struct('meters', 0.1)), ...
    struct('amount', struct('inches', 4))};
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
end

function testAWrongCompositeInsideACellFails(testCase)
doc = mixtureDoc();
doc.mixture.value.items = struct('amount', struct('meters', 0.1, ...
    'tolerance', struct('sigma', 0.01)));
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape', 'tolerance declares minus and plus only');
doc = mixtureDoc();
doc.mixture.value.strength = struct('molar', 0.001, 'source_unit', 'mM');
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape', 'source_unit is a term here, not text');
end

function testAWronglyShapedTopLevelCellFails(testCase)
doc = lengthDoc();
doc.length.value = struct('meters', 0.1, 'feet', 0.33);
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
end

function testDisarmedTheShapeIsNotChecked(testCase)
did2.schema.cache.strictMode('QuantityShape', false);
doc = mixtureDoc();
doc.mixture.value.strength = struct('millimolar', 1);
did2.schema.cache.shared().validateDocument(doc);
verifyTrue(testCase, true, 'DID_ENFORCE_QUANTITY_SHAPE=0 is the escape hatch');
end

% ---- the canonical ([canonical absent only as needs info], 2026-10-30) ------------

function testAUnitAndANumberWithNoCanonicalFail(testCase)
doc = lengthDoc();
doc.length.value = struct('source_value', 100, ...
    'source_unit', struct('node', 'om:millimetre', 'name', 'millimetre'));
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape');
doc = mixtureDoc();
doc.mixture.value.items = struct('amount', struct('source_value', 4, ...
    'source_unit', struct('node', '', 'name', 'inch')));
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape', 'a reference inside an array is checked too');
end

function testACanonicalHoldingNaNIsPresent(testCase) %#ok<INUSD>
doc = lengthDoc();
doc.length.value = struct('meters', NaN, 'source_value', 100, ...
    'source_unit', struct('node', 'om:millimetre', 'name', 'millimetre'));
did2.schema.cache.shared().validateDocument(doc);
end

function testNeedsInfoExcusesAMissingCanonical(testCase)
doc = did2.schema.cache.shared().buildBlankDocument('measured');
% a document missing nothing has no needs_info at all (did2.build.document
% writes it only when there is an entry); the blank structure would be one
% empty entry, and [] is not the struct the field's type asks for
if isfield(doc.base, 'needs_info')
    doc.base = rmfield(doc.base, 'needs_info');
end
doc.measured.reading = struct('source_value', 100, ...
    'source_unit', struct('node', 'om:millimetre', 'name', 'millimetre'));
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:quantityShape', 'not named: refused');
doc.base.needs_info = struct('field', 'measured.reading.meters', ...
    'reason', 'the source states millimetres with no conversion');
did2.schema.cache.shared().validateDocument(doc);
% an entry naming the cell itself names a field the document gives (its
% source_value and source_unit), which [missing facts are needs info] refuses
% (did2.schema.needsInfoFields): the entry names the canonical
doc.base.needs_info = struct('field', 'measured.reading', 'reason', 'not stated');
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(doc), ...
    'did2:validation:badNeedsInfo', 'the cell is given: naming it is refused');
end

function testWhatTheCanonicalCheckLeavesAlone(testCase) %#ok<INUSD>
% no unit, a non-finite number, or a class of several canonicals: not
% checked here (the writers of today; validateQuantityCells' header)
doc = lengthDoc();
doc.length.value = struct('source_value', 100);
did2.schema.cache.shared().validateDocument(doc);
doc.length.value = struct('source_value', NaN, ...
    'source_unit', struct('node', 'om:millimetre', 'name', 'millimetre'));
did2.schema.cache.shared().validateDocument(doc);
doc = mixtureDoc();
doc.mixture.value.strength = struct('source_value', 1, ...
    'source_unit', struct('node', '', 'name', 'dilution'));
did2.schema.cache.shared().validateDocument(doc);
end

% ---- did2.build reads the reference -----------------------------------------------

function testBuildFillsAReference(testCase)
% qualified by the declaring class: a bare 'value.strength' reads its first
% segment as the chain class `value` (fieldDef), which declares no strength
v = did2.build.composite('mixture', 'mixture.value.strength', ...
    struct('molar', 0.001, 'source_value', 1));
verifyEqual(testCase, v.molar, 0.001);
verifyEqual(testCase, v.source_value, 1);
end

function testBuildRefusesAnUndeclaredFieldInAReference(testCase)
verifyError(testCase, @() did2.build.composite('mixture', 'value', ...
    struct('strength', struct('millimolar', 1))), 'did2:build:unknownField');
verifyError(testCase, @() did2.build.composite('mixture', 'value', ...
    struct('items', {{struct('amount', struct('inches', 4))}})), 'did2:build:unknownField');
end

% ---- fixture --------------------------------------------------------------------

function doc = mixtureDoc()
doc = did2.schema.cache.shared().buildBlankDocument('mixture');
end

function doc = lengthDoc()
doc = did2.schema.cache.shared().buildBlankDocument('length');
end

function d = subDef(raw, name)
if iscell(raw)
    defs = raw;
else
    defs = num2cell(raw);
end
d = [];
for k = 1:numel(defs)
    if strcmp(char(defs{k}.name), name)
        d = defs{k};
        return;
    end
end
error('testQuantityReference:noField', 'No field "%s".', name);
end

function names = defNames(raw)
if iscell(raw)
    names = cellfun(@(d) char(d.name), reshape(raw, 1, []), 'UniformOutput', false);
else
    names = arrayfun(@(d) char(d.name), reshape(raw, 1, []), 'UniformOutput', false);
end
end

function raw = cellOf(c, className)
v = subDef(c.getClass(className).fields, 'value');
raw = v.fields;
end

function useFixture(testCase)
% A throwaway schema: value <- {length, concentration, count, mixture}, plus
% notvalue and oddities, which are not value classes.
dirPath = tempname();
mkdir(dirPath);
testCase.TestData.dirs{end+1} = dirPath;
term = leaf('source_unit', 'ontology_term');
term.fields = {leaf('node', 'char'), leaf('name', 'char')};
tolerance = leaf('tolerance', 'structure');
tolerance.blank_value = struct();
tolerance.fields = {leaf('minus', 'double'), leaf('plus', 'double')};
provenance = {term, leaf('source_value', 'double'), leaf('approximate', 'boolean')};

% a scalar boolean's blank is false: a blank [] is not scalar, and the
% validator rejects it (did2:validation:notScalar) before any cell is read
dataBody = leaf('data_body', 'boolean');
dataBody.blank_value = false;
dataBody.default_value = false;
writeClass(dirPath, 'value', {}, {dataBody});
writeClass(dirPath, 'notvalue', {}, {leaf('note', 'char')});
writeClass(dirPath, 'length', {'value'}, {cellField('value', 'length', false, ...
    [{leaf('meters', 'double')}, provenance, {tolerance}])});
writeClass(dirPath, 'concentration', {'value'}, {cellField('value', 'concentration', false, ...
    [{leaf('molar', 'double'), leaf('grams_per_liter', 'double')}, provenance])});
writeClass(dirPath, 'count', {'value'}, {cellField('value', 'count', false, ...
    {leaf('count', 'integer'), leaf('approximate', 'boolean')})});

% the reference form: a field naming its value class, with no `fields`
strength = leaf('strength', 'concentration');
n = leaf('n', 'count');
amount = leaf('amount', 'length');
items = leaf('items', 'structure');
items.mustBeScalar = false;
items.fields = {amount};
% today's form: the same cell copied by hand
copiedMolar = leaf('molar', 'double');
copiedMolar.documentation = 'copied by hand';
copied = cellField('copied', 'concentration', true, ...
    [{copiedMolar, leaf('grams_per_liter', 'double')}, provenance]);
mixtureValue = leaf('value', 'structure');
mixtureValue.blank_value = struct();
mixtureValue.fields = {strength, copied, items, n};
writeClass(dirPath, 'mixture', {'value'}, {mixtureValue});

writeClass(dirPath, 'oddities', {}, {leaf('reading', 'voltage'), leaf('other', 'notvalue')});

% a document with base.needs_info ([missing facts are needs info]) and a
% reference to a one-canonical class, for the canonical check
needsInfo = leaf('needs_info', 'structure');
needsInfo.mustBeScalar = false;
needsInfo.fields = {leaf('field', 'char'), leaf('reason', 'char')};
writeClass(dirPath, 'base', {}, {needsInfo});
writeClass(dirPath, 'measured', {'base'}, {leaf('reading', 'length')});
did2.schema.cache.setSchemaPath(dirPath);
end

function f = leaf(name, type)
f = struct('name', name, 'type', type, 'blank_value', [], 'default_value', [], ...
    'mustBeNonEmpty', false, 'mustBeScalar', true, 'mustNotHaveNaN', false, ...
    'queryable', true, 'ontology', [], 'documentation', 'fixture', ...
    'constraints', struct());
end

function f = cellField(name, type, scalar, subs)
f = leaf(name, type);
f.mustBeScalar = scalar;
f.fields = subs;
end

function writeClass(dirPath, name, parents, fields)
sc = cellfun(@(p) struct('class_name', p, 'class_version', '1.0.0'), parents, ...
    'UniformOutput', false);
cls = struct();
cls.document_class = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', {sc}, 'maturity_level', 'stable');
cls.depends_on = {};
cls.file = {};
cls.fields = fields;
fid = fopen(fullfile(dirPath, [name '.json']), 'w');
fwrite(fid, jsonencode(cls));
fclose(fid);
end
