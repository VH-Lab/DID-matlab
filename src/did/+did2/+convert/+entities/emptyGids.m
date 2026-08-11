function g = emptyGids()
%EMPTYGIDS A 0x0 `entity.global_identifier` struct array with the right fields.
%
%   Returned rather than `[]` so a caller can always concatenate onto it and so
%   `numel` reads 0 rather than erroring.
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB -- see entityDoc's header.
%
%   See also: did2.convert.entities.buildGids.

g = struct('scheme', {}, 'value', {});
end
