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
%                  source's amount, else NaN in `volume.liters`).
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
        unplaced = {['needs_mapping: manipulation (immersion | dose); decided ' ...
            'by where the treatment was given, in its dataset']};
        docs = {};
        return;
    case 'needs_mapping'
        unplaced = {['needs_mapping: manipulation (dose | exposure | ' ...
            'temperature); decided by what the treatment''s location (not an ' ...
            'UBERON body site) means in its dataset']};
        docs = {};
        return;
    case 'immersion'
        [parts, formulationId] = jDoseBodies(preBody, chemicals);
        % `formulation_manipulation` is no class: did2.build reads it as the
        % direction `manipulation` with the value kind `formulation`.
        manip = jStatement(preBody, 'manipulation', jSubjectOf(preBody), ...
            variable, [], 'TimeReferenceIds', {anchorId}, 'ValueId', formulationId, ...
            'Id', id, extra{:}, 'ValueKind', 'formulation');
    otherwise
        [value, chemicals, conflicts, ingredientRows, placeholders] = jDoseValue(chemicals);
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
            unplaced = [cellfun(@(t) ['vehicle amount placeholder: ' char(t)], ...
                reshape(placeholders, 1, []), 'UniformOutput', false), ...
                cellfun(@(t) ['conflicting amount: ' char(t)], ...
                reshape(conflicts, 1, []), 'UniformOutput', false)];
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
        manip = jStatement(preBody, 'manipulation', jSubjectOf(preBody), ...
            variable, value, 'TimeReferenceIds', {anchorId}, ...
            'Edges', edges, 'Id', id, extra{:}, 'ValueKind', 'dose');
        if strcmp(route, 'unknown')
            did2.convert.reportNote('route_unknown', ...
                char(preBody.document_class.class_name), id);
        end
end
docs = [{manip}, parts];
end
