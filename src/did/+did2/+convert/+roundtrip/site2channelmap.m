function [v1, spec] = site2channelmap(bodies)
%SITE2CHANNELMAP Rebuild a v1 `site2channelmap` from what the migration made
%   of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.site2channelmap(BODIES). V1 is the
%   document in NDI's v1 shape (probe/site2channelmap.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+fun/+probe/+geometry/fromStruct.m
%   writes it). Pass 1 passes the document through unchanged (the wiring needs
%   the probe_geometry's site order, which the NDI second pass joins), so BODIES
%   is that one passthrough: V1 is it with v1_to_v2's outbound renames undone
%   (the session edge back to base.session_id, creation_timestamp back to
%   base.datestamp). Anything else is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.site2channelmap.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'site2channelmap')
    v1 = undoOutbound(bodies{1});
    return;
end
spec.unplaced{end+1} = sprintf(['%d emitted document(s); pass 1 passes a site2channelmap ' ...
    'through as one'], numel(bodies));
end
