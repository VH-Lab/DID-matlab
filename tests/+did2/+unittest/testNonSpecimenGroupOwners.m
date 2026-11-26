function tests = testNonSpecimenGroupOwners
%TESTNONSPECIMENGROUPOWNERS did2.convert.resolveEpochProbemap: an ingested
%   archive's digital, auxiliary and analog output channel groups get their
%   own owner, and the batch still round trips.
%
%   did-schema docs/plans/did_v2_go_forward_class_audit.md [non-specimen
%   channel groups get their own owner] (Jess Haley, 2026-11-17): "a
%   digital group (`di`, `do`) is owned by an `observation` of value kind
%   `logical`, an auxiliary group (`ax`) by an `observation` of value kind
%   voltage; each with entity the device wired to those channels ([event
%   channel observes its wired device]), the acquisition system where none is
%   wired (counted), and instrument the acquisition system; an analog output
%   group (`ao`) is a manipulation of the subject with the wired stimulating
%   device as instrument where the probe map ties the output to a device and
%   a subject, otherwise an observation of the acquisition system's output;
%   analog input groups (`ai`) stay owned by the recording observation." The
%   acquisition system as an entity is the rig's device (Jess Haley,
%   2026-11-19 [acquisition system is a device entity]). The details (Jess
%   Haley, 2026-11-19 [channel group owners details]): no `instrument_id` on
%   the observations (the rig is their `acquisition_system_id`), the variable
%   is the group's channel-type term, and several devices wired to one group
%   fall back to the rig's device, counted.
%
%   The batch: one epoch of rig intan1, a probe `p` on ai1-2 and a stimulator
%   `vis` on ao1 and di1 (both of subject L), and the archive mfdaq.m wrote
%   for it with channel_list.bin, two ai segments and one di, ax and ao
%   segment each. The controls: the same batch with the rig's device edge
%   removed before the pass (no entity to fall back to: the recording
%   observations keep every group, as before the decision; and, with no
%   fallback to the acquisition_configuration since [unnamed rig is
%   malformed] (Jess Haley, 2026-11-26), no row is wired), and the round
%   trip with a group owner's variable changed to a recording's (it is then
%   read as a probe-map row, and the manifest fails).
tests = functiontests(localfunctions);
end

function testEachNonSpecimenGroupHasItsOwnOwner(testCase)
[~, result, rep] = groupBatch(testCase, 'ns_a', 'c1', true);
% denominators first
verifyEqual(testCase, rep.archive_series_seen, 5, 'channel_list, ai, di, ax, ao');
verifyEqual(testCase, rep.archive_series_specimen, 1);
verifyEqual(testCase, rep.archive_series_other, 1);
verifyEqual(testCase, rep.channel_groups_non_specimen, 3);
verifyEqual(testCase, rep.group_owners_digital, 1);
verifyEqual(testCase, rep.group_owners_auxiliary, 1);
verifyEqual(testCase, rep.group_owners_analog_output_manipulations, 1);
verifyEqual(testCase, rep.group_owners_analog_output_observations, 0);
verifyEqual(testCase, rep.group_owner_kept_recording_no_device, 0);
verifyEqual(testCase, rep.group_owner_entity_wired_device, 2, 'di and ao: the stimulator');
verifyEqual(testCase, rep.group_owner_entity_acquisition_system_unwired, 1, 'ax: nothing wired');
verifyEqual(testCase, rep.group_owner_entity_acquisition_system_several_devices, 0);
verifyEqual(testCase, rep.group_owners_quarantined, 0);
verifyEqual(testCase, rep.bodies_quarantined, 0);
verifyEqual(testCase, rep.archive_docs_retired, 1, 'every file has a surviving owner');
verifyEmpty(testCase, result.quarantine);

sys = 'ns_a_daq';
rig = depVal(docById(result, sys), 'device_id');
assertNotEmpty(testCase, rig, 'premise: the rig has its device entity');
rec = recordingOf(result, 'ns_a_probe');
assertNotEmpty(testCase, rec, 'premise: the probe has its recording observation');
anchors = depVals(rec, 'time_reference_id');

% ai and channel_list.bin: the recording observation, as before
verifyEqual(testCase, ownersOf(result, 'ai_group1_seg.nbf_#'), {char(rec.base.id)});
verifyEqual(testCase, ownersOf(result, 'channel_list.bin'), {char(rec.base.id)});

% di: a `logical` observation of the wired stimulator, the system its rig
di = ownerDoc(testCase, result, 'di_group1_seg.nbf_#');
verifyEqual(testCase, did2.unittest.helpers.classKey(di), 'observation+logical');
verifyEqual(testCase, depVal(di, 'entity_id'), 'ns_a_vis');
verifyEmpty(testCase, depVal(di, 'instrument_id'), 'the system is named by acquisition_system_id');
verifyEqual(testCase, depVal(di, 'acquisition_system_id'), sys);
verifyEqual(testCase, char(di.statement.variable.node), 'EMPTY:0000372');
verifyEqual(testCase, sort(depVals(di, 'time_reference_id')), sort(anchors), ...
    'timed as the recording: the epoch anchor and its clock');

% ax: a voltage observation; nothing wired, so the rig's device is the entity
ax = ownerDoc(testCase, result, 'ax_group1_seg.nbf_#');
verifyEqual(testCase, did2.unittest.helpers.classKey(ax), 'observation+voltage');
verifyEqual(testCase, depVal(ax, 'entity_id'), rig);
verifyEmpty(testCase, depVal(ax, 'instrument_id'));
verifyEqual(testCase, depVal(ax, 'acquisition_system_id'), sys);
verifyEqual(testCase, char(ax.statement.variable.node), 'EMPTY:0000375');

% ao: a manipulation of the subject by the wired stimulator
ao = ownerDoc(testCase, result, 'ao_group1_seg.nbf_#');
verifyEqual(testCase, did2.unittest.helpers.classKey(ao), 'manipulation+voltage');
verifyEqual(testCase, depVal(ao, 'entity_id'), 'ns_a_spec');
verifyEqual(testCase, depVal(ao, 'instrument_id'), 'ns_a_vis');
verifyEqual(testCase, depVal(ao, 'acquisition_system_id'), sys);
verifyEqual(testCase, char(ao.statement.variable.node), 'EMPTY:0000371');
end

function testWithoutTheRigsDeviceTheRecordingKeepsEveryGroup(testCase)
% the control: no device entity to stand for the acquisition system, so no
% owner is minted and the recording observation owns every group, counted
[~, result, rep] = groupBatch(testCase, 'ns_b', 'c2', false);
% and no row is wired: the wiring's parent is the rig's device, with no
% fallback to the configuration ([unnamed rig is malformed], Jess Haley,
% 2026-11-26)
verifyEqual(testCase, rep.wiring_relations_minted, 0);
verifyEqual(testCase, rep.rows_unwirable_rig_no_device, 2, 'p and vis');
verifyEqual(testCase, rep.channel_groups_non_specimen, 3);
verifyEqual(testCase, rep.group_owner_kept_recording_no_device, 3);
verifyEqual(testCase, rep.group_owners_digital + rep.group_owners_auxiliary ...
    + rep.group_owners_analog_output_manipulations ...
    + rep.group_owners_analog_output_observations, 0);
rec = recordingOf(result, 'ns_b_probe');
assertNotEmpty(testCase, rec);
for slot = {'ai_group1_seg.nbf_#', 'di_group1_seg.nbf_#', 'ax_group1_seg.nbf_#', ...
        'ao_group1_seg.nbf_#', 'channel_list.bin'}
    verifyEqual(testCase, ownersOf(result, slot{1}), {char(rec.base.id)}, slot{1});
end
verifyEqual(testCase, rep.archive_docs_retired, 1);
end

function testTheBatchWithGroupOwnersRoundTrips(testCase)
% the archive is rebuilt from its bodies and their owners (every owner names
% the same system, so the same reader, and the same epoch and clock), and the
% manifest's probe map from its statements, the group owners not being rows
[bodies, result, rep] = groupBatch(testCase, 'ns_c', 'c3', true);
assertEqual(testCase, rep.channel_groups_non_specimen - ...
    rep.group_owner_kept_recording_no_device, 3, 'premise: three group owners');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyGreaterThan(testCase, r.sources_compared, 0);
cls = 'daqreader_mfdaq_epochdata_ingested';
verifyTrue(testCase, isfield(r.compared_after_batch_pass_by_class, cls), describe(r));
verifyEmpty(testCase, failureOf(r, 'ns_c_arc'), describe(r));
verifyEmpty(testCase, failureOf(r, 'ns_c_efi'), describe(r));
end

function testAGroupOwnerReadAsARowBreaksTheManifest(testCase)
% the control for NOT A ROW (+roundtrip/private/manifestProbemap): the same
% batch with the digital group's owner given a recording's variable is read
% as a probe-map row, and the manifest no longer round trips
[bodies, result] = groupBatch(testCase, 'ns_d', 'c4', true);
r0 = did2.convert.roundtrip.wholeBatch(bodies, result);
assertEmpty(testCase, failureOf(r0, 'ns_d_efi'), ['premise: ' describe(r0)]);
k = ownerIndex(testCase, result, 'di_group1_seg.nbf_#');
d = result.migrated{k}.toStruct();
d.statement.variable = struct('node', 'AFO:AFR_0001916', 'name', 'voltage');
result.migrated{k} = did2.document(d);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyNotEmpty(testCase, failureOf(r, 'ns_d_efi'), describe(r));
end

function testOnlyTheWiredChannelsAreRecorded(testCase)
% Decided by Jess Haley, 2026-11-19 [only wired channels recorded] (did-schema
% docs/plans/did_v2_standing_wiring_plan.md): "migration records only the
% channels a probe is wired to; a rig's full channel list stays in the file
% headers". The batch of this file's header: the probe map wires p to ai1-2
% and vis to ao1 and di1 on intan1, and the rig's archive also holds an
% auxiliary group nobody is wired to, and its channel_list.bin. Every channel
% number written anywhere in the migrated documents (a channel-type variable
% beside numbers, at any depth) is one of the wired ones, and it is written
% only on a `connected to` wiring relation. The control: the same batch with
% an unwired auxiliary channel added to the auxiliary group's owner is caught.
[~, result, rep] = groupBatch(testCase, 'ns_e', 'c5', true);
% denominators first
assertGreaterThan(testCase, numel(result.migrated), 0, 'the batch migrated nothing');
assertEqual(testCase, rep.channel_groups_non_specimen, 3, 'premise: di, ax and ao groups');
assertEqual(testCase, rep.group_owner_entity_acquisition_system_unwired, 1, ...
    'premise: the ax group is wired to nobody');
recorded = recordedChannels(result);
assertNotEmpty(testCase, recorded, 'the instrument read no channel at all');
pairs = sort(arrayfun(@(r) sprintf('%s %g', r.node, r.number), recorded, ...
    'UniformOutput', false));
wired = sort({'EMPTY:0000370 1', 'EMPTY:0000370 2', ...   % p: ai1-2
    'EMPTY:0000371 1', 'EMPTY:0000372 1'});               % vis: ao1, di1
verifyEqual(testCase, unique(pairs), wired, 'the channels recorded are the wired ones');
for r = reshape(recorded, 1, [])
    verifyEqual(testCase, r.class, 'directed_relation', ...
        sprintf('channel %s %g is written on a %s (%s)', r.node, r.number, r.class, r.id));
end
for w = reshape(recorded, 1, [])
    d = docById(result, w.id);
    verifyEqual(testCase, char(d.directed_relation.relation.node), 'RO:0002170', ...
        'the channels are on a connected to relation');
end

% the control: a channel nobody is wired to, written on the auxiliary
% group's owner, is found and is not a wired one
k = ownerIndex(testCase, result, 'ax_group1_seg.nbf_#');
d = result.migrated{k}.toStruct();
ax = did2.convert.channelType('ax');
d.statement.conditions = struct('variable', struct('node', ax.node, 'name', ax.name), ...
    'numeric', 3);
result.migrated{k} = did2.document(d);
again = recordedChannels(result);
extra = again(strcmp({again.node}, char(ax.node)));
verifyNumElements(testCase, extra, 1, 'the instrument misses an unwired channel');
verifyFalse(testCase, any(strcmp(sprintf('%s %g', ax.node, 3), wired)));
end

function out = recordedChannels(result)
% every channel number in the migrated documents: a struct, at any depth,
% whose `variable.node` is a channel-type term (did2.convert.channelType)
% beside a `numeric` (one row per number: id, class, node, number)
nodes = {};
for p = {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx'}
    t = did2.convert.channelType(p{1});
    nodes{end+1} = char(t.node); %#ok<AGROW>
end
out = struct('id', {}, 'class', {}, 'node', {}, 'number', {});
for k = 1:numel(result.migrated)
    d = result.migrated{k}.toStruct();
    out = [out, walk(d, char(d.base.id), char(d.document_class.class_name), nodes)]; %#ok<AGROW>
end
end

function out = walk(x, id, cls, nodes)
out = struct('id', {}, 'class', {}, 'node', {}, 'number', {});
if iscell(x)
    for i = 1:numel(x); out = [out, walk(x{i}, id, cls, nodes)]; end %#ok<AGROW>
    return;
end
if ~isstruct(x); return; end
for i = 1:numel(x)
    e = x(i);
    if isfield(e, 'variable') && isstruct(e.variable) && isscalar(e.variable) ...
            && isfield(e.variable, 'node') && any(strcmp(char(e.variable.node), nodes)) ...
            && isfield(e, 'numeric') && isnumeric(e.numeric)
        for n = reshape(double(e.numeric), 1, [])
            out(end+1) = struct('id', id, 'class', cls, ...
                'node', char(e.variable.node), 'number', n); %#ok<AGROW>
        end
    end
    f = fieldnames(e);
    for j = 1:numel(f)
        out = [out, walk(e.(f{j}), id, cls, nodes)]; %#ok<AGROW>
    end
end
end

% ===================== the batch ========================================

function [bodies, result, rep] = groupBatch(testCase, stem, tail, withDevice)
% the batch of this file's header; WITHDEVICE false removes the rig's
% `device_id` edge before resolveEpochProbemap runs
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = ['41268b6f5c6a3d4e_00000000000000' tail];
bodies = {sessionV1([stem '_sess'], sid), subjectV1([stem '_spec'], sid, 'L'), ...
    elementV1([stem '_probe'], sid, 'p', 1, 'n-trode', [stem '_spec']), ...
    elementV1([stem '_vis'], sid, 'vis', 1, 'stimulator', [stem '_spec']), ...
    daqsystemV1([stem '_daq'], sid, 'intan1', [stem '_nav']), ...
    manifestV1([stem '_efi'], sid, 't0001', [stem '_nav'], ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'p\t1\tn-trode\tintan1:ai1-2\tL\n' ...
        'vis\t1\tstimulator\tintan1:ao1;di1\tL\n'])), ...
    archiveV1([stem '_arc'], sid, 't0001', ['rdr_' stem '_daq'])};
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
if ~withDevice
    for k = 1:numel(result.migrated)
        d = result.migrated{k}.toStruct();
        if strcmp(char(d.base.id), [stem '_daq'])
            keep = ~strcmp({d.depends_on.name}, 'device_id');
            assert(any(~keep), 'premise: the system names its device');
            d.depends_on = d.depends_on(keep);
            result.migrated{k} = did2.document(d);
        end
    end
end
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
end

function v1 = sessionV1(id, sid)
v1 = struct();
v1.document_class = struct('class_name', 'session', 'property_list_name', 'session', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', 'ref');
end

function v1 = subjectV1(id, sid, localId)
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', localId, 'description', '');
end

function v1 = elementV1(id, sid, name, reference, type, subjectId)
v1 = struct();
v1.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {subjectId});
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.element = struct('ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
    'name', name, 'reference', reference, 'type', type, 'direct', 1);
end

function v1 = daqsystemV1(id, sid, name, navId)
v1 = struct();
v1.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', id, 'session_id', sid, 'name', name, ...
    'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
v1.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'value', {navId, ['rdr_' id]});
end

function v1 = manifestV1(id, sid, epochId, navId, pm)
v1 = struct();
v1.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation', '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name', 'epochfiles_ingested', 'property_list_name', 'epochfiles_ingested', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', navId);
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochfiles_ingested = struct('epoch_id', epochId, ...
    'files', {{['epochid://' epochId]; ['/data/' epochId '/a.rhd']}}, 'epochprobemap', pm);
end

function v1 = archiveV1(id, sid, epochId, readerId)
% a v1 daqreader_mfdaq_epochdata_ingested as NDI-matlab's mfdaq.m
% ingest_epochfiles writes it: its template's file_list, the channel list and
% each segment attached in plan order (ai, ao, ax, di), the segment lengths
thisDir = fileparts(mfilename('fullpath'));
tmpl = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', ...
    'daqreader_mfdaq_epochdata_ingested.json')));
v1 = struct();
v1.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/ingestion/daqreader_mfdaq_epochdata_ingested.json', ...
    'validation', '$NDISCHEMAPATH/ingestion/daqreader_mfdaq_epochdata_ingested_schema.json', ...
    'class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'property_list_name', 'daqreader_mfdaq_epochdata_ingested', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json', ...
        '$NDIDOCUMENTPATH/epochid.json', ...
        '$NDIDOCUMENTPATH/ingestion/daqreader_epochdata_ingested.json'}));
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-03-20T13:48:13.459Z');
v1.depends_on = struct('name', 'daqreader_id', 'value', readerId);
v1.epochid = struct('epochid', epochId);
v1.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 348.66121599999997]));
v1.daqreader_mfdaq_epochdata_ingested = struct('parameters', ...
    struct('sample_analog_segment', 1e6, 'sample_digital_segment', 1e7));
loc = @(u) struct('delete_original', 0, 'uid', [id '_' u], ...
    'location', ['ndic://ds/' id '_' u], 'parameters', '', ...
    'location_type', 'ndicloud', 'ingest', 0);
v1.files = struct('file_list', {tmpl.files.file_list}, ...
    'file_info', struct('name', {'channel_list.bin', 'ai_group1_seg.nbf_1', ...
        'ai_group1_seg.nbf_2', 'ao_group1_seg.nbf_1', 'ax_group1_seg.nbf_1', ...
        'di_group1_seg.nbf_1'}, ...
    'locations', {loc('c'), loc('a1'), loc('a2'), loc('o1'), loc('x1'), loc('d1')}));
end

% ===================== readers ===========================================

function rec = recordingOf(result, probeId)
% the recording observation whose instrument is PROBEID
rec = [];
for k = 1:numel(result.migrated)
    d = result.migrated{k}.toStruct();
    if strcmp(char(d.document_class.class_name), 'observation') ...
            && strcmp(depVal(d, 'instrument_id'), probeId)
        rec = d;
        return;
    end
end
end

function ids = ownersOf(result, slot)
% the owner ids of the opaque_body carrying the v1 series SLOT
ids = {};
for k = 1:numel(result.migrated)
    d = result.migrated{k}.toStruct();
    if strcmp(char(d.document_class.class_name), 'opaque_body') ...
            && strcmp(char(d.data_body.filename), slot)
        ids = depVals(d, 'owner_id');
        return;
    end
end
end

function k = ownerIndex(testCase, result, slot)
% the position in RESULT.migrated of the one owner of SLOT's body
own = ownersOf(result, slot);
assertNumElements(testCase, own, 1, [slot ': one owner']);
k = [];
for j = 1:numel(result.migrated)
    if strcmp(char(result.migrated{j}.get('base.id')), own{1}); k = j; return; end
end
assertNotEmpty(testCase, k, [slot ': its owner is in the batch']);
end

function d = ownerDoc(testCase, result, slot)
d = result.migrated{ownerIndex(testCase, result, slot)}.toStruct();
end

function d = docById(result, id)
d = [];
for k = 1:numel(result.migrated)
    if strcmp(char(result.migrated{k}.get('base.id')), id)
        d = result.migrated{k}.toStruct();
        return;
    end
end
end

function v = depVal(b, name)
v = '';
vals = depVals(b, name);
if ~isempty(vals); v = vals{1}; end
end

function v = depVals(b, name)
v = {};
if ~isstruct(b) || ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
if iscell(deps); deps = [deps{:}]; end
for k = 1:numel(deps)
    if ~strcmp(deps(k).name, name); continue; end
    x = '';
    if isfield(deps(k), 'value') && ~isempty(deps(k).value); x = char(deps(k).value);
    elseif isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id); x = char(deps(k).document_id); end
    if ~isempty(x); v{end+1} = x; end %#ok<AGROW>
end
end

function f = failureOf(r, id)
f = [];
for k = 1:numel(r.failures)
    if strcmp(r.failures(k).source_id, id); f = r.failures(k); end
end
end

function s = describe(r)
parts = {};
for k = 1:numel(r.failures)
    f = r.failures(k);
    parts{end+1} = sprintf('%s (%s): lost %s; invented %s; unplaced %s', f.source_id, ...
        f.class_name, strjoin(f.lost, ', '), strjoin(f.invented, ', '), ...
        strjoin(f.unplaced, '; ')); %#ok<AGROW>
end
s = strjoin(parts, ' || ');
if isempty(s); s = '(no failures)'; end
end
