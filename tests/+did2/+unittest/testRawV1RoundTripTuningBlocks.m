function tests = testRawV1RoundTripTuningBlocks
%TESTRAWV1ROUNDTRIPTUNINGBLOCKS The NDIcalc-vis tuning result blocks written
%   alone read as raw v1, and their round trip: contrast_tuning,
%   spatial_frequency_tuning, temporal_frequency_tuning, speed_tuning.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary].
%
%   THE TEMPLATES are NDIcalc-vis-matlab's at 00e3e0f, the commit the tuning
%   family's fixtures already come from (tests/+did2/fixtures/ndi_templates:
%   contrast_tuning.json, spatial_frequency_tuning.json,
%   temporal_frequency_tuning.json, speed_tuning.json, copied verbatim from
%   ndi_common/database_documents/vision/; superclass base.json only, edges
%   element_id and stimulus_tuningcurve_id, no `app` block). NDI-matlab's locked
%   `main` holds no template for them.
%
%   THE v1 DOCUMENTS. Each calculator's calculate_*_indexes method
%   (NDIcalc-vis-matlab 00e3e0f: contrast_tuning.m calculate_contrast_indexes,
%   spatial_frequency_tuning.m calculate_spatial_frequency_indexes,
%   temporal_frequency_tuning.m calculate_temporal_frequency_indexes,
%   speed_tuning.m calculate_speed_indexes) writes
%   ndi.document('<class>', '<class>', <block>), then sets element_id and
%   stimulus_tuningcurve_id; calculate() adds that document to its *_calc
%   output. So each fixture is the calculator's stored self-test output's
%   result block (tests/+did2/fixtures/ndi_writer_outputs:
%   contrasttuning_calc.mock.1.json, spatial_frequency_tuning_calc.mock.6.json,
%   temporal_frequency_tuning_calc.mock.4.json, speedtuning_calc.mock.1.json)
%   over its template, with the writer's two edges and the calculator
%   document's identity. No corpus holds a document of any of the four
%   (tools/corpus_class_census.json).
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY: exactly what their *_calc documents
%   do (testRawV1RoundTripTuning, testRawV1RoundTripSpike), since the block is
%   the same. Each carries whole as v1 (carry-056: the contrast fits' relative
%   max gain, saturation index and sensitivity; the SF and TF `abs` block; the
%   three speed fit blocks that would all be named 'Priebe fit'), and a carry
%   round-trips as itself. The same documents with exactly those fields
%   removed (the "converted shape" fixtures, DID-side) convert and round trip
%   with nothing lost. No known findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testTheSwitchListsTheFour(testCase)
names = did2.convert.rawV1Classes();
for c = classNames()
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
    % the v1 spelling is the migrator's: no row in the spelling table
    verifyEqual(testCase, did2.convert.rawV1Classes(c{1}), c{1});
end
end

function testWriterShapesRoundTrip(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [label, v1, carried] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1, label);
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

function testTheCarriesNameTheirReason(testCase)
cases = { ...
    writerShape('contrast_tuning'), 'naka_rushton_RB_relative_max_gain'; ...
    writerShape('spatial_frequency_tuning'), '[carry-056] spatial_frequency_tuning.abs'; ...
    writerShape('temporal_frequency_tuning'), '[carry-056] temporal_frequency_tuning.abs'; ...
    writerShape('speed_tuning'), '[carry-056] speed_tuning.fit, speed_tuning.fit_no_speed'};
for k = 1:size(cases, 1)
    verifyCarried(testCase, cases{k, 1}, cases{k, 2});
end
end

function testTheConvertedDocumentsValidate(testCase)
for c = classNames()
    v1 = convertedShape(c{1});
    out = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine, c{1});
    verifyGreaterThan(testCase, numel(out.migrated), 1, c{1});
end
end

function testAFieldTheFoldDoesNotReadCarriesTheDocument(testCase)
% jCalculation 'AccountForEveryField': a field the fold reads nowhere carries
% the document whole as v1 (carry-056) instead of being dropped
v1 = convertedShape('contrast_tuning');
v1.contrast_tuning.significance.f_test_p = 0.01;
verifyCarried(testCase, v1, 'significance.f_test_p');
v1 = did2.unittest.helpers.setDependency(convertedShape('spatial_frequency_tuning'), ...
    'probe_id', 'p_1');
verifyCarried(testCase, v1, 'depends_on probe_id');
v1 = convertedShape('temporal_frequency_tuning');
v1.extra_block = struct('x', 1);
verifyCarried(testCase, v1, 'extra_block');
v1 = convertedShape('speed_tuning');
v1.app = struct('name', 'ndi.calc.vis.speed_tuning', 'license', 'MIT');
verifyCarried(testCase, v1, 'app.license');
end

function testADifferentSourceIsReportedLost(testCase)
for c = classNames()
    v1 = convertedShape(c{1});
    out = runRaw(v1);
    v1.(c{1}).tuning_curve.mean(2) = v1.(c{1}).tuning_curve.mean(2) + 1;
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.ok, c{1});
    verifyTrue(testCase, any(strcmp({r.lost.path}, [c{1} '.tuning_curve.mean'])), c{1});
end
end

% ===================== fixtures =========================================

function c = classNames()
c = {'contrast_tuning', 'spatial_frequency_tuning', 'temporal_frequency_tuning', 'speed_tuning'};
end

function f = fixtures()
f = cell(0, 3);
for c = classNames()
    f(end + 1, :) = {[c{1} ', writer shape'], writerShape(c{1}), true}; %#ok<AGROW>
    f(end + 1, :) = {[c{1} ', converted shape'], convertedShape(c{1}), false}; %#ok<AGROW>
end
end

function d = writerShape(cls)
% calculate_*_indexes: ndi.document(CLS, CLS, <block>), then element_id and
% stimulus_tuningcurve_id; the block is the one the calculator's stored output
% holds
files = struct('contrast_tuning', 'contrasttuning_calc.mock.1.json', ...
    'spatial_frequency_tuning', 'spatial_frequency_tuning_calc.mock.6.json', ...
    'temporal_frequency_tuning', 'temporal_frequency_tuning_calc.mock.4.json', ...
    'speed_tuning', 'speedtuning_calc.mock.1.json');
m = mock(files.(cls));
d = did2.unittest.helpers.ndiDocument(cls, 'Id', m.base.id, ...
    'SessionId', m.base.session_id, 'Datestamp', m.base.datestamp);
d.(cls) = m.(cls);
d = did2.unittest.helpers.setDependency(d, 'element_id', depOf(m, 'element_id'));
d = did2.unittest.helpers.setDependency(d, 'stimulus_tuningcurve_id', ...
    depOf(m, 'stimulus_tuningcurve_id'));
d = jsondecode(jsonencode(d));
end

function d = convertedShape(cls)
% the writer's document with exactly the fields that carry it removed
% (DID-side), as testRawV1RoundTripTuning / testRawV1RoundTripSpike do for the
% *_calc documents
d = writerShape(cls);
switch cls
    case 'contrast_tuning'
        for m = {'RB', 'RBN', 'RBNS'}
            for x = {'relative_max_gain', 'saturation_index', 'sensitivity'}
                d.contrast_tuning.fit = rmfield(d.contrast_tuning.fit, ...
                    ['naka_rushton_' m{1} '_' x{1}]);
            end
        end
    case {'spatial_frequency_tuning', 'temporal_frequency_tuning'}
        d.(cls) = rmfield(d.(cls), 'abs');
    case 'speed_tuning'
        d.speed_tuning = rmfield(d.speed_tuning, {'fit_no_speed', 'fit_fullspeed'});
end
end

function m = mock(file)
thisDir = fileparts(mfilename('fullpath'));
m = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_writer_outputs', file)));
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
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
