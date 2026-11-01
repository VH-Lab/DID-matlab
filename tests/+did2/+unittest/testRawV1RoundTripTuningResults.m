function tests = testRawV1RoundTripTuningResults
%TESTRAWV1ROUNDTRIPTUNINGRESULTS The NDI apps' own tuning results read as raw
%   v1, and their round trip: stimulus_tuningcurve, orientation_direction_tuning.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary].
%
%   THE v1 DOCUMENTS. ndi.app.stimulus.tuning_response (stimulus_tuningcurve)
%   and ndi.app.oridirtuning (orientation_direction_tuning) build the same
%   result block the calculators do (tuning_response.m tuning_curve, the code
%   ndi.calc.stimulus.tuningcurve calls; oridirtuning.m
%   calculate_oridir_indexes, the same struct ndi.calc.vis.oridir writes). So
%   each fixture is the calculator's stored self-test output's result block
%   (tests/+did2/fixtures/ndi_writer_outputs: tuningcurve_calc.mock.1.json,
%   oridirtuning_calc.mock.1.json) over its NDI template at the locked
%   NDI-matlab `main` (3cb19a8: stimulus_tuningcurve.json,
%   orientation_direction_tuning.json, base.json, copied verbatim), with the
%   app writer's own blocks: E.newdocument() (no app block) for the tuning
%   curve; the app's newdocument() app block for the orientation document;
%   their edges.
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY. stimulus_tuningcurve is carried
%   (carry-056: stimid and stimulus_presentation_number have no V2 home, as for
%   tuningcurve_calc); the same document with those removed converts and loses
%   nothing. A field outside the template carries the document under carry-100
%   instead (Decided by Jess Haley, 2026-10-27 [tuning stray fields are
%   malformed]). orientation_direction_tuning converts and loses nothing. No known
%   findings.
%
%   contrast_tuning, spatial_frequency_tuning, temporal_frequency_tuning and
%   speed_tuning (the NDIcalc-vis result blocks, templates from
%   NDIcalc-vis-matlab 00e3e0f) are switched too; their round trips are
%   testRawV1RoundTripTuningBlocks.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
verifyTrue(testCase, any(strcmp(names, 'stimulus_tuningcurve')));
verifyTrue(testCase, any(strcmp(names, 'orientation_direction_tuning')));
end

function testWriterShapesRoundTrip(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [label, v1, carried] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyEqual(testCase, r.carried, carried, [label ': carried?']);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testTheSwitchChangesNoOutcome(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(f(k, 2));
    verifyEmpty(testCase, problems, sprintf('%s: %s', f{k, 1}, strjoin(problems, '; ')));
end
end

function testTheConvertedDocumentsValidate(testCase)
for v1 = {curveConverted(), oridir()}
    out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'did_v2');
    verifyEmpty(testCase, out.quarantine, v1{1}.document_class.class_name);
end
end

function testAFieldTheFoldDoesNotReadCarriesTheDocument(testCase)
% Decided by Jess Haley, 2026-10-27 [tuning stray fields are malformed]: a
% field, block or edge outside the class's NDI template cites carry-100
% ([fields outside the template are malformed]), not carry-056
v1 = oridir();
v1.orientation_direction_tuning.extra_index = 3;
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: orientation_direction_tuning.extra_index');
v1 = did2.unittest.helpers.setDependency(curveConverted(), 'probe_id', 'p_1');
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: depends_on probe_id');
v1 = oridir();
v1.app.license = 'MIT';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: app.license');
end

function testATemplateFieldWithNoHomeCitesCarry056(testCase)
% [tuning stray fields are malformed]: carry-056 keeps only fields the writer
% does write that V2 has no home for yet. The writer's own tuning curve states
% stimid and stimulus_presentation_number (stimulus_tuningcurve.json declares
% both); with a stray field beside them, the one note cites each by its row.
[~, notes] = did2.unittest.helpers.carryNote({curve()});
for f = {'stimid', 'stimulus_presentation_number'}
    verifyEqual(testCase, did2.unittest.helpers.carryRowFor(notes, ...
        ['stimulus_tuningcurve.' f{1}]), 'carry-056', f{1});
end
v1 = curve();
v1.stimulus_tuningcurve.stray_index = 3;
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried, 'not carried as the untouched v1 source');
verifyEqual(testCase, did2.unittest.helpers.carryRowFor(notes, ...
    'stimulus_tuningcurve.stray_index'), 'carry-100', notes);
verifyEqual(testCase, did2.unittest.helpers.carryRowFor(notes, ...
    'stimulus_tuningcurve.stimid'), 'carry-056', notes);
verifyTrue(testCase, startsWith(notes, ['[carry-100] malformed: outside the NDI template, unplaced: ' ...
    'stimulus_tuningcurve.stray_index; unplaced: [carry-056] ']), notes);
end

function testADifferentSourceIsReportedLost(testCase)
v1 = oridir();
out = runRaw(v1);
v1.orientation_direction_tuning.properties.response_type = 'max';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp({r.lost.path}, ...
    'orientation_direction_tuning.properties.response_type')));
end

% ===================== fixtures =========================================

function f = fixtures()
f = { ...
    'stimulus_tuningcurve, tuning_response', curve(), true; ...
    'stimulus_tuningcurve, converted shape', curveConverted(), false; ...
    'orientation_direction_tuning, oridirtuning', oridir(), false};
end

function m = mock(file)
thisDir = fileparts(mfilename('fullpath'));
m = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_writer_outputs', file)));
end

function d = curve()
% tuning_response.tuning_curve: ndi.document('stimulus_tuningcurve',
% 'stimulus_tuningcurve', tuning_curve) + E.newdocument(), then
% stimulus_response_scalar_id and element_id
m = mock('tuningcurve_calc.mock.1.json');
d = did2.unittest.helpers.ndiDocument('stimulus_tuningcurve', 'Id', m.base.id, ...
    'SessionId', m.base.session_id, 'Datestamp', m.base.datestamp);
d.stimulus_tuningcurve = m.stimulus_tuningcurve;
d = did2.unittest.helpers.setDependency(d, 'stimulus_response_scalar_id', depOf(m, 'stimulus_response_scalar_id'));
d = did2.unittest.helpers.setDependency(d, 'element_id', depOf(m, 'element_id'));
d = jsondecode(jsonencode(d));
end

function d = curveConverted()
% the writer's document without the two fields that carry it (DID-side)
d = curve();
d.stimulus_tuningcurve.stimid = [];
d.stimulus_tuningcurve.stimulus_presentation_number = [];
end

function d = oridir()
% oridirtuning.calculate_oridir_indexes: ndi.document('orientation_direction_tuning',
% 'orientation_direction_tuning', var2struct(...)) + the app's newdocument(),
% then element_id and stimulus_tuningcurve_id
m = mock('oridirtuning_calc.mock.1.json');
d = did2.unittest.helpers.ndiDocument('orientation_direction_tuning', 'Id', m.base.id, ...
    'SessionId', m.base.session_id, 'Datestamp', m.base.datestamp);
d.orientation_direction_tuning = m.orientation_direction_tuning;
d.app = struct('name', 'ndi_app_oridirtuning', 'version', m.app.version, ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', m.app.os, ...
    'os_version', m.app.os_version, 'interpreter', 'MATLAB', ...
    'interpreter_version', m.app.interpreter_version);
d = did2.unittest.helpers.setDependency(d, 'element_id', depOf(m, 'element_id'));
d = did2.unittest.helpers.setDependency(d, 'stimulus_tuningcurve_id', depOf(m, 'stimulus_tuningcurve_id'));
d = jsondecode(jsonencode(d));
end

function v = depOf(m, name)
v = '';
for k = 1:numel(m.depends_on)
    if strcmp(m.depends_on(k).name, name); v = m.depends_on(k).value; end
end
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
