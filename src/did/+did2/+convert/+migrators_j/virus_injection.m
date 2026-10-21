function v2Body = virus_injection(preBody)
%VIRUS_INJECTION Brainstorm-J migrator: did_v1 virus_injection -> dose_manipulation.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J has no `injection` class (D8): a viral injection is a
%   dose_manipulation -- the virus identity is the spine
%   `subject_statement.variable` AND the first `dose.value.formulation.chemicals`
%   substance (serotype carried in the ontology term), the dilution/titer is its
%   concentration amount, and a named diluent is a second chemical. The site is
%   Path S -- merely-located -> a `term_observation` here (D3), attributed ->
%   promoted by the NDI second pass. 1 -> 2, or 1 -> 3 when a site is present.

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

% did-schema #88: chemical + formulation documents, and the dose names the
% formulation (jDoseBodies).
anchor = jSessionAnchor(preBody, 'during');
[parts, formulationId] = jDoseBodies(preBody, chemicals);
dose = jStatement(preBody, 'dose_manipulation', jSubjectOf(preBody), virusTerm, [], ...
    'TimeReferenceIds', {anchor.base.id}, ...
    'Edges', struct('formulation_id', formulationId), 'Id', char(preBody.base.id));
bodies = [{dose}, parts];

siteTerm = jOntologyTerm( ...
    jGetCharAny(block, {'virus_location_ontology_name', 'virusLocation_OntologyName'}), ...
    jGetCharAny(block, {'virus_location_name', 'virusLocation_name'}));
if ~isempty(siteTerm.node) || ~isempty(siteTerm.name)
    obs = jStatement(preBody, 'term_observation', jSubjectOf(preBody), ...
        did2.build.label('anatomical location'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id});
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end
