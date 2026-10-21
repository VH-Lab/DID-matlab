function [value, chemicals, conflicts] = jDoseValue(chemicals)
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
%   EVERY row carrying a finite amount in an amount unit puts that amount in
%   its matching dose slot -- a volume in `volume`, a mass in `mass`, a
%   substance amount (mol) in `substance_amount`, a count in `count`, an
%   amount per body mass in `amount_per_body_mass` -- with its canonical
%   field filled when the unit is one this table knows, `source_value` and
%   `source_unit` always, and is taken off its row so it is not also written
%   as the ingredient's concentration (Jess Haley, 2026-10-21, "a": each
%   amount in its matching dose slot, not only when exactly one row exists).
%   Two rows of the SAME kind: the first is kept; a later one that AGREES
%   with it (the same canonical amount, or the same number and unit when the
%   unit has no conversion) is a duplicate, and one that DISAGREES is listed
%   in CONFLICTS (a cellstr, one line each) for the caller to report
%   (jTreatmentBodies: reportNote 'dose_amount_conflict'). Either way it is
%   taken off its row.
%   INTERIM, per-body-mass: the decision puts an amount per body mass on the
%   ingredient (`formulation.value.ingredients[k].amount_per_body_mass`);
%   that field is not in the did-schema #88 tree yet (the dose agent is
%   landing it), so until it is, the amount stays in the dose's
%   `amount_per_body_mass` slot as before.
%   No such row: the amount is unrecorded and is written as NaN in the
%   dose's volume:
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

conflicts = {};
if ~isempty(hits)
    v = struct();
    firstSpelled = struct();   % the first row's unit spelling, per slot
    for i = 1:numel(hits)
        k = hits(i);
        c = chemicals(k);
        [slot, canon, factor] = slots{i, :};
        sv = double(c.source_value(1));
        spelled = unitSpelling(c.source_unit);
        q = struct();
        if ~isempty(factor)
            q.(canon) = sv * factor;
        end
        q.source_value = sv;
        q.source_unit = unitTerm(c.source_unit);
        chemicals(k).source_value = [];
        chemicals(k).source_unit = [];
        if ~isfield(v, slot)
            v.(slot) = q;
            firstSpelled.(slot) = spelled;
            continue;
        end
        % a second row of the same kind: keep the first; report a disagreement
        first = v.(slot);
        if isfield(first, canon) && isfield(q, canon)
            agree = abs(first.(canon) - q.(canon)) <= 1e-12 * max(1, abs(first.(canon)));
        else
            agree = first.source_value == sv && strcmp(firstSpelled.(slot), spelled);
        end
        if ~agree
            conflicts{end+1} = sprintf('%s: kept %s %s, not %s %s', slot, ...
                num2str(first.source_value, 17), firstSpelled.(slot), ...
                num2str(sv, 17), spelled); %#ok<AGROW>
        end
    end
    value = did2.build.composite('dose', 'value', v);
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
% substance amount and count: spelling, slot, canonical field, factor
Q = { ...
    'mol',          'substance_amount', 'moles', 1; ...
    'mmol',         'substance_amount', 'moles', 1e-3; ...
    'umol',         'substance_amount', 'moles', 1e-6; ...
    [mu 'mol'],     'substance_amount', 'moles', 1e-6; ...
    'nmol',         'substance_amount', 'moles', 1e-9; ...
    'pmol',         'substance_amount', 'moles', 1e-12; ...
    'count',        'count',            'count', 1; ...
    'counts',       'count',            'count', 1};
hit = find(strcmp(Q(:, 1), spelling), 1);
if ~isempty(hit)
    [slot, canon, factor] = Q{hit, 2:4};
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

function s = unitSpelling(unit)
s = '';
if isstruct(unit) && ~isempty(unit) && isfield(unit, 'name')
    s = strtrim(char(unit.name));
elseif ischar(unit) || isstring(unit)
    s = strtrim(char(unit));
end
end

function t = unitTerm(unit)
if isstruct(unit)
    t = unit;
else
    t = jSourceUnit(unit);
end
end
