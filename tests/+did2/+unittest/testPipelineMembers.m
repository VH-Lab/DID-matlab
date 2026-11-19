function tests = testPipelineMembers
%TESTPIPELINEMEMBERS A pipeline is a `software` entity whose programs are its
%   ordered `member of` members, counted from 0 (did-schema
%   did_v2_go_forward_class_audit.md: [pipeline is a software entity], Jess
%   Haley 2026-11-06; [pipeline order counts from 0] and [pipeline steps use
%   member of], Jess Haley 2026-11-12).
%
%   did2.build.pipelineMembership builds the relations, did2.build.
%   checkPipelineMembers checks a pipeline against its relations and
%   programs, and did2.validate.pipelineMembers counts the rule over a batch.
%   Every document here is built by did2.build and validated against the
%   loaded schema, so the builders accept a `member of` with a software
%   parent (did-schema main 3d1aae9+, the binding row's parent_types).
%
%   Run with:  results = runtests('did2.unittest.testPipelineMembers');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping pipeline tests');
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ---------------------------------------------------------------- builds

function testKilosortPipelineBuildsAndPasses(testCase)
% The decision's example: Kilosort 0, Phy 1, the NDI importer 2.
[pipe, progs, rels] = kilosortPipeline(testCase);
verifyEqual(testCase, numel(rels), 3);
for k = 1:3
    r = rels{k};
    verifyEqual(testCase, r.directed_relation.order, k - 1);
    verifyEqual(testCase, lower(r.directed_relation.relation.node), 'ro:0002350');
    verifyEqual(testCase, edge(r, 'child_id'), progs{k}.base.id);
    verifyEqual(testCase, edge(r, 'parent_id'), pipe.base.id);
end
did2.build.checkPipelineMembers(pipe, [progs, rels]);   % no error
rep = did2.validate.pipelineMembers([{pipe}, progs, rels]);
verifyEqual(testCase, rep.docs_inspected, 7);
verifyEqual(testCase, rep.member_of_relations, 3);
verifyEqual(testCase, rep.software_parent_relations, 3);
verifyEqual(testCase, rep.pipelines_inspected, 1);
verifyEqual(testCase, rep.pipelines_checked, 1);
verifyEqual(testCase, rep.violations, 0);
end

function testOneProgramIsAnOrdinarySoftwareEntity(testCase)
% "A one-program statement points at the program directly": a software
% entity no `member of` points at has nothing to check.
prog = entity(testCase, 'software', 'Kilosort', 'Kilosort@2.5');
did2.build.checkPipelineMembers(prog, {prog});
rep = did2.validate.pipelineMembers({prog});
verifyEqual(testCase, rep.docs_inspected, 1);
verifyEqual(testCase, rep.member_of_relations, 0);
verifyEqual(testCase, rep.pipelines_inspected, 0);
verifyEqual(testCase, rep.violations, 0);
end

% --------------------------------------------------------------- refusals

function testOrderFromOneIsRefused(testCase)
% "step 1 = Kilosort" was read as "the first step": positions are 0-based
[pipe, progs] = pipelineAndPrograms(testCase, 3);
rels = manual(testCase, pipe, progs, [1 2 3]);
verifyError(testCase, @() did2.build.checkPipelineMembers(pipe, [progs, rels]), ...
    'did2:build:ruleViolated');
rep = did2.validate.pipelineMembers([{pipe}, progs, rels]);
verifyEqual(testCase, rep.pipelines_checked, 1);
verifyEqual(testCase, rep.violations, 1);
verifyEqual(testCase, rep.violation_examples(1).id, pipe.base.id);
end

function testGapIsRefused(testCase)
[pipe, progs] = pipelineAndPrograms(testCase, 3);
rels = manual(testCase, pipe, progs, [0 1 3]);
verifyError(testCase, @() did2.build.checkPipelineMembers(pipe, [progs, rels]), ...
    'did2:build:ruleViolated');
end

function testRepeatedOrderIsRefused(testCase)
[pipe, progs] = pipelineAndPrograms(testCase, 2);
rels = manual(testCase, pipe, progs, [0 0]);
verifyError(testCase, @() did2.build.checkPipelineMembers(pipe, [progs, rels]), ...
    'did2:build:ruleViolated');
end

function testUnorderedMemberIsRefused(testCase)
% -1, the blank `order`, is "unordered"; a pipeline's programs have an order
[pipe, progs] = pipelineAndPrograms(testCase, 2);
rels = manual(testCase, pipe, progs, [0 NaN]);
verifyEqual(testCase, rels{2}.directed_relation.order, -1);
verifyError(testCase, @() did2.build.checkPipelineMembers(pipe, [progs, rels]), ...
    'did2:build:ruleViolated');
rep = did2.validate.pipelineMembers([{pipe}, progs, rels]);
verifyEqual(testCase, rep.violations, 1);
end

function testNonSoftwareMemberIsRefused(testCase)
pipe = entity(testCase, 'software', 'sort pipeline', 'sort pipeline');
worm = entity(testCase, 'organism', 'worm 1', 'worm 1');
rels = did2.build.pipelineMembership(pipe.base.id, {worm.base.id}, ...
    'SessionId', testCase.TestData.sid);
verifyError(testCase, @() did2.build.checkPipelineMembers(pipe, [{worm}, rels]), ...
    'did2:build:ruleViolated');
rep = did2.validate.pipelineMembers([{pipe, worm}, rels]);
verifyEqual(testCase, rep.violations, 1);
end

function testMemberNotGivenIsNotChecked(testCase)
% the builder check refuses what it cannot see; the batch census says NOT
% CHECKED rather than pass or fail
[pipe, progs, rels] = kilosortPipeline(testCase);
verifyError(testCase, @() did2.build.checkPipelineMembers(pipe, [progs(1:2), rels]), ...
    'did2:build:ruleViolated');
rep = did2.validate.pipelineMembers([{pipe}, progs(1:2), rels]);
verifyEqual(testCase, rep.pipelines_inspected, 1);
verifyEqual(testCase, rep.pipelines_child_not_in_batch, 1);
verifyEqual(testCase, rep.pipelines_checked, 0);
verifyEqual(testCase, rep.violations, 0);
% the pipeline itself absent: its relations are counted, not checked
rep = did2.validate.pipelineMembers([progs, rels]);
verifyEqual(testCase, rep.member_of_relations, 3);
verifyEqual(testCase, rep.parent_not_in_batch, 3);
verifyEqual(testCase, rep.pipelines_inspected, 0);
end

function testGroupParentIsNotThisRule(testCase)
% a Group's members (T20) may be unordered: the rule is for software parents
grp = entity(testCase, 'Group', '', 'cohort A');
a = entity(testCase, 'organism', '', 'worm a');
b = entity(testCase, 'organism', '', 'worm b');
member = did2.build.term(did2.build.vocabulary('relation', 'member_of'), 'member of');
r1 = did2.build.directedRelation(a.base.id, grp.base.id, member, 'SessionId', testCase.TestData.sid);
r2 = did2.build.directedRelation(b.base.id, grp.base.id, member, 'SessionId', testCase.TestData.sid);
rep = did2.validate.pipelineMembers({grp, a, b, r1, r2});
verifyEqual(testCase, rep.member_of_relations, 2);
verifyEqual(testCase, rep.other_parent_relations, 2);
verifyEqual(testCase, rep.pipelines_inspected, 0);
verifyEqual(testCase, rep.violations, 0);
verifyError(testCase, @() did2.build.checkPipelineMembers(grp, {a, b, r1, r2}), ...
    'did2:build:badOption');
end

function testPipelineMembershipRefusesBadPrograms(testCase)
sid = testCase.TestData.sid;
p = did.ido.unique_id(); x = did.ido.unique_id();
verifyError(testCase, @() did2.build.pipelineMembership(p, {}, 'SessionId', sid), ...
    'did2:build:badOption');
verifyError(testCase, @() did2.build.pipelineMembership(p, {x, x}, 'SessionId', sid), ...
    'did2:build:badOption');
verifyError(testCase, @() did2.build.pipelineMembership(p, {x, p}, 'SessionId', sid), ...
    'did2:build:badOption');
end

% ---------------------------------------------------------------- helpers

function [pipe, progs, rels] = kilosortPipeline(testCase)
pipe = entity(testCase, 'software', 'Kilosort to Phy to NDI', '');
progs = {entity(testCase, 'software', 'Kilosort', 'Kilosort@2.5'), ...
         entity(testCase, 'software', 'Phy', 'Phy'), ...
         entity(testCase, 'software', 'ndi.fun.probe.import.kilosort', 'ndi.fun.probe.import.kilosort')};
rels = did2.build.pipelineMembership(pipe.base.id, ...
    cellfun(@(e) e.base.id, progs, 'UniformOutput', false), ...
    'SessionId', testCase.TestData.sid);
end

function [pipe, progs] = pipelineAndPrograms(testCase, n)
pipe = entity(testCase, 'software', 'a pipeline', '');
progs = cell(1, n);
for k = 1:n
    progs{k} = entity(testCase, 'software', sprintf('program %d', k), '');
end
end

function rels = manual(testCase, pipe, progs, orders)
% relations built one by one, so a wrong order can be written; NaN = unordered
member = did2.build.term(did2.build.vocabulary('relation', 'member_of'), 'member of');
rels = cell(1, numel(progs));
for k = 1:numel(progs)
    if isnan(orders(k))
        rels{k} = did2.build.directedRelation(progs{k}.base.id, pipe.base.id, member, ...
            'SessionId', testCase.TestData.sid);
    else
        rels{k} = did2.build.directedRelation(progs{k}.base.id, pipe.base.id, member, ...
            'Order', orders(k), 'SessionId', testCase.TestData.sid);
    end
end
end

function e = entity(testCase, type, name, localId)
node = did2.build.vocabulary('entity_type', type);
f = struct('type', did2.build.term(node, type));
if ~isempty(name); f.name = name; end
if isempty(localId); localId = name; end
f.local_identifier = localId;
e = did2.build.document('entity', f, 'SessionId', testCase.TestData.sid);
end

function v = edge(doc, name)
names = {doc.depends_on.name};
v = doc.depends_on(strcmp(names, name)).document_id;
end
