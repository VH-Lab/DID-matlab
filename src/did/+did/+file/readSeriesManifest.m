function manifest = readSeriesManifest(filename)
% READSERIESMANIFEST - read a file series manifest (format version 1)
%
% MANIFEST = did.file.READSERIESMANIFEST(FILENAME)
%
% Reads the manifest that indexes a file series' members by their
% zero-based index. See docs/notes/file_series_manifest.md for the layout.
%
% Outputs:
%   MANIFEST - a structure with fields:
%       count       - number of member slots
%       uidWidth    - bytes per uid record, as the file declares
%       uids        - 1-by-count cellstr. Entry i is member i-1's uid, or
%                     '' when that member is absent.
%       sourceNames - 1-by-count cellstr of source paths RELATIVE to the
%                     series' source_root, or {} when the file records
%                     none. An individual member with no name has ''.
%       hasSourceNames - whether the name section was present
%
% Member indices are ZERO-BASED on disk and are deliberately NOT converted
% to MATLAB's one-based convention here: the same file is read by
% DID-python, and shifting indices on one side only is the likeliest way
% for the two to disagree. Convert at the point of use.
%
% See also: did.file.writeSeriesManifest

arguments
    filename (1,:) char {mustBeFile}
end

fid = fopen(filename, 'r', 'ieee-le');
if fid < 0
    error('DID:FileSeries:readSeriesManifest:cannotOpen', ...
        'Could not open ''%s'' for reading.', filename);
end
closer = onCleanup(@() fclose(fid));

magic = fread(fid, 8, '*uint8')';
if numel(magic) < 8 || ~isequal(char(magic), 'DIDFSER1')
    error('DID:FileSeries:readSeriesManifest:badMagic', ...
        '''%s'' is not a file series manifest (magic is ''%s'').', ...
        filename, char(magic));
end

formatVersion = fread(fid, 1, '*uint32');
if formatVersion ~= 1
    error('DID:FileSeries:readSeriesManifest:badVersion', ...
        ['''%s'' declares manifest format version %d; this reader ' ...
         'understands version 1.'], filename, formatVersion);
end

flags    = fread(fid, 1, '*uint32');
count    = double(fread(fid, 1, '*uint32'));
uidWidth = double(fread(fid, 1, '*uint32'));
fread(fid, 2, '*uint32');   % reserved

if uidWidth < 1
    error('DID:FileSeries:readSeriesManifest:badUidWidth', ...
        '''%s'' declares uid_width %d.', filename, uidWidth);
end

if count == 0
    uidBlock = zeros(uidWidth, 0, 'uint8');   % fread([w 0]) is a degenerate size
else
    uidBlock = fread(fid, [uidWidth count], '*uint8');
end
if size(uidBlock,2) < count
    error('DID:FileSeries:readSeriesManifest:truncated', ...
        ['''%s'' declares %d members but holds only %d uid records; ' ...
         'the file is truncated.'], filename, count, size(uidBlock,2));
end

uids = cell(1, count);
for i = 1:count
    thisUid = uidBlock(:,i)';
    thisUid = thisUid(thisUid ~= 0);   % strip the NUL padding
    if isempty(thisUid)
        uids{i} = '';                  % absent member
    else
        uids{i} = char(thisUid);
    end
end

hasSourceNames = bitget(flags, 1) == 1;
sourceNames = {};

if hasSourceNames
    nameOffset = fread(fid, count+1, '*uint32');
    if numel(nameOffset) < count+1
        error('DID:FileSeries:readSeriesManifest:truncated', ...
            ['''%s'' declares source names but its offset table is ' ...
             'truncated (%d of %d entries).'], ...
            filename, numel(nameOffset), count+1);
    end
    nameOffset = double(nameOffset);
    nameBytes = fread(fid, nameOffset(end), '*uint8')';
    if numel(nameBytes) < nameOffset(end)
        error('DID:FileSeries:readSeriesManifest:truncated', ...
            ['''%s'' declares %d bytes of source names but holds %d.'], ...
            filename, nameOffset(end), numel(nameBytes));
    end
    sourceNames = cell(1, count);
    for i = 1:count
        % Compare the ZERO-BASED offsets directly. Converting to a
        % one-based index first and comparing after is what makes an empty
        % name (equal offsets) look like a decreasing one: it lands on
        % last == first-1, which also satisfies last < first.
        firstOffset = nameOffset(i);      % inclusive
        lastOffset  = nameOffset(i+1);    % exclusive
        if lastOffset < firstOffset
            error('DID:FileSeries:readSeriesManifest:badOffsets', ...
                ['''%s'' has a decreasing name offset at member %d; ' ...
                 'offsets must be non-decreasing.'], filename, i-1);
        elseif lastOffset == firstOffset
            sourceNames{i} = '';          % member with no recorded name
        else
            sourceNames{i} = native2unicode( ...
                nameBytes(firstOffset+1 : lastOffset), 'UTF-8');
        end
    end
end

manifest = struct('count', count, ...
    'uidWidth', uidWidth, ...
    'uids', {uids}, ...
    'sourceNames', {sourceNames}, ...
    'hasSourceNames', hasSourceNames);

end
