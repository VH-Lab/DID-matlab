function v2Body = treatment_drug(preBody)
%TREATMENT_DRUG Brainstorm-J migrator: did_v1 treatment_drug -> an immersion
%   (`manipulation` valued by its formulation) or a `manipulation` with value
%   kind `dose`, decided by the recorded location.
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
%     a non-UBERON location CARRIED whole as v1 with a `needs_mapping` note
%                           (dose | exposure | temperature): not a body site
%                           ([one-reading quick answers] (Q1), the UBERON
%                           rule; the Babu media / heat routing left the
%                           generic stage, [dataset audit batch 1 and 2] (2)).
%
%   1 -> N: the manipulation, one chemical per mixture row, the formulation
%   and the anchor, plus the site observation for a dose at a site.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it, with no universalRenames (identity through jRawBody /
%   did2.convert.v1read.readBase; a carry is the untouched v1 source). Block
%   fields are read in the v1 spelling first and the universalRenames spelling
%   second, so 'RawV1Classes', {} still works. Every v1 field (NDI treatment/treatment_drug.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +NDIMaker/treatmentMaker writes it) and where it goes;
%   did2.convert.roundtrip.treatment_drug rebuilds the v1 document and
%   testRawV1RoundTripTreatment compares the two:
%
%     base.*, depends_on subject_id  -> as treatment.m
%     location_ontologyNode, location_ontologyName, location_name
%                              -> the route (jTreatmentRoute) and the site
%                                 observation of a dose. The template's
%                                 `location_ontologyNode` and the writer's
%                                 `location_ontologyName` (treatmentMaker) are
%                                 one field; both, differing, carry the
%                                 document as malformed ([treatment location
%                                 name is the node], Jess Haley, 2026-10-27)
%     mixture_table            -> chemicals + formulation (+ the dose's
%                                 per-ingredient amounts, jDoseValue)
%     administration_onset_time -> the anchor (jTreatmentAnchor)
%     administration_offset_time, administration_duration
%                              -> NOT READ (open findings)

arguments
    preBody (1,1) struct
end

body = jRawBody(preBody, 'treatment_drug');
v2Body = convertTreatmentDrug(body);
if isscalar(v2Body) && isequaln(v2Body{1}, body)
    v2Body = {preBody};   % a carry is the untouched v1 source
end
end

function v2Body = convertTreatmentDrug(preBody)
if ~isfield(preBody, 'treatment_drug') || ~isstruct(preBody.treatment_drug)
    error('did2:convert:missingBlock', ...
        'treatment_drug body is missing the treatment_drug property block.');
end
block = preBody.treatment_drug;

chemicals = jMixtureTable(jGetChar(block, 'mixture_table'));
variable  = chemicals(1).substance;   % the primary drug is the spine identity

% [treatment location name is the node] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): the WRITER's
% `location_ontologyName` (NDI-matlab main +setup/+NDIMaker/treatmentMaker.m
% line 163) and the template's `location_ontologyNode` are one field: either
% becomes the treatment's location term; a document holding both with
% different values is carried whole as v1, kind `malformed`. Each is read in
% its v1 spelling and in the universalRenames spelling ('RawV1Classes', {}).
% THE REGISTER ROW IS PENDING in did-schema: until it exists the note cites the
% placeholder LOCATION_ROW, which names no row.
LOCATION_ROW = 'carry-pending-treatment-location-malformed';
nodeOfTemplate = jGetCharAny(block, {'location_ontologyNode', 'location_ontology_node'});
nodeOfWriter = jGetCharAny(block, {'location_ontologyName', 'location_ontology_name'});
if ~isempty(strtrim(nodeOfTemplate)) && ~isempty(strtrim(nodeOfWriter)) ...
        && ~sameNode(nodeOfTemplate, nodeOfWriter)
    % carry-register: none (malformed row pending in did-schema; LOCATION_ROW)
    did2.convert.reportNote('carried_as_v1', char(preBody.document_class.class_name), ...
        char(preBody.base.id), sprintf(['[%s] malformed: location_ontologyNode "%s" ' ...
        'and location_ontologyName "%s" differ ([treatment location name is the ' ...
        'node])'], LOCATION_ROW, strtrim(nodeOfTemplate), strtrim(nodeOfWriter)));
    v2Body = {preBody};
    return;
end
locationNode = nodeOfTemplate;
if isempty(strtrim(locationNode))
    locationNode = nodeOfWriter;
end
siteTerm = jOntologyTerm(locationNode, jGetCharAny(block, {'location_name'}));
anchor = jTreatmentAnchor(preBody, block);  % the recorded onset, else the session
[bodies, route, unplaced] = jTreatmentBodies(preBody, variable, chemicals, siteTerm, anchor.base.id);
if ~isempty(unplaced)
    % [generic stage is lossless] / [partly placed is carried as v1] (Jess
    % Haley, 2026-10-25): an amount the dose cannot place carries the document
    % carry-register: carry-027 carry-028 carry-031 carry-057 via
    % private/jTreatmentBodies.m
    did2.convert.reportNote('carried_as_v1', char(preBody.document_class.class_name), ...
        char(preBody.base.id), jCarryWhy(unplaced));
    v2Body = {preBody};
    return;
end
if strcmp(route, 'dose')
    obs = jStatement(preBody, 'observation', jSubjectOf(preBody), ...
        did2.convert.registeredTerm('NCIT:C13717', 'Anatomic Site'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id}, 'ValueKind', 'term');
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end

% ===================== local helpers ===================================

function tf = sameNode(a, b)
%SAMENODE Two location node texts name one node: equal once edge blanks and
%   the prefix's case are set aside ([spelling is notation]).
a = strtrim(char(a));
b = strtrim(char(b));
tf = strcmp(a, b);
if ~tf
    try
        tf = strcmp(char(did2.schema.curieKey(a)), char(did2.schema.curieKey(b)));
    catch
        tf = strcmpi(a, b);
    end
end
end
