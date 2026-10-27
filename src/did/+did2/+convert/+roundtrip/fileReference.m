function [v1, spec] = fileReference(bodies)
%FILEREFERENCE Rebuild a v1 `fileReference` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.fileReference(BODIES). Pass 1 passes
%   the document through unchanged under its v1 class name
%   (did2.convert.rawV1Classes joins `fileReference` to its +migrators_j
%   migrator), so BODIES is that one passthrough and V1 is it with v1_to_v2's
%   outbound renames undone (private/passthroughInverse). A record a lightsheet
%   pyramid names is folded later, by did2.convert.foldGenericFiles, which this
%   inverse does not see.
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'fileReference');
end
