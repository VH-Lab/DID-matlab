function bodies = spatial_gene_expression_roi(preBody)
%SPATIAL_GENE_EXPRESSION_ROI Brainstorm-J migrator: did_v1
%   spatialGeneExpressionROI, PASSED THROUGH unchanged (an id-preserving 1:1
%   passthrough under its v1 class name), as the other spatial-transcriptomics
%   classes are until their migrator is built.
%
%   WHY A PASSTHROUGH. NDI-matlab `main` gained the class on 2026-11-02
%   (+ndi/+fun/+doc/+gene/makeROI.m, written by fromGEFbyROI), and the sibling
%   lock reached it on 2026-11-09 (NDI-matlab `main` 73f46d19). Until this file,
%   no route named it, so did2.convert.v1_to_v2 QUARANTINED every v1 ROI
%   (did2:convert:noMigrator; NDI Cloud dataset 6af091807a7d768be9ae22e6 holds
%   three). Its decided target, Decided by Jess Haley, 2026-11-09 [spatial ROI
%   is an outline] (did-schema did_v2_spatial_transcriptomics_plan.md section
%   H): the outline (`vertices_x`, `vertices_y`) becomes a position
%   calculation over [vertex], cyclic, in the chip's coordinate system ([one
%   coordinate system per chip]); `n_records_in` a count calculation about the
%   same region; `label` the notes. It is not built here: the coordinate
%   system, the section entity and the pyramid it depends on are made by the
%   pyramid's migrator, which still passes the pyramid through (see
%   spatial_gene_expression_pyramid), and the region the two calculations are
%   about and the count's variable are not decided. Until then the document is
%   kept exactly as v1 wrote it, like the pyramid, tiles, cells and labels.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1], did-schema did_v2_go_forward_class_audit.md): the
%   document exactly as v1 wrote it (`spatialGeneExpressionROI`, NDI-matlab
%   locked `main` 73f46d19, data/spatialGeneExpressionROI.json, as makeROI.m
%   writes it). Pass 1 hands it back UNCHANGED, under v1's class name, under
%   which V_eta keeps no class, so v1_to_v2 counts it as a passthrough with no
%   schema; NDI's last step stores its v1 source, stamped did_v1
%   ([passthrough stays v1: how]). A field, block or edge outside the template
%   carries the document whole as v1 (private/jRawAccount, jRawCarry; [fields
%   outside the template are malformed], carry-100).
%   did2.convert.roundtrip.spatialGeneExpressionROI rebuilds the v1 document
%   from the passthrough; testRawV1RoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'spatialGeneExpressionROI', {{'label', 'n_vertices', 'vertices_x', 'vertices_y', ...
        'coord_space', 'coord_units', 'n_records_in', 'roi_format_version'}}), ...
    {'^spatialGeneExpressionPyramid_id$', '^source_file_id$'});
jRawCarry('spatial_gene_expression_roi', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
