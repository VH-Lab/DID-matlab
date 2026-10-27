function [v1, spec] = vmspikesummary(bodies)
%VMSPIKESUMMARY Rebuild a v1 `vmspikesummary` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.vmspikesummary(BODIES). Pass 1 passes the
%   document through unchanged (did2.convert.migrators_j.vmspikesummary), so BODIES is
%   that one passthrough and V1 is it with v1_to_v2's outbound renames undone
%   (private/passthroughInverse).
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'vmspikesummary');
end
