function [v1, spec] = binaryseries_parameters(bodies)
%BINARYSERIES_PARAMETERS Rebuild a v1 `binaryseries_parameters` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.binaryseries_parameters(BODIES). Pass 1
%   keeps the document as it is, removing only an integer field that holds the
%   template's empty-text placeholder (not set). BODIES is that one document;
%   V1 is it with v1_to_v2's outbound renames undone
%   (private/passthroughInverse). A removed placeholder is not set in v1 either.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.binaryseries_parameters.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'binaryseries_parameters');
end
