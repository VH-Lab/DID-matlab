function [v, src] = itemRegular(e, which)
%ITEMREGULAR A covariate's origin or spacing, and the source's.
%
%   [V, SRC] = itemRegular(E, WHICH) with WHICH 'origin' or 'spacing' reads
%   the flat E.<which> and E.source_<which> ([one shape for measured
%   numbers], Jess Haley, 2026-11-17; did2.read.numeric). [] for what E does
%   not state. The old {value, source_value} block is the error
%   'did2:read:oldNumericShapeReMigrate' (section 9 step 4, [no migrated
%   database is kept], Jess Haley, 2026-11-19).
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
