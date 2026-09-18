function [uid, count] = readSeriesManifestUid(filename, slot)
% READSERIESMANIFESTUID - one member's uid from a series manifest, in O(1)
%
% [UID, COUNT] = did.file.READSERIESMANIFESTUID(FILENAME, SLOT)
%
% Returns the uid recorded for member SLOT of the manifest FILENAME, or ''
% when that member is absent or SLOT lies outside the manifest. COUNT is the
% number of member slots the manifest declares, whether or not SLOT is one
% of them.
%
% SLOT is the same one-based index that addresses MANIFEST.uids in
% did.file.readSeriesManifest -- that is, member SLOT-1 in the file's own
% zero-based numbering, and the member named NAME_<SLOT> in a document.
%
% WHY THIS EXISTS. did.file.readSeriesManifest reads the whole manifest:
% every uid, and every source name. That is what an inspector or an
% uploader wants. Resolving ONE member does not want it -- the uid block is
% a fixed-width array, so member SLOT sits at a known offset and costs one
% seek and UIDWIDTH bytes. For a lightsheet pyramid level the difference is
% 33 bytes against ~924 KB, paid once per member read rather than once per
% series. That O(1) index is the property the manifest format was chosen
% for (VH-Lab/DID-matlab#173); reading the array whole to use one entry of
% it would give it away.
%
% The source-name section is never touched here. It is provenance, and it
% is the part of the manifest whose size is unbounded.
%
% The header is validated exactly as did.file.readSeriesManifest validates
% it, and the same conditions raise the same error NAMES under this
% function's own identifier prefix (badMagic, badVersion, badUidWidth,
% truncated), so a caller can handle either reader the same way.
%
% See also: did.file.readSeriesManifest, did.file.writeSeriesManifest

arguments
    filename (1,:) char {mustBeFile}
    slot (1,1) double {mustBePositive, mustBeInteger}
end

uid = '';
count = 0;

fid = fopen(filename, 'r', 'ieee-le');
if fid < 0
    % See the same branch in did.file.readSeriesManifest: mustBeFile above
    % already rejects a missing path, so reaching this needs an existing
    % file the process cannot read.
    error('DID:FileSeries:readSeriesManifestUid:cannotOpen', ...
        'Could not open ''%s'' for reading.', filename);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>

magic = fread(fid, 8, '*uint8')';
if numel(magic) < 8 || ~isequal(char(magic), 'DIDFSER1')
    error('DID:FileSeries:readSeriesManifestUid:badMagic', ...
        '''%s'' is not a file series manifest (magic is ''%s'').', ...
        filename, char(magic));
end

formatVersion = fread(fid, 1, '*uint32');
if isempty(formatVersion)
    error('DID:FileSeries:readSeriesManifestUid:truncated', ...
        '''%s'' ends before its header is complete.', filename);
end
if formatVersion ~= 1
    error('DID:FileSeries:readSeriesManifestUid:badVersion', ...
        ['''%s'' declares manifest format version %d; this reader ' ...
         'understands version 1.'], filename, double(formatVersion));
end

fread(fid, 1, '*uint32');                    % flags: the name section is not read here
count    = fread(fid, 1, '*uint32');
uidWidth = fread(fid, 1, '*uint32');
fread(fid, 2, '*uint32');                    % reserved

if isempty(count) || isempty(uidWidth)
    error('DID:FileSeries:readSeriesManifestUid:truncated', ...
        '''%s'' ends before its header is complete.', filename);
end
count    = double(count);
uidWidth = double(uidWidth);

if uidWidth < 1
    error('DID:FileSeries:readSeriesManifestUid:badUidWidth', ...
        '''%s'' declares uid_width %d.', filename, uidWidth);
end

if slot > count
    % Not an error: a sparse series is asked about slots it does not have,
    % and "no such member" is an answer the caller acts on.
    return
end

% The uid block starts at byte 32 and member SLOT-1 sits UIDWIDTH bytes per
% member into it. See docs/notes/file_series_manifest.md.
if fseek(fid, 32 + (slot-1)*uidWidth, 'bof') ~= 0
    error('DID:FileSeries:readSeriesManifestUid:truncated', ...
        '''%s'' declares %d members but is too short to hold member %d.', ...
        filename, count, slot);
end

record = fread(fid, uidWidth, '*uint8')';
if numel(record) < uidWidth
    error('DID:FileSeries:readSeriesManifestUid:truncated', ...
        '''%s'' declares %d members but holds only %d bytes of member %d.', ...
        filename, count, numel(record), slot);
end

record = record(record ~= 0);   % strip the NUL padding; all-NUL means absent
if ~isempty(record)
    uid = char(record);
end

end
