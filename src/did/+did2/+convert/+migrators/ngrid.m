function v2Body = ngrid(preBody)
%NGRID Migrate a did_v1 ngrid block to V_delta.
%
%   This is a *superclass migrator*: ngrid is rarely a concrete
%   class; it ships as a superclass-contributed property block on
%   classes like hartley_calc (via reverse_correlation -> ngrid).
%   The dispatcher walks document_class.superclasses (as
%   normalised by universalRenames) and runs this migrator on any
%   document that declares ngrid among its superclasses, before
%   the concrete-class migrator runs.
%
%   Field renames / structural derivations inside the ngrid
%   property block:
%       ngrid.data_dim  -> ngrid.dim_sizes
%       (none)          -> ngrid.ndims = numel(data_dim)
%
%   v1 also stores `data_size` (per-element byte size) and
%   `coordinates` (sample coordinates along each dimension); both
%   are v1-only fields with no V_delta counterpart on ngrid and
%   are dropped per the conversion default (PLAN.md §9.6 Q1:
%   surface drop-counts in summary; promote to per-class migrators
%   only if a consumer surfaces).
%
%   v1 `data_type` matches V_delta `data_type` verbatim and passes
%   through. If v1 already supplied `ndims` (rare), the value is
%   preserved instead of recomputed.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'ngrid') || ~isstruct(v2Body.ngrid)
    return;
end

block = v2Body.ngrid;

if isfield(block, 'data_dim')
    dimSizes = block.data_dim;
    block.dim_sizes = dimSizes;
    block = rmfield(block, 'data_dim');
    if ~isfield(block, 'ndims')
        block.ndims = double(numel(dimSizes));
    end
elseif isfield(block, 'dim_sizes') && ~isfield(block, 'ndims')
    block.ndims = double(numel(block.dim_sizes));
end

if isfield(block, 'data_size')
    block = rmfield(block, 'data_size');
end
if isfield(block, 'coordinates')
    block = rmfield(block, 'coordinates');
end

v2Body.ngrid = block;
end
