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

%
%   READS RAW v1 (did2.convert.rawspatialGeneExpressionCellsClasses, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`spatialGeneExpressionCells`, NDI-matlab locked `main` 3cb19a8;
%   as +ndi/+fun/+doc/+gene/makeCells.m writes it). Pass 1 still hands it back UNCHANGED. The raw
%   passthrough keeps v1's class name `spatialGeneExpressionCells`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of validating
%   it against the renamed `spatial_gene_expression_cells` class (a `retire` class), as a raw imageStack
%   passthrough is; NDI's last step stores its v1 source, stamped did_v1, on
%   both paths ([passthrough stays v1: how]). No DID batch pass and no NDI
%   second-pass step reads the class. What the renamed path would have discarded
%   is carried, carry-049, as before; a field, block or edge outside the
%   template carries the document whole as v1 (private/jRawAccount, jRawCarry;
%   [fields outside the template are malformed], carry-100). The table in
%   did2.convert.rawspatialGeneExpressionCellsClasses joins `spatialGeneExpressionCells` to this migrator;
%   did2.convert.roundtrip.spatialGeneExpressionCells rebuilds the v1 document from the passthrough;
%   testRawspatialGeneExpressionCellsRoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'spatialGeneExpressionCells', {{'label', 'n_cells', 'segmentation_method', ...
        'segmentation_dilation', 'coordinate_units', 'contours_present', ...
        'contour_reference', 'n_vertices_per_cell', 'data_type_vertex', ...
        'data_type_offset', 'contour_format_version'}}), ...
    {'^spatialGeneExpressionPyramid_id$', '^subject_id$', '^source_file_id$'});
jRawCarry('spatial_gene_expression_cells', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
