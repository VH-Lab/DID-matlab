function ax = jAxis(variable, n, varargin)
%JAXIS One axis of a value: its extent and, optionally, its positions.
%
%   ax = jAxis(variableTerm, n, 'name', value, ...)
%
%   Returns an AXIS SPEC -- a plain struct {variable, n, <given fields>} --
%   that jDimCov turns into one `dimensions` entry and (when positions are
%   given) one `covariates` entry along it (did-schema data_body AMENDMENT 6,
%   Jess Haley 2026-10-22 [covariates]; `keys` until then). The names are the
%   former key entry's, so a caller states an axis as it always did:
%
%     unit, source_unit, approximate     -> the covariate's
%     origin, spacing  ({value, source_value} each)   -> covariate origin/spacing
%     quantity ({value, source_value})   -> covariate quantity
%     term                               -> covariate term
%     positions_from                     -> covariate key
%     cyclic                             -> covariate cyclic
%     chunk                              -> the DIMENSION's chunk
%     regular                            -> ignored (origin/spacing say it)
%
%   The dimension's term and the covariate's variable are both VARIABLE: the
%   axis IS what was its key. An axis given no positions is a bare dimension
%   [bare dimension].
%
%   `variable` and `n` are POSITIONAL: an axis that cannot name itself or
%   state its extent is not an axis. 'source_unit' given as text becomes a
%   term (jSourceUnit). Empty values are left out. The spec is checked when
%   jDimCov builds it (did2.build.dimension / composite 'data.covariates').
%
%   Shared helper for the Brainstorm-J (+migrators_j) migrators.
%
%   See also jDimCov.

if mod(numel(varargin), 2) ~= 0
    error('did2:migrators_j:jAxis:badOptions', ...
        'jAxis options must be name-value pairs; got %d trailing argument(s).', ...
        numel(varargin));
end
known = {'variable', 'unit', 'source_unit', 'approximate', 'n', 'regular', ...
    'origin', 'spacing', 'quantity', 'term', 'positions_from', 'cyclic', 'chunk'};
ax = struct('variable', variable, 'n', n);
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~any(strcmp(name, known))
        error('did2:migrators_j:jAxis:unknownField', ...
            'jAxis has no sub-field `%s`. An axis spec takes: %s.', ...
            name, strjoin(known, ', '));
    end
    v = varargin{k + 1};
    if strcmp(name, 'source_unit') && (ischar(v) || isstring(v))
        v = jSourceUnit(v);
    end
    if strcmp(name, 'regular')
        continue;   % origin/spacing say it (AMENDMENT 6 removed `regular`)
    end
    if isempty(v) || (isstruct(v) && isscalar(v) && isempty(fieldnames(v))) ...
            || (isstruct(v) && isfield(v, 'node') && isfield(v, 'name') ...
                && isscalar(v) && isempty(v.node) && isempty(v.name))
        continue;
    end
    if strcmp(name, 'quantity') && isstruct(v)
        if isfield(v, 'value'); v.value = reshape(v.value, 1, []); end
        if isfield(v, 'source_value'); v.source_value = reshape(v.source_value, 1, []); end
    end
    ax.(name) = v;
end
end
