function tests = testRawV1RoundTripIngestedEpochs
%TESTRAWV1ROUNDTRIPINGESTEDEPOCHS Pass-1 passthroughs read as raw v1, and their
%   round trip: daqreader_epochdata_ingested, daqreader_image_epochdata_ingested,
%   vmneuralresponseresiduals, vmspikesummary.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim), in
%   their writers' shapes where a writer exists, through jsonencode/jsondecode:
%     daqreader_epochdata_ingested        +ndi/+daq/reader.m ingest_epochfiles:
%                                         the epochtable and daqreader_id (that
%                                         writer names an undefined variable and
%                                         cannot run at that `main`; its shape
%                                         is the only evidence)
%     daqreader_image_epochdata_ingested  +ndi/+daq/+reader/image.m
%                                         ingest_epochfiles: the raster header,
%                                         the epochtable, epochid, daqreader_id,
%                                         frames.bin
%     vmneuralresponseresiduals,          no writer at that `main` and no corpus
%     vmspikesummary                      document: the template's own values,
%                                         with edges set
%   No corpus of the four zips holds any of them.
%
%   The two readers pass through pass 1 unchanged, as before (resolveEpochProbemap
%   folds their files); vmneuralresponseresiduals and vmspikesummary, which no
%   pass reads, are carried whole as v1 since 2026-10-29 ([one folder, final
%   classes only], Jess Haley). Each round trips as itself. No known findings.
tests = functiontests(localfunctions);
end

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for c = familyClasses()
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
end
f = fixtures();
r = runRaw(f(:, 2)');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, size(f, 1));
end

function testFixturesRoundTripAsPassthroughsOrCarries(testCase)
% INVERTED 2026-10-29 from testFixturesRoundTripAsPassthroughs, which asserted
% all four were silent pass-1 passthroughs stamped did_v2. Decided by Jess
% Haley, 2026-10-29 [one folder, final classes only] (did-schema
% V_eta_go_forward_class_audit.md): a retire class's V2 file is deleted once no
% v1 document passes through under it. vmneuralresponseresiduals and
% vmspikesummary (no V2 home, read by no later pass) are now carried whole as
% v1 with a note ([passthrough stays v1]); the two readers still pass through
% for resolveEpochProbemap, which folds their files.
f = fixtures();
for k = 1:size(f, 1)
    [label, v1] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
    isCarry = any(strcmp(v1.document_class.class_name, ...
        {'vmneuralresponseresiduals', 'vmspikesummary'}));
    if isCarry
        verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
            'did_v1', [label ': carried whole as v1']);
        [carried, notes] = did2.unittest.helpers.carryNote({v1});
        verifyTrue(testCase, carried, [label ': carried as the untouched v1 source']);
        verifyTrue(testCase, contains(notes, 'has no V2 home'), notes);
    else
        verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
            'did_v2', [label ': a passthrough is not a carry']);
    end
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyEqual(testCase, r.carried, isCarry, label);
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

function testValidationIsAsBefore(testCase)
% a raw passthrough validates exactly where the renamed one did
f = fixtures();
for k = 1:size(f, 1)
    raw = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'did_v2');
    old = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'did_v2', ...
        'RawV1Classes', {});
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), f{k, 1});
end
end

function testAFieldOutsideTheTemplateCarriesTheDocument(testCase)
v1 = ingested();
v1.daqreader_epochdata_ingested.sample_rate = 20000;
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: daqreader_epochdata_ingested.sample_rate');
v1 = imageIngested();
v1.daqreader_image_epochdata_ingested.bit_depth = 12;
verifyCarried(testCase, v1, 'daqreader_image_epochdata_ingested.bit_depth');
v1 = did2.unittest.helpers.setDependency(vmResiduals(), 'stimulus_presentation_id', 'sp_1');
verifyCarried(testCase, v1, 'depends_on(stimulus_presentation_id)');
v1 = vmSummary();
v1.vmspikesummary.mean_vm = -60;
verifyNotEmpty(testCase, runRaw(v1).quarantine, 'the V_alpha guard runs first');
v1 = vmSummary();
v1.vmspikesummary.median_isi = 0.01;
verifyCarried(testCase, v1, 'vmspikesummary.median_isi');
end

function testTheMfdaqDelegationIsNotReadTwice(testCase)
% daqreader_mfdaq_epochdata_ingested hands its de-encoded body (with the mfdaq
% parameters moved onto daqreader_epochdata_ingested) to the parent; the
% parent's raw read is skipped for it, so the delegated body is not carried
v1 = ingested();
v1.daqreader_epochdata_ingested.parameters = struct('sample_rate', 20000);
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.daqreader_epochdata_ingested(v1, true);
verifyTrue(testCase, isequaln(out, v1));
verifyEqual(testCase, did2.convert.reportNote('pending', 'carried_as_v1'), 0);
did2.convert.reportNote('reset');
end

function testADifferentSourceIsReportedLost(testCase)
v1 = imageIngested();
out = runRaw(v1);
v1.daqreader_image_epochdata_ingested.num_frames = 99;
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'daqreader_image_epochdata_ingested.num_frames'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = vmSummary();
out = runRaw(v1);
extra = runRaw(vmResiduals()).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== fixtures =========================================

function c = familyClasses()
c = {'daqreader_epochdata_ingested', 'daqreader_image_epochdata_ingested', ...
    'vmneuralresponseresiduals', 'vmspikesummary'};
end

function f = fixtures()
f = { ...
    'daqreader_epochdata_ingested, reader.m', ingested(); ...
    'daqreader_image_epochdata_ingested, image.m', imageIngested(); ...
    'vmneuralresponseresiduals, template', vmResiduals(); ...
    'vmspikesummary, template', vmSummary()};
end

function d = ingested()
% reader.m ingest_epochfiles: epochtable.epochclock, epochtable.t0_t1, then
% daqreader_id
d = did2.unittest.helpers.ndiDocument('daqreader_epochdata_ingested', ...
    'Id', '41268b6f5c6a3d4e_1e0000000000000a');
d.daqreader_epochdata_ingested.epochtable = struct('epochclock', {{'dev_local_time'}}, ...
    't0_t1', [0; 12.5]);
d = did2.unittest.helpers.setDependency(d, 'daqreader_id', '41268b6f5c6a3d4e_1e00000000000001');
d = jsondecode(jsonencode(d));
end

function d = imageIngested()
% image.m ingest_epochfiles: the header, the parent epochtable, epochid, then
% daqreader_id and add_file('frames.bin', ...)
d = did2.unittest.helpers.ndiDocument('daqreader_image_epochdata_ingested', ...
    'Id', '41268b6f5c6a3d4e_1e0000000000000b');
d.daqreader_image_epochdata_ingested = struct('dimension_order', 'YXCT', ...
    'dimension_size', [512 512 1 4], 'data_type', 'uint16', 'num_frames', 4, ...
    'frametimes', [0 0.033 0.066 0.099], 'clocktype', 'dev_local_time', ...
    'metadata', struct('israster', false, 'frame_period', 0.033, 'line_period', NaN, ...
    'dwell_time', NaN, 'lines_per_frame', 512, 'pixels_per_line', 512, 'bidirectional', false));
d.daqreader_epochdata_ingested.epochtable = struct('epochclock', {{'dev_local_time'}}, ...
    't0_t1', [0; 0.132]);
d.epochid = struct('epochid', 't00001');
d = did2.unittest.helpers.setDependency(d, 'daqreader_id', '41268b6f5c6a3d4e_1e00000000000002');
d.files = struct('file_list', {{'frames.bin'}}, 'file_info', struct('name', 'frames.bin', ...
    'locations', struct('delete_original', 1, 'uid', '41268b6f5c6a3d4e_1e000000000000f1', ...
    'location', '/tmp/ndi_frames.bin', 'parameters', '', 'location_type', 'file', 'ingest', 1)));
d = jsondecode(jsonencode(d));
end

function d = vmResiduals()
d = did2.unittest.helpers.ndiDocument('vmneuralresponseresiduals', ...
    'Id', '41268b6f5c6a3d4e_1e0000000000000c');
d = did2.unittest.helpers.setDependency(d, 'element_id', '41268b6f5c6a3d4e_1e00000000000003');
d = jsondecode(jsonencode(d));
end

function d = vmSummary()
d = did2.unittest.helpers.ndiDocument('vmspikesummary', 'Id', '41268b6f5c6a3d4e_1e0000000000000d');
d = did2.unittest.helpers.setDependency(d, 'element_id', '41268b6f5c6a3d4e_1e00000000000003');
d = did2.unittest.helpers.setDependency(d, 'spike_extraction_id', '41268b6f5c6a3d4e_1e00000000000004');
d = jsondecode(jsonencode(d));
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
