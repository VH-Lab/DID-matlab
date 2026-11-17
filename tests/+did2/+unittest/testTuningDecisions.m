function tests = testTuningDecisions
%TESTTUNINGDECISIONS Jess Haley's 2026-10-27 tuning and response decisions
%   (did-schema V_eta_go_forward_class_audit.md), one test (or more) per tag:
%
%     [tuning fits use curve fitting now]        testFitsUseCurveFittingAndStateTheModelOnce
%     [one calculation per named calculator output] (2026-10-28)
%                                                testFitsUseCurveFittingAndStateTheModelOnce,
%                                                testOneCalculationPerOutput
%     [fit model stated once] (2026-10-29)       testFitsUseCurveFittingAndStateTheModelOnce
%     [tuning best value is a condition] (2026-10-28)  testTuningBestValue*
%     [tuning stated value is a condition] (2026-11-11)  testTuningStatedValue*
%     [Priebe fits are one function]             testPriebeFitsAreOneFunction
%     [Naka-Rushton function minted] (2026-10-30)  testNakaRushtonFitsAreOneModelToldApartByConstraints,
%                                                testTheBareNakaRushtonLabelStillRoundTrips
%     [tuning fit coefficients named by symbol] (2026-11-11)  testFitsAreNamedBySymbol*,
%                                                testATemporalFrequencyDoGWithNoLeadingZeroIsCarried,
%                                                testContrastSensitivityIsOneFitPerSpatialFrequency
%     [contrast sensitivity repeated fit is a known v1 defect] (2026-11-12),
%     [known v1 defects list] (2026-11-12)  testARepeatedSpatialFrequencyIsAKnownV1Defect
%     [hotelling spellings are one field]        testHotellingSpellingsAreOneField
%     [input names rebuild from the input class] testInputNames*
%     [tuning stimids rebuild]                   testTuningStimids*
%     [tuning log in notes]                      testTuningLogInNotes
%     [varied properties are conditions by V2 name]  testVariedProperties*
%     [parameter names map by table]             testParameterNames*
%     [absolute-value fits are fit entries] (2026-10-28; supersedes
%       [absolute-value fits are a second calculation])  testAbsoluteValueFits*,
%                                                testOneCalculationPerOutput
%     [interpolated values are a list] (2026-10-30)  testInterpolatedValues*,
%                                                testAnAbsBlockOfOnlyInterpolatedValuesIsNoSecondCalculation
%                                                (each on a schema copy with and
%                                                without the list:
%                                                helpers.interpolatedListSchema)
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

function testFitsUseCurveFittingAndStateTheModelOnce(testCase)
% INVERTED 2026-10-29 from testFitsUseCurveFitting, which pinned a
% {function: <model>} method parameter on a calculation whose fits share one
% model. Decided by Jess Haley, 2026-10-29 [fit model stated once] (did-schema
% V_eta_go_forward_class_audit.md): such a calculation writes no `function`
% parameter; the model is stated in each fit entry, and the round trip
% rebuilds v1 from those entries. The method keeps its term OBI:0200072.
cases = { ...
    'oridir', writerOutput('oridirtuning_calc'), 'orientation_direction_tuning_calculation', ...
        'double Gaussian direction tuning function'; ...   % [tuning fit coefficients named by symbol]
    'contrast', convertedContrast(), 'contrast_tuning_calculation', 'Naka-Rushton function'; ...   % [Naka-Rushton function minted]
    'speed', writerOutput('speedtuning_calc'), 'speed_tuning_calculation', 'Priebe fit'; ...
    'SF', writerOutput('spatial_frequency_tuning_calc'), ...
        'spatial_frequency_tuning_calculation', ''};
% [one calculation per named calculator output] (Jess Haley, 2026-10-28): the
% method holds no `function` list; the SF fits' five models are named by their
% model_fit entries only (FN '' below: several models)
for k = 1:size(cases, 1)
    [label, v1, leafClass, fn] = cases{k, :};
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, label);
    leaf = firstOfClass(out, leafClass);
    assertNotEmpty(testCase, leaf, [label ': no ' leafClass]);
    term = leaf.interaction.method.term;
    verifyEqual(testCase, char(term.node), 'OBI:0200072', label);
    verifyEqual(testCase, parameterCount(leaf, 'function'), 0, ...
        [label ': [fit model stated once] writes no function parameter']);
    mf = asCell(leaf.tuning_curve.value.model_fit);
    models = cellfun(@(e) char(e.model.name), mf, 'UniformOutput', false);
    verifyTrue(testCase, all(cellfun(@(m) ~isempty(m), models)), ...
        [label ': each fit entry states its model']);
    if ~isempty(fn)
        verifyEqual(testCase, unique(models), {fn}, ...
            [label ': the one model is stated in every fit entry']);
    else
        verifyGreaterThan(testCase, numel(unique(models)), 1, label);
    end
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
% a tuning curve is not a fit: its method is EDAM:operation_2945 "Data
% analysis" ([data analysis is the general method], Jess Haley, 2026-10-30;
% INVERTED from "its method stays the calculator")
v1 = convertedTuningCurve();
out = runRaw({v1});
leaf = firstOfClass(out, 'tuning_curve_calculation');
t = leaf.interaction.method.term;
verifyEqual(testCase, char(t.node), 'EDAM:operation_2945');
end

function testOneCalculationPerOutput(testCase)
% [one calculation per named calculator output] (Jess Haley, 2026-10-28): one
% v1 output, one calculation, its id the v1 id, its fits model_fit entries
% each naming its own model. Since [absolute-value fits are fit entries]
% (Decided by Jess Haley, 2026-10-28) the SF / TF `abs` block is on the same
% calculation too: its five fits are five more entries, marked
% response_transform 'absolute value' (testAbsoluteValueFitsAreFitEntries);
% NFITS counts the entries fit to the responses as stated. Run with
% `interpolated_values` a list declared, without which the SF / TF `abs.fitless`
% has no home and the document carries.
did2.unittest.helpers.interpolatedListSchema(testCase, true);
cases = { ...
    'oridir', writerOutput('oridirtuning_calc'), 'orientation_direction_tuning_calculation', 1; ...
    'contrast', convertedContrast(), 'contrast_tuning_calculation', 3; ...
    'speed', writerOutput('speedtuning_calc'), 'speed_tuning_calculation', 3; ...
    'SF', writerOutput('spatial_frequency_tuning_calc'), ...
        'spatial_frequency_tuning_calculation', 5; ...
    'TF', writerOutput('temporal_frequency_tuning_calc'), ...
        'temporal_frequency_tuning_calculation', 5};
for k = 1:size(cases, 1)
    [label, v1, leafClass, nFits] = cases{k, :};
    out = runRaw({v1});
    calcs = allOfClass(out, leafClass);
    mine = calcs(cellfun(@(c) strcmp(char(c.base.id), v1.base.id), calcs));
    assertEqual(testCase, numel(mine), 1, [label ': one calculation holds the v1 id']);
    mf = asCell(mine{1}.tuning_curve.value.model_fit);
    mf = mf(cellfun(@(e) isempty(fitTransform(e)), mf));
    verifyEqual(testCase, numel(mf), nFits, [label ': every fit is an entry']);
    verifyTrue(testCase, all(cellfun(@(e) ~isempty(char(e.model.name)), mf)), ...
        [label ': each entry names its model']);
end
end

function testNakaRushtonFitsAreOneModelToldApartByConstraints(testCase)
% UPDATED 2026-10-30. Decided by Jess Haley, 2026-10-30, did-schema
% V_eta_go_forward_class_audit.md [Naka-Rushton function minted]: the one
% model is the term EMPTY:0000416 "Naka-Rushton function", not the bare label
% 'Naka-Rushton'; the coefficients keep their names. The term registry this
% test reads (did-schema main) need not hold the row yet (did-schema #242):
% setupOnce disarms the TermRegistry check, and the term is written by node.
out = runRaw({convertedContrast()});
leaf = firstOfClass(out, 'contrast_tuning_calculation');
mf = asCell(leaf.tuning_curve.value.model_fit);
verifyEqual(testCase, numel(mf), 3);
held = cell(1, 3);
for k = 1:3
    verifyEqual(testCase, char(mf{k}.model.node), 'EMPTY:0000416');
    verifyEqual(testCase, char(mf{k}.model.name), 'Naka-Rushton function');
    held{k} = constraintText(mf{k});
end
% UPDATED 2026-11-11 ([tuning fit coefficients named by symbol], Jess Haley):
% the constraints name the symbols n and s ('Naka-Rushton parameter 3' and
% '... 4' before)
verifyEqual(testCase, sort(held), sort({'n=1;s=1', 's=1', ''}));
end

function testTheBareNakaRushtonLabelStillRoundTrips(testCase)
% [Naka-Rushton function minted] (Jess Haley, 2026-10-30): the round trip reads
% the model by node, and a contrast fit migrated before the decision, whose
% model is the bare label 'Naka-Rushton', still rebuilds the v1 document.
v1 = convertedContrast();
out = runRaw({v1});
verifyEmpty(testCase, out.quarantine);
bodies = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
changed = 0;
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isfield(b, 'tuning_curve') || ~isfield(b.tuning_curve, 'value') ...
            || ~isfield(b.tuning_curve.value, 'model_fit')
        continue;
    end
    mf = b.tuning_curve.value.model_fit;
    wasStruct = isstruct(mf);
    mf = asCell(mf);
    for j = 1:numel(mf)
        if strcmp(char(mf{j}.model.node), 'EMPTY:0000416')
            mf{j}.model = struct('node', '', 'name', 'Naka-Rushton');
            changed = changed + 1;
        end
    end
    if wasStruct; mf = [mf{:}]; end
    b.tuning_curve.value.model_fit = mf;
    bodies{k} = b;
end
verifyEqual(testCase, changed, 3, 'the three Naka-Rushton fits were relabelled');
r = did2.convert.roundtrip.check(v1, bodies);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'contrast, bare Naka-Rushton label', {});
end

% ============== [tuning fit coefficients named by symbol] =================
% Decided by Jess Haley, 2026-11-11 (did-schema
% docs/plans/did_v2_go_forward_class_audit.md): a migrated tuning fit names
% each coefficient and constraint by its symbol in the writer's equation, its
% model by one registered term (EMPTY:0000416, EMPTY:0000441-0000445), and
% fills `equation` with the writer's formula; the round trip gives v1 back.

function testFitsAreNamedBySymbolDoubleGaussian(testCase)
v1 = writerOutput('oridirtuning_calc');
mf = fitsOf(testCase, v1, 'orientation_direction_tuning_calculation');
assertEqual(testCase, numel(mf), 1);
verifyNamedFit(testCase, mf{1}, 'EMPTY:0000441', {'Rsp', 'Rp', 'Op', 'sig', 'Rn'}, ...
    v1.orientation_direction_tuning.fit.double_gaussian_parameters, '', true);
verifySymbolsInEquation(testCase, mf{1});
verifyRoundTripOf(testCase, v1, 'oridir');
end

function testFitsAreNamedBySymbolNakaRushton(testCase)
v1 = convertedContrast();
mf = fitsOf(testCase, v1, 'contrast_tuning_calculation');
assertEqual(testCase, numel(mf), 3);
fit = v1.contrast_tuning.fit;
want = struct('RB', {{'Rm', 'c50'}}, 'RBN', {{'Rm', 'c50', 'n'}}, ...
    'RBNS', {{'Rm', 'c50', 'n', 's'}});
held = struct('RB', 'n=1;s=1', 'RBN', 's=1', 'RBNS', '');
for V = {'RB', 'RBN', 'RBNS'}
    e = mf(cellfun(@(x) strcmp(constraintText(x), held.(V{1})), mf));
    assertEqual(testCase, numel(e), 1, V{1});
    verifyNamedFit(testCase, e{1}, 'EMPTY:0000416', want.(V{1}), ...
        fit.(['naka_rushton_' V{1} '_parameters']), held.(V{1}), true);
    verifySymbolsInEquation(testCase, e{1});
end
verifyRoundTripOf(testCase, v1, 'contrast');
end

function testFitsAreNamedBySymbolFrequencyModels(testCase)
% SF and TF: difference of Gaussians, Movshon 2005 (movshon with C = 0,
% movshon c with none), log-Gaussian and the cubic spline, as stated and in
% the abs block. The TF difference of Gaussians' leading constant 0 is not a
% coefficient (temporal_frequency_analysis.m `dog_par = [0 dog_par]`) and the
% round trip restores it.
did2.unittest.helpers.interpolatedListSchema(testCase, true);
cases = {'spatial_frequency_tuning_calc', 'spatial_frequency_tuning', ...
        'spatial_frequency_tuning_calculation', false; ...
    'temporal_frequency_tuning_calc', 'temporal_frequency_tuning', ...
        'temporal_frequency_tuning_calculation', true};
for k = 1:size(cases, 1)
    [cls, blockName, leafClass, leadingZero] = cases{k, :};
    v1 = writerOutput(cls);
    mfAll = fitsOf(testCase, v1, leafClass);
    assertEqual(testCase, numel(mfAll), 10, [cls ': five fits as stated, five of |response|']);
    transforms = cellfun(@fitTransform, mfAll, 'UniformOutput', false);
    for t = {'', 'absolute value'}
        mf = mfAll(strcmp(transforms, t{1}));
        src = v1.(blockName);
        if ~isempty(t{1}); src = src.abs; end
        label = sprintf('%s (%s)', cls, t{1});
        nodes = cellfun(@(e) char(e.model.node), mf, 'UniformOutput', false);
        verifyEqual(testCase, sort(nodes), sort({'EMPTY:0000442', 'EMPTY:0000443', ...
            'EMPTY:0000443', 'EMPTY:0000444', 'EMPTY:0000445'}), label);
        dog = src.fit_dog.parameters;
        if leadingZero
            verifyEqual(testCase, double(dog(1)), 0, [label ': the writer''s leading 0']);
            dog = dog(2:end);
        end
        verifyNamedFit(testCase, onlyFit(testCase, mf, 'EMPTY:0000442', ''), 'EMPTY:0000442', ...
            {'a1', 'b1', 'a2', 'b2'}, dog, '', true);
        verifyNamedFit(testCase, onlyFit(testCase, mf, 'EMPTY:0000443', 'C=0'), 'EMPTY:0000443', ...
            {'k', 'fc', 'fh', 'B'}, src.fit_movshon.parameters, 'C=0', true);
        verifyNamedFit(testCase, onlyFit(testCase, mf, 'EMPTY:0000443', ''), 'EMPTY:0000443', ...
            {'k', 'fc', 'fh', 'B', 'C'}, src.fit_movshon_c.parameters, '', true);
        verifyNamedFit(testCase, onlyFit(testCase, mf, 'EMPTY:0000444', ''), 'EMPTY:0000444', ...
            {'a', 'b', 'c', 'd'}, src.fit_gausslog.parameters, '', true);
        sp = onlyFit(testCase, mf, 'EMPTY:0000445', '');
        verifyNamedFit(testCase, sp, 'EMPTY:0000445', {}, [], '', false);
        verifyFalse(testCase, isfield(sp, 'equation') && ~isempty(sp.equation), ...
            [label ': an interpolation has no equation']);
        for e = mf
            if ~strcmp(char(e{1}.model.node), 'EMPTY:0000445')
                verifySymbolsInEquation(testCase, e{1});
            end
        end
    end
    % the round trip gives back fit_movshon and fit_movshon_c by the
    % constraint, and (TF) the DoG's leading 0
    verifyRoundTripOf(testCase, v1, cls);
end
end

function testATemporalFrequencyDoGWithNoLeadingZeroIsCarried(testCase)
% [tuning fit coefficients named by symbol] (1): a TF difference of Gaussians
% whose leading value is not the writer's constant 0 has no faithful naming;
% it stays unplaced and the document is carried (carry-056)
did2.unittest.helpers.interpolatedListSchema(testCase, true);
v1 = writerOutput('temporal_frequency_tuning_calc');
v1.temporal_frequency_tuning.fit_dog.parameters(1) = 0.5;
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried, 'carried whole as v1');
verifyEqual(testCase, did2.unittest.helpers.carryRowFor(notes, ...
    'temporal_frequency_tuning.fit_dog.parameters'), 'carry-056', notes);
% the same vector with its leading 0 converts
v1 = writerOutput('temporal_frequency_tuning_calc');
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyFalse(testCase, carried, notes);
end

function testContrastSensitivityIsOneFitPerSpatialFrequency(testCase)
% [tuning fit coefficients named by symbol] (3): the Naka-Rushton term and
% symbols, one fit per spatial frequency and variant, the fixed values as
% constraints; the fit's spatial frequency is its position along the value's
% one spatial-frequency dimension; the round trip gives v1 back
v1 = writerOutput('contrastsensitivity_calc');
out = runRaw({v1});
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'the contrast sensitivity writer output converts');
leaf = firstOfClass(out, 'contrast_sensitivity_calculation');
assertNotEmpty(testCase, leaf);
mf = asCell(leaf.contrast_sensitivity.value.model_fit);
blk = v1.contrastsensitivity_calc;
nSF = numel(blk.spatial_frequencies);
assertEqual(testCase, numel(mf), 3 * nSF, 'one fit per variant and spatial frequency');
want = struct('RB', {{'Rm', 'c50'}}, 'RBN', {{'Rm', 'c50', 'n'}}, ...
    'RBNS', {{'Rm', 'c50', 'n', 's'}});
held = struct('RB', 'n=1;s=1', 'RBN', 's=1', 'RBNS', '');
for V = {'RB', 'RBN', 'RBNS'}
    e = mf(cellfun(@(x) strcmp(constraintText(x), held.(V{1})), mf));
    assertEqual(testCase, numel(e), nSF, V{1});
    P = blk.(['parameters_' V{1}]);
    S = blk.(['sensitivity_' V{1}]);
    G = blk.(['relative_max_gain_' V{1}]);
    for j = 1:nSF
        verifyNamedFit(testCase, e{j}, 'EMPTY:0000416', want.(V{1}), P(:, j), held.(V{1}), true);
        verifyEqual(testCase, e{j}.sensitivity(:), S(:, j), sprintf('%s fit %d', V{1}, j));
        verifyEqual(testCase, e{j}.relative_max_gain, G(j), sprintf('%s fit %d', V{1}, j));
    end
end
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'contrast sensitivity', {});
end

function testARepeatedSpatialFrequencyIsAKnownV1Defect(testCase)
% [contrast sensitivity repeated fit is a known v1 defect] and
% [known v1 defects list] (Jess Haley, 2026-11-12): a contrast sensitivity
% result whose spatial frequencies are more than one and all one value (Soph:
% the input tuning curves were all made at the first spatial frequency,
% NDI-matlab 49a875c94) is migrated unchanged, and the run's migration report
% lists ONE known v1 defect for it, of contrast_sensitivity.value.model_fit,
% and no gap; a result with distinct frequencies gets none
normal = writerOutput('contrastsensitivity_calc');
assertGreaterThan(testCase, numel(unique(normal.contrastsensitivity_calc.spatial_frequencies)), 1, ...
    'the writer output has distinct spatial frequencies');
out = runRaw({normal});
verifyEmpty(testCase, out.migration_report.known_v1_defects, 'distinct frequencies: no defect');
verifyEqual(testCase, out.migration_report.counts.known_v1_defects, 0);

repeated = normal;
blk = repeated.contrastsensitivity_calc;
sf = blk.spatial_frequencies;
blk.spatial_frequencies = repmat(sf(1), size(sf));
repeated.contrastsensitivity_calc = blk;
out = runRaw({repeated});
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'the document still converts');
leaf = firstOfClass(out, 'contrast_sensitivity_calculation');
assertNotEmpty(testCase, leaf);
d = out.migration_report.known_v1_defects;
assertEqual(testCase, numel(d), 1, 'one entry per affected document');
verifyEqual(testCase, d(1).document_id, char(repeated.base.id));
verifyEqual(testCase, d(1).class, 'contrast_sensitivity_calculation');
verifyEqual(testCase, d(1).field, 'contrast_sensitivity.value.model_fit');
verifyTrue(testCase, contains(d(1).reason, '49a875c94') ...
    && contains(d(1).reason, 'tuningcurve.m'), d(1).reason);
verifyEqual(testCase, out.migration_report.counts.known_v1_defects, 1);
verifyEmpty(testCase, out.migration_report.gaps, 'a defect is not a gap');
verifyEmpty(testCase, did2.convert.migrationReport('gaps', char(repeated.base.id)));
% the document is the same as with distinct frequencies but for the
% frequencies themselves: the fits are written as v1 wrote them
mf = asCell(leaf.contrast_sensitivity.value.model_fit);
verifyEqual(testCase, numel(mf), 3 * numel(sf));
r = did2.convert.roundtrip.check(repeated, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'contrast sensitivity, repeated frequency', {});
end

function mf = fitsOf(testCase, v1, leafClass)
% the model_fit entries of V1's one calculation of LEAFCLASS (converted)
out = runRaw({v1});
verifyEmpty(testCase, out.quarantine, leafClass);
verifyEmpty(testCase, out.passthrough, [leafClass ': converts']);
leaf = firstOfClass(out, leafClass);
assertNotEmpty(testCase, leaf, leafClass);
mf = asCell(leaf.tuning_curve.value.model_fit);
end

function e = onlyFit(testCase, mf, node, held)
% the one entry of MF whose model is NODE and whose constraints read HELD
hit = cellfun(@(x) strcmp(char(x.model.node), node) && strcmp(constraintText(x), held), mf);
assertEqual(testCase, nnz(hit), 1, sprintf('one %s fit with constraints "%s"', node, held));
e = mf{hit};
end

function verifyNamedFit(testCase, e, node, symbols, values, held, hasEquation)
% E's model is NODE, its coefficients are SYMBOLS (in order) with VALUES, its
% constraints read HELD, and it has an equation when HASEQUATION
label = sprintf('%s [%s]', node, strjoin(symbols, ' '));
verifyEqual(testCase, char(e.model.node), node, label);
verifyNotEmpty(testCase, char(e.model.name), label);
c = asCell(getFieldOr(e, 'coefficients'));
names = reshape(cellfun(@(x) char(x.variable.name), c, 'UniformOutput', false), 1, []);
verifyEqual(testCase, names, reshape(symbols, 1, []), [label ': coefficient symbols']);
verifyTrue(testCase, all(cellfun(@(x) isempty(getFieldOr(x.variable, 'node')), c)), ...
    [label ': a symbol is a label, not a term']);
if ~isempty(c)
    verifyEqual(testCase, cellfun(@(x) double(x.value), c), reshape(double(values), 1, []), ...
        [label ': the v1 vector, in stored order']);
end
verifyEqual(testCase, constraintText(e), held, [label ': constraints']);
if hasEquation
    verifyTrue(testCase, isfield(e, 'equation') && ~isempty(e.equation), [label ': equation']);
end
end

function verifySymbolsInEquation(testCase, e)
% every coefficient and constraint symbol of E appears in its equation
eq = char(e.equation);
c = [asCell(getFieldOr(e, 'coefficients')), asCell(getFieldOr(e, 'constraints'))];
for k = 1:numel(c)
    sym = char(c{k}.variable.name);
    verifyTrue(testCase, ~isempty(regexp(eq, ['(?<![A-Za-z0-9])' sym '(?![A-Za-z0-9])'], 'once')), ...
        sprintf('symbol %s is in "%s"', sym, eq));
end
end

function verifyRoundTripOf(testCase, v1, label)
out = runRaw({v1});
r = did2.convert.roundtrip.check(v1, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end

function v = getFieldOr(s, name)
v = [];
if isstruct(s) && isfield(s, name)
    v = s.(name);
end
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
    cs = did2.unittest.helpers.tuningSummary(leaf, 'circular_statistics');   % [tuning summaries in the value]
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

% ===================== [tuning best value is a condition] =================

function testTuningBestValueIsACondition(testCase)
% Decided by Jess Haley, 2026-10-28 [tuning best value is a condition]: the
% value an `angle ... best` selection chose (the log's "angle best value is
% 90.") is a condition (orientation = 90), and the stimid rebuild works from
% it. Amended by [tuning selection rule stated once] (Jess Haley, 2026-11-09,
% "A"): the rule is stated once, in the v1 `selection` setting; no
% "<V2 name> selection" = best method parameter is written beside it.
% The presentation shows each contrast at angle 90 (stimuli 1-6) and at angle
% 0 (7-12); the writer kept angle 90, so v1 stimid is 1-6.
[tc, resp, pres] = bestCurveBatch();
% WITHOUT the condition, the rebuild takes the last stimulus at each contrast
% (angle 0) and differs from v1: such a curve was carried before 2026-10-28
did2.convert.tuningBatchIndex('reset');
did2.convert.tuningBatchIndex('load', {resp, pres});
noCond = did2.convert.tuningStimids(tc.stimulus_tuningcurve.independent_variable_value, ...
    {'contrast'}, {}, [], resp.base.id);
verifyEqual(testCase, noCond, (7:12)', 'without the best value the rebuild picks angle 0');
withCond = did2.convert.tuningStimids(tc.stimulus_tuningcurve.independent_variable_value, ...
    {'contrast'}, {'angle'}, 90, resp.base.id);
verifyEqual(testCase, withCond, tc.stimulus_tuningcurve.stimid, 'with it, v1''s stimids');
% the migration
out = runRaw({tc, resp, pres});
verifyEmpty(testCase, out.quarantine);
mine = outputsOf(out, tc.base.id);
notes = '';
if isfield(out.summary.migration_notes, 'carried_as_v1')
    notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' || ');
end
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2', ...
    ['the best-selected curve converts; carried: ' notes]);
leaf = mine{1};
c = asCell(leaf.statement.conditions);
assertEqual(testCase, numel(c), 1);
% `angle` is NCIT:C42677 "Direction" (Jess Haley, 2026-11-03, "Ok": a tuning
% angle runs 0-360, the direction of motion), not "orientation"
verifyEqual(testCase, lower(char(c{1}.variable.name)), 'direction');
verifyEqual(testCase, c{1}.quantity.value, 90);
verifyEqual(testCase, parameterCount(leaf, 'Direction selection'), 0, ...
    '[tuning selection rule stated once]: no per-parameter rule');
verifyFalse(testCase, any(endsWith(parameterNames(leaf), ' selection')), ...
    sprintf('no ''<V2 name> selection'' parameter; parameters: %s', ...
    strjoin(parameterNames(leaf), ', ')));
verifyNotEmpty(testCase, parameterText(leaf, 'selection criterion'), ...
    'the rule stays in the v1 `selection` setting');
verifyEqual(testCase, leaf.statement.notes, tc.tuningcurve_calc.log, '[tuning log in notes]');
n = out.summary.migration_notes.tuning_stimid_rebuild;
verifyEqual(testCase, n.count, 1, 'one note per curve: the denominator');
verifyEqual(testCase, n.distinct_details, {'rebuilt exactly'});
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'best-selected tuning curve', {});
verifyTrue(testCase, any(strcmp('stimulus_tuningcurve.stimid', r.matched)));
end

function testABestSelectionRuleFromAnEarlierMigrationStillRoundTrips(testCase)
% [tuning selection rule stated once] (Jess Haley, 2026-11-09): a batch
% migrated before it carries a 'Direction selection' = best parameter; the
% round trip still reads it back when it names the setting's best selection,
% and reports it unplaced when it names another variable
[tc, resp, pres] = bestCurveBatch();
out = runRaw({tc, resp, pres});
docs = outputsExcept(out, {resp.base.id, pres.base.id});
mine = outputsOf(out, tc.base.id);
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2');
ix = find(cellfun(@(d) strcmp(char(d.base.id), char(mine{1}.base.id)), docs), 1);
assertNotEmpty(testCase, ix);
older = docs;
older{ix} = withParameter(docs{ix}, 'selection criterion', 'Direction selection', 'best');
r = did2.convert.roundtrip.check(tc, older);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'an earlier migration''s rule', {});
other = docs;
other{ix} = withParameter(docs{ix}, 'selection criterion', 'Contrast selection', 'best');
r = did2.convert.roundtrip.check(tc, other);
verifyNotEmpty(testCase, r.unplaced, 'a rule naming another variable is not the setting''s');
end

function leaf = withParameter(leaf, likeName, name, text)
% LEAF with one more method parameter NAME = TEXT, shaped like its LIKENAME one
p = asCell(leaf.interaction.method.parameters);
k = find(cellfun(@(e) strcmp(char(e.variable.name), likeName), p), 1);
e = p{k};
e.variable.name = name;
if isfield(e.variable, 'node'); e.variable.node = ''; end
e.text = text;
p{end+1} = e;
leaf.interaction.method.parameters = p;
end

function n = parameterNames(leaf)
n = {};
if ~isfield(leaf, 'interaction') || ~isfield(leaf.interaction, 'method') ...
        || ~isfield(leaf.interaction.method, 'parameters')
    return;
end
n = cellfun(@(e) char(e.variable.name), asCell(leaf.interaction.method.parameters), ...
    'UniformOutput', false);
end

function testTuningBestValueBesideADealtProperty(testCase)
% the older writer's log ("angle best value is 90.sz_{1}dealing sFrequency =
% 0.5,"): the dealt property stays stim_property_list, the best value is a
% second condition, and the round trip gives each back to its own field
[tc, resp, pres] = bestCurveBatch();
tc.tuningcurve_calc.log = 'angle best value is 90.sz_{1}dealing sFrequency = 0.5,';
tc.tuningcurve_calc.stim_property_list = struct('names', {{'sFrequency'}}, 'values', 0.5);
tc = jsondecode(jsonencode(tc));
out = runRaw({tc, resp, pres});
mine = outputsOf(out, tc.base.id);
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2');
c = asCell(mine{1}.statement.conditions);
got = sort(cellfun(@(x) lower(char(x.variable.name)), c, 'UniformOutput', false));
verifyEqual(testCase, got, {'direction', 'spatial frequency'});
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'best value beside a dealt property', {});
verifyTrue(testCase, any(startsWith(r.matched, 'tuningcurve_calc.stim_property_list')), ...
    'the dealt property is rebuilt into stim_property_list');
end

function testATuningBestValueTheLogDoesNotStateIsCarried(testCase)
% "a curve whose log does not state the chosen value is carried as before
% (carry-056)"
[tc, resp, pres] = bestCurveBatch();
tc.tuningcurve_calc.log = '';
[carried, notes] = did2.unittest.helpers.carryNote({tc, resp, pres});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-056] tuningcurve_calc.log'), notes);
verifyTrue(testCase, contains(notes, '[tuning best value is a condition]'), notes);
end

function testTuningBestValuesFunction(testCase)
sel = struct('property', {'angle', 'contrast', 'angle'}, ...
    'operation', {'hasfield', 'hasfield', 'exact_number'}, 'value', {'varies', 'varies', 'best'});
ip = struct('selection', sel);
[p, v, why] = did2.convert.tuningBestValues(ip, 'angle best value is 90.');
verifyEqual(testCase, p, {'angle'});
verifyEqual(testCase, v, 90);
verifyEmpty(testCase, why);
[~, v] = did2.convert.tuningBestValues(ip, 'angle best value is 135.sz_{1}dealing sFrequency = 0.04,');
verifyEqual(testCase, v, 135, 'the older writer''s log');
ip2 = struct('selection', struct('property', {'sFrequency', 'tFrequency'}, ...
    'operation', {'exact_number', 'exact_number'}, 'value', {'best', 'Best'}));
[p, v] = did2.convert.tuningBestValues(ip2, 'sFrequency best value is 0.08,tFrequency best value is 1.');
verifyEqual(testCase, p, {'sFrequency', 'tFrequency'});
verifyEqual(testCase, v, [0.08 1]);
[p, v, why] = did2.convert.tuningBestValues(ip, '');
verifyEqual(testCase, p, {'angle'});
verifyEmpty(testCase, v);
verifyNotEmpty(testCase, why, 'a log that does not state it');
[~, ~, why] = did2.convert.tuningBestValues(ip, 'xangle best value is 90.');
verifyNotEmpty(testCase, why, 'only a whole property name');
[p, ~, why] = did2.convert.tuningBestValues(struct('selection', sel(1:2)), 'anything');
verifyEmpty(testCase, p, 'no best selection');
verifyEmpty(testCase, why);
end

% ===================== [tuning log in notes] ==============================

% ===================== [tuning stated value is a condition] ==============

function testTuningStatedValueIsACondition(testCase)
% Decided by Jess Haley, 2026-11-11 [tuning stated value is a condition]: a
% curve whose writer chose its stimuli with a selection fixing a property at a
% stated number (tFrequency exact_number 4, as Soph's 1622 angle curves) has
% that property and value as a condition (temporal frequency = 4), and the
% stimid rebuild works from it. The presentation shows each contrast at
% tFrequency 4 (stimuli 1-6) and at tFrequency 8 (7-12); the writer kept 4, so
% v1 stimid is 1-6. Such a curve was carried before (carry-056, "the
% presentation and the response give other values").
[tc, resp, pres] = statedCurveBatch();
did2.convert.tuningBatchIndex('reset');
did2.convert.tuningBatchIndex('load', {resp, pres});
noCond = did2.convert.tuningStimids(tc.stimulus_tuningcurve.independent_variable_value, ...
    {'contrast'}, {}, [], resp.base.id);
verifyEqual(testCase, noCond, (7:12)', 'without the stated value the rebuild picks tFrequency 8');
out = runRaw({tc, resp, pres});
verifyEmpty(testCase, out.quarantine);
mine = outputsOf(out, tc.base.id);
notes = '';
if isfield(out.summary.migration_notes, 'carried_as_v1')
    notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' || ');
end
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2', ...
    ['the curve with a stated value converts; carried: ' notes]);
leaf = mine{1};
c = asCell(leaf.statement.conditions);
assertEqual(testCase, numel(c), 1);
verifyEqual(testCase, lower(char(c{1}.variable.name)), 'temporal frequency');
verifyEqual(testCase, c{1}.quantity.value, 4);
verifyFalse(testCase, any(endsWith(parameterNames(leaf), ' selection')), ...
    sprintf('no ''<V2 name> selection'' parameter; parameters: %s', ...
    strjoin(parameterNames(leaf), ', ')));
verifyNotEmpty(testCase, parameterText(leaf, 'selection criterion'), ...
    'the rule stays in the v1 `selection` setting');
n = out.summary.migration_notes.tuning_stimid_rebuild;
verifyEqual(testCase, n.count, 1, 'one note per curve: the denominator');
verifyEqual(testCase, n.distinct_details, {'rebuilt exactly'});
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'tuning curve with a stated value', {});
verifyTrue(testCase, any(strcmp('stimulus_tuningcurve.stimid', r.matched)));
verifyTrue(testCase, any(strcmp('stimulus_tuningcurve.stimulus_presentation_number', r.matched)));
verifyTrue(testCase, any(startsWith(r.matched, 'tuningcurve_calc.input_parameters.selection')), ...
    'the v1 selection is written back unchanged');
end

function testTuningStatedValueBesideABestValue(testCase)
% a `best` selection and a stated number on one curve: two conditions, each
% read back to its own place (the best value to the log, the stated number to
% the selection), and stim_property_list stays empty
[tc, resp, pres] = statedCurveBatch();
sel = asCell(tc.tuningcurve_calc.input_parameters.selection);
sel{end+1} = struct('property', 'angle', 'operation', 'exact_number', 'value', 'best');
tc.tuningcurve_calc.input_parameters.selection = sel;
tc.tuningcurve_calc.log = 'angle best value is 90.';
st = pres.stimulus_presentation.stimuli;
if iscell(st); st = [st{:}]; end
st = reshape(st, 1, []);
at90 = st;
at0 = st;
for k = 1:numel(st)
    at90(k).parameters.angle = 90;
    at0(k).parameters.angle = 0;
end
pres.stimulus_presentation.stimuli = [at90, at0];
tc = jsondecode(jsonencode(tc));
pres = jsondecode(jsonencode(pres));
out = runRaw({tc, resp, pres});
mine = outputsOf(out, tc.base.id);
notes = '';
if isfield(out.summary.migration_notes, 'carried_as_v1')
    notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' || ');
end
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2', ...
    ['carried: ' notes]);
c = asCell(mine{1}.statement.conditions);
got = sort(cellfun(@(x) lower(char(x.variable.name)), c, 'UniformOutput', false));
verifyEqual(testCase, got, {'direction', 'temporal frequency'});
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'a stated value beside a best value', {});
end

function testATuningStatedValueAtTwoNumbersIsCarried(testCase)
% one property stated at two numbers: the writer keeps no stimulus; carried
[tc, resp, pres] = statedCurveBatch();
sel = asCell(tc.tuningcurve_calc.input_parameters.selection);
sel{end+1} = struct('property', 'tFrequency', 'operation', 'exact_number', 'value', 8);
tc.tuningcurve_calc.input_parameters.selection = sel;
tc = jsondecode(jsonencode(tc));
[carried, notes] = did2.unittest.helpers.carryNote({tc, resp, pres});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[tuning stated value is a condition]'), notes);
end

function testTuningStatedValuesFunction(testCase)
sel = struct('property', {'angle', 'tFrequency', 'angle', 'contrast', 'tFrequency'}, ...
    'operation', {'hasfield', 'exact_number', 'exact_number', 'exact_number', 'exact_number'}, ...
    'value', {'varies', 4, 'best', 1, 4});
[p, v, why] = did2.convert.tuningStatedValues(struct('selection', sel));
verifyEmpty(testCase, why);
verifyEqual(testCase, p, {'tFrequency', 'contrast'}, 'best and varies are not stated numbers');
verifyEqual(testCase, v, [4 1]);
% as jsondecode reads a mixed selection (a cell of structs)
ip = jsondecode(['{"selection":[{"property":"tFrequency","operation":"exact_number",' ...
    '"value":4},{"property":"angle","operation":"hasfield","value":"varies"}]}']);
[p, v] = did2.convert.tuningStatedValues(ip);
verifyEqual(testCase, p, {'tFrequency'});
verifyEqual(testCase, v, 4);
[p, ~, why] = did2.convert.tuningStatedValues(struct('selection', struct( ...
    'property', {'tFrequency', 'tFrequency'}, 'operation', 'exact_number', 'value', {4, 8})));
verifyNotEmpty(testCase, why, 'one property at two numbers');
verifyEqual(testCase, p, {'tFrequency'});
[p, v, why] = did2.convert.tuningStatedValues(struct('selection', struct( ...
    'property', 'angle', 'operation', 'hasfield', 'value', 'varies')));
verifyEmpty(testCase, p);
verifyEmpty(testCase, v);
verifyEmpty(testCase, why);
end

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

function testTermPicksBatch3NodesAreWritten(testCase)
% Decided by Jess Haley, 2026-11-09 [term picks batch 3] (did-schema
% did_v2_go_forward_class_audit.md): independent_parameter -> NCIT:C191277
% Independent Variable, best_algorithm -> NCIT:C16275 Algorithm, selection ->
% OBI:0001755 selection criterion; the round trip gives each back its v1 name
[tc, resp, pres] = bestCurveBatch();
tc.tuningcurve_calc.input_parameters.independent_parameter = 'contrast';
tc.tuningcurve_calc.input_parameters.best_algorithm = 'empirical_maximum';
tc = jsondecode(jsonencode(tc));
out = runRaw({tc, resp, pres});
mine = outputsOf(out, tc.base.id);
assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2');
want = {'Independent Variable', 'NCIT:C191277'; 'Algorithm', 'NCIT:C16275'; ...
    'selection criterion', 'OBI:0001755'};
p = asCell(mine{1}.interaction.method.parameters);
for k = 1:size(want, 1)
    hit = p(cellfun(@(e) strcmp(char(e.variable.name), want{k, 1}), p));
    assertNotEmpty(testCase, hit, want{k, 1});
    verifyEqual(testCase, upper(char(hit{1}.variable.node)), upper(want{k, 2}), want{k, 1});
end
verifyEqual(testCase, parameterText(mine{1}, 'Algorithm'), 'empirical_maximum');
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'batch 3 settings', {});
for f = {'independent_parameter', 'best_algorithm', 'selection'}
    verifyTrue(testCase, any(startsWith(r.matched, ['tuningcurve_calc.input_parameters.' f{1}])), f{1});
end
end

function testTheDisplayLabelIsRebuiltAndComparedLoosely(testCase)
% Decided by Jess Haley, 2026-11-10 [display label compared loosely] (did-schema
% did_v2_go_forward_class_audit.md; the question [term picks batch 3] left):
% v1 input_parameters.independent_label is not written by the tuningcurve
% migration; the round trip rebuilds it from the curve's registered variable
% name, and a rebuilt label that differs from v1's only in letter case or in
% '_' versus space is the same. Any other difference is reported lost.
for c = {{'contrast', 'contrast'}, {'Contrast', 'Contrast'}, {'CONTRAST', 'contrast'}}
    [tc, resp, pres] = tuningCurveBatch();
    tc.tuningcurve_calc.input_parameters.independent_label = c{1}{1};
    tc.stimulus_tuningcurve.independent_variable_label = {c{1}{2}};
    tc = jsondecode(jsonencode(tc));
    label = sprintf('label "%s", curve label "%s"', c{1}{:});
    out = runRaw({tc, resp, pres});
    mine = outputsOf(out, tc.base.id);
    assertEqual(testCase, mine{1}.document_class.schema_version, 'did_v2', label);
    names = parameterNames(mine{1});
    verifyFalse(testCase, any(strcmpi(names, 'independent label')), ...
        [label ': independent_label is not written']);
    r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
    p = 'tuningcurve_calc.input_parameters.independent_label';
    verifyTrue(testCase, any(strcmp(p, [r.matched, r.equivalent])), [label ': ' p]);
end
% a label that is not the variable's name, beyond case and '_': lost
[tc, resp, pres] = tuningCurveBatch();
tc.tuningcurve_calc.input_parameters.independent_label = 'stimulus contrast';
tc = jsondecode(jsonencode(tc));
out = runRaw({tc, resp, pres});
r = did2.convert.roundtrip.check(tc, outputsExcept(out, {resp.base.id, pres.base.id}));
verifyTrue(testCase, any(strcmp({r.lost.path}, ...
    'tuningcurve_calc.input_parameters.independent_label')), ...
    'a label that names something else is reported lost');
% a configuration migrated before still holds it as a parameter: read back exactly
[tc, resp, pres] = tuningCurveBatch();
tc.tuningcurve_calc.input_parameters.independent_label = 'Stimulus Contrast';
tc = jsondecode(jsonencode(tc));
out = runRaw({tc, resp, pres});
docs = outputsExcept(out, {resp.base.id, pres.base.id});
mine = outputsOf(out, tc.base.id);
ix = find(cellfun(@(d) strcmp(char(d.base.id), char(mine{1}.base.id)), docs), 1);
assertNotEmpty(testCase, ix);
docs{ix} = withParameter(docs{ix}, 'Algorithm', 'independent label', 'Stimulus Contrast');
r = did2.convert.roundtrip.check(tc, docs);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'a label migrated before', {});
verifyTrue(testCase, any(strcmp(r.matched, 'tuningcurve_calc.input_parameters.independent_label')));
end

% ===================== [tuning axes named from the varied property] =====

function testTuningAxesAreNamedFromTheVariedProperty(testCase)
% Decided by Jess Haley, 2026-11-12 [tuning axes named from the varied
% property] (did-schema did_v2_go_forward_class_audit.md): the axis
% (dimension term and covariate variable) is named from v1
% `independent_parameter` through the registered terms, not from
% `independent_variable_label`; an `angle` whose values span less than 180
% degrees is an orientation (NCIT:C165680). The label text is kept in notes
% (the last line, did2.convert.tuningLabelNote) when the axis terms do not
% restate it, and the round trip gives it back exactly.
cases = { ...
    % parameter, values, v1 label, axis node, axis name, label in notes
    'angle', [0 60 120 180 240 300], 'Directio (4 Hz)', 'NCIT:C42677', 'Direction', true; ...
    'angle', [0 30 60 90 120 150], 'Orientation', 'NCIT:C165680', 'Orientation', false; ...
    'angle', [0 30 60 90 120 150], 'Direction', 'NCIT:C165680', 'Orientation', true; ...
    'sFrequency', [0.05 0.1 0.2 0.4 0.8 1.6], 'Spatial Frequency (loops)', 'NCIT:C75389', 'Spatial Frequency', true; ...
    'tFrequency', [0.5 1 2 4 8 16], 'Temporal Frequency (loops)', 'NCIT:C25515', 'Temporal Frequency', true; ...
    'sFrequency', [0.05 0.1 0.2 0.4 0.8 1.6], 'spatial_frequency', 'NCIT:C75389', 'Spatial Frequency', false};
for k = 1:size(cases, 1)
    [param, vals, label, node, name, noted] = cases{k, :};
    for withLog = [false true]
        v1 = convertedTuningCurve();
        v1.tuningcurve_calc.input_parameters.independent_parameter = param;
        v1.tuningcurve_calc.input_parameters.independent_label = label;
        v1.tuningcurve_calc.input_parameters.selection.property = param;
        v1.stimulus_tuningcurve.independent_variable_label = {label};
        v1.stimulus_tuningcurve.independent_variable_value = vals(:);
        if withLog
            v1.tuningcurve_calc.log = 'a line of the log';
        end
        v1 = jsondecode(jsonencode(v1));
        what = sprintf('%s over %g..%g labelled "%s" (log %d)', param, min(vals), ...
            max(vals), label, withLog);
        out = runRaw({v1});
        leaf = firstOfClass(out, 'tuning_curve_calculation');
        assertNotEmpty(testCase, leaf, [what ': converted']);
        ax = did2.unittest.helpers.axesOf(leaf);
        assertEqual(testCase, numel(ax), 1, what);
        verifyEqual(testCase, upper(char(ax(1).term.node)), node, [what ': dimension term']);
        verifyEqual(testCase, char(ax(1).term.name), name, [what ': dimension term']);
        verifyEqual(testCase, upper(char(ax(1).cov.variable.node)), node, [what ': covariate']);
        notes = '';
        if isfield(leaf.statement, 'notes'); notes = char(leaf.statement.notes); end
        [logBack, labelBack, has] = did2.convert.tuningLabelNote('read', notes);
        verifyEqual(testCase, has, noted, [what ': the label is in the notes when not restated']);
        if noted
            verifyEqual(testCase, labelBack, {label}, what);
        end
        if withLog
            verifyEqual(testCase, logBack, 'a line of the log', [what ': the log stays first']);
        end
        r = did2.convert.roundtrip.check(v1, out.migrated);
        did2.unittest.helpers.verifyRoundTrip(testCase, r, what, {});
        for f = {'stimulus_tuningcurve.independent_variable_label', ...
                'tuningcurve_calc.input_parameters.independent_label'}
            verifyTrue(testCase, any(strcmp(f{1}, [r.matched, r.equivalent])), [what ': ' f{1}]);
        end
    end
end
end

function testATuningCurveWithNoVariedParameterIsNamedFromItsLabel(testCase)
% a parameter the name table does not hold (or none, the bare curve): the
% axis is named from the label, as before, and nothing is noted
v1 = convertedTuningCurve();
v1.tuningcurve_calc.input_parameters.independent_parameter = 'notAStimulusParameter';
v1.tuningcurve_calc.input_parameters.selection.property = 'notAStimulusParameter';
v1 = jsondecode(jsonencode(v1));
out = runRaw({v1});
leaf = firstOfClass(out, 'tuning_curve_calculation');
assertNotEmpty(testCase, leaf);
ax = did2.unittest.helpers.axesOf(leaf);
verifyEqual(testCase, lower(char(ax(1).term.name)), 'contrast');
notes = '';
if isfield(leaf.statement, 'notes'); notes = char(leaf.statement.notes); end
[~, ~, has] = did2.convert.tuningLabelNote('read', notes);
verifyFalse(testCase, has);
end

function testTuningLabelNoteFunction(testCase)
verifyEqual(testCase, did2.convert.tuningLabelNote('write', 'log', []), 'log');
n = did2.convert.tuningLabelNote('write', 'line 1', {'Directio (4 Hz)'});
[lg, lbl, has] = did2.convert.tuningLabelNote('read', n);
verifyEqual(testCase, lg, 'line 1');
verifyEqual(testCase, lbl, {'Directio (4 Hz)'});
verifyTrue(testCase, has);
n = did2.convert.tuningLabelNote('write', '', 'say "x", y');
[lg, lbl, has] = did2.convert.tuningLabelNote('read', n);
verifyEqual(testCase, lg, '');
verifyEqual(testCase, lbl, 'say "x", y');
verifyTrue(testCase, has);
[lg, lbl, has] = did2.convert.tuningLabelNote('read', sprintf('a log\nof two lines'));
verifyEqual(testCase, lg, sprintf('a log\nof two lines'));
verifyEmpty(testCase, lbl);
verifyFalse(testCase, has);
end

% ===================== [depends on name not written when it equals the edge]

function testDependsOnNameIsNotWrittenWhenItEqualsTheEdge(testCase)
% Decided by Jess Haley, 2026-11-12 [depends on name not written when it
% equals the edge] (did-schema did_v2_go_forward_class_audit.md): a tuning
% curve's `depends on.name` method parameter is not written when it names the
% curve's own stimulus_response_scalar_id edge; the round trip rebuilds it
% from the edge; a curve whose value names anything else is carried as v1.
% The corpora's copies state the name and an empty value (Soph shard run
% 43465005782: 5,976 of 5,976 curves wrote 'depends on.name', none 'depends
% on.value'); both shapes are checked.
v1 = convertedTuningCurve();
edge = v1.depends_on(strcmp({v1.depends_on.name}, 'stimulus_response_scalar_id')).value;
for value = {edge, ''}
    v1 = convertedTuningCurve();
    v1.tuningcurve_calc.input_parameters.depends_on = struct( ...
        'name', 'stimulus_response_scalar_id', 'value', value{1});
    v1 = jsondecode(jsonencode(v1));
    what = sprintf('depends_on value "%s"', value{1});
    out = runRaw({v1});
    leaf = firstOfClass(out, 'tuning_curve_calculation');
    assertNotEmpty(testCase, leaf, [what ': converted']);
    names = parameterNames(leaf);
    verifyFalse(testCase, any(strcmp(names, 'depends on.name')), [what ': the name is not written']);
    verifyEqual(testCase, any(strcmp(names, 'depends on.value')), ~isempty(value{1}), ...
        [what ': the value is written when stated']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, what, {});
    hit = [r.matched, r.equivalent, r.restated];   % restated by the edge
    verifyTrue(testCase, any(~cellfun(@isempty, regexp(hit, ...
        '^tuningcurve_calc\.input_parameters\.depends_on(\(1\))?\.name$', 'once'))), ...
        [what ': ' strjoin(hit(contains(hit, 'depends_on')), ', ')]);
end
% a name other than the curve's edge: carried
for other = {'element_id', 'stimulus_tuningcurve_id'}
    v1 = convertedTuningCurve();
    v1.tuningcurve_calc.input_parameters.depends_on = struct('name', other{1}, 'value', edge);
    v1 = jsondecode(jsonencode(v1));
    [carried, notes] = did2.unittest.helpers.carryNote({v1});
    verifyTrue(testCase, carried, other{1});
    verifyTrue(testCase, contains(notes, ...
        '[carry-016] tuningcurve_calc.input_parameters.depends_on.name'), notes);
end
end

% ===================== [response type harmonics are integers] =============

function testResponseTypeMeanAndPeakAreTerms(testCase)
% Decided by Jess Haley, 2026-11-12 [response type harmonics are integers]
% (did-schema did_v2_go_forward_class_audit.md): a tuning or
% contrast-sensitivity `response_type` of `mean` is NCIT:C53319 Arithmetic
% Mean and `peak` STATO:0000151 maximum observed value; the round trip gives
% the v1 text back. F1 / F2 are not built here (where the integer harmonic
% is written on these values is not decided): they stay labels.
want = {'mean', 'NCIT:C53319'; 'peak', 'STATO:0000151'; 'F1', ''};
for k = 1:size(want, 1)
    v1 = convertedContrast();
    v1.contrast_tuning.properties.response_type = want{k, 1};
    out = runRaw({v1});
    leaf = firstOfClass(out, 'contrast_tuning_calculation');
    assertNotEmpty(testCase, leaf, want{k, 1});
    verifyEqual(testCase, termNode(leaf.tuning_curve.value.response_type), ...
        want{k, 2}, ['contrast tuning ' want{k, 1}]);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, ['contrast tuning ' want{k, 1}], {});

    v1 = writerOutput('contrastsensitivity_calc');
    v1.contrastsensitivity_calc.response_type = want{k, 1};
    out = runRaw({v1});
    leaf = firstOfClass(out, 'contrast_sensitivity_calculation');
    assertNotEmpty(testCase, leaf, want{k, 1});
    verifyEqual(testCase, termNode(leaf.contrast_sensitivity.value.response_type), ...
        want{k, 2}, ['contrast sensitivity ' want{k, 1}]);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, ['contrast sensitivity ' want{k, 1}], {});
end
end

function n = termNode(t)
% a term's node, upper case ('' when it has none: a label)
n = '';
if isstruct(t) && isfield(t, 'node') && ~isempty(t.node); n = upper(char(t.node)); end
end

function testParameterNamesMapByTable(testCase)
for name = {'independent_label', 'min_xi', 'prestimulus_time', 'selection.property', ...
        'depends_on.name'}   % (every corpus tuningcurve_calc states input_parameters.depends_on)
    [v2, found] = did2.convert.tuningNames('v2', name{1});
    verifyTrue(testCase, found, name{1});
    [back, found] = did2.convert.tuningNames('v1', v2);
    verifyTrue(testCase, found, v2);
    verifyEqual(testCase, back, name{1});
end
verifyEqual(testCase, did2.convert.tuningNames('v2', 'sFrequency'), 'spatial frequency');
[~, found] = did2.convert.tuningNames('v2', 'sPhaseShift');
verifyFalse(testCase, found, 'sPhaseShift changes unit in the v2 method: not in the table');
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
out = did2.convert.resolveResponseParameters(out, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, out.response_parameters_fold.refused_unknown_setting, 1);
verifyEqual(testCase, out.response_parameters_fold.methods_minted, 0);
end

% ===================== [absolute-value fits are fit entries] ==============
% Decided by Jess Haley, 2026-10-28 [absolute-value fits are fit entries]
% (did-schema V_eta_go_forward_class_audit.md), superseding [absolute-value
% fits are a second calculation] (2026-10-27), which conflicted with T10: an
% SF / TF output's `abs` fits are model_fit entries of the ONE calculation,
% each with response_transform 'absolute value'. Its condition (bring back
% anything else the `abs` block holds) was answered by [interpolated values
% are a list] (2026-10-30): `abs.fitless` is the 'absolute value'
% interpolated_values entry.

function testAbsoluteValueFitsAreFitEntries(testCase)
% With the list declared, each writer output is ONE calculation holding the
% five fits as stated and then the five abs fits, of the same models, marked
% 'absolute value'; no method parameter 'response transform' is written; the
% round trip rebuilds the v1 `abs` block; the validator takes the entries.
assertTrue(testCase, did2.unittest.helpers.schemaDeclares('tuning_curve', ...
    {'value', 'model_fit', 'response_transform'}), ...
    'the schema in use declares no model_fit response_transform (did-schema f02a251)');
did2.unittest.helpers.interpolatedListSchema(testCase, true);
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, cls{1});
    verifyEmpty(testCase, out.passthrough, [cls{1} ': converts']);
    leafClass = strrep(cls{1}, '_calc', '_calculation');
    calcs = allOfClass(out, leafClass);
    assertEqual(testCase, numel(calcs), 1, [cls{1} ': one calculation (T10)']);
    verifyEqual(testCase, char(calcs{1}.base.id), char(v1.base.id), cls{1});
    verifyEqual(testCase, parameterText(calcs{1}, 'response transform'), '', ...
        [cls{1} ': the transform is on the fit entries, not the method']);
    mf = asCell(calcs{1}.tuning_curve.value.model_fit);
    transforms = cellfun(@fitTransform, mf, 'UniformOutput', false);
    verifyEqual(testCase, transforms, [repmat({''}, 1, 5), repmat({'absolute value'}, 1, 5)], ...
        [cls{1} ': the fits as stated, then the abs fits']);
    models = cellfun(@(e) char(e.model.name), mf, 'UniformOutput', false);
    verifyEqual(testCase, sort(models(6:10)), sort(models(1:5)), ...
        [cls{1} ': the abs block fits the same five models']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, cls{1}, {});
    checked = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'did_v2');
    verifyFalse(testCase, any(contains(quarantineReasons(checked), ...
        {'model_fit', 'response_transform'})), ...
        [cls{1} ': the validator refuses the absolute-value fit entries']);
end
end

function testAbsoluteValueFitsWithAnUnknownTransformAreUnplaced(testCase)
% The round trip has a v1 place only for fits to the responses as stated and
% to |response| (SF / TF `abs`): a model_fit entry with any other transform
% is reported.
did2.unittest.helpers.interpolatedListSchema(testCase, true);
v1 = writerOutput('spatial_frequency_tuning_calc');
out = runRaw({v1});
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
k = find(cellfun(@(d) strcmp(char(d.document_class.class_name), ...
    'spatial_frequency_tuning_calculation'), docs), 1);
assertNotEmpty(testCase, k);
mf = docs{k}.tuning_curve.value.model_fit;
if iscell(mf); mf = [mf{:}]; end
mf(end).response_transform = 'logarithm';
docs{k}.tuning_curve.value.model_fit = mf;
r = did2.convert.roundtrip.check(v1, docs);
verifyNotEmpty(testCase, r.unplaced, 'an unknown transform is unplaced');
end

function testTheAbsBlockHoldsMoreThanFits(testCase)
% Why [absolute-value fits are fit entries] (2026-10-28) was held until
% [interpolated values are a list] (2026-10-30) answered it: the SF / TF
% writers' `abs` block (NDIcalc-vis-matlab 00e3e0f spatial_frequency_tuning.m,
% temporal_frequency_tuning.m: abs.fitless = abs_sf_props.fitless, then the
% five fits) holds the interpolated values of |response| as well as the fits.
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    blk = v1.(strrep(cls{1}, '_calc', ''));
    fns = fieldnames(blk.abs);
    verifyTrue(testCase, any(strcmp(fns, 'fitless')), cls{1});
    notFit = fns(~(strcmp(fns, 'fit') | startsWith(fns, 'fit_')));
    verifyEqual(testCase, notFit, {'fitless'}, [cls{1} ': the one non-fit field']);
end
end

% ===================== [interpolated values are a list] ==================
% Decided by Jess Haley, 2026-10-30 [interpolated values are a list] (did-schema
% V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G5): a tuning calculation's
% `interpolated_values` is a list of entries, each with the optional
% `response_transform`; v1 `abs.fitless` is the 'absolute value' entry on the
% MAIN calculation. The fold writes the list only once the loaded schema
% declares it (siblings first). Each test below runs on a copy of the loaded
% schema that declares the list, or does not
% (did2.unittest.helpers.interpolatedListSchema), so both shapes are
% exercised in every run, whatever did-schema `main` declares.

function testInterpolatedValuesAreOneStructureWithoutTheList(testCase)
% Without the declaration the fold would write the one structure, and since
% [absolute-value fits are fit entries] (2026-10-28) there is no second
% calculation to hold v1 `abs.fitless`: it has no home, and the writer
% outputs (which all state it) carry whole as v1 (carry-056).
did2.unittest.helpers.interpolatedListSchema(testCase, false);
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    [carried, notes] = did2.unittest.helpers.carryNote({v1});
    verifyTrue(testCase, carried, [cls{1} ': abs.fitless has no home without the list']);
    verifyTrue(testCase, contains(notes, '[carry-056]') && contains(notes, '.abs.fitless'), notes);
end
end

function testInterpolatedValuesAreReadBackAsAList(testCase)
% The round trip reads the list: the output written with the list declared
% rebuilds the same v1 document (abs.fitless from the 'absolute value'
% entry), and an entry with a transform v1 has no place for is reported.
did2.unittest.helpers.interpolatedListSchema(testCase, true);
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    leafClass = strrep(cls{1}, '_calc', '_calculation');
    out = runRaw({v1});
    docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
    mainK = find(cellfun(@(d) strcmp(char(d.document_class.class_name), leafClass), docs));
    assertNumElements(testCase, mainK, 1, cls{1});
    r = did2.convert.roundtrip.check(v1, docs);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, [cls{1} ', list shape'], {});
    iv = did2.unittest.helpers.tuningSummary(docs{mainK}, 'interpolated_values');
    if iscell(iv); iv = [iv{:}]; end
    odd = iv(1);
    odd.response_transform = 'logarithm';
    % where the document holds it ([tuning summaries in the value])
    if isfield(docs{mainK}.tuning_curve.value, 'interpolated_values')
        docs{mainK}.tuning_curve.value.interpolated_values = [num2cell(iv), {odd}];
    else
        docs{mainK}.(leafClass).interpolated_values = [num2cell(iv), {odd}];
    end
    r = did2.convert.roundtrip.check(v1, docs);
    verifyNotEmpty(testCase, r.unplaced, [cls{1} ': an unknown transform is unplaced']);
end
end

function testInterpolatedValuesAreAListOnceTheSchemaDeclaresIt(testCase)
% With the declaration the fold writes the list: the values as stated first,
% v1 `abs.fitless` second with response_transform 'absolute value', on the
% ONE calculation (its abs fits are model_fit entries there too, [absolute-
% value fits are fit entries]); the round trip is unchanged; and the
% validator takes the list.
did2.unittest.helpers.interpolatedListSchema(testCase, true);
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    leafClass = strrep(cls{1}, '_calc', '_calculation');
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, cls{1});
    verifyEmpty(testCase, out.passthrough, [cls{1} ': converts']);
    calcs = allOfClass(out, leafClass);
    assertEqual(testCase, numel(calcs), 1, [cls{1} ': one calculation']);
    mainIv = did2.unittest.helpers.tuningSummary(calcs{1}, 'interpolated_values');   % [tuning summaries in the value]
    if iscell(mainIv); mainIv = [mainIv{:}]; end
    assertEqual(testCase, numel(mainIv), 2, [cls{1} ': as stated, then |response|']);
    verifyTrue(testCase, ~isfield(mainIv, 'response_transform') ...
        || isempty(mainIv(1).response_transform), cls{1});
    verifyEqual(testCase, char(mainIv(2).response_transform), 'absolute value', cls{1});
    [asStated, absEntry, n] = did2.unittest.helpers.interpolatedEntries(mainIv);
    verifyEqual(testCase, n, 2, cls{1});
    verifyNotEmpty(testCase, fieldnames(asStated), cls{1});
    verifyNotEmpty(testCase, fieldnames(absEntry), cls{1});
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, [cls{1} ', list written'], {});
    % (the cache validator, fillField and validateField, takes a struct array
    % for a mustBeScalar-false structure; nothing it reports is about the list)
    checked = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'did_v2');
    verifyFalse(testCase, any(contains(quarantineReasons(checked), ...
        {'interpolated_values', 'response_transform'})), ...
        [cls{1} ': the validator refuses the list']);
end
end

function testAnAbsBlockOfOnlyInterpolatedValuesIsNoSecondCalculation(testCase)
% An `abs` block holding `fitless` and no fit: with the list declared it is
% the main calculation's 'absolute value' entry and there is no second
% calculation holding only it; without the list it has no place, and the
% document carries (carry-056), as before.
for cls = {'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc'}
    v1 = writerOutput(cls{1});
    blockName = strrep(cls{1}, '_calc', '');
    v1.(blockName).abs = struct('fitless', v1.(blockName).abs.fitless);
    leafClass = strrep(cls{1}, '_calc', '_calculation');

    did2.unittest.helpers.interpolatedListSchema(testCase, false);
    [carried, notes] = did2.unittest.helpers.carryNote({v1});
    verifyTrue(testCase, carried, [cls{1} ': no list, no place']);
    verifyTrue(testCase, contains(notes, '[carry-056]') && contains(notes, '.abs'), notes);

    did2.unittest.helpers.interpolatedListSchema(testCase, true);
    out = runRaw({v1});
    verifyEmpty(testCase, out.quarantine, cls{1});
    verifyEmpty(testCase, out.passthrough, [cls{1} ': converts with the list']);
    calcs = allOfClass(out, leafClass);
    assertEqual(testCase, numel(calcs), 1, [cls{1} ': no second calculation']);
    verifyEqual(testCase, parameterText(calcs{1}, 'response transform'), '', cls{1});
    [asStated, absEntry, n] = did2.unittest.helpers.interpolatedEntries( ...
        did2.unittest.helpers.tuningSummary(calcs{1}, 'interpolated_values'));
    verifyEqual(testCase, n, 2, cls{1});
    verifyNotEmpty(testCase, fieldnames(asStated), cls{1});
    verifyNotEmpty(testCase, fieldnames(absEntry), cls{1});
    r = did2.convert.roundtrip.check(v1, out.migrated);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, [cls{1} ', abs fitless only'], {});
end
end

function testInterpolatedValuesWithNoAbsoluteValueEntry(testCase)
% contrast_tuning_calculation and contrast_sensitivity's value: their writers
% state no |response| values, so in both shapes the field holds the one entry
% as stated (a scalar structure is a one-entry list), and the round trip is
% unchanged.
cases = { ...
    'contrasttuning_calc', convertedContrast(), 'contrast_tuning_calculation'; ...
    'contrastsensitivity_calc', writerOutput('contrastsensitivity_calc'), ...
        'contrast_sensitivity_calculation'};
for declared = [false true]
    did2.unittest.helpers.interpolatedListSchema(testCase, declared);
    for k = 1:size(cases, 1)
        [label, v1, leafClass] = cases{k, :};
        label = sprintf('%s, list declared = %d', label, declared);
        out = runRaw({v1});
        verifyEmpty(testCase, out.quarantine, label);
        verifyEmpty(testCase, out.passthrough, [label ': converts']);
        leaf = firstOfClass(out, leafClass);
        assertNotEmpty(testCase, leaf, label);
        if strcmp(leafClass, 'contrast_sensitivity_calculation')
            iv = leaf.contrast_sensitivity.value.interpolated_values;
        else
            iv = did2.unittest.helpers.tuningSummary(leaf, 'interpolated_values');   % [tuning summaries in the value]
        end
        [asStated, absEntry, n] = did2.unittest.helpers.interpolatedEntries(iv);
        verifyEqual(testCase, n, 1, label);
        verifyNotEmpty(testCase, fieldnames(asStated), label);
        verifyEmpty(testCase, fieldnames(absEntry), label);
        r = did2.convert.roundtrip.check(v1, out.migrated);
        did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
    end
end
end

function t = fitTransform(e)
% a model_fit entry's response_transform ('' when absent or empty)
t = '';
if isstruct(e) && isfield(e, 'response_transform') && ~isempty(e.response_transform)
    t = strtrim(char(e.response_transform));
end
end

function c = quarantineReasons(out)
c = {};
q = out.quarantine;
if isempty(q); return; end
if isstruct(q); q = num2cell(reshape(q, 1, [])); end
for k = 1:numel(q)
    if isstruct(q{k}) && isfield(q{k}, 'reason')
        c{end+1} = char(q{k}.reason); %#ok<AGROW>
    end
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
% UPDATED 2026-11-03 ([fixed writer values not written], Decided by Jess
% Haley): the writer's empty prestimulus_normalization is no longer written as
% 0; the round trip writes the empty default back, so it compares equal
% (matched or not set) rather than through the [] = 0 equivalence.
p = parameters('par_e1');   % the writer's prestimulus_normalization []
out = runRaw({p});
out = did2.convert.resolveResponseParameters(out, 'Validate', false, 'TargetVersion', 'did_v2');
m = outputsOf(out, 'par_e1');
r = did2.convert.roundtrip.check(p, m);
P = 'stimulus_response_scalar_parameters_basic.';
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'parameters as a method', {[P 'freq_response']});
verifyTrue(testCase, any(strcmp([P 'prestimulus_normalization'], ...
    [r.matched, r.not_set, r.equivalent])));
verifyTrue(testCase, any(strcmp([P 'temporalfreqfunc'], r.matched)), ...
    'the default temporalfreqfunc is written back');
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
    'speedtuning_calc', 'speedtuning_calc.mock.1.json', ...
    'contrastsensitivity_calc', 'contrastsensitivity_calc.mock.1.json');
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

function [tc, resp, pres] = bestCurveBatch()
% tuningCurveBatch with an `angle ... best` selection: the presentation shows
% each contrast at angle 90 (stimuli 1-6) and again at angle 0 (7-12); the
% writer kept angle 90 (its log: "angle best value is 90."), so the curve's
% stimids stay 1-6
[tc, resp, pres] = tuningCurveBatch();
tc.tuningcurve_calc.input_parameters.selection = struct( ...
    'property', {'contrast', 'angle'}, 'operation', {'hasfield', 'exact_number'}, ...
    'value', {'varies', 'best'});
tc.tuningcurve_calc.log = 'angle best value is 90.';
st = pres.stimulus_presentation.stimuli;
if iscell(st); st = [st{:}]; end
st = reshape(st, 1, []);
at90 = st;
at0 = st;
for k = 1:numel(st)
    at90(k).parameters.angle = 90;
    at0(k).parameters.angle = 0;
end
pres.stimulus_presentation.stimuli = [at90, at0];
tc = jsondecode(jsonencode(tc));
pres = jsondecode(jsonencode(pres));
end

function [tc, resp, pres] = statedCurveBatch()
% tuningCurveBatch with a selection fixing tFrequency at 4 (as Soph's angle
% curves: {"property":"tFrequency","operation":"exact_number","value":4},
% an empty log and stim_property_list): the presentation shows each contrast
% at tFrequency 4 (stimuli 1-6) and again at tFrequency 8 (7-12); the writer
% kept 4, so the curve's stimids stay 1-6
[tc, resp, pres] = tuningCurveBatch();
tc.tuningcurve_calc.input_parameters.selection = struct( ...
    'property', {'contrast', 'tFrequency'}, 'operation', {'hasfield', 'exact_number'}, ...
    'value', {'varies', 4});
tc.tuningcurve_calc.log = '';
st = pres.stimulus_presentation.stimuli;
if iscell(st); st = [st{:}]; end
st = reshape(st, 1, []);
at4 = st;
at8 = st;
for k = 1:numel(st)
    at4(k).parameters.tFrequency = 4;
    at8(k).parameters.tFrequency = 8;
end
pres.stimulus_presentation.stimuli = [at4, at8];
tc = jsondecode(jsonencode(tc));
pres = jsondecode(jsonencode(pres));
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
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'did_v2');
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

function n = parameterCount(leaf, name)
n = 0;
if ~isfield(leaf, 'interaction') || ~isfield(leaf.interaction, 'method') ...
        || ~isfield(leaf.interaction.method, 'parameters')
    return;
end
p = asCell(leaf.interaction.method.parameters);
for k = 1:numel(p)
    n = n + strcmp(char(p{k}.variable.name), name);
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
