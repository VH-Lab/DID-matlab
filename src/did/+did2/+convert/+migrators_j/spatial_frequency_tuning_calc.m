function bodies = spatial_frequency_tuning_calc(preBody)
%SPATIAL_FREQUENCY_TUNING_CALC Brainstorm-J migrator -> spatial_frequency_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the
%   ndi.calc.vis.spatialfrequency calculator OUTPUT document -> the CONCRETE
%   V_eta leaf `spatial_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, spatial_frequency_tuning]) + a session anchor
%   + minted `software` and `runtime_environment` entities.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (class `spatial_frequency_tuning_calc`), with no universalRenames and no superclass
%   migrator (none exists for its superclasses; the old +migrators/spatial_frequency_tuning_calc.m
%   wrapper was never reached and is deleted, [early migration pieces fixed]
%   (1)). Identity through jRawBody (did2.convert.v1read.readBase); depends_on
%   in either spelling ({name, value} / {name, document_id}); the `app` block
%   in either spelling ({name, version} / {app_name, app_version};
%   jSoftwareFromApp, checked by did2.convert.v1read.readApp); NDI's camelCase
%   result fields (e.g. fit_dog.L50, Pref, R2) read case- and underscore-insensitively
%   (jTuningCurve / jContrastSensitivityValue), so the universalRenames path
%   ('RawV1Classes', {}) converts the same way. Every other field is accounted
%   for (jCalculation 'AccountForEveryField'); a carry is the untouched v1
%   source. did2.convert.roundtrip.spatial_frequency_tuning_calc rebuilds the v1 document;
%   testRawV1RoundTripTuning compares the two on the writer's output
%   (ndi.calc.vis.spatial_frequency_tuning, NDIcalc-vis-matlab).

arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'spatial_frequency_tuning_calc');
bodies = jCalculation(body, 'spatial_frequency_tuning_calculation', 'sf', ...
    'spatial_frequency_tuning', 'spatial frequency tuning', 'ndi.calc.vis.spatial_frequency_tuning', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
end
end
