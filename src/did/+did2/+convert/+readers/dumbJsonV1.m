function bodies = dumbJsonV1(srcDir)
%DUMBJSONV1 Read raw v1 document JSON bodies from a legacy dumbjsondb tree.
%
%   BODIES = did2.convert.readers.dumbJsonV1(SRCDIR) walks a directory
%   produced by did.file.dumbjsondb (used by did.implementations.matlabdumbjsondb)
%   and returns the JSON document files verbatim as a cellstr column
%   vector. Documents are matched by the on-disk filename pattern
%   `Object_id_*_v<HHHHH>.json`, where the trailing five-hex token is
%   the version. For each unique document id this reader returns only
%   the latest (numerically maximum) version; older versions are
%   ignored so the downstream migrator sees the same document body
%   that did.file.dumbjsondb.read() would have served.
%
%   The reader looks for `.json` files directly under SRCDIR, and also
%   under one level of common subdirectories the dumbjsondb writer
%   uses (e.g. `.dumbjsondb` or `dumbjsondb`). It does NOT recurse
%   beyond that — the v1 layout is intentionally flat.
%
%   Errors:
%     did2:convert:readerFailed   - SRCDIR missing, or a matched file
%                                   could not be read.
%
%   See also: did2.convert.readers.sqliteV1,
%             did2.convert.fromV1Database.

arguments
    srcDir (1,:) char
end

if ~isfolder(srcDir)
    error('did2:convert:readerFailed', ...
        'v1 dumbjsondb source "%s" is not a directory.', srcDir);
end

searchDirs = candidateDirs(srcDir);
matches = struct('name', {}, 'folder', {}, 'id', {}, 'version', {});

for d = 1:numel(searchDirs)
    listing = dir(fullfile(searchDirs{d}, 'Object_id_*_v*.json'));
    for k = 1:numel(listing)
        entry = listing(k);
        if entry.isdir
            continue;
        end
        [id, versionHex] = parseDumbJsonName(entry.name);
        if isempty(id) || isempty(versionHex)
            continue;
        end
        try
            versionNum = hex2dec(versionHex);
        catch
            continue;
        end
        matches(end+1) = struct( ...
            'name',    entry.name, ...
            'folder',  entry.folder, ...
            'id',      id, ...
            'version', versionNum); %#ok<AGROW>
    end
end

if isempty(matches)
    bodies = cell(0, 1);
    return;
end

% Keep only the latest version per id (the dumbjsondb on-disk layout
% retains older versions side-by-side; the public read() returns the
% highest, so we match that).
ids = {matches.id};
[uniqueIds, ~, groupIdx] = unique(ids);
keepIndices = zeros(numel(uniqueIds), 1);
for g = 1:numel(uniqueIds)
    members = find(groupIdx == g);
    versions = [matches(members).version];
    [~, localMax] = max(versions);
    keepIndices(g) = members(localMax);
end
selected = matches(keepIndices);

bodies = cell(numel(selected), 1);
for k = 1:numel(selected)
    fullPath = fullfile(selected(k).folder, selected(k).name);
    try
        bodies{k} = fileread(fullPath);
    catch err
        error('did2:convert:readerFailed', ...
            'Failed to read "%s": %s', fullPath, err.message);
    end
end
end

function dirs = candidateDirs(root)
% The dumbjsondb writer stores docs in <paramfile_dir>/<dirname>/.
% Callers typically pass either the paramfile directory or the inner
% data directory; accept both shapes plus the two common dirnames.
dirs = {root};
inner = {'.dumbjsondb', 'dumbjsondb'};
for k = 1:numel(inner)
    candidate = fullfile(root, inner{k});
    if isfolder(candidate)
        dirs{end+1} = candidate; %#ok<AGROW>
    end
end
end

function [id, versionHex] = parseDumbJsonName(filename)
id = '';
versionHex = '';
tokens = regexp(filename, '^Object_id_(.+)_v([0-9A-Fa-f]+)\.json$', ...
    'tokens', 'once');
if isempty(tokens)
    return;
end
id = tokens{1};
versionHex = tokens{2};
end
