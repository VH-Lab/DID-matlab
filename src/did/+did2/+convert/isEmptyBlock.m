function tf = isEmptyBlock(v)
%ISEMPTYBLOCK True when a v1 value states nothing: empty ([], '', {}), a
%   struct with no fields (JSON `{}`), or a struct (or struct array) whose
%   every field is itself such a value.
%
%   Used for a legacy `ndi_document` block beside `base`: [empty ndi_document
%   block is notation] (Decided by Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md) -- an empty block does not carry the
%   document, a non-empty one does ([old ndi_document blocks carry]).

if isempty(v)
    tf = true;
elseif isstruct(v)
    tf = true;
    for k = 1:numel(v)
        fns = fieldnames(v(k));
        for j = 1:numel(fns)
            if ~did2.convert.isEmptyBlock(v(k).(fns{j}))
                tf = false;
                return;
            end
        end
    end
elseif isstring(v)
    tf = all(strlength(v) == 0);
else
    tf = false;
end
end
