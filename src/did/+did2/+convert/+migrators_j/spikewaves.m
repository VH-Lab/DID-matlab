function bodies = spikewaves(preBody)
%SPIKEWAVES Brainstorm-J migrator: did_v1 spikewaves -> TWO `calculation`s on
%   the element, the spike times and the spike waveforms.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THE DECISION. Jess Haley, 2026-11-10 [spike waveforms are two
%   calculations] (did-schema did_v2_go_forward_class_audit.md): a v1
%   `spikewaves` (NDI-matlab +app/spikeextractor.m: one per element per epoch,
%   files `spikewaves.vsw` and `spiketimes.bin`, edges `element_id` and
%   `extraction_parameters_id`) becomes two `calculation`s on the element, both
%   with the extraction settings as their `method`:
%     (1) the spike times, value kind `time`, one entry per spike, in a
%         `sampled_body` ([spike train leaf]);
%     (2) the waveforms, value kind `voltage`, a `sampled_body` with dimensions
%         spike x sample x channel, its spike dimension keyed to (1) ([key
%         covariate index]: a `key` covariate).
%   With [spike waveforms built now] (Jess Haley, 2026-11-10), D1-D6:
%     D1  both take the element's per-epoch recording observation as input,
%         wired by did2.convert.resolveEpochProbemap as [sorter input] is; (2)
%         also takes (1) as input (written here).
%     D2  (1) keeps the v1 id, so spike_clusters.spikewaves_doc_id resolves.
%     D3  the epoch tie is the per-epoch convention: pass 1 DEFERS
%         (did2:convert:needsEpochContext) and did2.convert.epochMint stamps
%         `epoch_id` and re-runs this migrator, which anchors both on the
%         epoch (relative_time_reference, intervalDuring, dev_local_time, as
%         stimulus_response_scalar does).
%     D4  the files are read as raw bytes (did2.convert.v1Files 'readBytes');
%         the waveform body is a NEW file: the .vsw's 512-byte header
%         stripped and its samples reordered spike x sample x channel. The
%         spike-times body IS spiketimes.bin (a plain little-endian float32
%         array, kept as v1 attached it). did2.convert.roundtrip.spikewaves
%         and spikewavesFiles rebuild the document and both files.
%     D5  the header facts: a time covariate on the sample axis (origin S0/fs,
%         spacing 1/fs, seconds); GO:0001508 "action potential" for the
%         variable and the spike axis, om:Time for the sample axis,
%         NCIT:C44170 "Channel" for the channel axis.
%     D6  zero spikes: two calculations with an n = 0 spike axis.
%
%   THE FILES, as NDI's writer makes them (spikeextractor.m extract;
%   vhlab-toolbox-matlab vlt.file.custom_file_formats.newvhlspikewaveformfile
%   and addvhlspikewaveformfile):
%     spikewaves.vsw  a 512-byte header -- numchannels uint8, S0 int8, S1 int8,
%                     name 80 chars (the spikewaves document's id), ref uint8
%                     (0), comment 80 chars (the epoch string), samplingrate
%                     float32 BIG-endian (newvhlspikewaveformfile opens the
%                     file 'b'), zeros to byte 512 -- then each spike's
%                     (S1-S0+1) x numchannels float32 samples, sample fastest,
%                     LITTLE-endian (the writer's fileobj is 'l').
%     spiketimes.bin  one float32 per spike, little-endian (ndi.file.temp_fid
%                     opens 'l'), the spike's time on the element's epoch clock.
%   A header this migrator could not rebuild byte for byte (a name that is not
%   the document's id, a comment that is not its epoch string, a non-zero ref
%   or padding, a non-positive rate or extent), sizes that do not divide, or a
%   count the two files disagree on, carries the document whole as v1: input
%   NDI's writer does not produce.
%
%   A file that cannot be read in this run (did2.convert.v1Files) carries the
%   document whole as v1; a DID-only run with no reader and no local file
%   carries every spikewaves this way, which is a property of the run.
%
%   THE GUARD. A body carrying `num_spikes`, `samples_per_spike` or
%   `sample_rate` is REJECTED BY NAME: DID-side inventions from the V_alpha
%   snapshot, so their presence means a fixture or a caller was built against
%   our schema instead of the real document.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'spikewaves');
if isfield(blk, 'num_spikes') || isfield(blk, 'samples_per_spike') ...
        || isfield(blk, 'sample_rate')
    error('did2:convert:spikewavesInventedShape', ...
        ['spikewaves body carries `num_spikes`/`samples_per_spike`/' ...
         '`sample_rate`, which no did_v1 document has -- the class has exactly ' ...
         'one property field, `extraction_name`, and both counts live in the ' ...
         'spikewaves.vsw binary header. This shape can only come from the ' ...
         'V_alpha snapshot or a fixture built against it.']);
end

% THE RAW READ: every field of the template (spikewaves.json + base, epochid,
% app at the locked NDI-matlab main) is read below; anything else carries.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'spikewaves', {{'extraction_name'}}, ...
    'epochid', {{'epochid'}}, ...
    'app', {{'name', 'version', 'url', 'os', 'os_version', 'interpreter', 'interpreter_version'}}, ...
    'files', {{'file_list', 'file_info'}}), ...
    {'^element_id$', '^extraction_parameters_id$', '^epoch_id$'});

reasons = {};
elementId = jDependency(preBody, 'element_id');
methodId = jDependency(preBody, 'extraction_parameters_id');
if isempty(elementId)
    reasons{end+1} = 'depends_on element_id (empty: no element to state the spikes of)';
end
if isempty(methodId)
    reasons{end+1} = 'depends_on extraction_parameters_id (empty: no extraction settings to be the method)';
end
epochStr = getCharField(getBlock(preBody, 'epochid'), 'epochid');
b = did2.convert.v1read.readBase(preBody);
v1Id = '';
if ischar(b.id); v1Id = b.id; end
if isfield(b, 'name') && ~isempty(b.name)
    % v2 writes no base.name on a statement (#73 item 54); the writer leaves
    % it empty, so a name is not the writer's
    reasons{end+1} = sprintf('base.name (''%s'': the writer writes none, v2 keeps none)', char(b.name));
end

parsed = [];
if isempty(reasons) && isempty(collision) && isempty(unplaced)
    [vsw, okW, whyW] = did2.convert.v1Files('readBytes', preBody, 'spikewaves.vsw');
    [st, okT, whyT] = did2.convert.v1Files('readBytes', preBody, 'spiketimes.bin');
    if ~okW
        reasons{end+1} = sprintf('files spikewaves.vsw (%s)', whyW);
    end
    if ~okT
        reasons{end+1} = sprintf('files spiketimes.bin (%s)', whyT);
    end
    if okW && okT
        [parsed, problem] = parseFiles(vsw, st, v1Id, epochStr);
        if ~isempty(problem)
            reasons{end+1} = sprintf('files spikewaves.vsw/spiketimes.bin (%s)', problem);
        end
    end
end
% carry-register: carry-100; none for the file and header reasons (no
%   register row yet: a spikewaves whose files cannot be read in this run, or
%   whose files are not the writer's shape)
if jRawCarry('spikewaves', src, collision, unplaced, 'carry-100', reasons)
    bodies = {src};   % the carry of the untouched v1 source
    return;
end

% THE EPOCH (D3): the epoch entity epochMint mints; until it exists, defer.
epochDocId = jEpochDocId(preBody);
if ~isempty(epochStr) && isempty(epochDocId)
    error('did2:convert:needsEpochContext', ...
        ['spikewaves "%s" names epoch "%s"; its time anchor is the epoch ' ...
         'entity epochMint mints, so it is deferred to that pass.'], v1Id, epochStr);
end
if ~isempty(epochDocId)
    anchor = did2.build.relativeTimeReference(epochDocId, ...
        'Clock', 'dev_local_time', 'Relation', 'intervalDuring', ...
        'SessionId', jSid(preBody), 'CreationTimestamp', jStamp(preBody), ...
        'Validate', false);
else
    anchor = jSessionAnchor(preBody, 'during');
end

% the software that produced both, and the run's environment
[software, swId, execEnv] = jSoftwareFromApp(preBody);
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
swOpt = {'OperatingSystemId', osId, 'InterpreterId', interpreterId};
if ~isempty(swId); swOpt = [swOpt, {'SoftwareId', swId}]; end

ap = SPIKE_TERM();
[datumType, ~] = jDatumType('float32');

% (1) THE SPIKE TIMES: id preserved (D2)
times = jStatement(preBody, 'calculation', elementId, ap, [], ...
    'ValueKind', 'time', 'DataBody', true, 'DatumType', datumType, ...
    'TimeReferenceIds', {anchor.base.id}, 'MethodId', methodId, swOpt{:}, ...
    'Id', v1Id);
o = jOpts(preBody, 'ByteOrder', 'little');
timesBody = did2.build.sampledBody(times.base.id, ...
    did2.build.dimension(ap, parsed.nSpikes), o{:});
timesBody.files = struct('file_list', {{'body_data_0'}});
fi = fileInfoOf(preBody, 'spiketimes.bin');
fi.name = 'body_data_0';
timesBody.files.file_info = fi;

% (2) THE WAVEFORMS: input (1) (D1), spike axis keyed to (1)
waves = jStatement(preBody, 'calculation', elementId, ap, [], ...
    'ValueKind', 'voltage', 'DataBody', true, 'DatumType', datumType, ...
    'TimeReferenceIds', {anchor.base.id}, 'MethodId', methodId, swOpt{:}, ...
    'InputIds', {times.base.id}, ...
    'Id', did2.convert.mintId('spikewaves waveforms', v1Id));
dims = did2.build.list( ...
    did2.build.dimension(ap, parsed.nSpikes), ...
    did2.build.dimension(TIME_TERM(), parsed.nSamples), ...
    did2.build.dimension(CHANNEL_TERM(), parsed.nChannels));
spacing = 1 / double(parsed.samplingRate);
covs = did2.build.list( ...
    did2.build.covariate(ap, 0, 'Key', 0), ...
    did2.build.covariate(TIME_TERM(), 1, 'Origin', double(parsed.S0) * spacing, ...
        'Spacing', spacing, 'Unit', SECOND()));
o = jOpts(preBody, 'Covariates', covs, 'DatumOrder', 'C', 'ByteOrder', 'little', ...
    'KeyIds', {times.base.id});
wavesBody = did2.build.sampledBody(waves.base.id, dims, o{:});
wavesBody.files = struct('file_list', {{'body_data_0'}});
wavesBody.files.file_info = writeWaveFile(parsed.waveBytes, v1Id);

bodies = [{times, timesBody, waves, wavesBody, anchor}, software, runDocs];
end

% ===================== the files =========================================

function [p, problem] = parseFiles(vsw, st, v1Id, epochStr)
% the writer's two files, read; PROBLEM names what is not the writer's shape
p = [];
problem = '';
if numel(vsw) < 512
    problem = sprintf('spikewaves.vsw holds %d bytes, less than its 512-byte header', numel(vsw));
    return;
end
h = vsw(1:512);
nCh = double(h(1));
S0 = double(typecast(h(2), 'int8'));
S1 = double(typecast(h(3), 'int8'));
fs = did2.convert.spikewavesHeader('rate', h(165:168));
nSamp = S1 - S0 + 1;
if nCh < 1 || nSamp < 1 || ~isfinite(fs) || fs <= 0
    problem = sprintf('header numchannels %d, S0 %d, S1 %d, samplingrate %g', nCh, S0, S1, fs);
    return;
end
% the rate as v2 keeps it (the sample axis's spacing, 1/fs) must give back
% the same four bytes, or the header cannot be rebuilt from it
spacing = 1 / fs;
rateBytes = did2.convert.spikewavesHeader('rateBytes', 1 / spacing);
if ~isequal(rateBytes, h(165:168))
    problem = sprintf('samplingrate %.9g does not rebuild from its sample spacing', fs);
    return;
end
rebuilt = did2.convert.spikewavesHeader('build', nCh, S0, S1, v1Id, epochStr, rateBytes);
if ~isequal(rebuilt, h)
    bad = find(rebuilt ~= h);
    problem = sprintf(['the header is not the one NDI''s writer makes for this document ' ...
        '(name = its id, ref 0, comment = its epoch string, zero padding): ' ...
        'bytes %s differ'], mat2str(bad(1:min(end, 8)) - 1));
    return;
end
perSpike = 4 * nSamp * nCh;
nData = numel(vsw) - 512;
if mod(nData, perSpike) ~= 0
    problem = sprintf('%d waveform bytes are not a whole number of %d-byte spikes', nData, perSpike);
    return;
end
nSp = nData / perSpike;
if mod(numel(st), 4) ~= 0
    problem = sprintf('spiketimes.bin holds %d bytes, not a whole number of float32', numel(st));
    return;
end
if numel(st) / 4 ~= nSp
    problem = sprintf('spiketimes.bin holds %d times for %d waveforms', numel(st) / 4, nSp);
    return;
end
p = struct('nChannels', nCh, 'S0', S0, 'S1', S1, 'nSamples', nSamp, ...
    'samplingRate', fs, 'nSpikes', nSp, ...
    'waveBytes', did2.convert.spikewavesHeader('toBody', vsw(513:end), nSamp, nCh, nSp));
end

function fi = writeWaveFile(bytes, v1Id)
% the waveform body's one member, body_data_0: a new file in the temporary
% folder, ingested when the documents are added (and then deleted), as
% did2.convert.migrationRecord writes its report
key = did2.convert.mintId('spikewaves waveform file', v1Id);
file = fullfile(tempdir, ['did2_spikewaves_' key '.bin']);
fid = fopen(file, 'w');
if fid < 0
    error('did2:convert:spikewavesWrite', 'could not write the waveform body file %s', file);
end
fwrite(fid, bytes, 'uint8');
fclose(fid);
fi = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 1, 'uid', key, 'location', file, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
end

function fi = fileInfoOf(body, name)
% the v1 `file_info` entry naming NAME (v1Files read it, so it exists)
fi = struct('name', name);
if ~isfield(body, 'files') || ~isstruct(body.files) || ~isfield(body.files, 'file_info')
    return;
end
all = body.files.file_info;
if iscell(all); all = [all{:}]; end
for k = 1:numel(all)
    if isfield(all, 'name') && strcmp(char(all(k).name), name)
        fi = all(k);
        return;
    end
end
end

% ===================== terms =============================================

function t = SPIKE_TERM()
% D5: the variable and the spike axis, GO:0001508 "action potential" ([spike
% train variable], the spike-train leaf's variable)
t = did2.convert.registeredTerm('GO:0001508', 'action potential');
end

function t = TIME_TERM()
% D5: the sample axis
t = did2.convert.registeredTerm('om:Time', 'time');
end

function t = CHANNEL_TERM()
% D5: the channel axis
t = did2.convert.registeredTerm('NCIT:C44170', 'Channel');
end

function t = SECOND()
t = struct('node', 'om:second-Time', 'name', 'second');
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end
