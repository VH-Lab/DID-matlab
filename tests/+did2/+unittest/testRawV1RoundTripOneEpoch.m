function tests = testRawV1RoundTripOneEpoch
%TESTRAWV1ROUNDTRIPONEEPOCH oneepoch read as raw v1, and its round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   oneepoch.json, element_epoch.json, epochid.json, base.json) in the shape
%   ndi.element addepoch writes with EPOCHIDS (E.newdocument('oneepoch',
%   'element_epoch.epoch_clock', ..., 'element_epoch.t0_t1', a column for one
%   clock, 'epochid.epochid', ..., 'oneepoch.epoch_ids', ...), element_id),
%   through jsonencode/jsondecode: one clock, and two clocks (a 2-by-2 t0_t1
%   and comma-joined clock names, as oneepoch.m writes them). No corpus of the
%   four zips holds one.
%
%   The migrator keeps the document (class oneepoch), its element_epoch block
%   folded onto oneepoch as `clocks` by did2.convert.migrators.element_epoch,
%   which the raw migrator now calls itself. No known findings.
tests = functiontests(localfunctions);
end

function testTheSwitchListsTheClass(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'oneepoch')));
end

function testWriterShapesRoundTrip(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [label, v1] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
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
f = fixtures();
for k = 1:size(f, 1)
    raw = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'V_eta');
    old = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'V_eta', ...
        'RawV1Classes', {});
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), f{k, 1});
end
end

function testCarries(testCase)
% a field outside the templates (refused by the strict-fields check before)
v1 = oneEpoch('dev_local_time', [0; 100]);
v1.oneepoch.n_epochs = 2;
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-100] malformed: outside the NDI template, unplaced: oneepoch.n_epochs'), notes);
% t0_t1 that does not match its clocks: the superclass migrator's carry-009,
% as on the renamed path
v1 = oneEpoch('dev_local_time,utc', [0; 100]);
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-009]'), notes);
end

function testADifferentSourceIsReportedLost(testCase)
v1 = oneEpoch('dev_local_time', [0; 100]);
out = runRaw(v1);
v1.oneepoch.epoch_ids = 't00001';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'oneepoch.epoch_ids'});
end

% ===================== fixtures =========================================

function f = fixtures()
f = { ...
    'oneepoch, one clock', oneEpoch('dev_local_time', [0; 100]); ...
    'oneepoch, two clocks', oneEpoch('dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100])};
end

function d = oneEpoch(clock, t0t1)
d = did2.unittest.helpers.ndiDocument('oneepoch', 'Id', '41268b6f5c6a3d4e_9f0000000000000a');
d.element_epoch = struct('epoch_clock', clock, 't0_t1', t0t1);
d.epochid = struct('epochid', 'oneepoch_41268b6f5c6a3d4e');
d.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');
d = did2.unittest.helpers.setDependency(d, 'element_id', '41268b6f5c6a3d4e_9f00000000000001');
d = jsondecode(jsonencode(d));
end

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end
