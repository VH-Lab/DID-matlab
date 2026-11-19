function out = spikewavesHeader(action, varargin)
%SPIKEWAVESHEADER The bytes of NDI's spike waveform file (.vsw), both ways.
%
%   One place for the byte layout that did2.convert.migrators_j.spikewaves
%   reads and did2.convert.roundtrip.spikewavesFiles writes back (Jess Haley,
%   2026-11-10 [spike waveforms built now], D4/D5). The layout is NDI's
%   writer's: vhlab-toolbox-matlab vlt.file.custom_file_formats.
%   newvhlspikewaveformfile writes a 512-byte header (the file opened
%   BIG-endian), and NDI-matlab +app/spikeextractor.m appends each spike's
%   samples through a LITTLE-endian fileobj (addvhlspikewaveformfile):
%
%       byte 0        numchannels   uint8
%       byte 1        S0            int8   samples before the spike centre
%       byte 2        S1            int8   samples after it
%       bytes 3-82    name          80 chars, zero-padded (the document id)
%       byte 83       ref           uint8  (0)
%       bytes 84-163  comment       80 chars, zero-padded (the epoch string)
%       bytes 164-167 samplingrate  float32, big-endian
%       bytes 168-511 zeros
%       then, per spike, (S1-S0+1) x numchannels float32, sample fastest,
%       little-endian.
%
%   FS = did2.convert.spikewavesHeader('rate', B4)   the rate four header
%       bytes hold (big-endian float32), as a double
%   B4 = did2.convert.spikewavesHeader('rateBytes', FS)   FS as those bytes
%   H = did2.convert.spikewavesHeader('build', NCH, S0, S1, NAME, COMMENT, B4)
%       the 512 header bytes the writer writes (NAME and COMMENT cut to 80
%       characters, as newvhlspikewaveformfile cuts them)
%   B = did2.convert.spikewavesHeader('toBody', DATA, NSAMP, NCH, NSPIKES)
%       the .vsw's sample bytes (after the header) reordered as the body's
%       array, dimensions spike x sample x channel in C order (channel
%       fastest); the bytes of each float32 are kept as they are
%       (little-endian), never converted
%   DATA = did2.convert.spikewavesHeader('fromBody', B, NSAMP, NCH, NSPIKES)
%       the inverse of 'toBody'
%
%   See also did2.convert.migrators_j.spikewaves,
%   did2.convert.roundtrip.spikewavesFiles.

switch action
    case 'rate'
        b = uint8(varargin{1}(:)');
        out = double(typecast(fliplr(b), 'single'));   % big-endian -> native
        if littleEndianHost()
            return;
        end
        out = double(typecast(b, 'single'));
    case 'rateBytes'
        b = typecast(single(varargin{1}), 'uint8');
        if littleEndianHost()
            b = fliplr(b);
        end
        out = reshape(b, 1, []);
    case 'build'
        [nCh, S0, S1, name, comment, b4] = varargin{:};
        out = zeros(1, 512, 'uint8');
        out(1) = uint8(nCh);
        out(2) = typecast(int8(S0), 'uint8');
        out(3) = typecast(int8(S1), 'uint8');
        out(4:83) = padded(name);
        out(84) = 0;
        out(85:164) = padded(comment);
        out(165:168) = uint8(b4(:)');
    case 'toBody'
        [data, nSamp, nCh, nSp] = varargin{:};
        a = reshape(uint8(data(:)), 4, nSamp, nCh, nSp);   % byte, sample, channel, spike
        a = permute(a, [1 3 2 4]);                         % byte, channel, sample, spike
        out = reshape(a, 1, []);
    case 'fromBody'
        [data, nSamp, nCh, nSp] = varargin{:};
        a = reshape(uint8(data(:)), 4, nCh, nSamp, nSp);
        a = permute(a, [1 3 2 4]);
        out = reshape(a, 1, []);
    otherwise
        error('did2:convert:spikewavesHeader:action', 'unknown action "%s"', action);
end
end

function b = padded(text)
text = char(text);
if numel(text) > 80
    text = text(1:80);
end
b = zeros(1, 80, 'uint8');
b(1:numel(text)) = uint8(text);
end

function tf = littleEndianHost()
[~, ~, e] = computer();
tf = strcmp(e, 'L');
end
