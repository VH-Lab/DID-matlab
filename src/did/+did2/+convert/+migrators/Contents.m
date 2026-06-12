% +migrators  Per-class did_v1 -> active-set migrator functions.
%
%   Each file in this package is named after the post-universal-rename
%   v1 class name (snake_case) and exports a single function:
%
%       out = <class_name>(preUniversalBody)
%
%   OUT is either a single body struct (1:1 rewrite) or a cell array of
%   body structs when the migration fans out into companion documents
%   (see the subject_interaction family below). The dispatcher
%   (did2.convert.v1_to_v2) applies the universal renames first, then
%   looks up the matching migrator by class name. If no migrator exists,
%   the dispatcher falls back to `identity`, which returns the
%   post-universal body unchanged.
%
%   subject_interaction family (V_epsilon active conversion). These
%   migrators implement the "fully active" did_v1 -> V_epsilon
%   conversion of the five deprecated families, per the ndi-next-steps
%   Summer 2026/1_Ingestion proposals. They build target documents in
%   the new observation / manipulation / annotation families and share
%   did2.convert.interactionCommon for identity carryover, ontology_term
%   / concentration / volume composites, and minting time_reference
%   companions:
%
%     treatment           - SPLIT on name/ontology into
%                           temperature_manipulation (thermal),
%                           procedural_manipulation (surgical/minor; and
%                           the Dab "...Target Location" case where
%                           string_value is the target_structure), or
%                           environmental_manipulation (husbandry/
%                           sensory/behavioral). A non-empty
%                           numeric_value is preserved as a companion
%                           generic_scalar_observation. Records that are
%                           not manipulations (DOB, session metadata) or
%                           cannot be routed are quarantined (the
%                           function throws), per the report-only-first
%                           mandate.
%     treatment_drug      - -> injection (kind="drug"); mixture_table ->
%                           mixture; location -> target_structure;
%                           administration onset/offset -> companion
%                           utc_reference.
%     virus_injection     - -> injection (kind="virus"); construct (+
%                           diluent) -> mixture; location ->
%                           target_structure; administration date ->
%                           companion (approximate) utc_reference.
%     treatment_transfer  - -> biological_transfer; method_* ->
%                           inherited procedure; entity_* -> entity;
%                           recipient_id -> subject_id; donor_id carried;
%                           global-clock timestamp -> companion
%                           utc_reference.
%     subject_group       - -> subject (is_group=true), carrying the
%                           legacy id so references resolve; an optional
%                           member is re-expressed as a companion
%                           group_assignment.
%     stimulus_bath       - re-rooted under `bath`: mixture_table ->
%                           pharmacological_manipulation.mixture;
%                           location -> bath.location; bath.kind defaults
%                           to "drug"; stimulus_element_id carried.
%
%   Other registered migrators (carried over; retargeted to the active
%   set via the version-agnostic dispatcher):
%
%     identity            - default passthrough.
%     ontology_image      - collapse (ontology_name, ontology_region)
%                           -> region.
%     ontology_label      - collapse (ontology_name, label_id, label)
%                           -> term, with the CURIE composed from the
%                           first two.
%     epochclocktimes     - SUPERCLASS migrator; rename clocktype ->
%                           epoch_clock and split t0_t1 -> (t0, t1).
%                           Applied by the dispatcher to any document
%                           that lists epochclocktimes among its
%                           superclasses, before the concrete-class
%                           migrator runs.
%     element_epoch       - concrete-class twin of epochclocktimes;
%                           splits t0_t1 -> (t0, t1). epoch_clock is
%                           already snake_case in v1, no rename
%                           needed. Accepts the older `clocktype`
%                           spelling defensively.
%     ngrid               - SUPERCLASS migrator; rename data_dim ->
%                           dim_sizes and derive ndims = numel(data_dim).
%                           Drops v1-only data_size and coordinates.
%                           Applied to any document that lists ngrid
%                           in its superclass chain (e.g., hartley_calc
%                           via reverse_correlation).
%     ontology_label      - extended to handle the JH single-`ontologyNode`
%                           idiom (no label/label_id). Looks up the
%                           name via ndi.ontology.lookup; falls back to
%                           empty name when the lookup is unavailable.
%     position_metadata   - semantic-shape migrator: builds
%                           measurement (ontology_term), units
%                           (ontology_term), and dimensions
%                           (array-of-records with axis_1, axis_2 labels)
%                           from v1 ontologyNode/units/dimensions.
%     distance_metadata   - paired A/B endpoint migrator: discovers
%                           labels by regex-scanning ontology_node_X
%                           keys and builds an endpoints array-of-records
%                           with measurement, integer_ids, string_ids,
%                           numeric_values per endpoint.
%
%   Calculator-base wrappers (PLAN.md §9.6 sub-step 6d, 20211116-driven):
%   each calls did2.convert.calcCommon to move v1's
%   `<class>.input_parameters` into a new inherited `calculator` block.
%   The calculator-identity string lives in `app.app_name` (carried in
%   v1 as `app.name`) and is handled by the universal app-block field
%   rename in did2.convert.universalRenames; the per-class wrapper does
%   not have to know its own calculator-name string.
%
%     tuningcurve_calc, oridirtuning_calc, hartley_calc,
%     contrast_sensitivity_calc, contrast_tuning_calc,
%     spatial_frequency_tuning_calc, speed_tuning_calc,
%     temporal_frequency_tuning_calc, simple_calc
%
%   See did-schema's
%   schemas/V_delta/conversions/from_did_v1/<class_name>.md for the
%   per-class specifications.
