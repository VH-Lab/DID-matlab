function tests = testRawV1RoundTripFit
%TESTRAWV1ROUNDTRIPFIT The curve fits read as raw v1, and their round trip:
%   fitcurve, vmspikefit.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27 [fit
%   classes kept; session list rebuilt] (both keep their target, a
%   `calculation` with value kind `model_fit`), [fields outside the template
%   are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (441530d; tests/+did2/fixtures/ndi_templates, copied verbatim):
%     fitcurve    data/fitcurve.json + base.json
%     vmspikefit  apps/vhlab_voltage2firingrate/vmspikefit.json + base.json +
%                 epochid.json + app.json
%   NEITHER HAS A WRITER at that `main` (vmspikefit's, vhlab_voltage2firingrate,
%   is in no repository we hold) and no corpus of the four zips holds one, so
%   the fixtures are the templates with every field set, as a writer would set
%   it. A fitcurve converts only when it names a subject, which its template
%   does not: the fixture adds `element_id` (testMigratorsJ's
%   testFitcurveFoldsToResidualScore keeps that path working); the bare
%   template is carried (carry-136).
%
%   WHAT V2 DOES NOT KEEP is listed per fixture as KNOWN FINDINGS (questions
%   for the team; today's behaviour, unchanged by the raw read, is kept):
%     fitcurve.fit_data.output_number_examples   jModelFit keeps the input and
%                                                output fields of fit_data only
%     epochid.epochid (vmspikefit)               the calculation is anchored to
%                                                the session ('during'), not
%                                                the epoch
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== fitcurve ========================================

function testFitcurveIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'fitcurve')));
out = runRaw(writerFitcurve('fc_1'));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
end

function testAFitcurveWithASubjectConvertsAndRoundTrips(testCase)
for withApp = [false true]
    v1 = writerFitcurve('fc_1', withApp);
    label = sprintf('fitcurve (app named: %d)', withApp);
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, not carried']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, ...
        {'fitcurve.fit_data.output_number_examples'});
end
end

function testTheBareFitcurveTemplateIsCarried(testCase)
% the template states no subject: carried whole as v1 (carry-136), as before
v1 = did2.unittest.helpers.ndiDocument('fitcurve', 'Id', 'fc_t');
v1 = jsondecode(jsonencode(v1));
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, '[carry-136] '), notes);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'fitcurve (template)', {});
end

function testAFieldOutsideTheFitcurveTemplateCarriesIt(testCase)
v1 = writerFitcurve('fc_x');
v1.fitcurve.fit_rsquared = 0.9;
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: fitcurve.fit_rsquared');
% an `app` block is read (jModelFit names the run's software from it,
% testMigratorsJ testFitcurveFoldsToResidualScore); a field outside app.json
% carries the document
v1 = writerFitcurve('fc_x', true);
v1.app.license = 'MIT';
verifyCarried(testCase, v1, 'app.license');
v1 = did2.unittest.helpers.setDependency(writerFitcurve('fc_x'), 'stimulus_presentation_id', 'sp_1');
verifyCarried(testCase, v1, 'depends_on(stimulus_presentation_id)');
end

% ===================== vmspikefit ======================================

function testVmspikefitIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'vmspikefit')));
out = runRaw(writerVmspikefit('vf_1', false));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
end

function testAVmspikefitConvertsAndRoundTrips(testCase)
for withApp = [false true]
    v1 = writerVmspikefit('vf_1', withApp);
    label = sprintf('vmspikefit (app named: %d)', withApp);
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, not carried']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {'epochid.epochid'});
end
end

function testTheBareVmspikefitTemplateIsCarried(testCase)
% the template's element_id is empty: no subject, carried whole as v1
% (carry-137), as before
v1 = did2.unittest.helpers.ndiDocument('vmspikefit', 'Id', 'vf_t');
v1 = jsondecode(jsonencode(v1));
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, '[carry-137] '), notes);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'vmspikefit (template)', {});
end

function testAFieldOutsideTheVmspikefitTemplateCarriesIt(testCase)
v1 = writerVmspikefit('vf_x', false);
v1.vmspikefit.fit_rsquared = 0.9;
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: vmspikefit.fit_rsquared');
v1 = writerVmspikefit('vf_x', true);
v1.app.license = 'MIT';
verifyCarried(testCase, v1, 'app.license');
v1 = did2.unittest.helpers.setDependency(writerVmspikefit('vf_x', false), 'stimulus_presentation_id', 'sp_1');
verifyCarried(testCase, v1, 'depends_on(stimulus_presentation_id)');
end

% ===================== both ============================================

function testAChangedValueIsReportedLost(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [label, v1] = f{k, :};
    out = runRaw(v1);
    cls = v1.document_class.class_name;
    v1.(cls).fit_sse = 99;
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, any(strcmp([cls '.fit_sse'], {r.lost.path})), label);
end
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = writerFitcurve('fc_1');
out = runRaw(v1);
extra = runRaw(writerFitcurve('fc_2')).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== fixtures, from the TEMPLATES ======================

function f = fixtures()
f = {'fitcurve, template + element_id', writerFitcurve('fc_1'); ...
    'fitcurve, template + element_id + app', writerFitcurve('fc_3', true); ...
    'vmspikefit, template', writerVmspikefit('vf_1', false); ...
    'vmspikefit, template + app', writerVmspikefit('vf_2', true)};
end

function v1 = writerVmspikefit(id, withApp)
% apps/vhlab_voltage2firingrate/vmspikefit.json (+ epochid, app), every fit
% field set; the template's two edges set in its order
v1 = did2.unittest.helpers.ndiDocument('vmspikefit', 'Id', id);
v1.vmspikefit.fit_name = 'double exponential';
v1.vmspikefit.fit_equation = 'exp2';
v1.vmspikefit.fit_parameters = [1 -0.5 2 -0.05];
v1.vmspikefit.fit_parameter_names = 'a b c d';
v1.vmspikefit.fit_sse = 3.25;
v1.vmspikefit.fit_sse_perpoint = 0.0325;
v1.vmspikefit.fit_constraints = struct('fit_constraint_name', 'b', 'fit_constraint_value', 0);
v1.epochid.epochid = 't00023';
if withApp
    v1.app.name = 'vhlab_voltage2firingrate';
    v1.app.version = '0.9';
end
v1 = did2.unittest.helpers.setDependency(v1, 'fit_input_id', '41268b6f5c6a3d4e_af00000000000001');
v1 = did2.unittest.helpers.setDependency(v1, 'element_id', '41268b6f5c6a3d4e_af000000000000e1');
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerFitcurve(id, withApp)
% data/fitcurve.json, every field set; the subject edge a fit needs to convert
% appended after the template's own (as set_dependency_value appends); with
% WITHAPP, an app.json block (outside the template, read by jModelFit)
if nargin < 2
    withApp = false;
end
v1 = did2.unittest.helpers.ndiDocument('fitcurve', 'Id', id);
v1.fitcurve.fit_name = 'power law';
v1.fitcurve.fit_equation = 'y=a+b*x.^c';
v1.fitcurve.fit_parameters = [0.5 2 1.5];
v1.fitcurve.fit_parameter_names = 'a b c';
v1.fitcurve.fit_independent_variable_names = 'x';
v1.fitcurve.fit_dependent_variable_names = 'y';
v1.fitcurve.fit_sse = 12.5;
v1.fitcurve.fit_constraints = struct('fit_constraint_name', 'c', 'fit_constraint_value', 1.5);
v1.fitcurve.fit_data = struct('input_data_field', 'mydocumenttype.x', ...
    'output_data_field', 'mydocumenttype.y', 'output_number_examples', 20);
if withApp
    v1.app = struct('name', 'curve fitter', 'version', '1');
end
v1 = did2.unittest.helpers.setDependency(v1, 'fit_example_data_id', '41268b6f5c6a3d4e_fc00000000000001');
v1 = did2.unittest.helpers.setDependency(v1, 'element_id', '41268b6f5c6a3d4e_fc000000000000e1');
v1 = jsondecode(jsonencode(v1));
end

% ===================== helpers =========================================

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
