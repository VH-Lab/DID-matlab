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
%       source_unit   '' or the source's unit spelling, or a term {node, name}
%   Each becomes a `chemical` {substance}, listed as an ingredient.
%
%   [canonical absent only as needs info] (Decided by Jess Haley, 2026-10-30,
%   did-schema V_eta_go_forward_class_audit.md): "every quantity holds exactly
%   one canonical value; it may be absent only when the document's
%   `needs_info` names it ...: a source number with no unit (v1 treatment
%   amounts, DID-matlab `jDoseBodies.m`), or an amount the source never
%   states, which is left out (the ingredient is still listed) rather than
%   written as `source_value` NaN (T14: missing is not a value)." So, per
%   ingredient k:
%     - a number with NO unit: `concentration` {source_value}, no canonical,
%       and a base.needs_info entry for the canonical,
%       'formulation.value.ingredients(k).concentration.canonical' (a
%       concentration has no single canonical field, and nothing says which
%       one this number is);
%     - NO number: the entry has no amount, and a base.needs_info entry names
%       'formulation.value.ingredients(k).concentration'. A unit stated with
%       no number is still not written, as before (it was dropped beside the
%       NaN too);
%     - a number WITH a concentration unit jSourceUnit knows (kind
%       'concentration': Molar, molar, M): `concentration` {molar,
%       source_value, source_unit}, the canonical `molar` the number times the
%       row's factor. A unit given as a term (jMixtureTable) is looked up by
%       its NAME, as jDoseValue's amountSlot does: NDI's writers name molar
%       'Molar' under the node OM:MolarVolumeUnit, which is not molar (OM's
%       molar volume unit), so the node is not read; the term is kept as the
%       source wrote it (the round trip restates it);
%     - a number with any OTHER unit: jTreatmentBodies has already carried
%       the document (carry-155: "A unit spelling the migrator does not
%       recognise is carried for mapping, not written without a canonical").
%       A virus injection's dilution is a number with NO unit (above):
%       [virus dilution needs info] (Decided by Jess Haley, 2026-10-31,
%       docs/V2_PLAN.md G71).
%
%   AN ALL-EMPTY FORMULATION. When NO ingredient states an amount, every
%   entry is empty and `value` is blank; each entry's missing amount is named
%   in needs_info as above, and the value rule (value_inline_or_body) accepts
%   a blank value that needs_info names: [formulation amount needs info]
%   (Decided by Jess Haley, 2026-10-31, did-schema
%   did_v2_go_forward_class_audit.md; docs/V2_PLAN.md G67 (a)). The NaN this
%   case wrote before is gone.
%
%   The formulation is what a DOSE names (`formulation_id`) and what an
%   IMMERSION is valued by (`value_id`), so jTreatmentBodies uses it for both.
%   An amount a dose takes off a row (jDoseValue) is no longer on that row
%   when it arrives here.
%
%   DOCS = {chemical..., formulation}; FORMULATIONID the formulation's id.

docs = {};
ids = cell(1, numel(chemicals));
entries = cell(1, numel(chemicals));
needsInfo = struct('field', {}, 'reason', {});
for k = 1:numel(chemicals)
    c = chemicals(k);
    o = jOpts(preBody);
    chem = did2.build.document('chemical', ...
        struct('value', struct('substance', c.substance)), o{:});
    docs{end+1} = chem; %#ok<AGROW>
    ids{k} = chem.base.id;
    e = struct();
    path = sprintf('formulation.value.ingredients(%d).concentration', k);
    if isfield(c, 'source_value') && ~isempty(c.source_value) ...
            && isnumeric(c.source_value) && isfinite(c.source_value(1))
        conc = struct('source_value', double(c.source_value(1)));
        if isfield(c, 'source_unit') && isstruct(c.source_unit) && ~isempty(c.source_unit)
            conc.source_unit = c.source_unit;          % already a term (jMixtureTable)
            conc = withMolar(conc, c.source_unit);
        elseif isfield(c, 'source_unit') && ~isempty(c.source_unit)
            conc.source_unit = jSourceUnit(c.source_unit);
            conc = withMolar(conc, c.source_unit);
        else
            % a number with no unit: no canonical can be computed
            needsInfo(end+1) = struct('field', [path '.canonical'], 'reason', ...
                sprintf(['the source states the number %s with no unit, so no ' ...
                'canonical value is computed'], num2str(double(c.source_value(1)), 17))); %#ok<AGROW>
        end
        e.concentration = conc;
    else
        % the source lists the ingredient but gives no amount: left out
        needsInfo(end+1) = struct('field', path, 'reason', ...
            'the source lists this ingredient but states no amount'); %#ok<AGROW>
    end
    entries{k} = e;
end
extra = {};
if ~isempty(needsInfo)
    extra = {'NeedsInfo', needsInfo};
end
o = jOpts(preBody, 'Edges', struct('ingredient_id', {ids}), extra{:});
f = did2.build.document('formulation', ...
    struct('value', struct('ingredients', {entries})), o{:});
docs{end+1} = f;
formulationId = f.base.id;
% counted, as probe_geometry counts its coordinate system's
for k = 1:numel(needsInfo)
    did2.convert.reportNote('needs_info', char(preBody.document_class.class_name), ...
        char(preBody.base.id), needsInfo(k).field);
end
end

function conc = withMolar(conc, unit)
%WITHMOLAR The canonical `molar` of a concentration whose unit jSourceUnit
%   knows as a concentration ([canonical absent only as needs info], Jess
%   Haley, 2026-10-30; carry-155 resolved by a unit-table row). UNIT is the
%   source's spelling or a term {node, name}; a term is read by its name.
%   Any other unit leaves CONC as it is.
spelling = '';
if isstruct(unit) && isfield(unit, 'name')
    spelling = strtrim(char(unit.name));
elseif ischar(unit) || isstring(unit)
    spelling = strtrim(char(unit));
end
[~, factor, kind] = jSourceUnit(spelling);
if strcmp(kind, 'concentration') && ~isempty(factor)
    conc.molar = conc.source_value * factor;
end
end
