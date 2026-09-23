function c = jConcentration(sourceUnit, sourceValue)
%JCONCENTRATION Build a V_eta concentration composite {source_unit,
%   source_value, approximate}. Blank (0.0, '') when called with no args -- the
%   curator's signal that an amount was not recoverable from the source.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
if nargin < 1; sourceUnit = ''; end
if nargin < 2 || isempty(sourceValue); sourceValue = 0.0; end
c = struct('source_unit', char(sourceUnit), ...
    'source_value', double(sourceValue), 'approximate', false);
end
