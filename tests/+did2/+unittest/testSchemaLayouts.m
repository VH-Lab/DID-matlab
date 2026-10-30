function tests = testSchemaLayouts
%TESTSCHEMALAYOUTS did2.schema.cache reads did-schema's old and new layouts alike.
%
%   Decided by Jess Haley, 2026-10-30 [schema folders by family] (did-schema
%   V_eta_go_forward_class_audit.md): schemas/did_v2/ holds class files only,
%   in family subfolders (core classes at the top; value/, calculation/,
%   data_body/, time_reference/, retiring/); the registries move to
%   schemas/registry/ and the tool-written files to schemas/generated/.
%   Siblings first: DID-matlab reads both layouts before did-schema moves.
%
%   Each test builds the SAME classes and registries in a temp tree in the old
%   layout (stable/ and draft/ tiers, registries in stable/) and in the new one,
%   and checks that the cache loads the same classes and the same registries
%   from both, and from the flat folder CI assembles; that a class or registry
%   held twice is an error, not a silent pick; and that non-class JSON is never
%   loaded as a class.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
testCase.TestData.fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal');
testCase.TestData.root = tempname;
mkdir(testCase.TestData.root);
testCase.TestData.old = buildTree(testCase.TestData, 'old');
testCase.TestData.new = buildTree(testCase.TestData, 'new');
end

function teardownOnce(testCase)
did2.schema.cache.resetSingleton();
if isfolder(testCase.TestData.root)
    rmdir(testCase.TestData.root, 's');
end
end

function teardown(~)
did2.schema.cache.resetSingleton();
end

% --- the tests -------------------------------------------------------------

function testBothLayoutsListTheSameClassFiles(testCase)
old = did2.schema.cache.classFilesIn(fullfile(testCase.TestData.old, 'did_v2'));
new = did2.schema.cache.classFilesIn(fullfile(testCase.TestData.new, 'did_v2'));
verifyEqual(testCase, sort(old.keys()), sort(classNames()));
verifyEqual(testCase, sort(new.keys()), sort(classNames()));
% the new layout's classes are found in their family folders
verifyTrue(testCase, contains(new('demoB'), [filesep 'value' filesep]));
verifyTrue(testCase, contains(new('demoC'), [filesep 'retiring' filesep]));
end

function testBothLayoutsLoadTheSameClassesAndRegistries(testCase)
got = struct();
for layout = {'old', 'new'}
    c = loadCache(fullfile(testCase.TestData.(layout{1}), 'did_v2'));
    got.(layout{1}) = c;
    verifyEqual(testCase, sort(c.loadedClasses.keys()), sort(classNames()), layout{1});
    verifyRegistries(testCase, c, layout{1});
end
for k = 1:numel(classNames())
    n = classNames();
    verifyEqual(testCase, got.new.getClass(n{k}), got.old.getClass(n{k}), n{k});
end
end

function testTheOldStableTierStillReadsItsRegistries(testCase)
% the old default (schemas/did_v2/stable) and a DID_SCHEMA_PATH set to it
c = loadCache(fullfile(testCase.TestData.old, 'did_v2', 'stable'));
verifyRegistries(testCase, c, 'old stable/');
verifyTrue(testCase, c.hasClass('demoA'));
verifyFalse(testCase, c.hasClass('demoB'));  % a draft class, as before
end

function testTheNewLayoutIsTheDefaultSetFolder(testCase)
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath( ...
    testCase.TestData.new, 'stable'), fullfile(testCase.TestData.new, 'did_v2'));
end

function testTheFlatAssembledFolderLoadsTheSame(testCase)
% CI copies the set FLAT into one folder (tools/assemble_schema_set.py);
% copySchemaSet does the same from MATLAB. Both layouts give the same folder.
for layout = {'old', 'new'}
    flat = fullfile(testCase.TestData.root, ['flat_' layout{1}]);
    n = did2.schema.cache.copySchemaSet( ...
        fullfile(testCase.TestData.(layout{1}), 'did_v2'), flat);
    verifyEqual(testCase, n, numel(classNames()) + numel(registryNames()), layout{1});
    % a flat folder may also hold the authored registers and the index: not classes
    writeJson(fullfile(flat, 'did_v2_term_registry.json'), '{"terms":[]}');
    writeJson(fullfile(flat, 'V_eta_carry_register.json'), '{"rows":[]}');
    writeJson(fullfile(flat, 'index.json'), '{"classes":[]}');
    c = loadCache(flat);
    verifyEqual(testCase, sort(c.loadedClasses.keys()), sort(classNames()), layout{1});
    verifyRegistries(testCase, c, ['flat ' layout{1}]);
end
end

function testAClassHeldTwiceIsAnError(testCase)
tree = buildTree(testCase.TestData, 'new', 'dupclass');
copyfile(fullfile(tree, 'did_v2', 'demoA.json'), ...
    fullfile(tree, 'did_v2', 'calculation', 'demoA.json'));
verifyError(testCase, @() did2.schema.cache.classFilesIn(fullfile(tree, 'did_v2')), ...
    'did2:schema:duplicateClass');
verifyError(testCase, @() did2.schema.cache.setSchemaPath(fullfile(tree, 'did_v2')), ...
    'did2:schema:duplicateClass');
end

function testARegistryHeldTwiceIsAnError(testCase)
tree = buildTree(testCase.TestData, 'new', 'dupregistry');
copyfile(fullfile(tree, 'registry', 'binding_registry_meta.json'), ...
    fullfile(tree, 'generated', 'binding_registry_meta.json'));
verifyError(testCase, @() did2.schema.cache.registryFileIn( ...
    fullfile(tree, 'did_v2'), 'binding_registry_meta.json'), ...
    'did2:schema:duplicateRegistryFile');
end

function testRenamedDataFilesAreFoundUnderEitherPrefix(testCase)
tree = buildTree(testCase.TestData, 'new', 'prefix');
writeJson(fullfile(tree, 'V_eta_carry_register.json'), '{"which":"old"}');
p = did2.schema.cache.registryFileIn(fullfile(tree, 'did_v2'), 'did_v2_carry_register.json');
verifyEqual(testCase, p, fullfile(tree, 'V_eta_carry_register.json'));
writeJson(fullfile(tree, 'registry', 'did_v2_carry_register.json'), '{"which":"new"}');
p = did2.schema.cache.registryFileIn(fullfile(tree, 'did_v2'), 'did_v2_carry_register.json');
verifyEqual(testCase, p, fullfile(tree, 'registry', 'did_v2_carry_register.json'));
end

function testNonClassFilesAreNotClasses(testCase)
verifyFalse(testCase, did2.schema.cache.isClassFileName('term_registry_meta'));
verifyFalse(testCase, did2.schema.cache.isClassFileName('ndi_reserved_keys'));
verifyFalse(testCase, did2.schema.cache.isClassFileName('index'));
verifyFalse(testCase, did2.schema.cache.isClassFileName('topics'));
verifyFalse(testCase, did2.schema.cache.isClassFileName('did_v2_term_registry'));
verifyFalse(testCase, did2.schema.cache.isClassFileName('V_eta_carry_register'));
verifyTrue(testCase, did2.schema.cache.isClassFileName('entity'));
verifyTrue(testCase, did2.schema.cache.isClassFileName('tuning_curve_calculation'));
end

% --- helpers ---------------------------------------------------------------

function names = classNames()
names = {'base', 'demoA', 'demoB', 'demoC'};
end

function names = registryNames()
names = {'CURIE_lookups_meta.json', 'term_registry_meta.json', ...
    'binding_registry_meta.json', 'class_disposition_meta.json'};
end

function schemas = buildTree(td, layout, tag)
% <root>/<layout>[_<tag>]/schemas in LAYOUT, holding the fixture classes
% base, demoA, demoB, demoC and four registries whose content names them.
if nargin < 3
    tag = '';
end
schemas = fullfile(td.root, [layout tag], 'schemas');
% class -> {old tier, new family folder ('' = top level)}
place = struct('base', {{'stable', ''}}, 'demoA', {{'stable', ''}}, ...
    'demoB', {{'draft', 'value'}}, 'demoC', {{'draft', 'retiring'}});
names = classNames();
for k = 1:numel(names)
    where = place.(names{k});
    if strcmp(layout, 'old')
        folder = fullfile(schemas, 'did_v2', where{1});
    else
        folder = fullfile(schemas, 'did_v2', where{2});
    end
    if ~isfolder(folder)
        mkdir(folder);
    end
    copyfile(fullfile(td.fixtureDir, [names{k} '.json']), fullfile(folder, [names{k} '.json']));
end
if strcmp(layout, 'new')
    mkdir(fullfile(schemas, 'did_v2', 'calculation'));  % an empty family folder
end
regs = registryNames();
for k = 1:numel(regs)
    if strcmp(layout, 'old')
        folder = fullfile(schemas, 'did_v2', 'stable');
    elseif any(strcmp(regs{k}, {'term_registry_meta.json', 'class_disposition_meta.json'}))
        folder = fullfile(schemas, 'generated');
    else
        folder = fullfile(schemas, 'registry');
    end
    if ~isfolder(folder)
        mkdir(folder);
    end
    if strcmp(regs{k}, 'CURIE_lookups_meta.json')
        copyfile(fullfile(td.fixtureDir, regs{k}), fullfile(folder, regs{k}));
    else
        writeJson(fullfile(folder, regs{k}), sprintf('{"marker":"%s"}', regs{k}));
    end
end
% the set's index and the authored registers are not classes
if strcmp(layout, 'old')
    writeJson(fullfile(schemas, 'did_v2', 'index.json'), '{"classes":[]}');
    writeJson(fullfile(schemas, 'V_eta_term_registry.json'), '{"terms":[]}');
else
    writeJson(fullfile(schemas, 'generated', 'index.json'), '{"classes":[]}');
    writeJson(fullfile(schemas, 'registry', 'did_v2_term_registry.json'), '{"terms":[]}');
end
end

function c = loadCache(schemaPath)
did2.schema.cache.setSchemaPath(schemaPath);
c = did2.schema.cache.shared();
c.loadAllSchemas();
end

function verifyRegistries(testCase, c, label)
verifyFalse(testCase, isempty(fieldnames(c.curieRegistry)), [label ': CURIE registry']);
verifyEqual(testCase, c.termRegistry.marker, 'term_registry_meta.json', label);
verifyEqual(testCase, c.bindingRegistry.marker, 'binding_registry_meta.json', label);
verifyEqual(testCase, c.classDisposition.marker, 'class_disposition_meta.json', label);
end

function writeJson(path, text)
fid = fopen(path, 'w');
fprintf(fid, '%s', text);
fclose(fid);
end
