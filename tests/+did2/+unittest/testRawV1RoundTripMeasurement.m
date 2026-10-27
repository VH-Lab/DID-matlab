function tests = testRawV1RoundTripMeasurement
%TESTRAWV1ROUNDTRIPMEASUREMENT The measurement family read as raw v1, and its
%   round trip: measurement, subjectmeasurement, stimulus_parameter.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim), in
%   their writers' shapes, through jsonencode/jsondecode:
%     measurement          +ndi/+setup/+NDIMaker/treatmentMaker.m
%                          create_measurement_doc: ontologyName (v1's camelCase
%                          spelling), name, string_value, numeric_value,
%                          subject_id; a number (an age), a term, a date
%     subjectmeasurement   no writer at that `main` outside its tests
%                          (+ndi/+test/+daq/build_intan_flat_exp.m: 'age', 30,
%                          a datestamp), whose shape is the fixture
%     stimulus_parameter   +ndi/+setup/+conv/+marder/temptable2stimulusparameters.m:
%                          an NDIC node, a name, the temperature, epochid,
%                          stimulus_element_id
%   No corpus of the four zips holds any of them.
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY. A numeric measurement and a term
%   measurement convert; a date has no V2 statement and is carried as v1 (on
%   the renamed path it passed through as a V2 `measurement`, a `retire` class,
%   which NDI's last step stored as v1: the same end state). subjectmeasurement
%   converts with its datestamp as an absolute time reference.
%   stimulus_parameter is kept as it is (its decided target is built by no
%   migrator yet). No known findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for c = {'measurement', 'subjectmeasurement', 'stimulus_parameter'}
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
end
end

function testWriterShapesRoundTrip(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [label, v1, outcome] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyEqual(testCase, r.carried, strcmp(outcome, 'carried'), [label ': carried?']);
    if strcmp(outcome, 'converted')
        verifyGreaterThan(testCase, numel(out.migrated), 1, label);
    end
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testTheSwitchChangesNoConvertedDocument(testCase)
f = fixtures();
for k = 1:size(f, 1)
    if strcmp(f{k, 3}, 'carried')
        continue;   % the one change: see testADateIsCarriedNotPassedThrough
    end
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(f(k, 2));
    verifyEmpty(testCase, problems, sprintf('%s: %s', f{k, 1}, strjoin(problems, '; ')));
end
end

function testADateIsCarriedNotPassedThrough(testCase)
[carried, notes] = did2.unittest.helpers.carryNote({measurementDate()});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'no V2 statement'), notes);
end

function testTheConvertedDocumentsValidate(testCase)
f = fixtures();
for k = 1:size(f, 1)
    out = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'V_eta');
    old = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'V_eta', ...
        'RawV1Classes', {});
    verifyLessThanOrEqual(testCase, numel(out.quarantine), numel(old.quarantine), f{k, 1});
end
end

function testAFieldTheMigratorDoesNotReadCarriesTheDocument(testCase)
v1 = measurementAge();
v1.measurement.units = 'weeks';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: measurement.units');
v1 = did2.unittest.helpers.setDependency(measurementAge(), 'protocol_id', 'pr_1');
verifyCarried(testCase, v1, 'depends_on(protocol_id) (no place in the observation)');
v1 = subjectAge();
v1.subjectmeasurement.unit = 'days';
verifyCarried(testCase, v1, 'subjectmeasurement.unit');
v1 = stimulusParameter();
v1.stimulus_parameter.unit = 'C';
verifyCarried(testCase, v1, 'stimulus_parameter.unit');
end

function testADifferentSourceIsReportedLost(testCase)
v1 = measurementAge();
out = runRaw(v1);
v1.measurement.numeric_value = 13;
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'measurement.numeric_value'});
v1 = subjectAge();
out = runRaw(v1);
v1.subjectmeasurement.datestamp = '2018-01-01T00:00:00.000Z';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'subjectmeasurement.datestamp'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = measurementAge();
out = runRaw(v1);
r = did2.convert.roundtrip.check(v1, out.migrated(1));
verifyFalse(testCase, r.ok, 'the session anchor is missing');
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== fixtures =========================================

function f = fixtures()
f = { ...
    'measurement, an age', measurementAge(), 'converted'; ...
    'measurement, a term', measurementTerm(), 'converted'; ...
    'measurement, a date', measurementDate(), 'carried'; ...
    'subjectmeasurement, age with a datestamp', subjectAge(), 'converted'; ...
    'stimulus_parameter, temptable2stimulusparameters', stimulusParameter(), 'kept'};
end

function d = writerMeasurement(id, node, name, stringValue, numericValue)
% create_measurement_doc: S.newdocument('measurement', 'measurement', s), then
% subject_id
d = did2.unittest.helpers.ndiDocument('measurement', 'Id', id);
d.measurement = struct('ontologyName', node, 'name', name, 'string_value', stringValue, ...
    'numeric_value', numericValue);
d = did2.unittest.helpers.setDependency(d, 'subject_id', '41268b6f5c6a3d4e_7e00000000000001');
d = jsondecode(jsonencode(d));
end

function d = measurementAge()
d = writerMeasurement('41268b6f5c6a3d4e_7e0000000000000a', 'NCIT:C25150', 'Age', '', 12);
end

function d = measurementTerm()
% a table row with a string value and no number (readtable's empty cell)
d = writerMeasurement('41268b6f5c6a3d4e_7e0000000000000b', 'NCIT:C14250', 'Organism', ...
    'NCBITaxon:10090', []);
end

function d = measurementDate()
d = writerMeasurement('41268b6f5c6a3d4e_7e0000000000000c', 'NCIT:C68615', 'Date of Birth', ...
    '2024-01-15', []);
end

function d = subjectAge()
% build_intan_flat_exp: E.newdocument('subjectmeasurement', 'measurement',
% 'age', 'value', 30, 'datestamp', ...), subject_id
d = did2.unittest.helpers.ndiDocument('subjectmeasurement', 'Id', '41268b6f5c6a3d4e_7e0000000000000d');
d.subjectmeasurement = struct('measurement', 'age', 'value', 30, ...
    'datestamp', '2017-03-17T19:53:57.066Z');
d = did2.unittest.helpers.setDependency(d, 'subject_id', '41268b6f5c6a3d4e_7e00000000000001');
d = jsondecode(jsonencode(d));
end

function d = stimulusParameter()
% temptable2stimulusparameters, a constant temperature: ontology_name, name,
% value, 'epochid', S.newdocument(), stimulus_element_id
d = did2.unittest.helpers.ndiDocument('stimulus_parameter', 'Id', '41268b6f5c6a3d4e_7e0000000000000e');
d.stimulus_parameter = struct('ontology_name', 'NDIC:8', 'name', 'Command temperature constant', ...
    'value', 11);
d.epochid = struct('epochid', 't00004');
d = did2.unittest.helpers.setDependency(d, 'stimulus_element_id', '41268b6f5c6a3d4e_7e00000000000002');
d = jsondecode(jsonencode(d));
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
