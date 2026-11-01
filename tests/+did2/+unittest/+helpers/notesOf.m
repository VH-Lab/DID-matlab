function s = notesOf(block)
%NOTESOF A V2 `entity` or `data_body` block's free text, as char.
%
%   S = did2.unittest.helpers.notesOf(BLOCK) is BLOCK.notes, else
%   BLOCK.description, else ''. did-schema did_v2_go_forward_class_audit.md
%   [one free-text field: notes] (Jess Haley, 2026-10-25) renames
%   `entity.description` and `data_body.description` to `notes`; did2.build
%   writes whichever the loaded schema declares, so the tests read both.
s = '';
if ~isstruct(block) || ~isscalar(block)
    return;
end
for f = {'notes', 'description'}
    if isfield(block, f{1}) && ~isempty(block.(f{1}))
        s = char(block.(f{1}));
        return;
    end
end
end
