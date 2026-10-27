function bodies = cell_type_labels(preBody)
%CELL_TYPE_LABELS Brainstorm-J migrator: did_v1 cellTypeLabels ->
%   V_eta cell_type_labels, an id-preserving 1:1 passthrough. ⊂ base in
%   V_eta; block fields (label, label_name, taxonomy_level, n_cells,
%   n_categories, n_unlabeled, assignment_method, is_unsupervised) carry
%   through verbatim -- `is_unsupervised` is LOAD-BEARING per the class's
%   own .md doc (a k-means clustering with no ground-truth reference is
%   modelled the same as a supervised classifier's output; only this flag
%   distinguishes them) and any coercion here would silently rewrite the
%   distinction. depends_on (cells_document_id required; reference_document_id
%   optional) is carried as-is. base.id is preserved.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   `cellTypeLabels` stays ⊂ base; labeling attaches to a cells doc, not
%   directly to a subject, so no observation-direction reshape is required.
%   Scope: DID-schema OPEN_WORK #122 / #123. Row #124 (corpus proof) and
%   #126 (T8 binding follow-ons -- taxonomy_level, assignment_method) are
%   DEFERRED.

%
%   READS RAW v1 (did2.convert.rawcellTypeLabelsClasses, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (`cellTypeLabels`, NDI-matlab locked `main` 3cb19a8;
%   as +ndi/+fun/+doc/+gene/makeCellTypeLabels.m writes it). Pass 1 still hands it back UNCHANGED. The raw
%   passthrough keeps v1's class name `cellTypeLabels`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of validating
%   it against the renamed `cell_type_labels` class (a `retire` class), as a raw imageStack
%   passthrough is; NDI's last step stores its v1 source, stamped did_v1, on
%   both paths ([passthrough stays v1: how]). No DID batch pass and no NDI
%   second-pass step reads the class. What the renamed path would have discarded
%   is carried, carry-049, as before; a field, block or edge outside the
%   template carries the document whole as v1 (private/jRawAccount, jRawCarry;
%   [fields outside the template are malformed], carry-100). The table in
%   did2.convert.rawcellTypeLabelsClasses joins `cellTypeLabels` to this migrator;
%   did2.convert.roundtrip.cellTypeLabels rebuilds the v1 document from the passthrough;
%   testRawcellTypeLabelsRoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'cellTypeLabels', {{'label', 'label_name', 'taxonomy_level', 'n_cells', ...
        'n_categories', 'n_unlabeled', 'assignment_method', 'is_unsupervised'}}), ...
    {'^cells_document_id$', '^reference_document_id$'});
jRawCarry('cell_type_labels', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end
