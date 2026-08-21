function tests = testResponseParametersFold
%TESTRESPONSEPARAMETERSFOLD The resolver half of the stimulus-response fold (#61).
%
%   Exercises `did2.convert.resolveResponseParameters`, which performs the line
%   of the signed model that a single-document migrator cannot
%   (V_eta_stimulus_response_model_plan.md, TEAM-SIGN-OFF [stimulus response],
%   jess@walthamdatascience.com / 2026-08-08):
%
%       stimulus_response_scalar_parameters_basic  FOLD -> method_parameters
%                                                  (inline); id dropped
%
%   and that plan's BUILD section: *"One migrator plus one resolver pass."* The
%   migrator half is +migrators_j/stimulus_response_scalar.m and is covered by
%   testMigratorsJStimulusResponse.m / ...GroundTruth.m / testStimulusResponseEpochGuard.m.
%
%   ***** UNVERIFIED: THESE TESTS HAVE NEVER BEEN EXECUTED. *****
%   Written 2026-08-11 in a container with NO MATLAB. Nothing here has been run;
%   test-migrators-quick.yml is the first thing with an opinion. This project's
%   own record says a test written from the same premise as the code cannot
%   catch the code, so treat the first CI run as the first real evidence.
%
%   ---------------------------------------------------------------------
%   EVERY FIXTURE IS BUILT FROM THE WRITER
%   ---------------------------------------------------------------------
%   The two v1 shapes below are the ones NDI-matlab
%   `+ndi/+app/+stimulus/tuning_response.m` constructs on origin/main -- the five
%   depends_on set unconditionally at :323-328, the `responses` sub-struct at
%   :309-313, `response_type` derived from `freq_response` at :262-266, the
%   `stimulus_response` block at :317-318, and the six parameter fields at
%   :172-177 / :276-281. They are deliberately the SAME shapes
%   testMigratorsJStimulusResponse.m uses, restated here rather than shared,
%   because that file is a sibling with its own owner and a shared fixture is a
%   shared premise.
%
%   THE `epoch_id` STAMP IS THE ONE FABRICATION, and it is loud at every call
%   site. No did_v1 document carries that edge; `did2.convert.epochMint` writes
%   it (epochMint.m:409) and `+migrators_j/private/jEpochDocId.m` reads it.
%   Without it, +migrators_j/stimulus_response_scalar.m's guard 4 SUPPRESSES the
%   fold and pass 1 emits no leaf at all -- which is the live branch on every
%   real document today, and is pinned by its own test below rather than left as
%   an assumption.
%
%   Run with:  results = runtests('did2.unittest.testResponseParametersFold');

tests = functiontests(localfunctions);
end

% ===================== fixtures (from the WRITER) ==========================

function v1 = responseFixture(responseType)
%RESPONSEFIXTURE A did_v1 stimulus_response_scalar as tuning_response.m builds it.
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
    'element_epochid', 't00003');
v1.stimulus_response_scalar = struct('response_type', responseType, ...
    'responses', struct( ...
        'stimid',                     [1 2 3 1 2 3], ...
        'response_real',              [2.10 5.44 1.02 2.31 5.61 0.94], ...
        'response_imaginary',         [0.31 -1.20 0.08 0.29 -1.11 0.05], ...
        'control_response_real',      [0.42 0.42 0.42 0.39 0.39 0.39], ...
        'control_response_imaginary', [0.01 0.01 0.01 0.02 0.02 0.02]));
end

function v1 = withEpochEdge(v1)
%WITHEPOCHEDGE Stamp the `epoch_id` edge that opens the migrator's guard 4.
%   The only fabrication in this file. See the header.
v1.depends_on(end+1) = struct('name', 'epoch_id', 'value', 'epochdoc_5f21b0');
end

function v1 = parametersFixture(freqResponse)
%PARAMETERSFIXTURE A did_v1 stimulus_response_scalar_parameters_basic (:276-281)
%   with the in-function defaults at :172-177. Its id is the one the response
%   fixture's parameters edge points at, so a batch of the two is self-consistent.
%
%   FREQRESPONSE is a parameter rather than a constant so the harmonic-agreement
%   test can make the two documents DISAGREE without editing anything else -- the
%   disagreement is the whole subject of that test, and hiding it inside a
%   hand-edited copy of this function would make it invisible.
if nargin < 1; freqResponse = 1; end
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_response_scalar_parameters_basic', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'stimulus_response_scalar_parameters', ...
                             'class_version', '1.0.0')]);
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'param_77c19b', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.stimulus_response_scalar_parameters_basic = struct( ...
    'temporalfreqfunc', 'ndi.fun.stimulustemporalfrequency', ...
    'freq_response', freqResponse, ...
    'prestimulus_time', [], ...
    'prestimulus_normalization', [], ...
    'isspike', 1, ...
    'spiketrain_dt', 0.001);
end

% ===================== the fold ============================================

function testTheFiveRunKnobsLandInlineOnTheLeaf(testCase)
% THE CENTRAL ASSERTION. All five, by value, in the plan's own mapping:
%   temporalfreqfunc, prestimulus_time, prestimulus_normalization,
%   isspike, spiketrain_dt  ->  subject_interaction.method_parameters
[~, leaf, rep] = foldPair(testCase, 'F1');
mp = leaf.subject_interaction.method_parameters;
verifyEqual(testCase, mp.temporalfreqfunc, 'ndi.fun.stimulustemporalfrequency');
verifyEqual(testCase, mp.isspike, 1);
verifyEqual(testCase, mp.spiketrain_dt, 0.001, 'AbsTol', 1e-12);
% PRESENT-AND-EMPTY, not absent. The writer sets both to [] on every document
% (tuning_response.m:174-175) and the plan's worked example inlines them as [].
% Dropping them would make "the writer's default was in force" and "nobody
% recorded this" the same shape.
verifyTrue(testCase, isfield(mp, 'prestimulus_time'));
verifyEmpty(testCase, mp.prestimulus_time);
verifyTrue(testCase, isfield(mp, 'prestimulus_normalization'));
verifyEmpty(testCase, mp.prestimulus_normalization);
verifyEqual(testCase, rep.fields_copied, 5);
verifyEqual(testCase, rep.inlined, 1);
end

function testTheEdgeIsDroppedBecauseTheSchemaSaysNeverBoth(testCase)
% subject_interaction.json, in the schema's own words: "A statement carries the
% inline `method_parameters` field OR this edge, NEVER BOTH (team, 2026-08-09)".
% Both halves are asserted -- an inline field beside a surviving edge would
% satisfy a test that only checked the field.
[~, leaf] = foldPair(testCase, 'F1');
verifyEmpty(testCase, depValue(leaf, 'method_parameters_id'));
verifyNotEmpty(testCase, fieldnames(leaf.subject_interaction.method_parameters));
end

function testFreqResponseIsNotCopiedBecauseTheHarmonicAlreadyHasIt(testCase)
% One fact, one place. `freq_response` IS the harmonic number and the migrator
% has already put it on `harmonic_component.value.harmonic` (via `response_type`,
% which the writer derives from it two lines earlier). Copying it here as well is
% the drift surface the plan's own OPEN 3 records.
[~, leaf] = foldPair(testCase, 'F1');
mp = leaf.subject_interaction.method_parameters;
verifyFalse(testCase, isfield(mp, 'freq_response'));
% ...and the fact itself is NOT lost -- it is on the composite.
verifyEqual(testCase, leaf.harmonic_component.value.harmonic, 1);
end

function testTheOtherFourEdgesAreUntouched(testCase)
% This pass removes exactly ONE edge. The four the migrator RECOVERED --
% instrument_id (the stimulator, T7) and derived_from_1/_2 (presentation and
% control), plus subject_id -- must survive it, or the resolver has undone the
% repair the migrator exists for.
[~, leaf] = foldPair(testCase, 'F1');
verifyEqual(testCase, depValue(leaf, 'subject_id'),     'elem_9c027e');
verifyEqual(testCase, depValue(leaf, 'instrument_id'),  'stim_5daa03');
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'pres_b671ff');
verifyEqual(testCase, depValue(leaf, 'derived_from_2'), 'ctrl_20e84c');
verifyNotEmpty(testCase, depValue(leaf, 'time_reference_1'));
end

function testTheUnreferencedParametersDocumentIsDeleted(testCase)
% VERIFY-BEFORE-DELETE, ARMED PER DOCUMENT (team, 2026-08-21). The F1 parameters
% document folds inline and nothing points at it afterwards, so THIS run's own
% edge-walk proves it unreferenced and it is deleted -- the fold's decided
% end-state (source retires once its content is inline on method_parameters).
[out, ~, rep] = foldPair(testCase, 'F1');
verifyFalse(testCase, anyClass(out, 'stimulus_response_scalar_parameters_basic'));
verifyEqual(testCase, rep.parameters_documents_seen, 1);
% the gate's own number: after the edge is dropped nothing points at it,
verifyEqual(testCase, rep.parameters_documents_unreferenced_after, 1);
verifyEqual(testCase, rep.parameters_documents_referenced_after, 0);
% ...and the eligible document actually went.
verifyEqual(testCase, rep.parameters_documents_deleted, 1);
end

function testTheUnreferencedCountIsMeasuredNotInferred(testCase)
% The deletion evidence must come from walking the graph, not from "this pass
% removed the only edge, therefore it is free". Give the parameters document a
% SECOND referent and the count must go the other way -- an inferred count could
% not tell the difference, and a wrong 1 here authorises deleting a document
% something still points at.
extra = otherReferrerFixture('param_77c19b');
[out, rep] = runFold(testCase, ...
    {withEpochEdge(responseFixture('F1')), parametersFixture(), extra});
verifyEqual(testCase, rep.inlined, 1);
verifyEqual(testCase, rep.parameters_documents_referenced_after, 1);
verifyEqual(testCase, rep.parameters_documents_unreferenced_after, 0);
% AND THE SAFETY PROOF: a document something still points at is KEPT, never
% deleted on the strength of "unreferenced in the corpora we tested".
verifyEqual(testCase, rep.parameters_documents_deleted, 0);
verifyTrue(testCase, anyClass(out, 'stimulus_response_scalar_parameters_basic'));
end

% ===================== what it refuses =====================================

function testAParametersDocumentOutsideTheBatchIsRefusedNotGuessed(testCase)
% The leaf alone: its `method_parameters_id` names a document not in the batch.
% Refusing keeps the edge -- which still resolves in a full migration -- rather
% than dropping it and losing the reference to values this pass never read.
[out, rep] = runFold(testCase, {withEpochEdge(responseFixture('F1'))});
verifyEqual(testCase, rep.leaves_seen, 1);
verifyEqual(testCase, rep.leaves_with_edge, 1);
verifyEqual(testCase, rep.refused_not_in_batch, 1);
verifyEqual(testCase, rep.refused_total, 1);
verifyEqual(testCase, rep.inlined, 0);
leaf = bodyOfClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, depValue(leaf, 'method_parameters_id'), 'param_77c19b');
verifyEmpty(testCase, fieldnames(leaf.subject_interaction.method_parameters));
end

function testADisagreeingHarmonicIsRefusedRatherThanReconciled(testCase)
% `response_type` is a TOTAL FUNCTION of `freq_response` at the writer
% (tuning_response.m:262-266), so 'F1' beside freq_response == 2 cannot happen in
% data the writer produced. If it does, the identity this whole fold rests on has
% broken and neither value is trustworthy -- so the pass stops instead of picking
% one. The leaf keeps its edge and its empty inline field.
[out, rep] = runFold(testCase, ...
    {withEpochEdge(responseFixture('F1')), parametersFixture(2)});
verifyEqual(testCase, rep.harmonic_checked, 1);
verifyEqual(testCase, rep.refused_harmonic_mismatch, 1);
verifyEqual(testCase, rep.refused_total, 1);
verifyEqual(testCase, rep.inlined, 0);
leaf = bodyOfClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, depValue(leaf, 'method_parameters_id'), 'param_77c19b');
verifyEmpty(testCase, fieldnames(leaf.subject_interaction.method_parameters));
end

function testAnAgreeingHarmonicIsCountedAsCheckedNotMerelyNotRefused(testCase)
% "0 mismatches" is only evidence once something says the comparison HAPPENED.
% This is Operating Rule 5 applied to a predicate: `harmonic_checked` and
% `harmonic_uncheckable` are separate counters precisely so a fold that never
% looked cannot read as a fold that looked and agreed.
[~, ~, rep] = foldPair(testCase, 'F1');
verifyEqual(testCase, rep.harmonic_checked, 1);
verifyEqual(testCase, rep.harmonic_uncheckable, 0);
verifyEqual(testCase, rep.refused_harmonic_mismatch, 0);
end

function testAParametersDocumentWithNoKnobsIsRefused(testCase)
% Inlining an empty struct records nothing WHILE removing the edge that still
% points at wherever the values are. Strictly worse than leaving it alone.
p = parametersFixture();
p.stimulus_response_scalar_parameters_basic = struct('freq_response', 1);
[out, rep] = runFold(testCase, {withEpochEdge(responseFixture('F1')), p});
verifyEqual(testCase, rep.refused_no_fields, 1);
verifyEqual(testCase, rep.inlined, 0);
leaf = bodyOfClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, depValue(leaf, 'method_parameters_id'), 'param_77c19b');
end

function testAnEdgePointingAtTheWrongClassIsRefused(testCase)
% `must_refer_to_document_class` is DECLARATIVE and existence-only, so nothing
% else in the pipeline would notice. This pass reads the referenced document's
% fields, so it checks the class itself rather than trusting the edge name.
p = parametersFixture();
p.document_class.class_name = 'stimulus_response_scalar_parameters';
[~, rep] = runFold(testCase, {withEpochEdge(responseFixture('F1')), p});
verifyEqual(testCase, rep.refused_wrong_class, 1);
verifyEqual(testCase, rep.inlined, 0);
end

% ===================== the denominator =====================================

function testZeroLeavesBesideSuppressedResponsesReadsAsBlockedNotIdle(testCase)
% THE REASON THIS PASS HAS TWO COUNTERS INSTEAD OF ONE. On every real corpus
% today the migrator's epoch gate suppresses every fold (jEpochDocId answers ''
% by construction and the writer sets `element_epochid` unconditionally), so
% `leaves_seen` is 0. Without `suppressed_responses_seen` beside it, that report
% is indistinguishable from a corpus with no stimulus responses in it -- the
% all-zeros-reads-as-clean failure this project keeps paying for.
%
% NOTE the fixture is UNSTAMPED: this is the live branch, not a contrived one.
[~, rep] = runFold(testCase, {responseFixture('F1'), parametersFixture()});
verifyEqual(testCase, rep.leaves_seen, 0);
verifyEqual(testCase, rep.suppressed_responses_seen, 1);
verifyEqual(testCase, rep.parameters_documents_seen, 1);
verifyEqual(testCase, rep.inlined, 0);
verifyEqual(testCase, rep.refused_total, 0);
verifyTrue(testCase, rep.ran);
end

function testTheSuppressedResponseIsLeftWhollyAloneByThisPass(testCase)
% The companion to the test above, and the one that says the suppression stays
% LOSSLESS. This pass reads `stimulus_response_scalar` documents only to count
% them; it must not touch one. Both epoch strings and the parameters edge have to
% still be there afterwards -- a dropped source field is seen by NO counter we
% have (silentLoss counts empty edges, vacuous fields and fragments; a field that
% is simply gone is none of those).
[out, ~] = runFold(testCase, {responseFixture('F1'), parametersFixture()});
src = bodyOfClass(testCase, out, 'stimulus_response_scalar');
verifyEqual(testCase, src.stimulus_response.element_epochid, 't00003');
verifyEqual(testCase, src.stimulus_response.stimulator_epochid, 't00003');
verifyEqual(testCase, depValue(src, 'stimulus_response_scalar_parameters_id'), ...
    'param_77c19b');
end

function testAnEmptyBatchRansWithEveryCounterAtZero(testCase)
% "ran and found nothing" must be readable as such, and must NOT print the same
% as "did not run" (the off-target case below).
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));
[out, rep] = did2.convert.resolveResponseParameters(r, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, rep.leaves_seen, 0);
verifyEqual(testCase, rep.refused_total, 0);
verifyEqual(testCase, out.migrated, {});
% The report rides on the result too, so a caller that ignores the second output
% still carries the measurement.
verifyTrue(testCase, out.response_parameters_fold.ran);
end

function testItIsANoOpOnANonVEtaTarget(testCase)
% `harmonic_component_calculation` exists only in V_eta, and this pass is wired
% into shared harnesses that also run V_delta/V_zeta. `ran` FALSE with every
% counter 0 is the off-target reading, distinct from the empty-batch one above.
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));
[out, rep] = did2.convert.resolveResponseParameters(r, ...
    'Validate', false, 'TargetVersion', 'V_zeta');
verifyFalse(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, out.migrated, {});
end

% ===================== validation ==========================================

function testTheInlinedLeafValidatesAgainstTheRealVEtaSchema(testCase)
% The only test here that proves the pass and the schema agree; every other test
% would pass just as happily against a method_parameters field that does not
% exist. Needs the assembled V_eta set on DID_SCHEMA_PATH (stable + draft +
% deprecated) -- the quick gate builds exactly that, and
% harmonic_component/_calculation are in the DRAFT tier, so a stable-only schema
% path fails here rather than skipping. Deliberate: a skip reads as success.
if isempty(getenv('DID_SCHEMA_PATH'))
    assumeFail(testCase, ...
        'DID_SCHEMA_PATH not set; run under the quick gate (assembled V_eta schema).');
end
out = did2.convert.v1_to_v2( ...
    {withEpochEdge(responseFixture('F2')), parametersFixture(2)}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('pass 1 quarantined %s: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
[out, rep] = did2.convert.resolveResponseParameters(out, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.inlined, 1);
verifyEqual(testCase, rep.fold_quarantined, 0);
verifyEmpty(testCase, out.quarantine);
leaf = bodyOfClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, leaf.subject_interaction.method_parameters.spiketrain_dt, ...
    0.001, 'AbsTol', 1e-12);
verifyEqual(testCase, leaf.harmonic_component.value.harmonic, 2);
% The id is untouched, so every inbound `stimulus_response_scalar_id` reference
% still resolves -- the property the whole calculator family rests on.
verifyEqual(testCase, leaf.base.id, 'resp_412fa1');
end

% ===================== helpers =============================================

function [out, rep] = runFold(testCase, bodies)
%RUNFOLD Pass 1 (validation OFF -- these tests assert the TRANSFORM) then the
%   resolver. Pass-1 quarantine is asserted empty here rather than left to the
%   individual tests: a resolver test that silently ran on an empty batch would
%   pass every assertion about counts being 0.
out = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
[out, rep] = did2.convert.resolveResponseParameters(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

function [out, leaf, rep] = foldPair(testCase, responseType)
%FOLDPAIR The ordinary case: one stamped response + its parameters document.
[out, rep] = runFold(testCase, ...
    {withEpochEdge(responseFixture(responseType)), parametersFixture()});
leaf = bodyOfClass(testCase, out, 'harmonic_component_calculation');
end

function v1 = otherReferrerFixture(targetId)
%OTHERREFERRERFIXTURE A second document pointing at the parameters document, so
%   the unreferenced-after count has something to be wrong about. A v1
%   `stimulus_response_scalar` passes through whole (the epoch gate, unstamped),
%   edge intact -- which is exactly the shape a real corpus produces today.
v1 = responseFixture('F1');
v1.base.id = 'resp_second99';
v1.depends_on(1).value = targetId;
end

function b = bodyOfClass(testCase, out, className)
%BODYOFCLASS One migrated document of CLASSNAME, as a raw body struct.
%   assertFail, not verifyFail: verifyFail records and CONTINUES, and the caller
%   would then dereference an empty struct and report a MATLAB error instead of
%   the real one.
b = struct();
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
    if strcmp(names{k}, className)
        b = out.migrated{k}.toStruct();
        return;
    end
end
assertFail(testCase, sprintf('no "%s" among {%s}', className, ...
    strjoin(names, ', ')));
end

function tf = anyClass(out, className)
tf = false;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        tf = true;
        return;
    end
end
end

function v = depValue(b, name)
%DEPVALUE Read an edge off a RAW BODY STRUCT, tolerant of both live spellings.
%   A depends_on entry is `value` on a body a migrator built and `document_id`
%   once universalRenames has normalised it, and both shapes occur in one batch
%   here. Precedence copied from +did2/+validate/references.m.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on) || ~isstruct(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    if ~isfield(b.depends_on(k), 'name') || ~strcmp(b.depends_on(k).name, name)
        continue;
    end
    if isfield(b.depends_on(k), 'document_id') && ~isempty(b.depends_on(k).document_id)
        v = char(b.depends_on(k).document_id);
    elseif isfield(b.depends_on(k), 'value') && ~isempty(b.depends_on(k).value)
        v = char(b.depends_on(k).value);
    end
    return;
end
end
