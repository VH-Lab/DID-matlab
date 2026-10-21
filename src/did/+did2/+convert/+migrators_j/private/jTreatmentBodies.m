function [docs, route] = jTreatmentBodies(preBody, variable, chemicals, locationTerm, anchorId, options)
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
%     'exposure'   the same shape, for Babu's agar plate medium / ambient air
%                  (Jess Haley, 2026-10-21 [babu-media]).
%     'dose'       a `dose_manipulation` whose `formulation_id` names the
%                  formulation and whose value is the amount (jDoseValue: the
%                  source's amount, else NaN in `volume.liters`).
%     'unknown'    the same dose, and a `route_unknown` note in the migration
%                  report (did2.convert.reportNote).
%
%   Options:
%     'AlwaysDose'  route as a dose whatever the location, never noted as
%                   route_unknown. No caller sets it since virus_injection
%                   follows the location rule (Jess Haley, 2026-10-21
%                   [virus-location]).
%     'Notes'       the manipulation's notes.
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
end

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

switch route
    case {'immersion', 'exposure'}
        [parts, formulationId] = jDoseBodies(preBody, chemicals);
        % `formulation_manipulation` is no class: did2.build reads it as the
        % direction `manipulation` with the value kind `formulation`.
        manip = jStatement(preBody, 'formulation_manipulation', jSubjectOf(preBody), ...
            variable, [], 'TimeReferenceIds', {anchorId}, 'ValueId', formulationId, ...
            'Id', id, extra{:});
    otherwise
        [value, chemicals] = jDoseValue(chemicals);
        [parts, formulationId] = jDoseBodies(preBody, chemicals);
        manip = jStatement(preBody, 'dose_manipulation', jSubjectOf(preBody), ...
            variable, value, 'TimeReferenceIds', {anchorId}, ...
            'Edges', struct('formulation_id', formulationId), 'Id', id, extra{:});
        if strcmp(route, 'unknown')
            did2.convert.reportNote('route_unknown', ...
                char(preBody.document_class.class_name), id);
        end
end
docs = [{manip}, parts];
end
