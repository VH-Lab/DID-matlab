function cache = getCache(action)
% GETCACHE - return the DID file-cache singleton
%
% CACHE = did.common.getCache()
% CACHE = did.common.getCache('reset')
%
% Returns the process-wide did.file.fileCache singleton. With no
% argument the cached handle is reused across the MATLAB session, so
% every DID call sees the same catalog and the same lock state.
%
% With 'reset', the persistent handle is cleared before returning a
% freshly constructed cache. Use this to recover from a poisoned
% in-memory state (a stuck hasLock, a stale fileobj descriptor) without
% ending the MATLAB session -- the equivalent of "clear
% did.common.getCache" from user code, but callable programmatically.
% The on-disk cache contents are not touched; only the singleton's
% memoization is discarded.

    arguments
        action (1,:) char {mustBeMember(action, {'', 'reset'})} = ''
    end

    persistent cachedCache
    if strcmp(action, 'reset')
        cachedCache = [];
    end
    if isempty(cachedCache)
        cachedCache = did.file.fileCache(did.common.PathConstants.filecachepath, 33);
    end
    cache = cachedCache;
end
