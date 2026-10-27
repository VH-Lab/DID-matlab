function [v1, spec] = sorting_parameters(bodies)
%SORTING_PARAMETERS Rebuild a v1 `sorting_parameters` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.sorting_parameters(BODIES). V1 is the
%   document in NDI's v1 shape (apps/spikesorter/sorting_parameters.json +
%   app.json + base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   ndi.app.spikesorter struct2doc writes it). BODIES holds the `method` (id
%   preserved) and its software entity (private/methodDocParts):
%
%     base.id, session_id, datestamp   the method's
%     base.name                        the method's name
%     app.name, version, url           the software entity
%     sorting_parameters.*             every method parameter (the bag:
%                                      jParameterList's names, '_' as ' ')
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.sorting_parameters.

arguments
    bodies cell
end

CLASS = 'sorting_parameters';
[v1, entries, spec] = methodDocParts(bodies, CLASS, struct('entity_id', 'element_id'));
if isempty(fieldnames(v1))
    return;
end
[blk, bad] = methodParameters(entries);
spec.unplaced = [spec.unplaced, bad];
[blk, v1] = parkedMethodBlocks(blk, v1);
v1.(CLASS) = blk;
end

