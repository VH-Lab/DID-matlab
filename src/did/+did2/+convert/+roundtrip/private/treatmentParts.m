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
%     subject     the subject's id: the manipulation's `entity_id`, or, when
%                 that names a region part among BODIES, the part's `part_of`
%                 parent ([region parts]; did2.convert.regionPart)
%     part        the region part entity the manipulation is about ([] when
%                 it is about the subject)
%     site        the term statement that names the site: the part's
%                 anatomical-structure (kind) assertion (UBERON:0000061), or
%                 the `observation` about the subject whose variable is
%                 NCIT:C13717 "Anatomic Site" (a side another document
%                 gives, which stays about the subject: [side said about
%                 its region]); either holds the
%                 site's term at `term.value`
%     laterality  the part's Laterality assertion (NCIT:C25185), when it has one
%     relations   every `directed_relation`
%     unplaced    cellstr: a document no role claims, or a named edge whose
%                 document is not among BODIES
%
%   Every field is [] / {} when absent.

p = struct('manip', [], 'kind', '', 'anchor', [], 'formulation', [], ...
    'chemicals', {{}}, 'subject', '', 'part', [], 'site', [], 'laterality', [], ...
    'age', [], 'relations', {{}}, 'unplaced', {{}});
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
if ~isempty(entity)
    p.subject = entity{1};
end
% a region part: the manipulation is about the part, the part is `part_of` the
% subject, and its kind assertion names the site ([region parts], [site
% scaffolding not a loss] (2); did2.convert.regionPart)
if isscalar(entity)
    hit = find(strcmp(ids, entity{1}) & ~used, 1);
    if ~isempty(hit) && strcmp(classNameOf(bodies{hit}), 'entity')
        p.part = bodies{hit};
        used(hit) = true;
        for k = 1:n
            if used(k); continue; end
            b = bodies{k};
            switch classNameOf(b)
                case 'directed_relation'
                    if isequal(edgeIds(b, 'child_id'), entity)
                        parent = edgeIds(b, 'parent_id');
                        if ~isempty(parent); p.subject = parent{1}; end
                        used(k) = true;
                    end
                case 'assertion'
                    if ~isequal(edgeIds(b, 'entity_id'), entity); continue; end
                    [node, ~] = termParts(getIn(b, 'statement', 'variable'));
                    if isempty(p.site) && sameCurie(node, 'UBERON:0000061')
                        p.site = b;
                        used(k) = true;
                    elseif isempty(p.laterality) && sameCurie(node, 'NCIT:C25185')
                        p.laterality = b;
                        used(k) = true;
                    end
            end
        end
    end
end
subject = entity;   % the age and a side are about the subject
if ~isempty(p.part)
    subject = {p.subject};
end
for k = 1:n
    if used(k); continue; end
    b = bodies{k};
    switch classNameOf(b)
        case 'observation'
            [node, ~] = termParts(getIn(b, 'statement', 'variable'));
            if isempty(p.site) && sameCurie(node, 'NCIT:C13717') ...
                    && isequal(edgeIds(b, 'entity_id'), subject)
                p.site = b;
                used(k) = true;
            elseif isempty(p.age) && sameCurie(node, 'NCIT:C25150') ...
                    && isequal(edgeIds(b, 'entity_id'), subject) ...
                    && isequal(edgeIds(b, 'time_reference_id'), tr)
                % [age at injection is an observation] (Jess Haley,
                % 2026-10-27): the subject's age, on the manipulation's time
                % reference ([age is NCIT Age], 2026-10-30)
                p.age = b;
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
