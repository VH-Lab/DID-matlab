function [v1, spec] = daqreader_image_epochdata_ingested(bodies)
%DAQREADER_IMAGE_EPOCHDATA_INGESTED Rebuild a v1 `daqreader_image_epochdata_ingested` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqreader_image_epochdata_ingested(BODIES). Pass 1 passes the
%   document through unchanged (did2.convert.migrators_j.daqreader_image_epochdata_ingested), so BODIES is
%   that one passthrough and V1 is it with v1_to_v2's outbound renames undone
%   (private/passthroughInverse).
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'daqreader_image_epochdata_ingested');
end
