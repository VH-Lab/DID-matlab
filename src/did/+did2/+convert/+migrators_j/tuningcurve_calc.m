function bodies = tuningcurve_calc(preBody)
%TUNINGCURVE_CALC Brainstorm-J migrator: the ndi.calc.stimulus.tuningcurve calculator
%   OUTPUT document -> the subject_calculation LEAF `tuning_curve_calculation` + the
%   `tuning_curve` result composite, with the id preserved, + a session anchor. R2/R3
%   TUNING COLLAPSE: the v1 `stimulus_tuningcurve` result block is RESHAPED into the
%   one tuning_curve value (a model_fit ARRAY + typed significance /
%   interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT carried
%   verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so downstream
%   calc references resolve) and the input document(s) consumed -> derived_from_#. See
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
%       $ grep -n "jCalculation(preBody" tuningcurve_calc.m
%         20:bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
%       $ find DID-schema/schemas/V_eta -name 'stimulus_tuningcurve_calculation.json'
%         (no match)
%       $ find DID-schema/schemas/V_eta -name 'tuning_curve_calculation.json'
%         schemas/V_eta/draft/tuning_curve_calculation.json
%
%   See DID-schema schemas/V_eta_tuning_model_plan.md for the collapse itself.
%
%   Single-doc, contrary to an earlier (mistaken) belief that this doc lacked a
%   subject: a real tuningcurve_calc IS-A stimulus_tuningcurve (v1 superclass) and so
%   carries the inherited `element_id` -- the NDI writer sets it from the consumed
%   stimulus_response_scalar (ndi.app.stimulus.tuning_response.tuning_curve). Hence the
%   fold is 1 -> 1 with base.id preserved and depends_on carried (downstream calc
%   references resolve): element_id -> subject_id; the tuning-curve result fields sit on
%   the inherited `stimulus_tuningcurve` block (== the composite name, the default
%   sourceBlock) and are kept verbatim; the calc block's input_parameters ->
%   `subject_interaction.method_parameters`; the app block is kept; the raw
%   stimulus_response_scalar it was computed from -> `derived_from_1`.
%
%   Same leaf as its raw-app sibling migrators_j.stimulus_tuningcurve. See
%   schemas/V_eta_subject_calculation_plan.md and
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
    'stimulus tuning curve', ...
    'ndi.calc.stimulus.tuningcurve', 'stimulus_tuningcurve');
end
