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
%   classes from PLAN.md §7 plus the PRED-driven §9.6 sub-step 6d
%   additions:
%
%     identity            - default passthrough.
%     probe_location      - collapse (ontology_name, name) -> location.
%     treatment           - collapse (ontologyName | ontology_name,
%                           name) -> treatment_name; pass through
%                           numeric_value and string_value.
%     ontology_image      - collapse (ontology_name, ontology_region)
%                           -> region.
%     ontology_label      - collapse (ontology_name, label_id, label)
%                           -> term, with the CURIE composed from the
%                           first two.
%     daqreader_ndr       - rename ndr_reader_string -> file_type;
%                           drop v1-only ndi_daqreader_ndr_class.
%     daqmetadatareader   - rename ndi_daqmetadatareader_class ->
%                           reader_class; drop v1-only
%                           tab_separated_file_parameter.
%     element             - rename name -> element_name, type ->
%                           element_type; coerce reference to char
%                           and direct to integer.
%     epochclocktimes     - SUPERCLASS migrator; rename clocktype ->
%                           epoch_clock and split t0_t1 -> (t0, t1).
%                           Applied by the dispatcher to any document
%                           that lists epochclocktimes among its
%                           superclasses, before the concrete-class
%                           migrator runs.
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
