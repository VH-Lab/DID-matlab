function d = entityDoc(preBody, className, docId, blockStruct, gids, fresh)
%ENTITYDOC An `<className>` entity body: entity.global_identifier + the class block.
%
%   D = did2.convert.entities.entityDoc(PREBODY, CLASSNAME, DOCID, BLOCKSTRUCT,
%   GIDS, FRESH) builds one V_eta entity-tier document body.
%
%     PREBODY     the source body the entity is derived from -- only its `base`
%                 is read (session_id / datestamp, and the whole base when
%                 FRESH is false).
%     CLASSNAME   'dataset' | 'person' | 'organization' | 'funding' |
%                 'publication' | 'web_resource' -- the six entity classes.
%     DOCID       the id the emitted document carries. AUTHORITATIVE: every
%                 relation that points at this entity uses this string, so a
%                 caller that wants an id-preserving 1:1 fold passes the source
%                 document's own base.id here.
%     BLOCKSTRUCT the `<className>` property block.
%     GIDS        an `entity.global_identifier` struct array (see buildGids).
%     FRESH       true  -> mint a new base (freshBase) and stamp DOCID on it.
%                 false -> carry PREBODY's whole base forward, then stamp
%                          DOCID. Used by the `dataset` entity, which is keyed
%                          on the DATASET id rather than on the source
%                          document's id.
%
%   ---------------------------------------------------------------------
%   WHY THIS LIVES IN A PACKAGE AND NOT IN ONE MIGRATOR
%   ---------------------------------------------------------------------
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB. There is neither MATLAB nor
%   Octave in the container this was authored in, so NOTHING HERE HAS BEEN
%   EXECUTED. CI is the first execution.
%
%   These builders were local functions inside
%   did2.convert.migrators_j.metadata_editor. There are now TWO readers of the
%   same six entity classes -- the editor blob (metadata_editor) and the
%   openMINDS citation graph (did2.convert.resolveOpenmindsCitations) -- and
%   the team's brief for the second one is explicit that the EMITTERS are
%   reused unchanged and only the readers differ. Copying them would have made
%   two spellings of one document shape inside a single dataset, which is the
%   failure the `local_identifier` triple decision names in a different family.
%
%   The bodies are consumed by did2.convert.v1_to_v2 with TargetVersion
%   'V_eta'; they carry `schema_version` 'V_eta' so the idempotency
%   short-circuit routes them straight to ensureClassBlocks + validate.
%
%   See also: did2.convert.entities.relationDoc, did2.convert.entities.orgFor,
%   did2.convert.entities.buildGids, did2.convert.migrators_j.metadata_editor,
%   did2.convert.resolveOpenmindsCitations.

arguments
    preBody (1,1) struct
    className char
    docId char
    blockStruct (1,1) struct
    gids
    fresh (1,1) logical
end

d = struct();
d.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
d.depends_on = struct('name', {}, 'value', {});
d.base = did2.convert.entities.freshBase(preBody, ['migrated_', className]);
if ~fresh && isfield(preBody, 'base') && isstruct(preBody.base)
    d.base = preBody.base;           % dataset: preserve the whole source base
end
d.base.id = docId;                   % the id the relations reference is authoritative
% cell-wrap: gids may be an empty or multi-element struct array; without the
% cell, struct() would fan `d.entity` out into a struct array (MATLAB gotcha).
d.entity = struct('global_identifier', {gids});
d.(className) = blockStruct;
end
