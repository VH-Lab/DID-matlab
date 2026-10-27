function rows = treatmentRows(p)
%TREATMENTROWS The substances a treatment's formulation names, one row per
%   chemical in ingredient order, in mixtureRows' shape {node, name, value,
%   unode, uname}: the inverse of jMixtureTable + jDoseValue + jDoseBodies.
%
%   P is treatmentParts' output. For row k (the k-th `ingredient_id` of the
%   formulation):
%     node, name    the chemical's `value.substance`
%     value, unit   the formulation's k-th ingredient `concentration`
%                   (source_value, source_unit) when its source_value is a
%                   finite number; else the DOSE's own per-ingredient amount
%                   for that chemical (the dose's `value.ingredients` entry at
%                   the position of the dose's `ingredient_id` edge naming it:
%                   amount_per_body_mass, mass or substance_amount), which
%                   jDoseValue took off the row; else no value. A unit stated
%                   with no number (NaN) is kept with an empty value.
%
%   An amount jDoseValue placed on the dose itself (`value.volume`, `mass`,
%   ... with a finite source_value) belongs to a row it does not name; it is
%   not attributed here, and the round trip reports that row's value lost.
rows = struct('node', {}, 'name', {}, 'value', {}, 'unode', {}, 'uname', {});
ingredients = asCell(getIn(p.formulation, 'formulation', 'value', 'ingredients'));
doseIng = {};
doseIngIds = {};
if strcmp(p.kind, 'dose')
    doseIng = asCell(getIn(p.manip, 'dose', 'value', 'ingredients'));
    doseIngIds = edgeIds(p.manip, 'ingredient_id');
end
for k = 1:numel(p.chemicals)
    c = p.chemicals{k};
    [node, name] = termParts(getIn(c, 'chemical', 'value', 'substance'));
    value = [];
    unit = [];
    if k <= numel(ingredients)
        [value, unit] = amountOf(ingredients{k}, {'concentration'});
    end
    if isempty(value)
        cid = '';
        [v, ok] = getIn(c, 'base', 'id');
        if ok; cid = char(v); end
        j = find(strcmp(doseIngIds, cid), 1);
        if ~isempty(j) && j <= numel(doseIng)
            [v2, u2] = amountOf(doseIng{j}, {'amount_per_body_mass', 'mass', 'substance_amount'});
            if ~isempty(v2) || ~isempty(u2)
                value = v2;
                unit = u2;
            end
        end
    end
    [unode, uname] = termParts(unit);
    rows(end+1) = struct('node', node, 'name', name, 'value', value, ...
        'unode', unode, 'uname', uname); %#ok<AGROW>
end
end

function [value, unit] = amountOf(entry, slots)
value = [];
unit = [];
for s = 1:numel(slots)
    [q, ok] = getIn(entry, slots{s});
    if ~ok || ~isstruct(q); continue; end
    [sv, okv] = getIn(q, 'source_value');
    [su, oku] = getIn(q, 'source_unit');
    if okv
        value = numberOf(sv);
    end
    if oku
        unit = su;
    end
    if ~isempty(value) || ~isempty(unit)
        return;
    end
end
end
