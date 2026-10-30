function [v1, spec] = openminds(bodies)
%OPENMINDS The v1 `openminds` document pass 1 passed through unchanged.
%
%   [V1, SPEC] = did2.convert.roundtrip.openminds(BODIES). Pass 1 passes a bare
%   `openminds` document through unchanged (did2.convert.migrators_j.openminds,
%   a guarded passthrough) for did2.convert.resolveOpenmindsCitations and
%   NDI-matlab's strainAssembly, so BODIES is the one passthrough and V1 is it
%   with v1_to_v2's outbound renames undone (passthroughInverse). A document
%   carried whole as v1 (a field outside the template, carry-100) never reaches
%   this inverse (did2.convert.roundtrip.check compares the carry itself). A
%   document a batch pass assembled into entities is not compared here
%   (did2.convert.roundtrip.wholeBatch counts it changed by a batch pass).
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.openminds.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'openminds');
end
