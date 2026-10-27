function [v1, spec] = cellTypeLabels(bodies)
%CELLTYPELABELS Rebuild a v1 `cellTypeLabels` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.cellTypeLabels(BODIES). Pass 1 passes the
%   document through unchanged under its v1 class name (did2.convert.rawV1Classes
%   joins `cellTypeLabels` to its +migrators_j migrator), so BODIES is that one
%   passthrough and V1 is it with v1_to_v2's outbound renames undone
%   (private/passthroughInverse).
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'cellTypeLabels');
end
