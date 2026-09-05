function writeSeriesManifest(filename, uids, options)
% WRITESERIESMANIFEST - write a file series manifest (format version 1)
%
% did.file.WRITESERIESMANIFEST(FILENAME, UIDS)
% did.file.WRITESERIESMANIFEST(FILENAME, UIDS, 'sourceNames', NAMES)
%
% Writes the manifest that indexes a file series' members by their
% zero-based index. See docs/notes/file_series_manifest.md for the layout.
%
% Inputs:
%   FILENAME - where to write
%   UIDS     - cellstr, one entry per member SLOT. Entry i (one-based here,
%              member i-1 on disk) is that member's uid, or '' when the
%              member is absent. A series is sparse -- a zarr level never
%              writes an all-fill chunk -- so absent slots are expected,
%              not an error.
%
% Optional Name-Value Arguments:
%   sourceNames ({}) - cellstr the same length as UIDS, each the member's
%       source path RELATIVE to the series' source_root. Pass {} to record
%       none. Absolute paths do not belong here: they leak a directory
%       layout when a document is shared, and the root lives in one
%       document field precisely so it can be redacted once.
%   uidWidth (33)    - bytes per uid record. 33 fits did.ido.unique_id.
%
% A uid wider than UIDWIDTH is an error rather than a silent truncation:
% uids are not all minted by did.ido.unique_id, and a truncated uid would
% resolve to the wrong file or to none, discovered much later.
%
% See also: did.file.readSeriesManifest, did.file.isSafeUid

arguments
    filename (1,:) char
    uids cell
    options.sourceNames cell = {}
    options.uidWidth (1,1) {mustBePositive, mustBeInteger} = 33
end

n = numel(uids);
haveNames = ~isempty(options.sourceNames);

if haveNames && numel(options.sourceNames) ~= n
    error('DID:FileSeries:writeSeriesManifest:lengthMismatch', ...
        ['sourceNames must have one entry per member slot (%d), not %d. ' ...
         'A member with no recorded name takes an empty entry.'], ...
        n, numel(options.sourceNames));
end

% Build the uid block: fixed-width, NUL-padded. An absent member is all-NUL,
% which no real uid can collide with because isSafeUid rejects NUL.
uidBlock = zeros(options.uidWidth, n, 'uint8');
for i = 1:n
    thisUid = uids{i};
    % Convert BEFORE testing emptiness. isempty("") is FALSE -- a string
    % scalar holding no characters is still 1-by-1 -- so checking first
    % would send an empty string down the non-absent path, where it only
    % happens to work because a zero-length write leaves the slot all-NUL.
    % The source-name loop below already converts first; these must agree.
    if isstring(thisUid) && isscalar(thisUid)
        thisUid = char(thisUid);
    end
    if isempty(thisUid)
        continue    % absent member: leave the slot all-NUL
    end
    if ~ischar(thisUid)
        error('DID:FileSeries:writeSeriesManifest:badUid', ...
            'Member %d has a uid that is neither char nor a string scalar.', i-1);
    end
    if numel(thisUid) > options.uidWidth
        error('DID:FileSeries:writeSeriesManifest:uidTooWide', ...
            ['Member %d has a %d-character uid, wider than uidWidth (%d). ' ...
             'Raise uidWidth rather than truncating: a truncated uid ' ...
             'resolves to the wrong file or to none.'], ...
            i-1, numel(thisUid), options.uidWidth);
    end
    uidBlock(1:numel(thisUid), i) = uint8(thisUid);
end

% Build the optional name section.
nameBytes = uint8([]);
nameOffset = zeros(1, n+1, 'uint32');
if haveNames
    parts = cell(1, n);
    for i = 1:n
        thisName = options.sourceNames{i};
        if isstring(thisName) && isscalar(thisName)
            thisName = char(thisName);
        end
        if isempty(thisName)
            parts{i} = uint8([]);
        else
            parts{i} = uint8(unicode2native(thisName, 'UTF-8'));
        end
        nameOffset(i+1) = nameOffset(i) + uint32(numel(parts{i}));
    end
    nameBytes = [parts{:}];
end

flags = uint32(0);
if haveNames
    flags = bitset(flags, 1);   % bit 0, one-based in bitset
end

fid = fopen(filename, 'w', 'ieee-le');
if fid < 0
    error('DID:FileSeries:writeSeriesManifest:cannotOpen', ...
        'Could not open ''%s'' for writing.', filename);
end
closer = onCleanup(@() fclose(fid));

fwrite(fid, uint8('DIDFSER1'), 'uint8');
fwrite(fid, uint32(1), 'uint32');                 % format_version
fwrite(fid, flags, 'uint32');
fwrite(fid, uint32(n), 'uint32');                 % count
fwrite(fid, uint32(options.uidWidth), 'uint32');  % uid_width
fwrite(fid, zeros(1,2,'uint32'), 'uint32');       % reserved
fwrite(fid, uidBlock(:), 'uint8');

if haveNames
    fwrite(fid, nameOffset, 'uint32');
    if ~isempty(nameBytes)
        fwrite(fid, nameBytes, 'uint8');
    end
end

end
