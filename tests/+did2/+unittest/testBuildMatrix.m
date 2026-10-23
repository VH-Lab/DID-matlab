function tests = testBuildMatrix
%TESTBUILDMATRIX did2.build: the `matrix` value form (data_body AMENDMENT 4).
%
%   did-schema PR #88 (commit 0e26907, V_eta_data_body_model_plan.md
%   AMENDMENT 4, a PROPOSAL built ahead of signature): the single-value entry
%   shared by `conditions` and `method.parameters` gains a fifth value form,
%   `matrix` -- a numeric N-D array that is ONE value of the entry's
%   `variable`, in the entry's `unit`, with no `source_value`, stored
%   row-major as JSON nested arrays. A dimension does NOT get it; a covariate
%   does, as a whole array at EACH position (data_body AMENDMENT 6,
%   [matrix covariate]; keys before AMENDMENT 6 did not).
%
%   The case that prompted it is a noise stimulus as a `method` document: a
%   colour palette (n x 3, in NCIT:C75765 Arbitrary Unit), colour weights, a
%   background RGB triple, a 35-number random seed (variable NCIT:C64220
%   Random Seed) and a bit depth (a count, 8).
%
%   What is pinned here: the builder writes the form and its checks (exactly
%   one form; no SourceValue; a dimension refuses it); the document validates
%   against the #88 schema; and the arrays come back IDENTICAL -- values,
%   class AND orientation -- through did2's JSON writer and reader and
%   through a did2 sqlite database. Orientation is the part plain
%   jsonencode/jsondecode get wrong (a 1xN row comes back Nx1), so it is
%   asserted for a row, a column and an n x 3 matrix separately.
%
%   Every test is FILTERED (assumeFail) when the loaded schema has no
%   `matrix` on method.parameters, as testBuild filters on a pre-#73 schema;
%   test-builder.yml runs this file against the same-named did-schema branch.
%
%   UNVERIFIED: written without MATLAB; test-builder.yml is where it runs.
%
%   Run with:  results = runtests('did2.unittest.testBuildMatrix');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build matrix tests');
% The term registry check (tenet T19, strictMode 'TermRegistry') is OFF for
% this file, whatever DID_ENFORCE_TERM_REGISTRY says: these tests build from
% made-up terms ('voltage', 'colour palette', a bare {name:'time'}) to test the
% builder's mechanics. test-builder.yml and test-migrators-quick.yml set
% DID_ENFORCE_TERM_REGISTRY=0 for that reason; test-code.yml does not, so once
% this file stopped filtering itself there (AMENDMENT 6's dimensions.n), every
% made-up term was refused (run 39745771053). The registry check itself is
% tested with the switch ARMED in testBuildTermRegistry, testBuildSourceUnit,
% testBuildValueSet and testBuildMatrix/testTermChecksStillCoverVariableAndUnit.
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
cache = did2.schema.cache.shared();
if ~hasMatrix(cache)
    assumeFail(testCase, sprintf(['the loaded schema (%s) declares no `matrix` ' ...
        'value form on method.parameters (did-schema #88, data_body AMENDMENT 4).'], ...
        cache.schemaPath));
end
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the builder ==========================================

function testAParameterCarriesAMatrixAsOneValue(testCase)
p = did2.build.parameter('colour palette', 'Matrix', palette(), 'Unit', arbitraryUnit());
verifyEqual(testCase, p.matrix, palette());
verifyEqual(testCase, p.unit.node, 'NCIT:C75765');
verifyFalse(testCase, isfield(p, 'quantity'));
% a logical array is stored as 0/1 doubles
q = did2.build.parameter('mask', 'Matrix', logical([1 0 1]));
verifyClass(testCase, q.matrix, 'double');
verifyEqual(testCase, q.matrix, [1 0 1]);
end

function testAConditionCarriesAMatrix(testCase)
c = did2.build.condition('background colour', 'Matrix', [128 128 128], ...
    'Unit', arbitraryUnit());
verifyEqual(testCase, c.matrix, [128 128 128]);
end

function testTheNoiseMethodDocumentValidates(testCase)
m = noiseMethod(testCase);   % did2.build.method validates by default
verifyEqual(testCase, m.document_class.class_name, 'method');
params = m.method.parameters;
verifyEqual(testCase, numel(params), 5);
verifyEqual(testCase, entry(params, 'colour palette').matrix, palette());
verifyEqual(testCase, entry(params, 'colour weights').matrix, weights());
verifyEqual(testCase, entry(params, 'Random Seed').matrix, seed());
verifyEqual(testCase, entry(params, 'bit depth').count, 8);
% and the cache's own validator agrees, independently of the builder
verifyWarningFree(testCase, @() did2.document(m).validate( ...
    'SchemaCache', did2.schema.cache.shared()));
end

function testTwoValueFormsAtOnceAreRefused(testCase)
verifyError(testCase, @() did2.build.parameter('x', 'Value', 1, 'Matrix', [1 2]), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.condition('x', 'Count', 3, 'Matrix', [1 2]), ...
    'did2:build:ruleViolated');
% the same, written by hand past the option checks: the document check sees it
both = struct('variable', struct('name', 'x'), ...
    'quantity', struct('value', 1), 'matrix', [1 2]);
verifyError(testCase, @() did2.build.method('x', both, ...
    'SessionId', testCase.TestData.sid), 'did2:build:ruleViolated');
end

function testAMatrixCarriesNoSourceValue(testCase)
verifyError(testCase, @() did2.build.parameter('x', 'Matrix', [1 2], ...
    'SourceValue', '1 2'), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.parameter('x', 'Matrix', {1, 2}), ...
    'did2:build:typeMismatch');
end

function testADimensionHasNoMatrix(testCase)
% the dimension builder has no 'Matrix' option ...
threw = false;
try
    did2.build.dimension('colour', 3, 'Matrix', palette());
catch
    threw = true;
end
verifyTrue(testCase, threw, 'did2.build.dimension accepted a ''Matrix'' option.');
% ... and the schema declares none on a dimension (AMENDMENT 6: a dimension
% is {term, n, chunk}; what varies along it is a covariate)
verifyError(testCase, @() did2.build.composite('data', 'dimensions', ...
    struct('term', struct('name', 'colour'), 'n', 3, 'matrix', palette())), ...
    'did2:build:unknownField');
end

function testACovariateMatrixIsAnArrayAtEachPosition(testCase)
% [matrix covariate] (Jess Haley, 2026-10-22): along a `colour` dimension of
% 4, each position holds a 1 x 3 RGB triple: shape [4 3], the dimension's
% extent first, then the array's own shape.
c = did2.build.covariate('rgb', 0, 'Matrix', palette(), 'Unit', arbitraryUnit());
verifyEqual(testCase, c.matrix, palette());
end

function testTermChecksStillCoverVariableAndUnit(testCase)
ix = did2.schema.termIndex();
assumeTrue(testCase, ix.present, 'the loaded schema has no term registry');
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
% both registered by #88: Random Seed (variable), Arbitrary Unit (unit)
verifyWarningFree(testCase, @() did2.build.parameter(randomSeed(), ...
    'Matrix', seed(), 'Unit', arbitraryUnit()));
verifyError(testCase, @() did2.build.parameter( ...
    did2.build.term('', 'a variable nobody registered'), 'Matrix', [1 2]), ...
    'did2:build:unregisteredTerm');
verifyError(testCase, @() did2.build.parameter(randomSeed(), 'Matrix', [1 2], ...
    'Unit', did2.build.term('', 'a unit nobody registered')), ...
    'did2:build:unregisteredTerm');
end

% ===================== the JSON writer and reader ===========================

function testTheWriterKeepsEveryDimension(testCase)
m = noiseMethod(testCase);
txt = did2.document(m).toJSON('SchemaCache', did2.schema.cache.shared());
% 1 x 4 weights: one row; 35 x 1 seed: 35 rows of one; 4 x 3 palette
verifyTrue(testCase, contains(txt, '"matrix":[[0.1,0.2,0.3,0.4]]'), txt);
verifyTrue(testCase, contains(txt, '"matrix":[[0,0,0],[255,0,0],[0,255,0],[0,0,255]]'), txt);
s = seed();
verifyTrue(testCase, contains(txt, sprintf('"matrix":[[%s],', ...
    did2unittestNumber(s(1)))), txt);
% a document whose class declares no matrix is written as jsonencode writes it
plain = struct('a', [1 2 3]);
verifyEqual(testCase, did2.document(plain).toJSON(), jsonencode(plain));
end

function testJsonRoundTripPreservesOrientation(testCase)
cache = did2.schema.cache.shared();
m = noiseMethod(testCase);
back = did2.document.fromJSON(did2.document(m).toJSON('SchemaCache', cache), ...
    'SchemaCache', cache);
params = back.get('method.parameters');
fprintf('DENOMINATOR: 1 method document, %d parameter(s) round-tripped through JSON\n', ...
    numel(params));
verifyMatrix(testCase, entry(params, 'colour palette').matrix, palette(), 'palette (4 x 3)');
verifyMatrix(testCase, entry(params, 'colour weights').matrix, weights(), 'weights (1 x 4)');
verifyMatrix(testCase, entry(params, 'Random Seed').matrix, seed(), 'seed (35 x 1)');
verifyEqual(testCase, entry(params, 'bit depth').count, 8);
verifyWarningFree(testCase, @() back.validate('SchemaCache', cache));
end

function testJsonRoundTripOfScalarAndNDimensionalMatrices(testCase)
cache = did2.schema.cache.shared();
nd = reshape([1:11 pi], 2, 3, 2);
m = did2.build.method([], did2.build.list( ...
        did2.build.parameter('one', 'Matrix', 7), ...
        did2.build.parameter('cube', 'Matrix', nd), ...
        did2.build.parameter('awkward', 'Matrix', [1/3 0.1 -2.5e-17 NaN])), ...
    'SessionId', testCase.TestData.sid);
back = did2.document.fromJSON(did2.document(m).toJSON('SchemaCache', cache), ...
    'SchemaCache', cache);
params = back.get('method.parameters');
verifyMatrix(testCase, entry(params, 'one').matrix, 7, 'scalar');
verifyMatrix(testCase, entry(params, 'cube').matrix, nd, '2 x 3 x 2');
verifyMatrix(testCase, entry(params, 'awkward').matrix, [1/3 0.1 -2.5e-17 NaN], ...
    'non-terminating decimals and NaN');
end

% ===================== a did2 sqlite database ===============================

function testSqliteRoundTripReturnsIdenticalArrays(testCase)
assumeFalse(testCase, isempty(which('mksqlite')), 'mksqlite is not installed');
cache = did2.schema.cache.shared();
dbFile = [tempname '.sqlite'];
testCase.addTeardown(@() deleteIfThere(dbFile));
db = did2.database.sqlitedb(dbFile, 'SchemaCache', cache);
testCase.addTeardown(@() db.close());

m = noiseMethod(testCase);
db.add(did2.document(m), 'Validate', true);
back = db.get(m.base.id);
params = back.get('method.parameters');
fprintf('DENOMINATOR: 1 method document written to and read from a did2 sqlite db, %d parameter(s)\n', ...
    numel(params));
verifyMatrix(testCase, entry(params, 'colour palette').matrix, palette(), 'palette (4 x 3)');
verifyMatrix(testCase, entry(params, 'colour weights').matrix, weights(), 'weights (1 x 4)');
verifyMatrix(testCase, entry(params, 'Random Seed').matrix, seed(), 'seed (35 x 1)');
verifyEqual(testCase, entry(params, 'Random Seed').variable.node, 'NCIT:C64220');
verifyEqual(testCase, entry(params, 'colour palette').unit.node, 'NCIT:C75765');
verifyEqual(testCase, entry(params, 'bit depth').count, 8);
verifyWarningFree(testCase, @() back.validate('SchemaCache', cache));
end

% ===================== helpers ==============================================

function m = noiseMethod(testCase)
% a sparse-noise stimulus as a method document (V_eta_method_plan.md)
au = arbitraryUnit();
m = did2.build.method('sparse noise', did2.build.list( ...
        did2.build.parameter('colour palette', 'Matrix', palette(), 'Unit', au), ...
        did2.build.parameter('colour weights', 'Matrix', weights()), ...
        did2.build.parameter('background colour', 'Matrix', [128 128 128], 'Unit', au), ...
        did2.build.parameter(randomSeed(), 'Matrix', seed()), ...
        did2.build.parameter('bit depth', 'Count', 8)), ...
    'SessionId', testCase.TestData.sid);
end

function p = palette()
p = [0 0 0; 255 0 0; 0 255 0; 0 0 255];   % n x 3, n = 4
end

function w = weights()
w = [0.1 0.2 0.3 0.4];                    % 1 x n
end

function s = seed()
% the 35-number legacy rand('state') vector is a COLUMN; drawn from a local
% stream so the global generator is untouched
rs = RandStream('mt19937ar', 'Seed', 7);
s = [rand(rs, 34, 1); 12];
end

function t = arbitraryUnit()
t = did2.build.term('NCIT:C75765', 'Arbitrary Unit');
end

function t = randomSeed()
t = did2.build.term('NCIT:C64220', 'Random Seed');
end

function e = entry(params, name)
% the parameter whose variable is NAME
names = arrayfun(@(p) char(p.variable.name), params, 'UniformOutput', false);
e = params(strcmp(names, name));
assert(isscalar(e), 'expected exactly one parameter "%s"', name);
end

function verifyMatrix(testCase, got, want, what)
verifyClass(testCase, got, 'double', what);
verifyEqual(testCase, size(got), size(want), sprintf('%s: shape', what));
verifyTrue(testCase, isequaln(got, want), sprintf('%s: values differ', what));
end

function t = did2unittestNumber(x)
% the writer's number text for one value (shortest of 15..17 digits)
for digits = 15:17
    t = sprintf(sprintf('%%.%dg', digits), x);
    if str2double(t) == x
        return;
    end
end
end

function tf = hasMatrix(cache)
tf = false;
if ~cache.hasClass('method')
    return;
end
own = cache.ownFields('method');
for k = 1:numel(own)
    if strcmp(char(own{k}.name), 'parameters') && isfield(own{k}, 'fields')
        sub = own{k}.fields;
        if isstruct(sub)
            names = {sub.name};
        else
            names = cellfun(@(d) char(d.name), sub, 'UniformOutput', false);
        end
        tf = any(strcmp(names, 'matrix'));
        return;
    end
end
end

function deleteIfThere(f)
if isfile(f)
    delete(f);
end
end
