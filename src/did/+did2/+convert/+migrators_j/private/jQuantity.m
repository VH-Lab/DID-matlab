function cells = jQuantity(kind, sourceValues, sourceUnit, varargin)
%JQUANTITY The `value` cells of a quantity value kind, from what the v1
%   source wrote.
%
%   CELLS = jQuantity(KIND, SOURCEVALUES, SOURCEUNIT, NAME, VALUE, ...) builds
%   KIND's value array ('voltage', 'time', 'length', 'mass', 'angle', ...), one
%   cell per element of SOURCEVALUES, each carrying `source_value` and, when
%   SOURCEUNIT is non-empty, `source_unit` as a term (jSourceUnit). The
%   CANONICAL field (volts, seconds, ...) is filled ONLY when jSourceUnit knows
%   the spelling and it belongs to KIND -- the migrator does not guess a unit
%   the source did not state (the pre-#73 migrators wrote source_value alone
%   for the same reason). Trailing NAME, VALUE pairs are extra cell fields
%   applied to every cell (e.g. 'approximate', false).
%
%   Built with did2.build.composite, not valueCell, because the canonical is
%   optional in the schema and valueCell requires it.

if nargin < 3; sourceUnit = ''; end
[term, factor, unitKind] = jSourceUnit(sourceUnit);
canon = '';
if ~isempty(factor) && strcmp(unitKind, kind)
    canon = canonicalField(kind);
end
vals = double(sourceValues);
n = numel(vals);
c = cell(1, n);
for k = 1:n
    s = struct();
    if ~isempty(canon) && isfinite(vals(k))
        s.(canon) = vals(k) * factor;
    end
    s.source_value = vals(k);
    if ~isempty(term)
        s.source_unit = term;
    end
    for j = 1:2:numel(varargin)
        s.(varargin{j}) = varargin{j + 1};
    end
    c{k} = s;
end
cells = did2.build.composite(kind, 'value', c);
end

function f = canonicalField(kind)
switch kind
    case 'voltage',     f = 'volts';
    case 'time',        f = 'seconds';
    case 'length',      f = 'meters';
    case 'mass',        f = 'grams';
    case 'frequency',   f = 'hertz';
    case 'angle',       f = 'degrees';
    case 'temperature', f = 'celsius';
    case 'volume',      f = 'liters';
    case 'current',     f = 'amperes';
    otherwise,          f = '';
end
end
