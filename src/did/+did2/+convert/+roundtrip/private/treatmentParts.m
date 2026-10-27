function p = treatmentParts(bodies)
%TREATMENTPARTS The documents a treatment-family migrator emitted, by role.
%
%   P = treatmentParts(BODIES), BODIES the emitted document structs of ONE v1
%   treatment, treatment_drug, treatment_transfer or virus_injection
%   (did2.convert.migrators_j: jTreatmentBodies, jDoseBodies,
%   jTreatmentAnchor). Roles, each found by the edge that names it:
%
%     manip       the `manipulation` (the first one; it keeps the v1 id)
%     kind        its value kind (did2.convert.statementKind): 'dose',
%                 'formulation' (an immersion), 'term', 'time', ...
%     anchor      the time reference its first `time_reference_id` names
%     formulation the formulation its `formulation_id` (a dose) or `value_id`
%                 (an immersion) names
%     chemicals   the chemicals the formulation's `ingredient_id` edges name,
%                 in edge order (jDoseBodies writes them in mixture-row order)
%     site        the `observation` about the same entity whose variable is
%                 NCIT:C13717 "Anatomic Site" (the Path S site, D3)
%     relations   every `directed_relation`
%     unplaced    cellstr: a document no role claims, or a named edge whose
%                 document is not among BODIES
%
%   Every field is [] / {} when absent.

p = struct('manip', [], 'kind', '', 'anchor', [], 'formulation', [], ...
    'chemicals', {{}}, 'site', [], 'relations', {{}}, 'unplaced', {{}});
n = numel(bodies);
used = false(1, n);
ids = cell(1, n);
for k = 1:n
    ids{k} = '';
    [v, ok] = getIn(bodies{k}, 'base', 'id');
    if ok && ~isempty(v); ids{k} = char(v); end
end

for k = 1:n
    if strcmp(classNameOf(bodies{k}), 'manipulation')
        p.manip = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(p.manip)
    p.unplaced{end+1} = 'no manipulation was emitted';
    return;
end
[~, p.kind] = did2.convert.statementKind(p.manip);

tr = edgeIds(p.manip, 'time_reference_id');
if ~isempty(tr)
    [p.anchor, used, p.unplaced] = claim(tr{1}, 'time reference', ids, bodies, used, p.unplaced);
end
fid = edgeIds(p.manip, 'formulation_id');
if isempty(fid)
    fid = edgeIds(p.manip, 'value_id');
end
if ~isempty(fid)
    [p.formulation, used, p.unplaced] = claim(fid{1}, 'formulation', ids, bodies, used, p.unplaced);
end
if ~isempty(p.formulation)
    ing = edgeIds(p.formulation, 'ingredient_id');
    for i = 1:numel(ing)
        [c, used, p.unplaced] = claim(ing{i}, 'chemical', ids, bodies, used, p.unplaced);
        p.chemicals{end+1} = c;
    end
end
entity = edgeIds(p.manip, 'entity_id');
for k = 1:n
    if used(k); continue; end
    b = bodies{k};
    switch classNameOf(b)
        case 'observation'
            [node, ~] = termParts(getIn(b, 'statement', 'variable'));
            if isempty(p.site) && sameCurie(node, 'NCIT:C13717') ...
                    && isequal(edgeIds(b, 'entity_id'), entity)
                p.site = b;
                used(k) = true;
            end
        case 'directed_relation'
            p.relations{end+1} = b;
            used(k) = true;
    end
end
for k = find(~used)
    p.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a treatment', ...
        k, classNameOf(bodies{k}));
end
end

function [doc, used, unplaced] = claim(id, role, ids, bodies, used, unplaced)
doc = [];
hit = find(strcmp(ids, id), 1);
if isempty(hit)
    unplaced{end+1} = sprintf('the %s %s the manipulation names was not emitted', role, id);
    return;
end
doc = bodies{hit};
used(hit) = true;
end
