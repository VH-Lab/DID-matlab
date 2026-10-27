function bodies = tuningcurve_calc(preBody)
%TUNINGCURVE_CALC Brainstorm-J migrator: the ndi.calc.stimulus.tuningcurve
%   calculator OUTPUT document -> the CONCRETE V_eta leaf `tuningcurve_calc`
%   (⊂ [tuning_curve_calculation, tuning_curve]; the raw case per issue #67)
%   + a session anchor + minted `software` and `runtime_environment` entities.
%
%   In V_eta, `tuningcurve_calc` is the raw case: its marker superclass IS
%   `tuning_curve` (not a thin subclass of it), so the composite value block
%   and the marker block are the same. The fold otherwise mirrors the five
%   fitted per-family leaves.
%
%   Single-doc: a tuningcurve_calc IS-A stimulus_tuningcurve (v1 superclass) and
%   so carries the inherited `element_id` -- the NDI writer sets it from the
%   consumed stimulus_response_scalar (ndi.app.stimulus.tuning_response.tuning_curve).
%   element_id -> subject_id; the tuning-curve result fields sit on the inherited
%   `stimulus_tuningcurve` block (sourceBlock) and are reshaped to V_eta's
%   tuning_curve.value shape.
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (class `tuningcurve_calc`), with no universalRenames and no superclass
%   migrator (none exists for its superclasses; the old +migrators/tuningcurve_calc.m
%   wrapper was never reached and is deleted, [early migration pieces fixed]
%   (1)). Identity through jRawBody (did2.convert.v1read.readBase); depends_on
%   in either spelling ({name, value} / {name, document_id}); the `app` block
%   in either spelling ({name, version} / {app_name, app_version};
%   jSoftwareFromApp, checked by did2.convert.v1read.readApp); NDI's camelCase
%   result fields (e.g. independent_variable_label) read case- and underscore-insensitively
%   (jTuningCurve / jContrastSensitivityValue), so the universalRenames path
%   ('RawV1Classes', {}) converts the same way. Every other field is accounted
%   for (jCalculation 'AccountForEveryField'); a carry is the untouched v1
%   source. did2.convert.roundtrip.tuningcurve_calc rebuilds the v1 document;
%   testRawV1RoundTripTuning compares the two on the writer's output
%   (ndi.calc.stimulus.tuningcurve, NDI-matlab).

arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'tuningcurve_calc');
bodies = jCalculation(body, 'tuning_curve_calculation', 'stimulus', ...
    'stimulus_tuningcurve', 'stimulus tuning curve', 'ndi.calc.stimulus.tuningcurve', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
end
end
