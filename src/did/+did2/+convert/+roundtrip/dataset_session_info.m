function [v1, spec] = dataset_session_info(bodies)
%DATASET_SESSION_INFO The v1 `dataset_session_info` the migration emitted.
%
%   [V1, SPEC] = did2.convert.roundtrip.dataset_session_info(BODIES). Pass 1
%   writes NO V2 document for a list ([fit classes kept; session list rebuilt],
%   Decided by Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 (carryUnrebuiltSessionLists)
%   checks, after the batch, that the batch's converted `session_in_a_dataset`
%   memberships rebuild the list exactly, and carries it whole as v1 otherwise
%   (carry-118), as it carries one that a field outside the template, or a
%   collision universalRenames would discard, carries (carry-100, carry-049).
%   did2.convert.roundtrip.check reads a carried document as the v1 document
%   itself, so this inverse is reached only for:
%     - a body that was NOT carried: it rebuilds a single passed-through
%       document (passthroughInverse) and calls anything else unplaced;
%     - NO body (a list that rebuilt): it rebuilds nothing and says so in
%       SPEC.unplaced. The rebuild is the batch check above, which reads the
%       v1 memberships; did2.convert.roundtrip.wholeBatch does not compare a
%       source that became nothing.
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.dataset_session_info.

arguments
    bodies cell
end

if isempty(bodies)
    spec = emptySpec();
    v1 = struct();
    spec.unplaced{end+1} = ['no document was emitted: a dataset_session_info that ' ...
        'rebuilds from the batch''s memberships writes none, and its rebuild is ' ...
        'checked by did2.convert.v1_to_v2 (carryUnrebuiltSessionLists), not here'];
    return;
end
[v1, spec] = passthroughInverse(bodies, 'dataset_session_info');
end
