function tests = testRawV1RoundTripVmSpikeFiltering
%TESTRAWV1ROUNDTRIPVMSPIKEFILTERING vmspikefilteringparameters read as raw
%   v1, and its round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's template at the locked NDI-matlab
%   `main` (441530d; tests/+did2/fixtures/ndi_templates, copied verbatim):
%   apps/vhlab_voltage2firingrate/vmspikefilteringparameters.json + base.json
%   + epochid.json + app.json, the template's own values (`threshold` the
%   STRING "0.030", `rm60Hz` camelCase, `spiketimes` empty) with the sampling
%   rates, the epoch, the element edge and the app's name and version set. The
%   writer, vhlab_voltage2firingrate, is in no repository we hold, and no
%   corpus of the four zips holds one.
%
%   The fold to a `method` is unchanged: the raw block's `rm60Hz` lands in the
%   bag as `filter.rm60_hz`, the spelling the renamed path gave it. A non-empty
%   `spiketimes` is carried (carry-143), as before. No known findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testTheClassIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'vmspikefilteringparameters')));
out = runRaw(writerFilter('vfp_1', ''));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

function testTheTemplateShapeFoldsAndRoundTrips(testCase)
v1 = writerFilter('vfp_1', '');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'folded, not carried');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'vmspikefilteringparameters', {});
end

function testTheBagKeepsTheRenamedSpelling(testCase)
% the raw block says rm60Hz; the bag says filter.rm60_hz, as it did on the
% renamed path (testMigratorsJMethodParams pins the bag itself)
v1 = writerFilter('vfp_1', '');
raw = runRaw(v1);
old = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'did_v2', ...
    'RawV1Classes', {});
verifyEqual(testCase, numel(raw.migrated), numel(old.migrated));
for j = 1:min(numel(raw.migrated), numel(old.migrated))
    a = raw.migrated{j}.toStruct();
    b = old.migrated{j}.toStruct();
    verifyTrue(testCase, isequaln(a, b), sprintf('document %d: raw %s; renamed %s', ...
        j, jsonencode(a), jsonencode(b)));
end
end

function testSpiketimesStillCarry(testCase)
v1 = writerFilter('vfp_s', [0.11 0.22 0.35]);
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, '[carry-143] '), notes);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'vmspikefilteringparameters (spiketimes)', {});
end

function testARunEnvironmentStillCarries(testCase)
v1 = writerFilter('vfp_o', '');
v1.app.os = 'GLNXA64';
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-005] '), notes);
end

function testAFieldOutsideTheTemplateCarriesIt(testCase)
v1 = writerFilter('vfp_x', '');
v1.app.license = 'MIT';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: app.license');
v1 = did2.unittest.helpers.setDependency(writerFilter('vfp_x', ''), 'stimulus_presentation_id', 'sp_1');
verifyCarried(testCase, v1, 'depends_on(stimulus_presentation_id)');
v1 = writerFilter('vfp_x', '');
v1.notes = struct('text', 'kept');
verifyCarried(testCase, v1, 'unplaced: notes');
% two spellings of rm60Hz that disagree: what universalRenames would discard
v1 = writerFilter('vfp_x', '');
v1.vmspikefilteringparameters.rm60_hz = 0;
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: vmspikefilteringparameters.rm60Hz');
end

function testTheSwitchChangesNoOutcome(testCase)
for v1 = {writerFilter('vfp_1', ''), writerFilter('vfp_s', [0.11 0.22]), ...
        setfield(writerFilter('vfp_o', ''), 'app', struct('name', 'vhlab_voltage2firingrate', ...
        'version', '0.9', 'url', '', 'os', 'GLNXA64', 'os_version', '', ...
        'interpreter', '', 'interpreter_version', ''))} %#ok<SFLD>
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(v1);
    verifyEmpty(testCase, problems, strjoin(problems, '; '));
end
end

function testAChangedValueIsReportedLost(testCase)
v1 = writerFilter('vfp_1', '');
out = runRaw(v1);
v1.vmspikefilteringparameters.refract = 0.003;
v1.vmspikefilteringparameters.threshold = '0.031';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, sort({r.lost.path}), {'vmspikefilteringparameters.refract', ...
    'vmspikefilteringparameters.threshold'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = writerFilter('vfp_1', '');
out = runRaw(v1);
extra = runRaw(writerFilter('vfp_2', '')).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== fixtures, from the TEMPLATE ======================

function v1 = writerFilter(id, spiketimes)
v1 = did2.unittest.helpers.ndiDocument('vmspikefilteringparameters', 'Id', id);
v1.vmspikefilteringparameters.sampling_rate = 30000;
v1.vmspikefilteringparameters.new_sampling_rate = 10000;
v1.vmspikefilteringparameters.spiketimes = spiketimes;
v1.epochid.epochid = 't00001';
v1.app.name = 'vhlab_voltage2firingrate';
v1.app.version = '0.9';
v1 = did2.unittest.helpers.setDependency(v1, 'element_id', '41268b6f5c6a3d4e_bf000000000000e1');
v1 = jsondecode(jsonencode(v1));
end

% ===================== helpers =========================================

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('vmspikefilteringparameters (%s)', part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
