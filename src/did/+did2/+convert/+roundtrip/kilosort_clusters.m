function [v1, spec] = kilosort_clusters(bodies)
%KILOSORT_CLUSTERS Rebuild a v1 `kilosort_clusters` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.kilosort_clusters(BODIES). V1 is the
%   document in NDI's v1 shape (apps/kilosort/kilosort_clusters.json + app.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+fun/+probe/+import/+kilosort/probe.m writes it). BODIES is what
%   +migrators_j/private/jSorterOutput emitted; private/sorterInverse says
%   where each field comes from.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.kilosort_clusters.

arguments
    bodies cell
end

[v1, spec] = sorterInverse(bodies, 'kilosort_clusters', 'kilosort', 'kilosort_directory');
end
