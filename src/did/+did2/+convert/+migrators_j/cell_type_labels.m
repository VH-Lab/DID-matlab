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

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
