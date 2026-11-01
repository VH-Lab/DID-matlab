function bodies = oridirtuning_calc(preBody)
%ORIDIRTUNING_CALC Brainstorm-J migrator -> orientation_direction_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the ndi.calc.vis.oridir calculator
%   OUTPUT document -> the CONCRETE V_eta leaf `oridirtuning_calc`
%   (⊂ [tuning_curve_calculation, orientation_direction_tuning]) + a session
%   anchor + minted `software` and `runtime_environment` entities.
%
%   PR #68 (Waltham-Data-Science/DID-schema): the R2/R3 leaf collapse is
%   reversed. This migrator no longer emits the abstract
%   `tuning_curve_calculation` as the concrete class -- the concrete class is
%   `oridirtuning_calc` (v1 spelling per Lepsky et al. 2026 Fig. 4). The
%   composite value fields land on `tuning_curve.value`; the calc-family fields
%   (significance, model_fit) land on `tuning_curve_calculation`; the marker
%   `orientation_direction_tuning` has no new fields per its V_eta schema.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved (downstream calc
%   references resolve) and the input document(s) consumed -> derived_from_#.
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (class `oridirtuning_calc`), with no universalRenames and no superclass
%   migrator (none exists for its superclasses; the old +migrators/oridirtuning_calc.m
%   wrapper was never reached and is deleted, [early migration pieces fixed]
%   (1)). Identity through jRawBody (did2.convert.v1read.readBase); depends_on
%   in either spelling ({name, value} / {name, document_id}); the `app` block
%   in either spelling ({name, version} / {app_name, app_version};
%   jSoftwareFromApp, checked by did2.convert.v1read.readApp); NDI's camelCase
%   result fields (e.g. vector.Hotelling2Test) read case- and underscore-insensitively
%   (jTuningCurve / jContrastSensitivityValue), so a body in the spelling
%   of the rename pass (since deleted) converts the same way. Every other field is accounted
%   for (jCalculation 'AccountForEveryField'); a carry is the untouched v1
%   source. did2.convert.roundtrip.oridirtuning_calc rebuilds the v1 document;
%   testRawV1RoundTripTuning compares the two on the writer's output
%   (ndi.calc.vis.oridir_tuning, NDIcalc-vis-matlab).

arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'oridirtuning_calc');
bodies = jCalculation(body, 'orientation_direction_tuning_calculation', 'oridir', ...
    'orientation_direction_tuning', 'orientation/direction tuning', 'ndi.calc.vis.oridir', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
end
end
