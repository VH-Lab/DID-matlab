function tf = allEmpty(v)
%ALLEMPTY Empty, or a struct (array) whose every field is empty all the way
%   down: a block the builder padded and nothing filled.
if isEmptyValue(v)
    tf = true;
elseif isstruct(v)
    tf = true;
    for k = 1:numel(v)
        fns = fieldnames(v(k));
        for f = 1:numel(fns)
            if ~allEmpty(v(k).(fns{f}))
                tf = false;
                return;
            end
        end
    end
else
    tf = false;
end
end
