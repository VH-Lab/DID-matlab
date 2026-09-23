% +ENTITIES -- shared emitters for the V_eta entity tier.
%
%   The six entity classes (`dataset`, `person`, `organization`, `funding`,
%   `publication`, `web_resource`) and the `directed_relation` edges between
%   them are produced from TWO independent did_v1 sources:
%
%     did2.convert.migrators_j.metadata_editor   the NDIMetaDataEditorApp blob
%                                                (`metadata_editor.metadata_structure`)
%     did2.convert.resolveOpenmindsCitations     the openMINDS dataset graph
%                                                (bare `openminds` documents)
%
%   Those two stores are written on INDEPENDENT NDI paths and are NOT
%   information-equivalent -- the graph holds only a DOI for a related
%   publication, while the editor blob carries title / DOI / PMID / PMCID
%   (NDI recovers the rest by network lookup in
%   ndi.database.metadata_app.fun.resolveRelatedPublication). Neither store
%   dominates. So the readers must stay separate and the EMITTERS must not:
%   these functions are the one place the emitted shape is defined.
%
%   entityDoc    one `<className>` entity body (id is the caller's, so an
%                id-preserving 1:1 fold is a matter of what is passed in)
%   relationDoc  one `directed_relation` child --relation--> parent
%   orgFor       name-deduplicated `organization`, optionally id-preserving
%   buildGids    an `entity.global_identifier` array from {scheme,value} pairs
%   emptyGids    the 0x0 global_identifier struct
%   freshBase    a minted `base` carrying the source's session context
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB. Neither MATLAB nor Octave exists
%   in the container this package was authored in; nothing here has been
%   executed locally. CI is the first execution.
%
%   See also: did2.convert.resolveDatasetEntities.
