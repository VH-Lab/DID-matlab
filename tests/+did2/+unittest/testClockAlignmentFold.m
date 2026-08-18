function tests = testClockAlignmentFold
%TESTCLOCKALIGNMENTFOLD The #57 syncgraph batch pass: did2.convert.resolveClockAlignment.
%
%   The pass that un-gates `syncgraph` -> `clock_alignment_policy`. A single-
%   document migrator cannot fill `clock_alignment_policy.session_id` because it
%   names the session DOCUMENT's base.id -- a corpus-wide lookup -- so pass 1
%   passes the syncgraph through and THIS pass supplies the id and re-runs the
%   migrator. Structural sibling of resolveSessionAnchors; same session index,
%   same refuse-don't-invent discipline, same base.id-preserving swap.
%
%   Driven through did2.convert.v1_to_v2 to build the migrated set exactly as a
%   real run does (a syncgraph passes through, a session document persists), then
%   resolveClockAlignment over the result. NOT VERIFIED BY EXECUTION: no MATLAB
%   in the authoring container.
%
%   Run with:  results = runtests('did2.unittest.testClockAlignmentFold');

tests = functiontests(localfunctions);
end

% ===================== the fold ============================================

function testSyncgraphFoldsToPolicyWhenTheSessionResolves(testCase)
% The headline. A syncgraph whose base.session_id matches a session document in
% the batch folds to a clock_alignment_policy anchored to that document's id.
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A')});
% Pass 1 leaves the syncgraph a passthrough.
verifyEqual(testCase, countOf(result, 'syncgraph'), 1);
verifyEqual(testCase, countOf(result, 'clock_alignment_policy'), 0);

out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;

verifyEqual(testCase, rep.syncgraphs_seen, 1);
verifyEqual(testCase, rep.policies_folded, 1);
verifyEqual(testCase, rep.refused_total, 0);
% The syncgraph is gone; a clock_alignment_policy stands in its place.
verifyEqual(testCase, countOf(out, 'syncgraph'), 0);
verifyEqual(testCase, countOf(out, 'clock_alignment_policy'), 1);

policy = firstOf(out, 'clock_alignment_policy');
% base.id PRESERVED -- syncrule_mapping's syncgraph_id edge still resolves.
verifyEqual(testCase, policy.get('base.id'), 'graph_1');
% session_id names the session DOCUMENT's base.id, not the base.session_id.
verifyEqual(testCase, depValue(policy, 'session_id'), 'sessdoc_A');
% the rule membership survives as a clock_alignment_configuration_# family.
verifyEqual(testCase, depValue(policy, 'clock_alignment_configuration_1'), 'rule_1');
end

function testTheStampDoesNotPersistOntoThePolicy(testCase)
% The seam is a transient `session_document_id` dep the migrator reads and
% discards -- the policy sets its session_id BY NAME. If the stamp leaked onto
% the emitted policy it would be an undeclared edge and quarantine.
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
policy = firstOf(out, 'clock_alignment_policy');
verifyEmpty(testCase, depValue(policy, 'session_document_id'));
end

% ===================== refusal, not invention ==============================

function testNoSessionDocumentIsRefusedNotFilledEmpty(testCase)
% A syncgraph whose session id names no session document in the batch is LEFT
% as a passthrough -- never a clock_alignment_policy with an empty required
% session edge (the invented-empty-edge pattern).
result = migrate({syncgraphFixture('graph_1', {'rule_1'}, 'sess_MISSING')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncgraphs_seen, 1);
verifyEqual(testCase, rep.refused_no_session_document, 1);
verifyEqual(testCase, rep.policies_folded, 0);
verifyEqual(testCase, countOf(out, 'syncgraph'), 1);
verifyEqual(testCase, countOf(out, 'clock_alignment_policy'), 0);
end

function testTwoSessionDocumentsClaimingOneIdAreRefusedAmbiguous(testCase)
% Guessing which session a syncgraph belongs to when two documents claim the id
% would be inventing a fact; refuse and keep the passthrough.
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A'), ...
    sessionDocFixture('sessdoc_B', 'sess_A')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.refused_ambiguous_session, 1);
verifyEqual(testCase, rep.policies_folded, 0);
verifyEqual(testCase, countOf(out, 'syncgraph'), 1);
end

function testAnEmptySessionSentinelIsRefused(testCase)
% ndi.session.empty_id() ("applies in any session") is not a real session; a
% syncgraph carrying it must not resolve to a document.
result = migrate({syncgraphFixture('graph_1', {'rule_1'}, ...
    '0000000000000000_0000000000000000')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
% Either the migrator's own sentinel guard declines, or no session document
% claims the sentinel id -- both are refusals, neither is a fold.
verifyEqual(testCase, rep.policies_folded, 0);
verifyEqual(testCase, countOf(out, 'syncgraph'), 1);
end

% ===================== the denominator is reported =========================

function testAnEmptyBatchRunsAndReportsZero(testCase)
% A pass over nothing must report ran=true with a zero denominator, not skip
% silently -- the silentLoss discipline.
result = struct('migrated', {{}}, 'summary', struct('total', 0));
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
verifyTrue(testCase, out.clock_alignment_fold.ran);
verifyEqual(testCase, out.clock_alignment_fold.syncgraphs_seen, 0);
end

function testNonEtaTargetIsUntouched(testCase)
% `clock_alignment_policy` exists only in V_eta; another target is a no-op.
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A')});
out = did2.convert.resolveClockAlignment(result, 'TargetVersion', 'V_zeta');
verifyEqual(testCase, countOf(out, 'syncgraph'), 1);
verifyEqual(testCase, countOf(out, 'clock_alignment_policy'), 0);
end

% ===================== fixtures & helpers ==================================

function result = migrate(fixtures)
result = did2.convert.v1_to_v2(fixtures, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v1 = syncgraphFixture(id, ruleIds, sessionId)
%SYNCGRAPHFIXTURE A did_v1 syncgraph: base.session_id is the REAL session, each
%   rule attached as syncrule_id_1, syncrule_id_2, ... (add_dependency_value_n).
v1 = struct();
v1.document_class = struct('class_name', 'syncgraph', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
deps = struct('name', {}, 'value', {});
for k = 1:numel(ruleIds)
    deps(end+1) = struct('name', sprintf('syncrule_id_%d', k), ...
        'value', ruleIds{k}); %#ok<AGROW>
end
v1.depends_on = deps;
v1.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'the_syncgraph', 'datestamp', '2024-01-01T00:00:00.000Z');
v1.syncgraph = struct('ndi_syncgraph_class', 'ndi.time.syncgraph');
end

function v1 = sessionDocFixture(id, sessionId)
%SESSIONDOCFIXTURE A did_v1 `session` document. Its base.id is a fresh ido and
%   its base.session_id is the session identity its siblings carry -- the two
%   are DIFFERENT strings, which is the whole reason the fold needs an index.
v1 = struct();
v1.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'a_session', 'datestamp', '2024-01-01T00:00:00.000Z');
v1.session = struct('reference', 'exp1');
end

function n = countOf(result, className)
n = 0;
for k = 1:numel(result.migrated)
    if strcmp(result.migrated{k}.get('document_class.class_name'), className)
        n = n + 1;
    end
end
end

function doc = firstOf(result, className)
doc = [];
for k = 1:numel(result.migrated)
    if strcmp(result.migrated{k}.get('document_class.class_name'), className)
        doc = result.migrated{k};
        return;
    end
end
end

function v = depValue(doc, name)
v = '';
deps = doc.get('depends_on');
for k = 1:numel(deps)
    if ~strcmp(deps(k).name, name); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v = char(deps(k).value);
    end
    return;
end
end
