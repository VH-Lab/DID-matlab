function [v1, spec] = spatialGeneExpressionTiles(bodies)
%SPATIALGENEEXPRESSIONTILES Rebuild a v1 `spatialGeneExpressionTiles` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.spatialGeneExpressionTiles(BODIES). Pass 1 passes the
%   document through unchanged under its v1 class name (did2.convert.rawV1Classes
%   joins `spatialGeneExpressionTiles` to its +migrators_j migrator), so BODIES is that one
%   passthrough and V1 is it with v1_to_v2's outbound renames undone
%   (private/passthroughInverse).
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'spatialGeneExpressionTiles');
end
