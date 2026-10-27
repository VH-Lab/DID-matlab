% +migrators  Per-class did_v1 -> V2 migrator functions.
%
%   Each file in this package is named after the post-universal-rename
%   v1 class name (snake_case) and exports a single function:
%
%       v2Body = <class_name>(preUniversalBody)
%
%   The dispatcher (did2.convert.v1_to_v2) applies the universal
%   renames first, then looks up the matching migrator by class name.
%   If no migrator exists, the dispatcher falls back to `identity`,
%   which returns the post-universal body unchanged.
%
%   Currently registered migrators implement the four 2.0.0-bumped
%   classes plus the PRED-driven additions:
%
%     identity            - default passthrough.
%     probe_location      - collapse (ontology_name, name) -> location.
%     treatment           - collapse (ontologyName | ontology_name,
%                           name) -> treatment_name; pass through
%                           numeric_value and string_value.
%     element_epoch       - splits t0_t1 -> (t0, t1). epoch_clock is
%                           already snake_case in v1, no rename
%                           needed. Accepts the older `clocktype`
%                           spelling defensively.
%     ngrid               - SUPERCLASS migrator; rename data_dim ->
%                           dim_sizes and derive ndims = numel(data_dim).
%                           Drops v1-only data_size and coordinates.
%                           Applied to any document that lists ngrid
%                           in its superclass chain (e.g., hartley_calc
%                           via reverse_correlation).
%
%   The calculator-base wrappers are all deleted, with their shared helper
%   calcCommon: the tuning family's (tuningcurve_calc, oridirtuning_calc,
%   contrast_sensitivity_calc, contrast_tuning_calc,
%   spatial_frequency_tuning_calc, temporal_frequency_tuning_calc) and then
%   hartley_calc, speed_tuning_calc and simple_calc, with jrclust_clusters'
%   rename. Each class has a +migrators_j migrator, so the wrapper was never
%   reached; the classes read raw v1 (did2.convert.rawV1Classes; simple_calc
%   is not switched, see there; [early migration pieces fixed] (1), Jess
%   Haley, 2026-10-26).
%
%   The position_metadata, distance_metadata and stimulus_bath base migrators
%   are deleted too: each class has a +migrators_j migrator, which reads raw v1
%   (distance_metadata's reshapes the v1 spelling itself, where it used to hand
%   the renamed body to the base migrator).
%
%   The element, ontology_image and ontology_label base migrators are deleted
%   (2026-10-27): each class has a +migrators_j migrator that reads raw v1, and
%   no NDI template at the locked main names element, ontologyImage or
%   ontologyLabel as a superclass, so nothing reached them. element_epoch stays
%   (+migrators_j/element_epoch.m and oneepoch.m call it on the raw block).
%   The epochclocktimes and filter SUPERCLASS migrators are deleted (Decided by
%   Jess Haley, 2026-10-27 [unreached superclass migrators deleted], did-schema
%   V_eta_go_forward_class_audit.md): pyraview, the only class at the locked
%   NDI main that names either as a superclass, reads raw v1 since DID-matlab
%   PR #256 (did2.convert.rawV1Classes), so no superclass pass runs on it, and
%   no writer at that main constructs a leaf `epochclocktimes` or `filter`
%   document. ngrid stays as
%   the concrete migrator of a leaf `ngrid` document (+migrators_j has only
%   the +super guard); identity stays as v1_to_v2's fallback.
%
%   See did-schema's
%   did-schema's per-class conversion notes (deleted with did-schema #88) for the
%   per-class specifications.
