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
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (class `contrastsensitivity_calc`), with no universalRenames and no superclass
%   migrator (none exists for its superclasses; the old +migrators/contrast_sensitivity_calc.m
%   wrapper was never reached and is deleted, [early migration pieces fixed]
%   (1)). Identity through jRawBody (did2.convert.v1read.readBase); depends_on
%   in either spelling ({name, value} / {name, document_id}); the `app` block
%   in either spelling ({name, version} / {app_name, app_version};
%   jSoftwareFromApp, checked by did2.convert.v1read.readApp); NDI's camelCase
%   result fields (e.g. sensitivity_RBNS) read case- and underscore-insensitively
%   (jTuningCurve / jContrastSensitivityValue), so a body in the spelling
%   of the rename pass (since deleted) converts the same way. Every other field is accounted
%   for (jCalculation 'AccountForEveryField'); a carry is the untouched v1
%   source. did2.convert.roundtrip.contrastsensitivity_calc rebuilds the v1 document;
%   testRawV1RoundTripTuning compares the two on the writer's output
%   (ndi.calc.vis.contrast_sensitivity, NDIcalc-vis-matlab).

arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'contrastsensitivity_calc');
bodies = jCalculation(body, 'contrast_sensitivity_calculation', 'csf', ...
    char(body.document_class.class_name), 'contrast sensitivity', 'ndi.calc.vis.contrast_sensitivity', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
end
end
