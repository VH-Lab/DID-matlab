function tests = testRawV1RoundTripTuning
%TESTRAWV1ROUNDTRIPTUNING The tuning family read as raw v1, and its round trip:
%   tuningcurve_calc, contrasttuning_calc, oridirtuning_calc,
%   spatial_frequency_tuning_calc, temporal_frequency_tuning_calc,
%   contrastsensitivity_calc.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [early migration pieces
%   fixed] (1) (one migrator per class: the old +migrators/<calc> wrappers are
%   deleted) and [migration reliability practices] (a) (a round trip per class,
%   did2.convert.roundtrip.check).
%
%   THE v1 DOCUMENTS ARE THE WRITERS' OWN OUTPUT. Each calculator's self-test
%   stores the document it wrote as `mock.N.json` (ndi.mock.ctest
%   mock_expected_filename: "the expected NDI document answer"); those files
%   are copied verbatim to tests/+did2/fixtures/ndi_writer_outputs:
%
%     tuningcurve_calc.mock.1.json      NDI-matlab locked `main` 3cb19a8,
%                                       +ndi/+calc/+stimulus/mock/tuningcurve
%     oridirtuning_calc.mock.1.json     NDIcalc-vis-matlab 00e3e0f (its `main`;
%     contrasttuning_calc.mock.1.json   not in did-schema's sibling lock),
%     spatial_frequency_tuning_calc.mock.6.json   +ndi/+calc/+vis/mock/<calc>
%     temporal_frequency_tuning_calc.mock.4.json
%     contrastsensitivity_calc.mock.1.json
%
%   The templates they are written over are in tests/+did2/fixtures/
%   ndi_templates, copied verbatim (NDI-matlab 3cb19a8: tuningcurve_calc,
%   stimulus_tuningcurve, orientation_direction_tuning, calculator, app;
%   NDIcalc-vis-matlab 00e3e0f: the five ndi.calc.vis calculators and
%   contrast_tuning, spatial_frequency_tuning, temporal_frequency_tuning).
%   Where a template and its writer disagree the writer wins: the writer
%   spells `vector.Hotelling2Test` (the template `hotelling2test`) and writes
%   a `calculator` block and `class_version` 2; the corpora (Soph, 20211116)
%   hold the older shape with no `calculator` block and `class_version` 1
%   (the "corpus vintage" fixtures below).
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY. oridirtuning_calc,
%   contrastsensitivity_calc and spatial_frequency_tuning_calc and
%   temporal_frequency_tuning_calc convert (the SF / TF `abs` block on the one
%   calculation since [absolute-value fits are fit entries], Decided by Jess
%   Haley, 2026-10-28, with [interpolated values are a list], 2026-10-30; a
%   second calculation from 2026-10-27 until then), and their round trips
%   lose nothing. contrasttuning_calc carries (carry-056: its fits' relative max
%   gain, saturation index and sensitivity) until did-schema declares them
%   ([contrast metrics added]); tuningcurve_calc alone carries (its stimid and
%   stimulus_presentation_number rebuild only with its response and
%   presentation in the batch, [tuning stimids rebuild]: testTuningDecisions);
%   a carry round-trips as itself. To prove their inverses, the
%   same documents with exactly those fields removed (the "converted shape"
%   fixtures, DID-side) convert and round trip with nothing lost.
%
%   Every fixture converts or carries exactly as on the universalRenames path
%   (testTheSwitchChangesNoConvertedTuning), and broken inputs must fail the
%   round trip. No writer-shaped document here loses a field: there are no
%   known findings for this family.
tests = functiontests(localfunctions);
end

% ===================== the writers' documents round trip =================

function testWriterOutputsRoundTrip(testCase)
roundTripCases(testCase, { ...
    'oridir writer output', writerOutput('oridirtuning_calc'), false; ...
    'oridir corpus vintage', corpusVintage(writerOutput('oridirtuning_calc')), false; ...
    'contrast sensitivity writer output', writerOutput('contrastsensitivity_calc'), false; ...
    'contrast sensitivity corpus vintage', ...
        corpusVintage(writerOutput('contrastsensitivity_calc')), false; ...
    'contrast tuning writer output', writerOutput('contrasttuning_calc'), ...
        ~did2.unittest.helpers.schemaDeclares('tuning_curve', ...
        {'value', 'model_fit', 'metrics', 'relative_max_gain'}); ...
    'SF tuning writer output', writerOutput('spatial_frequency_tuning_calc'), false; ...
    'TF tuning writer output', writerOutput('temporal_frequency_tuning_calc'), false; ...
    'tuningcurve writer output', writerOutput('tuningcurve_calc'), true});
end

function testConvertedShapesRoundTrip(testCase)
% the writers' documents with exactly the fields that carry them removed:
% each converts, and its inverse rebuilds everything that is left
roundTripCases(testCase, { ...
    'contrast tuning, converted shape', convertedShape('contrasttuning_calc'), false; ...
    'SF tuning, converted shape', convertedShape('spatial_frequency_tuning_calc'), false; ...
    'TF tuning, converted shape', convertedShape('temporal_frequency_tuning_calc'), false; ...
    'tuningcurve, converted shape', convertedShape('tuningcurve_calc'), false});
end

function testEveryWriterFieldOfAConvertedOridirIsAccountedFor(testCase)
% each leaf of the writer's document is matched, restated, not set or exempt,
% by name (the denominator is the writer's document, not the inverse's)
v1 = writerOutput('oridirtuning_calc');
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
accounted = [r.matched, r.restated, r.equivalent, r.not_set, r.exempt];
verifyEqual(testCase, numel(accounted), r.fields_inspected);
for p = {'base.id', 'base.session_id', 'base.name', 'base.datestamp', ...
        'depends_on(1).value', 'depends_on(2).value', 'app.name', 'app.version', ...
        'app.url', 'app.os', 'app.os_version', 'app.interpreter', ...
        'app.interpreter_version', 'oridirtuning_calc.depends_on(1).value', ...
        'orientation_direction_tuning.properties.coordinates', ...
        'orientation_direction_tuning.tuning_curve.direction', ...
        'orientation_direction_tuning.tuning_curve.individual', ...
        'orientation_direction_tuning.tuning_curve.control_individual', ...
        'orientation_direction_tuning.vector.Hotelling2Test', ...
        'orientation_direction_tuning.fit.double_gaussian_parameters', ...
        'orientation_direction_tuning.fit.hwhh', 'document_class.class_name'}
    verifyTrue(testCase, any(strcmp(p{1}, [r.matched, r.restated, r.not_set])), ...
        sprintf('%s is not accounted for', p{1}));
end
end

% ===================== the switch ======================================

function testBothSpellingsDispatch(testCase)
% rawV1Classes lists the v1 spelling and maps it to the migrator in ONE table
% (temporary: it goes with universalRenames). The v1 spelling is read raw; the
% migrator's spelling is not switched and reaches it through universalRenames;
% both give the same documents.
verifyEqual(testCase, did2.convert.rawV1Classes('contrasttuning_calc'), 'contrast_tuning_calc');
verifyEqual(testCase, did2.convert.rawV1Classes('contrastsensitivity_calc'), ...
    'contrast_sensitivity_calc');
verifyEqual(testCase, did2.convert.rawV1Classes('oridirtuning_calc'), 'oridirtuning_calc');
names = did2.convert.rawV1Classes();
verifyFalse(testCase, any(strcmp(names, 'contrast_tuning_calc')));
verifyFalse(testCase, any(strcmp(names, 'contrast_sensitivity_calc')));
pairs = {convertedShape('contrasttuning_calc'), 'contrast_tuning_calc'; ...
    writerOutput('contrastsensitivity_calc'), 'contrast_sensitivity_calc'};
for k = 1:size(pairs, 1)
    v1 = pairs{k, 1};
    snake = respelled(v1, pairs{k, 2});
    a = runRaw(v1);
    b = runRaw(snake);
    label = v1.document_class.class_name;
    verifyEqual(testCase, a.summary.legacy_ndi_document.bodies_read_raw_v1, 1, label);
    verifyEqual(testCase, b.summary.legacy_ndi_document.bodies_read_raw_v1, 0, pairs{k, 2});
    verifyEmpty(testCase, a.passthrough, label);
    verifyEmpty(testCase, b.passthrough, pairs{k, 2});
    verifyEqual(testCase, numel(a.migrated), numel(b.migrated), label);
    for j = 1:min(numel(a.migrated), numel(b.migrated))
        verifyTrue(testCase, isequaln(a.migrated{j}.toStruct(), b.migrated{j}.toStruct()), ...
            sprintf('%s: document %d differs between the two spellings', label, j));
    end
end
end

function testWriterOutputsValidate(testCase)
% the converted documents pass the V2 schema (the corpus run validates too)
for cls = {'oridirtuning_calc', 'contrastsensitivity_calc'}
    v1 = writerOutput(cls{1});
    out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine, cls{1});
    verifyGreaterThan(testCase, numel(out.migrated), 1, cls{1});
end
end

% ===================== every field accounted for =========================

function testAFieldTheFoldDoesNotReadCarriesTheDocument(testCase)
% jCalculation 'AccountForEveryField' (the switched migrators): a field the
% fold reads nowhere carries the document whole as v1 instead of being dropped
% from a converted one ([generic stage is lossless]). Its row (Decided by Jess
% Haley, 2026-10-27 [tuning stray fields are malformed]): carry-100 for a
% field, block or edge outside the class's NDI template ([fields outside the
% template are malformed]); carry-056 for a field the template defines and the
% writer writes that V2 has no home for yet.
% (tuningcurve_calc.log is placed since 2026-10-27, [tuning log in notes]; a
% held-fixed property the name table does not hold has no home:
% [varied properties are conditions by V2 name])
v1 = convertedShape('tuningcurve_calc');
v1.tuningcurve_calc.stim_property_list = struct('names', {{'notAStimulusParameter'}}, 'values', 1);
v1 = jsondecode(jsonencode(v1));
verifyCarriedFor(testCase, v1, 'tuningcurve_calc.stim_property_list', 'carry-056');

v1 = writerOutput('oridirtuning_calc');
v1.calculator.note = 'a calculator field';   % calculator.json declares none
verifyCarriedFor(testCase, v1, 'calculator.note', 'carry-100');

v1 = writerOutput('oridirtuning_calc');
v1.app.license = 'MIT';
verifyCarriedFor(testCase, v1, 'app.license', 'carry-100');

v1 = writerOutput('oridirtuning_calc');
v1.depends_on(end + 1) = struct('name', 'stimulus_presentation_id', 'value', 'sp_1');
verifyCarriedFor(testCase, v1, 'depends_on stimulus_presentation_id', 'carry-100');

v1 = writerOutput('oridirtuning_calc');
v1.orientation_direction_tuning.significance.f_test_p = 0.01;
verifyCarriedFor(testCase, v1, 'orientation_direction_tuning.significance.f_test_p', 'carry-100');

v1 = writerOutput('contrastsensitivity_calc');
v1.contrastsensitivity_calc.bandwidth_RB = [1 2 3];
verifyCarriedFor(testCase, v1, 'contrastsensitivity_calc.bandwidth_RB', 'carry-100');

v1 = writerOutput('oridirtuning_calc');
v1.extra_block = struct('x', 1);
verifyCarriedFor(testCase, v1, 'extra_block', 'carry-100');

% a stray field beside the writer's own unhomed fields: one note, each path
% under its own row (the contrast fits' relative_max_gain is in
% contrast_tuning.json and the writer writes it)
v1 = writerOutput('contrasttuning_calc');
v1.contrast_tuning.fit.naka_rushton_RB_note = 'x';
verifyCarriedFor(testCase, v1, 'contrast_tuning.fit.naka_rushton_RB_note', 'carry-100');
if ~did2.unittest.helpers.schemaDeclares('tuning_curve', ...
        {'value', 'model_fit', 'metrics', 'relative_max_gain'})
    % ([contrast metrics added], 2026-10-27: placed once did-schema declares it)
    verifyCarriedFor(testCase, v1, 'contrast_tuning.fit.naka_rushton_RB_relative_max_gain', 'carry-056');
end
end

% ===================== a recognised spelling is notation ===================

function testARecognisedResponseSpellingConvertsAndRoundTrips(testCase)
% Decided by Jess Haley, 2026-10-26 [spelling is notation]: a recognised
% `response_units` spelling converts to its registered term (om:hertz; dF/F's
% variable EMPTY:0000397 with unit om:one), and the round trip counts the v1
% spelling as `equivalent` through the term's registry `synonyms`
% (sameTermSpelling). An unrecognised spelling still comes back exactly.
% A spelling that IS the registered term's name ('dF/F', EMPTY:0000397's
% name) comes back as itself, so the round trip reads it as `matched`
% (did2.convert.roundtrip.check compares exactly before it asks spec.same);
% every other spelling is `equivalent`.
spellings = {'Hz', 'spikes/s', 'Spikes per second', 'dF/F', 'ΔF/F', 'dFF'};
outcome   = {'equivalent', 'equivalent', 'equivalent', 'matched', ...
    'equivalent', 'equivalent'};
inspected = 0;
for j = 1:numel(spellings)
    v1 = writerOutput('oridirtuning_calc');
    v1.orientation_direction_tuning.properties.response_units = spellings{j};
    out = runRaw(v1);
    label = sprintf('oridirtuning_calc, ''%s''', spellings{j});
    verifyEmpty(testCase, out.passthrough, [label ': carried']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    inspected = inspected + 1;
    verifyEmpty(testCase, r.lost, sprintf('%s: lost: %s', label, describeLost(r)));
    verifyTrue(testCase, any(strcmp(r.(outcome{j}), ...
        'orientation_direction_tuning.properties.response_units')), ...
        sprintf('%s: the spelling was not %s', label, outcome{j}));
end
verifyEqual(testCase, inspected, numel(spellings));

% a spelling of ANOTHER term is not the same thing
v1 = writerOutput('oridirtuning_calc');
v1.orientation_direction_tuning.properties.response_units = 'Hz';
docs = structs(runRaw(v1).migrated);
v1.orientation_direction_tuning.properties.response_units = 'dF/F';
r = did2.convert.roundtrip.check(v1, docs);
verifyEqual(testCase, {r.lost.path}, {'orientation_direction_tuning.properties.response_units'});
end

% ===================== a check that cannot fail proves nothing ===========

function testAMissingVersionIsReportedLost(testCase)
v1 = writerOutput('oridirtuning_calc');
docs = structs(runRaw(v1).migrated);
for k = 1:numel(docs)
    d = docs{k};
    if strcmp(d.document_class.class_name, 'assertion') && isfield(d, 'text') ...
            && strcmp(char(d.text.value.text), v1.app.version)
        docs(k) = [];
        break;
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'app.version'});
end

function testAChangedResponseIsReportedLost(testCase)
v1 = writerOutput('oridirtuning_calc');
docs = structs(runRaw(v1).migrated);
docs{1}.tuning_curve.value.mean(3) = docs{1}.tuning_curve.value.mean(3) + 1;
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'orientation_direction_tuning.tuning_curve.mean'});
end

function testADifferentSourceIsReportedLost(testCase)
% the v1 document the emitted ones are compared with states another value
v1 = writerOutput('contrastsensitivity_calc');
out = runRaw(v1);
v1.contrastsensitivity_calc.relative_max_gain_RBN(2) = 0;
v1.depends_on(4).value = 'another_contrast_tuning';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, sort({r.lost.path}), ...
    {'contrastsensitivity_calc.relative_max_gain_RBN', 'depends_on(4).value'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = writerOutput('oridirtuning_calc');
out = runRaw(v1);
extra = runRaw(writerOutput('contrastsensitivity_calc')).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== helpers =========================================

function roundTripCases(testCase, cases)
for k = 1:size(cases, 1)
    [label, v1, carried] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, [label ': quarantined']);
    if ~isempty(out.quarantine)
        continue;
    end
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
    verifyEqual(testCase, r.carried, carried, [label ': carried?']);
    verifyEmpty(testCase, r.lost, sprintf('%s: lost: %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end
end

function verifyCarriedFor(testCase, v1, path, row)
% V1 is carried whole as v1, and its note cites PATH under register row ROW
% (did2.unittest.helpers.carryRowFor)
out = runRaw(v1);
label = sprintf('%s with %s', v1.document_class.class_name, path);
verifyEmpty(testCase, out.quarantine, label);
verifyEqual(testCase, numel(out.passthrough), 1, [label ': not carried']);
if numel(out.migrated) ~= 1
    return;
end
verifyTrue(testCase, isequaln(stripStamp(out.migrated{1}.toStruct()), v1), ...
    [label ': the carry is not the v1 source']);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'carried_as_v1'), [label ': no carried_as_v1 note']);
d = strjoin(cellstr(notes.carried_as_v1.distinct_details), ' || ');
verifyEqual(testCase, did2.unittest.helpers.carryRowFor(d, path), row, ...
    sprintf('%s: the note does not cite it under %s: %s', label, row, d));
end

function s = describeLost(r)
s = '';
for k = 1:numel(r.lost)
    s = [s, sprintf('%s; ', r.lost(k).path)]; %#ok<AGROW>
end
end

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function c = structs(docs)
c = cellfun(@(d) d.toStruct(), docs, 'UniformOutput', false);
end

function s = stripStamp(s)
s.document_class = rmfield(s.document_class, 'schema_version');
end

function names = familyNames()
names = {'tuningcurve_calc', 'contrasttuning_calc', 'oridirtuning_calc', ...
    'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc', ...
    'contrastsensitivity_calc'};
end

function v1 = writerOutput(cls)
% the calculator's own stored output (see the header), as a corpus delivers it
files = struct('tuningcurve_calc', 'tuningcurve_calc.mock.1.json', ...
    'contrasttuning_calc', 'contrasttuning_calc.mock.1.json', ...
    'oridirtuning_calc', 'oridirtuning_calc.mock.1.json', ...
    'spatial_frequency_tuning_calc', 'spatial_frequency_tuning_calc.mock.6.json', ...
    'temporal_frequency_tuning_calc', 'temporal_frequency_tuning_calc.mock.4.json', ...
    'contrastsensitivity_calc', 'contrastsensitivity_calc.mock.1.json');
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_writer_outputs', files.(cls));
v1 = jsondecode(fileread(f));
end

function v1 = corpusVintage(v1)
% the shape the Soph and 20211116 corpora hold: no `calculator` block, class
% version 1 (an earlier writer)
v1 = rmfield(v1, 'calculator');
v1.document_class.class_version = 1;
end

function v1 = convertedShape(cls)
% the writer's document with exactly the fields that carry it removed
v1 = writerOutput(cls);
switch cls
    case 'tuningcurve_calc'
        v1.stimulus_tuningcurve.stimid = [];
        v1.stimulus_tuningcurve.stimulus_presentation_number = [];
    case 'contrasttuning_calc'
        for m = {'RB', 'RBN', 'RBNS'}
            for x = {'relative_max_gain', 'saturation_index', 'sensitivity'}
                v1.contrast_tuning.fit = rmfield(v1.contrast_tuning.fit, ...
                    ['naka_rushton_' m{1} '_' x{1}]);
            end
        end
    case 'spatial_frequency_tuning_calc'
        v1.spatial_frequency_tuning = rmfield(v1.spatial_frequency_tuning, 'abs');
    case 'temporal_frequency_tuning_calc'
        v1.temporal_frequency_tuning = rmfield(v1.temporal_frequency_tuning, 'abs');
end
end

function s = respelled(v1, name)
% V1 with its class and block spelled NAME (the migrator's spelling)
s = v1;
old = s.document_class.class_name;
s.document_class.class_name = name;
s.document_class.property_list_name = name;
s.(name) = s.(old);
s = rmfield(s, old);
end
