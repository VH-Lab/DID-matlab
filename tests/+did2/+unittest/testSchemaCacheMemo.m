function tests = testSchemaCacheMemo
% testSchemaCacheMemo - superclasses() and resolvePlacement() are computed
%   once per class and remembered; the remembered answer must be the
%   answer a fresh cache computes, for every fixture class, and an error
%   must not be remembered as an answer.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
testCase.TestData.fixtureDir = fixtureDir;
files = dir(fullfile(fixtureDir, '*.json'));
names = erase({files.name}, '.json');
testCase.TestData.classes = names(~endsWith(names, '_meta'));
end

function setup(testCase)
did2.schema.cache.setSchemaPath(testCase.TestData.fixtureDir);
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function testRememberedAnswersEqualAFreshCache(testCase)
classes = testCase.TestData.classes;
a = did2.schema.cache.shared();
first = answers(a, classes);
second = answers(a, classes);                 % from the memo
did2.schema.cache.setSchemaPath(testCase.TestData.fixtureDir);
fresh = answers(did2.schema.cache.shared(), classes);
verifyGreaterThan(testCase, nnz(cellfun(@(x) isstruct(x.placement), first)), 0, ...
    'some fixture class resolves a placement');
for k = 1:numel(classes)
    verifyEqual(testCase, second{k}, first{k}, classes{k});
    verifyEqual(testCase, second{k}, fresh{k}, classes{k});
end
end

function testAnErrorIsNotRemembered(testCase)
% fixtures built to violate the placement rules raise every time
c = did2.schema.cache.shared();
bad = {'demoBadConcrete', 'demoCollideAbstract', 'demoCollideConcrete'};
bad = bad(ismember(bad, testCase.TestData.classes));
verifyNotEmpty(testCase, bad);
for k = 1:numel(bad)
    id1 = errorId(@() c.resolvePlacement(bad{k}));
    id2 = errorId(@() c.resolvePlacement(bad{k}));
    verifyNotEmpty(testCase, id1, bad{k});
    verifyEqual(testCase, id2, id1, [bad{k} ': the second call raises too']);
end
end

function testDecodingIsUnchangedOnRepeat(testCase)
% fromJSON rehydrates through resolvePlacement: the same JSON decodes to
% the same document the first time (computed) and the tenth (remembered)
c = did2.schema.cache.shared();
for name = {'demoA', 'demoB', 'demoArray'}
    doc = did2.document.blank(name{1});
    json = doc.toJSON();
    d1 = did2.document.fromJSON(json, 'SchemaCache', c);
    for k = 1:9
        dk = did2.document.fromJSON(json, 'SchemaCache', c);
    end
    verifyEqual(testCase, dk.toStruct(), d1.toStruct(), name{1});
end
end

% ---- helpers ----

function out = answers(c, classes)
out = cell(1, numel(classes));
for k = 1:numel(classes)
    x = struct('superclasses', {{}}, 'placement', []);
    try
        x.superclasses = c.superclasses(classes{k});
    catch err
        x.superclasses = err.identifier;
    end
    try
        info = c.resolvePlacement(classes{k});
        keys = sort(info.fieldsByBlock.keys());
        vals = cellfun(@(key) info.fieldsByBlock(key), keys, 'UniformOutput', false);
        x.placement = struct('blocks', {info.blocksContributed}, 'chain', {info.chain}, ...
            'keys', {keys}, 'values', {vals});
    catch err
        x.placement = err.identifier;
    end
    out{k} = x;
end
end

function id = errorId(fn)
id = '';
try
    fn();
catch err
    id = err.identifier;
end
end
