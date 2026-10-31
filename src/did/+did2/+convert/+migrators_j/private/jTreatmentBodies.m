function [docs, route, unplaced] = jTreatmentBodies(preBody, variable, chemicals, locationTerm, anchorId, options)
%JTREATMENTBODIES The manipulation a v1 substance treatment becomes, routed
%   by its recorded location, plus the chemical and formulation documents.
%
%   [DOCS, ROUTE] = jTreatmentBodies(PREBODY, VARIABLE, CHEMICALS,
%   LOCATIONTERM, ANCHORID, ...) for treatment (substance branch),
%   treatment_drug and virus_injection. DOCS = {manipulation, chemical...,
%   formulation}, the manipulation FIRST and carrying the source id; the
%   caller adds the anchor and the location observation. ROUTE is
%   jTreatmentRoute's answer (or 'dose' when 'AlwaysDose' is set).
%
%     'immersion'  a `manipulation` whose value kind is `formulation`, with an
%                  empty `value` and a `value_id` edge to the formulation -- the
%                  shape resolveDeferredBaths writes for a stimulus_bath
%                  (DID-matlab ff6d542). No amount: the subject sat in it.
%     'needs_mapping'  a non-body (non-UBERON) location (jTreatmentRoute):
%                  nothing is built; DOCS is {} and UNPLACED is the `needs_mapping:` note
%                  naming the V2 homes, so the caller carries the document
%                  whole as v1 ([one correct reading], [dataset audit batch 1
%                  and 2] (2), Jess Haley, 2026-10-26).
%     'dose'       a `dose_manipulation` whose `formulation_id` names the
%                  formulation and whose value is the amount (jDoseValue: the
%                  source's amount; with only ingredient amounts, the whole
%                  formulation's amount named in base.needs_info
%                  ([canonical absent only as needs info], 2026-10-30);
%                  with none, NaN in `volume.liters`).
%     'unknown'    no location: nothing is built; UNPLACED is a
%                  `needs_mapping:` note and the caller carries the document
%                  whole as v1 ([one-reading quick answers] (Q1), Jess Haley,
%                  2026-10-26; it was a NaN-amount dose noted route_unknown).
%   A dose whose rows give two DIFFERENT amounts of one kind keeps the first
%   and leaves a `dose_amount_conflict` note per other (jDoseValue).
%   A vehicle row's amount per body mass (saline `1 mg/kg`) is not an amount:
%   an `amount_placeholder` note per row (jDoseValue).
%
%   UNPLACED (third output). Since [generic stage is lossless] and [partly
%   placed is carried as v1] (Jess Haley, 2026-10-25, did-schema
%   V_eta_go_forward_class_audit.md) a dose whose rows include a vehicle
%   placeholder amount, or two disagreeing amounts of one kind, is NOT built:
%   the placeholder amount and the second amount would be written nowhere.
%   DOCS is {} and UNPLACED names each such row (the jDoseValue text); the
%   caller carries the source document whole as v1. Empty when everything is
%   placed.
%
%   A CONCENTRATION UNIT THE UNIT TABLE DOES NOT KNOW is carried too
%   (carry-155; Decided by Jess Haley, 2026-10-30 [canonical absent only as
%   needs info], did-schema V_eta_go_forward_class_audit.md: "A unit spelling
%   the migrator does not recognise is carried for mapping, not written
%   without a canonical."). A row with a finite number and a unit, still on
%   its row when the formulation is built (not taken by jDoseValue as an
%   amount), is an ingredient's concentration; when jSourceUnit does not know
%   its unit (by name) as a concentration (Molar, molar, M), nothing is built
%   and UNPLACED names the row. A virus injection's `dilution` is a number
%   with NO unit, not a unit the table fails to know: jDoseBodies names its
%   canonical in needs_info ([virus dilution needs info], Decided by Jess
%   Haley, 2026-10-31, did-schema did_v2_go_forward_class_audit.md;
%   docs/V2_PLAN.md G71), and it is not carried.
%
%   Options:
%     'AlwaysDose'  route as a dose whatever the location, never noted as
%                   route_unknown. No caller sets it since virus_injection
%                   follows the location rule (Jess Haley, 2026-10-21
%                   [virus-location]).
%     'Notes'       the manipulation's notes.
%     'Conditions'  the manipulation's `conditions` (did2.build.condition),
%                   e.g. a generic treatment's unlabelled number (treatment.m).
%
%   Decided by Jess Haley, 2026-10-21; the decision is quoted in
%   jTreatmentRoute.

arguments
    preBody (1,1) struct
    variable
    chemicals struct
    locationTerm
    anchorId
    options.AlwaysDose (1,1) logical = false
    options.Notes = ''
    options.Conditions = []
end

unplaced = {};
if options.AlwaysDose
    route = 'dose';
else
    route = jTreatmentRoute(locationTerm);
end
id = char(preBody.base.id);
extra = {};
if ~isempty(options.Notes)
    extra = {'Notes', options.Notes};
end
if ~isempty(options.Conditions)
    extra = [extra, {'Conditions', options.Conditions}];
end

switch route
    case 'unknown'
        % [one-reading quick answers] (Q1) (Decided by Jess Haley, 2026-10-26):
        % a treatment with no recorded location is carried as v1 instead of
        % becoming a dose with a NaN amount -- immersion or dose is decided by
        % where it was given, which the document does not say.
        unplaced = {[treatmentRow(preBody, '[carry-023] ', '[carry-027] ', '[carry-029] ') ...
            'needs_mapping: manipulation (immersion | dose); decided ' ...
            'by where the treatment was given, in its dataset']};
        docs = {};
        return;
    case 'needs_mapping'
        unplaced = {[treatmentRow(preBody, '[carry-024] ', '[carry-028] ', '[carry-030] ') ...
            'needs_mapping: manipulation (dose | exposure | ' ...
            'temperature); decided by what the treatment''s location (not an ' ...
            'UBERON body site) means in its dataset']};
        docs = {};
        return;
    case 'immersion'
        unplaced = unknownConcentrationUnits(preBody, chemicals);
        if ~isempty(unplaced)
            docs = {};
            return;
        end
        [parts, formulationId] = jDoseBodies(preBody, chemicals);
        % `formulation_manipulation` is no class: did2.build reads it as the
        % direction `manipulation` with the value kind `formulation`.
        manip = jStatement(preBody, 'manipulation', jSubjectOf(preBody), ...
            variable, [], 'TimeReferenceIds', {anchorId}, 'ValueId', formulationId, ...
            'Id', id, extra{:}, 'ValueKind', 'formulation');
    otherwise
        [value, chemicals, conflicts, ingredientRows, placeholders, needsInfo] = jDoseValue(chemicals);
        % a vehicle's per-body-mass number (Hunsberger saline `1 mg/kg`) is a
        % placeholder, not an amount (Jess Haley, 2026-10-21 [dose per
        % ingredient]); two rows of one amount kind that disagree (Jess Haley,
        % 2026-10-21, "a"). Each is still noted, as before.
        for k = 1:numel(placeholders)
            did2.convert.reportNote('amount_placeholder', ...
                char(preBody.document_class.class_name), id, placeholders{k});
        end
        for k = 1:numel(conflicts)
            did2.convert.reportNote('dose_amount_conflict', ...
                char(preBody.document_class.class_name), id, conflicts{k});
        end
        % [generic stage is lossless]: the placeholder amount and the second,
        % disagreeing amount would be written nowhere, so the dose is not
        % built and the caller carries the document whole as v1 (header,
        % UNPLACED). This used to keep the first amount and write the dose.
        if ~isempty(placeholders) || ~isempty(conflicts)
            % a conflict cites carry-071 (treatment), carry-031
            % (treatment_drug) or carry-073 (virus_injection); a vehicle
            % placeholder carry-070, carry-057 ([vehicle rate needs a map],
            % Jess Haley, 2026-10-26) or carry-072
            conflictRow = treatmentRow(preBody, '[carry-071] ', '[carry-031] ', '[carry-073] ');
            placeholderRow = treatmentRow(preBody, '[carry-070] ', '[carry-057] ', '[carry-072] ');
            unplaced = [cellfun(@(t) [placeholderRow 'vehicle amount placeholder: ' char(t)], ...
                reshape(placeholders, 1, []), 'UniformOutput', false), ...
                cellfun(@(t) [conflictRow 'conflicting amount: ' char(t)], ...
                reshape(conflicts, 1, []), 'UniformOutput', false)];
            docs = {};
            return;
        end
        % the rows jDoseValue took as amounts are off; what still has a
        % number and a unit is an ingredient's concentration
        unplaced = unknownConcentrationUnits(preBody, chemicals);
        if ~isempty(unplaced)
            docs = {};
            return;
        end
        [parts, formulationId] = jDoseBodies(preBody, chemicals);
        % one ingredient_id edge per value.ingredients entry, to that row's
        % chemical (jDoseBodies emits the chemicals first, in row order)
        edges = struct('formulation_id', formulationId);
        if ~isempty(ingredientRows)
            ingIds = cellfun(@(r) char(parts{r}.base.id), num2cell(ingredientRows), ...
                'UniformOutput', false);
            edges.ingredient_id = ingIds;
        end
        % [canonical absent only as needs info] (Decided by Jess Haley,
        % 2026-10-30): an amount the source never states is named in
        % needs_info (jDoseValue), one `needs_info` note each
        niOpt = {};
        if ~isempty(needsInfo)
            niOpt = {'NeedsInfo', needsInfo};
        end
        manip = jStatement(preBody, 'manipulation', jSubjectOf(preBody), ...
            variable, value, 'TimeReferenceIds', {anchorId}, ...
            'Edges', edges, 'Id', id, extra{:}, niOpt{:}, 'ValueKind', 'dose');
        for k = 1:numel(needsInfo)
            did2.convert.reportNote('needs_info', ...
                char(preBody.document_class.class_name), id, needsInfo(k).field);
        end
        if strcmp(route, 'unknown')
            did2.convert.reportNote('route_unknown', ...
                char(preBody.document_class.class_name), id);
        end
end
docs = [{manip}, parts];
end

function tag = treatmentRow(preBody, treatmentTag, drugTag, virusTag)
%TREATMENTROW The carry register row tag ('[carry-NNN] ', [carry register],
%   Jess Haley, 2026-10-26, did-schema schemas/V_eta_carry_register.json) for
%   this document's v1 class: TREATMENTTAG for a `treatment`, DRUGTAG for a
%   `treatment_drug`, VIRUSTAG for a `virus_injection` (each register row names
%   one v1 class). '' for any other class, or where the register has no row
%   (an empty tag argument).
tag = '';
cn = '';
if isfield(preBody, 'document_class') && isstruct(preBody.document_class) ...
        && isfield(preBody.document_class, 'class_name')
    cn = char(preBody.document_class.class_name);
end
switch cn
    case 'treatment'
        tag = treatmentTag;
    case 'treatment_drug'
        tag = drugTag;
    case 'virus_injection'
        tag = virusTag;
end
end

function unplaced = unknownConcentrationUnits(preBody, chemicals)
%UNKNOWNCONCENTRATIONUNITS One carry-155 line per row whose concentration
%   unit jSourceUnit does not know (header). {} when there is none.
unplaced = {};
for k = 1:numel(chemicals)
    c = chemicals(k);
    if ~isfield(c, 'source_value') || isempty(c.source_value) ...
            || ~isnumeric(c.source_value) || ~isfinite(c.source_value(1))
        continue;
    end
    spelling = '';
    if isfield(c, 'source_unit')
        u = c.source_unit;
        if isstruct(u) && ~isempty(u) && isfield(u, 'name')
            spelling = strtrim(char(u.name));
        elseif ischar(u) || isstring(u)
            spelling = strtrim(char(u));
        end
    end
    if isempty(spelling)
        continue;           % no unit: jDoseBodies names it in needs_info
    end
    [~, factor, kind] = jSourceUnit(spelling);
    if strcmp(kind, 'concentration') && ~isempty(factor)
        continue;
    end
    unplaced{end+1} = sprintf(['[carry-155] needs_mapping: %s row %d (%s) ' ...
        'concentration unit "%s" (no concentration unit is known for it; ' ...
        '[canonical absent only as needs info])'], className(preBody), k, ...
        substanceName(c), spelling); %#ok<AGROW>
end
end

function n = className(preBody)
n = '';
if isfield(preBody, 'document_class') && isstruct(preBody.document_class) ...
        && isfield(preBody.document_class, 'class_name')
    n = char(preBody.document_class.class_name);
end
end

function n = substanceName(c)
n = '';
if isfield(c, 'substance') && isstruct(c.substance) && ~isempty(c.substance) ...
        && isfield(c.substance, 'name')
    n = strtrim(char(c.substance.name));
end
end
