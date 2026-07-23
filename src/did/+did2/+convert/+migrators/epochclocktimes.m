function v2Body = epochclocktimes(preBody)
%EPOCHCLOCKTIMES Migrate a did_v1 epochclocktimes block to V_delta.
%
%   This is a *superclass migrator*: epochclocktimes is rarely a
%   concrete class; it ships as a superclass-contributed property
%   block on classes like pyraview, ngrid, etc. The dispatcher walks
%   document_class.superclasses (as normalised by universalRenames)
%   and runs this migrator on any document that declares
%   epochclocktimes among its superclasses, before the concrete-class
%   migrator runs.
%
%   Field renames / structural rewrites inside the epochclocktimes
%   property block:
%       epochclocktimes.clocktype -> epochclocktimes.epoch_clock
%       epochclocktimes.t0_t1     -> epochclocktimes.t0,
%                                    epochclocktimes.t1
%
%   The v1 `t0_t1` field carries a 2-vector [t0 t1]; V_delta splits
%   them into two scalar double fields.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'epochclocktimes') ...
        || ~isstruct(v2Body.epochclocktimes)
    return;
end

block = v2Body.epochclocktimes;

if isfield(block, 'clocktype')
    block.epoch_clock = char(block.clocktype);
    block = rmfield(block, 'clocktype');
end

if isfield(block, 't0_t1')
    pair = block.t0_t1;
    if numel(pair) >= 2
        block.t0 = double(pair(1));
        block.t1 = double(pair(2));
    elseif isscalar(pair)
        block.t0 = double(pair(1));
    end
    block = rmfield(block, 't0_t1');
end

v2Body.epochclocktimes = block;
end
