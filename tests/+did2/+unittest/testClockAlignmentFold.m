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

function testANonEtaTargetIsRefused(testCase)
% V_eta is the only migration target (2026-10-23); another one is an argument
% error rather than a no-op.
result = struct('migrated', {{}}, 'summary', struct('total', 0));
verifyError(testCase, @() did2.convert.resolveClockAlignment(result, ...
    'TargetVersion', 'V_delta'), 'MATLAB:validators:mustBeMember');
end

% ===================== the filefind syncrule arm ===========================
% A v1 `ndi.time.syncrule.filefind` names its two acquisition systems by NAME
% (filefind.m:32: number_fullpath_matches, syncfilename, daqsystem1,
% daqsystem2). Pass 1 passes it through; this pass resolves both names within
% the rule's session and re-runs the migrator. Fixtures are the writer's shape
% (syncrule.m:183-187 + filefind.m:32), stored after session.database_add has
% replaced the empty session id with the real one (session.m:267-275).

function testFilefindRuleFoldsWhenBothSystemsResolve(testCase)
result = migrate({ ...
    daqsystemFixture('sys_1', 'sess_A', 'mydaq1'), ...
    daqsystemFixture('sys_2', 'sess_A', 'mydaq2'), ...
    filefindFixture('rule_ff', 'sess_A', 'mydaq1', 'mydaq2')});
verifyEqual(testCase, countOf(result, 'syncrule'), 1);   % pass 1: passthrough
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.acquisition_systems_indexed, 2);
verifyEqual(testCase, rep.syncrules_seen, 1);
verifyEqual(testCase, rep.syncrule_filefind_seen, 1);
verifyEqual(testCase, rep.syncrule_refused_total, 0);
verifyEqual(testCase, rep.syncrule_configurations_folded, 1);
verifyEqual(testCase, rep.syncrule_channels_emitted, 2);
verifyEqual(testCase, rep.syncrule_software_emitted, 1);
verifyEqual(testCase, countOf(out, 'syncrule'), 0);
verifyEqual(testCase, countOf(out, 'clock_alignment_configuration'), 1);
verifyEqual(testCase, countOf(out, 'acquisition_channels'), 2);

cfg = firstOf(out, 'clock_alignment_configuration');
verifyEqual(testCase, cfg.get('base.id'), 'rule_ff');      % base.id PRESERVED
chIds = depValues(cfg, 'acquisition_channels_id');
verifyEqual(testCase, numel(chIds), 2);
verifyNotEmpty(testCase, depValue(cfg, 'software_id'));
verifyEmpty(testCase, depValue(cfg, 'resolved_acquisition_system_id'));
% Each channel group names its system by the resolved EDGE; together they are
% the two systems the rule named, as a set (the pair is UNORDERED).
sysIds = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if ~strcmp(d.get('document_class.class_name'), 'acquisition_channels'); continue; end
    verifyTrue(testCase, any(strcmp(chIds, d.get('base.id'))));
    sysIds{end+1} = depValue(d, 'acquisition_system_id'); %#ok<AGROW>
end
verifyEqual(testCase, sort(sysIds), {'sys_1', 'sys_2'});
% number_fullpath_matches and syncfilename are DECLARED method.parameters.
m = cfg.get('clock_alignment_configuration.method');
names = arrayfun(@(e) char(e.variable.name), m.parameters, 'UniformOutput', false);
verifyEqual(testCase, sort(names), sort({'minimum matching file paths', 'sync file name'}));
for k = 1:numel(m.parameters)
    e = m.parameters(k);
    switch char(e.variable.name)
        case 'minimum matching file paths'
            verifyEqual(testCase, double(e.count), 1);
        case 'sync file name'
            verifyEqual(testCase, char(e.text), 'syncfile.txt');
    end
end
end


function testFilefindFoldValidatesAgainstTheSchema(testCase)
% The transform test above cannot tell whether the fold and the schema agree;
% this one validates every body, in pass 1 and in the fold.
result = did2.convert.v1_to_v2({ ...
    daqsystemFixture('sys_1', 'sess_A', 'mydaq1'), ...
    daqsystemFixture('sys_2', 'sess_A', 'mydaq2'), ...
    filefindFixture('rule_ff', 'sess_A', 'mydaq1', 'mydaq2')}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
out = did2.convert.resolveClockAlignment(result, 'Validate', true);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncrule_fold_quarantined, 0);
verifyEqual(testCase, rep.syncrule_configurations_folded, 1);
verifyEqual(testCase, countOf(out, 'clock_alignment_configuration'), 1);
verifyEqual(testCase, countOf(out, 'acquisition_channels'), 2);
verifyEqual(testCase, countOf(out, 'syncrule'), 0);
end


function testFilefindWithAMissingNameStaysPassthroughAndIsCounted(testCase)
% mydaq2 is not a system in sess_A: nothing is minted for it, and no half pair.
result = migrate({ ...
    daqsystemFixture('sys_1', 'sess_A', 'mydaq1'), ...
    filefindFixture('rule_ff', 'sess_A', 'mydaq1', 'mydaq2')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncrule_refused_name_missing, 1);
verifyEqual(testCase, rep.syncrule_names_missing, 1);
verifyEqual(testCase, rep.syncrule_refused_total, 1);
verifyEqual(testCase, rep.syncrule_configurations_folded, 0);
verifyEqual(testCase, countOf(out, 'syncrule'), 1);
verifyEqual(testCase, countOf(out, 'clock_alignment_configuration'), 0);
verifyEqual(testCase, countOf(out, 'acquisition_channels'), 0);
verifyEqual(testCase, firstOf(out, 'syncrule').get('base.id'), 'rule_ff');
end


function testFilefindNameInAnotherSessionDoesNotResolve(testCase)
% Resolution is WITHIN the rule's session: a same-named system elsewhere is a
% different device.
result = migrate({ ...
    daqsystemFixture('sys_1', 'sess_A', 'mydaq1'), ...
    daqsystemFixture('sys_2', 'sess_B', 'mydaq2'), ...
    filefindFixture('rule_ff', 'sess_A', 'mydaq1', 'mydaq2')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncrule_refused_name_missing, 1);
verifyEqual(testCase, countOf(out, 'syncrule'), 1);
verifyEqual(testCase, countOf(out, 'acquisition_channels'), 0);
end


function testFilefindWithAnAmbiguousNameStaysPassthroughAndIsCounted(testCase)
% Two systems in sess_A are both called mydaq2: no first match is taken.
result = migrate({ ...
    daqsystemFixture('sys_1', 'sess_A', 'mydaq1'), ...
    daqsystemFixture('sys_2', 'sess_A', 'mydaq2'), ...
    daqsystemFixture('sys_3', 'sess_A', 'mydaq2'), ...
    filefindFixture('rule_ff', 'sess_A', 'mydaq1', 'mydaq2')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncrule_refused_name_ambiguous, 1);
verifyEqual(testCase, rep.syncrule_names_ambiguous, 1);
verifyEqual(testCase, rep.syncrule_refused_name_missing, 0);
verifyEqual(testCase, rep.syncrule_refused_total, 1);
verifyEqual(testCase, countOf(out, 'syncrule'), 1);
verifyEqual(testCase, countOf(out, 'clock_alignment_configuration'), 0);
verifyEqual(testCase, countOf(out, 'acquisition_channels'), 0);
end


function testFilefindOnTheEmptySessionSentinelIsRefused(testCase)
sentinel = '0000000000000000_0000000000000000';
result = migrate({ ...
    daqsystemFixture('sys_1', sentinel, 'mydaq1'), ...
    daqsystemFixture('sys_2', sentinel, 'mydaq2'), ...
    filefindFixture('rule_ff', sentinel, 'mydaq1', 'mydaq2')});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncrule_refused_no_session_id, 1);
verifyEqual(testCase, countOf(out, 'syncrule'), 1);
end


function testAChannelBasedRuleIsNotConsumed(testCase)
% commonTriggersOverlappingEpochs also names systems, but with channel strings;
% this arm is the filefind arm, and the channel rule is counted, not folded.
v1 = filefindFixture('rule_ct', 'sess_A', 'mydaq1', 'mydaq2');
v1.syncrule = struct('ndi_syncrule_class', ...
    'ndi.time.syncrule.commonTriggersOverlappingEpochs', ...
    'parameters', struct('daqsystem1_name', 'mydaq1', 'daqsystem2_name', 'mydaq2', ...
        'daqsystem_ch1', 'dep1', 'daqsystem_ch2', 'mk1', ...
        'epochclocktype', 'dev_local_time', ...
        'minEmbeddedFileOverlap', 1, 'errorOnFailure', true));
result = migrate({ ...
    daqsystemFixture('sys_1', 'sess_A', 'mydaq1'), ...
    daqsystemFixture('sys_2', 'sess_A', 'mydaq2'), v1});
out = did2.convert.resolveClockAlignment(result, 'Validate', false);
rep = out.clock_alignment_fold;
verifyEqual(testCase, rep.syncrules_seen, 1);
verifyEqual(testCase, rep.syncrule_not_filefind, 1);
verifyEqual(testCase, rep.syncrule_filefind_seen, 0);
verifyEqual(testCase, countOf(out, 'syncrule'), 1);
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

function v1 = daqsystemFixture(id, sessionId, name)
%DAQSYSTEMFIXTURE A did_v1 daqsystem (+ndi/+daq/system.m:485-497); its base.name
%   is the name a filefind rule's daqsystem1 / daqsystem2 matches.
v1 = struct();
v1.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', id, 'session_id', sessionId, ...
    'name', name, 'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
% reader_id and epoch_file_pattern_id are REQUIRED on acquisition_system (Jess
% Haley 2026-10-22 [required acquisition edges]); a real v1 daqsystem names both.
v1.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'id', {['nav_' id], ['rdr_' id]});
end

function v1 = filefindFixture(id, sessionId, name1, name2)
%FILEFINDFIXTURE A did_v1 syncrule as syncrule.m:183-187 writes a filefind
%   rule, with filefind.m:32's parameter set.
v1 = struct();
v1.document_class = struct('class_name', 'syncrule', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncrule = struct('ndi_syncrule_class', 'ndi.time.syncrule.filefind', ...
    'parameters', struct('number_fullpath_matches', 1, ...
        'syncfilename', 'syncfile.txt', 'daqsystem1', name1, 'daqsystem2', name2));
end

function v = depValues(doc, name)
v = {};
deps = doc.get('depends_on');
for k = 1:numel(deps)
    if ~strcmp(deps(k).name, name); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v{end+1} = char(deps(k).document_id); %#ok<AGROW>
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v{end+1} = char(deps(k).value); %#ok<AGROW>
    end
end
end
