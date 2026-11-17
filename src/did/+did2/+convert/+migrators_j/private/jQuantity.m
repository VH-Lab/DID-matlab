function [cells, gaps] = jQuantity(kind, sourceValues, sourceUnit, varargin)
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
%
%   In the new numeric shape (did2.build.numericShape, the default) the
%   readings are ONE cell whose canonical field and `source_numeric` are
%   arrays (seriesCell, below); in the old shape, one cell per reading with
%   `source_value`.
%
%   GAPS, a struct array {field, reason} for did2.build's 'Gaps' option, names
%   each canonical left out because the source gave NO unit or a number that
%   is not finite: "every quantity holds exactly one canonical value; it may
%   be absent only when the document's `needs_info` names it" ([canonical
%   absent only as needs info], Decided by Jess Haley, 2026-10-30; the run's
%   migration report since [gap accepted when the report lists it]). The
%   path is <KIND>.value.<canonical slot> ('.canonical' for a kind with no one
%   slot, the convention kept by [formulation amount needs info]); a value
%   whose every cell lacks it is ONE gap with no index ([waveform unit gap
%   once], Jess Haley, 2026-11-03), otherwise one per cell, indexed (k) when
%   there are several. A STATED unit jSourceUnit does not know for KIND gives
%   no gap: an unrecognised spelling is carried for mapping, not written
%   without a canonical (carry-155), and the validator refuses it.

if nargin < 3; sourceUnit = ''; end
[term, factor, unitKind, slot] = jSourceUnit(sourceUnit);
canon = '';
if ~isempty(factor) && strcmp(unitKind, kind)
    canon = canonicalField(kind);
    if ~isempty(slot)
        canon = slot;   % a concentration row names its own slot (jSourceUnit)
    end
end
vals = double(sourceValues);
n = numel(vals);
if strcmp(did2.build.numericShape(), 'new')
    [cells, gaps] = seriesCell(kind, vals, term, factor, canon, varargin);
    return;
end
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
gaps = struct('field', {}, 'reason', {});
noUnit = isempty(term);
% a stated unit jSourceUnit does not know for KIND (CANON empty): no gap
missing = noUnit | (~isempty(canon) & ~isfinite(vals));
if ~any(missing)
    return;
end
slot = canon;
if isempty(slot) && ~strcmp(kind, 'concentration')
    slot = canonicalField(kind);   % concentration has no one slot
end
if isempty(slot); slot = 'canonical'; end
base = [kind '.value'];
if all(missing)
    if noUnit && n > 1
        why = sprintf(['unit not stated: the source gives %d numbers with ' ...
            'no unit, so no canonical %s is computed'], n, slot);
    elseif noUnit
        why = sprintf(['unit not stated: the source gives the number %s ' ...
            'with no unit, so no canonical %s is computed'], ...
            num2str(vals(1), 17), slot);
    else
        why = sprintf(['the source gives no finite number (%s), so no ' ...
            'canonical %s is computed'], mat2str(vals), slot);
    end
    gaps(1).field = [base '.' slot];
    gaps(1).reason = why;
    return;
end
for k = find(missing)
    gaps(end+1).field = sprintf('%s(%d).%s', base, k, slot); %#ok<AGROW>
    gaps(end).reason = sprintf(['the source''s number is %s, not a finite ' ...
        'number, so no canonical %s is computed'], num2str(vals(k)), slot);
end
end

function [cells, gaps] = seriesCell(kind, vals, term, factor, canon, extra)
% The new numeric shape ([one shape for measured numbers], Jess Haley,
% 2026-11-17, did-schema did_v2_numeric_shape_plan.md, section 8 answer 4):
% ONE cell whose canonical field and source_numeric are arrays, one
% source_unit for the series. A reading the source wrote as a non-finite
% number keeps it in the canonical array too (NaN * factor is NaN), so the
% canonical is left out -- and named as a gap, once -- only when the source
% states no unit.
s = struct();
if ~isempty(canon)
    s.(canon) = reshape(vals * factor, 1, []);
end
s.source_numeric = reshape(vals, 1, []);
if ~isempty(term)
    s.source_unit = term;
end
for j = 1:2:numel(extra)
    s.(extra{j}) = extra{j + 1};
end
cells = did2.build.composite(kind, 'value', {s});
gaps = struct('field', {}, 'reason', {});
if ~isempty(term)
    return;   % a stated unit: the canonical is written, or (unknown for KIND) carried
end
slot = '';
if ~strcmp(kind, 'concentration')
    slot = canonicalField(kind);   % concentration has no one slot
end
if isempty(slot); slot = 'canonical'; end
n = numel(vals);
if n > 1
    why = sprintf(['unit not stated: the source gives %d numbers with ' ...
        'no unit, so no canonical %s is computed'], n, slot);
else
    why = sprintf(['unit not stated: the source gives the number %s ' ...
        'with no unit, so no canonical %s is computed'], ...
        num2str(vals(1), 17), slot);
end
gaps(1).field = [kind '.value.' slot];
gaps(1).reason = why;
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
    case 'concentration', f = 'molar';   % jSourceUnit's SLOT, when it names one, wins
    otherwise,          f = '';
end
end
