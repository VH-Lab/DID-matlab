function why = jCarryWhy(unplaced)
%JCARRYWHY The `carried_as_v1` note for a treatment the generic stage carries
%   because jTreatmentBodies could not place it (UNPLACED, a cellstr).
%
%   A `needs_mapping:` entry ([one correct reading], Jess Haley, 2026-10-26,
%   did-schema V_eta_go_forward_class_audit.md: the v1 document admits more
%   than one V2 reading) is the note as it stands, so the note starts with the
%   register kind; any other entry is something a dose could not place, noted
%   'unplaced: ...' as before.
if any(startsWith(unplaced, 'needs_mapping:'))
    why = strjoin(unplaced(startsWith(unplaced, 'needs_mapping:')), '; ');
else
    why = ['unplaced: ' strjoin(unplaced, '; ')];
end
end
