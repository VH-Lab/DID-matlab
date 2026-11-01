function [v, found] = findNotes(s)
%FINDNOTES A document's free text, found as findField finds a field.
%
%   [V, FOUND] = findNotes(S) is findField(S, 'notes'), or, when the
%   document has no `notes`, findField(S, 'description'): did-schema
%   did_v2_go_forward_class_audit.md [one free-text field: notes] (Jess
%   Haley, 2026-10-25) renames `entity.description` and
%   `data_body.description` to `notes`, and the inverses read both until
%   every writer has moved.
%
%   See also findField, notesText.
[v, found] = findField(s, 'notes');
if ~found
    [v, found] = findField(s, 'description');
end
end
