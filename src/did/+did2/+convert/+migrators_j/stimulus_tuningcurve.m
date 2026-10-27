function bodies = stimulus_tuningcurve(preBody)
%STIMULUS_TUNINGCURVE Brainstorm-J migrator: a raw ndi.app.stimulus.tuning_response
%   tuning curve (the pre-calculator-framework stimulus_tuningcurve document)
%   -> the CONCRETE V_eta leaf `tuningcurve_calc`
%   (⊂ [tuning_curve_calculation, tuning_curve]; the raw case per issue #67)
%   + a session anchor + minted `software` and `runtime_environment` entities.
%
%   V_eta preserves the v1 `stimulus_tuningcurve` shape under the `tuning_curve`
%   composite (self-describing raw curve). The raw v1 doc migrates 1 -> 1 to a
%   concrete `tuningcurve_calc` leaf whose marker superclass IS `tuning_curve`,
%   with the result fields reshaped into `tuning_curve.value` (independent
%   variables + mean/stddev/stderr/individual/control/... per the V_eta schema).
%
%   Single-doc: the writer sets a populated `element_id` (from the consumed
%   stimulus_response_scalar), so element_id -> subject_id. Same target as
%   migrators_j.tuningcurve_calc (calc sibling of this raw class).
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (stimulus_tuningcurve.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as ndi.app.stimulus.tuning_response tuning_curve
%   writes it: the curve, + E.newdocument(), stimulus_response_scalar_id and
%   element_id). Identity through jRawBody; the `app` block (none here) and the
%   result fields read in either spelling by jCalculation / jTuningCurve, as for
%   tuningcurve_calc. Every other field is accounted for (jCalculation
%   'AccountForEveryField', carry-056 as for the calculator outputs). The
%   writer always writes stimid and stimulus_presentation_number, which have no
%   V2 home, so every writer document is carried (carry-056), as before. A
%   carry is the untouched v1 source. did2.convert.roundtrip.stimulus_tuningcurve
%   rebuilds the v1 document; testRawV1RoundTripTuningResults compares the two.
arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'stimulus_tuningcurve');
bodies = jCalculation(body, 'tuning_curve_calculation', 'stimulus', ...
    'stimulus_tuningcurve', 'stimulus tuning curve', 'ndi.app.stimulus.tuning_response', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry or passthrough is the untouched v1 source
end
end
