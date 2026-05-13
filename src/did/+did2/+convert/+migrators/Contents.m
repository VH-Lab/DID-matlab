% +migrators  Per-class did_v1 -> V_delta migrator functions.
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
%   classes from PLAN.md §7:
%
%     identity        - default passthrough.
%     probe_location  - collapse (ontology_name, name) -> location.
%     treatment       - collapse (ontologyName | ontology_name, name)
%                       -> treatment_name; pass through numeric_value
%                       and string_value.
%     ontology_image  - collapse (ontology_name, ontology_region)
%                       -> region.
%     ontology_label  - collapse (ontology_name, label_id, label)
%                       -> term, with the CURIE composed from the
%                       first two.
%
%   See did-schema's
%   schemas/V_delta/conversions/from_did_v1/<class_name>.md for the
%   per-class specifications.
