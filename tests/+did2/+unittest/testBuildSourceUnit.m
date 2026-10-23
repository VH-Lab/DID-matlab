function tests = testBuildSourceUnit
%TESTBUILDSOURCEUNIT A value's `source_unit` as a term or as text, as the schema declares.
%
%   DID-schema V_eta_source_unit_plan.md (signed 2026-10-21): every dimensioned
%   value's `source_unit` is an `ontology_term` {node, name} bound
%   {strength: preferred, node_form: curie} -- the unit's REGISTERED term, its
%   label as the name; blank when the source gives no unit. did-schema `main`
%   declared char until #88 merged (2026-10-23), as does the pre-#73 tag
%   v_eta-pre73. So the builders read the
%   declaration of each field they fill (private/fillField.m):
%     - term shape: a term is written; TEXT IS AN ERROR
%       (did2:build:sourceUnitNotATerm) -- a spelling is not a term and the
%       builder does not guess one;
%     - char shape: text is written as given; a term writes its name;
%   and a caller asks did2.schema.cache/sourceUnitIsTerm which it has.
%
%   BOTH SHAPES ARE TESTED HERE WHATEVER DID_SCHEMA_PATH SAYS: each test points
%   the schema cache at a throwaway directory holding one value class,
%   `length`, whose value cell declares `source_unit` in the shape it wants
%   (the pattern of testSessionIdEdge). testBuild pins the real schema's half.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   test-builder.yml is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testBuildSourceUnit');

tests = functiontests(localfunctions);
end

function setup(testCase)
testCase.TestData.dirs = {};
end

function teardown(testCase)
did2.schema.cache.resetSingleton();
for k = 1:numel(testCase.TestData.dirs)
    if isfolder(testCase.TestData.dirs{k})
        rmdir(testCase.TestData.dirs{k}, 's');
    end
end
end

% ---- the shape question -------------------------------------------------------

function testTheSchemaSaysWhichShape(testCase)
useShape(testCase, 'term');
verifyTrue(testCase, did2.schema.cache.shared().sourceUnitIsTerm());
useShape(testCase, 'char');
verifyFalse(testCase, did2.schema.cache.shared().sourceUnitIsTerm());
end

% ---- the term shape -------------------------------------------------------------

function testOnTheTermShapeATermIsWritten(testCase)
useShape(testCase, 'term');
mm = did2.build.term('om:millimetre', 'millimetre');
v = did2.build.valueCell('length', [0.001 0.002], 'SourceValue', [1 2], 'SourceUnit', mm);
verifyEqual(testCase, size(v), [1 2]);
verifyEqual(testCase, v(1).source_unit, mm);
verifyEqual(testCase, v(2).source_unit, mm, 'one term for all cells');
% a {node, name} struct is the same thing
v = did2.build.valueCell('length', 0.001, 'SourceUnit', struct('node', 'om:millimetre', 'name', 'millimetre'));
verifyEqual(testCase, v.source_unit, mm);
end

function testOnTheTermShapeOneTermPerCell(testCase)
useShape(testCase, 'term');
units = did2.build.term({'om:millimetre', 'om:metre'}, {'millimetre', 'metre'});
v = did2.build.valueCell('length', [0.001 2], 'SourceValue', [1 2], 'SourceUnit', units);
verifyEqual(testCase, v(1).source_unit.node, 'om:millimetre');
verifyEqual(testCase, v(2).source_unit.node, 'om:metre');
end

function testOnTheTermShapeTextIsRefused(testCase)
useShape(testCase, 'term');
verifyError(testCase, @() did2.build.valueCell('length', 0.001, 'SourceValue', 1, ...
    'SourceUnit', 'mm'), 'did2:build:sourceUnitNotATerm');
verifyError(testCase, @() did2.build.valueCell('length', 0.001, 'SourceUnit', "mm"), ...
    'did2:build:sourceUnitNotATerm');
verifyError(testCase, @() did2.build.valueCell('length', [0.001 0.002], ...
    'SourceUnit', {'mm', 'mm'}), 'did2:build:sourceUnitNotATerm');
% the same through a hand-built cell (composite reaches the same check)
verifyError(testCase, @() did2.build.composite('length', 'value', ...
    struct('meters', 0.001, 'source_unit', 'mm')), 'did2:build:sourceUnitNotATerm');
end

function testOnTheTermShapeNoUnitLeavesTheFieldOut(testCase)
useShape(testCase, 'term');
v = did2.build.valueCell('length', 0.001, 'SourceValue', 1);
verifyFalse(testCase, isfield(v, 'source_unit'), ...
    'no source unit given: nothing written (the schema''s blank term is the default)');
end

% ---- the char shape -------------------------------------------------------------

function testOnTheCharShapeTextIsWrittenAsGiven(testCase)
useShape(testCase, 'char');
v = did2.build.valueCell('length', 0.001, 'SourceValue', 1, 'SourceUnit', 'mm');
verifyEqual(testCase, v.source_unit, 'mm');
end

function testOnTheCharShapeATermWritesItsName(testCase)
useShape(testCase, 'char');
v = did2.build.valueCell('length', [0.001 0.002], 'SourceUnit', ...
    did2.build.term('om:millimetre', 'millimetre'));
verifyEqual(testCase, {v.source_unit}, {'millimetre', 'millimetre'});
c = did2.build.composite('length', 'value', ...
    struct('meters', 0.001, 'source_unit', struct('node', 'om:millimetre', 'name', 'millimetre')));
verifyEqual(testCase, c.source_unit, 'millimetre');
end

% ---- the term registry covers a source unit like any other term ---------------

function testAnUnregisteredSourceUnitIsRefusedWhenArmed(testCase)
useShape(testCase, 'term', true);
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
verifyError(testCase, @() did2.build.valueCell('length', 0.001, 'SourceUnit', ...
    did2.build.term('om:inch-International', 'inch')), 'did2:build:unregisteredTerm');
% the registered term passes
v = did2.build.valueCell('length', 0.001, 'SourceUnit', did2.build.term('om:millimetre', 'millimetre'));
verifyEqual(testCase, v.source_unit.node, 'om:millimetre');
% the registered node under a label that is not the registered one is refused
verifyError(testCase, @() did2.build.valueCell('length', 0.001, 'SourceUnit', ...
    did2.build.term('om:millimetre', 'mm')), 'did2:build:unregisteredTerm');
end

function testAnUnregisteredSourceUnitIsCollectedWhenDisarmed(testCase)
useShape(testCase, 'term', true);
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
prevC = did2.build.unregisteredTerms('-collect', true);
testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prevC));
did2.build.unregisteredTerms('-reset');
testCase.addTeardown(@() did2.build.unregisteredTerms('-reset'));
did2.build.valueCell('length', [0.001 0.002], 'SourceUnit', did2.build.term('om:inch-International', 'inch'));
L = did2.build.unregisteredTerms();
verifyNumElements(testCase, L, 1);
verifyEqual(testCase, L.node, 'om:inch-International');
verifyTrue(testCase, endsWith(L.field, 'source_unit'), ...
    sprintf('the field is the source unit, got "%s"', L.field));
end

% ===================== helpers =================================================

function useShape(testCase, shape, withRegistry)
% Point the shared schema cache at a throwaway directory whose only class is a
% `length` value with `source_unit` declared as SHAPE ('term' or 'char'), and,
% with WITHREGISTRY, a term registry holding om:millimetre.
arguments
    testCase
    shape {mustBeMember(shape, {'term', 'char'})}
    withRegistry (1,1) logical = false
end
dirPath = tempname();
mkdir(dirPath);
testCase.TestData.dirs{end+1} = dirPath;
leaf = @(name, type) struct('name', name, 'type', type, 'mustBeNonEmpty', false, ...
    'mustBeScalar', true, 'blank_value', [], 'default_value', [], 'constraints', struct());
if strcmp(shape, 'term')
    unit = leaf('source_unit', 'ontology_term');
    unit.blank_value = struct('node', '', 'name', '');
    unit.default_value = struct('node', '', 'name', '');
    unit.constraints = struct('binding', struct('strength', 'preferred', 'node_form', 'curie'));
    unit.fields = {leaf('node', 'char'), leaf('name', 'char')};
else
    unit = leaf('source_unit', 'char');
end
meters = leaf('meters', 'double');
meters.mustBeNonEmpty = true;
value = struct('name', 'value', 'type', 'structure', 'mustBeNonEmpty', true, ...
    'mustBeScalar', false, 'constraints', struct());
value.fields = {meters, unit, leaf('source_value', 'double')};
cls = struct();
cls.document_class = struct('class_name', 'length', 'class_version', '1.0.0', ...
    'superclasses', {{}}, 'maturity_level', 'stable');
cls.depends_on = {};
cls.fields = {value};
cls.file = {};
writeJson(fullfile(dirPath, 'length.json'), cls);
if withRegistry
    writeJson(fullfile(dirPath, 'term_registry_meta.json'), struct('terms', ...
        {{struct('node', 'om:millimetre', 'name', 'millimetre', 'status', 'decided')}}));
end
did2.schema.cache.setSchemaPath(dirPath);
end

function writeJson(file, s)
fid = fopen(file, 'w');
fwrite(fid, jsonencode(s));
fclose(fid);
end
