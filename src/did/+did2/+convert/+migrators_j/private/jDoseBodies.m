function [docs, formulationId] = jDoseBodies(preBody, chemicals)
%JDOSEBODIES The chemical and formulation documents a migrated dose names.
%
%   [DOCS, FORMULATIONID] = jDoseBodies(PREBODY, CHEMICALS). did-schema #88
%   requires a dose to name what was given: `dose.formulation_id` is a required
%   edge to a standalone `formulation` document (#73 item 59), whose
%   `ingredient_id` edges name one `chemical` document per substance, with
%   `value.ingredients` one entry per edge in the same order. The pre-#73 dose
%   carried all of this inline (`dose.value.formulation.chemicals`).
%
%   CHEMICALS is a struct array with fields
%       substance     an ontology term {node, name}
%       source_value  [] or the number the source gave for it
%       source_unit   '' or the source's unit spelling
%   Each becomes a `chemical` {substance}. Its amount, when the source gave
%   one, is the ingredient entry's `concentration` with `source_value` (and
%   `source_unit` as a term, jSourceUnit) and NO canonical value: the v1
%   treatment documents state no unit the canonical could be computed from.
%   A substance with no amount gets an empty ingredient entry (every field of
%   an entry is optional; the entry must exist, one per edge).
%
%   DOCS = {chemical..., formulation}; FORMULATIONID the formulation's id.

docs = {};
ids = cell(1, numel(chemicals));
entries = cell(1, numel(chemicals));
for k = 1:numel(chemicals)
    c = chemicals(k);
    o = jOpts(preBody);
    chem = did2.build.document('chemical', ...
        struct('value', struct('substance', c.substance)), o{:});
    docs{end+1} = chem; %#ok<AGROW>
    ids{k} = chem.base.id;
    e = struct();
    if isfield(c, 'source_value') && ~isempty(c.source_value) ...
            && isnumeric(c.source_value) && isfinite(c.source_value(1))
        conc = struct('source_value', double(c.source_value(1)));
        if isfield(c, 'source_unit') && ~isempty(c.source_unit)
            conc.source_unit = jSourceUnit(c.source_unit);
        end
        e.concentration = conc;
    end
    entries{k} = e;
end
o = jOpts(preBody, 'Edges', struct('ingredient_id', {ids}));
f = did2.build.document('formulation', ...
    struct('value', struct('ingredients', {entries})), o{:});
docs{end+1} = f;
formulationId = f.base.id;
end
