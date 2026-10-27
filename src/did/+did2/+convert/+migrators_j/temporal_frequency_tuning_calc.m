function bodies = temporal_frequency_tuning_calc(preBody)
%TEMPORAL_FREQUENCY_TUNING_CALC Brainstorm-J migrator -> temporal_frequency_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the
%   ndi.calc.vis.temporalfrequency calculator OUTPUT document -> the CONCRETE
%   V_eta leaf `temporal_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, temporal_frequency_tuning]) + a session
%   anchor + minted `software` and `runtime_environment` entities.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (class `temporal_frequency_tuning_calc`), with no universalRenames and no superclass
%   migrator (none exists for its superclasses; the old +migrators/temporal_frequency_tuning_calc.m
%   wrapper was never reached and is deleted, [early migration pieces fixed]
%   (1)). Identity through jRawBody (did2.convert.v1read.readBase); depends_on
%   in either spelling ({name, value} / {name, document_id}); the `app` block
%   in either spelling ({name, version} / {app_name, app_version};
%   jSoftwareFromApp, checked by did2.convert.v1read.readApp); NDI's camelCase
%   result fields (e.g. fitless.H50) read case- and underscore-insensitively
%   (jTuningCurve / jContrastSensitivityValue), so the universalRenames path
%   ('RawV1Classes', {}) converts the same way. Every other field is accounted
%   for (jCalculation 'AccountForEveryField'); a carry is the untouched v1
%   source. did2.convert.roundtrip.temporal_frequency_tuning_calc rebuilds the v1 document;
%   testRawV1RoundTripTuning compares the two on the writer's output
%   (ndi.calc.vis.temporal_frequency_tuning, NDIcalc-vis-matlab).

arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'temporal_frequency_tuning_calc');
bodies = jCalculation(body, 'temporal_frequency_tuning_calculation', 'tf', ...
    'temporal_frequency_tuning', 'temporal frequency tuning', 'ndi.calc.vis.temporal_frequency_tuning', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
end
end
