function [v1, spec] = spike_clusters(bodies)
%SPIKE_CLUSTERS The v1 `spike_clusters` the migration emitted: always the v1 document itself.
%
%   [V1, SPEC] = did2.convert.roundtrip.spike_clusters(BODIES). Pass 1 carries every
%   v1 `spike_clusters` whole as v1 under a needs-home register row (Decided by Jess
%   Haley, 2026-10-27 [unbuilt spike classes carry as needs home], did-schema
%   V_eta_go_forward_class_audit.md), and did2.convert.roundtrip.check reads a
%   carried document as the v1 document itself, so this inverse is reached
%   only for a body that was NOT carried: it rebuilds a single passed-through
%   document (passthroughInverse) and calls anything else unplaced.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.spike_clusters.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'spike_clusters');
end
