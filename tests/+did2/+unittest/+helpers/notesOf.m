function s = notesOf(block)
%NOTESOF A V2 `entity` or `data_body` block's free text, as char.
%
%   S = did2.unittest.helpers.notesOf(BLOCK) is BLOCK.notes, else ''.
%   did-schema did_v2_go_forward_class_audit.md [one free-text field: notes]
%   (Jess Haley, 2026-10-25) renamed `description` on those blocks to
%   `notes`; the old name is not read.
s = '';
if ~isstruct(block) || ~isscalar(block)
    return;
end
if isfield(block, 'notes') && ~isempty(block.notes)
    s = char(block.notes);
end
end
