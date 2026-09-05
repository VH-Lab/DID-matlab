function filePath = cachedPathForUid(uid, options)
% CACHEDPATHFORUID - local path of a file already on disk, with NO database lookup
%
% FILEPATH = did.file.CACHEDPATHFORUID(UID)
% FILEPATH = did.file.CACHEDPATHFORUID(UID, 'additionalRoots', {DIR1, DIR2, ...})
%
% Returns the full path of the file stored under UID, or '' if no such file
% is on disk. UID values that are unsafe as a basename are refused (see
% did.file.isSafeUid).
%
% WHY THIS EXISTS. Both roots a DID file can live in are named by the file's
% uid: the global file cache at did.common.PathConstants.filecachepath, and a
% database's own FileDir. did.database/open_doc and check_exist_doc already
% build exactly these candidates -- but they run a SQL query first, purely to
% learn the uid. A caller that already holds the did.document holds the uid
% too (document_properties.files.file_info(i).locations(j).uid), so for that
% caller the query is pure overhead.
%
% Avoiding it is not only faster. A SQLite connection belongs to the thread
% that opened it, so any resolution that goes through the database must run
% on the thread that owns the session. This function touches no database and
% no network, so it is safe to call from ANY thread and from any process --
% which is what lets a viewer resolve many files in parallel without holding
% a session per worker.
%
% Optional Name-Value Arguments:
%   additionalRoots ({}) - further directories to search, in order, AFTER the
%       global file cache. did.database/cachedPathForFile passes the
%       database's own file root here. The order matches
%       did.implementations.sqlitedb/do_open_doc, which prefers the global
%       cache: a file retrieved from a remote location once is kept there, so
%       a second open of the same document does not fetch it again.
%
% Example:
%   p = did.file.cachedPathForUid(uid, 'additionalRoots', {myDb.FileDir});
%
% See also: did.file.isSafeUid, did.database/cachedPathForFile

arguments
    uid
    options.additionalRoots (1,:) cell = {}
end

filePath = '';

if ~did.file.isSafeUid(uid)
    return
end
uid = char(uid);

roots = [{did.common.PathConstants.filecachepath}, options.additionalRoots];

for i = 1:numel(roots)
    thisRoot = roots{i};
    if isstring(thisRoot) && isscalar(thisRoot)
        thisRoot = char(thisRoot);
    end
    if isempty(thisRoot) || ~ischar(thisRoot)
        continue
    end
    candidate = fullfile(thisRoot, uid);
    if isfile(candidate)
        filePath = candidate;
        return
    end
end
end
