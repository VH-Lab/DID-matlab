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

%
%   READS RAW v1 (did2.convert.rawgeneListClasses, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`geneList`, NDI-matlab locked `main` 3cb19a8;
%   as +ndi/+fun/+doc/+gene/makeGeneList.m writes it). Pass 1 still hands it back UNCHANGED. The raw
%   passthrough keeps v1's class name `geneList`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of validating
%   it against the renamed `gene_list` class (a `retire` class), as a raw imageStack
%   passthrough is; NDI's last step stores its v1 source, stamped did_v1, on
%   both paths ([passthrough stays v1: how]). No DID batch pass and no NDI
%   second-pass step reads the class. What the renamed path would have discarded
%   is carried, carry-100, [rename clashes are malformed]; a field, block or edge outside the
%   template carries the document whole as v1 (private/jRawAccount, jRawCarry;
%   [fields outside the template are malformed], carry-100). The table in
%   did2.convert.rawgeneListClasses joins `geneList` to this migrator;
%   did2.convert.roundtrip.geneList rebuilds the v1 document from the passthrough;
%   testRawgeneListRoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'geneList', {{'label', 'n_genes', 'genome_assembly', 'gene_id_namespace', ...
        'gene_symbol_namespace', 'annotation_source', 'gene_name_completeness', ...
        'n_duplicate_gene_names'}}), ...
    {});
jRawCarry('gene_list', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
