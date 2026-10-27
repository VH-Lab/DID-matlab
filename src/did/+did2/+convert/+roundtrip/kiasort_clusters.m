function [v1, spec] = kiasort_clusters(bodies)
%KIASORT_CLUSTERS Rebuild a v1 `kiasort_clusters` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.kiasort_clusters(BODIES). V1 is the
%   document in NDI's v1 shape (apps/kiasort/kiasort_clusters.json + app.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+fun/+probe/+import/+kiasort/probe.m writes it). BODIES is what
%   +migrators_j/private/jSorterOutput emitted; private/sorterInverse says
%   where each field comes from.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.kiasort_clusters.

arguments
    bodies cell
end

[v1, spec] = sorterInverse(bodies, 'kiasort_clusters', 'kiasort', 'kiasort_directory');
end
