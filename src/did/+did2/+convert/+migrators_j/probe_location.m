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
%   The subject is taken from the source `probe_id` dependency. The
%   observation is a fact about the PROBE and stays one. What it says about the
%   specimen is the NDI second pass's (Jess Haley, 2026-10-21, replacing D3's
%   located-by-default): "recordings from a region become observations of the
%   region's part entity" -- ndi.migrate.internal.pathSPromotion ('located')
%   moves every statement whose instrument is this probe onto the specimen's
%   part for this region (one part per subject and region, `part_of` the
%   subject, shared with an injection into the same region). A single-document
%   migrator cannot see the recordings, so nothing here changes.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'probe_location') || ~isstruct(preBody.probe_location)
    error('did2:convert:missingBlock', ...
        'probe_location body is missing the probe_location property block.');
end
block = preBody.probe_location;

locTerm = jOntologyTerm(jGetChar(block, 'ontology_name'), jGetChar(block, 'name'));

anchor = jSessionAnchor(preBody, 'during');
obs = jStatement(preBody, 'term_observation', ...
    jSubjectOf(preBody, {'probe_id', 'element_id', 'subject_id'}), ...
    jLabel('anatomical location'), locTerm, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', char(preBody.base.id));
v2Body = {obs, anchor};
end
