function v2Body = probe_location(preBody)
%PROBE_LOCATION Brainstorm-J migrator: did_v1 probe_location -> term_observation.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Per D5, an element/probe location is not its own class in J: the probe IS a
%   `subject` (device-as-subject, D2) and the location is a `term_observation`
%   about it -- `subject_statement.variable` = a spatial relation, the leaf
%   `value` = the atlas term. did_v1 carried the atlas term as a coordinated
%   (ontology_name, name) char pair; here they compose the ontology_term value.
%   1 -> 2 (the observation + the shared session anchor).
%
%   The subject is taken from the source `probe_id` dependency. NOTE: whether
%   the probe's location should instead be an attributed part-relationship
%   (Path S) is a per-corpus call reserved for the NDI second pass; here the
%   located-by-default form (D3) is emitted.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'probe_location') || ~isstruct(preBody.probe_location)
    error('did2:convert:missingBlock', ...
        'probe_location body is missing the probe_location property block.');
end
block = preBody.probe_location;

locTerm = jOntologyTerm(jGetChar(block, 'ontology_name'), jGetChar(block, 'name'));

obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
    {}, jOntologyTerm('', 'anatomical location'), {'probe_id', 'element_id', 'subject_id'});
obs.term = struct('value', locTerm);

anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

v2Body = {obs, anchor};
end
