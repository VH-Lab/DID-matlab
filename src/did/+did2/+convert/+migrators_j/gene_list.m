function bodies = gene_list(preBody)
%GENE_LIST Brainstorm-J migrator: did_v1 geneList -> V_eta gene_list, an
%   id-preserving 1:1 passthrough. ⊂ base in V_eta; a reference table --
%   `genes.tsv` names the columns of a pyramid's count space, and the
%   block fields (label, n_genes, genome_assembly, gene_id_namespace,
%   gene_symbol_namespace, annotation_source, gene_name_completeness,
%   n_duplicate_gene_names) are metadata about that table. All carry
%   through verbatim; base.id is preserved so a pyramid's `gene_list_id`
%   edge (mustBeNonEmpty: true) still resolves.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   `geneList` PERSISTS ⊂ base as a reference table -- outside the six
%   classes named in DID-schema#70 but confirmed by the same sign-off.
%   Scope: DID-schema OPEN_WORK #122 / #123. Row #124 (corpus proof) is
%   DEFERRED.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
