function bodies = sqliteV1(srcPath)
%SQLITEV1 Read raw v1 document JSON bodies from a legacy DID SQLite file.
%
%   BODIES = did2.convert.readers.sqliteV1(SRCPATH) opens the legacy v1
%   DID SQLite database at SRCPATH (the format implemented by
%   did.implementations.sqlitedb), reads every row of the `docs` table,
%   and returns the `json_code` column as a cellstr column vector of
%   raw JSON bodies. Nothing is decoded here; downstream consumers
%   (e.g. did2.convert.v1_to_v2) handle parsing.
%
%   The function is pure-read: it does NOT instantiate
%   did.implementations.sqlitedb (which would run validation, create a
%   cache folder, etc.). The database is opened directly via mksqlite
%   and closed before this function returns.
%
%   Errors:
%     did2:convert:readerFailed   - mksqlite missing, file unreadable,
%                                   or the `docs.json_code` column not
%                                   found in SRCPATH.
%
%   See also: did2.convert.readers.dumbJsonV1,
%             did2.convert.fromV1Database.

arguments
    srcPath (1,:) char
end

if isempty(which('mksqlite'))
    error('did2:convert:readerFailed', ...
        ['mksqlite is required to read a v1 SQLite database. ' ...
         'Install https://github.com/a-ma72/mksqlite and put it on the path.']);
end

if ~isfile(srcPath)
    error('did2:convert:readerFailed', ...
        'v1 sqlite source "%s" does not exist.', srcPath);
end

try
    dbid = mksqlite(0, 'open', srcPath);
catch err
    error('did2:convert:readerFailed', ...
        'Failed to open "%s" as a sqlite database: %s', srcPath, err.message);
end
% Box the handle so the closure sees mutations, then null it out once
% we've explicitly closed (preventing a double-close in the cleanup hook).
handle = struct('id', dbid);
cleanup = onCleanup(@() closeIfOpen(handle)); %#ok<NASGU>

try
    rows = mksqlite(dbid, 'SELECT json_code FROM docs');
catch err
    error('did2:convert:readerFailed', ...
        ['Failed to read docs.json_code from "%s": %s. ' ...
         'Is this a did.implementations.sqlitedb file?'], ...
        srcPath, err.message);
end

if isempty(rows)
    bodies = cell(0, 1);
    return;
end

bodies = cell(numel(rows), 1);
for k = 1:numel(rows)
    body = rows(k).json_code;
    if iscell(body)
        if isempty(body)
            body = '';
        else
            body = body{1};
        end
    end
    if isstring(body)
        body = char(body);
    end
    if isempty(body)
        body = '';
    end
    bodies{k} = body;
end
end

function closeIfOpen(handle)
if ~isempty(handle) && isfield(handle, 'id') && ~isempty(handle.id)
    try
        mksqlite(handle.id, 'close');
    catch
    end
end
end
