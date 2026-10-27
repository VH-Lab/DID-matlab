function [v1, spec] = spike_extraction_parameters_modification(bodies)
%SPIKE_EXTRACTION_PARAMETERS_MODIFICATION Rebuild a v1
%   `spike_extraction_parameters_modification` from what the migration made of
%   it.
%
%   [V1, SPEC] = did2.convert.roundtrip.spike_extraction_parameters_modification(BODIES).
%   V1 is the document in NDI's v1 shape (apps/spikeextractor/
%   spike_extraction_parameters_modification.json + app.json + base.json at
%   the locked NDI-matlab `main`, 3cb19a8, as ndi.app.spikeextractor
%   struct2doc writes it: the settings, the epoch string in `epochid.epochid`,
%   edges extraction_parameters_id and element_id). BODIES holds the `method`
%   (id preserved) and its software entity. The fields are rebuilt as for
%   did2.convert.roundtrip.spike_extraction_parameters, and:
%
%     depends_on extraction_parameters_id   the method's parent_id
%     depends_on element_id                 the method's entity_id
%     epochid.epochid                       the parameter "epochid" (pass 1
%                                           has no epoch document to name)
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.spike_extraction_parameters_modification.

arguments
    bodies cell
end

CLASS = 'spike_extraction_parameters_modification';
[v1, entries, spec] = methodDocParts(bodies, CLASS, ...
    struct('parent_id', 'extraction_parameters_id', 'entity_id', 'element_id'));
if isempty(fieldnames(v1))
    return;
end
[blk, v1, bad] = spikeExtractionBlock(entries, v1);
spec.unplaced = [spec.unplaced, bad];
v1.(CLASS) = blk;
end
