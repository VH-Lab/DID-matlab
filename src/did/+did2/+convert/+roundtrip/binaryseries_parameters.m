function [v1, spec] = binaryseries_parameters(bodies)
%BINARYSERIES_PARAMETERS The v1 `binaryseries_parameters` the migration emitted:
%   always the v1 document itself.
%
%   [V1, SPEC] = did2.convert.roundtrip.binaryseries_parameters(BODIES). Pass 1
%   carries every v1 `binaryseries_parameters` whole as v1, needs_mapping
%   (Decided by Jess Haley, 2026-10-29 [binaryseries parameters carried],
%   did-schema V_eta_go_forward_class_audit.md), and
%   did2.convert.roundtrip.check reads a carried document as the v1 document
%   itself, so this inverse is reached only for a body that was NOT carried: it
%   rebuilds a single passed-through document (passthroughInverse) and calls
%   anything else unplaced. (Until 2026-10-29 pass 1 passed the document
%   through, removing an integer field that held the template's empty-text
%   placeholder.)
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.binaryseries_parameters.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'binaryseries_parameters');
end
