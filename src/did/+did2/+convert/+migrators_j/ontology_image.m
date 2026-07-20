function v2Body = ontology_image(preBody)
%ONTOLOGY_IMAGE Brainstorm-J migrator: did_v1 ontology_image -> term_observation.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. An
%   ontology_image tags an imaged subject with the anatomical region it depicts;
%   in strict J that is a `term_observation` about the imaged subject (D5, the
%   probe_location / ontology_label idiom): subject_statement.variable = the
%   observed attribute ('imaged region'), the leaf value = the region ontology
%   term. 1 -> 2 (the observation + the shared session anchor).
arguments
    preBody (1,1) struct
end
region = jOntologyTerm('', '');
if isfield(preBody, 'ontology_image') && isstruct(preBody.ontology_image) ...
        && isfield(preBody.ontology_image, 'region') ...
        && isstruct(preBody.ontology_image.region)
    r = preBody.ontology_image.region;
    region = jOntologyTerm(jGetChar(r, 'node'), jGetChar(r, 'name'));
end

obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
    {}, jOntologyTerm('', 'imaged region'), {'element_id', 'subject_id'});
obs.term_observation = struct('value', region);

anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

v2Body = {obs, anchor};
end
