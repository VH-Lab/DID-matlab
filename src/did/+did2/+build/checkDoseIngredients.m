function checkDoseIngredients(dose, formulation)
%CHECKDOSEINGREDIENTS A dose names only ingredients of its own formulation.
%
%   did2.build.checkDoseIngredients(DOSE, FORMULATION) raises
%   did2:build:ruleViolated unless
%     * DOSE's `formulation_id` edge names FORMULATION (its base.id), and
%     * every `ingredient_id` edge on DOSE is also an `ingredient_id` edge of
%       FORMULATION.
%   This is the did-schema dose rule `ingredient_in_formulation` (Jess Haley,
%   2026-10-21 [dose per ingredient]): "each ingredient_id on a dose must be
%   one of the ingredients of the dose's formulation". The rule needs the
%   formulation document, which did2.build.statement/document do not have, so
%   checkRules does not run it; a caller that builds both (a migrator, an
%   import) calls this. DOSE and FORMULATION are built document structs
%   (did2.build.*) or did2.document objects.
%
%   See also did2.build.statement, did2.build.document.

arguments
    dose
    formulation
end

dose = asStruct(dose);
formulation = asStruct(formulation);
fid = char(formulation.base.id);
named = edgeIds(dose, 'formulation_id');
if ~isequal(named, {fid})
    error('did2:build:ruleViolated', ...
        ['ingredient_in_formulation (dose %s): its formulation_id names %s, ' ...
         'not the formulation given (%s).'], char(dose.base.id), ...
        strjoin(named, ', '), fid);
end
mine = edgeIds(dose, 'ingredient_id');
theirs = edgeIds(formulation, 'ingredient_id');
missing = setdiff(mine, theirs, 'stable');
if ~isempty(missing)
    error('did2:build:ruleViolated', ...
        ['ingredient_in_formulation (dose %s): ingredient_id %s is not an ' ...
         'ingredient_id of formulation %s.'], char(dose.base.id), ...
        strjoin(missing, ', '), fid);
end
end

function s = asStruct(d)
if isa(d, 'did2.document')
    s = d.documentProperties;
else
    s = d;
end
end

function ids = edgeIds(doc, name)
ids = {};
if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
for k = 1:numel(doc.depends_on)
    if iscell(doc.depends_on)
        d = doc.depends_on{k};
    else
        d = doc.depends_on(k);
    end
    if ~strcmp(char(d.name), name)
        continue;
    end
    v = '';
    if isfield(d, 'document_id')
        v = d.document_id;
    elseif isfield(d, 'value')
        v = d.value;
    end
    if ~isempty(v)
        ids{end+1} = char(v); %#ok<AGROW>
    end
end
end
