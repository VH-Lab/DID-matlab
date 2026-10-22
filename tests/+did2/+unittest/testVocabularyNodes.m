function tests = testVocabularyNodes
%TESTVOCABULARYNODES Relations and entity types are matched BY NODE and written
%   with the schema's name (Jess Haley 2026-10-22 [vocabulary nodes] G6, L1,
%   L2; [registry holds nodes] S1): did2.build.vocabulary,
%   did2.build.isVocabulary, and the builder's completion of a bound term.
%
%   Run with:  results = runtests('did2.unittest.testVocabularyNodes');
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping vocabulary tests');
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
testCase.TestData.schemaPath = did2.schema.cache.shared().schemaPath;
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testHandlesHaveTheDecidedNodes(testCase)
verifyEqual(testCase, did2.build.vocabulary('relation', 'member_of'), 'RO:0002350');
verifyEqual(testCase, did2.build.vocabulary('relation', 'member of'), 'RO:0002350');
verifyEqual(testCase, did2.build.vocabulary('relation', 'contained_in'), 'RO:0001025');   % K1
verifyEqual(testCase, did2.build.vocabulary('relation', 'sample_of'), 'ENVO:01003004');   % K5
verifyEqual(testCase, did2.build.vocabulary('relation', 'derived_from'), 'RO:0001000');   % K2
verifyEqual(testCase, did2.build.vocabulary('entity_type', 'epoch'), 'EMPTY:0000383');    % L3
verifyEqual(testCase, did2.build.vocabulary('entity_type', 'Data Set'), 'NCIT:C47824');
verifyEqual(testCase, did2.build.vocabulary('entity_type', 'culture'), '');               % no node
% the retired relations have no node ([vocabulary nodes] K5, A1, G5)
for r = {'recorded_by', 'measured_distance_to', 'aliquot_of', 'passage_of'}
    verifyEqual(testCase, did2.build.vocabulary('relation', r{1}), '', r{1});
end
end

function testEveryNodeIsInTheSchemasBoundSet(testCase)
% the code's map names only nodes the loaded schema binds (by node), so a
% writer's handle always finds its row
c = did2.schema.cache.shared();
for spec = {{'directed_relation', 'relation', 'relation'}, {'entity', 'type', 'entity_type'}}
    s = spec{1};
    bound = boundNodes(c, s{1}, s{2});
    if isempty(bound)
        assumeFail(testCase, sprintf('the loaded schema binds %s.%s to no nodes', s{1}, s{2}));
    end
    [~, h] = did2.build.vocabulary(s{3});
    nodes = unique(h(:, 2));
    if strcmp(s{1}, 'directed_relation')
        und = boundNodes(c, 'undirected_relation', 'relation');
        bound = [bound, und];
    end
    missing = setdiff(lower(nodes), lower(bound));
    verifyEmpty(testCase, missing, sprintf('%s nodes the schema does not bind', s{3}));
end
end

function testIsVocabularyMatchesByNode(testCase)
verifyTrue(testCase, did2.build.isVocabulary(struct('node', 'RO:0002350', 'name', 'member of'), ...
    'relation', 'member_of'));
% a node decides even when the name says something else
verifyFalse(testCase, did2.build.isVocabulary(struct('node', 'BFO:0000050', 'name', 'member_of'), ...
    'relation', 'member_of'));
% a node-less term from an older writer: by its name
verifyTrue(testCase, did2.build.isVocabulary(struct('node', '', 'name', 'member_of'), ...
    'relation', 'member_of'));
verifyTrue(testCase, did2.build.isVocabulary(struct('node', 'EMPTY:0000383', 'name', 'recording epoch'), ...
    'entity_type', 'epoch'));
verifyTrue(testCase, did2.build.isVocabulary(struct('node', 'empty:0000383', 'name', 'epoch'), ...
    'entity_type', 'epoch'));   % prefix case ignored
end

function testTheBuilderWritesTheSchemasNodeAndName(testCase)
sid = testCase.TestData.sid;
rel = did2.build.directedRelation(did.ido.unique_id(), did.ido.unique_id(), 'member_of', ...
    'SessionId', sid);
verifyEqual(testCase, rel.directed_relation.relation.node, 'RO:0002350');
% a node alone takes the schema's name
rel = did2.build.directedRelation(did.ido.unique_id(), did.ido.unique_id(), ...
    struct('node', 'RO:0002350', 'name', ''), 'SessionId', sid);
verifyEqual(testCase, rel.directed_relation.relation.node, 'RO:0002350');
verifyEqual(testCase, rel.directed_relation.relation.name, ...
    boundName(did2.schema.cache.shared(), 'directed_relation', 'relation', 'RO:0002350'));
ent = did2.build.document('entity', struct('type', did2.build.term('', 'epoch'), ...
    'local_identifier', 'e1'), 'SessionId', sid);
verifyEqual(testCase, ent.entity.type.node, 'EMPTY:0000383');
end

function testAHandleStillFindsItsRowWhenTheSchemaStoresTheLabel(testCase)
% [vocabulary nodes] L1: the schema's rows will store the ontology label
% ("member of"); a writer that says 'member_of' must still write the row's
% node and, now, its label. Simulated on a copy of the schema.
src = testCase.TestData.schemaPath;
tmp = tempname;
mkdir(tmp);
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
f = fullfile(tmp, 'directed_relation.json');
txt = fileread(f);
txt = strrep(txt, '"name": "member_of"', '"name": "member of"');
fid = fopen(f, 'w'); fwrite(fid, txt); fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
rel = did2.build.directedRelation(did.ido.unique_id(), did.ido.unique_id(), 'member_of', ...
    'SessionId', testCase.TestData.sid);
verifyEqual(testCase, rel.directed_relation.relation.node, 'RO:0002350');
verifyEqual(testCase, rel.directed_relation.relation.name, 'member of');
end

% ===================== helpers =============================================

function nodes = boundNodes(c, className, fieldName)
vals = boundValues(c, className, fieldName);
nodes = cellfun(@(v) char(v.node), vals, 'UniformOutput', false);
nodes = nodes(~cellfun(@isempty, nodes));
nodes = reshape(nodes, 1, []);
end

function name = boundName(c, className, fieldName, node)
name = '';
vals = boundValues(c, className, fieldName);
for k = 1:numel(vals)
    if strcmpi(char(vals{k}.node), node); name = char(vals{k}.name); return; end
end
end

function vals = boundValues(c, className, fieldName)
vals = {};
s = c.getClass(className);
f = s.fields;
if isstruct(f); f = num2cell(f); end
hit = f(cellfun(@(d) strcmp(char(d.name), fieldName), f));
if isempty(hit) || ~isfield(hit{1}, 'constraints') || ~isfield(hit{1}.constraints, 'binding') ...
        || ~isfield(hit{1}.constraints.binding, 'values')
    return;
end
vals = hit{1}.constraints.binding.values;
if isstruct(vals); vals = num2cell(vals); end
end
