function bodies = orientation_direction_tuning(preBody)
%ORIENTATION_DIRECTION_TUNING Brainstorm-J migrator: did_v1
%   orientation_direction_tuning -> the subject_calculation LEAF
%   `tuning_curve_calculation` + the `tuning_curve` result composite, with the id
%   preserved, + a session anchor. R2/R3 TUNING COLLAPSE: the v1
%   `orientation_direction_tuning` result block is RESHAPED into the one tuning_curve
%   value (a model_fit ARRAY + typed significance / interpolated_values sub-blocks) by
%   private/jTuningCurveValue -- it is NOT carried verbatim; the fold is 1 -> 1 with
%   base.id + depends_on preserved (so downstream calc references resolve) and the
%   input document(s) consumed -> derived_from_#. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   CORRECTED 2026-08-12 -- THE SUMMARY ABOVE NAMED A CLASS THAT DOES NOT EXIST. It
%   read "the subject_calculation LEAF orientation_direction_tuning_calculation" (and,
%   where it named a composite, the per-tuning result class). The R2/R3 tuning
%   collapse folded the six per-tuning result classes and their leaves into ONE
%   `tuning_curve` composite + ONE `tuning_curve_calculation` leaf, and this header
%   never caught up. The BEHAVIOUR was never wrong -- only the description was, which
%   is why the code below is untouched. Positive evidence, both halves:
%
%       $ grep -n "jCalculation(preBody" orientation_direction_tuning.m
%         21:bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
%       $ find DID-schema/schemas/V_eta -name 'orientation_direction_tuning_calculation.json'
%         (no match)
%       $ find DID-schema/schemas/V_eta -name 'tuning_curve_calculation.json'
%         schemas/V_eta/draft/tuning_curve_calculation.json
%
%   See DID-schema schemas/V_eta_tuning_model_plan.md for the collapse itself.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The team's
%   calculator-motif model (Lepsky et al.): a calculator produces ONE output document
%   type, kept as a first-class composite LEAF -- `subject_calculation` + the
%   `orientation_direction_tuning` result composite (properties / tuning_curve /
%   significance / vector / fit), exactly as visual_grating_manipulation pairs
%   subject_manipulation with visual_grating. The structured result is kept verbatim
%   as the composite value; the fold is 1 -> 1 with base.id preserved and depends_on
%   carried (so downstream calc references resolve -- un-defers calculators). The raw
%   stimulus_tuningcurve it was computed from becomes `derived_from_1`.
%
%   Supersedes the earlier D-C grain-A decomposition (curve + scalar observations):
%   the team keeps calculators as composite leafs rather than dissolving them. See
%   schemas/V_eta_subject_calculation_plan.md and
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
    'orientation/direction tuning', ...
    'ndi.calc.vis.oridir', 'orientation_direction_tuning');
end
