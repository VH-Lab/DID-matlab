function v2Body = probe_location(preBody)
%PROBE_LOCATION Brainstorm-J migrator: did_v1 probe_location -> an `observation`
%   with value kind `term`, + the session anchor.
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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI probe_location.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +fun/+doc/+probe/probeLocations4probes.m,
%   +setup/+conv/+dabrowska/doImport.m and +marder/marderprobe2uberon.m write
%   it). Every v1 field and where it goes; did2.convert.roundtrip.probe_location
%   rebuilds the v1 document and testRawV1RoundTripDaq compares the two:
%
%     base.id, session_id, datestamp   -> the observation's (the session also
%                                         names the anchor's referent)
%     base.name                        -> not written (the writers leave '')
%     depends_on probe_id              -> the observation's entity_id
%     probe_location.ontology_name     -> the value term's node
%     probe_location.name              -> the value term's name (the registry's
%                                         label when the node is registered)
%
%   What the renamed path would have discarded is carried, carry-049, as
%   before; a field or edge no part of this migrator reads now carries the
%   document whole as v1 (private/jRawAccount, jRawCarry; carry-100, [fields outside the template
%   are malformed]).

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, ...
    struct('probe_location', {{'ontology_name', 'name'}}), ...
    {'^probe_id$', '^element_id$', '^subject_id$'});
if jRawCarry('probe_location', src, collision, unplaced, 'carry-100')
    v2Body = {src};
    return;
end

if ~isfield(preBody, 'probe_location') || ~isstruct(preBody.probe_location)
    error('did2:convert:missingBlock', ...
        'probe_location body is missing the probe_location property block.');
end
block = preBody.probe_location;

locTerm = jOntologyTerm(jGetChar(block, 'ontology_name'), jGetChar(block, 'name'));

anchor = jSessionAnchor(preBody, 'during');
obs = jStatement(preBody, 'observation', ...
    jSubjectOf(preBody, {'probe_id', 'element_id', 'subject_id'}), ...
    did2.convert.registeredTerm('NCIT:C13717', 'Anatomic Site'), locTerm, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', char(preBody.base.id), 'ValueKind', 'term');
v2Body = {obs, anchor};
end
