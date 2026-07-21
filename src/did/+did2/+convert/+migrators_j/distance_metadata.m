function bodies = distance_metadata(preBody)
%DISTANCE_METADATA Brainstorm-J migrator: did_v1 distance_metadata -> a
%   `measured_distance_to` directed_relation between its two endpoint subjects.
%   1 -> 1.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The v1
%   distance_metadata is FLAT and records the two ENDPOINTS of a distance
%   measurement, not the distance itself (see the writer NDI-matlab
%   +setup/+conv/+haley/doImport.m and V_eta_distance_metadata_plan.md):
%     - ontologyNode_A = the animal SUBJECT document id (id-preserved subject in V_eta)
%     - ontologyNode_B = a patch document id (id-preserved subject via
%                        ontology_table_row.makePatchSubject)
%     - ontologyNumericValues_A/_B = [] (empty by design; the distance timeseries
%                        lives on the distance ELEMENT via depends_on element_id)
%   The endpoint IDENTITIES are the doc ids (ontologyNode_A/_B); the V_eta
%   `endpoints` structure has no slot for a doc-id reference, so they are preserved
%   as a `directed_relation` (child = A --measured_distance_to--> parent = B). Both
%   endpoint ids survive migration id-preserved, so the relation resolves (no
%   orphan). Turning the distance element's timeseries into a body-backed
%   length_observation (units from `units`) is Part B -- the NDI second pass
%   element-data decomposition (TaskList #18), which this relation tees up.
%
%   A doc missing either endpoint id carries unchanged (discovery fallback).
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'distance_metadata') && isstruct(preBody.distance_metadata)
    blk = preBody.distance_metadata;
end
% Endpoint doc ids. Read snake-first with a camelCase fallback: these are immediate
% block fields (universalRenames snake_cases them), but the fallback keeps the
% migrator correct on the RenameClassNames=false read path too.
nodeA = jGetCharAny(blk, {'ontology_node_a', 'ontologyNode_A'});
nodeB = jGetCharAny(blk, {'ontology_node_b', 'ontologyNode_B'});
if isempty(nodeA) || isempty(nodeB)
    bodies = {preBody};   % no endpoint pair -> carry unchanged (discovery fallback)
    return;
end

rel = struct();
rel.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', nodeA), ...   % the animal (measured from)
    struct('name', 'parent', 'value', nodeB)];      % the reference (the patch)
rel.base = freshBase(preBody, 'migrated_distance_endpoints');
rel.directed_relation = struct('relation', jOntologyTerm('', 'measured_distance_to'));

bodies = {rel};
end

% ===================== helpers =========================================

function base = freshBase(preBody, name)
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end
