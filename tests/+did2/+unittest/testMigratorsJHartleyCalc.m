function tests = testMigratorsJHartleyCalc
%TESTMIGRATORSJHARTLEYCALC The receptive-field fold: `hartley_calc` -> a
%   `receptive_field_calculation` leaf + two plane bodies + a spike-time input
%   body, and the guards that stop it folding something it cannot justify.
%
%   STATUS: NEVER RUN LOCALLY. `command -v matlab octave` exits 1 in the
%   container these were written in, so every assertion below is UNEXECUTED
%   here. CI is the first execution. Treat a green run as the evidence, not this
%   file.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST
%   ---------------------------------------------------------------------
%   DID-schema V_eta_ngrid_family_findings.md, TEAM-SIGN-OFF [receptive field
%   fold] + [receptive field naming], jess@walthamdatascience.com / 2026-08-17.
%   The migrator's own header quotes it in full; the tests below pin the parts
%   that are checkable without a corpus.
%
%   ---------------------------------------------------------------------
%   PROVENANCE OF THE FIXTURE -- IT IS A REAL DOCUMENT, MEASURED
%   ---------------------------------------------------------------------
%   `hartleyCalcV1()` is the shape of the 210 real `hartley_calc` documents in
%   corpus 20211116, read off the unpacked corpus rather than from any DID-side
%   schema (the ground-truth rule: fixtures are built from the writer, never
%   from our own schema). Every structural fact it asserts was counted across
%   all 210:
%
%     DENOMINATOR: 1220 json file(s) in the corpus; 210 of class `hartley_calc`
%       210  blocks = app, base, depends_on, document_class, files,
%            hartley_calc, hartley_reverse_correlation, ngrid, reverse_correlation
%       210  ngrid = {data_size 8, data_type 'double', data_dim [200 200 36 2],
%            coordinates (436 values)}
%       210  reverse_correlation = {method 'Hartley', dimension_labels ''}
%       210  hartley_calc.input_parameters = {T (36), X_sample 1, Y_sample 1}
%       210  hartley_reverse_correlation = {stimulus_properties (8 keys),
%            reconstruction_properties {T_coords 36, X_coords 200, Y_coords 200},
%            hartley_numbers {S, KXV, KYV, ORDER}, spiketimes, frameTimes}
%       210  depends_on = {element_id, stimulus_presentation_id}, BOTH non-empty
%       210  files.file_list = {'hartley_results.ngrid'}
%       210  coordinates segmented [36 200 200] == (T_coords, X_coords, Y_coords)
%       210  X_coords == 1..200 and Y_coords == 1..200
%       210  T == reconstruction_properties.T_coords
%       210  len(frameTimes) == 3360 == len(hartley_numbers.KXV)
%
%   THE REAL EXTENTS ARE USED, NOT SHRUNK ONES. [200 200 36 2] is 436
%   coordinate values and 3,360 frame times -- cheap to build and the only way
%   the "436 against a data_dim summing to 438" arithmetic the signature turns
%   on is actually exercised. Only `spiketimes` is shortened, and deliberately:
%   its length is genuinely per-document (194 distinct values across the 210,
%   from 4 to 13,379), so no single length would be more real than another.
%
%   THE T VECTOR IS THE REAL ONE, VERBATIM, INCLUDING ITS FLOATING-POINT NOISE.
%   That is load-bearing for testTheLagAxisCarriesItsValuesRatherThanASpacing:
%
%     DENOMINATOR: 210 hartley_calc document(s); 1 distinct T vector
%     T reproducible EXACTLY by origin -0.1 + k*0.01 :  0 of 210
%     6 of the 36 entries differ at the ulp (T(25) = 0.14 vs 0.13999999999999999)
%
%   so a regular axis would hand back different doubles from the stored ones,
%   and `values` is the lossless carry rather than a stylistic choice. A fixture
%   built from `-0.1:0.01:0.25` would make that test pass for the wrong reason.
%
%   FIELD NAMES ARE THE POST-`universalRenames` SPELLINGS, because that is what
%   a migrator is handed. The one field that moves is `frameTimes` ->
%   `frame_times`: universalRenames snake_cases block keys and the field names
%   ONE level inside each block and nothing deeper, so `T_coords`, `K_max` and
%   `KXV` arrive verbatim.

tests = functiontests(localfunctions);
end

% ===================== the shape ===========================================

function testTheFoldEmitsTheLeafTheTwoPlanesAndTheSpikeInput(testCase)
% 1 -> 6: the leaf, the session anchor every calculator fold carries, the
% `software` entity the app block becomes, TWO plane bodies and ONE input body.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 6, ...
    sprintf('expected 6 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyEqual(testCase, sum(strcmp(names, 'receptive_field_calculation')), 1);
verifyEqual(testCase, sum(strcmp(names, 'sampled_body')), 3, ...
    'two planes plus the spike-time input body');
verifyEqual(testCase, sum(strcmp(names, 'session_relative_reference')), 1);
verifyEqual(testCase, sum(strcmp(names, 'software')), 1);
end

function testTheLeafIsTheSignedClassAndItsSuperclassPair(testCase)
% TEAM-SIGN-OFF [receptive field naming]: the composite is `receptive_field`
% and the leaf is `receptive_field_calculation`. The method is NOT in the name
% -- T11 says a name reading as how it was made is a smell -- so this also pins
% that no class called `spike_triggered_average` or `hartley_receptive_field`
% is emitted.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
supers = {leaf.document_class.superclasses.class_name};
verifyTrue(testCase, ismember('subject_calculation', supers));
verifyTrue(testCase, ismember('receptive_field', supers));
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyFalse(testCase, any(contains(names, 'hartley')), ...
    'the method must not appear in any emitted class name (T11)');
verifyFalse(testCase, any(contains(names, 'spike_triggered')));
end

% ===================== the calculator contract =============================

function testTheSourceIdIsPRESERVEDOnTheLeafAndOnNothingElse(testCase)
% THE CALCULATOR RULE, and it is the expensive one: dissolution changes the id
% and every inbound reference dangles. Soph went red with 11,448 such orphans.
% The id lands on EXACTLY ONE emitted body, or a follower cannot tell which.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
verifyEqual(testCase, pick(out, 'receptive_field_calculation').base.id, 'hc_1');
carriers = 0;
for k = 1:numel(out)
    if isfield(out{k}, 'base') && isfield(out{k}.base, 'id') ...
            && strcmp(out{k}.base.id, 'hc_1')
        carriers = carriers + 1;
    end
end
verifyEqual(testCase, carriers, 1, ...
    'the source id must land on exactly one emitted body');
end

function testElementIdBecomesSubjectIdAndThePresentationBecomesDerivedFrom(testCase)
% `element_id` IS a subject edge -- +migrators_j/element.m promotes elements to
% subjects with their ids PRESERVED. The presentation is provenance, not a
% subject, so it takes the `derived_from_1` slot subject_calculation declares.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
verifyEqual(testCase, depValueOf(leaf, 'subject_id'), 'elem_7');
verifyEqual(testCase, depValueOf(leaf, 'derived_from_1'), 'pres_3');
verifyNotEmpty(testCase, depValueOf(leaf, 'time_reference_1'));
verifyNotEmpty(testCase, depValueOf(leaf, 'software_id'));
end

function testEveryEmittedEdgeIsNonEmpty(testCase)
% THE INVENTED-EMPTY-EDGE SWEEP, with its DENOMINATOR asserted first --
% without that an empty `out` would make this vacuously true.
% `RequiredDependencies` is ARMED BY DEFAULT (+did2/+schema/cache.m:72), so an
% empty required edge QUARANTINES; an empty OPTIONAL one validates clean and is
% invisible, which is the 7,233-document pattern. Neither is emitted here.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
edges = 0;
for k = 1:numel(out)
    if ~isfield(out{k}, 'depends_on'); continue; end
    d = out{k}.depends_on;
    for j = 1:numel(d)
        edges = edges + 1;
        verifyNotEmpty(testCase, d(j).value, sprintf( ...
            'body %d (%s) declares edge `%s` with an empty value', ...
            k, out{k}.document_class.class_name, d(j).name));
    end
end
verifyGreaterThanOrEqual(testCase, edges, 7, ...
    ['DENOMINATOR: the sweep must actually see edges -- 4 on the leaf ' ...
     '(subject_id, time_reference_1, derived_from_1, software_id) and 1 ' ...
     'statement edge on each of the 3 bodies, plus derived_from_1 on the ' ...
     'spike body']);
end

function testTheSubjectEdgeIsNeverEmittedBlank(testCase)
% THE HUSK TEST. An empty `subject_id` is mustBeNonEmpty and would quarantine,
% but a migrator that emits one has already thrown away the fact -- and before
% #37 was armed it validated clean, which is how 4,563 image_observations about
% nobody went unnoticed for months. Read through `.document_id`, the second
% spelling jCarrySubject accepts, so the reader divergence that produced that
% husk cannot come back through this migrator.
v1 = hartleyCalcV1();
v1.depends_on = struct('name', {'element_id', 'stimulus_presentation_id'}, ...
    'document_id', {'elem_7', 'pres_3'});
out = did2.convert.migrators_j.hartley_calc(v1);
verifyEqual(testCase, ...
    depValueOf(pick(out, 'receptive_field_calculation'), 'subject_id'), 'elem_7');
end

% ===================== the composite value =================================

function testTheMethodIsABoundTermOnTheCompositeAndTwoPlanesAreDeclared(testCase)
% `reverse_correlation.method` -> receptive_field.value.method, 'Hartley' in
% 210 of 210. `planes` is mustBeNonEmpty and is declared as one entry per
% emitted body IN EMISSION ORDER, so its length must equal the number of plane
% bodies -- a mismatch would silently mis-pair a reader's plane names.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
value = pick(out, 'receptive_field_calculation').receptive_field.value;
verifyEqual(testCase, value.method.name, 'Hartley');
verifyEqual(testCase, value.storage_mode, 'body');
verifyEqual(testCase, numel(value.planes), 2);
verifyEqual(testCase, ...
    arrayfun(@(p) p.quantity.name, value.planes, 'UniformOutput', false), ...
    {'response estimate', 'significance'});
end

function testTheStatementSaysTheValueIsBodyBackedAndCarriesTheEncoding(testCase)
% D1: one home for a body-backed value. jCalculation seeds `inline`, which is
% right for the twelve calculators whose result is a small matrix and wrong
% here (a plane is 200x200x36 doubles). And `ngrid.data_type` is real source
% data, so it lands on the STATEMENT with its source spelling beside it.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
st = pick(out, 'receptive_field_calculation').subject_statement;
verifyEqual(testCase, st.storage_mode, 'body');
verifyEqual(testCase, st.datum_type, 'float64');
verifyEqual(testCase, st.source_datum_type, 'double');
end

% ===================== the two plane bodies ================================

function testEachPlaneBodyDescribesOnePlaneAndNotTheStack(testCase)
% THE ARITHMETIC THE SIGNATURE TURNS ON: data_dim is [200 200 36 2] and sums to
% 438, while `coordinates` has 436 values -- so the length-2 dimension has NO
% coordinates, which is the writer saying in the data that it is not an axis.
% Two bodies of three axes each, never one body with a fourth axis of length 2.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
planes = planeBodies(out);
verifyEqual(testCase, numel(planes), 2);
for k = 1:numel(planes)
    ax = planes{k}.sampled_body.axes;
    verifyEqual(testCase, numel(ax), 3, ...
        'three axes per plane -- the trailing 2 is a plane count, not an axis');
    verifyEqual(testCase, [ax.n], [200 200 36]);
end
end

function testTheLagAxisCarriesItsValuesRatherThanASpacing(testCase)
% THE COORDINATE CARRY. The lag axis is `regular = false` with the stored
% doubles in `values`; the two index axes stay regular because their
% coordinates ARE 1..200 and `n` already says so.
%
% NOT A STYLISTIC CHOICE. The stored T is not reproducible from origin+spacing:
% 6 of its 36 entries differ at the ulp from -0.1 + k*0.01 (0 of 210 documents
% reproduce exactly). The fixture carries the real vector, so a regular axis
% here would fail this assertion rather than pass it by luck.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
ax = planeBodies(out); ax = ax{1}.sampled_body.axes;
verifyEqual(testCase, [ax.regular], [true true false]);
verifyEqual(testCase, ax(1).origin.value, 1);
verifyEqual(testCase, ax(1).spacing.value, 1);
verifyEqual(testCase, ax(3).values.values, realLagVector());
verifyEqual(testCase, ax(3).values.source_values, realLagVector());
verifyEmpty(testCase, fieldnames(ax(3).origin), ...
    'an irregular axis has no origin -- it has values');
end

function testTheLagAxisIsNamedAndTheTwoSpatialAxesAreNotGuessed(testCase)
% The lag axis is named on POSITIVE EVIDENCE: its coordinates equal
% `hartley_calc.input_parameters.T`, the reverse-correlation lag vector, in 210
% of 210. Nothing distinguishes X from Y -- both coordinate vectors are the
% identical default index vector, both dims are 200, and
% `reverse_correlation.dimension_labels` (the field whose job is to name the
% axes) is '' in 210 of 210. So they stay positional. `axes[].variable` is
% queryable, and a guess recorded there is a guess recorded as a fact.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
ax = planeBodies(out); ax = ax{1}.sampled_body.axes;
verifyEqual(testCase, ...
    arrayfun(@(a) a.variable.name, ax, 'UniformOutput', false), ...
    {'axis_1', 'axis_2', 'lag'});
end

function testBothPlanesNameTheSourceFileAndSayWhichPlaneTheyAre(testCase)
% ONE FILE, TWO BODIES, SAID OUT LOUD. The v1 document attaches a single
% `hartley_results.ngrid` holding cat(4, sta, p_val), and `data_body` has no
% byte-range field to split it with. Declaring it on only one body would make
% the other plane's bytes unreachable from the document that describes them.
% The name is carried VERBATIM: universalRenames skips the structural keys, so
% a renamed file name is the image_stack `imagestack_file` bug again.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
planes = planeBodies(out);
for k = 1:numel(planes)
    verifyEqual(testCase, planes{k}.data_body.filename, 'hartley_results.ngrid');
    verifyEqual(testCase, planes{k}.files.file_list, {'hartley_results.ngrid'});
    verifyTrue(testCase, contains(planes{k}.data_body.description, ...
        sprintf('plane %d of 2', k)));
    % Without `datum_order` a 200x200x36 volume cannot be reassembled from the
    % bytes at all, and the field is OPTIONAL to the validator -- so its absence
    % would be silent. 'F' is a property of MATLAB (`fwrite` linearises
    % column-major), not an inference. `byte_order` is deliberately NOT set:
    % the document records the producing machine and not its endianness.
    verifyEqual(testCase, planes{k}.sampled_body.datum_order, 'F');
    verifyFalse(testCase, isfield(planes{k}.sampled_body, 'byte_order'));
end
end

function testEveryBodyIsBoundToTheCalculationByItsStatementEdge(testCase)
% `data_body.statement` is the ONE required edge on a body, and it is what makes
% the volume findable from the subject side.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leafId = pick(out, 'receptive_field_calculation').base.id;
bodies = allOf(out, 'sampled_body');
verifyEqual(testCase, numel(bodies), 3);
for k = 1:numel(bodies)
    verifyEqual(testCase, depValueOf(bodies{k}, 'statement'), leafId);
end
end

% ===================== the spike-time input body ===========================

function testSpiketimesBecomeAnInputBodyDerivedFromTheNeuron(testCase)
% THE SIGNATURE DIVERGES FROM FINDING F6 DELIBERATELY, and this pins the
% divergence: F6 read these as primary archival data on the neuron-subject; the
% team decided they are CALCULATION INPUT, because they are WINDOWED to one
% presentation (210 sets over 21 neurons x 10 presentations) and a windowed
% subset filed as archival is indistinguishable from a complete train.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
sb = spikeBody(out);
verifyNotEmpty(testCase, sb);
verifyEqual(testCase, depValueOf(sb, 'derived_from_1'), 'elem_7');
ax = sb.sampled_body.axes;
verifyEqual(testCase, numel(ax), 1);
verifyEqual(testCase, ax.variable.name, 'time');
verifyFalse(testCase, ax.regular);
verifyEqual(testCase, ax.n, 5);
verifyEqual(testCase, ax.values.values, [0.106; 0.31; 0.55; 0.9; 1.4]);
verifyFalse(testCase, isfield(sb, 'files'), ...
    'the spike train has no attached bytes -- the times ARE the coordinates');
end

function testNoSpiketimesMeansNoInputBodyRatherThanAnEmptyOne(testCase)
% An empty body is a husk. The block is genuinely per-document (194 distinct
% lengths across the 210), so absence is a real state and not a fixture artefact.
v1 = hartleyCalcV1();
v1.hartley_reverse_correlation.spiketimes = [];
out = did2.convert.migrators_j.hartley_calc(v1);
verifyEqual(testCase, numel(allOf(out, 'sampled_body')), 2, ...
    'the two planes remain; the input body does not appear empty');
end

% ===================== what is dropped, and what is parked =================

function testTheDerivableAndEmptyFieldsAreDropped(testCase)
% `ngrid.data_size` (8, bytes-per-element -- restates the dtype) and
% `reverse_correlation.dimension_labels` ('' in 210 of 210) are the two the
% signature names droppable. Nothing else from those blocks survives as a
% v1-named field on any emitted body.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
for k = 1:numel(out)
    verifyFalse(testCase, isfield(out{k}, 'ngrid'));
    verifyFalse(testCase, isfield(out{k}, 'reverse_correlation'));
    verifyFalse(testCase, isfield(out{k}, 'hartley_reverse_correlation'));
    if isfield(out{k}, 'sampled_body')
        verifyFalse(testCase, isfield(out{k}.sampled_body, 'data_size'));
    end
end
end

function testTheStimulusSequenceIsCARRIEDRatherThanDropped(testCase)
% `frame_times` + `hartley_numbers` are 5 parallel 3,360-vectors naming which
% basis function was shown on each frame. The signature sends `frameTimes` to
% the per-presentation `timed_sequence` and says NOTHING about
% `hartley_numbers`; `timed_sequence` is DECLARED ABSTRACT, so neither can be
% built here. They are therefore parked in `method_parameters`, whose own
% documentation is "Retaining it keeps the computation reproducible" -- and
% these are the reverse correlation's regressors. Dropping them would be a
% silent loss of 16,800 real values per document.
%
% THIS TEST IS ALSO THE CAMELCASE FALLBACK'S ONLY WITNESS: universalRenames
% snake_cases `frameTimes` to `frame_times`, and both spellings are read.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
mp = pick(out, 'receptive_field_calculation').subject_interaction.method_parameters;
verifyEqual(testCase, mp.T, realLagVector()', 'input_parameters still land here');
verifyEqual(testCase, numel(mp.stimulus_sequence.frame_times), 3360);
verifyEqual(testCase, numel(mp.stimulus_sequence.hartley_numbers.KXV), 3360);

v1 = hartleyCalcV1();
ft = v1.hartley_reverse_correlation.frame_times;
v1.hartley_reverse_correlation = rmfield(v1.hartley_reverse_correlation, 'frame_times');
v1.hartley_reverse_correlation.frameTimes = ft;
out2 = did2.convert.migrators_j.hartley_calc(v1);
mp2 = pick(out2, 'receptive_field_calculation').subject_interaction.method_parameters;
verifyEqual(testCase, numel(mp2.stimulus_sequence.frame_times), 3360, ...
    'the camelCase spelling must be read too');
end

function testStimulusPropertiesAreDroppedWhenTheReferentHoldsThem(testCase)
% Dropped, and the only reason it is lossless is that the referenced
% `stimulus_presentation` holds the same spec and survives migration intact
% (+migrators_j/stimulus_presentation.m is a guarded passthrough). The VALUE
% comparison is did2.validate.sourceCensus's half -- a single-document migrator
% cannot follow the edge.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
verifyFalse(testCase, isfield(leaf.subject_interaction.method_parameters, ...
    'stimulus_properties'));
end

% ===================== the guards ==========================================

function testADroppedSpecWithNoReferentIsREFUSED(testCase)
% Without the edge there is nothing holding the spec, so the drop is a deletion
% of the only copy. All 210 documents carry the edge, populated -- which is
% exactly why a document that does not is worth quarantining loudly.
v1 = hartleyCalcV1();
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_7'});
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(v1), ...
    'did2:convert:hartleyStimulusPropertiesUnverifiable');
end

function testAnUnknownStimulusPropertyKeyIsREFUSED(testCase)
% A key outside the eight the presentation's generator spec is known to supply
% has never been shown redundant for ANY document. "No corpus we looked at has
% one" is a fact about a SAMPLE, so the guard turns it into a loud, dated
% failure rather than a standing risk. Tested in BOTH directions: a guard that
% fires on everything passes the same tests a correct one does.
v1 = hartleyCalcV1();
v1.hartley_reverse_correlation.stimulus_properties.gamma = 2.2;
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(v1), ...
    'did2:convert:hartleyStimulusPropertiesUnverifiable');
verifyEqual(testCase, numel(did2.convert.migrators_j.hartley_calc(hartleyCalcV1())), 6, ...
    'the same document without the extra key folds');
end

function testAMissingNgridBlockIsREFUSED(testCase)
% No volume means a receptive_field whose value lives nowhere -- storage_mode
% `body` with no body, which validates clean. The image_stack husk.
v1 = hartleyCalcV1();
v1 = rmfield(v1, 'ngrid');
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(v1), ...
    'did2:convert:hartleyNgridBlockMissing');
end

function testACoordinateVectorThatAccountsForNoDimensionsIsREFUSED(testCase)
% The signature's arithmetic is re-derived per document rather than hard-coded:
% a trailing run of data_dim must sum to the coordinate count. A document where
% no run does is one whose blocks disagree about the volume, and guessing which
% numbers describe which axis is how an axis gets mislabelled in a document
% that validates.
v1 = hartleyCalcV1();
v1.ngrid.coordinates = (1:99)';
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(v1), ...
    'did2:convert:hartleyCoordinateCountUnaccounted');
end

function testAReconstructionVectorThatFitsNoDimensionIsREFUSED(testCase)
% `reconstruction_properties` is the un-concatenated form of
% `ngrid.coordinates`. A vector with nowhere to go means the two disagree.
v1 = hartleyCalcV1();
v1.hartley_reverse_correlation.reconstruction_properties.T_coords = (1:7)';
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(v1), ...
    'did2:convert:hartleyReconstructionCoordsUnplaced');
end

function testASegmentationThatDoesNotReconcileIsREFUSEDByTheHelper(testCase)
% jNgridBody VERIFIES the caller's segmentation against the stored vector
% instead of trusting it: some ordering of the per-axis vectors must
% re-concatenate to `coordinates` EXACTLY. Here the reconstruction coordinates
% have the right LENGTHS and different VALUES -- the near-miss case, which
% length-only checking would wave through and which would carry one axis's
% positions under another axis's name.
v1 = hartleyCalcV1();
v1.hartley_reverse_correlation.reconstruction_properties.X_coords = ...
    (1001:1200)';
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(v1), ...
    'did2:convert:ngridCoordinatesHaveNoHome');
end

% ===================== the fold VALIDATES ==================================

function testTheFoldedSetVALIDATESThroughTheDispatcher(testCase)
% End to end: the migrator is reached by class name, every emitted body
% validates against the built V_eta schema, and nothing quarantines. This is
% the only assertion here that exercises `RequiredDependencies` (armed by
% default) and `undeclaredField` on the real schema rather than on a fixture's
% idea of it.
out = did2.convert.v1_to_v2(hartleyCalcV1(), 'Validate', true, ...
    'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0, ...
    sprintf('quarantined: %s', strjoin(arrayfun(@(q) ...
        sprintf('%s|%s', q.class_name, q.identifier), out.quarantine, ...
        'UniformOutput', false), '; ')));
verifyEqual(testCase, out.summary.migrated_count, 6);
end

% ===================== the census half of the stimulus check ===============

function testTheCensusCOMPARESTheSpecAndCountsItsDenominatorFirst(testCase)
% The half a single-document migrator cannot do, done where both documents are
% in hand. THREE STATES, never two: equal / mismatch / unresolved.
rep = did2.validate.sourceCensus({hartleyCalcV1(), stimulusPresentationV1()});
verifyEqual(testCase, rep.rf_source_docs, 1, 'the denominator, stated first');
verifyEqual(testCase, rep.rf_docs_with_properties, 1);
verifyEqual(testCase, rep.rf_checked, 1);
verifyEqual(testCase, rep.rf_equal, 1);
verifyEqual(testCase, rep.rf_mismatch, 0);
verifyEqual(testCase, rep.rf_presentation_unresolved, 0);
end

function testTheCensusREPORTSAMismatchRatherThanHidingIt(testCase)
% Tested in both directions. `K_max` -> `K_absmax` is one of the six pairs whose
% names DIFFER across the join, so this also pins that the key map is applied
% rather than an intersection taken -- an intersection would compare nothing
% and report every document equal.
pres = stimulusPresentationV1();
pres.stimulus_presentation.stimuli.parameters.K_absmax = 99;
rep = did2.validate.sourceCensus({hartleyCalcV1(), pres});
verifyEqual(testCase, rep.rf_checked, 1);
verifyEqual(testCase, rep.rf_mismatch, 1);
verifyEqual(testCase, rep.rf_equal, 0);
verifyEqual(testCase, rep.rf_mismatch_by_key.K_max, 1);
verifyEqual(testCase, rep.rf_mismatch_examples(1).doc_id, 'hc_1');
end

function testAnAbsentPresentationIsUNRESOLVEDAndNeitherAPassNorAFailure(testCase)
% "Nobody looked" is a THIRD STATE. Collapsing it into `equal` is the
% absent-from-the-corpora-means-clean error; collapsing it into `mismatch` is
% the same error running backwards, which is how 10 v1 classes were reported
% FAILED in run 31587869672 because a counter was missing.
rep = did2.validate.sourceCensus({hartleyCalcV1()});
verifyEqual(testCase, rep.rf_source_docs, 1);
verifyEqual(testCase, rep.rf_presentation_unresolved, 1);
verifyEqual(testCase, rep.rf_checked, 0);
verifyEqual(testCase, rep.rf_equal, 0);
verifyEqual(testCase, rep.rf_mismatch, 0);
end

function testTheCensusDenominatorIsStatedEvenWithNoRFDocuments(testCase)
% A corpus with no hartley_calc must report 0 SOURCE DOCUMENTS beside its 0
% mismatches. "No mismatches" and "no documents" are different facts, and a
% report that prints only the second is what silentLoss printed for two days.
rep = did2.validate.sourceCensus({stimulusPresentationV1()});
verifyEqual(testCase, rep.rf_source_docs, 0);
verifyEqual(testCase, rep.rf_checked, 0);
verifyEqual(testCase, rep.rf_mismatch, 0);
end

% ===================== fixtures ============================================

function T = realLagVector()
%REALLAGVECTOR The 36 reverse-correlation lags, VERBATIM from a real document.
%
%   One distinct vector across all 210 documents in corpus 20211116, and it is
%   NOT `-0.1:0.01:0.25`: 6 of the 36 entries differ from that at the ulp, so 0
%   of 210 documents are reproducible from origin + spacing. Typed out rather
%   than generated for exactly that reason -- a generated fixture would make
%   the losslessness test pass for the wrong reason.
T = [ ...
    -0.1 -0.09000000000000001 -0.08 -0.07 -0.060000000000000005 -0.05 ...
    -0.04000000000000001 -0.03 -0.020000000000000004 -0.010000000000000009 ...
    0 0.009999999999999995 ...
    0.01999999999999999 0.03 0.04000000000000001 0.04999999999999999 0.06 0.07 ...
    0.07999999999999999 0.09 0.1 0.10999999999999999 0.12 0.13 ...
    0.14 0.15 0.16 0.16999999999999998 0.18 0.19 ...
    0.2 0.21 0.22 0.23 0.24 0.25]';
end

function v1 = hartleyCalcV1()
%HARTLEYCALCV1 The real 20211116 shape, POST-universalRenames.
%
%   Every block, every field name and every extent is the measured one -- see
%   the file header for the census. `spiketimes` is the one shortened array,
%   because its real length is per-document (194 distinct values across 210).
T = realLagVector();
v1 = struct();
v1.document_class = struct('class_name', 'hartley_calc', 'class_version', '1.0.0', ...
    ... % THE REAL CHAIN, and it is FIVE entries with `base` twice. v1 stores
    ... % superclasses as `definition` paths only; universalRenames derives the
    ... % class name from the basename. Read off a real document:
    ... %   hartley_reverse_correlation, reverse_correlation, base, ngrid, base
    ... % applySuperclassMigrators dedupes, and the `ngrid` entry is the one
    ... % that matters: it is why +migrators_j/+super/ngrid.m has to shadow the
    ... % legacy +migrators/ngrid.m, which rmfield's `coordinates` outright.
    'superclasses', struct( ...
        'class_name', {'hartley_reverse_correlation', 'reverse_correlation', ...
                       'base', 'ngrid', 'base'}, ...
        'class_version', {'1.0.0', '1.0.0', '1.0.0', '1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'element_id', 'stimulus_presentation_id'}, ...
    'value', {'elem_7', 'pres_3'});
v1.base = struct('id', 'hc_1', 'session_id', 'sess_1', 'name', '', ...
    'datestamp', '2025-09-11T14:12:53.088Z');
% universalRenames rewrites `name`/`version` on the app block to
% `app_name`/`app_version` before any migrator runs; jSoftwareFromApp reads
% both spellings, and the renamed one is what a real run hands over.
v1.app = struct('app_name', 'ndi.calc.vis.hartley_calc', ...
    'app_version', '7b0d5d19c779d9b75f99e21d3eda851ef8b1a8c3', ...
    'url', 'https://github.com/VH-Lab/NDIcalc-vis-matlab', ...
    'os', 'MACA64', 'os_version', '15.6.1', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.2');
v1.files = struct('file_list', {{'hartley_results.ngrid'}});
v1.hartley_calc = struct('input_parameters', ...
    struct('T', T', 'X_sample', 1, 'Y_sample', 1));
v1.hartley_reverse_correlation = struct();
v1.hartley_reverse_correlation.stimulus_properties = struct( ...
    'M', 200, 'L_max', 20, 'K_max', 20, 'sf_max', 5, 'fps', 10, ...
    'color_high', [255 255 255], 'color_low', [0 0 0], ...
    'rect', [-7 -138 793 662]);
v1.hartley_reverse_correlation.reconstruction_properties = struct( ...
    'T_coords', T, 'X_coords', (1:200)', 'Y_coords', (1:200)');
v1.hartley_reverse_correlation.hartley_numbers = struct( ...
    'S', ones(3360, 1), 'KXV', (1:3360)', 'KYV', (1:3360)', ...
    'ORDER', (1:3360)');
v1.hartley_reverse_correlation.spiketimes = [0.106; 0.31; 0.55; 0.9; 1.4];
% `frameTimes` is a BLOCK-LEVEL field, so universalRenames snake_cases it.
v1.hartley_reverse_correlation.frame_times = (1:3360)' * 0.1;
% THE COORDINATE ORDER IS THE WRITER'S AND IS NOT data_dim ORDER: [T; X; Y]
% against a data_dim of [200 200 36 2]. 436 values, 438 dims -- the length-2
% dimension has none.
v1.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [200 200 36 2], ...
    'coordinates', [T; (1:200)'; (1:200)']);
v1.reverse_correlation = struct('method', 'Hartley', 'dimension_labels', '');
end

function v1 = stimulusPresentationV1()
%STIMULUSPRESENTATIONV1 The referenced presentation, real 20211116 shape.
%
%   Only the eight generator keys the census compares are asserted here; the
%   rest of the real block (windowShape, distance, contrast, background,
%   backdrop, reps, randState, dispprefs) is carried so the fixture is not a
%   list of exactly what the checker looks at -- a fixture built from the
%   checker cannot catch the checker.
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_presentation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {'stimulus_element_id'}, 'value', {'stim_1'});
v1.base = struct('id', 'pres_3', 'session_id', 'sess_1', 'name', '', ...
    'datestamp', '2025-09-11T12:48:21.932Z');
v1.epochid = struct('epochid', 't00001');
v1.stimulus_presentation = struct('presentation_order', 1, ...
    'stimuli', struct('parameters', struct( ...
        'rect', [-7 -138 793 662], 'windowShape', 0, 'distance', 30, ...
        'M', 200, 'K_absmax', 20, 'L_absmax', 20, 'sfmax', 5, ...
        'contrast', 1, 'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
        'background', 0.5, 'backdrop', 0.5, 'reps', 1, 'fps', 10)));
end

% ===================== small readers =======================================

function b = pick(bodies, className)
%PICK The single body of CLASSNAME, erroring rather than returning the first of
%   several -- a silent first-match would hide a duplicate emission.
hits = allOf(bodies, className);
if numel(hits) ~= 1
    error('testMigratorsJHartleyCalc:pick', ...
        'expected exactly 1 `%s` body, found %d', className, numel(hits));
end
b = hits{1};
end

function hits = allOf(bodies, className)
hits = {};
for k = 1:numel(bodies)
    if isfield(bodies{k}, 'document_class') ...
            && strcmp(bodies{k}.document_class.class_name, className)
        hits{end+1} = bodies{k}; %#ok<AGROW>
    end
end
end

function out = planeBodies(bodies)
%PLANEBODIES The plane bodies, IN EMISSION ORDER, identified by base.name.
%   Identified by name rather than by position so a reordering of the emitted
%   set fails the assertion instead of silently re-pairing the planes.
out = {};
for k = 1:numel(bodies)
    if isfield(bodies{k}, 'base') && isfield(bodies{k}.base, 'name') ...
            && startsWith(bodies{k}.base.name, 'migrated_receptive_field_plane_')
        out{end+1} = bodies{k}; %#ok<AGROW>
    end
end
end

function b = spikeBody(bodies)
b = [];
for k = 1:numel(bodies)
    if isfield(bodies{k}, 'base') && isfield(bodies{k}.base, 'name') ...
            && strcmp(bodies{k}.base.name, ...
                'migrated_receptive_field_input_spiketimes')
        b = bodies{k};
        return;
    end
end
end

function v = depValueOf(body, name)
v = '';
if ~isfield(body, 'depends_on'); return; end
d = body.depends_on;
for k = 1:numel(d)
    if strcmp(d(k).name, name)
        v = d(k).value;
        return;
    end
end
end
