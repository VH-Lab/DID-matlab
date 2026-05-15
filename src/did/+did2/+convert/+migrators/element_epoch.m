function v2Body = element_epoch(preBody)
%ELEMENT_EPOCH Migrate a did_v1 element_epoch body to V_delta.
%
%   V_delta requires `element_epoch.t0` and `element_epoch.t1` as
%   separate scalar doubles (both required, non-empty). did_v1
%   carries the same data as a single 2-vector `t0_t1: [t0, t1]`
%   on the element_epoch block. This migrator splits the vector
%   into two scalar fields.
%
%   The `epoch_clock` field is already snake_case in did_v1 (unlike
%   the epochclocktimes superclass, which used `clocktype`), so no
%   field-name rename is needed; the value passes through.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'element_epoch') ...
        || ~isstruct(v2Body.element_epoch)
    error('did2:convert:missingBlock', ...
        'element_epoch body is missing the element_epoch property block.');
end

block = v2Body.element_epoch;

% Some v1 generations stored `clocktype` instead of `epoch_clock`
% (matching the superclass naming); accept either.
if isfield(block, 'clocktype') && ~isfield(block, 'epoch_clock')
    block.epoch_clock = char(block.clocktype);
    block = rmfield(block, 'clocktype');
elseif isfield(block, 'clocktype')
    block = rmfield(block, 'clocktype');
end

if isfield(block, 't0_t1')
    pair = block.t0_t1;
    if numel(pair) >= 2
        block.t0 = double(pair(1));
        block.t1 = double(pair(2));
    elseif numel(pair) == 1
        block.t0 = double(pair(1));
    end
    block = rmfield(block, 't0_t1');
end

v2Body.element_epoch = block;
end
