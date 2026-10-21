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
%     agar plate medium /   an EXPOSURE (Babu): the immersion shape, no location
%     ambient air           observation (Jess Haley, 2026-10-21 [babu-media]).
%     a heat-only mixture   a `temperature_manipulation` of the worm (Babu's
%                           OM:Heat row), whatever the location.
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
if isHeatOnly(chemicals)
    % Babu writes a heat pulse as a treatment_drug whose one mixture row is
    % OM:Heat at 37 Degree Celsius (+babu/treatments.json `heat`), one
    % document per training time. "a heat row (OM:Heat, 37 °C) is a
    % temperature manipulation of the worms at each training time" (Jess
    % Haley, 2026-10-21 [babu-media]). No formulation, no location
    % observation (the location is the agar medium, no site on the worm).
    v2Body = {makeHeat(preBody, chemicals(1), anchor.base.id), anchor};
    return;
end
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

% ===================== local helpers ===================================

function tf = isHeatOnly(chemicals)
% Every mixture row is a heat row: node OM:Heat or name "heat".
tf = ~isempty(chemicals);
for k = 1:numel(chemicals)
    sub = chemicals(k).substance;
    if ~(strcmpi(strtrim(char(sub.node)), 'OM:Heat') || strcmpi(strtrim(char(sub.name)), 'heat'))
        tf = false;
        return;
    end
end
end

function doc = makeHeat(preBody, row, anchorId)
% A temperature_manipulation of the worm: the row's number in its unit, with
% the canonical `celsius` filled only when the unit says Celsius (NCIT:C42559
% "Degree Celsius" in Babu's table) -- no unit is guessed.
c = struct();
v = row.source_value;
unit = row.source_unit;
isC = false;
if isstruct(unit) && ~isempty(unit)
    isC = strcmpi(strtrim(char(unit.node)), 'NCIT:C42559') ...
        || ~isempty(regexpi(char(unit.name), 'celsius', 'once'));
end
if ~isempty(v) && isnumeric(v) && isfinite(v(1))
    if isC
        c.celsius = double(v(1));
    end
    c.source_value = double(v(1));
end
if isstruct(unit) && ~isempty(unit)
    c.source_unit = unit;
end
c.approximate = false;
value = did2.build.composite('temperature', 'value', {c});
doc = jStatement(preBody, 'temperature_manipulation', jSubjectOf(preBody), ...
    did2.convert.registeredTerm(row.substance.node, row.substance.name), value, ...
    'TimeReferenceIds', {anchorId}, 'Id', char(preBody.base.id));
end
