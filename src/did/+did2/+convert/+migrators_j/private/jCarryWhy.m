function why = jCarryWhy(unplaced)
%JCARRYWHY The `carried_as_v1` note for a treatment the generic stage carries
%   because jTreatmentBodies could not place it (UNPLACED, a cellstr).
%
%   A `needs_mapping:` entry ([one correct reading], Jess Haley, 2026-10-26,
%   did-schema V_eta_go_forward_class_audit.md: the v1 document admits more
%   than one V2 reading) is the note as it stands, so the note starts with the
%   carry register row it cites and the register kind ('[carry-023]
%   needs_mapping: ...', [carry register], Jess Haley, 2026-10-26); any other
%   entry is something a dose could not place, noted 'unplaced: ...' as before.

isMapping = ~cellfun(@isempty, regexp(unplaced, '^(\[carry-\d{3}\] )?needs_mapping:', 'once'));
if any(isMapping)
    why = strjoin(unplaced(isMapping), '; ');
else
    why = ['unplaced: ' strjoin(unplaced, '; ')];
end
end
