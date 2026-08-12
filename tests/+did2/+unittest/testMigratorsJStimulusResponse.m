function tests = testMigratorsJStimulusResponse
%TESTMIGRATORSJSTIMULUSRESPONSE The stimulus response family at V_eta (#61).
%
%   Exercises the two migrators that implement the signed stimulus-response
%   decision (V_eta_stimulus_response_model_plan.md, TEAM-SIGN-OFF
%   [stimulus response], 2026-08-08 -- four classes to TWO):
%
%     stimulus_response_scalar
%         -> harmonic_component_calculation (id PRESERVED) + a time anchor
%            (a `relative_reference` onto the epoch when the epoch document
%             exists, jCalculation's session anchor when there is no epoch
%             string at all, and NO FOLD in between -- see the epoch gate below)
%     stimulus_response_scalar_parameters_basic
%         -> guarded passthrough (the inline fold needs the resolver pass)
%
%   EVERY FIXTURE IS BUILT FROM THE WRITER, NOT FROM A DID-SIDE SCHEMA. The
%   shapes below are the ones NDI-matlab `+ndi/+app/+stimulus/tuning_response.m`
%   actually constructs on origin/main -- five depends_on set unconditionally at
%   :323-328, the `responses` sub-struct at :309-313, `response_type` derived from
%   `freq_response` at :262-266, the `stimulus_response` block at :317-318, and
%   the six parameter fields at :172-177/:276-281. Building a fixture from our own
%   schema is what produced ~2,078 distance_metadata quarantines from a migrator
%   whose unit test was green.
%
%   Note what the fixtures deliberately do NOT carry: an `epochid` block. The NDI
%   templates give this family the superclasses base (+ stimulus_response) and
%   nothing else -- the two epoch strings are ordinary fields on the
%   `stimulus_response` block, not the `epochid` mixin. Adding one would be
%   fabricating the source.
%
%   ---------------------------------------------------------------------
%   WHY THE FOLD TESTS STAMP AN `epoch_id` EDGE (added 2026-08-10)
%   ---------------------------------------------------------------------
%   The migrator gained a fourth guard after this file was written
%   (stimulus_response_scalar.m:259-263): an `element_epochid` STRING with no
%   `epoch` DOCUMENT to anchor to SUPPRESSES the fold, because folding would
%   delete a string recoverable from nothing. Every test below that asserts what
%   the fold PRODUCES therefore has to open that gate, or it is asserting the
%   contents of a document the migrator never emits -- which is how all ten of
%   them failed in Actions run 31439501430 with
%   `no "harmonic_component_calculation" among {stimulus_response_scalar}`.
%
%   The gate is opened the way the epoch pass opens it in production, not by
%   weakening the assertions: `withEpochEdge` stamps the same `epoch_id` edge
%   `did2.convert.epochMint` stamps (epochMint.m:409,
%   `b = setDep(b, 'epoch_id', epochIdByKey(key))`), spelled the way
%   `+migrators_j/private/jEpochDocId.m` reads it. NO did_v1 DOCUMENT CARRIES
%   THAT EDGE -- it is a second-pass product, and stamping it here is the only
%   fabrication in the file, made loud at every call site rather than hidden in
%   the fixture.
%
%   Opening the gate also RESTORES the meaning of the passthrough guards below.
%   With the gate shut, `testUnparseableResponseTypePassesThrough` would pass
%   with guards 2 and 3 deleted -- guard 4 alone would produce the passthrough it
%   asserts. Stamped, only the guard each test names can produce it.
%
%   BOTH BRANCHES STAY COVERED. `testTheUnstampedFixtureIsSuppressedNotFolded`
%   below pins the shut gate (the live branch on every did_v1 document today),
%   `testWithNoEpochStringTheAnchorIsStillTheDuringSessionReference` pins the
%   no-epoch-string branch and the session anchor it emits, and
%   `testStimulusResponseEpochGuard.m` drives all three in detail.
%
%   Most tests run with Validate=false so they assert the TRANSFORM; the last one
%   runs with Validate=true against the real assembled V_eta schema, because a
%   transform test cannot tell you the fold and the schema agree.
%
%   ***** UNVERIFIED: THESE TESTS HAVE NEVER BEEN EXECUTED. *****
%   There is no MATLAB in the environment they were written in. They are written
%   carefully against the pipeline's observed conventions, but "written carefully"
%   is not "run", and this project's own record says a test written from the same
%   premise as the code cannot catch the code. Treat the first CI run as the
%   first real evidence.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJStimulusResponse');

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
% All five, always, in the writer's own order (:323-328).
v1.depends_on = struct( ...
    'name',  {'stimulus_response_scalar_parameters_id', 'element_id', ...
              'stimulus_presentation_id', 'stimulus_control_id', 'stimulator_id'}, ...
    'value', {'param_77c19b', 'elem_9c027e', 'pres_b671ff', 'ctrl_20e84c', 'stim_5daa03'});
v1.base = struct('id', 'resp_412fa1', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
% :317-318 -- both epoch strings live HERE, on the stimulus_response block.
v1.stimulus_response = struct('stimulator_epochid', 't00003', ...
    'element_epochid', 't00003');
% :309-315 -- response_type + the five parallel per-trial row vectors.
v1.stimulus_response_scalar = struct('response_type', responseType, ...
    'responses', struct( ...
        'stimid',                     [1 2 3 1 2 3], ...
        'response_real',              [2.10 5.44 1.02 2.31 5.61 0.94], ...
        'response_imaginary',         [0.31 -1.20 0.08 0.29 -1.11 0.05], ...
        'control_response_real',      [0.42 0.42 0.42 0.39 0.39 0.39], ...
        'control_response_imaginary', [0.01 0.01 0.01 0.02 0.02 0.02]));
end

function v1 = withEpochEdge(v1)
%WITHEPOCHEDGE Stamp the `epoch_id` edge that unlocks the fold (guard 4).
%
%   NO did_v1 DOCUMENT CARRIES THIS EDGE. It is what
%   `did2.convert.epochMint` writes once it has minted one `epoch` document per
%   distinct (session, epoch string) pair:
%
%     epochMint.m:409   b = setDep(b, 'epoch_id', epochIdByKey(key));
%
%   and it is what `+migrators_j/private/jEpochDocId.m` reads -- the entry named
%   `epoch_id`, its value taken from `document_id` | `value` | `id`, whichever is
%   populated. `value` is the spelling a raw v1 body uses, so that is what is
%   written here.
%
%   The id is a stand-in for a document minted OUTSIDE these one- and
%   two-document batches; it is deliberately not an `epochdoc`-shaped substring
%   of either epoch string, so a test that greps the output for a leaked 't000nn'
%   cannot be fooled by it.
v1.depends_on(end+1) = struct('name', 'epoch_id', 'value', epochDocId());
end

function id = epochDocId()
%EPOCHDOCID The one stamped epoch document id, named once.
id = 'epochdoc_5f21b0';
end

function v1 = parametersFixture()
%PARAMETERSFIXTURE A did_v1 stimulus_response_scalar_parameters_basic (:276-281),
%   with the in-function defaults the writer sets at :172-177. The id is the one
%   the response fixture's parameters edge points at, so a batch of the two is
%   self-consistent.
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
    'freq_response', 1, ...
    'prestimulus_time', [], ...
    'prestimulus_normalization', [], ...
    'isspike', 1, ...
    'spiketrain_dt', 0.001);
end

% ===================== the fold ============================================

function testResponseScalarFoldsToHarmonicComponentCalculation(testCase)
out = runJ(withEpochEdge(responseFixture('F1')));
verifyEmpty(testCase, out.quarantine);
% 1 -> 2: the leaf plus its 'during' time anchor. No software entity: this class
% has no `app` block (its NDI superclasses are base + stimulus_response), so
% jCalculation emits none. The anchor is a `relative_reference` onto the epoch
% rather than jCalculation's session anchor, because the epoch document exists --
% stimulus_response_scalar.m:306-310 retargets `time_reference_1` and REPLACES
% bodies{2}, so the count is 2 either way.
verifyEqual(testCase, numel(out.migrated), 2);

leaf = findClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, leaf.get('document_class.schema_version'), 'V_eta');

% ID PRESERVED. Two NDI templates declare an inbound edge to it --
% ndi_common/database_documents/stimulus/stimulus_tuningcurve.json and
% .../apps/calculators/tuningcurve_calc.json both list
% `stimulus_response_scalar_id` in depends_on -- and both of those classes fold
% to tuning_curve_calculation, which resolves the edge by existence. Minting a
% new id here is the mistake that cost 11,448 orphans.
verifyEqual(testCase, leaf.get('base.id'), 'resp_412fa1');
verifyEqual(testCase, leaf.get('base.session_id'), 'sess_0001');
end

function testTheFiveV1EdgesAreAllRehomed(testCase)
% The point of the repair: V_eta dropped stimulator_id and stimulus_control_id
% and inverted the parameters edge. All five come back, under J names.
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
b    = leaf.toStruct();

verifyEqual(testCase, depValue(b, 'subject_id'),           'elem_9c027e');
verifyEqual(testCase, depValue(b, 'instrument_id'),        'stim_5daa03');
verifyEqual(testCase, depValue(b, 'derived_from_1'),       'pres_b671ff');
verifyEqual(testCase, depValue(b, 'derived_from_2'),       'ctrl_20e84c');
verifyEqual(testCase, depValue(b, 'method_parameters_id'), 'param_77c19b');

% the anchor is a real sibling document, not a dangling string. With the epoch
% document in hand it is a `relative_reference` onto that epoch and the relation
% is still 'during' -- spelled as the OWL-Time CURIE the field's value_set
% binding requires. The session-anchor spelling of the same assertion lives in
% testWithNoEpochStringTheAnchorIsStillTheDuringSessionReference.
anchor = findClass(testCase, out, 'relative_reference');
verifyEqual(testCase, depValue(b, 'time_reference_1'), anchor.get('base.id'));
verifyEqual(testCase, char(anchor.get('relative_reference.value.relation.node')), ...
    'time:intervalDuring');
verifyFalse(testCase, anyClass(out, 'session_relative_reference'));

% and the v1 spellings are GONE -- a leaf that still carried element_id would be
% claiming the fold happened while leaving the old edge to be re-read.
verifyEmpty(testCase, depValue(b, 'element_id'));
verifyEmpty(testCase, depValue(b, 'stimulator_id'));
verifyEmpty(testCase, depValue(b, 'stimulus_presentation_id'));
verifyEmpty(testCase, depValue(b, 'stimulus_control_id'));
verifyEmpty(testCase, depValue(b, 'stimulus_response_scalar_parameters_id'));
end

function testHarmonicComponentValueCarriesBothComplexPairs(testCase)
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');

verifyEqual(testCase, leaf.get('harmonic_component.value.harmonic'), 1);
verifyEqual(testCase, leaf.get('harmonic_component.value.real'), ...
    [2.10 5.44 1.02 2.31 5.61 0.94], 'AbsTol', 1e-12);
verifyEqual(testCase, leaf.get('harmonic_component.value.imaginary'), ...
    [0.31 -1.20 0.08 0.29 -1.11 0.05], 'AbsTol', 1e-12);
% The CONTROL pair is the half V_eta had no home for at all. It is not
% decoration: control_response_* is what response_* is measured against.
verifyEqual(testCase, leaf.get('harmonic_component.value.control_real'), ...
    [0.42 0.42 0.42 0.39 0.39 0.39], 'AbsTol', 1e-12);
verifyEqual(testCase, leaf.get('harmonic_component.value.control_imaginary'), ...
    [0.01 0.01 0.01 0.02 0.02 0.02], 'AbsTol', 1e-12);
end

function testResponseTypeBecomesTheHarmonicNumber(testCase)
% tuning_response.m:262-266 -- 'mean' when freq_response==0, else 'F<n>'. The
% three response_types are ONE thing at three values, which is the whole reason
% the class is called harmonic_component. freq_response_commands = [0 1 2] (:202),
% so all three occur in real corpora.
verifyEqual(testCase, harmonicOf(testCase, 'mean'), 0);
verifyEqual(testCase, harmonicOf(testCase, 'F1'), 1);
verifyEqual(testCase, harmonicOf(testCase, 'F2'), 2);
end

function testStatementIsAnInlineCalculationWithTheAppAsMethod(testCase)
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, leaf.get('subject_statement.storage_mode'), 'inline');
verifyEqual(testCase, leaf.get('subject_interaction.method.name'), ...
    'ndi.app.stimulus.tuning_response');
% OPEN 1/OPEN 2 of the plan are not closed: the quantity actually measured is not
% recorded anywhere in this family, so `variable` is the v1-level label and the
% resolver must refine it from the migrated element. Pinned so a change is
% deliberate rather than incidental.
verifyEqual(testCase, leaf.get('subject_statement.variable.name'), 'stimulus response');
end

function testInlineMethodParametersStaysEmptyBesideTheEdge(testCase)
% V_eta's rule (team, 2026-08-09): a statement carries the inline
% `method_parameters` field OR `method_parameters_id`, NEVER BOTH. Pass 1 has the
% edge, so the inline block must stay empty until the resolver inlines the six
% fields and drops the edge.
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
verifyEmpty(testCase, fieldnames(leaf.get('subject_interaction.method_parameters')));
verifyEqual(testCase, depValue(leaf.toStruct(), 'method_parameters_id'), 'param_77c19b');
end

function testStimidIsDeferredRatherThanWrittenIntoConditions(testCase)
% DELIBERATE DEFERRAL, PINNED. Revision 1 of the signed plan moves `stimid` to an
% `axes[]` entry and states that `conditions` is explicitly NOT an axis. V_eta's
% subject_statement has no `axes` field yet (it declares variable / conditions /
% storage_mode), so pass 1 carries neither: emitting `axes` would quarantine on
% undeclaredField, and emitting `conditions` would write the shape the signed
% revision rejects into every migrated document.
%
% Nothing is lost. stimid is column 3 of ts_stim_onsetoffsetid (:248-249), which
% is stim_doc.document_properties.stimulus_presentation.presentation_order
% verbatim (:237-239) -- and that document is derived_from_1 on this leaf.
%
% When #45 lands, this test should FAIL and be replaced by an axes assertion.
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
s    = leaf.toStruct();
verifyFalse(testCase, isfield(s.subject_statement, 'axes'));
if isfield(s.subject_statement, 'conditions')
    verifyEmpty(testCase, s.subject_statement.conditions);
end
% the recovery path must be present, or the deferral argument is not true
verifyEqual(testCase, depValue(s, 'derived_from_1'), 'pres_b671ff');
end

% ===================== the guards ==========================================

function testNoElementIdPassesThroughInsteadOfEmittingASubjectlessLeaf(testCase)
% subject_statement.subject_id is mustBeNonEmpty, and references.m skips empty
% edges, so a subject-less leaf would validate clean and be invisible -- the
% image_stack husk (4,563 documents) and the fitcurve husk both worked exactly
% that way. Pass the document through instead.
% STAMPED so that guard 1 is the only thing that can produce the passthrough.
% Unstamped, guard 4 would produce it too and this test would pass with guard 1
% deleted -- a test that cannot fail for the reason it names.
v1 = withEpochEdge(responseFixture('F1'));
v1.depends_on(strcmp({v1.depends_on.name}, 'element_id')) = [];
out = runJ(v1);

verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'stimulus_response_scalar');
verifyEqual(testCase, out.summary.unconverted_count, 1);
% the payload survives intact for the second pass
verifyEqual(testCase, out.migrated{1}.get('stimulus_response_scalar.response_type'), 'F1');
end

function testUnparseableResponseTypePassesThrough(testCase)
% The V_delta/V_eta tombstone's own documentation claims 'peak' and 'frequency'
% are possible values; that text came from DID-schema's V_alpha snapshot, and the
% writer can produce only 'mean' | 'F<n>'. If a document ever carries something
% else the harmonic is unknown -- and `harmonic` is the field that makes this
% class this class -- so guess nothing and carry the document forward.
% STAMPED, so guard 2 is the only guard that can fire (see guard 1's test).
out = runJ(withEpochEdge(responseFixture('peak')));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'stimulus_response_scalar');
end

function testEmptyResponsesPassThrough(testCase)
% STAMPED, so guard 3 is the only guard that can fire (see guard 1's test).
v1 = withEpochEdge(responseFixture('F1'));
v1.stimulus_response_scalar.responses.response_real = [];
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'stimulus_response_scalar');
end

function testMissingOptionalEdgesAreOmittedNotEmptied(testCase)
% The 26,406-document invented-empty-edge pattern in one assertion: a restored
% edge whose source value is absent must not appear at all. An edge present with
% an empty value is skipped by references.m and by the schema cache alike, so it
% is a fact that looks recorded and is not.
v1 = responseFixture('F1');
keep = ~ismember({v1.depends_on.name}, {'stimulator_id', 'stimulus_control_id'});
v1.depends_on = v1.depends_on(keep);
out  = runJ(withEpochEdge(v1));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
b    = leaf.toStruct();

verifyFalse(testCase, any(strcmp({b.depends_on.name}, 'instrument_id')));
verifyFalse(testCase, any(strcmp({b.depends_on.name}, 'derived_from_2')));
% ...and derived_from_1 keeps its number rather than being packed down to fill
% the gap: a document names the instances of the family (revision 3), so
% renumbering would make two datasets disagree about what derived_from_1 means.
verifyEqual(testCase, depValue(b, 'derived_from_1'), 'pres_b671ff');
end

function testTheUnstampedFixtureIsSuppressedNotFolded(testCase)
% THE OTHER SIDE OF EVERY `withEpochEdge` ABOVE, and the branch every did_v1
% document in every corpus takes today: the writer sets `element_epochid`
% unconditionally (tuning_response.m:317-318, a straight line with no branch) and
% no migrator mints an `epoch` document, so guard 4 fires and the fold does not
% run. Without this test the stamping above would silently redefine what this
% file claims to cover -- it would assert the behaviour of a branch no production
% document reaches while saying nothing about the one they all reach.
%
% Deliberately duplicates testStimulusResponseEpochGuard's branch-2 test. That is
% the point: the assertions in THIS file are only about branch 1 because ONE line
% opens the gate, and the reader has to be able to see the closed gate here.
out = runJ(responseFixture('F1'));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'stimulus_response_scalar');
verifyFalse(testCase, anyClass(out, 'harmonic_component_calculation'));
% suppressing is only worth anything if the string it protects is still there
verifyEqual(testCase, out.migrated{1}.get('stimulus_response.element_epochid'), 't00003');
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testWithNoEpochStringTheAnchorIsStillTheDuringSessionReference(testCase)
% BRANCH 3, and the home of the session-anchor assertion that
% testTheFiveV1EdgesAreAllRehomed used to carry. With no epoch string there is
% nothing for the fold to destroy, so it runs on jCalculation's session anchor --
% and that anchor states 'during' in the `session_relative_reference` spelling,
% which is a different field from branch 1's OWL-Time CURIE and so needs its own
% assertion rather than an edit to the other one.
v1 = responseFixture('F1');
v1.stimulus_response.element_epochid = '';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);

leaf   = findClass(testCase, out, 'harmonic_component_calculation');
anchor = findClass(testCase, out, 'session_relative_reference');
verifyEqual(testCase, depValue(leaf.toStruct(), 'time_reference_1'), ...
    anchor.get('base.id'));
verifyEqual(testCase, anchor.get('session_relative_reference.relation'), 'during');
% id still preserved on the branch that does not have an epoch document
verifyEqual(testCase, leaf.get('base.id'), 'resp_412fa1');
end

% ===================== the parameters document =============================

function testParametersBasicPassesThroughWithItsIdAndFields(testCase)
% DEFERRED, NOT DELETED. The signed fold is inline into method_parameters, which
% needs the resolver pass; until then the document must survive so the leaf's
% method_parameters_id resolves and so the six values are still there to inline.
out = runJ(parametersFixture());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), ...
    'stimulus_response_scalar_parameters_basic');
verifyEqual(testCase, d.get('base.id'), 'param_77c19b');
blk = 'stimulus_response_scalar_parameters_basic.';
verifyEqual(testCase, d.get([blk 'temporalfreqfunc']), 'ndi.fun.stimulustemporalfrequency');
verifyEqual(testCase, d.get([blk 'freq_response']), 1);
verifyEqual(testCase, d.get([blk 'isspike']), 1);
verifyEqual(testCase, d.get([blk 'spiketrain_dt']), 0.001, 'AbsTol', 1e-12);
% counted as unconverted -- that count IS the signal that the resolver is owed
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testParametersBasicKeepsTheTwoEmptyFieldsPRESENT(testCase)
% THE SEAM BETWEEN THIS MIGRATOR AND did2.convert.resolveResponseParameters, and
% the one part of it the test above does not assert: it checks four of the six
% fields, and the two it skips are the two that are EMPTY.
%
% They are empty at the writer, on every document ever written --
% `git show origin/main:src/ndi/+ndi/+app/+stimulus/tuning_response.m`:
%
%     :174  prestimulus_time          = []
%     :175  prestimulus_normalization = []
%     :276-281  the document is built from exactly the six via vlt.data.var2struct
%
% and the resolver copies them INLINE rather than skipping them, deliberately:
% "Dropping them would make 'the writer's default was in force' and 'nobody
% recorded this' the same shape -- and the second is a claim the source never
% made." testResponseParametersFold.m:123-126 asserts that with isfield +
% verifyEmpty on the resolver's OUTPUT.
%
% Nothing asserted it on the INPUT. `bodies = {preBody}` cannot drop a field by
% itself, but the fixture does not reach the assertion untouched: it goes
% through universalRenames and a document round-trip, and a `[]` that arrives as
% an ABSENT field instead of an EMPTY one is exactly the distinction the
% resolver rests on -- it would silently degrade to `refused_no_fields` or to a
% five-knob inline, with no counter naming the cause. So the property is
% asserted as presence-AND-emptiness, never as a value comparison, which would
% pass on an absent field.
out = runJ(parametersFixture());
verifyEmpty(testCase, out.quarantine);
b = out.migrated{1}.toStruct();
verifyTrue(testCase, isfield(b, 'stimulus_response_scalar_parameters_basic'), ...
    'the v1 block must survive the passthrough under its own name');
blk = b.stimulus_response_scalar_parameters_basic;
verifyTrue(testCase, isfield(blk, 'prestimulus_time'), ...
    'prestimulus_time must be PRESENT-but-empty, not absent');
verifyEmpty(testCase, blk.prestimulus_time);
verifyTrue(testCase, isfield(blk, 'prestimulus_normalization'), ...
    'prestimulus_normalization must be PRESENT-but-empty, not absent');
verifyEmpty(testCase, blk.prestimulus_normalization);
end

function testParametersBasicMustNotRegainTheInventedReverseEdge(testCase)
% This class was the LARGEST instance of the invented-empty-edge pattern: 11,440
% documents, 100% of them carrying an empty, REQUIRED `stimulus_response_scalar_id`
% that NDI has the other way round (on the response, tuning_response.m:323-324).
% The schema repair landed; the migrator must not put it back.
out = runJ(parametersFixture());
b   = out.migrated{1}.toStruct();
verifyEmpty(testCase, depValue(b, 'stimulus_response_scalar_id'));
end

function testTheMigratedPairHasNoOrphanEdges(testCase)
% The gate that actually matters on a corpus. The four external referents
% (element, stimulator, presentation, control) are supplied as KnownIds -- they
% migrate in their own right with ids preserved (element.m promotes elements to
% subjects; control_stimulus_ids.m -> control_designation keeps base verbatim) --
% and the fifth, the parameters document, must resolve INSIDE the batch, which is
% exactly what re-homing the edge onto method_parameters_id depends on.
out = did2.convert.v1_to_v2({withEpochEdge(responseFixture('F1')), parametersFixture()}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);

% The SIXTH external referent is the `epoch` document the anchor points at. It is
% minted by did2.convert.epochMint by GROUPING on (session, epoch string) over the
% whole batch -- so like the other four it exists in a full migration and not in a
% two-document one, and like the other four it is supplied as a KnownId rather
% than fabricated into the batch. It is listed SEPARATELY here so that a reader
% can see it is our own second pass's product and not an NDI-side id.
report = did2.validate.references(out.migrated, 'KnownIds', ...
    [{'elem_9c027e', 'stim_5daa03', 'pres_b671ff', 'ctrl_20e84c'}, {epochDocId()}]);
% DENOMINATOR FIRST: an orphan count means nothing without the edges inspected.
verifyGreaterThanOrEqual(testCase, report.edges_examined, 6);
if report.orphan_count > 0
    verifyFail(testCase, sprintf('%d orphan edge(s), first: %s.%s -> %s', ...
        report.orphan_count, report.orphans(1).doc_class, ...
        report.orphans(1).edge_name, report.orphans(1).edge_document_id));
end
end

% ===================== validation ==========================================

function testFoldValidatesAgainstTheRealVEtaSchema(testCase)
% The only test here that proves the migrator and the schema agree. The other
% tests would pass just as happily against a harmonic_component_calculation that
% does not exist. Needs the assembled V_eta set on DID_SCHEMA_PATH (stable +
% draft + deprecated) -- the quick gate builds exactly that, and
% harmonic_component/_calculation are in the DRAFT tier, so a stable-only schema
% path will fail here rather than skip. Deliberate: a skip reads as success.
%
% This is also the only place the EPOCH ANCHOR meets the schema: branch 1 emits a
% `relative_reference` (V_eta/stable) whose `relative_to` names a document that is
% not in this batch. That validates -- +did2/+validate/references.m is not run by
% Validate, and `must_refer_to_document_class` is existence-only and declarative --
% and testMigratorsJIngested/testReferenceLiftValidatesUnderVEta already relies on
% exactly that, with the same fabricated epoch id.
out = did2.convert.v1_to_v2({withEpochEdge(responseFixture('F2')), parametersFixture()}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined under validation: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
% leaf + anchor + the passed-through parameters document
verifyEqual(testCase, numel(out.migrated), 3);
leaf = findClass(testCase, out, 'harmonic_component_calculation');
verifyEqual(testCase, leaf.get('base.id'), 'resp_412fa1');
verifyEqual(testCase, leaf.get('harmonic_component.value.harmonic'), 2);

% ...and no silent loss: no empty required edge, no vacuous required field on
% anything this fold emitted. Those two counters are the reason the husks of
% image_stack and fitcurve were ever found.
if isfield(out, 'silent_loss') && isfield(out.silent_loss, 'total_docs')
    % DENOMINATOR FIRST -- silentLoss printed zeros for two days while reading
    % nothing, so a zero is only evidence once total_docs is non-zero.
    verifyEqual(testCase, out.silent_loss.total_docs, 3);
    verifyEqual(testCase, out.silent_loss.skipped_docs, 0);
    verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
    verifyEqual(testCase, out.silent_loss.vacuous_field_count, 0);
    % time_reference_# declares min_count 1 on subject_interaction; the leaf
    % carries exactly one, and derived_from_# has no maximum.
    verifyEqual(testCase, out.silent_loss.family_violation_count, 0);
end
end

% ===================== helpers =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function h = harmonicOf(testCase, responseType)
out  = runJ(withEpochEdge(responseFixture(responseType)));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
h    = leaf.get('harmonic_component.value.harmonic');
end

function tf = anyClass(out, className)
%ANYCLASS Whether the batch contains a document of CLASSNAME. Distinct from
%   findClass, which FAILS when it does not -- this one is for asserting absence.
tf = false;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        tf = true;
        return;
    end
end
end

function doc = findClass(testCase, out, className)
doc = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        doc = out.migrated{k};
        return;
    end
end
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
% assertFail, not verifyFail: verifyFail records the failure and CONTINUES, and
% the caller would then dereference an empty doc and report a MATLAB error
% instead of the real one.
assertFail(testCase, sprintf('no "%s" among {%s}', className, strjoin(names, ', ')));
end

function v = depValue(b, name)
% Read an edge off a RAW BODY STRUCT, tolerant of BOTH spellings. A depends_on
% entry is `value` on a body a migrator built and `document_id` once
% universalRenames has normalised it, and both shapes are live in one batch here:
% the leaf's edges were built by the migrator, the passthrough's came through the
% rename. Precedence copied from +did2/+validate/references.m.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    if ~strcmp(b.depends_on(k).name, name)
        continue;
    end
    if isfield(b.depends_on(k), 'document_id') && ~isempty(b.depends_on(k).document_id)
        v = b.depends_on(k).document_id;
    elseif isfield(b.depends_on(k), 'value')
        v = b.depends_on(k).value;
    end
    return;
end
end
