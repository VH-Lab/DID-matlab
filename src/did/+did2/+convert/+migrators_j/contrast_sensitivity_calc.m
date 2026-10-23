function bodies = contrast_sensitivity_calc(preBody)
%CONTRAST_SENSITIVITY_CALC Brainstorm-J migrator: the ndi.calc.vis.contrast_sensitivity
%   calculator OUTPUT document -> the named calculation contrast_sensitivity_calculation
%   (id-preserved) + a session anchor + its software / run entities. Single-doc fold:
%   element_id (subject_id as fallback) -> entity_id; the result fields on the
%   contrast_sensitivity_calc block -> value (jContrastSensitivityValue: one model_fit
%   entry per RB / RBN / RBNS Naka-Rushton variant, interpolated_values, significance,
%   response_type), the spatial frequencies the dimension and covariate; inherited
%   input_parameters -> method.parameters; `app` -> software / operating system /
%   interpreter.
%
%   LOSSLESS (Jess Haley 2026-10-23 [contrast sensitivity lossless]): input_id carries
%   the consumed responses (stimulus_response_scalar_id, contrasttuning_id_*) AND the
%   stimulus_presentation_id; v1 is_modulated_response (0/1) ->
%   value.significance.modulated_response (boolean), written only when present.
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'contrast_sensitivity_calculation', 'csf', ...
    'contrast_sensitivity_calc', 'contrast sensitivity', 'ndi.calc.vis.contrast_sensitivity');
end
