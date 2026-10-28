function [v1, spec] = treatment_transfer(bodies)
%TREATMENT_TRANSFER The v1 `treatment_transfer` the migration emitted: always
%   the v1 document itself.
%
%   [V1, SPEC] = did2.convert.roundtrip.treatment_transfer(BODIES). Pass 1
%   carries every v1 `treatment_transfer` whole as v1 under a needs-mapping
%   register row (Decided by Jess Haley, 2026-10-27 [treatment transfer stays
%   v1], did-schema V_eta_go_forward_class_audit.md), and
%   did2.convert.roundtrip.check reads a carried document as the v1 document
%   itself, so this inverse is reached only for a body that was NOT carried:
%   it rebuilds a single passed-through document (passthroughInverse) and
%   calls anything else unplaced. The inverse of the conversion that was
%   removed (a term manipulation, a derived_from relation and an anchor) is
%   gone with it.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.treatment_transfer.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'treatment_transfer');
end
