function bodies = contrast_tuning_calc(preBody)
%CONTRAST_TUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.contrast calculator
%   OUTPUT document -> the subject_calculation LEAF `tuning_curve_calculation` + the
%   `tuning_curve` result composite, with the id preserved, + a session anchor. R2/R3
%   TUNING COLLAPSE: the v1 `contrast_tuning` result block is RESHAPED into the one
%   tuning_curve value (a model_fit ARRAY + typed significance / interpolated_values
%   sub-blocks) by private/jTuningCurveValue -- it is NOT carried verbatim; the fold
%   is 1 -> 1 with base.id + depends_on preserved (so downstream calc references
%   resolve) and the input document(s) consumed -> derived_from_#. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   CORRECTED 2026-08-12 -- THE SUMMARY ABOVE NAMED A CLASS THAT DOES NOT EXIST. It
%   read "the subject_calculation LEAF contrast_tuning_calculation" (and, where it
%   named a composite, the per-tuning result class). The R2/R3 tuning collapse folded
%   the six per-tuning result classes and their leaves into ONE `tuning_curve`
%   composite + ONE `tuning_curve_calculation` leaf, and this header never caught up.
%   The BEHAVIOUR was never wrong -- only the description was, which is why the code
%   below is untouched. Positive evidence, both halves:
%
%       $ grep -n "jCalculation(preBody" contrast_tuning_calc.m
%         20:bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
%       $ find DID-schema/schemas/V_eta -name 'contrast_tuning_calculation.json'
%         (no match)
%       $ find DID-schema/schemas/V_eta -name 'tuning_curve_calculation.json'
%         schemas/V_eta/draft/tuning_curve_calculation.json
%
%   See DID-schema schemas/V_eta_tuning_model_plan.md for the collapse itself.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
    ...
    'contrast tuning', 'ndi.calc.vis.contrast', 'contrast_tuning');
end
