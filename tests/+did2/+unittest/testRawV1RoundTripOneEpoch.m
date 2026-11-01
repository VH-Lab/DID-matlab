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
%   EVERY oneepoch is carried whole as v1. One stitched on device-local time
%   (no clock of it global) is carried needs_mapping, carry-126 ([oneepoch is
%   a redundant calculation], Jess Haley, 2026-10-27; [oneepoch method is data
%   combination], Jess Haley, 2026-10-29): testADeviceLocalOneEpochIsCarried.
%   One on a global clock, which until 2026-10-29 kept the class `oneepoch`
%   with its element_epoch block folded onto it as `clocks`, is carried
%   ([reshaped retire classes carried], Jess Haley, 2026-10-29, "B") with its
%   output element, its note citing the element's carry ([global-clock
%   oneepoch carried with its element], Jess Haley, 2026-10-30, "Q5 a"):
%   testAGlobalClockOneEpochIsCarried, testAGlobalClockOneEpochCitesItsElement.
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
% V_eta_go_forward_class_audit.md). INVERTED 2026-10-29 in full: the
% two-clock fixture (one of them utc) kept the class; it is carried too
% ([reshaped retire classes carried], Jess Haley, 2026-10-29). CARRIED below
% says which.
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
% whole as v1, needs_mapping, citing register row carry-126 (did-schema
% 64ad58b8; until then the note said it had no register row).
v1 = oneEpoch('dev_local_time', [0; 100]);
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'needs_mapping'), notes);
verifyTrue(testCase, startsWith(notes, '[carry-126] needs_mapping: '), notes);
verifyTrue(testCase, contains(notes, 'device-local time'), notes);
end

function testAGlobalClockOneEpochIsCarried(testCase)
% INVERTED 2026-10-29 from the second half of testADeviceLocalOneEpochIsCarried,
% which asserted that a oneepoch with any global clock among its clocks was
% NOT carried (it kept the class `oneepoch`). [reshaped retire classes
% carried] (Jess Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md,
% "B"): it is carried whole as v1. [global-clock oneepoch carried with its
% element] (Jess Haley, 2026-10-30): with its output element, citing the
% element's carry; the awaiting_home row it cited until then is dropped. Its
% element is not in this batch, so its note says so and cites no row. It is
% still told apart from the device-local carry: its note is not carry-126's.
cases = { ...
    'dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]; ...
    'dev_local_time,approx_dev_global_time', [0 7.3855e5; 100 7.3855e5 + 0.01]; ...
    'exp_global_time', [7.3855e5; 7.3855e5 + 0.01]};
for k = 1:size(cases, 1)
    [clock, t] = cases{k, :};
    [carried, notes, out] = did2.unittest.helpers.carryNote({oneEpoch(clock, t)});
    verifyTrue(testCase, carried, [clock ': carried as the untouched v1 source']);
    verifyEqual(testCase, numel(out.passthrough), 1, [clock ': recorded as a passthrough']);
    verifyTrue(testCase, startsWith(notes, ...
        'a oneepoch on a global clock, not carried with its output element: '), [clock ': ' notes]);
    verifyTrue(testCase, contains(notes, 'which is not in this batch'), [clock ': ' notes]);
    verifyEmpty(testCase, regexp(notes, 'carry-\d{3}', 'once'), [clock ': ' notes]);
end
end

function testAGlobalClockOneEpochCitesItsElement(testCase)
% [global-clock oneepoch carried with its element] (Decided by Jess Haley,
% 2026-10-30, did-schema V_eta_go_forward_class_audit.md): its output element
% (ndi.element.oneepoch keeps the input's probe type on class
% ndi.element.oneepoch) is carried, carry-063 ([element types have no
% default]), and the oneepoch's note cites that row. Its round trip is the
% carry.
v1 = oneEpoch('dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]);
el = did2.unittest.helpers.ndiDocument('element', 'Id', '41268b6f5c6a3d4e_9f00000000000001');
el.element = struct('ndi_element_class', 'ndi.element.oneepoch', 'name', 'probeA', ...
    'reference', 1, 'type', 'n-trode', 'direct', 0);
el = jsondecode(jsonencode(el));
[carried, notes, out] = did2.unittest.helpers.carryNote({v1, el});
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, ['[carry-063] a oneepoch on a global clock, ' ...
    'carried with its output element 41268b6f5c6a3d4e_9f00000000000001']), notes);
verifyFalse(testCase, contains(notes, 'awaiting_home'), notes);
r = did2.convert.roundtrip.check(v1, out.migrated(1));
verifyTrue(testCase, r.carried);
end

function testADifferentSourceIsReportedLost(testCase)
% (a global-clock oneepoch since 2026-10-29: the device-local one is carried,
% [oneepoch method is data combination]). INVERTED 2026-10-29: the global-clock
% one is carried too ([reshaped retire classes carried], Jess Haley,
% 2026-10-29), so the round trip reads the carry, and a source that differs
% from the carried body is still reported lost at the field that differs.
v1 = oneEpoch('dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]);
out = runRaw(v1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried, 'the global-clock oneepoch is carried');
v1.oneepoch.epoch_ids = 't00001';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'oneepoch.epoch_ids'});
end

% ===================== fixtures =========================================

function f = fixtures()
% {label, v1, carried}: a oneepoch with no global clock is carried
% ([oneepoch method is data combination], Jess Haley, 2026-10-29); so is one
% on a global clock ([reshaped retire classes carried], Jess Haley, 2026-10-29)
f = { ...
    'oneepoch, one clock', oneEpoch('dev_local_time', [0; 100]), true; ...
    'oneepoch, two clocks', oneEpoch('dev_local_time,utc', [0 1.7e9; 100 1.7e9 + 100]), true};
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
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end
