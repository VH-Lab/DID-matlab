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

%
%   READS RAW v1 (did2.convert.rawgeneListMappingClasses, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`geneListMapping`, NDI-matlab locked `main` 3cb19a8;
%   no NDI writer at that `main` constructs one as a document of its own).
%   No corpus holds one either: the template alone fixes its shape. Pass 1 still hands it back UNCHANGED. The raw
%   passthrough keeps v1's class name `geneListMapping`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of validating
%   it against the renamed `gene_list_mapping` class (a `retire` class), as a raw imageStack
%   passthrough is; NDI's last step stores its v1 source, stamped did_v1, on
%   both paths ([passthrough stays v1: how]). No DID batch pass and no NDI
%   second-pass step reads the class. What the renamed path would have discarded
%   is carried, carry-049, as before; a field, block or edge outside the
%   template carries the document whole as v1 (private/jRawAccount, jRawCarry;
%   [fields outside the template are malformed], carry-100). The table in
%   did2.convert.rawgeneListMappingClasses joins `geneListMapping` to this migrator;
%   did2.convert.roundtrip.geneListMapping rebuilds the v1 document from the passthrough;
%   testRawgeneListMappingRoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'geneListMapping', {{'label', 'mapping_type', 'method', 'symmetric', 'n_pairs', ...
        'n_genes_mapped_a', 'n_genes_mapped_b', 'has_score'}}), ...
    {'^geneList_id_a$', '^geneList_id_b$'});
jRawCarry('gene_list_mapping', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
