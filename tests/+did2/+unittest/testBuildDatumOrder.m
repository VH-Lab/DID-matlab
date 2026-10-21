function tests = testBuildDatumOrder
%TESTBUILDDATUMORDER Which block declares `datum_order`, as the schema says.
%
%   did-schema PR #88 (Haley audit D-5, signed 2026-10-20) moved `datum_order`
%   from `sampled_body` up to `data`, beside `keys`: it describes whichever
%   array the keys do, an inline value or a body's own; empty means F.
%   did-schema `main` and the pinned v_eta-pre73 still declare it on
%   `sampled_body`. did2.build places a field by its declaration, so
%   sampledBody is unchanged; a caller that writes or reads the block directly
%   (hartley_calc, the tests) asks did2.schema.cache/datumOrderBlock.
%
%   BOTH SHAPES ARE TESTED HERE WHATEVER DID_SCHEMA_PATH SAYS: each test points
%   the schema cache at a throwaway directory holding `data` and
%   `sampled_body` with `datum_order` declared on the one it wants (the
%   pattern of testBuildSourceUnit). testBuild/testSampledBody pins the real
%   schema's half.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   test-builder.yml is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testBuildDatumOrder');

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

function testOnTheD5ShapeItIsData(testCase)
useShape(testCase, 'data');
verifyEqual(testCase, did2.schema.cache.shared().datumOrderBlock(), 'data');
end

function testOnTheOlderShapeItIsSampledBody(testCase)
useShape(testCase, 'sampled_body');
verifyEqual(testCase, did2.schema.cache.shared().datumOrderBlock(), 'sampled_body');
end

function testWhenNeitherDeclaresItTheAnswerIsEmpty(testCase)
useShape(testCase, 'none');
verifyEqual(testCase, did2.schema.cache.shared().datumOrderBlock(), '');
end

% ===================== helpers =================================================

function useShape(testCase, where)
% Point the shared schema cache at a throwaway directory holding `data`
% (declaring `keys`) and `sampled_body` (declaring `byte_order`), with
% `datum_order` declared on WHERE ('data', 'sampled_body' or 'none').
arguments
    testCase
    where {mustBeMember(where, {'data', 'sampled_body', 'none'})}
end
dirPath = tempname();
mkdir(dirPath);
testCase.TestData.dirs{end+1} = dirPath;
leaf = @(name, type) struct('name', name, 'type', type, 'mustBeNonEmpty', false, ...
    'mustBeScalar', true, 'blank_value', '', 'default_value', '', 'constraints', struct());
order = leaf('datum_order', 'char');
order.constraints = struct('enum', {{'C', 'F'}});
dataFields = {leaf('keys', 'structure')};
bodyFields = {leaf('byte_order', 'char')};
switch where
    case 'data'
        dataFields{end+1} = order;
    case 'sampled_body'
        bodyFields{end+1} = order;
end
writeClass(dirPath, 'data', {}, dataFields);
writeClass(dirPath, 'sampled_body', {}, bodyFields);
did2.schema.cache.setSchemaPath(dirPath);
end

function writeClass(dirPath, name, supers, fields)
cls = struct();
cls.document_class = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', {supers}, 'maturity_level', 'stable');
cls.depends_on = {};
cls.fields = fields;
cls.file = {};
fid = fopen(fullfile(dirPath, [name '.json']), 'w');
fwrite(fid, jsonencode(cls));
fclose(fid);
end
