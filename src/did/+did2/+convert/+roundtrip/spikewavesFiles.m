function [vsw, times, problem] = spikewavesFiles(bodies, epochString)
%SPIKEWAVESFILES Rebuild a v1 spikewaves' two files from its v2 bodies.
%
%   [VSW, TIMES, PROBLEM] = did2.convert.roundtrip.spikewavesFiles(BODIES,
%   EPOCHSTRING). BODIES are what did2.convert.migrators_j.spikewaves emitted
%   for one v1 document (structs or did2.document); EPOCHSTRING is the v1
%   `epochid.epochid` (did2.convert.roundtrip.spikewaves rebuilds it). VSW and
%   TIMES are the bytes of `spikewaves.vsw` and `spiketimes.bin` (1xN uint8),
%   read from each body's `body_data_0` location (a local file), byte for
%   byte as NDI's writer wrote them (Jess Haley, 2026-11-10 [spike waveforms
%   built now], D4):
%
%     spiketimes.bin  the spike-times body's bytes, unchanged (the body is
%                     that file)
%     spikewaves.vsw  the 512-byte header did2.convert.spikewavesHeader builds
%                     from what v2 keeps -- numchannels the channel axis's n,
%                     S0 = origin/spacing of the sample axis's time covariate,
%                     S1 = S0 + n - 1, name the spike-times calculation's id
%                     (the v1 id), ref 0, comment EPOCHSTRING, samplingrate
%                     1/spacing written big-endian -- then the body's samples
%                     back in the writer's order (sample fastest, channel,
%                     spike; little-endian, as stored)
%
%   PROBLEM is '' when both rebuilt; otherwise it says what could not be read
%   (VSW / TIMES are then empty).
%
%   See also did2.convert.roundtrip.spikewaves, did2.convert.spikewavesHeader.

vsw = zeros(1, 0, 'uint8');
times = zeros(1, 0, 'uint8');
problem = '';
s = cell(1, numel(bodies));
for k = 1:numel(bodies)
    b = bodies{k};
    if isa(b, 'did2.document'); b = b.toStruct(); end
    s{k} = b;
end
names = cellfun(@classNameOf, s, 'UniformOutput', false);
calcIdx = find(strcmp(names, 'calculation'));
if numel(calcIdx) ~= 2
    problem = sprintf('%d calculations, not 2', numel(calcIdx));
    return;
end
a = s{calcIdx(1)};
b = s{calcIdx(2)};
if any(strcmp(edgeIds(b, 'input_id'), char(a.base.id)))
    timesCalc = a; wavesCalc = b;
else
    timesCalc = b; wavesCalc = a;
end
timesBody = [];
wavesBody = [];
for k = find(strcmp(names, 'sampled_body'))
    owner = edgeIds(s{k}, 'owner_id');
    if isequal(owner, {char(timesCalc.base.id)}); timesBody = s{k}; end
    if isequal(owner, {char(wavesCalc.base.id)}); wavesBody = s{k}; end
end
if isempty(timesBody) || isempty(wavesBody)
    problem = 'a body is missing';
    return;
end
[tb, why] = memberBytes(timesBody);
if isempty(why)
    [wb, why] = memberBytes(wavesBody);
end
if ~isempty(why)
    problem = why;
    return;
end
dims = getIn(wavesBody, 'data', 'dimensions');
covs = getIn(wavesBody, 'data', 'covariates');
if ~isstruct(dims) || numel(dims) ~= 3
    problem = 'the waveform body does not have 3 dimensions';
    return;
end
nSp = double(dims(1).n);
nSamp = double(dims(2).n);
nCh = double(dims(3).n);
origin = [];
spacing = [];
for c = 1:numel(covs)
    cv = covs(c);
    if iscell(covs); cv = covs{c}; end
    al = getIn(cv, 'along');
    if isequal(double(al(:)'), 1) && isfield(cv, 'origin') && isfield(cv, 'spacing')
        origin = numberOf(cv.origin);
        spacing = numberOf(cv.spacing);
    end
end
if isempty(origin) || isempty(spacing) || ~(spacing > 0)
    problem = 'the sample axis has no origin + spacing time covariate';
    return;
end
S0 = round(origin / spacing);
S1 = S0 + nSamp - 1;
rate = did2.convert.spikewavesHeader('rateBytes', 1 / spacing);
h = did2.convert.spikewavesHeader('build', nCh, S0, S1, char(timesCalc.base.id), ...
    epochString, rate);
vsw = [h, did2.convert.spikewavesHeader('fromBody', wb, nSamp, nCh, nSp)];
times = tb;
end

function [bytes, why] = memberBytes(body)
bytes = zeros(1, 0, 'uint8');
why = '';
fi = getIn(body, 'files', 'file_info');
if iscell(fi); fi = [fi{:}]; end
loc = '';
if isstruct(fi) && ~isempty(fi) && isfield(fi, 'locations')
    l = fi(1).locations;
    if iscell(l); l = [l{:}]; end
    if isstruct(l) && ~isempty(l); loc = char(l(1).location); end
end
fid = -1;
if ~isempty(loc); fid = fopen(loc, 'r'); end
if fid < 0
    why = sprintf('body_data_0 of %s is not readable at "%s"', char(body.base.id), loc);
    return;
end
got = fread(fid, Inf, '*uint8');
fclose(fid);
bytes = reshape(got, 1, []);
if isempty(bytes); bytes = zeros(1, 0, 'uint8'); end
end

function v = numberOf(x)
% a covariate's origin/spacing: a number, or a {value, ...} composite
v = [];
if isnumeric(x) && isscalar(x)
    v = double(x);
elseif isstruct(x) && isfield(x, 'value')
    v = double(x.value);
end
end
