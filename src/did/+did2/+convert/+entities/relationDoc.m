function rel = relationDoc(preBody, childId, parentId, relationName, sequence)
%RELATIONDOC child --relationName--> parent, both entities.
%
%   REL = did2.convert.entities.relationDoc(PREBODY, CHILDID, PARENTID,
%   RELATIONNAME, SEQUENCE) builds one `directed_relation` body. SEQUENCE may
%   be [] (omitted from the block) or an integer (author position).
%
%   The base.name sentinel is `migrated_dataset_<relationName>`; that string is
%   what did2.convert.resolveDatasetEntities matches on when it prunes
%   best-effort session-membership edges, so relations minted here are
%   deliberately NOT named `migrated_session_membership` and are never pruned.
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB -- see entityDoc's header. Moved
%   verbatim out of did2.convert.migrators_j.metadata_editor so the openMINDS
%   citation assembler emits the same edges from a different reader.
%
%   See also: did2.convert.entities.entityDoc,
%   did2.convert.migrators_j.metadata_editor,
%   did2.convert.resolveOpenmindsCitations.

arguments
    preBody (1,1) struct
    childId char
    parentId char
    relationName char
    sequence = []
end

rel = struct();
rel.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', childId), ...
    struct('name', 'parent', 'value', parentId)];
rel.base = did2.convert.entities.freshBase(preBody, ...
    ['migrated_dataset_', relationName]);
drBlock = struct('relation', struct('node', '', 'name', relationName));
if ~isempty(sequence); drBlock.sequence = sequence; end
rel.directed_relation = drBlock;
end
