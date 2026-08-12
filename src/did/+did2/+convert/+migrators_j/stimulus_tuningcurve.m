function bodies = stimulus_tuningcurve(preBody)
%STIMULUS_TUNINGCURVE Brainstorm-J migrator: a raw ndi.app.stimulus.tuning_response
%   tuning curve (the pre-calculator-framework stimulus_tuningcurve document) -> the
%   subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve` result
%   composite, with the id preserved, + a session anchor. R2/R3 TUNING COLLAPSE: the
%   v1 `stimulus_tuningcurve` result block is RESHAPED into the one tuning_curve value
%   (a model_fit ARRAY + typed significance / interpolated_values sub-blocks) by
%   private/jTuningCurveValue -- it is NOT carried verbatim; the fold is 1 -> 1 with
%   base.id + depends_on preserved (so downstream calc references resolve) and the
%   input document(s) consumed -> derived_from_#. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   CORRECTED 2026-08-12 -- THE SUMMARY ABOVE NAMED A CLASS THAT DOES NOT EXIST. It
%   read "the subject_calculation LEAF stimulus_tuningcurve_calculation" (and, where
%   it named a composite, the per-tuning result class). The R2/R3 tuning collapse
%   folded the six per-tuning result classes and their leaves into ONE `tuning_curve`
%   composite + ONE `tuning_curve_calculation` leaf, and this header never caught up.
%   The BEHAVIOUR was never wrong -- only the description was, which is why the code
%   below is untouched. Positive evidence, both halves:
%
%       $ grep -n "jCalculation(preBody" stimulus_tuningcurve.m
%         21:bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
%       $ find DID-schema/schemas/V_eta -name 'stimulus_tuningcurve_calculation.json'
%         (no match)
%       $ find DID-schema/schemas/V_eta -name 'tuning_curve_calculation.json'
%         schemas/V_eta/draft/tuning_curve_calculation.json
%
%   See DID-schema schemas/V_eta_tuning_model_plan.md for the collapse itself.
%
%   Single-doc: the writer sets a populated `element_id` (from the consumed
%   stimulus_response_scalar), so element_id -> subject_id. The result fields already sit
%   on the self-named `stimulus_tuningcurve` block (== the composite name, the default
%   sourceBlock) and are kept verbatim; there is no calculator input_parameters/app on a
%   raw doc (method_parameters/app come out empty); the raw stimulus_response_scalar ->
%   `derived_from_1`. The V_eta `stimulus_tuningcurve` class is the ABSTRACT data_type
%   composite (a superclass, never instantiated); the concrete migrated doc is the leaf.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
    'stimulus tuning curve', ...
    'ndi.app.stimulus.tuning_response', 'stimulus_tuningcurve');
end
