function v2Body = virus_injection(preBody)
%VIRUS_INJECTION Brainstorm-J migrator: did_v1 virus_injection -> dose_manipulation.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J has no `injection` class (D8): a viral injection is a
%   dose_manipulation, WHEREVER it was recorded -- "virus_injection is always a
%   dose (an injection), its volume NaN when unrecorded, its dilution staying
%   on the formulation" (Jess Haley, 2026-10-21; jTreatmentRoute quotes the
%   whole decision). The virus identity is the spine
%   `subject_statement.variable` AND the formulation's first ingredient (a
%   `chemical`, serotype carried in the ontology term); the dilution is that
%   ingredient's concentration (`source_unit` "dilution"); a named diluent is a
%   second ingredient. The template has no volume field, so the dose's amount
%   is always NaN in `volume.liters` (jDoseValue). The site is Path S --
%   merely-located -> a `term_observation` here (D3), attributed -> promoted
%   by the NDI second pass. A virus_injection with no site is NOT counted as
%   route unknown: its route is the injection.

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
if isfield(block, 'dilution') && isnumeric(block.dilution) && ~isempty(block.dilution)
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

anchor = jSessionAnchor(preBody, 'during');
bodies = jTreatmentBodies(preBody, virusTerm, chemicals, [], anchor.base.id, ...
    'AlwaysDose', true);

siteTerm = jOntologyTerm( ...
    jGetCharAny(block, {'virus_location_ontology_name', 'virusLocation_OntologyName'}), ...
    jGetCharAny(block, {'virus_location_name', 'virusLocation_name'}));
if ~isempty(siteTerm.node) || ~isempty(siteTerm.name)
    obs = jStatement(preBody, 'term_observation', jSubjectOf(preBody), ...
        jLabel('anatomical location'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id});
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end
