function [value, chemicals] = jDoseValue(chemicals)
%JDOSEVALUE A migrated dose's `value`: the amount the source gave, else NaN.
%
%   [VALUE, CHEMICALS] = jDoseValue(CHEMICALS). CHEMICALS is the struct array
%   jDoseBodies takes (substance, source_value, source_unit). A dose always
%   has an amount (Jess Haley, 2026-10-21); a v1 treatment records one only as
%   a mixture_table row whose UNIT is an amount -- a mass, a volume, or an
%   amount per body mass (Hunsberger writes alprazolam/saline as `1 mg/kg`,
%   SNOMED:396163008). A row in a CONCENTRATION unit (Molar, % v/v -- Birren,
%   Babu) says what the formulation is made of, not how much was given, and
%   stays on its ingredient entry.
%
%   When EXACTLY ONE row carries a finite amount in an amount unit, that
%   amount becomes the dose's value (its canonical slot filled when the unit
%   is one this table knows, `source_value` and `source_unit` always) and is
%   taken off the row, so it is not also written as the ingredient's
%   concentration. Otherwise -- no such row, or several (an amount per
%   ingredient is not one amount of the formulation) -- the amount is
%   unrecorded and is written as NaN in the dose's volume:
%   `value.volume.liters = NaN` ("An unrecorded amount is written as NaN in
%   its quantity (e.g. a dose's volume.liters: NaN)", Jess Haley,
%   2026-10-21). When no row gives a number but exactly one kind of amount
%   unit is stated, the NaN goes in THAT quantity, with the unit as
%   `source_unit` ("where the kind is known ... the NaN goes in that quantity
%   instead", Jess Haley, 2026-10-21 [unknown-amount-slot]). Whether NaN
%   survives a did2 write and read is DID-matlab
%   #218's work (testSqliteDbNonFinite); this function only writes it.

hits = [];
slots = {};
kindOnly = [];          % rows stating an amount UNIT but no number
kindSlots = {};
for k = 1:numel(chemicals)
    c = chemicals(k);
    [slot, canon, factor] = amountSlot(c.source_unit);
    if isempty(slot)
        continue;
    end
    if isempty(c.source_value) || ~isnumeric(c.source_value) || ~isfinite(c.source_value(1))
        kindOnly(end+1) = k; %#ok<AGROW>
        kindSlots(end+1, :) = {slot, canon}; %#ok<AGROW>
        continue;
    end
    hits(end+1) = k; %#ok<AGROW>
    slots(end+1, :) = {slot, canon, factor}; %#ok<AGROW>
end

if isscalar(hits)
    c = chemicals(hits);
    q = struct();
    if ~isempty(slots{1, 3})
        q.(slots{1, 2}) = double(c.source_value(1)) * slots{1, 3};
    end
    q.source_value = double(c.source_value(1));
    q.source_unit = unitTerm(c.source_unit);
    value = did2.build.composite('dose', 'value', struct(slots{1, 1}, q));
    chemicals(hits).source_value = [];
    chemicals(hits).source_unit = [];
elseif isempty(hits) && ~isempty(kindOnly) && isscalar(unique(kindSlots(:, 1)))
    % The source states the KIND of amount (its unit) but not the number: the
    % NaN goes in that quantity, not in volume (Jess Haley, 2026-10-21
    % [unknown-amount-slot]). The unit is carried as `source_unit`.
    c = chemicals(kindOnly(1));
    q = struct(kindSlots{1, 2}, NaN, 'source_unit', unitTerm(c.source_unit));
    value = did2.build.composite('dose', 'value', struct(kindSlots{1, 1}, q));
    for k = kindOnly
        chemicals(k).source_value = [];
        chemicals(k).source_unit = [];
    end
else
    % Neither the amount nor its kind is known: the NaN goes in
    % value.volume.liters (Jess Haley, 2026-10-21 [unknown-amount-slot]).
    value = did2.build.composite('dose', 'value', ...
        struct('volume', struct('liters', NaN)));
end
end

function [slot, canon, factor] = amountSlot(unit)
% The dose slot an amount unit fills, its canonical field and the factor
% into it ([] when the unit is an amount but this table cannot convert it).
slot = ''; canon = ''; factor = [];
spelling = '';
if isstruct(unit) && ~isempty(unit) && isfield(unit, 'name')
    spelling = strtrim(char(unit.name));
elseif ischar(unit) || isstring(unit)
    spelling = strtrim(char(unit));
end
if isempty(spelling); return; end
mu = char(181);
% per body mass: spelling, canonical field, factor
P = { ...
    'mg/kg',        'grams_per_gram',  1e-6; ...
    'g/kg',         'grams_per_gram',  1e-3; ...
    'ug/kg',        'grams_per_gram',  1e-9; ...
    [mu 'g/kg'],    'grams_per_gram',  1e-9; ...
    'ng/kg',        'grams_per_gram',  1e-12; ...
    'mL/kg',        'liters_per_gram', 1e-6; ...
    'ml/kg',        'liters_per_gram', 1e-6; ...
    'uL/kg',        'liters_per_gram', 1e-9; ...
    'ul/kg',        'liters_per_gram', 1e-9; ...
    'uL/g',         'liters_per_gram', 1e-6; ...
    'ul/g',         'liters_per_gram', 1e-6; ...
    'mol/kg',       'moles_per_gram',  1e-3; ...
    'mmol/kg',      'moles_per_gram',  1e-6};
hit = find(strcmp(P(:, 1), spelling), 1);
if ~isempty(hit)
    slot = 'amount_per_body_mass';
    canon = P{hit, 2};
    factor = P{hit, 3};
    return;
end
[~, f, kind] = jSourceUnit(spelling);
switch kind
    case 'mass'
        slot = 'mass'; canon = 'grams'; factor = f;
    case 'volume'
        slot = 'volume'; canon = 'liters'; factor = f;
end
end

function t = unitTerm(unit)
if isstruct(unit)
    t = unit;
else
    t = jSourceUnit(unit);
end
end
