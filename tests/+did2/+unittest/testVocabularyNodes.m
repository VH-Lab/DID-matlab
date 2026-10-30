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
% derived_from ([derived from general], [derived from label], Jess Haley
% 2026-10-22): the schema row named derived_from wins while there is one
% ({RO:0001000, "derived_from"}); once the row is {prov:wasDerivedFrom,
% "wasDerivedFrom"} no row spells the handle and the table's node is used
want = boundNodeNamed(did2.schema.cache.shared(), 'directed_relation', 'relation', 'derived_from');
if isempty(want); want = 'prov:wasDerivedFrom'; end
verifyEqual(testCase, did2.build.vocabulary('relation', 'derived_from'), want);
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
    % a handle the schema spells as a row name resolves to THAT row's node
    % (vocabulary step 1), never to the table's: the table row is the
    % fallback for when the row's name changes (derived_from's table node
    % prov:wasDerivedFrom while the schema still binds RO:0001000). Its
    % effective node must be bound; the table's own node is checked only
    % when it is the one used.
    names = boundRowNames(c, s{1}, s{2});
    if strcmp(s{1}, 'directed_relation')
        names = [names, boundRowNames(c, 'undirected_relation', 'relation')];
    end
    norm = @(x) lower(regexprep(char(x), '[\s_\-]', ''));
    shadowed = ismember(cellfun(norm, h(:, 1), 'UniformOutput', false), ...
        cellfun(norm, names, 'UniformOutput', false));
    eff = cellfun(@(x) did2.build.vocabulary(s{3}, x), h(shadowed, 1), 'UniformOutput', false);
    nodes = unique([h(~shadowed, 2); eff(:)]);
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
did2.schema.cache.copySchemaSet(src, tmp);
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

function testANodeTheSchemaChangesIsFollowed(testCase)
% [derived from general], [derived from label] (Jess Haley 2026-10-22): the
% schema's derived_from row becomes {prov:wasDerivedFrom, "wasDerivedFrom"}
% (PROV-O's rdfs:label). Writers keep saying 'derived_from' and write the
% row's node and label; comparisons follow the node. Simulated on a copy.
flipDerivedFrom(testCase);
verifyEqual(testCase, did2.build.vocabulary('relation', 'derived_from'), 'prov:wasDerivedFrom');
rel = did2.build.directedRelation(did.ido.unique_id(), did.ido.unique_id(), 'derived_from', ...
    'SessionId', testCase.TestData.sid, 'Validate', false);
verifyEqual(testCase, rel.directed_relation.relation.node, 'prov:wasDerivedFrom');
verifyEqual(testCase, rel.directed_relation.relation.name, 'wasDerivedFrom');
verifyTrue(testCase, did2.build.isVocabulary(rel.directed_relation.relation, 'relation', 'derived_from'));
verifyFalse(testCase, did2.build.isVocabulary(struct('node', 'RO:0001000', 'name', 'derived_from'), ...
    'relation', 'derived_from'));
end

function testDerivedFromResolvesByTheTableWhenTheRowIsWasDerivedFrom(testCase)
% [derived from label]: "wasDerivedFrom" does not normalise to derived_from,
% so step 1 (the schema row by name) cannot find it; the handle table's row
% derived_from -> prov:wasDerivedFrom is what resolves it.
flipDerivedFrom(testCase);
c = did2.schema.cache.shared();
verifyEmpty(testCase, boundNodeNamed(c, 'directed_relation', 'relation', 'derived_from'), ...
    'the flipped copy must have no row spelling the handle, or this test proves nothing');
verifyEqual(testCase, boundNodeNamed(c, 'directed_relation', 'relation', 'wasDerivedFrom'), ...
    'prov:wasDerivedFrom');
[~, h] = did2.build.vocabulary('relation');
verifyEqual(testCase, h(strcmp(h(:, 1), 'derived_from'), 2), {'prov:wasDerivedFrom'});
verifyEqual(testCase, did2.build.vocabulary('relation', 'derived_from'), 'prov:wasDerivedFrom');
verifyEqual(testCase, did2.build.vocabulary('relation', 'wasDerivedFrom'), 'prov:wasDerivedFrom');
% a node-less name, either spelling, still matches by node
verifyTrue(testCase, did2.build.isVocabulary(struct('node', '', 'name', 'wasDerivedFrom'), ...
    'relation', 'derived_from'));
verifyTrue(testCase, did2.build.isVocabulary('derived_from', 'relation', 'derived_from'));
end

function testDerivedFromWritesTheCurrentRowWhileTheSchemaHasIt(testCase)
% did-schema flips the row AFTER this repository: while the loaded schema's
% row is still {RO:0001000, "derived_from"}, that row (step 1) wins over the
% table and a writer saying 'derived_from' writes it unchanged.
c = did2.schema.cache.shared();
cur = boundNodeNamed(c, 'directed_relation', 'relation', 'derived_from');
if isempty(cur)
    assumeFail(testCase, 'the loaded schema has no row named derived_from (flipped already)');
end
verifyEqual(testCase, did2.build.vocabulary('relation', 'derived_from'), cur);
rel = did2.build.directedRelation(did.ido.unique_id(), did.ido.unique_id(), 'derived_from', ...
    'SessionId', testCase.TestData.sid, 'Validate', false);
verifyEqual(testCase, rel.directed_relation.relation.node, cur);
verifyEqual(testCase, rel.directed_relation.relation.name, ...
    boundName(c, 'directed_relation', 'relation', cur));
verifyTrue(testCase, did2.build.isVocabulary(rel.directed_relation.relation, 'relation', 'derived_from'));
end

% ===================== helpers =============================================

function flipDerivedFrom(testCase)
% load a copy of the schema whose derived_from row is {prov:wasDerivedFrom,
% "wasDerivedFrom"}; a schema already flipped is used as it is
src = testCase.TestData.schemaPath;
tmp = tempname;
mkdir(tmp);
did2.schema.cache.copySchemaSet(src, tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
f = fullfile(tmp, 'directed_relation.json');
txt = fileread(f);
if contains(txt, '"RO:0001000"')
    txt = strrep(txt, '"RO:0001000"', '"prov:wasDerivedFrom"');
    txt = strrep(txt, '"name": "derived_from"', '"name": "wasDerivedFrom"');
elseif ~contains(txt, '"prov:wasDerivedFrom"')
    assumeFail(testCase, 'the loaded schema binds derived_from to neither RO:0001000 nor prov:wasDerivedFrom');
end
fid = fopen(f, 'w'); fwrite(fid, txt); fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
end

function names = boundRowNames(c, className, fieldName)
vals = boundValues(c, className, fieldName);
names = reshape(cellfun(@(v) char(v.name), vals, 'UniformOutput', false), 1, []);
end

function nodes = boundNodes(c, className, fieldName)
vals = boundValues(c, className, fieldName);
nodes = cellfun(@(v) char(v.node), vals, 'UniformOutput', false);
nodes = nodes(~cellfun(@isempty, nodes));
nodes = reshape(nodes, 1, []);
end

function node = boundNodeNamed(c, className, fieldName, name)
node = '';
vals = boundValues(c, className, fieldName);
norm = @(x) lower(regexprep(char(x), '[\s_\-]', ''));
for k = 1:numel(vals)
    if strcmp(norm(vals{k}.name), norm(name)); node = char(vals{k}.node); return; end
end
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
