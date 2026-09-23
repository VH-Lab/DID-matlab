function bodies = spatial_gene_expression_tiles(preBody)
%SPATIAL_GENE_EXPRESSION_TILES Brainstorm-J migrator: did_v1
%   spatialGeneExpressionTiles -> V_eta spatial_gene_expression_tiles, an
%   id-preserving 1:1 passthrough. The class is ⊂ base in V_eta; block
%   fields (bin_size, dimension_*, data_type_*, tile geometry) and the
%   depends_on edges (spatial_gene_expression_pyramid_id required;
%   subject_id optional -- the pyramid dep carries it; source_file_id
%   optional) carry through as-is. universalRenames has snake_cased the
%   block key and its immediate fields; ensureClassBlocks rebuilds the
%   superclass chain. base.id is preserved.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   `spatialGeneExpressionTiles` stays ⊂ base with subject_id OPTIONAL --
%   the pyramid dep carries the subject, so tiles do not need to restate
%   it. Migrator scope: DID-schema OPEN_WORK rows #122 / #123; the schemas
%   landed in DID-schema commit 71298fd. Row #124 (corpus proof) is
%   DEFERRED. Field-level data_body refactors are OPEN_WORK #125 and are
%   out of scope here.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
