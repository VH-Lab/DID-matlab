function tests = testSessionIdEdge
%TESTSESSIONIDEDGE `base.session_id` as a field or as the `session_id` edge.
%
%   did-schema V_eta_relation_inheritance_plan.md (2026-10-20, built ahead of
%   signature): `base` lost its `session_id` FIELD and gained one required
%   depends_on EDGE, `session_id`, to the session or dataset entity a document
%   is stored with; that entity's base.id IS its session id. The same change
%   gave record membership its own relation, `included_in` (schema:isPartOf).
%   did-schema `main` and the pinned v_eta-pre73 keep the field, so every
%   writer asks the loaded schema (did2.schema.cache/sessionIdIsEdge).
%
%   BOTH SHAPES ARE TESTED HERE WHATEVER DID_SCHEMA_PATH SAYS: each test points
%   the schema cache at a throwaway directory holding one `base.json` of the
%   shape it wants. Nothing else is in the directory, so the documents run with
%   Validate=false and the tests pin the TRANSFORM (did2.convert.v1_to_v2's
%   outbound move, the session re-id, the membership relation), not the schema.
%   The real schema's half is pinned by testBuild (the builder writes valid
%   documents on whichever schema test-builder.yml loads) and by the fixture
%   corpus.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment).
%
%   Run with:  results = runtests('did2.unittest.testSessionIdEdge');

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
useShape(testCase, 'edge');
verifyTrue(testCase, did2.schema.cache.shared().sessionIdIsEdge());
useShape(testCase, 'field');
verifyFalse(testCase, did2.schema.cache.shared().sessionIdIsEdge());
end

% ---- did2.schema.cache.sessionIdOf --------------------------------------------------

function testSessionIdOfReadsTheFieldFirstThenTheEdge(testCase)
both = struct('base', struct('id', 'd', 'session_id', 'from_field'), ...
    'depends_on', struct('name', 'session_id', 'document_id', 'from_edge'));
verifyEqual(testCase, did2.schema.cache.sessionIdOf(both), 'from_field');
% a body that HAS the field answers from it even blank: on the field shape an
% epoch's own `session_id` edge names the session DOCUMENT, a different id
blank = both;
blank.base.session_id = '';
verifyEqual(testCase, did2.schema.cache.sessionIdOf(blank), '');
edgeOnly = struct('base', struct('id', 'd'), ...
    'depends_on', struct('name', {'other_id', 'session_id'}, 'document_id', {'o', 'e1'}));
verifyEqual(testCase, did2.schema.cache.sessionIdOf(edgeOnly), 'e1');
% a raw migrator body spells the target `value`, and a cell of entries occurs
asValue = struct('base', struct('id', 'd'), ...
    'depends_on', {{struct('name', 'session_id', 'value', 'e2')}});
verifyEqual(testCase, did2.schema.cache.sessionIdOf(asValue), 'e2');
verifyEqual(testCase, did2.schema.cache.sessionIdOf(struct('base', struct('id', 'd'))), '');
verifyEqual(testCase, did2.schema.cache.sessionIdOf(did2.document(edgeOnly)), 'e1');
end

% ---- did2.convert.v1_to_v2: the field moves onto the edge on the way out ---------

function testOnTheEdgeShapeTheFieldBecomesTheEdge(testCase)
useShape(testCase, 'edge');
out = runJ(passthroughV1('sess_A', struct('name', 'thing_id', 'value', 't1')));
did2.unittest.helpers.dumpJ('testOnTheEdgeShapeTheFieldBecomesTheEdge', 'out', out);
assertEqual(testCase, numel(out.migrated), 1, 'nothing emitted');
s = out.migrated{1}.toStruct();
verifyFalse(testCase, isfield(s.base, 'session_id'), ...
    'base.session_id survived beside the session_id edge');
verifyEqual(testCase, edgeTargets(s, 'session_id'), {'sess_A'});
verifyEqual(testCase, edgeTargets(s, 'thing_id'), {'t1'}, ...
    'the document''s other edges must be carried unchanged');
verifyEqual(testCase, out.migrated{1}.get('base.session_id'), 'sess_A', ...
    'did2.document.get answers base.session_id from the edge');
end

function testOnTheFieldShapeNothingMoves(testCase)
useShape(testCase, 'field');
out = runJ(passthroughV1('sess_A', struct('name', 'thing_id', 'value', 't1')));
did2.unittest.helpers.dumpJ('testOnTheFieldShapeNothingMoves', 'out', out);
assertEqual(testCase, numel(out.migrated), 1, 'nothing emitted');
s = out.migrated{1}.toStruct();
verifyEqual(testCase, s.base.session_id, 'sess_A');
verifyEmpty(testCase, edgeTargets(s, 'session_id'));
end

function testAStaleSessionEdgeIsReplacedNotDoubled(testCase)
% an epoch minted by did2.convert.epochMint carries a session_id edge naming the
% session document; the field is the authority and there is one edge after
useShape(testCase, 'edge');
out = runJ(passthroughV1('sess_A', struct('name', 'session_id', 'value', 'stale')));
did2.unittest.helpers.dumpJ('testAStaleSessionEdgeIsReplacedNotDoubled', 'out', out);
s = out.migrated{1}.toStruct();
verifyEqual(testCase, edgeTargets(s, 'session_id'), {'sess_A'});
end

function testAMovedDocumentPassesThroughAgainUnchanged(testCase)
% the batch passes send their bodies back through v1_to_v2: a body already on
% the edge shape must come out as it went in
useShape(testCase, 'edge');
first = runJ(passthroughV1('sess_A', struct('name', 'thing_id', 'value', 't1')));
did2.unittest.helpers.dumpJ('testAMovedDocumentPassesThroughAgainUnchanged', 'first', first);
again = runJ(first.migrated{1}.toStruct());
did2.unittest.helpers.dumpJ('testAMovedDocumentPassesThroughAgainUnchanged', 'again', again);
assertEqual(testCase, numel(again.migrated), 1, 'nothing emitted on the second pass');
s = again.migrated{1}.toStruct();
verifyFalse(testCase, isfield(s.base, 'session_id'));
verifyEqual(testCase, edgeTargets(s, 'session_id'), {'sess_A'});
end

function testVDeltaKeepsTheField(testCase)
useShape(testCase, 'edge');
out = did2.convert.v1_to_v2(passthroughV1('sess_A', struct('name', {}, 'value', {})), ...
    'Validate', false);
did2.unittest.helpers.dumpJ('testVDeltaKeepsTheField', 'out', out);
s = out.migrated{1}.toStruct();
verifyEqual(testCase, s.base.session_id, 'sess_A');
end

% ---- the session entity takes its session id as its id ------------------------

function testTheSessionIsReIdOnlyOnTheEdgeShape(testCase)
useShape(testCase, 'edge');
s = runJ(sessionV1()).migrated{1}.toStruct();
did2.unittest.helpers.dumpJ('testTheSessionIsReIdOnlyOnTheEdgeShape', 's', s);
verifyEqual(testCase, s.base.id, 'sess_09');
verifyEqual(testCase, edgeTargets(s, 'session_id'), {'sess_09'}, ...
    'the session entity points at itself');
useShape(testCase, 'field');
s = runJ(sessionV1()).migrated{1}.toStruct();
did2.unittest.helpers.dumpJ('testTheSessionIsReIdOnlyOnTheEdgeShape', 's', s);
verifyEqual(testCase, s.base.id, 'sess_doc_1');
verifyEqual(testCase, s.base.session_id, 'sess_09');
end

% ---- record membership: included_in, not part_of -----------------------------

function testMembershipIsIncludedInOnTheEdgeShape(testCase)
useShape(testCase, 'edge');
rel = membershipRelation(runJ(sessionInADatasetV1()));
did2.unittest.helpers.dumpJ('testMembershipIsIncludedInOnTheEdgeShape', 'rel', rel);
verifyEqual(testCase, rel.directed_relation.relation.name, 'included_in');
verifyEqual(testCase, rel.directed_relation.relation.node, 'schema:isPartOf');
% the relation is a dataset-level document: its edge names the dataset entity
verifyEqual(testCase, edgeTargets(rel, 'session_id'), {'dsid_1'});
end

function testMembershipIsPartOfOnTheFieldShape(testCase)
useShape(testCase, 'field');
rel = membershipRelation(runJ(sessionInADatasetV1()));
did2.unittest.helpers.dumpJ('testMembershipIsPartOfOnTheFieldShape', 'rel', rel);
verifyEqual(testCase, rel.directed_relation.relation.name, 'part_of');
end

% ===================== helpers =================================================

function useShape(testCase, shape)
% Point the shared schema cache at a throwaway directory whose only schema is a
% `base` declaring session_id as SHAPE ('edge' or 'field').
arguments
    testCase
    shape {mustBeMember(shape, {'edge', 'field'})}
end
dirPath = tempname();
mkdir(dirPath);
testCase.TestData.dirs{end+1} = dirPath;
base = struct();
base.document_class = struct('class_name', 'base', 'class_version', '1.0.0', ...
    'superclasses', {{}}, 'maturity_level', 'stable');
idField = struct('name', 'id', 'type', 'did_uid', 'mustBeNonEmpty', true);
if strcmp(shape, 'edge')
    base.depends_on = {struct('name', 'session_id', 'mustBeNonEmpty', true, ...
        'must_refer_to_document_class', 'entity')};
    base.fields = {idField};
else
    base.depends_on = {};
    base.fields = {idField, struct('name', 'session_id', 'type', 'did_uid', ...
        'mustBeNonEmpty', true)};
end
base.file = {};
fid = fopen(fullfile(dirPath, 'base.json'), 'w');
fwrite(fid, jsonencode(base));
fclose(fid);
did2.schema.cache.setSchemaPath(dirPath);
end

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v1 = passthroughV1(sessionId, deps)
% a class no migrator is named for: v1_to_v2 passes it through, so what comes
% out is the pipeline's own outbound handling and nothing else
v1 = struct();
v1.document_class = struct('class_name', 'session_id_probe', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = deps;
v1.base = struct('id', 'probe_1', 'session_id', sessionId, ...
    'name', 'probe', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session_id_probe = struct('value', 1);
end

function v1 = sessionV1()
v1 = struct();
v1.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.base = struct('id', 'sess_doc_1', 'session_id', 'sess_09', ...
    'name', 'ts_2024', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session = struct('reference', 'ts_2024');
end

function v1 = sessionInADatasetV1()
v1 = struct();
v1.document_class = struct('class_name', 'session_in_a_dataset', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'sid_01', 'session_id', 'dsid_1', ...
    'name', 'sid', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session_in_a_dataset = struct('session_id', 'member_sess_9', ...
    'session_reference', 'exp_demo', 'is_linked', 0);
end

function rel = membershipRelation(out)
rel = [];
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    if strcmp(s.document_class.class_name, 'directed_relation')
        rel = s;
        return;
    end
end
error('testSessionIdEdge:noRelation', 'no directed_relation was emitted');
end

function ids = edgeTargets(s, name)
% the targets of every depends_on entry called NAME, under any key spelling
ids = {};
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
deps = s.depends_on;
for k = 1:numel(deps)
    if iscell(deps)
        d = deps{k};
    else
        d = deps(k);
    end
    if ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            ids{end+1} = char(d.(key{1})); %#ok<AGROW>
            break;
        end
    end
end
end
