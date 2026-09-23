function bodies = gene_list_mapping(preBody)
%GENE_LIST_MAPPING Brainstorm-J migrator: did_v1 geneListMapping -> V_eta
%   gene_list_mapping, an id-preserving 1:1 passthrough. ⊂ base in V_eta;
%   the two gene_list_id_a / gene_list_id_b edges are both required and
%   carry through, and the block fields (label, mapping_type, method,
%   symmetric, n_pairs, n_genes_mapped_a, n_genes_mapped_b, has_score)
%   carry through verbatim. `mapping_type` and `symmetric` are
%   LOAD-BEARING per the class's own .md doc: alias-vs-ortholog is not
%   collapsible to a bare `directed_relation` (the two answer different
%   questions -- symbol drift vs. species mapping), and this migrator
%   makes no attempt to normalise or infer either. base.id is preserved.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   `geneListMapping` stays ⊂ base as a between-entity relation with
%   structure. Scope: DID-schema OPEN_WORK #122 / #123. Row #124 (corpus
%   proof) is DEFERRED; #126 (T8 binding follow-on: `mapping_type` gets a
%   controlled term for alias vs ortholog) is out of scope here.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
