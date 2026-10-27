function [v1, spec] = ontologyImage(bodies)
%ONTOLOGYIMAGE Rebuild a v1 `ontologyImage` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.ontologyImage(BODIES). Every document
%   NDI's writer at the locked NDI-matlab `main` (3cb19a8,
%   +ndi/+setup/+NDIMaker/imageDocMaker.m) makes states `ontologyNodes`, and
%   pass 1 passes it through unchanged under its v1 class name
%   (did2.convert.migrators_j.ontology_image): BODIES is that one passthrough
%   and V1 is it with v1_to_v2's outbound renames undone
%   (private/passthroughInverse).
%
%   The legacy vintage (ontology_name / ontology_region), which the migrator
%   folds to an observation, has no writer at that `main` and no corpus
%   document: its inverse is not built, and a round trip of it reports the
%   emitted documents unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.ontology_image.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'ontologyImage');
end
