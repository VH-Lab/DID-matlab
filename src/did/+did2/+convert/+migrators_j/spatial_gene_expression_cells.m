function bodies = spatial_gene_expression_cells(preBody)
%SPATIAL_GENE_EXPRESSION_CELLS Brainstorm-J migrator: did_v1
%   spatialGeneExpressionCells -> V_eta spatial_gene_expression_cells, an
%   id-preserving 1:1 passthrough. The class is ⊂ base in V_eta; the block
%   fields (segmentation_method, contour geometry, data types, ...) and the
%   depends_on edges (spatial_gene_expression_pyramid_id, subject_id,
%   source_file_id) carry through as-is -- universalRenames has already
%   snake_cased both the block key and its immediate fields, and
%   ensureClassBlocks rebuilds document_class.superclasses from the V_eta
%   chain. base.id is preserved so a dependent labeling row's
%   cells_document_id edge (mustBeNonEmpty: true) still resolves.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md): the
%   family PERSISTS structurally, with `spatialGeneExpressionCells` staying
%   ⊂ base (subject_id required, per its schema) as the data-of-record for
%   the pyramid observation. Migrator scope for the family: DID-schema
%   OPEN_WORK rows #122 (migrators) and #123 (fast-fixture tests); the
%   schemas + `variable` binding landed in DID-schema commit 71298fd
%   (Waltham-Data-Science/DID-schema#64). Row #124 (corpus proof) is
%   DEFERRED -- none of the 6 target corpora holds this class.
%
%   Field-level structural refactors for the tile / cells data_body are
%   OPEN_WORK #125, blocked on the 2.D data_body plan; explicitly out of
%   scope here.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
