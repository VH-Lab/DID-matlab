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
% UPDATED for did-schema #88. This batch pass existed to supply the session
% DOCUMENT id a single-document migrator could not resolve. On #88 the session
% entity's id IS the session id and `session_id` is base.session_id as an edge,
% so pass 1 already folds the graph; the pass then finds no syncgraph left and
% refuses nothing. The policy is asserted as pass 1 left it.
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A')});
verifyEqual(testCase, countOf(result, 'syncgraph'), 0);
verifyEqual(testCase, countOf(result, 'clock_alignment_policy'), 1);
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncgraphs_seen, 0);
verifyEqual(testCase, rep.policies_folded, 0);
verifyEqual(testCase, rep.refused_total, 0);
policy = firstOf(out, 'clock_alignment_policy');
verifyEqual(testCase, policy.get('base.id'), 'graph_1');
verifyEqual(testCase, depValue(policy, 'session_id'), ...
    did2.unittest.helpers.sessionDocumentId('sessdoc_A', 'sess_A'));
verifyEqual(testCase, depValue(policy, 'clock_alignment_configuration_id'), 'rule_1');
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
% UPDATED for #88: the session edge names the session ENTITY by the session id
% itself, so no session document has to be found -- pass 1 folds the graph and
% nothing is filled empty (the edge carries sess_MISSING, the id the source
% names; in a full migration the session entity of that id is in the batch).
result = migrate({syncgraphFixture('graph_1', {'rule_1'}, 'sess_MISSING')});
verifyEqual(testCase, countOf(result, 'clock_alignment_policy'), 1);
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncgraphs_seen, 0);
verifyEqual(testCase, rep.refused_no_session_document, 0);
policy = firstOf(out, 'clock_alignment_policy');
verifyEqual(testCase, depValue(policy, 'session_id'), 'sess_MISSING');
end


function testTwoSessionDocumentsClaimingOneIdAreRefusedAmbiguous(testCase)
% UPDATED for #88: there is no session-document lookup left to be ambiguous --
% the graph folds in pass 1 and the pass refuses nothing.
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A'), ...
    sessionDocFixture('sessdoc_B', 'sess_A')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.refused_ambiguous_session, 0);
verifyEqual(testCase, countOf(out, 'syncgraph'), 0);
verifyEqual(testCase, countOf(out, 'clock_alignment_policy'), 1);
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
% A non-V_eta target leaves the batch exactly as it came in. UPDATED for #88:
% compared against the input rather than a syncgraph count (pass 1 now folds).
result = migrate({ ...
    syncgraphFixture('graph_1', {'rule_1'}, 'sess_A'), ...
    sessionDocFixture('sessdoc_A', 'sess_A')});
out = did2.convert.resolveClockAlignment(result, 'TargetVersion', 'V_delta');
verifyEqual(testCase, numel(out.migrated), numel(result.migrated));
verifyEqual(testCase, countOf(out, 'clock_alignment_policy'), countOf(result, 'clock_alignment_policy'));
verifyEqual(testCase, countOf(out, 'syncgraph'), countOf(result, 'syncgraph'));
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
