function [v, found] = resolveSteps(s, steps)
%RESOLVESTEPS The value at STEPS (from flattenLeaves) in S, if S has one.
%   A numeric step k on a scalar struct reads element 1 when k is 1, so a
%   one-entry list matches a one-entry list however each was built.
v = s;
found = true;
for i = 1:numel(steps)
    st = steps{i};
    if ischar(st)
        if isstruct(v) && isscalar(v) && isfield(v, st)
            v = v.(st);
        else
            found = false;
        end
    elseif isnumeric(st)
        if isstruct(v) && numel(v) >= st
            v = v(st);
        elseif iscell(v) && numel(v) >= st && isstruct(v{st})
            v = v{st};   % jsondecode's cell of differently-keyed entries
        else
            found = false;
        end
    else
        k = st{1};
        if iscell(v) && numel(v) >= k
            v = v{k};
        else
            found = false;
        end
    end
    if ~found
        v = [];
        return;
    end
end
end
