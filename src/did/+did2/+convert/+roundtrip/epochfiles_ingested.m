function [v1, spec] = epochfiles_ingested(bodies)
%EPOCHFILES_INGESTED Rebuild a v1 `epochfiles_ingested` from what pass 1 made
%   of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.epochfiles_ingested(BODIES). V1 is the
%   manifest in NDI's v1 shape (epochfiles_ingested.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+file/navigator.m writes it:
%   epoch_id, files, epochprobemap and the filenavigator_id edge). BODIES is
%   the pass-1 passthrough, one `epochfiles_ingested` document as v1_to_v2
%   padded and stamped it: the document itself, its session edge read back into
%   base.session_id and its creation_timestamp into base.datestamp.
%
%   THIS IS THE PASS-1 ROUND TRIP. The batch passes (epochMint,
%   resolveEpochProbemap) then decompose the manifest into an
%   ingestion_manifest, observations and data bodies when every probe-map row
%   has a home; that decomposition is not inverted here.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.epochfiles_ingested.

arguments
    bodies cell
end

CLASS = 'epochfiles_ingested';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
for k = 1:numel(bodies)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the pass-1 passthrough', ...
        k, classNameOf(bodies{k}));
end
if isempty(bodies)
    spec.unplaced{end+1} = 'nothing was emitted';
end
end
