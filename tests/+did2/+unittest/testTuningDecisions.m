function tests = testTuningDecisions
%TESTTUNINGDECISIONS Jess Haley's 2026-10-27 tuning and response decisions
%   (did-schema V_eta_go_forward_class_audit.md), one test (or more) per tag:
%
%     [tuning fits use curve fitting now]        testFitsUseCurveFitting
%     [Priebe fits are one function]             testPriebeFitsAreOneFunction
%     [hotelling spellings are one field]        testHotellingSpellingsAreOneField
%     [input names rebuild from the input class] testInputNames*
%     [tuning stimids rebuild]                   testTuningStimids*
%     [tuning log in notes]                      testTuningLogInNotes
%     [varied properties are conditions by V2 name]  testVariedProperties*
%     [parameter names map by table]             testParameterNames*
%     [absolute-value fits are a second calculation] testAbsoluteValueFits*
%     [contrast metrics added]                   testContrastMetrics
%     [response links: epoch rebuilt, control as input]  testResponseLinks*
%     [empty prestimulus normalization is zero]  testEmptyPrestimulusNormalization
%     [unreadable responses are malformed]       testUnreadableResponses*
%     [carried documents may point at converted ones]  testACarriedDocument*
%
%   The v1 documents are the writers' own stored outputs
%   (tests/+did2/fixtures/ndi_writer_outputs, see testRawV1RoundTripTuning)
%   and the NDI templates (tests/+did2/fixtures/ndi_templates), changed only
%   where a test says so.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== [tuning fits use curve fitting now] ===============

function testFitsUseCurveFitting(testCase)
cases = { ...
    'oridir', writerOutput('oridirtuning_calc'), 'orientation_direction_tuning_calculation', ...
        'double gaussian'; ...
    'contrast', convertedContrast(), 'contrast_tuning_calculation', 'Naka-Rushton'; ...
    'speed', writerOutput('speedtuning_calc'), 'speed_tuning_calculation', 'Priebe fit'; ...
    'SF', writerOutput('spatial_frequency_tuning_calc'), ...
        'spatial_frequency_tuning_calculation', ...
        '["dog","movshon","movshon c","spline","gausslog"]'};
for k = 1:size(cases, 1)
    [label, v1, leafClass, fn] = cases{k, :};
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, label);
    leaf = firstOfClass(out, leafClass);
    assertNotEmpty(testCase, leaf, [label ': no ' leafClass]);
    term = leaf.interaction.method.term;
    verifyEqual(testCase, char(term.node), 'OBI:0200072', label);
    verifyEqual(testCase, parameterText(leaf, 'function'), fn, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
% a tuning curve is not a fit: its method stays the calculator
v1 = convertedTuningCurve();
out = runRaw({v1});
leaf = firstOfClass(out, 'tuning_curve_calculation');
t = leaf.interaction.method.term;
verifyFalse(testCase, isfield(t, 'node') && strcmp(char(t.node), 'OBI:0200072'));
end

function testNakaRushtonFitsAreOneModelToldApartByConstraints(testCase)
out = runRaw({convertedContrast()});
leaf = firstOfClass(out, 'contrast_tuning_calculation');
mf = asCell(leaf.tuning_curve.value.model_fit);
verifyEqual(testCase, numel(mf), 3);
held = cell(1, 3);
for k = 1:3
    verifyEqual(testCase, char(mf{k}.model.name), 'Naka-Rushton');
    held{k} = constraintText(mf{k});
end
verifyEqual(testCase, sort(held), sort({'Naka-Rushton parameter 3=1;Naka-Rushton parameter 4=1', ...
    'Naka-Rushton parameter 4=1', ''}));
end

% ===================== [Priebe fits are one function] =====================

function testPriebeFitsAreOneFunction(testCase)
% NDIcalc-vis-matlab 00e3e0f: vis.speed.fit, fit_nospeed and fit_fullspeed
% all fit vis.speed.tuningfunc; xi (parameter 3) free, held at 0, held at 1
v1 = writerOutput('speedtuning_calc');
out = runRaw({v1});
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'the speed writer output converts');
leaf = firstOfClass(out, 'speed_tuning_calculation');
mf = asCell(leaf.tuning_curve.value.model_fit);
verifyEqual(testCase, numel(mf), 3);
held = cellfun(@constraintText, mf, 'UniformOutput', false);
verifyEqual(testCase, sort(held), sort({'', 'Priebe fit parameter 3=0', 'Priebe fit parameter 3=1'}));
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'speed writer output', {});
% a fourth fit block no constraint tells apart is still carried
v1.speed_tuning.fit_other = v1.speed_tuning.fit;
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-056]'), notes);
end

% ===================== [hotelling spellings are one field] ================

function testHotellingSpellingsAreOneField(testCase)
w = writerOutput('oridirtuning_calc');   % the writer's Hotelling2Test
t = w;                                   % the template's hotelling2test
vec = t.orientation_direction_tuning.vector;
vec.hotelling2test = vec.Hotelling2Test;
vec = rmfield(vec, 'Hotelling2Test');
t.orientation_direction_tuning.vector = vec;
for c = {{'writer spelling', w, 'Hotelling2Test'}, {'template spelling', t, 'hotelling2test'}}
    [label, v1, field] = c{1}{:};
    out = runRaw({v1});
    leaf = firstOfClass(out, 'orientation_direction_tuning_calculation');
    cs = leaf.orientation_direction_tuning_calculation.circular_statistics;
    verifyEqual(testCase, cs.hotelling_t2_p, v1.orientation_direction_tuning.vector.(field), label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
    verifyTrue(testCase, any(strcmp(['orientation_direction_tuning.vector.' field], r.matched)), label);
end
end

% ===================== [input names rebuild from the input class] =========

function testInputNamesRebuildFromTheInputClass(testCase)
% the oridir fit's input is a tuningcurve_calc in the batch: named back
% stimulus_tuningcurve_id from that class
tc = convertedTuningCurve();
od = did2.unittest.helpers.setDependency(writerOutput('oridirtuning_calc'), ...
    'stimulus_tuningcurve_id', tc.base.id);
od.oridirtuning_calc.depends_on.value = tc.base.id;
od = jsondecode(jsonencode(od));
out = runRaw({od, tc});
verifyEmpty(testCase, out.quarantine);
verifyNotEmpty(testCase, firstOfClass(out, 'orientation_direction_tuning_calculation'), ...
    'converted with its input''s class known');
% the round trip of the oridir fit alone, with the tuning curve's class in the
% batch index (as after the run above)
own = runRaw({od});
did2.convert.tuningBatchIndex('load', {tc});
r = did2.convert.roundtrip.check(od, own.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'oridir with its tuning curve', {});
end

function testAnInputNameItsClassDoesNotGiveIsCarriedAsMalformed(testCase)
% stimulus_tuningcurve_id naming a stimulus_response_scalar: the class gives
% another name, so the name cannot be rebuilt
resp = response('resp_in_1', 't00001', 't00001');
od = did2.unittest.helpers.setDependency(writerOutput('oridirtuning_calc'), ...
    'stimulus_tuningcurve_id', resp.base.id);
od.oridirtuning_calc.depends_on.value = resp.base.id;
od = jsondecode(jsonencode(od));
[carried, notes] = did2.unittest.helpers.carryNote({od, resp});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-100] malformed: input edges'), notes);
end

function testTwoInputsOfOneClassUnderTwoNamesAreCarried(testCase)
r1 = response('resp_in_2', 't00001', 't00001');
r2 = response('resp_in_3', 't00001', 't00001');
tc = convertedTuningCurve();
tc = did2.unittest.helpers.setDependency(tc, 'stimulus_response_scalar_id', r1.base.id);
tc = did2.unittest.helpers.setDependency(tc, 'stimulus_response_id', r2.base.id);
tc.tuningcurve_calc.depends_on = struct('name', 'stimulus_response_scalar_id', 'value', r1.base.id);
tc = jsondecode(jsonencode(tc));
[carried, notes] = did2.unittest.helpers.carryNote({tc, r1, r2});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-100] malformed: input edges'), notes);
end

% ===================== [tuning stimids rebuild] ===========================

function testTuningStimidsRebuildFromThePresentation(testCase)
[tc, resp, pres] = tuningCurveBatch();
out = runRaw({tc, resp, pres});
verifyEmpty(testCase, out.quarantine);
mine = outputsOf(out, tc.base.id);
notes = '';
if isfield(out.summary.migration_notes, 'carried_as_v1')
    notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' || ');
end
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2', ...
    ['the writer''s tuning curve converts; carried: ' notes]);
n = out.summary.migration_notes.tuning_stimid_rebuild;
verifyEqual(testCase, n.count, 1, 'one note per curve: the denominator');
verifyEqual(testCase, n.distinct_details, {'rebuilt exactly'});
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'tuning curve with its presentation', {});
verifyTrue(testCase, any(strcmp('stimulus_tuningcurve.stimid', r.matched)));
verifyTrue(testCase, any(strcmp('stimulus_tuningcurve.stimulus_presentation_number', r.matched)));
end

function testATuningCurveWhoseStimidsDoNotRebuildIsCarried(testCase)
% a seventh stimulus at contrast 0: the rebuild gives stimid 7 for the first
% point, the writer's document says 1
[tc, resp, pres] = tuningCurveBatch();
pres.stimulus_presentation.stimuli(end + 1) = pres.stimulus_presentation.stimuli(1);
pres = jsondecode(jsonencode(pres));
[carried, notes, out] = did2.unittest.helpers.carryNote({tc, resp, pres});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'do not rebuild exactly'), notes);
verifyEqual(testCase, out.summary.migration_notes.tuning_stimid_rebuild.distinct_details, ...
    {'not rebuilt'});
% and with no presentation in the batch, it is carried too
[carried, notes] = did2.unittest.helpers.carryNote({tc});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'not in the batch'), notes);
end

function testTuningStimidsRebuildFunction(testCase)
[~, resp, pres] = tuningCurveBatch();
did2.convert.tuningBatchIndex('reset');
did2.convert.tuningBatchIndex('load', {resp, pres});
[stimid, spn, why] = did2.convert.tuningStimids([0; 0.2; 0.4; 0.6; 0.8; 1], {'contrast'}, {}, [], resp.base.id);
verifyEmpty(testCase, why);
verifyEqual(testCase, stimid, (1:6)');
verifyEqual(testCase, spn, reshape(1:30, 6, 5)');
[~, ~, why] = did2.convert.tuningStimids([0; 0.2; 0.4; 0.6; 0.8; 1], {'contrast'}, {}, [], 'no_such_response');
verifyNotEmpty(testCase, why);
end

% ===================== [tuning log in notes] ==============================

function testTuningLogInNotes(testCase)
v1 = convertedTuningCurve();
v1.tuningcurve_calc.log = 'contrast best value is 0.5,dealing sFrequency = 0.5,';
out = runRaw({v1});
leaf = firstOfClass(out, 'tuning_curve_calculation');
verifyEqual(testCase, leaf.statement.notes, v1.tuningcurve_calc.log);
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'tuning curve with a log', {});
end

% ===================== [varied properties are conditions by V2 name] ======

function testVariedPropertiesAreConditionsByV2Name(testCase)
v1 = convertedTuningCurve();
v1.tuningcurve_calc.stim_property_list = struct('names', {{'sFrequency'; 'tFrequency'}}, ...
    'values', [0.5; 4]);
v1 = jsondecode(jsonencode(v1));
out = runRaw({v1});
leaf = firstOfClass(out, 'tuning_curve_calculation');
c = asCell(leaf.statement.conditions);
verifyEqual(testCase, numel(c), 2);
verifyEqual(testCase, lower(char(c{1}.variable.name)), 'spatial frequency');
verifyEqual(testCase, c{1}.quantity.value, 0.5);
verifyEqual(testCase, lower(char(c{2}.variable.name)), 'temporal frequency');
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'tuning curve with two conditions', {});
end

function testAVariedPropertyNotInTheTableCarriesTheCurve(testCase)
for name = {'notAStimulusParameter', 'sPhaseShift'}
    v1 = convertedTuningCurve();
    v1.tuningcurve_calc.stim_property_list = struct('names', {name}, 'values', 1);
    v1 = jsondecode(jsonencode(v1));
    [carried, notes] = did2.unittest.helpers.carryNote({v1});
    verifyTrue(testCase, carried, name{1});
    verifyTrue(testCase, contains(notes, '[carry-056] tuningcurve_calc.stim_property_list'), notes);
end
end

% ===================== [parameter names map by table] =====================

function testParameterNamesMapByTable(testCase)
for name = {'independent_label', 'min_xi', 'prestimulus_time', 'selection.property'}
    [v2, found] = did2.convert.tuningNames('v2', name{1});
    verifyTrue(testCase, found, name{1});
    [back, found] = did2.convert.tuningNames('v1', v2);
    verifyTrue(testCase, found, v2);
    verifyEqual(testCase, back, name{1});
end
verifyEqual(testCase, did2.convert.tuningNames('v2', 'sFrequency'), 'spatial frequency');
[~, found] = did2.convert.tuningNames('v2', 'sPhaseShift');
verifyFalse(testCase, found, 'sPhaseShift changes unit in the V2 method: not in the table');
end

function testASettingNotInTheTableCarriesTheDocument(testCase)
v1 = convertedTuningCurve();
v1.tuningcurve_calc.input_parameters.smoothing_window = 3;
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-056] input_parameters.smoothing_window'), notes);
end

function testAResponseSettingNotInTheTableKeepsTheParametersV1(testCase)
p = parameters('par_t1');
p.stimulus_response_scalar_parameters_basic.baseline_window = 0.2;
out = runRaw({p});
out = did2.convert.resolveResponseParameters(out, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.response_parameters_fold.refused_unknown_setting, 1);
verifyEqual(testCase, out.response_parameters_fold.methods_minted, 0);
end

% ===================== [absolute-value fits are a second calculation] =====

function testAbsoluteValueFitsAreASecondCalculation(testCase)
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, cls{1});
    verifyEmpty(testCase, out.passthrough, [cls{1} ': converts']);
    leafClass = strrep(cls{1}, '_calc', '_calculation');
    calcs = allOfClass(out, leafClass);
    verifyEqual(testCase, numel(calcs), 2, cls{1});
    transforms = cellfun(@(c) parameterText(c, 'response transform'), calcs, ...
        'UniformOutput', false);
    verifyEqual(testCase, sort(transforms), {'', 'absolute value'}, cls{1});
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, cls{1}, {});
end
end

% ===================== [contrast metrics added] ===========================

function testContrastMetrics(testCase)
% The fit entry's three metrics are a did-schema change (Build pending there):
% written only once the schema declares them. Both states are asserted, so
% the test says which one this run measured.
v1 = writerOutput('contrasttuning_calc');
if schemaHasContrastMetrics()
    out = runRaw({v1});
    leaf = firstOfClass(out, 'contrast_tuning_calculation');
    mf = asCell(leaf.tuning_curve.value.model_fit);
    verifyTrue(testCase, isfield(mf{1}.metrics, 'relative_max_gain'));
    verifyEqual(testCase, numel(mf{1}.metrics.sensitivity), 10);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, 'contrast writer output', {});
else
    [carried, notes] = did2.unittest.helpers.carryNote({v1});
    verifyTrue(testCase, carried, 'no schema field yet: carried as before');
    verifyTrue(testCase, contains(notes, 'relative_max_gain'), notes);
end
end

% ===================== [response links: epoch rebuilt, control as input] ==

function testResponseLinksControlIsAnInputAndTheEpochIsRebuilt(testCase)
v1 = response('resp_l1', '', '');   % no epoch: the session anchor
out = runRaw({v1});
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted');
calc = firstOfClass(out, 'calculation');
verifyEqual(testCase, edges(calc, 'input_id'), {'pres_1', 'ctl_1'});
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'response with its control', {});
n = out.summary.migration_notes.stimulus_control_id;
verifyEqual(testCase, n.distinct_details, {'input'});
end

function testResponseLinksTheStimulatorEpochIsRebuiltFromTheEpoch(testCase)
v1 = response('resp_l2', 't00003', 't00003');
stamped = v1;
stamped.depends_on(end + 1) = struct('name', 'epoch_id', 'value', 'epochdoc_l2');
out = runRaw({stamped});
verifyEmpty(testCase, out.passthrough, 'converted on its epoch');
epoch = did2.build.document('entity', ...
    struct('type', did2.convert.registeredTerm( ...
        did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch'), ...
        'local_identifier', 't00003'), ...
    'Id', 'epochdoc_l2', 'SessionId', v1.base.session_id, ...
    'CreationTimestamp', v1.base.datestamp, 'Validate', false);
r = did2.convert.roundtrip.check(v1, [out.migrated, {epoch}]);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'response on its epoch', {});
verifyTrue(testCase, any(strcmp('stimulus_response.stimulator_epochid', r.matched)));
end

function testAResponseWhoseStimulatorEpochDiffersIsCarried(testCase)
[carried, notes] = did2.unittest.helpers.carryNote({response('resp_l3', 't00003', 't00004')});
verifyTrue(testCase, carried);
verifyTrue(testCase, startsWith(notes, '[carry-050] '), notes);
end

function testAControlWithNoPresentationIsCarriedAsMalformed(testCase)
v1 = response('resp_l4', '', '');
v1.depends_on(strcmp({v1.depends_on.name}, 'stimulus_presentation_id')).value = '';
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, startsWith(notes, '[carry-100] malformed: input edges'), notes);
end

% ===================== [unreadable responses are malformed] ==============

function testUnreadableResponsesAreCarriedAsMalformed(testCase)
noElement = response('resp_u1', '', '');
noElement.depends_on(strcmp({noElement.depends_on.name}, 'element_id')).value = '';
badType = response('resp_u2', '', '');
badType.stimulus_response_scalar.response_type = 'peak';
noValues = response('resp_u3', '', '');
noValues.stimulus_response_scalar.responses.response_real = [];
wrongLength = response('resp_u4', '', '');
wrongLength.stimulus_response_scalar.responses.stimid = [1; 2];
cases = {'no element', noElement, 'no element_id edge'; ...
    'unknown response type', badType, 'response_type "peak"'; ...
    'no values', noValues, 'no responses.response_real'; ...
    'stimid of another length', wrongLength, '2 stimid for 6 readings'};
for k = 1:size(cases, 1)
    [label, v1, why] = cases{k, :};
    [carried, notes] = did2.unittest.helpers.carryNote({v1});
    verifyTrue(testCase, carried, label);
    verifyTrue(testCase, startsWith(notes, '[carry-100] malformed: '), [label ': ' notes]);
    verifyTrue(testCase, contains(notes, why), [label ': ' notes]);
end
end

% ===================== [empty prestimulus normalization is zero] =========

function testEmptyPrestimulusNormalizationIsZero(testCase)
p = parameters('par_e1');   % the writer's prestimulus_normalization []
out = runRaw({p});
out = did2.convert.resolveResponseParameters(out, 'Validate', false, 'TargetVersion', 'V_eta');
m = outputsOf(out, 'par_e1');
r = did2.convert.roundtrip.check(p, m);
P = 'stimulus_response_scalar_parameters_basic.';
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'parameters as a method', {[P 'freq_response']});
verifyTrue(testCase, any(strcmp([P 'prestimulus_normalization'], r.equivalent)));
end

% ===================== [carried documents may point at converted ones] ===

function testACarriedDocumentMayPointAtAConvertedOne(testCase)
% a carried oridir fit (a field outside its template) keeps its edge to the
% converted tuning curve; the edge resolves (same id)
tc = convertedTuningCurve();
od = did2.unittest.helpers.setDependency(writerOutput('oridirtuning_calc'), ...
    'stimulus_tuningcurve_id', tc.base.id);
od.oridirtuning_calc.depends_on.value = tc.base.id;
od.orientation_direction_tuning.vector.stray_field = 1;
od = jsondecode(jsonencode(od));
out = runRaw({od, tc});
verifyEmpty(testCase, out.quarantine);
odOut = outputsOf(out, od.base.id);
verifyEqual(testCase, numel(odOut), 1);
verifyEqual(testCase, odOut{1}.document_class.schema_version, 'did_v1', 'carried');
tcOut = outputsOf(out, tc.base.id);
verifyTrue(testCase, any(cellfun(@(b) strcmp(b.document_class.schema_version, 'did_v2'), tcOut)), ...
    'the tuning curve converted');
rep = did2.validate.references(out.migrated);
verifyGreaterThan(testCase, rep.edges_examined, 0);
% (the fixtures' other edges name documents outside this batch: orphans here)
toCurve = arrayfun(@(o) strcmp(o.edge_document_id, tc.base.id), rep.orphans);
verifyFalse(testCase, any(toCurve), 'the carried fit''s edge to the converted curve resolves');
verifyTrue(testCase, any(strcmp(edges(odOut{1}, 'stimulus_tuningcurve_id'), tc.base.id)), ...
    'the carried fit keeps its edge');
end

% ===================== fixtures ===========================================

function v1 = writerOutput(cls)
thisDir = fileparts(mfilename('fullpath'));
files = struct('tuningcurve_calc', 'tuningcurve_calc.mock.1.json', ...
    'contrasttuning_calc', 'contrasttuning_calc.mock.1.json', ...
    'oridirtuning_calc', 'oridirtuning_calc.mock.1.json', ...
    'spatial_frequency_tuning_calc', 'spatial_frequency_tuning_calc.mock.6.json', ...
    'temporal_frequency_tuning_calc', 'temporal_frequency_tuning_calc.mock.4.json', ...
    'speedtuning_calc', 'speedtuning_calc.mock.1.json');
v1 = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', ...
    'ndi_writer_outputs', files.(cls))));
end

function v1 = convertedContrast()
% the contrast writer output without the three metrics the schema may lack
v1 = writerOutput('contrasttuning_calc');
for m = {'RB', 'RBN', 'RBNS'}
    for x = {'relative_max_gain', 'saturation_index', 'sensitivity'}
        v1.contrast_tuning.fit = rmfield(v1.contrast_tuning.fit, ...
            ['naka_rushton_' m{1} '_' x{1}]);
    end
end
end

function v1 = convertedTuningCurve()
% the tuningcurve writer output without the stimids (no presentation here)
v1 = writerOutput('tuningcurve_calc');
v1.stimulus_tuningcurve.stimid = [];
v1.stimulus_tuningcurve.stimulus_presentation_number = [];
end

function [tc, resp, pres] = tuningCurveBatch()
% the tuningcurve writer output (contrast 0:0.2:1, stimid 1..6, 5 trials),
% the response it was made from (stimid 1..6 five times) and that response's
% presentation (six stimuli, contrast 0:0.2:1)
tc = writerOutput('tuningcurve_calc');
respId = '';
for k = 1:numel(tc.depends_on)
    if strcmp(tc.depends_on(k).name, 'stimulus_response_scalar_id')
        respId = tc.depends_on(k).value;
    end
end
resp = response(respId, 't00001', 't00001', 30);
pres = did2.unittest.helpers.ndiDocument('stimulus_presentation', ...
    'Id', '412696f9abe1aaaa_40c2e3dda9140001', 'SessionId', tc.base.session_id);
c = [0 0.2 0.4 0.6 0.8 1];   % the writer's values exactly (0:0.2:1 gives 0.6000000000000001)
st = struct('parameters', cell(1, numel(c)));
for k = 1:numel(c)
    st(k).parameters = struct('contrast', c(k), 'sFrequency', 0.5);
end
pres.stimulus_presentation.stimuli = st;
pres.stimulus_presentation.presentation_order = repmat(1:6, 1, 5);
resp.depends_on(strcmp({resp.depends_on.name}, 'stimulus_presentation_id')).value = pres.base.id;
pres = jsondecode(jsonencode(pres));
resp = jsondecode(jsonencode(resp));
end

function v1 = response(id, elementEpoch, stimulatorEpoch, nReadings)
% NDI's stimulus_response_scalar as tuning_response.m writes it (the five
% edges sorted and set; both epoch strings)
if nargin < 4; nReadings = 6; end
tpl = loadTemplate('stimulus_response_scalar');
srTpl = loadTemplate('stimulus_response');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
deps = [reshape(tpl.depends_on, [], 1); reshape(srTpl.depends_on, [], 1)];
[~, ix] = unique({deps.name});
deps = reshape(deps(ix), 1, []);
values = struct('element_id', 'el_unit_1', 'stimulator_id', 'el_stim_1', ...
    'stimulus_control_id', 'ctl_1', 'stimulus_presentation_id', 'pres_1', ...
    'stimulus_response_scalar_parameters_id', 'par_x');
for k = 1:numel(deps)
    deps(k).value = values.(deps(k).name);
end
v1.depends_on = deps;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '412696f9abd9edc3_40dbbdf6582271b2';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.stimulus_response = srTpl.stimulus_response;
v1.stimulus_response.stimulator_epochid = stimulatorEpoch;
v1.stimulus_response.element_epochid = elementEpoch;
v1.stimulus_response_scalar = tpl.stimulus_response_scalar;
v1.stimulus_response_scalar.response_type = 'mean';
stimid = repmat(1:6, 1, ceil(nReadings / 6));
r = struct();
r.stimid = stimid(1:nReadings);
r.response_real = 2.5 + (1:nReadings) * 1.25;
r.response_imaginary = zeros(1, nReadings);
r.control_response_real = repmat(0.75, 1, nReadings);
r.control_response_imaginary = zeros(1, nReadings);
v1.stimulus_response_scalar.responses = r;
v1 = jsondecode(jsonencode(v1));
end

function v1 = parameters(id)
tpl = loadTemplate('stimulus_response_scalar_parameters_basic');
parentTpl = loadTemplate('stimulus_response_scalar_parameters');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '412696f9abd9edc3_40dbbdf6582271b2';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.stimulus_response_scalar_parameters = parentTpl.stimulus_response_scalar_parameters;
v1.stimulus_response_scalar_parameters_basic = struct( ...
    'temporalfreqfunc', 'ndi.fun.stimulustemporalfrequency', ...
    'freq_response', 0, 'prestimulus_time', [], ...
    'prestimulus_normalization', [], 'isspike', 1, 'spiketrain_dt', 0.001);
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
tpl = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', ...
    [name '.json'])));
end

% ===================== helpers ============================================

function out = runRaw(batch)
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
end

function c = outputsOf(out, id)
c = {};
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    if isfield(s, 'base') && isfield(s.base, 'id') && strcmp(char(s.base.id), id)
        c{end+1} = s; %#ok<AGROW>
    end
end
% the documents minted with it (anchor, software, a second calculation)
% are added only when the caller passes all of out.migrated
end

function c = outputsExcept(out, ids)
%OUTPUTSEXCEPT What the batch emitted, less the documents of the other sources
%   (by id; the other sources here emit only themselves)
c = {};
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    if ~(isfield(s, 'base') && isfield(s.base, 'id') && any(strcmp(char(s.base.id), ids)))
        c{end+1} = s; %#ok<AGROW>
    end
end
end

function b = firstOfClass(out, cls)
c = allOfClass(out, cls);
b = [];
if ~isempty(c); b = c{1}; end
end

function c = allOfClass(out, cls)
c = {};
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.className(), cls)
        c{end+1} = out.migrated{k}.toStruct(); %#ok<AGROW>
    end
end
end

function t = parameterText(leaf, name)
t = '';
if ~isfield(leaf, 'interaction') || ~isfield(leaf.interaction, 'method') ...
        || ~isfield(leaf.interaction.method, 'parameters')
    return;
end
p = asCell(leaf.interaction.method.parameters);
for k = 1:numel(p)
    if strcmp(char(p{k}.variable.name), name)
        t = char(p{k}.text);
        return;
    end
end
end

function s = constraintText(e)
s = '';
if ~isfield(e, 'constraints') || isempty(e.constraints)
    return;
end
c = asCell(e.constraints);
parts = cellfun(@(x) sprintf('%s=%g', char(x.variable.name), x.value), c, ...
    'UniformOutput', false);
s = strjoin(sort(parts), ';');
end

function ids = edges(b, name)
ids = {};
d = asCell(b.depends_on);
for k = 1:numel(d)
    if strcmp(char(d{k}.name), name)
        v = '';
        for key = {'document_id', 'value'}
            if isfield(d{k}, key{1}) && ~isempty(d{k}.(key{1}))
                v = char(d{k}.(key{1}));
                break;
            end
        end
        ids{end+1} = v; %#ok<AGROW>
    end
end
end

function c = asCell(v)
if iscell(v)
    c = reshape(v, 1, []);
elseif isstruct(v)
    c = num2cell(reshape(v, 1, []));
else
    c = {};
end
end

function tf = schemaHasContrastMetrics()
tf = false;
try
    s = did2.schema.cache.shared().getClass('tuning_curve');
catch
    return;
end
path = {'value', 'model_fit', 'metrics', 'relative_max_gain'};
f = s;
for k = 1:numel(path)
    fs = f.fields;
    if isstruct(fs); fs = num2cell(fs); end
    hit = [];
    for j = 1:numel(fs)
        if strcmp(fs{j}.name, path{k}); hit = fs{j}; break; end
    end
    if isempty(hit); return; end
    f = hit;
end
tf = true;
end
