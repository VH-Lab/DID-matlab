function tests = testRawV1RoundTripElementEpoch
%TESTRAWV1ROUNDTRIPELEMENTEPOCH The v1 `element_epoch` read as raw v1, and the
%   round trip of its pass-1 carrier (an `acquisition_epoch`).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a); [small unread settings] (4) (a t0_t1 that does
%   not match its clocks is carried, carry-009); [dependents of a carried
%   document carry] (the epoch of a carried element is carried, carry-064).
%   The carrier's dissolution ([device clocks on one epoch], [untied epochs
%   keep the session anchor]) is the batch passes' (testEpochMint,
%   testResolveEpochProbemap) and is not this round trip.
%
%   THE v1 DOCUMENTS are built from NDI's element_epoch.json / epochid.json /
%   base.json templates at the locked NDI-matlab `main` (3cb19a8) as
%   ndi.element/addepoch writes them (+ndi/element.m: epoch_clock the clock
%   string, t0_t1 a column [t0; t1] for one clock, epochid.epochid, then
%   set_dependency_value('element_id', ...) and the .vhsb file), and pass
%   through jsonencode/jsondecode.
tests = functiontests(localfunctions);
end

function testWriterShapedEpochsRoundTrip(testCase)
cases = { ...
    'one clock', epochDoc('ee_1', 'el_probe', 't00001', 'dev_local_time', [0; 10.5], false); ...
    'two clocks', epochDoc('ee_2', 'el_track', 'N2_head_position', ...
        'dev_local_time,exp_global_time', [0 739081.594; 3599.8 739081.636], false); ...
    'with its file info', epochDoc('ee_3', 'el_probe', 't00002', 'dev_local_time', [0; 12], true)};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': carried']);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEqual(testCase, out.migrated{1}.className(), 'acquisition_epoch', label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyGreaterThan(testCase, r.fields_inspected, 0);
    verifyEmpty(testCase, r.lost, sprintf('%s: lost: %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
    for p = {'element_epoch.epoch_clock', 'element_epoch.t0_t1', 'epochid.epochid', ...
            'depends_on(1).value', 'base.id', 'files.file_list'}
        verifyTrue(testCase, any(strcmp(p{1}, r.matched)), sprintf('%s: %s not matched', label, p{1}));
    end
end
end

function testAMismatchedT0T1IsCarriedUntouched(testCase)
% [small unread settings] (4): three columns for two clocks
v1 = epochDoc('ee_bad', 'el_probe', 't00003', 'dev_local_time,exp_global_time', ...
    [0 1 2; 10 11 12], false);
out = runRaw(v1);
verifyEqual(testCase, numel(out.passthrough), 1);
emitted = out.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, contains(d, '[carry-009]'), d);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried && r.ok);
end

function testTheEpochOfACarriedElementIsCarried(testCase)
% [dependents of a carried document carry]: an unlabelled sorted unit is
% carried (carry-062), so its epoch is too (carry-064)
unit = elementDoc('el_unit', 'spikes', 'ndi.neuron');
v1 = epochDoc('ee_unit', 'el_unit', 't00001', 'dev_local_time', [0; 10.5], false);
out = runRaw({unit, v1});
ids = {out.passthrough.id};
verifyTrue(testCase, any(strcmp(ids, 'el_unit')), 'the unit is not carried');
verifyTrue(testCase, any(strcmp(ids, 'ee_unit')), 'its epoch is not carried');
n = out.summary.migration_notes.carried_as_v1;
d = n.details{strcmp(n.ids, 'ee_unit')};
verifyTrue(testCase, startsWith(d, '[carry-064] '), d);
for k = 1:numel(out.migrated)
    verifyNotEqual(testCase, out.migrated{k}.className(), 'acquisition_epoch');
end
end

function testBothPathsMakeTheSameCarrier(testCase)
for v1 = {epochDoc('ee_1', 'el_probe', 't00001', 'dev_local_time', [0; 10.5], false), ...
        epochDoc('ee_3', 'el_probe', 't00002', 'dev_local_time', [0; 12], true)}
    raw = runRaw(v1{1});
    old = did2.convert.v1_to_v2(v1{1}, 'Validate', false, 'TargetVersion', 'V_eta', ...
        'RawV1Classes', {});
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated));
    a = raw.migrated{1}.toStruct();
    b = old.migrated{1}.toStruct();
    verifyTrue(testCase, isequaln(a, b), sprintf('raw %s; renamed %s', jsonencode(a), jsonencode(b)));
end
end

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function s = describeLost(r)
parts = cell(1, numel(r.lost));
for k = 1:numel(r.lost)
    parts{k} = sprintf('%s (v1 %s, rebuilt %s)', r.lost(k).path, ...
        jsonencode(r.lost(k).v1), jsonencode(r.lost(k).rebuilt));
end
s = strjoin(parts, '; ');
if isempty(s); s = '(none)'; end
end

function v1 = epochDoc(id, elementId, epochId, clock, t0t1, withFileInfo)
tpl = loadTemplate('element_epoch');
baseTpl = loadTemplate('base');
eTpl = loadTemplate('epochid');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = tpl.depends_on;
v1.depends_on(1).value = elementId;
v1.files = tpl.files;
if withFileInfo
    % ndi.document/add_file (did.document): one file_info entry per file
    v1.files.file_info = struct('name', 'epoch_binary_data.vhsb', ...
        'locations', struct('uid', '41268b6f5c6a3d4e_f000000000000001', ...
        'location', 'https://example.org/files/41268b6f5c6a3d4e_f000000000000001', ...
        'parameters', '', 'location_type', 'ndicloud', 'ingest', 0, 'delete_original', 0));
end
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.epochid = eTpl.epochid;
v1.epochid.epochid = epochId;
v1.element_epoch = tpl.element_epoch;
v1.element_epoch.epoch_clock = clock;
v1.element_epoch.t0_t1 = t0t1;
v1 = jsondecode(jsonencode(v1));
end

function v1 = elementDoc(id, type, ndiClass)
tpl = loadTemplate('element');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = tpl.depends_on;
v1.depends_on(strcmp({v1.depends_on.name}, 'underlying_element_id')).value = 'el_probe';
v1.depends_on(strcmp({v1.depends_on.name}, 'subject_id')).value = 'subj_1';
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.element = tpl.element;
v1.element.ndi_element_class = ndiClass;
v1.element.name = 'unit_1';
v1.element.reference = 1;
v1.element.type = type;
v1.element.direct = false;
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
