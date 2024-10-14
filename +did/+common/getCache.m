function cache = getCache()
    
    persistent cachedCache
    if isempty(cachedCache)
        cachedCache = did.file.fileCache(did.common.PathConstants.filecachepath, 33);
    end
    cache = cachedCache;
end
