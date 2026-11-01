function bodies = contrast_tuning_calc(preBody)
%CONTRAST_TUNING_CALC Brainstorm-J migrator -> contrast_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the ndi.calc.vis.contrast
%   calculator OUTPUT document -> the CONCRETE V_eta leaf `contrasttuning_calc`
%   (⊂ [tuning_curve_calculation, contrast_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `contrasttuning_calc` (no interior underscore) as the concrete
%   class per Lepsky et al. 2026. universalRenames maps the v1 body's class_name
%   from `contrasttuning_calc` -> `contrast_tuning_calc` for dispatcher routing;
%   the emitted body carries the V_eta spelling.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (class `contrasttuning_calc`), with no universalRenames and no superclass
%   migrator (none exists for its superclasses; the old +migrators/contrast_tuning_calc.m
%   wrapper was never reached and is deleted, [early migration pieces fixed]
%   (1)). Identity through jRawBody (did2.convert.v1read.readBase); depends_on
%   in either spelling ({name, value} / {name, document_id}); the `app` block
%   in either spelling ({name, version} / {app_name, app_version};
%   jSoftwareFromApp, checked by did2.convert.v1read.readApp); NDI's camelCase
%   result fields (e.g. naka_rushton_RB_parameters) read case- and underscore-insensitively
%   (jTuningCurve / jContrastSensitivityValue), so a body in the spelling
%   of the rename pass (since deleted) converts the same way. Every other field is accounted
%   for (jCalculation 'AccountForEveryField'); a carry is the untouched v1
%   source. did2.convert.roundtrip.contrasttuning_calc rebuilds the v1 document;
%   testRawV1RoundTripTuning compares the two on the writer's output
%   (ndi.calc.vis.contrast_tuning, NDIcalc-vis-matlab).

arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'contrasttuning_calc');
bodies = jCalculation(body, 'contrast_tuning_calculation', 'contrast', ...
    'contrast_tuning', 'contrast tuning', 'ndi.calc.vis.contrast', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
end
end
