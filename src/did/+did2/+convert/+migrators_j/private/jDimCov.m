function [dims, covs] = jDimCov(axes)
%JDIMCOV A value's `dimensions` and `covariates` from its axis specs.
%
%   [DIMS, COVS] = jDimCov(AXES) takes the value's axes IN ARRAY ORDER -- a
%   cell of axis specs (jAxis; or the same struct a key-style caller writes:
%   {variable, n, unit, source_unit, approximate, origin, spacing, quantity,
%   term, positions_from, cyclic, chunk}) or a struct array of them -- and
%   returns, per did-schema data_body AMENDMENT 6 (Jess Haley, 2026-10-22
%   [covariates], [along by index], [bare dimension]):
%
%     DIMS   one entry per axis: {term: the axis variable, n, chunk}
%     COVS   one entry per axis that states its positions, along that axis
%            (`along` = its 0-based index): {variable, unit, source_unit,
%            approximate, along, origin+spacing | quantity | term |
%            document (was positions_from), cyclic}
%
%   This is the mechanical port of a former `keys` list: the key's variable
%   becomes BOTH the dimension's term and its covariate's variable, and the
%   key's positions become the covariate. An axis with no positions gives a
%   bare dimension and no covariate; so does an axis whose positions only
%   repeat 0..n-1 with no unit (jIndexOnly; Jess Haley 2026-10-22 [covariate
%   rules named], 6.2a: such a covariate is not written). Both lists are built through
%   did2.build.dimension and did2.build.composite('data', 'covariates', ...),
%   so they are checked against the loaded schema; empty AXES gives [] and [].
%
%   See also jAxis, did2.build.dimension, did2.build.covariate.

if isempty(axes)
    dims = [];
    covs = [];
    return;
end
if isstruct(axes)
    axes = num2cell(reshape(axes, 1, []));
end
dimList = cell(1, numel(axes));
covList = {};
for k = 1:numel(axes)
    a = axes{k};
    opts = {};
    if has(a, 'chunk'); opts = {'Chunk', a.chunk}; end
    dimList{k} = did2.build.dimension(a.variable, a.n, opts{:});
    c = struct('variable', {a.variable});
    for f = {'unit', 'source_unit', 'approximate'}
        if has(a, f{1}); c.(f{1}) = a.(f{1}); end
    end
    c.along = k - 1;
    positioned = false;
    if has(a, 'origin') || has(a, 'spacing')
        c.origin = a.origin;
        c.spacing = a.spacing;
        positioned = true;
    end
    for f = {'quantity', 'term'}
        if has(a, f{1})
            c.(f{1}) = a.(f{1});
            positioned = true;
        end
    end
    if has(a, 'positions_from') && ~isequal(a.positions_from, -1)
        c.document = a.positions_from;
        positioned = true;
    end
    if has(a, 'cyclic'); c.cyclic = a.cyclic; end
    if positioned && ~jIndexOnly(c, a.n)
        covList{end+1} = did2.build.composite('data', 'covariates', c); %#ok<AGROW>
    end
end
dims = did2.build.list(dimList{:});
if isempty(covList)
    covs = [];
else
    covs = did2.build.list(covList{:});
end
end

function tf = has(s, name)
tf = isfield(s, name) && ~isempty(s.(name)) ...
    && ~(isstruct(s.(name)) && isscalar(s.(name)) && isempty(fieldnames(s.(name))));
end
