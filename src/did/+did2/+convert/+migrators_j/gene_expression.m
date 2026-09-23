function bodies = gene_expression(preBody)
%GENE_EXPRESSION Brainstorm-J migrator: did_v1 geneExpression -> V_eta
%   gene_expression, an id-preserving 1:1 passthrough. ⊂ base in V_eta;
%   a SHAPE MIXIN, not itself an observation -- assay / count_type /
%   count_units describe how counts were produced, not what they measure,
%   and the observation-ness lives on the concrete pyramid class that
%   binds `variable = NCIT:C16608 "gene expression"` (see
%   spatial_gene_expression_pyramid.m). Block fields carry through
%   verbatim; base.id is preserved.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   `geneExpression` STAYS a ⊂ base shape mixin (assay / count_type /
%   count_units); the corrected Option C from
%   Waltham-Data-Science/DID-schema#70 puts the observation direction on
%   spatial_gene_expression_pyramid, not here. Scope: DID-schema
%   OPEN_WORK #122 / #123. Row #124 (corpus proof) is DEFERRED. Whether
%   the mixin's `assay` deserves its own controlled binding is an OPEN
%   modelling question tracked on OPEN_WORK #126 (T8 follow-ons); default
%   here is to carry the char through and not mint anything.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
