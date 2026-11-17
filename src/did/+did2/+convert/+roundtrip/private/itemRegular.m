function [v, src] = itemRegular(e, which)
%ITEMREGULAR A covariate's origin or spacing, and the source's, from either shape.
%
%   [V, SRC] = itemRegular(E, WHICH) with WHICH 'origin' or 'spacing' reads
%   the old block E.<which>.value / .source_value, or the new flat E.<which>
%   and E.source_<which> ([one shape for measured numbers], Jess Haley,
%   2026-11-17; did2.read.numeric). [] for what E does not state.
v = [];
src = [];
e = firstOf(e);
if ~isstruct(e) || ~isscalar(e)
    return;
end
r = did2.read.numeric(e);
if ~strcmp(r.form, 'origin')
    return;
end
v = r.(which);
src = r.(['source_' which]);
end
