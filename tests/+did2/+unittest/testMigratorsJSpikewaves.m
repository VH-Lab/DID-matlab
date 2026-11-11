function tests = testMigratorsJSpikewaves
%TESTMIGRATORSJSPIKEWAVES +migrators_j/spikewaves: a v1 spikewaves becomes two
%   calculations on the element (Jess Haley, 2026-11-10, did-schema
%   did_v2_go_forward_class_audit.md [spike waveforms are two calculations],
%   [spike waveforms built now] D1-D6), and the round trip rebuilds the
%   document and both files.
%
%   THE FIXTURE IS NDI's WRITER'S (CLAUDE.md: fixtures from the writer). The
%   document is ndi.document('spikewaves') from NDI's template
%   (tests/+did2/fixtures/ndi_templates/spikewaves.json, copied verbatim from
%   NDI-matlab's locked `main`, 73f46d19) with what NDI-matlab
%   +app/spikeextractor.m extract sets: extraction_name, epochid, the app
%   block of ndi.app/newdocument, the two edges and the two files. The files
%   are written exactly as extract writes them: the header by
%   vlt.file.custom_file_formats.newvhlspikewaveformfile (opened big-endian),
%   the waveforms by addvhlspikewaveformfile through a little-endian
%   vlt.file.fileobj, the times by fwrite 'float32' on a little-endian fid
%   (ndi.file.temp_fid).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
testCase.TestData.dir = tempname;
mkdir(testCase.TestData.dir);
testCase.addTeardown(@() rmdir(testCase.TestData.dir, 's'));
end

% ===================== the shape =========================================

function testTheWriterDocumentBecomesTwoCalculations(testCase)
f = writerSpikewaves(testCase, 'a', 7);
out = runStamped(f.v1);
verifyEmpty(testCase, out.quarantine, quarantineText(out));
docs = structs(out.migrated);
names = cellfun(@(d) char(d.document_class.class_name), docs, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'calculation')), 2, strjoin(names, ', '));
verifyEqual(testCase, sum(strcmp(names, 'sampled_body')), 2, strjoin(names, ', '));
verifyEqual(testCase, sum(strcmp(names, 'relative_time_reference')), 1, strjoin(names, ', '));

% (1) the spike times keep the v1 id (D2)
times = byId(docs, f.id);
assertNotEmpty(testCase, times, 'the v1 id is not on the spike-times calculation');
verifyEqual(testCase, char(times.document_class.class_name), 'calculation');
verifyEqual(testCase, char(times.statement.variable.node), 'GO:0001508');
verifyEqual(testCase, dep(times, 'entity_id'), {f.element});
verifyEqual(testCase, dep(times, 'method_id'), {f.params});
[~, kind] = did2.convert.statementKind(times);
verifyEqual(testCase, kind, 'time');
% (2) the waveforms: input (1), the same method and element
calcs = docs(strcmp(names, 'calculation'));
waves = calcs{~strcmp(cellfun(@(d) char(d.base.id), calcs, 'UniformOutput', false), f.id)};
[~, kind] = did2.convert.statementKind(waves);
verifyEqual(testCase, kind, 'voltage');
verifyEqual(testCase, dep(waves, 'input_id'), {f.id});
verifyEqual(testCase, dep(waves, 'method_id'), {f.params});
verifyEqual(testCase, dep(waves, 'entity_id'), {f.element});
verifyEqual(testCase, dep(waves, 'time_reference_id'), dep(times, 'time_reference_id'));

% the bodies
tb = ownedBy(docs, f.id);
wb = ownedBy(docs, char(waves.base.id));
assertNotEmpty(testCase, tb);
assertNotEmpty(testCase, wb);
verifyEqual(testCase, double(tb.data.dimensions.n), 7);
verifyEqual(testCase, char(tb.data.dimensions.term.node), 'GO:0001508');
d = wb.data.dimensions;
verifyEqual(testCase, double([d.n]), [7, f.nSamples, f.nChannels]);
verifyEqual(testCase, reshape(arrayfun(@(x) char(x.term.node), d, 'UniformOutput', false), 1, []), ...
    {'GO:0001508', 'om:Time', 'NCIT:C44170'});
verifyEqual(testCase, char(wb.data.datum_order), 'C');
verifyEqual(testCase, dep(wb, 'key_id'), {f.id});
% the epoch anchor (D3)
a = byId(docs, dep(times, 'time_reference_id'));
verifyEqual(testCase, dep(a, 'referent_id'), {f.epochId});
% the waveform body holds the samples spike x sample x channel (C order)
bytes = readFile(wb.files.file_info.locations.location);
got = reshape(typecast(bytes, 'single'), f.nChannels, f.nSamples, 7);
verifyEqual(testCase, permute(got, [3 2 1]), permute(f.waves, [3 1 2]));
% the spike-times body IS spiketimes.bin
verifyEqual(testCase, char(tb.files.file_info.locations.location), f.timesFile);
end

function testTheConvertedDocumentsValidate(testCase)
f = writerSpikewaves(testCase, 'b', 3);
out = did2.convert.v1_to_v2({stamp(f.v1)}, 'Validate', true, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine, quarantineText(out));
verifyEqual(testCase, sum(strcmp(cellfun(@(d) d.className(), out.migrated, ...
    'UniformOutput', false), 'calculation')), 2);
end

function testZeroSpikesAreTwoCalculationsWithAnEmptySpikeAxis(testCase)
% D6: allowed, not carried
f = writerSpikewaves(testCase, 'c', 0);
out = runStamped(f.v1);
verifyEmpty(testCase, out.quarantine, quarantineText(out));
docs = structs(out.migrated);
names = cellfun(@(d) char(d.document_class.class_name), docs, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'calculation')), 2);
tb = ownedBy(docs, f.id);
verifyEqual(testCase, double(tb.data.dimensions.n), 0);
r = roundTrip(f, out);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'zero spikes', vswRecordPaths());
[vsw, tbin, problem] = did2.convert.roundtrip.spikewavesFiles(out.migrated, f.epoch);
verifyEmpty(testCase, problem);
verifyEqual(testCase, vsw, readFile(f.vswFile));
verifyEqual(testCase, tbin, readFile(f.timesFile));
end

% ===================== the round trip ====================================

function testTheRoundTripRebuildsTheDocument(testCase)
f = writerSpikewaves(testCase, 'd', 5);
out = runStamped(f.v1);
r = roundTrip(f, out);
% the .vsw record is the new waveform file's: its uid and location are not
% the v1 file's (the bytes are rebuilt, below)
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'spikewaves', vswRecordPaths());
end

function testTheRoundTripRebuildsBothFilesByteForByte(testCase)
f = writerSpikewaves(testCase, 'e', 9);
out = runStamped(f.v1);
[vsw, tbin, problem] = did2.convert.roundtrip.spikewavesFiles(out.migrated, f.epoch);
verifyEmpty(testCase, problem);
verifyEqual(testCase, vsw, readFile(f.vswFile), 'spikewaves.vsw');
verifyEqual(testCase, tbin, readFile(f.timesFile), 'spiketimes.bin');
% and the writer's own reader reads the rebuilt file as it read the original
p = fullfile(testCase.TestData.dir, 'rebuilt.vsw');
fid = fopen(p, 'w');
fwrite(fid, vsw, 'uint8');
fclose(fid);
fo = vlt.file.fileobj('fullpathfilename', p, 'permission', 'r', 'machineformat', 'l');
fo = fo.fopen();
[w, params] = vlt.file.custom_file_formats.readvhlspikewaveformfile(fo);
fclose(fo);
verifyEqual(testCase, single(w), f.waves);
verifyEqual(testCase, params.numchannels, f.nChannels);
verifyEqual(testCase, params.S0, f.S0);
verifyEqual(testCase, params.S1, f.S1);
verifyEqual(testCase, params.name, f.id);
verifyEqual(testCase, params.comment, f.epoch);
end

function testTheCarriedSpikeClustersEdgeResolves(testCase)
% D2: spike_clusters (carried, carry-102) points at the spikewaves id by
% spikewaves_doc_id; the spike-times calculation keeps that id, so the edge
% resolves (did2.validate.references: id resolution)
f = writerSpikewaves(testCase, 'f', 2);
sc = did2.unittest.helpers.ndiDocument('spike_clusters', 'Id', '41268b6f5c6a3d4e_5f000000000000c1', ...
    'SessionId', f.sid, 'Datestamp', '2024-06-01T12:00:00.000Z');
sc = did2.unittest.helpers.setDependency(sc, 'spikewaves_doc_id', f.id);
sc = jsondecode(jsonencode(sc));
out = did2.convert.v1_to_v2({stamp(f.v1), sc}, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine, quarantineText(out));
names = cellfun(@(d) d.className(), out.migrated, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'spike_clusters')), 'spike_clusters is carried');
rep = did2.validate.references(out.migrated);
edges = {};
for k = 1:numel(rep.orphans)
    edges{end+1} = rep.orphans(k).edge_name; %#ok<AGROW>
end
verifyFalse(testCase, any(strcmp(edges, 'spikewaves_doc_id')), ...
    'the carried spike_clusters'' spikewaves_doc_id does not resolve');
end

% ===================== the epoch (D3) ====================================

function testPassOneDefersAndEpochMintMigratesIt(testCase)
f = writerSpikewaves(testCase, 'g', 4);
out = did2.convert.v1_to_v2({f.v1}, 'Validate', false, 'TargetVersion', 'did_v2');
assertNumElements(testCase, out.quarantine, 1);
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:needsEpochContext');
out.migrated{end+1} = did2.document(epochEntity(f));
out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, out.epoch_mint.spikewaves_deferred_seen, 1);
verifyEqual(testCase, out.epoch_mint.spikewaves_deferred_resolved, 1);
verifyEmpty(testCase, out.quarantine, quarantineText(out));
docs = structs(out.migrated);
times = byId(docs, f.id);
assertNotEmpty(testCase, times);
a = byId(docs, dep(times, 'time_reference_id'));
verifyEqual(testCase, dep(a, 'referent_id'), {f.epochId});
end

function testADeferredSpikewavesOfACarriedElementCarries(testCase)
% [dependents of a carried document carry] (carry-064): the deferred document
% is not seen by pass 1's carryDependents, so epochMint checks it
f = writerSpikewaves(testCase, 'h', 1);
% the writer's extraction settings: ndi.app/newdocument writes the run's os
% and interpreter, so the document is carried (carry-003)
p = did2.unittest.helpers.ndiDocument('spike_extraction_parameters', ...
    'Id', f.params, 'Name', 'default', 'SessionId', f.sid, ...
    'Datestamp', '2024-06-01T12:00:00.000Z');
p.app = f.v1.app;
if isfield(p, 'depends_on'); p = rmfield(p, 'depends_on'); end
p = jsondecode(jsonencode(p));
out = did2.convert.v1_to_v2({p, f.v1}, 'Validate', false, 'TargetVersion', 'did_v2');
assertNumElements(testCase, out.quarantine, 1);
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:needsEpochContext');
out.migrated{end+1} = did2.document(epochEntity(f));
out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, out.epoch_mint.spikewaves_deferred_carried_dependent, 1);
verifyEmpty(testCase, out.quarantine, quarantineText(out));
sw = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), f.id); sw = out.migrated{k}.toStruct(); end
end
assertNotEmpty(testCase, sw);
verifyEqual(testCase, char(sw.document_class.class_name), 'spikewaves');
verifyEqual(testCase, char(sw.document_class.schema_version), 'did_v1');
end

% ===================== what carries ======================================

function testUnreadableFilesCarryTheDocument(testCase)
f = writerSpikewaves(testCase, 'i', 2);
v1 = f.v1;
v1.files.file_info(1).locations.location = fullfile(testCase.TestData.dir, 'gone.vsw');
[carried, notes, out] = did2.unittest.helpers.carryNote({stamp(v1)});
verifyEmpty(testCase, out.quarantine, quarantineText(out));
verifyTrue(testCase, carried, 'not carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, '[carry-171] files spikewaves.vsw'), notes);
end

function testAHeaderTheWriterDoesNotWriteCarries(testCase)
% the header names another document: it would not rebuild from this one
f = writerSpikewaves(testCase, 'j', 2, 'Name', '41268b6f5c6a3d4e_5f00000000000999');
[carried, notes] = did2.unittest.helpers.carryNote({stamp(f.v1)});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'not the one NDI''s writer makes'), notes);
verifyTrue(testCase, contains(notes, '[carry-120] files spikewaves.vsw/spiketimes.bin'), notes);
end

function testCountsTheTwoFilesDisagreeOnCarry(testCase)
f = writerSpikewaves(testCase, 'k', 3);
fid = fopen(f.timesFile, 'a', 'l');
fwrite(fid, single(9.5), 'float32');
fclose(fid);
[carried, notes] = did2.unittest.helpers.carryNote({stamp(f.v1)});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '4 times for 3 waveforms'), notes);
verifyTrue(testCase, contains(notes, '[carry-120] files spikewaves.vsw/spiketimes.bin'), notes);
end

function testTheReaderIsReadAsBytes(testCase)
% D4: with a v1 file reader set, the migrator asks it for BYTES
f = writerSpikewaves(testCase, 'l', 2);
% only the reader can find the files: their recorded locations are gone
v1 = f.v1;
v1.files.file_info(1).locations.location = '/gone/spikewaves.vsw';
v1.files.file_info(2).locations.location = '/gone/spiketimes.bin';
asked = {};
    function out = reader(body, name, mode)
        asked{end+1} = mode;
        out = readFile(fullfile(testCase.TestData.dir, ['l_' name]));
    end
out = did2.convert.v1_to_v2({stamp(v1)}, 'Validate', false, 'TargetVersion', 'did_v2', ...
    'V1FileReader', @reader);
verifyEmpty(testCase, out.quarantine, quarantineText(out));
verifyEqual(testCase, unique(asked), {'bytes'});
verifyEqual(testCase, sum(strcmp(cellfun(@(d) d.className(), out.migrated, ...
    'UniformOutput', false), 'calculation')), 2);
end

% ===================== the writer ========================================

function f = writerSpikewaves(testCase, tag, nSpikes, opts)
% one spikewaves document and its two files, as spikeextractor.m extract
% writes them for one epoch of a 2-channel element at 30 kHz, S0 -9, S1 20
arguments
    testCase
    tag (1,:) char
    nSpikes (1,1) double
    opts.Name (1,:) char = ''
end
f = struct();
f.id = ['41268b6f5c6a3d4e_5f0000000000' sprintf('%04x', double(tag(1)))];
f.sid = '41268b6f5c6a3d4e_00000000000000a1';
f.element = '41268b6f5c6a3d4e_5f000000000000e1';
f.params = '41268b6f5c6a3d4e_5e0000000000000a';
f.epochId = '41268b6f5c6a3d4e_5f000000000000ee';
f.epoch = 't00001';
f.nChannels = 2;
f.S0 = -9;
f.S1 = 20;
f.nSamples = f.S1 - f.S0 + 1;
rng(double(tag(1)));
f.waves = single(randn(f.nSamples, f.nChannels, nSpikes) * 1e-4);   % Nsamples x Nchannels x Nspikes
times = single(sort(rand(nSpikes, 1) * 10));
dir = testCase.TestData.dir;
f.vswFile = fullfile(dir, [tag '_spikewaves.vsw']);
f.timesFile = fullfile(dir, [tag '_spiketimes.bin']);
% spikeextractor.m extract, in its order
fidW = fopen(f.vswFile, 'w', 'l');   % ndi.file.temp_fid
fidT = fopen(f.timesFile, 'w', 'l');
fo = vlt.file.fileobj('permission', 'w', 'fullpathfilename', f.vswFile, ...
    'machineformat', 'l', 'fid', fidW);
fp = struct('numchannels', f.nChannels, 'S0', f.S0, 'S1', f.S1, ...
    'name', f.id, 'ref', 0, 'comment', f.epoch, 'samplingrate', 30000);
if ~isempty(opts.Name); fp.name = opts.Name; end
vlt.file.custom_file_formats.newvhlspikewaveformfile(f.vswFile, fp);
if nSpikes > 0
    vlt.file.custom_file_formats.addvhlspikewaveformfile(fo, f.waves);
    fwrite(fidT, times, 'float32');
end
fclose(fidT);
fclose(fo);

d = did2.unittest.helpers.ndiDocument('spikewaves', 'Id', f.id, 'SessionId', f.sid, ...
    'Datestamp', '2024-06-01T12:00:00.000Z');
d.spikewaves.extraction_name = 'default';
d.epochid.epochid = f.epoch;
d.app = struct('name', 'ndi_app_spikeextractor', ...
    'version', '9f3c2a1b7d4e5f60718293a4b5c6d7e8f9012345', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'GLNXA64', ...
    'os_version', '6.5.0', 'interpreter', 'MATLAB', ...
    'interpreter_version', '24.2.0.2712019 (R2024b)');
d = did2.unittest.helpers.setDependency(d, 'extraction_parameters_id', f.params);
d = did2.unittest.helpers.setDependency(d, 'element_id', f.element);
loc = @(p, u) struct('delete_original', 1, 'uid', u, 'location', p, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1);
d.files = struct('file_list', {{'spikewaves.vsw', 'spiketimes.bin'}});
d.files.file_info = struct('name', {'spikewaves.vsw', 'spiketimes.bin'}, ...
    'locations', {loc(f.vswFile, ['41268b6f5c6a3d4e_5f0000000001' sprintf('%04x', double(tag(1)))]), ...
                  loc(f.timesFile, ['41268b6f5c6a3d4e_5f0000000002' sprintf('%04x', double(tag(1)))])});
f.v1 = jsondecode(jsonencode(d));
end

% ===================== helpers ===========================================

function v1 = stamp(v1)
% the edge epochMint stamps before it re-runs the migrator
v1 = did2.unittest.helpers.setDependency(v1, 'epoch_id', '41268b6f5c6a3d4e_5f000000000000ee');
v1 = jsondecode(jsonencode(v1));
end

function out = runStamped(v1)
out = did2.convert.v1_to_v2({stamp(v1)}, 'Validate', false, 'TargetVersion', 'did_v2');
end

function e = epochEntity(f)
epochType = did2.convert.registeredTerm( ...
    did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch');
e = did2.build.document('entity', ...
    struct('type', epochType, 'local_identifier', f.epoch), ...
    'Id', f.epochId, 'SessionId', f.sid, ...
    'CreationTimestamp', '2024-06-01T12:00:00.000Z', 'Validate', false);
end

function r = roundTrip(f, out)
% the round trip, with the batch the inverse reads the epoch and the
% settings' name from (the epoch entity, the extraction settings document)
docs = structs(out.migrated);
e = epochEntity(f);
m = struct('document_class', struct('class_name', 'spike_extraction_parameters'), ...
    'base', struct('id', f.params, 'name', 'default'));
ctx = context([docs, {e, m}]);
r = did2.convert.roundtrip.check(f.v1, out.migrated, ctx);
end

function ctx = context(docs)
% the shape of did2.convert.roundtrip's private batchContext
ctx = struct('docs', {docs}, ...
    'byId', containers.Map('KeyType', 'char', 'ValueType', 'double'), ...
    'referrers', containers.Map('KeyType', 'char', 'ValueType', 'any'));
for k = 1:numel(docs)
    id = char(docs{k}.base.id);
    if ~isKey(ctx.byId, id); ctx.byId(id) = k; end
    if ~isfield(docs{k}, 'depends_on'); continue; end
    dd = docs{k}.depends_on;
    if iscell(dd); dd = [dd{:}]; end
    for j = 1:numel(dd)
        if strcmp(dd(j).name, 'session_id'); continue; end
        v = '';
        if isfield(dd, 'value'); v = char(dd(j).value); end
        if isempty(v) && isfield(dd, 'document_id'); v = char(dd(j).document_id); end
        if isempty(v); continue; end
        if isKey(ctx.referrers, v)
            ctx.referrers(v) = [ctx.referrers(v), k];
        else
            ctx.referrers(v) = k;
        end
    end
end
end

function p = vswRecordPaths()
p = {'files.file_info(1).locations.uid', 'files.file_info(1).locations.location'};
end

function b = readFile(p)
fid = fopen(p, 'r');
b = reshape(fread(fid, Inf, '*uint8'), 1, []);
fclose(fid);
if isempty(b); b = zeros(1, 0, 'uint8'); end
end

function c = structs(docs)
c = cellfun(@(d) d.toStruct(), docs, 'UniformOutput', false);
end

function d = byId(docs, id)
d = [];
if iscell(id); id = id{1}; end
for k = 1:numel(docs)
    if strcmp(char(docs{k}.base.id), id); d = docs{k}; return; end
end
end

function d = ownedBy(docs, id)
d = [];
for k = 1:numel(docs)
    if strcmp(char(docs{k}.document_class.class_name), 'sampled_body') ...
            && isequal(dep(docs{k}, 'owner_id'), {id})
        d = docs{k};
        return;
    end
end
end

function v = dep(b, name)
v = {};
if ~isfield(b, 'depends_on'); return; end
dd = b.depends_on;
if iscell(dd); dd = [dd{:}]; end
for j = 1:numel(dd)
    if strcmp(dd(j).name, name)
        x = '';
        if isfield(dd, 'value'); x = char(dd(j).value); end
        if isempty(x) && isfield(dd, 'document_id'); x = char(dd(j).document_id); end
        if ~isempty(x); v{end+1} = x; end %#ok<AGROW>
    end
end
end

function s = quarantineText(out)
s = '';
if isempty(out.quarantine); return; end
s = strjoin(arrayfun(@(q) sprintf('%s|%s|%s', q.class_name, q.identifier, q.reason), ...
    out.quarantine, 'UniformOutput', false), '; ');
end
