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

virusTerm = jOntologyTerm(jGetChar(block, 'virus_OntologyName'), ...
    jGetChar(block, 'virus_name'));
amount = jConcentration();
if isfield(block, 'dilution') && isnumeric(block.dilution) && ~isempty(block.dilution)
    amount.source_value = double(block.dilution(1));
    amount.source_unit = 'dilution';
end
chemicals = struct('substance', virusTerm, 'amount', amount);

diluentNode = jGetChar(block, 'diluent_OntologyName');
diluentName = jGetChar(block, 'diluent_name');
if ~isempty(diluentNode) || ~isempty(diluentName)
    chemicals(end+1) = struct('substance', jOntologyTerm(diluentNode, diluentName), ...
        'amount', jConcentration());
end

dose = jStartInteraction(preBody, 'dose_manipulation', ...
    'subject_manipulation', {'dose'}, virusTerm);
dose.dose = struct('value', jDoseValue(chemicals));

anchor = jSessionAnchor(preBody, 'during');
dose.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

bodies = {dose};
siteTerm = jOntologyTerm(jGetChar(block, 'virusLocation_OntologyName'), ...
    jGetChar(block, 'virusLocation_name'));
if ~isempty(siteTerm.node) || ~isempty(siteTerm.name)
    obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
        {}, jOntologyTerm('', 'anatomical location'), {'subject_id'}, true);
    obs.term_observation = struct('value', siteTerm);
    obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end
