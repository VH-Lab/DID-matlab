function bodies = contrast_sensitivity_calc(preBody)
%CONTRAST_SENSITIVITY_CALC Brainstorm-J migrator: the ndi.calc.vis.contrast_sensitivity
%   calculator OUTPUT document -> the subject_calculation LEAF
%   contrast_sensitivity_calculation (id-preserved) + a session anchor. Un-defers the
%   aggregate contrast-sensitivity calculation. This doc HAS element_id (like every
%   vision calculator, tuningcurve_calc included), so the fold is single-doc:
%   element_id -> subject_id; the result fields
%   (sensitivity / gain / c50 / p-value matrices) sit on the concrete
%   contrast_sensitivity_calc block, so it is passed as the sourceBlock (its inherited
%   input_parameters stripped -> method_parameters); app kept; the raw responses
%   (stimulus_response_scalar_id) -> derived_from_1.
%
%   NOTE: the doc's stimulus_presentation_id (and any upstream contrast_tuning refs)
%   are simplified away in this single-doc pass; carrying the full input provenance as
%   derived_from_# is a follow-up. See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'contrast_sensitivity_calculation', ...
    'contrast_sensitivity', 'contrast sensitivity', ...
    'ndi.calc.vis.contrast_sensitivity', 'contrast_sensitivity_calc');
end
