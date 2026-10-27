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

%
%   READS RAW v1 (did2.convert.rawgeneExpressionClasses, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`geneExpression`, NDI-matlab locked `main` 3cb19a8;
%   no NDI writer at that `main` constructs one as a document of its own (it is
%   the superclass block makePyramid writes on a spatialGeneExpressionPyramid)).
%   No corpus holds one either: the template alone fixes its shape. Pass 1 still hands it back UNCHANGED. The raw
%   passthrough keeps v1's class name `geneExpression`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of validating
%   it against the renamed `gene_expression` class (a `retire` class), as a raw imageStack
%   passthrough is; NDI's last step stores its v1 source, stamped did_v1, on
%   both paths ([passthrough stays v1: how]). No DID batch pass and no NDI
%   second-pass step reads the class. What the renamed path would have discarded
%   is carried, carry-049, as before; a field, block or edge outside the
%   template carries the document whole as v1 (private/jRawAccount, jRawCarry;
%   [fields outside the template are malformed], carry-100). The table in
%   did2.convert.rawgeneExpressionClasses joins `geneExpression` to this migrator;
%   did2.convert.roundtrip.geneExpression rebuilds the v1 document from the passthrough;
%   testRawgeneExpressionRoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'geneExpression', {{'assay', 'count_type', 'count_units'}}), ...
    {});
jRawCarry('gene_expression', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
