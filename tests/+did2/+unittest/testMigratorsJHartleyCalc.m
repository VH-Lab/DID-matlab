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

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
% RE-ARMED 2026-10-21. On did-schema #88 before data_body AMENDMENT 5,
% receptive_field.value was a REQUIRED structure declaring no sub-fields, so
% hartley_calc passed through and these tests were filtered. AMENDMENT 5 (rule
% `value_inline_or_body` on `value`, Jess Haley, signed 2026-10-21) replaced
% the required value: a receptive field is `data_body: true` with an empty
% `value`. A schema without the rule cannot hold the fold.
testCase.assumeTrue(valueRuleDeclared(), ...
    ['the loaded schema''s `value` does not declare `value_inline_or_body` ' ...
     '(did-schema before data_body AMENDMENT 5), so receptive_field.value ' ...
     'is still required and the fold cannot be stated']);
end

function tf = valueRuleDeclared()
tf = false;
c = did2.schema.cache.shared().getClass('value');
if ~isfield(c, 'rules') || isempty(c.rules)
    return;
end
r = c.rules;
if iscell(r)
    names = cellfun(@(x) char(x.name), r, 'UniformOutput', false);
else
    names = {r.name};
end
tf = any(strcmp(names, 'value_inline_or_body'));
end

% ===================== the shape ===========================================

function testTheFoldEmitsTheLeafTheTwoPlanesAndTheSpikeInput(testCase)
% The leaf, the session anchor every calculator fold carries, the entities the
% app block becomes (software, operating system, interpreter on #88; the
% pre-#88 `runtime_environment` entity is gone), TWO plane bodies and ONE
% input body.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'receptive_field_calculation')), 1, strjoin(names, ', '));
verifyEqual(testCase, sum(strcmp(names, 'sampled_body')), 3, ...
    'two planes plus the spike-time input body');
verifyEqual(testCase, sum(strcmp(names, 'relative_time_reference')), 1);
% the calculator, its operating system and its interpreter are each a
% `software` entity on #88
verifyGreaterThanOrEqual(testCase, sum(strcmp(names, 'software')), 1);
verifyEqual(testCase, sum(strcmp(names, 'runtime_environment')), 0);
end

function testTheLeafIsTheSignedClassAndItsSuperclassPair(testCase)
% TEAM-SIGN-OFF [receptive field naming]: the composite is `receptive_field`
% and the leaf is `receptive_field_calculation` (on #88 a `calculation` whose
% chain holds `receptive_field`). The method is NOT in the name -- T11 -- so
% this also pins that no class called `spike_triggered_average` or
% `hartley_receptive_field` is emitted.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
supers = {leaf.document_class.superclasses.class_name};
verifyTrue(testCase, ismember('calculation', supers));
verifyTrue(testCase, ismember('receptive_field', supers));
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
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

function testElementIdBecomesTheEntityAndThePresentationBecomesAnInput(testCase)
% `element_id` IS a subject edge -- +migrators_j/element.m promotes elements to
% subjects with their ids PRESERVED -- and on #88 it is the leaf's `entity_id`.
% The presentation is provenance, not a subject: an `input_id` (the pre-#88
% `derived_from_1`). A calculation REQUIRES an operating system, named from
% the app block.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
verifyEqual(testCase, depValueOf(leaf, 'entity_id'), 'elem_7');
verifyEqual(testCase, depValueOf(leaf, 'input_id'), 'pres_3');
verifyNotEmpty(testCase, depValueOf(leaf, 'time_reference_id'));
verifyNotEmpty(testCase, depValueOf(leaf, 'software_id'));
verifyNotEmpty(testCase, depValueOf(leaf, 'operating_system_id'));
end

function testEveryEmittedEdgeIsNonEmpty(testCase)
% THE INVENTED-EMPTY-EDGE SWEEP, with its DENOMINATOR asserted first --
% without that an empty `out` would make this vacuously true.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
edges = 0;
for k = 1:numel(out)
    if ~isfield(out{k}, 'depends_on'); continue; end
    d = out{k}.depends_on;
    for j = 1:numel(d)
        edges = edges + 1;
        verifyNotEmpty(testCase, edgeId(d(j)), sprintf( ...
            'body %d (%s) declares edge `%s` with an empty value', ...
            k, out{k}.document_class.class_name, d(j).name));
    end
end
verifyGreaterThanOrEqual(testCase, edges, 8, ...
    ['DENOMINATOR: the sweep must actually see edges -- entity_id, ' ...
     'time_reference_id, input_id, software_id and operating_system_id on ' ...
     'the leaf, and owner_id on each of the 3 bodies']);
end

function testTheSubjectEdgeIsNeverEmittedBlank(testCase)
% THE HUSK TEST, read through `.document_id`, the second spelling the edge
% readers accept, so the reader divergence that produced the image_stack husk
% cannot come back through this migrator.
v1 = hartleyCalcV1();
v1.depends_on = struct('name', {'element_id', 'stimulus_presentation_id'}, ...
    'document_id', {'elem_7', 'pres_3'});
out = did2.convert.migrators_j.hartley_calc(v1);
verifyEqual(testCase, ...
    depValueOf(pick(out, 'receptive_field_calculation'), 'entity_id'), 'elem_7');
end

% ===================== the composite value =================================

function testTheMethodIsTheCalculatorAndEachPlaneSaysWhatItHolds(testCase)
% #73 item 57 moved the method onto the statement: its term is the
% calculator. #73 audit 2 D11 dropped `planes[]`: bodies have no order, so
% each plane body says what it holds as ONE body condition {variable:
% represented quantity, term: response estimate | significance}.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
verifyEqual(testCase, lower(char(leaf.interaction.method.term.name)), 'ndi.calc.vis.hartley');
planes = planeBodies(out);
verifyEqual(testCase, numel(planes), 2);
verifyEqual(testCase, cellfun(@planeName, planes, 'UniformOutput', false), ...
    {'response estimate', 'significance'});
end

function testTheValueIsInItsBodiesAndCarriesTheEncoding(testCase)
% data_body AMENDMENT 5: `receptive_field.value` declares no sub-fields, so the
% value is in data bodies (`data_body: true`) and the inline value stays
% empty. The bytes are a plain array in sampled_body documents, so the leaf
% says their type (`data_type`), with the source spelling beside it.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
verifyTrue(testCase, logical(leaf.value.data_body));
verifyEqual(testCase, leaf.value.data_type, 'float64');
verifyEqual(testCase, leaf.value.source_data_type, 'double');
if isfield(leaf, 'receptive_field') && isfield(leaf.receptive_field, 'value')
    v = leaf.receptive_field.value;
    verifyTrue(testCase, isempty(v) || (isstruct(v) && isempty(fieldnames(v))), ...
        'the inline value must stay empty: the volume is in the bodies');
end
end

% ===================== the two plane bodies ================================

function testEachPlaneBodyDescribesOnePlaneAndNotTheStack(testCase)
% THE ARITHMETIC THE SIGNATURE TURNS ON: data_dim is [200 200 36 2] and sums to
% 438, while `coordinates` has 436 values -- so the length-2 dimension has NO
% coordinates, which is the writer saying in the data that it is not an axis.
% Two bodies of three keys each, never one body with a fourth key of length 2.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
planes = planeBodies(out);
verifyEqual(testCase, numel(planes), 2);
for k = 1:numel(planes)
    ax = planes{k}.data.keys;
    verifyEqual(testCase, numel(ax), 3, ...
        'three keys per plane -- the trailing 2 is a plane count, not a key');
    verifyEqual(testCase, [ax.n], [200 200 36]);
end
end

function testTheLagAxisCarriesItsValuesRatherThanASpacing(testCase)
% THE COORDINATE CARRY. The lag key is `regular = false` with the stored
% doubles in `quantity`; the two index keys stay regular because their
% coordinates ARE 1..200 and `n` already says so. NOT A STYLISTIC CHOICE: 6 of
% the 36 stored lags differ at the ulp from -0.1 + k*0.01.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
ax = planeBodies(out); ax = ax{1}.data.keys;
verifyEqual(testCase, logical([ax.regular]), [true true false]);
verifyEqual(testCase, ax(3).quantity.value(:), realLagVector());
end

function testTheLagAxisIsNamedAndTheTwoSpatialAxesAreNotGuessed(testCase)
% The lag key is named on POSITIVE EVIDENCE (its coordinates equal
% `hartley_calc.input_parameters.T` in 210 of 210). Nothing distinguishes X
% from Y, so they stay positional: a guess recorded in a queryable `variable`
% is a guess recorded as a fact.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
ax = planeBodies(out); ax = ax{1}.data.keys;
verifyEqual(testCase, ...
    arrayfun(@(a) char(a.variable.name), ax, 'UniformOutput', false), ...
    {'axis_1', 'axis_2', 'lag'});
end

function testBothPlanesNameTheSourceFileAndSayWhichPlaneTheyAre(testCase)
% ONE FILE, TWO BODIES, SAID OUT LOUD. The v1 document attaches a single
% `hartley_results.ngrid` holding cat(4, sta, p_val), and `data_body` has no
% byte-range field to split it with, so both bodies declare it. The name is
% carried VERBATIM (universalRenames skips the structural keys).
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
planes = planeBodies(out);
for k = 1:numel(planes)
    verifyEqual(testCase, planes{k}.data_body.filename, 'hartley_results.ngrid');
    verifyEqual(testCase, cellstr(planes{k}.files.file_list), {'hartley_results.ngrid'});
    verifyTrue(testCase, contains(planes{k}.data_body.description, ...
        sprintf('plane %d of 2', k)));
    % Without `datum_order` a 200x200x36 volume cannot be reassembled from the
    % bytes. 'F' is a property of MATLAB (`fwrite` linearises column-major).
    % `byte_order` is deliberately NOT set: the document records the
    % producing machine and not its endianness.
    where = did2.schema.cache.shared().datumOrderBlock();
    if isempty(where); where = 'sampled_body'; end
    verifyEqual(testCase, planes{k}.(where).datum_order, 'F');
    verifyFalse(testCase, isfield(planes{k}.(where), 'byte_order') ...
        && ~isempty(planes{k}.(where).byte_order));
end
end

function testEveryBodyIsBoundToTheCalculationByItsOwnerEdge(testCase)
% `owner_id` is the ONE required edge on a body (`statement` before #88), and
% it is what makes the volume findable from the subject side.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leafId = pick(out, 'receptive_field_calculation').base.id;
bodies = allOf(out, 'sampled_body');
verifyEqual(testCase, numel(bodies), 3);
for k = 1:numel(bodies)
    verifyEqual(testCase, depValueOf(bodies{k}, 'owner_id'), leafId);
end
end

% ===================== the spike-time input body ===========================

function testSpiketimesBecomeAnInputBodyOfTheCalculation(testCase)
% THE SIGNATURE DIVERGES FROM FINDING F6 DELIBERATELY: the spike times are
% CALCULATION INPUT, windowed to one presentation. On #88 a data_body declares
% no lineage edge; the neuron is the leaf's own entity.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
sb = spikeBody(out);
assertNotEmpty(testCase, sb);
verifyEqual(testCase, depValueOf(sb, 'owner_id'), 'hc_1');
ax = sb.data.keys;
verifyEqual(testCase, numel(ax), 1);
verifyEqual(testCase, char(ax.variable.name), 'time');
verifyFalse(testCase, logical(ax.regular));
verifyEqual(testCase, ax.n, 5);
verifyEqual(testCase, ax.quantity.value(:), [0.106; 0.31; 0.55; 0.9; 1.4]);
% FINDING, 2026-10-21, NOT FIXED HERE: the spike train has no bytes -- the
% times ARE the key's positions -- yet did2.build.sampledBody declares its
% default file series member `body_data_0` on every body (bodyFiles.m), so
% this body names a file nothing will ever hold. Pinned as it is, so a change
% either way is seen; whether a keys-only body should declare no file is a
% team question. What must hold now: it carries none of the v1 attachment.
fl = {};
if isfield(sb, 'files') && isfield(sb.files, 'file_list')
    fl = cellstr(sb.files.file_list);
end
verifyFalse(testCase, any(strcmp(fl, 'hartley_results.ngrid')), ...
    'the spike body must not claim the plane file');
verifyTrue(testCase, all(startsWith(fl, 'body_data_')), strjoin(fl, ', '));
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
% v1-named block on any emitted body.
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
% `frame_times` + `hartley_numbers` are parallel 3,360-vectors naming which
% basis function was shown on each frame. Their signed home (the
% per-presentation sequence) cannot be built here, so they are carried in the
% method parameters, entries named `stimulus sequence.<field>` -- the
% reverse correlation's regressors. Dropping them would be a silent loss.
%
% THIS TEST IS ALSO THE CAMELCASE FALLBACK'S ONLY WITNESS: universalRenames
% snake_cases `frameTimes` to `frame_times`, and both spellings are read.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
verifyEqual(testCase, jsondecode(paramText(leaf, 'T')), realLagVector(), 'AbsTol', 1e-12, ...
    'input_parameters still land here');
verifyEqual(testCase, numel(jsondecode(paramText(leaf, 'stimulus sequence.frame times'))), 3360);
verifyEqual(testCase, numel(jsondecode(paramText(leaf, 'stimulus sequence.hartley numbers.KXV'))), 3360);

v1 = hartleyCalcV1();
ft = v1.hartley_reverse_correlation.frame_times;
v1.hartley_reverse_correlation = rmfield(v1.hartley_reverse_correlation, 'frame_times');
v1.hartley_reverse_correlation.frameTimes = ft;
out2 = did2.convert.migrators_j.hartley_calc(v1);
leaf2 = pick(out2, 'receptive_field_calculation');
verifyEqual(testCase, numel(jsondecode(paramText(leaf2, 'stimulus sequence.frame times'))), 3360, ...
    'the camelCase spelling must be read too');
end

function testStimulusPropertiesAreDroppedWhenTheReferentHoldsThem(testCase)
% Dropped, and the only reason it is lossless is that the referenced
% `stimulus_presentation` holds the same spec and survives migration. The
% VALUE comparison is did2.validate.sourceCensus's half.
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
leaf = pick(out, 'receptive_field_calculation');
names = paramNames(leaf);
verifyFalse(testCase, any(startsWith(names, 'stimulus properties')), strjoin(names, ', '));
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
out = did2.convert.migrators_j.hartley_calc(hartleyCalcV1());
verifyEqual(testCase, numel(allOf(out, 'receptive_field_calculation')), 1, ...
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
verifyEqual(testCase, out.summary.migrated_count, ...
    numel(did2.convert.migrators_j.hartley_calc(hartleyCalcV1())));
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
%PICK The single body of CLASSNAME (its #88 leaf name), erroring rather than
%   returning the first of several -- a silent first-match would hide a
%   duplicate emission.
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
    if strcmp(did2.unittest.helpers.leafName(bodies{k}), className)
        hits{end+1} = bodies{k}; %#ok<AGROW>
    end
end
end

function out = planeBodies(bodies)
%PLANEBODIES The plane bodies, IN EMISSION ORDER: the sampled bodies that say
%   what they hold in a `represented quantity` condition (#73 audit 2 D11). #88
%   writes no base.name, so a plane is found by what it says it is.
out = {};
sb = allOf(bodies, 'sampled_body');
for k = 1:numel(sb)
    if ~isempty(planeName(sb{k}))
        out{end+1} = sb{k}; %#ok<AGROW>
    end
end
end

function name = planeName(b)
name = '';
c = [];
for blk = {'data_body', 'data', 'sampled_body'}
    if isfield(b, blk{1}) && isfield(b.(blk{1}), 'conditions') ...
            && ~isempty(b.(blk{1}).conditions)
        c = b.(blk{1}).conditions;
        break;
    end
end
if isempty(c); return; end
if iscell(c); c = c{1}; end
c = c(1);
if isfield(c, 'variable') && strcmp(char(c.variable.name), 'represented quantity') ...
        && isfield(c, 'term')
    name = char(c.term.name);
end
end

function b = spikeBody(bodies)
%SPIKEBODY The input body: the sampled body that is not a plane.
b = [];
sb = allOf(bodies, 'sampled_body');
for k = 1:numel(sb)
    if isempty(planeName(sb{k}))
        b = sb{k};
        return;
    end
end
end

function v = edgeId(e)
v = '';
if isfield(e, 'document_id') && ~isempty(e.document_id)
    v = char(e.document_id);
elseif isfield(e, 'value') && ~isempty(e.value)
    v = char(e.value);
end
end

function v = depValueOf(body, name)
v = '';
if ~isfield(body, 'depends_on'); return; end
d = body.depends_on;
for k = 1:numel(d)
    if strcmp(d(k).name, name)
        v = edgeId(d(k));
        return;
    end
end
end

function names = paramNames(leaf)
names = {};
p = leaf.interaction.method.parameters;
for k = 1:numel(p)
    names{end+1} = char(p(k).variable.name); %#ok<AGROW>
end
end

function t = paramText(leaf, varName)
t = '';
p = leaf.interaction.method.parameters;
for k = 1:numel(p)
    if strcmp(char(p(k).variable.name), varName)
        t = char(p(k).text);
        return;
    end
end
error('testMigratorsJHartleyCalc:param', 'no method parameter `%s`; have: %s', ...
    varName, strjoin(paramNames(leaf), ', '));
end
