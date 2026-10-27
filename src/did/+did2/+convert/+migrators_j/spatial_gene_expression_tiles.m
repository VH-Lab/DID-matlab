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

%
%   READS RAW v1 (did2.convert.rawspatialGeneExpressionTilesClasses, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`spatialGeneExpressionTiles`, NDI-matlab locked `main` 3cb19a8;
%   as +ndi/+fun/+doc/+gene/makePyramid.m writes it). Pass 1 still hands it back UNCHANGED. The raw
%   passthrough keeps v1's class name `spatialGeneExpressionTiles`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of validating
%   it against the renamed `spatial_gene_expression_tiles` class (a `retire` class), as a raw imageStack
%   passthrough is; NDI's last step stores its v1 source, stamped did_v1, on
%   both paths ([passthrough stays v1: how]). No DID batch pass and no NDI
%   second-pass step reads the class. What the renamed path would have discarded
%   is carried, carry-049, as before; a field, block or edge outside the
%   template carries the document whole as v1 (private/jRawAccount, jRawCarry;
%   [fields outside the template are malformed], carry-100). The table in
%   did2.convert.rawspatialGeneExpressionTilesClasses joins `spatialGeneExpressionTiles` to this migrator;
%   did2.convert.roundtrip.spatialGeneExpressionTiles rebuilds the v1 document from the passthrough;
%   testRawspatialGeneExpressionTilesRoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'spatialGeneExpressionTiles', {{'label', 'bin_size', 'pixel_size_x', ...
        'pixel_size_y', 'pixel_size_units', 'dimension_order', 'dimension_labels', ...
        'dimension_size', 'dimension_scale', 'dimension_scale_units', ...
        'tile_size_x_bins', 'tile_size_y_bins', 'n_tiles_stored', ...
        'data_type_gene_index', 'data_type_count', 'data_type_offset', ...
        'data_type_coordinate', 'tile_compression', 'tile_format_version', ...
        'tile_index_origin'}}), ...
    {'^spatialGeneExpressionPyramid_id$', '^subject_id$', '^source_file_id$'});
jRawCarry('spatial_gene_expression_tiles', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
