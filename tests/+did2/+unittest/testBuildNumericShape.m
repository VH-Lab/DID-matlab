function tests = testBuildNumericShape
%TESTBUILDNUMERICSHAPE [one shape for measured numbers]: both shapes build, the new one reads.
%
%   Decided by Jess Haley, 2026-11-17, did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers].
%   Its section 9, step 1: DID-matlab's validator and did2.build read BOTH the
%   old numeric shape and the new one, with no change for today's documents;
%   the builders can write the new shape (did2.build.numericShape; the default
%   since step 2, which switched it). Since step 4 ([no migrated database is
%   kept], Jess Haley, 2026-11-19) the readers (did2.read.numeric for a list
%   item, did2.read.canonical for a value) read the new shape only: a number
%   in the old shape is the error 'did2:read:oldNumericShapeReMigrate'.
%
%   For each kind -- covariates (a number, a matrix, origin + spacing),
%   conditions, method parameters, compression parameters, value cells (one
%   reading and a series), logical's value, model_fit coefficients -- a
%   document is built in the OLD shape and in the NEW one; both pass the
%   builder's rules and the validator (did2.build.statement validates, and
%   did2.schema.cache.validateDocument is called again on each); and the
%   reader reads the new one and refuses the old one (an item whose form is
%   the same in both shapes, a term or a count, reads the same). The schema JSON (did-schema) still
%   describes only the old shape: the new fields are declared by
%   did2.schema.numericShapeFields, and it is those code paths that validate
%   the new-shape documents here.
%
%   Also pinned: the default is the new shape since step 2 (DID-matlab
%   numeric-shape writers PR); 'old' is byte for byte the documents the
%   builders wrote before; a mix of the two shapes in one item or one value is
%   refused; and the new shape's numbers keep their orientation through
%   did2's JSON writer and reader.
%
%   UNVERIFIED: written without MATLAB; test-builder.yml runs it.
%
%   Run with:  results = runtests('did2.unittest.testBuildNumericShape');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping numeric shape tests');
% made-up terms ('depth', 'volt', ...) test the builder's mechanics, as in
% testBuild; the term registry check has its own tests
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
cache = did2.schema.cache.shared();
if ~cache.hasClass('data') || ~cache.hasClass('voltage') || ~cache.hasClass('logical')
    assumeFail(testCase, sprintf('the loaded schema (%s) has no data, voltage or logical class.', ...
        cache.schemaPath));
end
testCase.TestData.sid = did.ido.unique_id();
prevShape = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prevShape));
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the switch ===========================================

function testTheDefaultIsTheNewShape(testCase)
% step 2 of the plan's section 9 switched the default from 'old' to 'new'
prev = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prev));
if isempty(getenv('DID_NUMERIC_SHAPE'))
    verifyEqual(testCase, did2.build.numericShape(), 'new');
    c = did2.build.covariate('depth', 0, 'Value', [1 2 3], 'Unit', 'meter');
    verifyTrue(testCase, isfield(c, 'numeric') && ~isfield(c, 'quantity'), ...
        'a builder given no ''Shape'' writes the new shape');
end
did2.build.numericShape('new');
verifyEqual(testCase, did2.build.numericShape(), 'new');
c = did2.build.covariate('depth', 0, 'Value', [1 2 3], 'Unit', 'meter');
verifyTrue(testCase, isfield(c, 'numeric'), 'the setting reaches a builder given no ''Shape''');
did2.build.numericShape('old');
c = oldBuilt(testCase, @() did2.build.covariate('depth', 0, 'Value', [1 2 3], 'Unit', 'meter'), []);
if did2.unittest.helpers.oldListShapeDeclared()
    verifyTrue(testCase, isfield(c, 'quantity'));
end
verifyError(testCase, @() did2.build.numericShape('newest'), 'did2:build:badOption');
end

function testTheOldShapeIsWrittenAsBefore(testCase)
% no behaviour change for today's documents: the old shape carries none of
% the new fields. A list item's old shape is written only while the schema
% declares it; once did-schema removes it (numeric shape plan section 9 step
% 4, Waltham-Data-Science/did-schema #373) the builder refuses it.
covariateOld = @() did2.build.covariate('depth', 0, 'Value', [1 2 3], ...
    'SourceValue', [1000 2000 3000], 'Unit', 'meter', 'Shape', 'old');
regularOld = @() did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 0.001, ...
    'Unit', 'second', 'Shape', 'old');
conditionOld = @() did2.build.condition('OD600', 'Value', 0.4, 'SourceValue', '0.40', ...
    'Shape', 'old');
fitOld = @() did2.build.fitEntry('von Mises', 'Coefficients', {'amplitude', 12.1}, ...
    'Shape', 'old');
if did2.unittest.helpers.oldListShapeDeclared()
    c = covariateOld();
    verifyEqual(testCase, sort(fieldnames(c))', sort({'variable', 'along', 'unit', 'quantity'}));
    verifyEqual(testCase, c.quantity, struct('value', [1 2 3], 'source_value', [1000 2000 3000]));
    t = regularOld();
    verifyEqual(testCase, t.origin, struct('value', 0));
    verifyEqual(testCase, t.spacing, struct('value', 0.001));
    q = conditionOld();
    verifyEqual(testCase, q.quantity, struct('value', 0.4, 'source_value', '0.40'));
    f = fitOld();
    verifyEqual(testCase, f.coefficients.value, 12.1);
    verifyFalse(testCase, isfield(f.coefficients, 'numeric'));
else
    verifyError(testCase, covariateOld, 'did2:build:unknownField');
    verifyError(testCase, regularOld, 'did2:build:typeMismatch', ...
        'origin is a flat number once the old block is not declared');
    verifyError(testCase, conditionOld, 'did2:build:unknownField');
    verifyError(testCase, fitOld, 'did2:build:unknownField');
end
v = did2.build.valueCell('voltage', [0.012 0.013], 'SourceValue', [12 13], 'Shape', 'old');
verifyEqual(testCase, size(v), [1 2]);
verifyFalse(testCase, isfield(v, 'source_numeric'));
end

% ===================== covariates ===========================================

function testCovariateNumberInBothShapes(testCase)
uV = did2.build.term('om:microvolt', 'microvolt');
old = oldBuilt(testCase, @() did2.build.covariate('Unit Conversion Factor', 0, ...
    'Value', [1.95e-7 1.95e-7], 'SourceValue', [0.195 0.195], 'Unit', 'volt', ...
    'SourceUnit', uV, 'Shape', 'old'), ...
    struct('variable', label('Unit Conversion Factor'), 'along', 0, 'unit', label('volt'), ...
    'source_unit', uV, 'quantity', struct('value', [1.95e-7 1.95e-7], 'source_value', [0.195 0.195])));
new = did2.build.covariate('Unit Conversion Factor', 0, 'Value', [1.95e-7 1.95e-7], ...
    'SourceValue', [0.195 0.195], 'Unit', 'volt', 'SourceUnit', uV, 'Shape', 'new');
% the plan's section 5 example
verifyEqual(testCase, new.numeric, [1.95e-7 1.95e-7]);
verifyEqual(testCase, new.source_numeric, [0.195 0.195]);
verifyEqual(testCase, new.unit.name, 'volt');
verifyEqual(testCase, new.source_unit, uV);
verifyFalse(testCase, isfield(new, 'quantity'));
verifySameReading(testCase, old, new);
r = did2.read.numeric(new);
verifyEqual(testCase, r.form, 'numeric');
verifyEqual(testCase, r.numbers, [1.95e-7 1.95e-7]);
verifyEqual(testCase, r.source_numbers, [0.195 0.195]);
end

function testCovariateOriginSpacingInBothShapes(testCase)
s = did2.build.term('om:second', 'second');
old = oldBuilt(testCase, @() did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 3.33e-5, ...
    'SourceOrigin', 0, 'SourceSpacing', 3.33e-5, 'Unit', 'second', 'SourceUnit', s, ...
    'Shape', 'old'), ...
    struct('variable', label('time'), 'along', 0, 'unit', label('second'), 'source_unit', s, ...
    'origin', struct('value', 0, 'source_value', 0), ...
    'spacing', struct('value', 3.33e-5, 'source_value', 3.33e-5)), 'did2:build:typeMismatch');
new = did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 3.33e-5, ...
    'SourceOrigin', 0, 'SourceSpacing', 3.33e-5, 'Unit', 'second', 'SourceUnit', s, 'Shape', 'new');
verifyEqual(testCase, new.origin, 0);
verifyEqual(testCase, new.spacing, 3.33e-5);
verifyEqual(testCase, new.source_origin, 0);
verifyEqual(testCase, new.source_spacing, 3.33e-5);
r = did2.read.numeric(new);
verifyEqual(testCase, r.form, 'origin');
verifyEqual(testCase, [r.origin r.spacing r.source_origin r.source_spacing], [0 3.33e-5 0 3.33e-5]);
verifySameReading(testCase, old, new);
end

function testCovariateMatrixBecomesNumeric(testCase)
rgb = [1 0 0; 0 1 0; 0 0 1; 1 1 1];
old = oldBuilt(testCase, @() did2.build.covariate('rgb', 0, 'Matrix', rgb, ...
    'Unit', 'arbitrary unit', 'Shape', 'old'), ...
    struct('variable', label('rgb'), 'along', 0, 'unit', label('arbitrary unit'), 'matrix', rgb));
new = did2.build.covariate('rgb', 0, 'Matrix', rgb, 'Unit', 'arbitrary unit', 'Shape', 'new');
verifyEqual(testCase, new.numeric, rgb);
verifyFalse(testCase, isfield(new, 'matrix'));
verifySameReading(testCase, old, new);
end

function testTheOtherCovariateFormsAreTheSameInBothShapes(testCase)
for form = {{'Term', {'A1', 'A2'}}, {'Text', {'a', 'b'}}, {'Logical', [true false]}, {'Count', [1 2]}}
    f = form{1};
    old = did2.build.covariate('x', 0, f{1}, f{2}, 'Shape', 'old');
    new = did2.build.covariate('x', 0, f{1}, f{2}, 'Shape', 'new');
    verifyEqual(testCase, new, old, sprintf('a ''%s'' covariate', f{1}));
end
% a count has no unit in the new shape (plan section 4)
verifyError(testCase, @() did2.build.covariate('x', 0, 'Count', [1 2], 'Unit', 'cell', ...
    'Shape', 'new'), 'did2:build:ruleViolated');
% the old shape has no item tolerance
verifyError(testCase, @() did2.build.covariate('x', 0, 'Value', [1 2], 'Tolerance', [0.1 0.1], ...
    'Shape', 'old'), 'did2:build:ruleViolated');
t = did2.build.covariate('x', 0, 'Value', [1 2], 'Unit', 'meter', 'Tolerance', [0.1 0.2], 'Shape', 'new');
verifyEqual(testCase, t.tolerance, struct('minus', 0.1, 'plus', 0.2));
end

% ===================== conditions and parameters ============================

function testConditionAndParameterInBothShapes(testCase)
for shape = {'old', 'new'}
    build = { ...
        @() did2.build.condition('OD600', 'Value', 0.4, 'SourceValue', '0.40', 'Shape', shape{1}), ...
        @() did2.build.parameter('threshold', 'Value', 4.5, 'SourceValue', '4.5', 'Unit', 'volt', ...
            'Shape', shape{1}), ...
        @() did2.build.parameter('colour palette', 'Matrix', [1 2; 3 4], 'Unit', 'arbitrary unit', ...
            'Shape', shape{1})};
    if strcmp(shape{1}, 'old')
        byHand = { ...
            struct('variable', label('OD600'), 'quantity', struct('value', 0.4, 'source_value', '0.40')), ...
            struct('variable', label('threshold'), 'unit', label('volt'), ...
                'quantity', struct('value', 4.5, 'source_value', '4.5')), ...
            struct('variable', label('colour palette'), 'unit', label('arbitrary unit'), ...
                'matrix', [1 2; 3 4])};
        for k = 1:numel(build)
            x = oldBuilt(testCase, build{k}, byHand{k});
            verifyError(testCase, @() did2.read.numeric(x), OLD, 'old shape');
        end
        continue;
    end
    c = build{1}();
    p = build{2}();
    m = build{3}();
    rc = did2.read.numeric(c);
    rp = did2.read.numeric(p);
    rm = did2.read.numeric(m);
    verifyEqual(testCase, {rc.form, rc.numbers, rc.source_numbers}, {'numeric', 0.4, '0.40'}, shape{1});
    verifyEqual(testCase, {rp.numbers, rp.source_numbers, rp.unit.name}, {4.5, '4.5', 'volt'}, shape{1});
    verifyEqual(testCase, rm.numbers, [1 2; 3 4], shape{1});
end
c = did2.build.condition('OD600', 'Value', 0.4, 'Shape', 'new');
verifyEqual(testCase, c.numeric, 0.4);
verifyFalse(testCase, isfield(c, 'quantity'));
verifyError(testCase, @() did2.build.parameter('passes', 'Count', 3, 'Unit', 'cell', 'Shape', 'new'), ...
    'did2:build:ruleViolated');
end

function testAStatementValidatesInBothShapes(testCase)
% one voltage observation with every list kind, built in each shape: both
% pass the builder's rules and the validator, and read back the same
docs = struct();
docs.new = recording(testCase, 'new');
did2.schema.cache.shared().validateDocument(docs.new);
if did2.unittest.helpers.oldListShapeDeclared()
    docs.old = recording(testCase, 'old');
    did2.schema.cache.shared().validateDocument(docs.old);
else
    % did-schema without the old shape (section 9 step 4): the builder
    % refuses it, and the same document in the old shape is written by hand
    verifyError(testCase, @() recording(testCase, 'old'), 'did2:build:unknownField');
    docs.old = docs.new;
    docs.old.data.covariates = toOldItems(docs.new.data.covariates, true);
    docs.old.statement.conditions = toOldItems(docs.new.statement.conditions, false);
    docs.old.interaction.method.parameters = toOldItems(docs.new.interaction.method.parameters, false);
    docs.old.voltage.value = struct('volts', num2cell(docs.new.voltage.value.volts));
end
oldCovs = docs.old.data.covariates;
newCovs = docs.new.data.covariates;
verifyEqual(testCase, numel(newCovs), numel(oldCovs));
for k = 1:numel(oldCovs)
    verifySameReading(testCase, oldCovs(k), newCovs(k));
end
verifySameReading(testCase, docs.old.statement.conditions, docs.new.statement.conditions);
verifySameReading(testCase, docs.old.interaction.method.parameters, ...
    docs.new.interaction.method.parameters);
verifyError(testCase, @() did2.read.canonical(docs.old), OLD, 'the old series is refused');
verifyEqual(testCase, did2.read.canonical(docs.new).numbers, zeros(1, 6));
verifyTrue(testCase, isfield(newCovs, 'numeric') && ~isfield(newCovs, 'quantity'));
end

function testTheNewShapeSurvivesJson(testCase)
cache = did2.schema.cache.shared();
doc = recording(testCase, 'new');
back = did2.document.fromJSON(did2.document(doc).toJSON('SchemaCache', cache), ...
    'SchemaCache', cache);
covs = back.get('data.covariates');
if iscell(covs); covs = [covs{:}]; end
depth = covs(strcmp(arrayfun(@(c) c.variable.name, covs, 'UniformOutput', false), 'depth'));
verifyEqual(testCase, size(depth.numeric), [1 3], 'a row stays a row');
verifyEqual(testCase, depth.numeric, [10 20 30]);
verifyWarningFree(testCase, @() back.validate('SchemaCache', cache));
end

% ===================== value cells ==========================================

function testAValueCellInBothShapes(testCase)
mV = did2.build.term('om:millivolt', 'millivolt');
old = did2.build.valueCell('voltage', 0.012, 'SourceValue', 12, 'SourceUnit', mV, 'Shape', 'old');
new = did2.build.valueCell('voltage', 0.012, 'SourceValue', 12, 'SourceUnit', mV, 'Shape', 'new');
verifyEqual(testCase, new.volts, 0.012);
verifyEqual(testCase, new.source_numeric, 12);
verifyFalse(testCase, isfield(new, 'source_value'));
verifyError(testCase, @() did2.read.canonical(old), OLD, 'the old source_value is refused');
verifyEqual(testCase, did2.read.canonical(new).numbers, 0.012);
r = did2.read.canonical(new, 'Class', 'voltage');
verifyEqual(testCase, {r.field, r.numbers, r.source_numbers}, {'volts', 0.012, 12});
verifyEqual(testCase, r.source_unit, mV);
end

function testASeriesInBothShapes(testCase)
% plan section 8, answer 4: one value block whose canonical field is an array
mV = did2.build.term('om:millivolt', 'millivolt');
old = did2.build.valueCell('voltage', [0.012 0.013 0.014], 'SourceValue', [12 13 14], ...
    'SourceUnit', mV, 'Approximate', false, 'Shape', 'old');
new = did2.build.valueCell('voltage', [0.012 0.013 0.014], 'SourceValue', [12 13 14], ...
    'SourceUnit', mV, 'Approximate', false, 'Shape', 'new');
verifyEqual(testCase, size(old), [1 3]);
verifyEqual(testCase, size(new), [1 1]);
verifyEqual(testCase, new.volts, [0.012 0.013 0.014]);
verifyEqual(testCase, new.source_numeric, [12 13 14]);
verifyError(testCase, @() did2.read.canonical(old), OLD, 'one cell per reading is refused');
rn = did2.read.canonical(new);
verifyEqual(testCase, rn.numbers, [0.012 0.013 0.014]);
verifyEqual(testCase, rn.source_numbers, [12 13 14]);
verifyEqual(testCase, rn.n, 3);
verifyEqual(testCase, rn.source_unit, mV);
verifyEqual(testCase, rn.approximate, false);
% both as statements: both validate; the new one reads, the old one is refused
for v = {old, new}
    doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', v{1}, ...
        'Dimensions', did2.build.dimension('time', 3), ...
        'Covariates', did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 1, 'Unit', 'second'), ...
        'TimeReferenceIds', {did.ido.unique_id()}, 'SessionId', testCase.TestData.sid, ...
        'ValueKind', 'voltage');
    did2.schema.cache.shared().validateDocument(doc);
    if numel(v{1}) > 1
        verifyError(testCase, @() did2.read.canonical(doc), OLD, 'the old statement is refused');
    else
        verifyEqual(testCase, did2.read.canonical(doc).numbers, [0.012 0.013 0.014]);
    end
end
% one series has one source unit
verifyError(testCase, @() did2.build.valueCell('voltage', [1 2], 'SourceUnit', {mV, ...
    did2.build.term('om:volt', 'volt')}, 'Shape', 'new'), 'did2:build:sizeMismatch');
end

function testAConcentrationSeriesInBothShapes(testCase)
old = did2.build.valueCell('concentration', [0.1 0.2], 'Canonical', 'molar', 'Shape', 'old');
new = did2.build.valueCell('concentration', [0.1 0.2], 'Canonical', 'molar', 'Shape', 'new');
verifyEqual(testCase, new.molar, [0.1 0.2]);
r = did2.read.canonical(new, 'Class', 'concentration');
verifyEqual(testCase, {r.field, r.numbers}, {'molar', [0.1 0.2]});
verifyError(testCase, @() did2.read.canonical(old, 'Class', 'concentration'), OLD, ...
    'one cell per reading is refused');
end

function testAMixOfTheTwoShapesIsRefused(testCase)
cache = did2.schema.cache.shared();
doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', [1 2]), ...
    'Dimensions', did2.build.dimension('time', 2), ...
    'Covariates', did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 1, 'Unit', 'second'), ...
    'TimeReferenceIds', {did.ido.unique_id()}, 'SessionId', testCase.TestData.sid, ...
    'ValueKind', 'voltage');
% an array of cells, one of which holds a series
bad = doc;
bad.voltage.value = struct('volts', {[1 2], 3});
verifyError(testCase, @() cache.validateDocument(bad), 'did2:validation:quantityShape');
% source_value and source_numeric in one cell
bad = doc;
bad.voltage.value = struct('volts', 1, 'source_value', 1, 'source_numeric', 1);
verifyError(testCase, @() cache.validateDocument(bad), 'did2:validation:quantityShape');
% a series stating its source as source_value
bad = doc;
bad.voltage.value = struct('volts', [1 2], 'source_value', [1 2]);
verifyError(testCase, @() cache.validateDocument(bad), 'did2:validation:quantityShape');
% the same through the builder
verifyError(testCase, @() did2.build.composite('voltage', 'value', ...
    struct('volts', {[1 2], 3})), 'did2:build:notScalar');
% a new-shape series validates
ok = doc;
ok.voltage.value = struct('volts', [1 2], 'source_numeric', [1000 2000]);
cache.validateDocument(ok);
% a covariate mixing the two shapes
% (refused by the rule while the schema declares `quantity`; once it does
% not, by the builder, which writes only declared fields)
cov = struct('variable', struct('node', '', 'name', 'depth'), 'along', 0, ...
    'quantity', struct('value', [1 2]), 'source_numeric', [1 2]);
verifyError(testCase, @() did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', [1 2]), 'Dimensions', did2.build.dimension('time', 2), ...
    'Covariates', cov, 'TimeReferenceIds', {did.ido.unique_id()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage'), ...
    oldOrNew('did2:build:ruleViolated', 'did2:build:unknownField'));
% the new shape's fields go with their form (plan section 6, "New")
cov = struct('variable', struct('node', '', 'name', 'depth'), 'along', 0, ...
    'numeric', [1 2], 'source_origin', 0);
verifyError(testCase, @() did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', [1 2]), 'Dimensions', did2.build.dimension('time', 2), ...
    'Covariates', cov, 'TimeReferenceIds', {did.ido.unique_id()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage'), 'did2:build:ruleViolated');
cov = struct('variable', struct('node', '', 'name', 'time'), 'along', 0, ...
    'origin', struct('value', 0), 'spacing', 1, 'source_spacing', 1);
verifyError(testCase, @() did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', [1 2]), 'Dimensions', did2.build.dimension('time', 2), ...
    'Covariates', cov, 'TimeReferenceIds', {did.ido.unique_id()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage'), ...
    oldOrNew('did2:build:ruleViolated', 'did2:build:typeMismatch'));
end

% ===================== logical ==============================================

function testLogicalValueInBothShapes(testCase)
% plan section 3: logical.value.logical, beside voltage.value.volts
cache = did2.schema.cache.shared();
newBlock = did2.build.valueCell('logical', true, 'Shape', 'new');
verifyEqual(testCase, newBlock, struct('logical', true));
values = {true, newBlock};
docs = cell(1, 2);
for k = 1:2
    docs{k} = did2.build.statement('assertion', did.ido.unique_id(), 'control condition', ...
        values{k}, 'SessionId', testCase.TestData.sid, 'ValueKind', 'logical');
    cache.validateDocument(docs{k});
end
verifyEqual(testCase, docs{2}.logical.value, struct('logical', true));
verifyError(testCase, @() did2.read.canonical(docs{1}), OLD, 'the bare logical is refused');
verifyEqual(testCase, did2.read.canonical(docs{2}).numbers, true);
verifyEqual(testCase, did2.read.canonical(docs{2}).field, 'logical');
bad = docs{2};
bad.logical.value = struct('logical', true, 'extra', 1);
verifyError(testCase, @() cache.validateDocument(bad), 'did2:validation:typeMismatch');
bad.logical.value = struct('logical', 'yes');
verifyError(testCase, @() cache.validateDocument(bad), 'did2:validation:typeMismatch');
end

% ===================== model_fit ============================================

function testFitCoefficientsInBothShapes(testCase)
% plan section 8, answer 5: coefficients and constraints are list items
cache = did2.schema.cache.shared();
assumeTrue(testCase, cache.hasClass('tuning_curve_calculation'), 'no tuning_curve_calculation');
docs = struct();
fitDoc = @(shape) fitStatement(testCase, shape);
docs.new = fitDoc('new');
cache.validateDocument(docs.new);
newCoef = docs.new.tuning_curve.value.model_fit.coefficients;
verifyEqual(testCase, [newCoef.numeric], [12.1 30]);
verifyFalse(testCase, isfield(newCoef, 'value'));
if did2.unittest.helpers.oldListShapeDeclared()
    docs.old = fitDoc('old');
    cache.validateDocument(docs.old);
    oldCoef = docs.old.tuning_curve.value.model_fit.coefficients;
else
    % did-schema without the old shape: refused by the builder; the old
    % coefficients {variable, value} written by hand
    verifyError(testCase, @() fitDoc('old'), 'did2:build:unknownField');
    oldCoef = struct('variable', {label('amplitude'), label('width')}, 'value', {12.1, 30});
end
verifySameReading(testCase, oldCoef, newCoef);
% a coefficient given in the new shape is accepted whatever the setting
f = did2.build.fitEntry('von Mises', 'Coefficients', struct('variable', ...
    did2.build.term('', 'amplitude'), 'numeric', 12.1, 'unit', did2.build.term('', 'hertz')), ...
    'Shape', 'old');
verifyEqual(testCase, f.coefficients.numeric, 12.1);
end

% ===================== compression parameters ===============================

function testCompressionParametersInBothShapes(testCase)
assumeTrue(testCase, did2.build.compressionBlockDeclared(), ...
    'the loaded schema types compression as text, not a {term, parameters} block');
prev = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prev));
settings = struct('cname', 'zstd', 'clevel', 5, 'ratio', 0.5);
did2.build.numericShape('new');
new = did2.build.compression('blosc-zstd', 'Settings', settings);
did2.build.numericShape('old');
old = oldBuilt(testCase, @() did2.build.compression('blosc-zstd', 'Settings', settings), ...
    struct('parameters', toOldItems(new.parameters, false)));
did2.build.numericShape('new');
verifySameReading(testCase, old.parameters, new.parameters);
ratio = new.parameters(end);
verifyEqual(testCase, ratio.numeric, 0.5);
verifyFalse(testCase, isfield(new.parameters, 'quantity'));
end

% ===================== helpers ==============================================

function x = oldBuilt(testCase, build, byHand, refusedAs)
% A list item (or block) in the OLD shape. While the loaded schema declares
% the old shape, the builder writes it (BUILD). Once did-schema removes it
% (numeric shape plan section 9 step 4, Waltham-Data-Science/did-schema #373)
% the builder refuses it -- checked here, as REFUSEDAS (default
% did2:build:unknownField) -- and the same item is written by hand (BYHAND),
% so what the test checks of the old shape (the readers refuse it) is
% checked on either schema.
if nargin < 4
    refusedAs = 'did2:build:unknownField';
end
if did2.unittest.helpers.oldListShapeDeclared()
    x = build();
else
    verifyError(testCase, build, refusedAs, 'the schema declares no old list shape');
    x = byHand;
end
end

function id = oldOrNew(whileDeclared, onceRemoved)
% the error id that refuses an old-shape field: WHILEDECLARED while the schema
% declares the old list shape, ONCEREMOVED once it does not
if did2.unittest.helpers.oldListShapeDeclared()
    id = whileDeclared;
else
    id = onceRemoved;
end
end

function t = label(name)
t = struct('node', '', 'name', name);
end

function out = toOldItems(items, isCovariate)
% ITEMS (new shape, a struct array or a cell) in the old shape, by hand: a
% number becomes `quantity` {value, source_value} (text on a condition or
% parameter, as the old builders wrote it), an array on a condition or
% parameter `matrix`, a flat origin/spacing the {value, source_value} block;
% the other forms are the same in both shapes
items = asItems(items);
out = cell(1, numel(items));
for k = 1:numel(items)
    e = items{k};
    o = struct();
    for f = reshape(fieldnames(e), 1, [])
        if ~any(strcmp(f{1}, {'numeric', 'source_numeric', 'tolerance', 'origin', 'spacing', ...
                'source_origin', 'source_spacing'})) && ~isempty(e.(f{1}))
            o.(f{1}) = e.(f{1});
        end
    end
    if isfield(e, 'numeric') && ~isempty(e.numeric)
        src = [];
        if isfield(e, 'source_numeric'); src = e.source_numeric; end
        if ~isCovariate && ~isscalar(e.numeric)
            o.matrix = e.numeric;
        else
            q = struct('value', e.numeric);
            if ~isempty(src)
                if ~isCovariate && isnumeric(src); src = num2str(src); end
                q.source_value = src;
            end
            o.quantity = q;
        end
    end
    if isfield(e, 'origin') && ~isempty(e.origin)
        o.origin = struct('value', e.origin);
        o.spacing = struct('value', e.spacing);
    end
    out{k} = o;
end
end

function doc = fitStatement(testCase, shape)
f = did2.build.fitEntry('von Mises', 'Coefficients', {'amplitude', 12.1; 'width', 30}, ...
    'Shape', shape, 'Target', 'tuning_curve_calculation.tuning_curve.value.model_fit');
v = struct('mean', [1 2 3 4], 'model_fit', f);
doc = did2.build.statement('tuning_curve_calculation', did.ido.unique_id(), ...
    'response', v, 'Dimensions', did2.build.dimension('direction', 4), ...
    'Covariates', did2.build.covariate('direction', 0, 'Unit', 'degree', ...
        'Value', [0 90 180 270], 'Shape', shape), ...
    'TimeReferenceIds', {did.ido.unique_id()}, 'SessionId', testCase.TestData.sid);
end

function doc = recording(testCase, shape)
uV = did2.build.term('om:microvolt', 'microvolt');
covs = did2.build.list( ...
    did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 3.33e-5, 'Unit', 'second', 'Shape', shape), ...
    did2.build.covariate('depth', 1, 'Value', [10 20 30], 'SourceValue', [10000 20000 30000], ...
        'Unit', 'micrometer', 'SourceUnit', did2.build.term('om:nanometre', 'nanometre'), ...
        'Shape', shape), ...
    did2.build.covariate('Unit Conversion Factor', 1, 'Value', [1.95e-7 1.95e-7 1.95e-7], ...
        'SourceValue', [0.195 0.195 0.195], 'Unit', 'volt', 'SourceUnit', uV, 'Shape', shape), ...
    did2.build.covariate('channel', 1, 'Term', {'A1', 'A2', 'A3'}, 'Shape', shape));
doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 6), 'Shape', shape), ...
    'Dimensions', did2.build.list(did2.build.dimension('time', 2), did2.build.dimension('channel', 3)), ...
    'DatumOrder', 'C', ...
    'Covariates', covs, ...
    'Conditions', did2.build.condition('temperature setting', 'Value', 37, 'SourceValue', '37', ...
        'Unit', 'degree Celsius', 'Shape', shape), ...
    'MethodParameters', did2.build.list( ...
        did2.build.parameter('threshold', 'Value', 4.5, 'SourceValue', '4.5', 'Unit', 'volt', 'Shape', shape), ...
        did2.build.parameter('colour weights', 'Matrix', [0.2 0.3 0.5], 'Shape', shape), ...
        did2.build.parameter('passes', 'Count', 3, 'Shape', shape)), ...
    'TimeReferenceIds', {did.ido.unique_id()}, 'SessionId', testCase.TestData.sid, ...
    'ValueKind', 'voltage');
end

function verifySameReading(testCase, old, new)
% item by item: an old item holding an old-shape form is refused
% ([no migrated database is kept], Jess Haley, 2026-11-19), and the new
% item states a number of its own; an item whose form is the same in both
% shapes (a term, a count) reads the same
old = asItems(old);
new = asItems(new);
verifyEqual(testCase, numel(new), numel(old));
for k = 1:min(numel(old), numel(new))
    rn = did2.read.numeric(new{k});
    if ~isempty(did2.read.oldNumericForm(old{k}))
        verifyError(testCase, @() did2.read.numeric(old{k}), OLD, ...
            sprintf('old item %d is refused', k));
        verifyNotEmpty(testCase, rn.form, sprintf('new item %d states a number', k));
        verifyTrue(testCase, isempty(did2.read.oldNumericForm(new{k})), ...
            sprintf('new item %d holds no old form', k));
    else
        verifyEqual(testCase, rn, did2.read.numeric(old{k}), sprintf('item %d', k));
    end
end
end

function c = asItems(x)
if iscell(x)
    c = reshape(x, 1, []);
else
    c = num2cell(reshape(x, 1, []));
end
end

function id = OLD
id = 'did2:read:oldNumericShapeReMigrate';
end
