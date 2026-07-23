function corpusDir = ensureCorpus(corpusURL, cacheName, innerDir)
%ENSURECORPUS Download (if necessary) and extract a corpus zip.
%
%   CORPUSDIR = did2.unittest.helpers.ensureCorpus(URL, CACHENAME, INNERDIR)
%   returns <tempdir>/<CACHENAME>/<INNERDIR>, fetching and unzipping
%   URL into the cache on first call so repeated runs in the same
%   MATLAB session reuse the same files.

arguments
    corpusURL (1,:) char
    cacheName (1,:) char
    innerDir  (1,:) char
end

cacheRoot = fullfile(tempdir(), cacheName);
corpusDir = fullfile(cacheRoot, innerDir);
if isfolder(corpusDir) && ~isempty(dir(fullfile(corpusDir, '*.json')))
    return;
end
if ~exist(cacheRoot, 'dir')
    mkdir(cacheRoot);
end
zipPath = fullfile(cacheRoot, [innerDir '.zip']);
if ~isfile(zipPath)
    websave(zipPath, corpusURL);
end
unzip(zipPath, cacheRoot);
end
