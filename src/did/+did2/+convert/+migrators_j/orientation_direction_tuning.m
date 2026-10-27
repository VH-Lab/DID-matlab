function bodies = orientation_direction_tuning(preBody)
%ORIENTATION_DIRECTION_TUNING Brainstorm-J migrator -> orientation_direction_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: did_v1
%   orientation_direction_tuning (raw NDI-matlab result class) -> the CONCRETE
%   V_eta leaf `oridirtuning_calc` (⊂ [tuning_curve_calculation,
%   orientation_direction_tuning]) + a session anchor + minted `software` and
%   `runtime_environment` entities.
%
%   PR #68 keeps the class name `orientation_direction_tuning` as a THIN MARKER
%   composite (⊂ tuning_curve) with no new fields; the actual instances become
%   concrete calc leaves. Same emit target as the raw-app sibling
%   migrators_j.stimulus_tuningcurve (which becomes `tuningcurve_calc`) and the
%   calc sibling migrators_j.oridirtuning_calc: one v1 class per source, one
%   V_eta concrete leaf per family.
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (orientation_direction_tuning.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as ndi.app.oridirtuning
%   calculate_oridir_indexes writes it: properties, tuning_curve, significance,
%   vector (the writer spells Hotelling2Test), fit, + the app's newdocument(),
%   element_id and stimulus_tuningcurve_id). Identity through jRawBody; the
%   `app` block and the result fields read in either spelling by jCalculation
%   / jTuningCurve, as for oridirtuning_calc. Every other field is accounted
%   for (jCalculation 'AccountForEveryField', carry-056 as for the calculator
%   outputs). A carry is the untouched v1 source.
%   did2.convert.roundtrip.orientation_direction_tuning rebuilds the v1
%   document; testRawV1RoundTripTuningResults compares the two.
arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'orientation_direction_tuning');
bodies = jCalculation(body, 'orientation_direction_tuning_calculation', 'oridir', ...
    'orientation_direction_tuning', 'orientation/direction tuning', 'ndi.calc.vis.oridir', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry or passthrough is the untouched v1 source
end
end
