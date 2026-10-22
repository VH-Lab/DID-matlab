function tests = testBuildAuditRules
%TESTBUILDAUDITRULES did2.build checks the four rules did-schema #88 named in
%   the 2026-10-22 tenet audit (Jess Haley):
%     method_shared_and_own        interaction.json  [method shared plus own]
%     assertion_no_time_dimension  assertion.json    [rules and clock_alignment tenet]
%     datum_order_multidimensional sampled_body.json [covariate rules named] 6.3a
%     fit_metric_unit              tuning_curve.json [calculator units]
%   Each has a document that builds (positive) and one refused with
%   did2:build:ruleViolated naming the rule (negative). A schema that does not
%   declare a rule FILTERS its test (assumeFail) with a message saying so; it
%   is never silently passed.
%
%   Run with:  results = runtests('did2.unittest.testBuildAuditRules');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build audit-rule tests');
% made-up terms ('voltage', 'direction', 'gain'): the registry check is tested
% elsewhere (testBuildTermRegistry), as in testBuild
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function id = newId()
id = did.ido.unique_id();
end

function requireRule(testCase, className, ruleName)
c = did2.schema.cache.shared();
tf = false;
if c.hasClass(className)
    s = c.getClass(className);
    if isfield(s, 'rules') && ~isempty(s.rules)
        r = s.rules;
        if isstruct(r); r = num2cell(r); end
        tf = any(cellfun(@(x) strcmp(char(x.name), ruleName), r));
    end
end
if ~tf
    assumeFail(testCase, sprintf(['the loaded schema (%s) does not declare rule "%s" ' ...
        'on "%s" (did-schema #88 at 34a15e2 and later does)'], c.schemaPath, ruleName, className));
end
end

function verifyRule(testCase, fn, ruleName)
try
    fn();
    verifyFail(testCase, sprintf('no error; wanted did2:build:ruleViolated for %s', ruleName));
catch err
    verifyEqual(testCase, err.identifier, 'did2:build:ruleViolated');
    verifySubstring(testCase, err.message, ruleName);
end
end

% ===================== method_shared_and_own ================================

function testInlineSettingsBesideASharedMethodBuild(testCase)
requireRule(testCase, 'interaction', 'method_shared_and_own');
sid = testCase.TestData.sid;
m = did2.build.method('whole-cell patch clamp', did2.build.parameter('gain', 'Value', 100), ...
    'SessionId', sid);
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'MethodId', m.base.id, ...
    'MethodParameters', did2.build.parameter('holding potential', 'Value', -70, 'Unit', 'millivolt'), ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid, 'ValueKind', 'voltage');
verifyEqual(testCase, doc.interaction.method.parameters.variable.name, 'holding potential');
verifyFalse(testCase, isfield(doc.interaction.method, 'term'));
% the across-document half: the shared method's variables are not repeated
did2.build.checkMethodSharedAndOwn(doc, m);
end

function testAnInlineTermBesideASharedMethodIsRefused(testCase)
requireRule(testCase, 'interaction', 'method_shared_and_own');
verifyRule(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'MethodId', newId(), ...
    'Method', 'refrigeration', 'TimeReferenceIds', {newId()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage'), 'method_shared_and_own');
end

function testASharedVariableRepeatedInlineIsRefused(testCase)
requireRule(testCase, 'interaction', 'method_shared_and_own');
sid = testCase.TestData.sid;
m = did2.build.method('whole-cell patch clamp', did2.build.parameter('gain', 'Value', 100), ...
    'SessionId', sid);
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'MethodId', m.base.id, ...
    'MethodParameters', did2.build.parameter('gain', 'Value', 200), ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid, 'ValueKind', 'voltage');
% a changed shared setting is a variant method document with parent_id
verifyRule(testCase, @() did2.build.checkMethodSharedAndOwn(doc, m), 'method_shared_and_own');
% and the statement must name that method
other = did2.build.method('blank screen', [], 'SessionId', sid);
verifyRule(testCase, @() did2.build.checkMethodSharedAndOwn(doc, other), 'method_shared_and_own');
end

% ===================== assertion_no_time_dimension ==========================

function testAnAssertionWithoutTimeBuilds(testCase)
requireRule(testCase, 'assertion', 'assertion_no_time_dimension');
doc = did2.build.statement('assertion', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 3)), ...
    'Dimensions', did2.build.dimension('channel', 3), ...
    'Covariates', did2.build.covariate('electrode depth', 0, 'Unit', 'micrometer', 'Value', [10 20 30]), ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage');
verifyEqual(testCase, doc.data.dimensions.term.name, 'channel');
end

function testAnAssertionWithATimeDimensionIsRefused(testCase)
requireRule(testCase, 'assertion', 'assertion_no_time_dimension');
sid = testCase.TestData.sid;
% by label (writers name the time axis {name: 'time'}) ...
verifyRule(testCase, @() did2.build.statement('assertion', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 3)), ...
    'Dimensions', did2.build.dimension('time', 3), ...
    'SessionId', sid, 'ValueKind', 'voltage'), 'assertion_no_time_dimension');
% ... and by node
verifyRule(testCase, @() did2.build.statement('assertion', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 3)), ...
    'Dimensions', did2.build.dimension(did2.build.term('om:Time', 'time'), 3), ...
    'SessionId', sid, 'ValueKind', 'voltage'), 'assertion_no_time_dimension');
end

function testAnAssertionWithATimeCovariateIsRefused(testCase)
requireRule(testCase, 'assertion', 'assertion_no_time_dimension');
verifyRule(testCase, @() did2.build.statement('assertion', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 3)), ...
    'Dimensions', did2.build.dimension('presentation', 3), ...
    'Covariates', did2.build.covariate(did2.build.term('EMPTY:0000368', 'onset time'), 0, ...
        'Unit', 'second', 'Value', [0 1 2]), ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage'), 'assertion_no_time_dimension');
end

function testAnObservationMayHaveATimeDimension(testCase)
% the rule is the assertion's: an interaction carries its time
requireRule(testCase, 'assertion', 'assertion_no_time_dimension');
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 3)), ...
    'Dimensions', did2.build.dimension('time', 3), 'TimeReferenceIds', {newId()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage');
verifyEqual(testCase, doc.data.dimensions.term.name, 'time');
end

% ===================== datum_order_multidimensional =========================

function testDatumOrderOnAMultiDimensionalBody(testCase)
requireRule(testCase, 'sampled_body', 'datum_order_multidimensional');
sid = testCase.TestData.sid;
two = did2.build.list(did2.build.dimension('time', 2), did2.build.dimension('channel', 2));
body = did2.build.sampledBody(newId(), two, 'DatumOrder', 'F', 'SessionId', sid);
verifyEqual(testCase, body.data.datum_order, 'F');
verifyRule(testCase, @() did2.build.sampledBody(newId(), two, 'SessionId', sid), ...
    'datum_order_multidimensional');
end

function testNoDatumOrderOnAOneDimensionalBody(testCase)
requireRule(testCase, 'sampled_body', 'datum_order_multidimensional');
sid = testCase.TestData.sid;
one = did2.build.dimension('time', 4);
body = did2.build.sampledBody(newId(), one, 'SessionId', sid);
verifyFalse(testCase, isfield(body.data, 'datum_order') && ~isempty(body.data.datum_order));
verifyRule(testCase, @() did2.build.sampledBody(newId(), one, 'DatumOrder', 'C', 'SessionId', sid), ...
    'datum_order_multidimensional');
end

% ===================== fit_metric_unit ======================================

function testAFitMetricInTheCovariatesUnitBuilds(testCase)
requireRule(testCase, 'tuning_curve', 'fit_metric_unit');
doc = buildCurve(testCase, 'degree');
verifyEqual(testCase, doc.tuning_curve.value.model_fit.metrics.preferred_value, 90);
end

function testAFitMetricInAnotherUnitIsRefused(testCase)
requireRule(testCase, 'tuning_curve', 'fit_metric_unit');
verifyRule(testCase, @() buildCurve(testCase, 'radian'), 'fit_metric_unit');
end

function doc = buildCurve(testCase, fitUnit)
% a direction curve whose covariate is in degrees, fitted with the fit's
% independent variable in FITUNIT
f = did2.build.fitEntry('von Mises', 'Coefficients', {'amplitude', 12.1}, ...
    'Metrics', struct('preferred_value', 90), ...
    'Fields', struct('independent_variables', struct( ...
        'variable', did2.build.term('', 'direction'), 'unit', did2.build.term('', fitUnit))), ...
    'Target', 'tuning_curve_calculation.tuning_curve.value.model_fit');
v = struct('mean', [1 2 3 4], 'model_fit', f);
doc = did2.build.statement('tuning_curve_calculation', newId(), 'response', v, ...
    'Dimensions', did2.build.dimension('direction', 4), ...
    'Covariates', did2.build.covariate('direction', 0, 'Unit', 'degree', 'Value', [0 90 180 270]), ...
    'TimeReferenceIds', {newId()}, 'SessionId', testCase.TestData.sid);
end
