function [v1, spec] = control_stimulus_ids(bodies)
%CONTROL_STIMULUS_IDS The v1 `control_stimulus_ids` the migration emitted: always
%   the v1 document itself.
%
%   [V1, SPEC] = did2.convert.roundtrip.control_stimulus_ids(BODIES). Pass 1
%   carries every v1 `control_stimulus_ids` whole as v1 (carry-152, Decided by
%   Jess Haley, 2026-10-30 [control records carried in pass 1], did-schema
%   V_eta_go_forward_class_audit.md), and did2.convert.roundtrip.check reads a
%   carried document as the v1 document itself, so this inverse is reached
%   only for a body that was NOT carried: it rebuilds a single passed-through
%   document (passthroughInverse) and calls anything else unplaced.
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.control_stimulus_ids.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'control_stimulus_ids');
end
