function s = notesText(block)
%NOTESTEXT A V2 `entity` or `data_body` block's free text, as char.
%
%   S = notesText(BLOCK) is BLOCK.notes, or BLOCK.description when BLOCK has
%   no non-empty `notes`, or ''. did-schema did_v2_go_forward_class_audit.md
%   [one free-text field: notes] (Jess Haley, 2026-10-25) renames
%   `entity.description` and `data_body.description` to `notes`; the
%   inverses read both until every writer has moved.
%
%   See also findNotes, fieldText.
s = fieldText(block, 'notes');
if isempty(s)
    s = fieldText(block, 'description');
end
end
