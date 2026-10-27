function [v, found] = findField(s, name)
%FINDFIELD The first field NAME anywhere in the document's property blocks.
%
%   [V, FOUND] = findField(S, NAME) searches S depth-first, in field order,
%   through nested scalar structs, skipping `document_class`, `base`,
%   `depends_on` and `files`, and returns the first field called NAME. The
%   lightsheet inverses read a statement's or a body's fields this way, as
%   NDI-matlab ndi.vintage.lightsheetPyramid / lightsheetLevel do, without
%   naming the block the builder put each in.
%
%   See also did2.convert.roundtrip.lightsheetZarrPyramid.

v = [];
found = false;
if ~isstruct(s) || ~isscalar(s)
    return;
end
fns = fieldnames(s);
if isfield(s, name)
    v = s.(name);
    found = true;
    return;
end
for k = 1:numel(fns)
    if any(strcmp(fns{k}, {'document_class', 'base', 'depends_on', 'files'}))
        continue;
    end
    b = s.(fns{k});
    if isstruct(b) && isscalar(b)
        [v, found] = findInner(b, name);
        if found; return; end
    end
end
end

function [v, found] = findInner(s, name)
v = [];
found = false;
if isfield(s, name)
    v = s.(name);
    found = true;
    return;
end
fns = fieldnames(s);
for k = 1:numel(fns)
    b = s.(fns{k});
    if isstruct(b) && isscalar(b)
        [v, found] = findInner(b, name);
        if found; return; end
    end
end
end
