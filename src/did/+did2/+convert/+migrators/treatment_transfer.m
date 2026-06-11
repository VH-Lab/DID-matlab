function out = treatment_transfer(preBody)
%TREATMENT_TRANSFER Migrate did_v1 treatment_transfer -> biological_transfer.
%
%   Maps the legacy donor->recipient transfer to the V_epsilon
%   `biological_transfer` family (a procedural_manipulation subclass),
%   per Biological_Transfer_Proposal.md. The legacy method_* pair lands
%   on the inherited procedural_manipulation.procedure; the entity_*
%   pair on biological_transfer.entity; the recipient becomes
%   subject_id and the donor carries forward as donor_id. Fans out a
%   companion utc_reference when the legacy timestamp is on a global
%   clock.
%
%   Legacy block fields (post-universalRenames snake_case):
%     timestamp (datenum if global clock, else seconds)
%     clocktype
%     entity_name / entity_ontology_node
%     method_name / method_ontology_node
%   Legacy depends_on: recipient_id (required), donor_id (optional).
%
%   Target biological_transfer:
%     procedural_manipulation.procedure        = {method_ontology_node, method_name}
%     procedural_manipulation.target_structure = [] (legacy none; backfill)
%     procedural_manipulation.notes            = ''
%     biological_transfer.entity               = {entity_ontology_node, entity_name}
%     biological_transfer.kind                 = bucket(entity_name)
%     depends_on: subject_id (<- recipient_id), donor_id, time_reference_1
%
%   See did-schema schemas/V_epsilon/conversions/from_did_v1/treatment_transfer.md.

arguments
    preBody (1,1) struct
end

ic = did2.convert.interactionCommon;

block = struct();
if isfield(preBody, 'treatment_transfer') && isstruct(preBody.treatment_transfer)
    block = preBody.treatment_transfer;
end

entityName = getField(block, 'entity_name', '');
entityNode = getField(block, 'entity_ontology_node', '');
methodName = getField(block, 'method_name', '');
methodNode = getField(block, 'method_ontology_node', '');

btBody = struct();
btBody.document_class = struct('class_name', 'biological_transfer');
btBody.base = ic.carryBase(preBody);
btBody.procedural_manipulation = struct( ...
    'procedure', ic.ontologyTerm(methodNode, methodName), ...
    'target_structure', ic.ontologyTermArray({}), ...
    'notes', '');
btBody.biological_transfer = struct( ...
    'entity', ic.ontologyTerm(entityNode, entityName), ...
    'kind', materialKind(entityName));

% --- timing: global-clock datenum -> utc_reference ---
timestamp = getField(block, 'timestamp', []);
clocktype = lower(char(getField(block, 'clocktype', '')));
companions = {};
timeRefId = '';
if ~isempty(timestamp) && isnumeric(timestamp) && isscalar(timestamp) ...
        && timestamp > 0 ...
        && (contains(clocktype, 'global') || contains(clocktype, 'utc'))
    iso = datenumToISO(timestamp);
    if ~isempty(iso)
        [trBody, timeRefId] = ic.utcReferenceBody(iso, ...
            ic.sessionIdOf(preBody), '', false);
        companions{end+1} = trBody;
    end
end

btBody.depends_on = ic.dependsOn({ ...
    'subject_id',       ic.depDocId(preBody, 'recipient_id'); ...
    'donor_id',         ic.depDocId(preBody, 'donor_id'); ...
    'time_reference_1', timeRefId});

out = [{btBody}, companions];
end

function kind = materialKind(entityName)
% Coarse material bucket from the legacy entity name (proposal table).
% Ambiguous/unknown defaults to "lysate" (the preparation catch-all),
% flagged for curator confirmation in the conversion doc.
n = lower(char(entityName));
if contains(n, 'blood') || contains(n, 'plasma') || contains(n, 'serum')
    kind = 'blood';
elseif contains(n, 'cell') || contains(n, 'marrow')
    kind = 'cells';
elseif contains(n, 'graft') || contains(n, 'tissue') || contains(n, 'explant')
    kind = 'tissue_graft';
else
    kind = 'lysate';
end
end

function iso = datenumToISO(dn)
iso = '';
try
    iso = [datestr(dn, 'yyyy-mm-ddTHH:MM:SS') 'Z'];
catch
    iso = '';
end
end

function v = getField(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end
