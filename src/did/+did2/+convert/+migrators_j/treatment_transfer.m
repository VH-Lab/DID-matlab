function v2Body = treatment_transfer(preBody)
%TREATMENT_TRANSFER Brainstorm-J migrator: did_v1 treatment_transfer ->
%   term_manipulation + a provenance directed_relation.
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

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment_transfer') || ~isstruct(preBody.treatment_transfer)
    error('did2:convert:missingBlock', ...
        'treatment_transfer body is missing the treatment_transfer property block.');
end
block = preBody.treatment_transfer;

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
act = struct();
act.document_class = struct( ...
    'class_name', 'term_manipulation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_manipulation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
act.depends_on = struct('name', 'subject_id', 'value', recipientId);
if isfield(preBody, 'base'); act.base = preBody.base; end
act.subject_statement  = struct('variable', material, 'storage_mode', 'inline');
act.subject_interaction = struct('method', ontologyTerm('', methodName), ...
    'sample_time', struct('kind', 'point'));
act.subject_manipulation = struct('notes', '');
act.term_manipulation = struct('value', material);   % the imposed material term

% ---- 2. the provenance relation: recipient material derived_from donor ----
rel = struct();
rel.document_class = struct( ...
    'class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', recipientId), ...
    struct('name', 'parent', 'value', donorId)];
relBase = struct('id', did.ido.unique_id(), 'name', 'migrated_transfer_provenance', ...
    'session_id', '', 'datestamp', '2024-01-01T00:00:00.000Z');
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); relBase.session_id = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        relBase.datestamp = preBody.base.datestamp;
    end
end
rel.base = relBase;
rel.subject_relation = struct();
rel.directed_relation = struct('relation', ontologyTerm('ro:0001000', 'derived_from'));

% ---- 3. the shared session anchor; wire it onto the act ----
anchor = makeSessionAnchor(preBody, 'during');
act.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

v2Body = {act, rel, anchor};
end

% ===================== shared helpers ==================================

function anchor = makeSessionAnchor(preBody, relation)
sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
anchor = struct();
anchor.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
% Session identity rides on base.session_id; no redundant session_id edge.
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
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
