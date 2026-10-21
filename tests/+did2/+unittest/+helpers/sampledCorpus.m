function [corpusDir, manifest] = sampledCorpus(innerDir)
%SAMPLEDCORPUS The SAMPLED copy of a corpus, when this run asked for one.
%
%   [CORPUSDIR, MANIFEST] = did2.unittest.helpers.sampledCorpus(INNERDIR)
%   returns '' and [] when the environment variable DID_CORPUS_SAMPLE_DIR is
%   unset or empty: the run is a FULL corpus run and nothing changes.
%
%   When it is set (test-corpus.yml does this for a `sample: true` dispatch),
%   returns <DID_CORPUS_SAMPLE_DIR>/<INNERDIR>, the whole-session sample that
%   tools/sample_corpus.py wrote, and its manifest
%   <DID_CORPUS_SAMPLE_DIR>/<INNERDIR>.sample.json (without the file list).
%
%   A REQUESTED SAMPLE THAT IS MISSING IS AN ERROR, never a quiet fallback to
%   the full corpus: a run labelled sampled that measured the whole corpus, or
%   one labelled full that measured a sample, would be reporting a different
%   denominator from the one its log claims.

corpusDir = '';
manifest = [];
root = getenv('DID_CORPUS_SAMPLE_DIR');
if isempty(strtrim(root))
    return;
end
corpusDir = fullfile(root, innerDir);
manifestPath = fullfile(root, [innerDir '.sample.json']);
if ~isfolder(corpusDir) || ~isfile(manifestPath)
    error('did2:test:sampleMissing', ...
        ['DID_CORPUS_SAMPLE_DIR=%s asks for a SAMPLED run, but %s or %s is ' ...
         'missing. Refusing to fall back to the full corpus.'], ...
        root, corpusDir, manifestPath);
end
manifest = jsondecode(fileread(manifestPath));
if isfield(manifest, 'kept_files')
    manifest = rmfield(manifest, 'kept_files');
end
fprintf(['SAMPLED corpus %s: %d of %d doc(s), %d of %d session(s), ' ...
         'classes covered %d of %d (manifest %s)\n'], innerDir, ...
    manifest.docs_kept, manifest.docs_in_corpus, manifest.sessions_kept, ...
    manifest.sessions_in_corpus, manifest.classes_covered, ...
    manifest.classes_in_corpus, manifestPath);
end
