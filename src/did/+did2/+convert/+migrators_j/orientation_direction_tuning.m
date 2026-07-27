function bodies = orientation_direction_tuning(preBody)
%ORIENTATION_DIRECTION_TUNING Brainstorm-J migrator: did_v1
%   orientation_direction_tuning -> the subject_calculation LEAF
%   `orientation_direction_tuning_calculation` (id-preserved) + a session anchor.
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
