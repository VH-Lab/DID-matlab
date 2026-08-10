function tests = testStimulusResponseEpochGuard
%TESTSTIMULUSRESPONSEEPOCHGUARD The epoch gate on the stimulus-response fold.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   nothing in this file has been run. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion.
%
%   NEW FILE, deliberately. `testMigratorsJ.m` is owned by another session.
%   `testMigratorsJStimulusResponse.m` and
%   `testMigratorsJStimulusResponseGroundTruth.m` pin the UNGATED fold and now
%   assert the pre-guard behaviour; the inversions they need are listed in the
%   change report rather than applied here, because this file is additive by
%   instruction and those two are not mine to rewrite.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST, AND WHY IT IS A DEFECT WORTH A TEST FILE
%   ---------------------------------------------------------------------
%   `stimulus_response.element_epochid` is the RECORDING ELEMENT's epoch, taken
%   from `ts_epoch_timeref.epoch` (tuning_response.m:318) and recoverable from no
%   other document. The signed model
%   (V_eta_stimulus_response_model_plan.md, TEAM-SIGN-OFF [stimulus response],
%   2026-08-08, revision 2) PRESERVES it as a `relative_reference` whose
%   `relative_to` points at an `epoch`. The fold as first built emitted a session
%   anchor instead and wrote no `stimulus_response` block, so the string simply
%   ceased to exist.
%
%   A DROPPED SOURCE FIELD IS SEEN BY NO COUNTER WE HAVE.
%   `did2.validate.silentLoss` counts empty edges, vacuous required fields and
%   fragments; a field that is not there is none of the three. The output is
%   well-formed and complete by its own schema. Nothing subtracts.
%
%   So the fold is gated, in the shape +migrators_j/syncrule_mapping.m already
%   uses for the same wall:
%
%     BRANCH 1  an `epoch_id` edge on the pre-body -> fold, anchored to a
%               relative_reference whose relative_to IS that epoch.
%     BRANCH 2  an epoch string and no epoch document -> DO NOT FOLD. The
%               passthrough keeps the string.
%     BRANCH 3  no epoch string -> fold with the session anchor; nothing to lose.
%
%   Branch 2 is the live branch on every did_v1 document today. BOTH branches are
%   driven here, which is the shape private/jEpochDocId.m documents for exactly
%   this seam -- a gate whose open side is never exercised is a gate nobody can
%   trust when it opens.
%
%   Run with:  results = runtests('did2.unittest.testStimulusResponseEpochGuard');

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function out = runJ(v1)
out = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_eta');
end

function d = findClass(testCase, out, className)
d = [];
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('document_class.class_name')), className)
        d = out.migrated{k};
        return;
    end
end
verifyFail(testCase, sprintf('no %s document was emitted', className));
end

function tf = anyClass(out, className)
tf = false;
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('document_class.class_name')), className)
        tf = true; return;
    end
end
end

function v = depValue(b, name)
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if ~isfield(deps(k), 'name') || ~strcmp(char(deps(k).name), name); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v = char(deps(k).value);
    end
    return;
end
end

% ===================== fixture (from the WRITER) =======================

function v1 = responseFixture(elementEpochid)
%RESPONSEFIXTURE A did_v1 stimulus_response_scalar as tuning_response.m builds it.
%
%   The shape is copied from testMigratorsJStimulusResponse.m's fixture, which
%   documents its own writer lines. TWO things about it are load-bearing here and
%   are restated rather than assumed:
%
%   1. THERE IS NO `epochid` BLOCK. The template's superclasses are base +
%      stimulus_response, nothing else:
%
%        git show origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_response_scalar.json
%           "superclasses": [ { ... base.json }, { ... stimulus_response.json } ]
%
%      (V_eta_stimulus_response_model_plan.md's worked example shows an
%      `"epochid": { "epochid": "t00003" }` block on this document. That block
%      does not exist on the real class -- the plan's own prose one page earlier
%      says the epoch strings live on `stimulus_response`, and the migrator
%      header says the superclasses are base + stimulus_response only. The
%      fixture follows the template.)
%
%   2. THE WRITER SETS `element_epochid` UNCONDITIONALLY, at :317-318, in a
%      straight line with no branch. So branch 2 is not an edge case; it is every
%      real document.
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_response_scalar', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'stimulus_response', 'class_version', '1.0.0')]);
v1.depends_on = struct( ...
    'name',  {'stimulus_response_scalar_parameters_id', 'element_id', ...
              'stimulus_presentation_id', 'stimulus_control_id', 'stimulator_id'}, ...
    'value', {'param_77c19b', 'elem_9c027e', 'pres_b671ff', 'ctrl_20e84c', 'stim_5daa03'});
v1.base = struct('id', 'resp_412fa1', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.stimulus_response = struct('stimulator_epochid', 't00003', ...
    'element_epochid', elementEpochid);
v1.stimulus_response_scalar = struct('response_type', 'F1', ...
    'responses', struct( ...
        'stimid',                     [1 2 3 1 2 3], ...
        'response_real',              [2.10 5.44 1.02 2.31 5.61 0.94], ...
        'response_imaginary',         [0.31 -1.20 0.08 0.29 -1.11 0.05], ...
        'control_response_real',      [0.42 0.42 0.42 0.39 0.39 0.39], ...
        'control_response_imaginary', [0.01 0.01 0.01 0.02 0.02 0.02]));
end

function v1 = withEpochEdge(v1, epochDocId)
%WITHEPOCHEDGE Stamp the `epoch_id` edge that #60's remaining line will stamp.
%   This is the ONLY difference between branch 2 and branch 1, which is the
%   property the gate is designed to have: nothing else in the migrator changes
%   when the epoch pass starts filling it. private/jEpochDocId.m reads this edge.
v1.depends_on(end+1) = struct('name', 'epoch_id', 'value', epochDocId);
end

% ===================== BRANCH 2: the live branch today =================

function testAnEpochStringWithNoEpochDocumentSuppressesTheFold(testCase)
out = runJ(responseFixture('t00003'));
verifyEmpty(testCase, out.quarantine);
% 1 -> 1. NOT the leaf, NOT an anchor: the source document, whole.
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, char(out.migrated{1}.get('document_class.class_name')), ...
    'stimulus_response_scalar');
verifyFalse(testCase, anyClass(out, 'harmonic_component_calculation'));
end

function testTheSuppressedPassthroughStillCarriesBothEpochStrings(testCase)
% The whole point of suppressing. If this assertion ever fails, the suppression
% has stopped buying anything and should be reconsidered rather than kept.
out = runJ(responseFixture('t00003'));
b = out.migrated{1}.toStruct();
hits = did2.validate.epochStrings(b);
verifyEqual(testCase, numel(hits), 2);
verifyEqual(testCase, sort({hits.value}), {'t00003', 't00003'});
end

function testTheSuppressionIsVisibleToTheRetentionCounter(testCase)
% A suppression nobody counts is indistinguishable from a drop. The counter that
% proves it: v1 pairs in, pairs still reachable out, and the subtraction.
v1  = responseFixture('t00003');
out = runJ(v1);
r = did2.validate.epochStringRetention({v1}, out.migrated);
verifyTrue(testCase, r.ran);
verifyEqual(testCase, r.v1_pairs, 1);          % both strings are 't00003'
verifyEqual(testCase, r.retained_as_string, 1);
verifyEqual(testCase, r.pairs_dropped, 0);
end

function testTheMintCanSeeThisFamilysEpochStrings(testCase)
% Branch 1 is unreachable until an `epoch` document exists for this pair, and
% that is did2.convert.epochMint's job. Before this change its reader could not
% see the stimulus-response family at all, so the epochs branch 1 needs would
% never have been minted no matter how the migrator was written.
v1  = responseFixture('t00003');
out = runJ(v1);
[~, rep] = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'V_eta');
sources = {rep.strings_by_source.source};
verifyTrue(testCase, any(strcmp(sources, 'stimulus_response.element_epochid')));
verifyTrue(testCase, any(strcmp(sources, 'stimulus_response.stimulator_epochid')));
% No `session` document in this one-document batch, so nothing is minted -- and
% the refusal is COUNTED rather than silent.
verifyEqual(testCase, rep.epochs_minted, 0);
verifyEqual(testCase, rep.skipped_no_session_document, 1);
end

% ===================== BRANCH 3: nothing to lose =======================

function testWithNoEpochStringTheFoldStillRunsOnTheSessionAnchor(testCase)
% Refusing here would strand a document for a fact it does not have.
out = runJ(responseFixture(''));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);
leaf = findClass(testCase, out, 'harmonic_component_calculation');
anchor = findClass(testCase, out, 'session_relative_reference');
verifyEqual(testCase, depValue(leaf.toStruct(), 'time_reference_1'), ...
    char(anchor.get('base.id')));
end

% ===================== BRANCH 1: the day the mint stamps the edge ======

function testAnEpochDocumentUnlocksTheFold(testCase)
out = runJ(withEpochEdge(responseFixture('t00003'), 'epochdoc_aa11'));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);
leaf = findClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, char(leaf.get('base.id')), 'resp_412fa1');   % id preserved
end

function testTheAnchorIsARelativeReferenceOntoTheEpochNotASessionAnchor(testCase)
% Revision 2 of the sign-off, built: `element_epochid` -> relative_reference,
% relative_to -> epoch. The session anchor is REPLACED, not added beside -- two
% anchors on one interaction would be #52's undefined-meaning case.
out  = runJ(withEpochEdge(responseFixture('t00003'), 'epochdoc_aa11'));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
ref  = findClass(testCase, out, 'relative_reference');
verifyFalse(testCase, anyClass(out, 'session_relative_reference'));

rb = ref.toStruct();
verifyEqual(testCase, depValue(rb, 'relative_to'), 'epochdoc_aa11');
verifyEqual(testCase, depValue(leaf.toStruct(), 'time_reference_1'), ...
    char(ref.get('base.id')));
end

function testTheEpochAnchorStatesTheRelationAndTheClockAndNoInventedOffset(testCase)
% `clock` is TRANSCRIBED from the writer, not chosen: the epoch this anchors to
% is the recording element's, produced by
%   E.syncgraph.time_convert(..., ndi.time.clocktype('dev_local_time'))
% at tuning_response.m:245-246. `dev_local_time` is one of the four terms in
% relative_reference's `clock` binding, so it is a BOUND value, not a staged one.
%
% NO `start` and NO `duration`. The source says WHICH epoch and nothing about
% where in it; relative_reference.json says absent-together means "the relation
% alone is asserted". A zero offset would assert the response began exactly at
% the epoch boundary, which the writer never said.
out = runJ(withEpochEdge(responseFixture('t00003'), 'epochdoc_aa11'));
ref = findClass(testCase, out, 'relative_reference');
verifyEqual(testCase, char(ref.get('relative_reference.value.relation.node')), ...
    'time:intervalDuring');
verifyEqual(testCase, char(ref.get('relative_reference.value.clock.name')), ...
    'dev_local_time');
val = ref.get('relative_reference.value');
verifyFalse(testCase, isfield(val, 'start') && ~isempty(val.start) ...
    && isstruct(val.start) && isfield(val.start, 'source_value') ...
    && ~isempty(val.start.source_value) && val.start.source_value ~= 0);
end

function testBranchOneStillRehomesAllFiveV1Edges(testCase)
% Opening the gate must not quietly change anything else about the fold.
out  = runJ(withEpochEdge(responseFixture('t00003'), 'epochdoc_aa11'));
b    = findClass(testCase, out, 'harmonic_component_calculation').toStruct();
verifyEqual(testCase, depValue(b, 'subject_id'),           'elem_9c027e');
verifyEqual(testCase, depValue(b, 'instrument_id'),        'stim_5daa03');
verifyEqual(testCase, depValue(b, 'derived_from_1'),       'pres_b671ff');
verifyEqual(testCase, depValue(b, 'derived_from_2'),       'ctrl_20e84c');
verifyEqual(testCase, depValue(b, 'method_parameters_id'), 'param_77c19b');
end

% ===================== the guards that already existed =================

function testTheOlderGuardsStillPassTheDocumentThrough(testCase)
% Guard 1 (no element_id) must keep winning even with no epoch string, or the
% new gate would have quietly reordered the refusals.
v1 = responseFixture('');
v1.depends_on(2).value = '';        % element_id
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, char(out.migrated{1}.get('document_class.class_name')), ...
    'stimulus_response_scalar');
end
