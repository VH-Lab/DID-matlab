function [v1, spec] = ontologyTableRow(bodies)
%ONTOLOGYTABLEROW The v1 `ontologyTableRow` the migration emitted: always the
%   v1 document itself.
%
%   [V1, SPEC] = did2.convert.roundtrip.ontologyTableRow(BODIES). Pass 1
%   carries every v1 `ontologyTableRow` whole as v1 (carry-026, Decided by
%   Jess Haley, 2026-10-30 [table rows carried as v1], did-schema
%   V_eta_go_forward_class_audit.md), and did2.convert.roundtrip.check reads a
%   carried document as the v1 document itself, so this inverse is reached
%   only for a body that was NOT carried: it rebuilds a single passed-through
%   document (passthroughInverse) and calls anything else unplaced.
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26); its migrator is
%   did2.convert.migrators_j.ontology_table_row.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.ontology_table_row.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'ontologyTableRow');
end
