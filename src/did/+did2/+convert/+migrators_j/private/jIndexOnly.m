function tf = jIndexOnly(c, n)
%JINDEXONLY True when the covariate C only repeats its dimension's positions
%   0..N-1, so it is not written (did-schema data_body plan, Jess Haley
%   2026-10-22 [covariate rules named], 6.2a: "a covariate that only repeats
%   its dimension's positions 0..n-1 is not written"; [bare dimension]: a
%   dimension may have no covariate, a plain index).
%
%   C is a covariate struct (or a jAxis spec), N the dimension's extent. True
%   only for a covariate with NO unit and NO source unit (a unit says the
%   numbers are a measurement, not positions) whose positions are LISTED as
%   exactly 0, 1, ..., N-1 (`quantity` or `count`), and never one marked
%   `cyclic`. 1..N (MATLAB's numbering, which several migrators write for a
%   channel axis) is NOT 0..N-1 and is kept: the decision names 0..n-1.
%
%   NOT the regular form origin 0 + spacing 1: the migrators write it from a
%   RECORDED scale of 1 (image_stack's dimension_scale, a lightsheet voxel
%   size), and testMigratorsJ's image_stack test records that such an axis is
%   "calibrated, not an index axis" -- its unit may be stated elsewhere (a
%   lightsheet level's t takes its pyramid's second). Callers that hold no
%   positions at all write no covariate (jLightsheetAxes).

tf = false;
if ~isstruct(c) || ~isscalar(c)
    return;
end
for f = {'unit', 'source_unit'}
    if isfield(c, f{1}) && given(c.(f{1}))
        return;
    end
end
if isfield(c, 'cyclic') && isequal(c.cyclic, true)
    return;
end
idx = 0:(double(n) - 1);
if isfield(c, 'origin') && given(c.origin)
    return;   % the regular form: a recorded scale (above)
end
for f = {'quantity', 'count'}
    if isfield(c, f{1}) && given(c.(f{1}))
        v = num(c.(f{1}));
        tf = isnumeric(v) && numel(v) == numel(idx) && isequal(double(v(:).'), idx);
        return;
    end
end
end

function v = num(x)
% a {value, source_value} pair's value, or the number itself
v = x;
if isstruct(x) && isfield(x, 'value')
    v = x.value;
    if isfield(x, 'source_value') && ~isempty(x.source_value) ...
            && ~isequal(double(x.source_value), double(x.value))
        v = NaN;   % the source said something else: not a bare index
    end
end
if iscell(v); v = cell2mat(v); end
end

function tf = given(x)
tf = ~isempty(x) && ~(isstruct(x) && isscalar(x) && ( isempty(fieldnames(x)) ...
    || (isfield(x, 'node') && isfield(x, 'name') && isempty(x.node) && isempty(x.name))));
end
