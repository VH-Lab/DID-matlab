function [v1, spec] = openminds_stimulus(bodies)
%OPENMINDS_STIMULUS The v1 `openminds_stimulus` pass 1 passed through
%   unchanged.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds_stimulus(BODIES). Pass 1
%   passes an `openminds_stimulus` (a stimulation-approach label scoped to an
%   epoch and a stimulator) through unchanged for NDI's second pass
%   (did2.convert.migrators_j.openminds_stimulus), so BODIES is the one
%   passthrough and V1 is it with v1_to_v2's outbound renames undone
%   (passthroughInverse). A document carried whole as v1 (a field outside the
%   template, carry-100) never reaches this inverse
%   (did2.convert.roundtrip.check compares the carry itself).
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.openminds_stimulus.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'openminds_stimulus');
end
