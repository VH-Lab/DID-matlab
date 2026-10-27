function [v, found] = getIn(s, varargin)
%GETIN The value at S.(A).(B)... (FOUND false, V [] when any step is
%   missing). A struct array or a cell is read at its first element at each
%   step, the shape jsondecode or did2.build gives a one-element list.
v = s;
found = true;
for i = 1:numel(varargin)
    v = firstOf(v);
    f = varargin{i};
    if isstruct(v) && isscalar(v) && isfield(v, f)
        v = v.(f);
    else
        v = [];
        found = false;
        return;
    end
end
end
