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
%   The migrator keeps a oneepoch on a global clock (class oneepoch), its
%   element_epoch block folded onto oneepoch as `clocks` by
%   did2.convert.migrators.element_epoch, which the raw migrator now calls
%   itself. No known findings. A oneepoch stitched on device-local time (no
%   clock of it global) is carried whole as v1, needs_mapping ([oneepoch is a
%   redundant calculation], Jess Haley, 2026-10-27; [oneepoch method is data
%   combination], Jess Haley, 2026-10-29): testADeviceLocalOneEpochIsCarried.
tests = functiontests(localfunctions);
end

function testTheSwitchListsTheClass(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'oneepoch')));
end

function testWriterShapesRoundTrip(testCase)
% INVERTED 2026-10-29 in part: the one-clock fixture ('dev_local_time' alone)
% was converted; it is a oneepoch stitched on device-local time, now carried
% whole as v1 ([oneepoch is a redundant calculation], Jess Haley, 2026-10-27;
% [oneepoch method is data combination], Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md). CARRIED below says which.
f = fixtures();
for k = 1:size(f, 1)
    [label, v1, carried] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyEqual(testCase, r.carried, carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testADeviceLocalOneEpochIsCarried(testCase)
% [oneepoch is a redundant calculation] (Jess Haley, 2026-10-27) with
% [oneepoch method is data combination] (Jess Haley, 2026-10-29): NDI-matlab
% main +element/oneepoch.m stitches on dev_local_time only when the input has
% no global clock (ndi.time.clocktype.isGlobal); such a oneepoch is carried
% whole as v1, needs_mapping. No carry register row exists for it yet.
v1 = oneEpoch('dev_local_time', [0; 100]);
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'needs_mapping'), notes);
verifyTrue(testCase, contains(notes, 'device-local time'), notes);
% any global clock among its clocks: stitched on that clock, not carried
cases = { ...
    'dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]; ...
    'dev_local_time,approx_dev_global_time', [0 7.3855e5; 100 7.3855e5 + 0.01]; ...
    'exp_global_time', [7.3855e5; 7.3855e5 + 0.01]};
for k = 1:size(cases, 1)
    [clock, t] = cases{k, :};
    out = runRaw(oneEpoch(clock, t));
    verifyEmpty(testCase, out.passthrough, [clock ': not carried']);
    assertNotEmpty(testCase, out.migrated, clock);
    verifyEqual(testCase, out.migrated{1}.className(), 'oneepoch', clock);
end
end

function testADifferentSourceIsReportedLost(testCase)
% (a global-clock oneepoch since 2026-10-29: the device-local one is carried,
% [oneepoch method is data combination])
v1 = oneEpoch('dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]);
out = runRaw(v1);
v1.oneepoch.epoch_ids = 't00001';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'oneepoch.epoch_ids'});
end

% ===================== fixtures =========================================

function f = fixtures()
% {label, v1, carried}: a oneepoch with no global clock is carried
% ([oneepoch method is data combination], Jess Haley, 2026-10-29)
f = { ...
    'oneepoch, one clock', oneEpoch('dev_local_time', [0; 100]), true; ...
    'oneepoch, two clocks', oneEpoch('dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]), false};
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
