function v2Body = virus_injection(preBody)
%VIRUS_INJECTION Brainstorm-J migrator: did_v1 virus_injection -> a dose or an
%   immersion, decided by the recorded location.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J has no `injection` class (D8). "virus_injection follows the same
%   location rule as the other treatments: a bath location makes it an
%   immersion (a manipulation of the subject valued by the virus formulation
%   through value_id, no location observation); a body site makes it a dose.
%   A dilution of 0 is treated as not recorded (NaN), not as a measured 0."
%   (Jess Haley, 2026-10-21 [virus-location]; supersedes "virus_injection is
%   always a dose" in [treatment-location].) Birren writes virus at the bath
%   (NCIm:C0179246) for cell cultures, with dilution 0, the template blank.
%
%   The virus identity is the spine `subject_statement.variable` AND the
%   formulation's first ingredient (a `chemical`); a non-zero dilution is that
%   ingredient's concentration (`source_unit` "dilution"), and 0 is NaN; a
%   named diluent is a second ingredient. Routing is jTreatmentRoute /
%   jTreatmentBodies: bath -> immersion; a body site -> a dose whose amount is
%   NaN in `volume.liters` (the template has no volume field) plus the site
%   `term_observation` (Path S, D3); no location -> that dose, listed in the
%   migration report as `route_unknown`.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'virus_injection') || ~isstruct(preBody.virus_injection)
    error('did2:convert:missingBlock', ...
        'virus_injection body is missing the virus_injection property block.');
end
block = preBody.virus_injection;

% universalRenames snake_cases block fields (virus_OntologyName ->
% virus_ontology_name); read the snake form first, camelCase as a fallback.
virusTerm = jOntologyTerm( ...
    jGetCharAny(block, {'virus_ontology_name', 'virus_OntologyName'}), ...
    jGetCharAny(block, {'virus_name'}));
dilution = [];
dilutionUnit = '';
if isfield(block, 'dilution') && isnumeric(block.dilution) && ~isempty(block.dilution) ...
        && double(block.dilution(1)) ~= 0
    % 0 is the template blank, not a measured dilution: left unrecorded, so
    % jDoseBodies writes the ingredient's concentration as NaN.
    dilution = double(block.dilution(1));
    dilutionUnit = 'dilution';
end
chemicals = struct('substance', virusTerm, 'source_value', dilution, ...
    'source_unit', dilutionUnit);
diluentNode = jGetCharAny(block, {'diluent_ontology_name', 'diluent_OntologyName'});
diluentName = jGetCharAny(block, {'diluent_name'});
if ~isempty(diluentNode) || ~isempty(diluentName)
    chemicals(end+1) = struct('substance', jOntologyTerm(diluentNode, diluentName), ...
        'source_value', [], 'source_unit', '');
end

siteTerm = jOntologyTerm( ...
    jGetCharAny(block, {'virus_location_ontology_name', 'virusLocation_OntologyName'}), ...
    jGetCharAny(block, {'virus_location_name', 'virusLocation_name'}));
anchor = jTreatmentAnchor(preBody, block)  % the recorded onset, else the session;
[bodies, route] = jTreatmentBodies(preBody, virusTerm, chemicals, siteTerm, anchor.base.id);
if strcmp(route, 'dose')
    obs = jStatement(preBody, 'observation', jSubjectOf(preBody), ...
        did2.convert.registeredTerm('NCIT:C13717', 'Anatomic Site'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id}, 'ValueKind', 'term');
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end
