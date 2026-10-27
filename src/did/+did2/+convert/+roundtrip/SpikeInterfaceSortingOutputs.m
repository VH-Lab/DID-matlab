function [v1, spec] = SpikeInterfaceSortingOutputs(bodies)
%SPIKEINTERFACESORTINGOUTPUTS Rebuild a v1 `SpikeInterfaceSortingOutputs`
%   from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.SpikeInterfaceSortingOutputs(BODIES).
%   V1 is the document in NDI's v1 shape
%   (sorting/SpikeInterfaceSortingOutputs.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8; no writer at that `main` constructs one).
%   Pass 1 passes the document through unchanged
%   (did2.convert.migrators_j.spike_interface_sorting_outputs), so BODIES is
%   that one passthrough: V1 is it with v1_to_v2's outbound renames undone
%   (the session edge back to base.session_id, creation_timestamp back to
%   base.datestamp). Anything else is unplaced.
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), 'SpikeInterfaceSortingOutputs')
    v1 = undoOutbound(bodies{1});
    return;
end
spec.unplaced{end+1} = sprintf(['%d emitted document(s); pass 1 passes a ' ...
    'SpikeInterfaceSortingOutputs through as one'], numel(bodies));
end
