function tests = testMigratorsJStimulusResponseGroundTruth
%TESTMIGRATORSJSTIMULUSRESPONSEGROUNDTRUTH #61, the parts nothing else pins.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   not one line below has been run. The NDI writer citations were each verified
%   against `git show origin/main:...` and the schema facts against the built
%   V_eta set, but "verified against the source" is not "the test passed". The
%   quick gate (test-migrators-quick.yml) is the first thing entitled to an
%   opinion; read a failure here as a question about the assertion as readily as
%   about the code.
%
%   A SECOND file for the stimulus response family, deliberately. Its sibling
%   `testMigratorsJStimulusResponse.m` asserts the TRANSFORM -- that the fold
%   produces a harmonic_component_calculation with the right edges and the right
%   value. This file asserts three things that survive review only if somebody
%   writes them down:
%
%     1. WHAT THE FOLD DOES TO THE TWO EPOCH STRINGS. `stimulator_epochid` does
%        not survive it and is recoverable; `element_epochid` was not recoverable
%        from anything, which is why section 1 of this file originally PINNED ITS
%        LOSS and said in its own words "WHEN THAT DECISION IS TAKEN THIS TEST
%        MUST BE INVERTED, not deleted". The decision has been taken and built
%        (stimulus_response_scalar.m:259-263 + :306-310 + :328-369, 2026-08-10):
%        the fold is GATED on an `epoch` document and, when one exists, the
%        string becomes a `relative_reference` anchored to it. The test is
%        inverted below, not relaxed and not deleted.
%     2. THAT AN F2 DOCUMENT SURVIVES VALIDATION. `freq_response` was declared
%        `integer {min:0, max:1}` -- a bound that would reject roughly a third of
%        the class -- and was inert only because the validator reads
%        `minimum`/`maximum`. The bound has now been repaired schema-side. A
%        schema test proves the JSON changed; only a validating round-trip proves
%        a real F2 document passes.
%     3. WHAT PASS 1 DOES TO THE DOCUMENT COUNT. The signed plan's arithmetic
%        table describes the END state, after the resolver deletes the parameters
%        documents. Pass 1 does the opposite: it ADDS an anchor per response and
%        deletes nothing. A corpus run read against the plan's table will look
%        like a regression unless the expectation is written down -- and until the
%        epoch mint runs, the gate in 1. means pass 1 does not even do THAT, so
%        both arithmetics are pinned.
%
%   THE EPOCH GATE, AND WHY MOST FIXTURES BELOW ARE STAMPED. The fold now refuses
%   to run on an `element_epochid` string with no `epoch` document behind it, so a
%   test that asserts what the fold produces must supply one. `withEpochEdge`
%   stamps the same `epoch_id` edge `did2.convert.epochMint` stamps (epochMint.m:409,
%   `b = setDep(b, 'epoch_id', epochIdByKey(key))`) and
%   `+migrators_j/private/jEpochDocId.m` reads. NO did_v1 DOCUMENT CARRIES IT: it
%   is our own second pass's product, which is why it is written at the call site
%   and not into the writer-derived fixture.
%
%   EVERY FIXTURE IS BUILT FROM THE WRITER. NDI-matlab
%   `+ndi/+app/+stimulus/tuning_response.m` on origin/main, verified with
%   `git show origin/main:src/ndi/+ndi/+app/+stimulus/tuning_response.m`:
%
%     :202   freq_response_commands = [0 1 2]   the DEFAULT sweep, so one
%                                               recording yields THREE documents
%     :204   freq_response_commands = 0         when no stimulus has a
%                                               fundamental frequency
%     :207   freq_response_commands = freq_response    CALLER-SUPPLIED, unbounded
%     :260   freq_response = freq_response_commands(f)
%     :262-266  response_type = 'mean' | ['F' int2str(freq_response)]
%     :276-281  the parameters document, from six locals via vlt.data.var2struct
%     :309-313  the responses sub-struct, five parallel per-trial row vectors
%     :315      struct('response_type', ..., 'responses', ...)
%     :317-318  stimulus_response block:
%                  stimulator_epochid = stim_doc...epochid.epochid
%                  element_epochid    = ts_epoch_timeref.epoch
%     :320-328  the document + all FIVE depends_on, unconditionally
%
%   ***** UNVERIFIED: THESE TESTS HAVE NEVER BEEN EXECUTED. *****
%   There is no MATLAB in the environment they were written in. Treat the first
%   CI run as the first real evidence, and read a failure here as a question
%   about the assertion as readily as about the code.
%
%   Run with:
%     results = runtests('did2.unittest.testMigratorsJStimulusResponseGroundTruth');

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
% The parameters edge points at the document THIS harmonic's parameters live on
% (the writer dedups parameter documents by freq_response -- :269-272 searches
% `..._basic.freq_response` with `exact_number` and only builds one at :276-281
% when that search comes back empty), so a batch
% of the three responses plus the three parameters documents is self-consistent.
v1.depends_on = struct( ...
    'name',  {'stimulus_response_scalar_parameters_id', 'element_id', ...
              'stimulus_presentation_id', 'stimulus_control_id', 'stimulator_id'}, ...
    'value', {sprintf('param_gt%d', harmonicFor(responseType)), ...
              'elem_gt01', 'pres_gt01', 'ctrl_gt01', 'stim_gt01'});
v1.base = struct('id', ['resp_' responseType], 'session_id', 'sess_gt', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
% :317-318. The two epoch strings are DIFFERENT here on purpose: the stimulator
% and the element are different devices with independent epoch numbering, which
% is the entire reason NDI has a syncgraph. A fixture that used one value for
% both would make the recoverability argument look true by construction.
v1.stimulus_response = struct('stimulator_epochid', 't00003', ...
    'element_epochid', 't00017');
v1.stimulus_response_scalar = struct('response_type', responseType, ...
    'responses', struct( ...
        'stimid',                     [1 2 3], ...
        'response_real',              [2.10 5.44 1.02], ...
        'response_imaginary',         [0.31 -1.20 0.08], ...
        'control_response_real',      [0.42 0.42 0.42], ...
        'control_response_imaginary', [0.01 0.01 0.01]));
end

function v1 = withEpochEdge(v1)
%WITHEPOCHEDGE Stamp the `epoch_id` edge that opens the fold's epoch gate.
%   See the header. The id is deliberately unlike either epoch string, so
%   testTheDroppedStringIsNotSilentlyReplacedByTheStimulatorOne cannot be fooled
%   by the stamp itself.
v1.depends_on(end+1) = struct('name', 'epoch_id', 'value', epochDocId());
end

function id = epochDocId()
%EPOCHDOCID The one stamped epoch document id, named once. It stands for the
%   `epoch` document epochMint would have minted for (sess_gt, 't00017') -- the
%   ELEMENT's epoch, which is the one the gate is about.
id = 'epochdoc_gt7a34';
end

function v1 = parametersFixture(freqResponse)
%PARAMETERSFIXTURE A did_v1 stimulus_response_scalar_parameters_basic (:276-281)
%   with the writer's in-function defaults (:172-177). FREQRESPONSE is the
%   harmonic index the writer stored for this document (:260).
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_response_scalar_parameters_basic', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'stimulus_response_scalar_parameters', ...
                             'class_version', '1.0.0')]);
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', sprintf('param_gt%d', freqResponse), 'session_id', 'sess_gt', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.stimulus_response_scalar_parameters_basic = struct( ...
    'temporalfreqfunc', 'ndi.fun.stimulustemporalfrequency', ...
    'freq_response', freqResponse, ...
    'prestimulus_time', [], ...
    'prestimulus_normalization', [], ...
    'isspike', 1, ...
    'spiketrain_dt', 0.001);
end

% ============ 1. WHAT THE FOLD DESTROYS ====================================

function testStimulatorEpochidIsDroppedAndTheRecoveryPathIsRealNotAsserted(testCase)
% `stimulator_epochid` does not survive the fold, and that is the DEFENSIBLE
% half of the deletion. The writer sets it (:317) from
% `stim_doc.document_properties.epochid.epochid` -- it is a COPY of the
% presentation's own epoch id, not an independent fact. NDI's
% stimulus_presentation.json declares `epochid` as a superclass, so the
% presentation document carries the same string in its own right, and the leaf
% points at that document as derived_from_1.
%
% The test therefore checks BOTH halves: the string is gone from the leaf, AND
% the edge that makes it recoverable is present. Asserting only the first would
% be recording a loss; asserting only the second would be assuming a recovery.
%
% STAMPED: the fold only runs when an `epoch` document exists (the gate), and
% this test is about what the FOLD does.
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
s    = leaf.toStruct();

verifyFalse(testCase, isfield(s, 'stimulus_response'));
verifyEqual(testCase, depValue(s, 'derived_from_1'), 'pres_gt01');
end

function testElementEpochidIsCarriedAsAnEpochAnchorAndNeverSilentlyDropped(testCase)
% *********************************************************************
% THE INVERSION THIS TEST'S PREDECESSOR ASKED FOR, 2026-08-10.
% *********************************************************************
% This test used to be `testElementEpochidIsDESTROYEDAndNothingCarriesIt`, and
% it PINNED A DATA LOSS while saying, in its own last paragraph: "WHEN THAT
% DECISION IS TAKEN THIS TEST MUST BE INVERTED, not deleted." The decision has
% been taken and built, so it is inverted here rather than relaxed to whatever
% the code now does.
%
% What has not changed: `element_epochid` is the OTHER epoch string and it is not
% a copy of anything. The writer sets it (:318) from `ts_epoch_timeref.epoch` --
% the epoch of the ELEMENT's own timeseries -- and the signed plan says
% "`element_epochid` comes from `ts_epoch_timeref.epoch` and is recoverable from
% nothing." A dropped source field is seen by NO counter we have: silentLoss
% counts empty edges, vacuous required fields and fragments, and a field that is
% simply absent is none of the three. So the string needs a test either way.
%
% What HAS changed is the migrator (stimulus_response_scalar.m):
%   :259-263  GUARD 4 -- an epoch string with no `epoch` document SUPPRESSES the
%             fold, so the string leaves in the passthrough rather than being
%             deleted. That is the branch every did_v1 document takes today and
%             testStimulusResponseEpochGuard pins it.
%   :306-310  with an `epoch` document, `time_reference_1` is RETARGETED at a
%             `relative_reference` whose `relative_to` IS that epoch.
% Both branches carry the fact. Neither drops it. THERE IS NO LONGER A BRANCH ON
% WHICH THIS STRING IS DESTROYED -- if a future change reintroduces one, this
% test is the thing that must be made to fail first.
out  = runJ(withEpochEdge(responseFixture('F1')));
leaf = findClass(testCase, out, 'harmonic_component_calculation');
s    = leaf.toStruct();

% The leaf itself still carries no epoch STRING, under any spelling -- the fold
% moves the fact onto the anchor rather than parking a string on the statement.
verifyFalse(testCase, isfield(s, 'stimulus_response'));
verifyFalse(testCase, isfield(s.subject_statement, 'element_epochid'));
verifyFalse(testCase, isfield(s.subject_interaction, 'element_epochid'));
% not smuggled into the parameters block either -- that block is reserved for
% the resolver and must stay empty beside the edge
verifyEmpty(testCase, fieldnames(s.subject_interaction.method_parameters));

% ...and the fact is on the ANCHOR, as an edge to the epoch document. The old
% assertion here was that the anchor is ordinal ('during' the session) and so NOT
% a substitute for an epoch-relative reference; that is exactly what has been
% fixed, so the session anchor must now be ABSENT.
verifyFalse(testCase, anyClass(out, 'session_relative_reference'));
ref = findClass(testCase, out, 'relative_reference');
a   = ref.toStruct();
verifyEqual(testCase, depValue(a, 'relative_to'), epochDocId());
verifyEqual(testCase, depValue(s, 'time_reference_1'), a.base.id);
verifyFalse(testCase, isfield(a, 'stimulus_response'));

% the string IS present on the input, so a drop would have been a real drop and
% not an empty source
src = responseFixture('F1');
verifyEqual(testCase, src.stimulus_response.element_epochid, 't00017');
end

function testWithoutTheEpochDocumentTheStringLeavesInThePassthrough(testCase)
% THE OTHER HALF OF THE INVERSION, and the branch every did_v1 document in every
% corpus takes today: no `epoch` document, so guard 4 suppresses the fold and the
% source document goes through whole with BOTH strings on it. Without this the
% file would only describe a branch production data does not reach.
out = runJ(responseFixture('F1'));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'stimulus_response_scalar');
verifyEqual(testCase, d.get('stimulus_response.element_epochid'), 't00017');
verifyEqual(testCase, d.get('stimulus_response.stimulator_epochid'), 't00003');
verifyFalse(testCase, anyClass(out, 'harmonic_component_calculation'));
end

function testTheDroppedStringIsNotSilentlyReplacedByTheStimulatorOne(testCase)
% A plausible-looking "fix" would be to keep whichever epoch string is present
% and call it the epoch. The two are different devices' epoch numbering
% (t00003 vs t00017 in this fixture), so conflating them would attribute the
% response to the wrong stretch of recording. If a future change starts carrying
% an epoch, this test says which one it must NOT be.
%
% Now that the fold DOES carry an epoch (as an edge to an `epoch` document), the
% check is run over the WHOLE emitted batch rather than the leaf alone: the
% anchor is where an epoch could plausibly be smuggled in as a literal, and the
% stamped document id is deliberately unlike both strings so the stamp itself
% cannot satisfy the assertion.
out = runJ(withEpochEdge(responseFixture('F1')));
verifyGreaterThanOrEqual(testCase, numel(out.migrated), 2);   % DENOMINATOR
for k = 1:numel(out.migrated)
    flat = lower(jsonencode(out.migrated{k}.toStruct()));
    verifyEmpty(testCase, strfind(flat, 't00003'), ...
        out.migrated{k}.get('document_class.class_name'));
    verifyEmpty(testCase, strfind(flat, 't00017'), ...
        out.migrated{k}.get('document_class.class_name'));
end
% and the epoch that IS carried is carried by REFERENCE, to the element's epoch
ref = findClass(testCase, out, 'relative_reference');
verifyEqual(testCase, depValue(ref.toStruct(), 'relative_to'), epochDocId());
end

% ============ 2. THE F2 DOCUMENT, THROUGH VALIDATION ========================

function testAnF2ParametersDocumentValidates(testCase)
% REPAIR 4 of the signed plan, end to end.
%
% `freq_response` was declared `integer {min: 0, max: 1}` and documented "1 if
% this scalar response is a frequency-domain measurement, 0 otherwise". It is
% the HARMONIC INDEX: tuning_response.m:202 sweeps [0 1 2] by default, so
% roughly a third of the 11,440 corpus documents carry freq_response = 2, and
% `max: 1` is a claim that would reject every one of them.
%
% It never fired because +did2/+schema/cache.m validateConstraints (:1340)
% switches on maxLength|minLength|minimum|maximum|enum and its `otherwise`
% branch silently tolerates unrecognised keys -- so `min`/`max` were INERT. The
% bound and the key were BOTH wrong, and fixing only the key would have
% quarantined a third of the class. Both are repaired; this is the round-trip
% that proves a real F2 document passes.
out = did2.convert.v1_to_v2({parametersFixture(2)}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('F2 parameters document quarantined: %s', ...
        out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get( ...
    'stimulus_response_scalar_parameters_basic.freq_response'), 2);
end

function testTheThreeHarmonicsOfOneRecordingAllValidate(testCase)
% freq_response_commands = [0 1 2] (:202) -- one recording, three parameters
% documents and three responses. All three must pass, which is a stronger claim
% than any one of them passing: 0 is the old lower bound, 1 the old upper bound,
% and 2 the value the old declaration excluded.
batch = {parametersFixture(0), parametersFixture(1), parametersFixture(2)};
out = did2.convert.v1_to_v2(batch, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 3);
end

function testTheThreeResponseTypesFoldToTheThreeHarmonics(testCase)
% The response side of the same sweep, through validation. 'mean' is not a
% fourth kind of thing -- it is harmonic 0 (:262-263) -- which is the reason the
% class is `harmonic_component` and not a response-type enum.
expected = containers.Map({'mean', 'F1', 'F2'}, {0, 1, 2});
keys_ = expected.keys();
for k = 1:numel(keys_)
    rt  = keys_{k};
    % STAMPED: the fold is gated on an `epoch` document, and this test is about
    % what the fold produces. Under validation the batch is leaf + the
    % `relative_reference` anchor, and the anchor's `relative_to` names a
    % document outside the batch -- which validates, because
    % must_refer_to_document_class is existence-only and declarative and
    % +did2/+validate/references.m is not run by Validate.
    out = did2.convert.v1_to_v2({withEpochEdge(responseFixture(rt))}, ...
        'Validate', true, 'TargetVersion', 'V_eta');
    if ~isempty(out.quarantine)
        verifyFail(testCase, sprintf('response_type %s quarantined: %s', ...
            rt, out.quarantine(1).reason));
    end
    leaf = findClass(testCase, out, 'harmonic_component_calculation');
    verifyEqual(testCase, leaf.get('harmonic_component.value.harmonic'), ...
        expected(rt), sprintf('response_type %s', rt));
end
end

% ============ 3. WHAT PASS 1 DOES TO THE DOCUMENT COUNT =====================

function testPassOneGrowsTheCorpusAndDeletesNothing(testCase)
% DENOMINATOR FIRST. One recording as the writer produces it: three responses
% (freq_response_commands = [0 1 2], :202) plus the three parameters documents
% they point at, six v1 documents in.
%
% Out: three leaves + three anchors + three passed-through parameters documents
% = NINE. Pass 1 ADDS 50% and deletes nothing.
%
% The signed plan's arithmetic table reads
%
%     documents (5 corpora)   21,564 -> 10,124   -11,440
%
% and that is the END state, AFTER the resolver inlines the parameters and the
% verify-before-delete gate lets them go. Reading a corpus run against that
% table would make a correct pass 1 look like a 3x regression. Written down here
% so the first corpus number is read against the right expectation.
%
% TWO arithmetics, because the epoch gate makes the answer depend on whether the
% epoch mint has run. This block is the AFTER: an `epoch` document exists, so the
% fold runs and the anchor is a `relative_reference`.
batch = {withEpochEdge(responseFixture('mean')), ...
         withEpochEdge(responseFixture('F1')), ...
         withEpochEdge(responseFixture('F2')), ...
         parametersFixture(0), parametersFixture(1), parametersFixture(2)};
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 9);

counts = classCounts(out);
verifyEqual(testCase, counts('harmonic_component_calculation'), 3);
verifyEqual(testCase, counts('relative_reference'), 3);
verifyEqual(testCase, counts('stimulus_response_scalar_parameters_basic'), 3);
verifyFalse(testCase, counts.isKey('session_relative_reference'));
% the parameters documents are UNCONVERTED, and that count is the standing
% signal that the resolver is still owed
verifyEqual(testCase, out.summary.unconverted_count, 3);
end

function testTodayTheGateMakesPassOneANoOpForThisFamily(testCase)
% THE BEFORE, and the number a corpus run reports RIGHT NOW. The same six v1
% documents with no `epoch` document behind them: the three responses are
% suppressed by guard 4 and pass through, the three parameters documents pass
% through as they always did, and the count does not move at all -- SIX in, SIX
% out, nothing minted, nothing deleted, all six unconverted.
%
% This is not a duplicate of the test above; it is the other half of the same
% expectation, and it is the half that matches every corpus number until
% did2.convert.epochMint's migrator side lands. Reading a run against the 9 above
% would look like the fold had silently stopped working.
batch = {responseFixture('mean'), responseFixture('F1'), responseFixture('F2'), ...
         parametersFixture(0), parametersFixture(1), parametersFixture(2)};
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 6);

counts = classCounts(out);
verifyFalse(testCase, counts.isKey('harmonic_component_calculation'));
verifyFalse(testCase, counts.isKey('relative_reference'));
verifyFalse(testCase, counts.isKey('session_relative_reference'));
verifyEqual(testCase, counts('stimulus_response_scalar'), 3);
verifyEqual(testCase, counts('stimulus_response_scalar_parameters_basic'), 3);
verifyEqual(testCase, out.summary.unconverted_count, 6);
end

% ============ the empty-but-present edge ===================================

function testAnEdgeThatIsPresentButEmptyIsNotCarriedForward(testCase)
% Distinct from the sibling file's test, which DELETES the depends_on entries.
% NDI's templates initialise every edge to `[]` or `""`
% (stimulus_response.json), so the shape a real degraded document takes is the
% entry PRESENT with an empty value, not the entry absent. Both paths must reach
% the same place: no edge at all on the leaf.
%
% An edge present with an empty value is the 26,406-document pattern exactly --
% +did2/+validate/references.m:90 skips it, so it is a fact that looks recorded
% and is not.
v1 = withEpochEdge(responseFixture('F1'));
v1 = emptyEdge(v1, 'stimulator_id');
v1 = emptyEdge(v1, 'stimulus_control_id');
out  = runJ(v1);
leaf = findClass(testCase, out, 'harmonic_component_calculation');
b    = leaf.toStruct();

verifyFalse(testCase, any(strcmp({b.depends_on.name}, 'instrument_id')));
verifyFalse(testCase, any(strcmp({b.depends_on.name}, 'derived_from_2')));
% every edge that IS present carries a value -- no empty ones anywhere
for k = 1:numel(b.depends_on)
    verifyNotEmpty(testCase, b.depends_on(k).value, b.depends_on(k).name);
end
end

function testAnEmptyElementIdEdgePassesThroughLikeAMissingOne(testCase)
% The subject guard, reached by the empty-value path rather than the absent one.
% A leaf whose subject_id is empty is a calculation about nobody, and it would
% validate clean -- the image_stack husk, 4,563 documents.
% STAMPED, so the subject guard is the only guard that can fire: unstamped, the
% epoch gate would produce this same passthrough and the test would pass with the
% subject guard deleted.
v1 = emptyEdge(withEpochEdge(responseFixture('F1')), 'element_id');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'stimulus_response_scalar');
end

% ===================== helpers =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function h = harmonicFor(responseType)
%HARMONICFOR The writer's own mapping, inverted (tuning_response.m:262-266).
switch responseType
    case 'mean', h = 0;
    case 'F1',   h = 1;
    case 'F2',   h = 2;
    otherwise,   h = -1;   % only reached by a fixture testing the guard
end
end

function v1 = emptyEdge(v1, name)
%EMPTYEDGE Blank an edge's VALUE while leaving the entry in place -- the shape a
%   real degraded did_v1 document takes, since NDI's templates initialise every
%   edge to [] or "". Distinct from deleting the entry.
idx = find(strcmp({v1.depends_on.name}, name), 1);
if ~isempty(idx)
    v1.depends_on(idx).value = '';
end
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

function counts = classCounts(out)
counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(out.migrated)
    cn = out.migrated{k}.get('document_class.class_name');
    if counts.isKey(cn)
        counts(cn) = counts(cn) + 1;
    else
        counts(cn) = 1;
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
% Read an edge off a RAW BODY STRUCT, tolerant of BOTH spellings: a depends_on
% entry is `value` on a body a migrator built and `document_id` once
% universalRenames has normalised it. Precedence copied from
% +did2/+validate/references.m.
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
