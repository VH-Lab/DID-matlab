function v2Body = treatment_transfer(preBody)
%TREATMENT_TRANSFER Brainstorm-J migrator: did_v1 treatment_transfer ->
%   a `manipulation` with value kind `term` + a provenance directed_relation
%   (+ the session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Per V_eta_SPEC.md (D4): there is no biological_transfer class in strict J
%   (a transfer is not a data type). The transfer ACT becomes a
%   term_manipulation (the transferred material as its bound term value), and
%   the donor relationship becomes a PROVENANCE directed_relation -- the
%   recipient material derives from the donor:
%
%       treatment_transfer  ->  term_manipulation           (the act, on the recipient)
%                            +  directed_relation (derived_from: recipient <- donor)
%                            +  session_relative_reference   (the shared anchor)
%
%   1 -> 3. The spine restructures per J: `variable` lives on the
%   subject_statement block, `method`/`sample_time` on subject_interaction,
%   and `notes` on subject_manipulation. subject_id (the recipient) is the
%   patient; the donor is captured by the relation, not a dependency.
%
%   NOTE: a precise model would mint a "transferred material" part-subject and
%   relate THAT to the donor (Path S); that refinement is a job for the NDI
%   second pass (ndi.migrate) which has the corpus-wide subject graph. Here we
%   emit the recipient<-donor provenance edge directly.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it, with no universalRenames (identity through jRawBody /
%   did2.convert.v1read.readBase; a carry is the untouched v1 source). Block
%   fields are read in the v1 spelling first and the universalRenames spelling
%   second, so 'RawV1Classes', {} still works. Every v1 field (NDI treatment/treatment_transfer.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +NDIMaker/treatmentMaker writes it) and where it goes;
%   did2.convert.roundtrip.treatment_transfer rebuilds the v1 document and
%   testRawV1RoundTripTreatment compares the two:
%
%     base.*                   -> as treatment.m
%     depends_on recipient_id  -> the act's entity_id and the relation's child
%     depends_on donor_id      -> the relation's parent
%     entity_ontologyNode, entity_name -> the variable and the term value
%     method_name              -> interaction.method (a label; '' becomes
%                                 'transfer', an open finding)
%     method_ontologyNode      -> NOT READ (an open finding)
%     timestamp, clocktype     -> the anchor; a clock with no timestamp is
%                                 not kept (an open finding)

arguments
    preBody (1,1) struct
end

body = jRawBody(preBody, 'treatment_transfer');
v2Body = convertTreatmentTransfer(body);
if isscalar(v2Body) && isequaln(v2Body{1}, body)
    v2Body = {preBody};   % a carry is the untouched v1 source
end
end

function v2Body = convertTreatmentTransfer(preBody)
if ~isfield(preBody, 'treatment_transfer') || ~isstruct(preBody.treatment_transfer)
    error('did2:convert:missingBlock', ...
        'treatment_transfer body is missing the treatment_transfer property block.');
end
block = preBody.treatment_transfer;

% [one-reading quick answers] (Q2) (Decided by Jess Haley, 2026-10-26,
% did-schema V_eta_go_forward_class_audit.md): a timestamp with no clock type
% is not given `dev_local_time` ([no invented values]); the document is
% carried whole as v1.
if hasFiniteTimestamp(block) && isempty(jGetCharAny(block, {'clocktype', 'clockType'}))
    % carry-register: carry-035
    did2.convert.reportNote('carried_as_v1', 'treatment_transfer', char(preBody.base.id), ...
        '[carry-035] unplaced: treatment_transfer.timestamp names no clocktype');
    v2Body = {preBody};
    return;
end

recipientId = namedDep(preBody, 'recipient_id');
donorId     = namedDep(preBody, 'donor_id');

% universalRenames snake_cases block fields (entity_ontologyNode ->
% entity_ontology_node); read the snake form first, camelCase as a fallback.
matNode = getCharField(block, 'entity_ontology_node');
if isempty(matNode); matNode = getCharField(block, 'entity_ontologyNode'); end
material = ontologyTerm(matNode, getCharField(block, 'entity_name'));  % transferred material
methodName = getCharField(block, 'method_name');
if isempty(methodName); methodName = 'transfer'; end

% ---- 1. the transfer act: a term_manipulation on the recipient ----
% did-schema #88: built through did2.build. The act on the recipient (id
% preserved), the recipient <- donor provenance relation, and the session anchor.
anchor = jTreatmentAnchor(preBody, block);   % the recorded timestamp, else the session
act = jStatement(preBody, 'manipulation', recipientId, material, material, ...
    'TimeReferenceIds', {anchor.base.id}, ...
    'Fields', struct('method', jMethod(methodName)), 'Id', char(preBody.base.id), 'ValueKind', 'term');
rel = jEntityRelation(preBody, recipientId, donorId, 'derived_from');   % node from the schema's row (did2.build.vocabulary)

v2Body = {act, rel, anchor};
end

function val = namedDep(preBody, name)
val = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value'); val = d.value;
            elseif isfield(d, 'document_id'); val = d.document_id; end
        end
    end
end
end

function t = ontologyTerm(node, name)
t = struct('node', char(node), 'name', char(name));
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function tf = hasFiniteTimestamp(block)
tf = false;
if ~isfield(block, 'timestamp'); return; end
t = block.timestamp;
if ischar(t) || isstring(t); t = str2double(t); end
tf = isnumeric(t) && ~isempty(t) && isfinite(double(t(1)));
end
