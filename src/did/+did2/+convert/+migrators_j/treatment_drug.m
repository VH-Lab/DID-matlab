function v2Body = treatment_drug(preBody)
%TREATMENT_DRUG Brainstorm-J migrator: did_v1 treatment_drug -> an immersion
%   (`manipulation` valued by its formulation) or a dose_manipulation, decided
%   by the recorded location.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J has no `injection` class (D8). The administered substance(s)
%   become `chemical` documents named by a `formulation` (jDoseBodies), the
%   primary drug is the spine `subject_statement.variable`, and the location
%   decides the leaf (jTreatmentRoute; Jess Haley, 2026-10-21):
%
%     bath (NCIm:C0179246)  an IMMERSION: a `manipulation` whose value is the
%                           formulation, through `value_id`. No location
%                           observation -- "bath" is where the subject sat, not
%                           a site on it, and the leaf already says so.
%     any other location    a DOSE: `dose_manipulation`, its amount the
%                           mixture row's when that row is in an amount unit
%                           (Hunsberger: mg/kg), else NaN in `volume.liters`
%                           (jDoseValue); the site is Path S -- a merely-located
%                           site becomes a `term_observation` here (D3), an
%                           attributed site is promoted by the NDI second pass.
%     no location           a dose with a NaN amount, listed in the migration
%                           report as `route_unknown` (did2.convert.reportNote).
%
%   1 -> N: the manipulation, one chemical per mixture row, the formulation
%   and the anchor, plus the site observation for a dose at a site.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment_drug') || ~isstruct(preBody.treatment_drug)
    error('did2:convert:missingBlock', ...
        'treatment_drug body is missing the treatment_drug property block.');
end
block = preBody.treatment_drug;

chemicals = jMixtureTable(jGetChar(block, 'mixture_table'));
variable  = chemicals(1).substance;   % the primary drug is the spine identity

siteTerm = jOntologyTerm( ...
    jGetCharAny(block, {'location_ontology_node', 'location_ontologyNode'}), ...
    jGetCharAny(block, {'location_name'}));
anchor = jSessionAnchor(preBody, 'during');
[bodies, route] = jTreatmentBodies(preBody, variable, chemicals, siteTerm, anchor.base.id);
if strcmp(route, 'dose')
    obs = jStatement(preBody, 'term_observation', jSubjectOf(preBody), ...
        jLabel('anatomical location'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id});
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end
