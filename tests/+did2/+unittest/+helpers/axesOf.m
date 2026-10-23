function ax = axesOf(blk)
%AXESOF Each dimension of a `data` block, paired with the covariate along it.
%
%   AX = did2.unittest.helpers.axesOf(BLK) reads BLK.dimensions and
%   BLK.covariates (did-schema data_body AMENDMENT 6; `keys` until
%   2026-10-22) and returns a 1xN struct array, one entry per dimension in
%   array order:
%
%     term    the dimension's term
%     n       its extent
%     chunk   its chunk ([] when absent)
%     cov     the covariate whose `along` is EXACTLY this dimension's 0-based
%             index, or [] when none (a bare dimension)
%     nCov    how many covariates run along exactly this dimension
%
%   BLK may be a document (its `data` block is read) or the block itself. A
%   cell (a ragged JSON array) is accepted for either list. Covariates along
%   several dimensions are not paired; read BLK.covariates for those.

if isstruct(blk) && isfield(blk, 'data') && ~isfield(blk, 'dimensions')
    blk = blk.data;
end
dims = cellsOf(fieldOr(blk, 'dimensions'));
covs = cellsOf(fieldOr(blk, 'covariates'));
ax = struct('term', {}, 'n', {}, 'chunk', {}, 'cov', {}, 'nCov', {});
for k = 1:numel(dims)
    d = dims{k};
    e = struct('term', fieldOr(d, 'term'), 'n', fieldOr(d, 'n'), ...
        'chunk', fieldOr(d, 'chunk'), 'cov', [], 'nCov', 0);
    for c = 1:numel(covs)
        al = fieldOr(covs{c}, 'along');
        if iscell(al); al = cell2mat(al); end
        if isnumeric(al) && isscalar(al) && double(al) == k - 1
            if e.nCov == 0
                e.cov = covs{c};
            end
            e.nCov = e.nCov + 1;
        end
    end
    ax(end+1) = e; %#ok<AGROW>
end
end

function v = fieldOr(s, name)
v = [];
if isstruct(s) && isscalar(s) && isfield(s, name)
    v = s.(name);
end
end

function c = cellsOf(v)
c = {};
if isempty(v); return; end
if iscell(v)
    c = reshape(v, 1, []);
elseif isstruct(v)
    c = reshape(num2cell(v), 1, []);
end
end
