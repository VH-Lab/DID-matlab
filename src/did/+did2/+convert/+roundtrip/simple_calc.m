function [v1, spec] = simple_calc(bodies)
%SIMPLE_CALC The v1 `simple_calc` the migration emitted: always the v1 document itself.
%
%   [V1, SPEC] = did2.convert.roundtrip.simple_calc(BODIES). Pass 1 carries every
%   v1 `simple_calc` whole as v1 under a needs-home register row (Decided by Jess
%   Haley, 2026-10-27 [simple_calc carries as needs home], did-schema
%   V_eta_go_forward_class_audit.md), and did2.convert.roundtrip.check reads a
%   carried document as the v1 document itself, so this inverse is reached
%   only for a body that was NOT carried: it rebuilds a single passed-through
%   document (passthroughInverse) and calls anything else unplaced.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.simple_calc.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'simple_calc');
end
