function [value, chemicals, conflicts, ingredientRows, placeholders, gaps] = jDoseValue(chemicals)
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
%   A MASS OR SUBSTANCE AMOUNT ON A ROW THAT NAMES A CHEMICAL is that
%   chemical's too (Jess Haley, 2026-10-21, "a"): it goes in its
%   `value.ingredients` entry (`.mass` / `.substance_amount`), and only a row
%   naming no chemical states a top-level mass (the whole formulation's).
%   AN AMOUNT PER BODY MASS IS ONE INGREDIENT'S (Jess Haley, 2026-10-21
%   [dose per ingredient], did-schema 959e6d5): Hunsberger's "1 mg/kg" is of
%   the alprazolam, not of the solution. Such a row becomes an entry of the
%   dose's `value.ingredients` ({amount_per_body_mass}), and INGREDIENTROWS
%   lists the CHEMICALS rows those entries describe, in order -- the caller
%   adds one `ingredient_id` edge per row to that row's chemical
%   (rule ingredients_match_edges). The top level then states the whole
%   formulation's amount; unrecorded, it is LEFT OUT and named in GAPS
%   (a {field, reason} struct array for the migration report's gaps of the dose):
%   'dose.value.volume' ([canonical absent only as needs info], Decided by
%   Jess Haley, 2026-10-30, did-schema V_eta_go_forward_class_audit.md: "an
%   amount the source never states ... is left out ... rather than written
%   as ... NaN (T14: missing is not a value)"; it was `volume.liters = NaN`
%   until then).
%   A PLACEHOLDER IS NOT AN AMOUNT (Jess Haley, 2026-10-21 [dose per
%   ingredient]): an amount per body mass on a VEHICLE row (saline,
%   EFO:0002677 -- Hunsberger's control group is written `saline, 1 mg/kg`,
%   copied from the drug group's row) is the amount of no active ingredient.
%   It is not made an ingredient amount and not a concentration: it is taken
%   off its row and listed in PLACEHOLDERS (a cellstr, one line each:
%   substance, number, unit) for the caller to report
%   (jTreatmentBodies: reportNote 'amount_placeholder'); with no other amount
%   the dose's volume is NaN.
%   No such row: the amount is unrecorded and is written as NaN in the
%   dose's volume:
%   `value.volume.liters = NaN` ("An unrecorded amount is written as NaN in
%   its quantity (e.g. a dose's volume.liters: NaN)", Jess Haley,
%   2026-10-21). NOT YET CHANGED by [canonical absent only as needs info]
%   (2026-10-30) where the NaN is ALL the dose states: left out, `value`
%   would be blank and rule value_inline_or_body (did-schema value.json,
%   checked by did2.build) refuses the dose -- the same question as the
%   all-blank formulation, docs/V2_PLAN.md G67, left to the team. The same
%   holds for the NaN canonical of a kind stated with no number, below. When no row gives a number but exactly one kind of amount
%   unit is stated, the NaN goes in THAT quantity, with the unit as
%   `source_unit` ("where the kind is known ... the NaN goes in that quantity
%   instead", Jess Haley, 2026-10-21 [unknown-amount-slot]). Whether NaN
%   survives a did2 write and read is DID-matlab
%   #218's work (testSqliteDbNonFinite); this function only writes it.

gaps = struct('field', {}, 'reason', {});
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
placeholders = {};
ingredientRows = [];
entryByRow = containers.Map('KeyType', 'double', 'ValueType', 'any');
% A per-body-mass row that NAMES a chemical but gives no number is that
% chemical's unrecorded amount: its value.ingredients entry, amount_per_body_mass
% NaN with the unit, paired with its ingredient_id edge -- not the dose's top
% level (Jess Haley, 2026-10-21 [blank per-body-mass on the ingredient]).
keepKind = true(size(kindOnly));
for i = 1:numel(kindOnly)
    k = kindOnly(i);
    c = chemicals(k);
    if strcmp(kindSlots{i, 1}, 'amount_per_body_mass') && namesChemical(c.substance) ...
            && ~isVehicle(c.substance)
        q = struct(kindSlots{i, 2}, NaN, 'source_unit', unitTerm(c.source_unit));
        entryByRow(k) = struct('amount_per_body_mass', q);
        ingredientRows(end+1) = k; %#ok<AGROW>
        chemicals(k).source_value = [];
        chemicals(k).source_unit = [];
        keepKind(i) = false;
    end
end
kindOnly = kindOnly(keepKind);
kindSlots = kindSlots(keepKind, :);
if ~isempty(hits) || ~isempty(ingredientRows)
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
        if strcmp(slot, 'amount_per_body_mass') && isVehicle(c.substance)
            % a vehicle's "amount per body mass" names no active ingredient
            placeholders{end+1} = sprintf('%s: %s %s', termName(c.substance), ...
                num2str(sv, 17), spelled); %#ok<AGROW>
            continue;
        end
        if strcmp(slot, 'amount_per_body_mass') || ...
                (any(strcmp(slot, {'mass', 'substance_amount'})) && namesChemical(c.substance))
            % one ingredient's own amount, not the formulation's: an amount per
            % body mass always; a mass or substance amount when the row NAMES a
            % chemical (Jess Haley, 2026-10-21, "a", refining [multiple amount
            % rows]). One entry per chemical row, its slots merged.
            e = struct();
            if isKey(entryByRow, k); e = entryByRow(k); end
            if ~isfield(e, slot)
                e.(slot) = q;
            end
            entryByRow(k) = e;
            if ~any(ingredientRows == k)
                ingredientRows(end+1) = k; %#ok<AGROW>
            end
            continue;
        end
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
    if isempty(fieldnames(v)) && ~isempty(kindOnly) && isscalar(unique(kindSlots(:, 1))) ...
            && ~strcmp(kindSlots{1, 1}, 'amount_per_body_mass')
        % the whole formulation's amount is unrecorded but its KIND is stated
        % ([unknown-amount-slot]): the NaN goes in that quantity
        c = chemicals(kindOnly(1));
        v.(kindSlots{1, 1}) = struct(kindSlots{1, 2}, NaN, 'source_unit', unitTerm(c.source_unit));
        for k = kindOnly
            chemicals(k).source_value = [];
            chemicals(k).source_unit = [];
        end
    elseif isempty(fieldnames(v)) && ~isempty(ingredientRows)
        % only per-ingredient amounts: the whole formulation's amount is
        % unrecorded. [canonical absent only as needs info] (Decided by Jess
        % Haley, 2026-10-30): left out and listed as a gap, not
        % `volume.liters = NaN`; `value` still states the ingredients
        gaps(end+1) = struct('field', 'dose.value.volume', 'reason', ...
            ['the source states each ingredient''s amount but not the amount ' ...
             'of the whole formulation given']);
    elseif isempty(fieldnames(v))
        % nothing else to state (every amount was a vehicle placeholder, which
        % the caller carries): NaN at the top level, as before -- left out,
        % `value` would be blank (header: G67)
        v.volume = struct('liters', NaN);
    end
    if ~isempty(ingredientRows)
        es = cell(1, numel(ingredientRows));
        for i = 1:numel(ingredientRows)
            es{i} = entryByRow(ingredientRows(i));
        end
        v.ingredients = did2.build.list(es{:});   % ragged entries, merged
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

function tf = isVehicle(substance)
% a vehicle carries no active ingredient: saline (EFO:0002677, the term the
% Hunsberger converter writes), or a substance named 'saline' / 'vehicle'
tf = false;
if ~isstruct(substance) || isempty(substance)
    return;
end
node = '';
if isfield(substance, 'node'); node = strtrim(char(substance.node)); end
if strcmpi(node, 'EFO:0002677')
    tf = true;
    return;
end
tf = any(strcmpi(termName(substance), {'saline', 'vehicle'}));
end

function n = termName(substance)
n = '';
if isstruct(substance) && ~isempty(substance) && isfield(substance, 'name')
    n = strtrim(char(substance.name));
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

function tf = namesChemical(substance)
% the row names a chemical: its substance term has a node or a name
tf = false;
if isstruct(substance) && ~isempty(substance)
    n = ''; m = '';
    if isfield(substance, 'node'); n = strtrim(char(substance.node)); end
    if isfield(substance, 'name'); m = strtrim(char(substance.name)); end
    tf = ~isempty(n) || ~isempty(m);
end
end
