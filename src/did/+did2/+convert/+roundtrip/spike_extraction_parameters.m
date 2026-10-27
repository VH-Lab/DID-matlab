function [v1, spec] = spike_extraction_parameters(bodies)
%SPIKE_EXTRACTION_PARAMETERS Rebuild a v1 `spike_extraction_parameters` from
%   what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.spike_extraction_parameters(BODIES). V1
%   is the document in NDI's v1 shape (apps/spikeextractor/
%   spike_extraction_parameters.json + app.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as ndi.app.spikeextractor struct2doc writes
%   it). BODIES holds the `method` (id preserved) and its software entity
%   (private/methodDocParts, private/spikeExtractionBlock):
%
%     base.id, session_id, datestamp   the method's
%     base.name                        the method's name
%     app.name, version, url           the software entity
%     refractory_time                  parameter "refractory period"
%     spike_start_time                 parameter "waveform window start"
%     spike_end_time                   start + parameter "waveform window
%                                      duration" (the migrator stores the
%                                      extent; a sum that does not give back
%                                      the v1 number exactly is reported lost)
%     threshold_method,                parameter "standard-deviation threshold"
%       threshold_parameter            ('standard_deviation') or "absolute
%                                      voltage threshold" ('absolute')
%     filter_*, do_filter              the bag's `filter.*` entries
%     the other fields                 the bag
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.spike_extraction_parameters.

arguments
    bodies cell
end

CLASS = 'spike_extraction_parameters';
[v1, entries, spec] = methodDocParts(bodies, CLASS, struct('entity_id', 'element_id'));
if isempty(fieldnames(v1))
    return;
end
[blk, v1, bad] = spikeExtractionBlock(entries, v1);
spec.unplaced = [spec.unplaced, bad];
v1.(CLASS) = blk;
end
