function bodies = contrast_tuning(preBody)
%CONTRAST_TUNING Brainstorm-J migrator -> contrast_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: did_v1 contrast_tuning (raw NDIcalc-vis
%   result class) -> the CONCRETE V_eta leaf `contrasttuning_calc`
%   (⊂ [tuning_curve_calculation, contrast_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   In V_eta the class name `contrast_tuning` survives as a THIN MARKER
%   composite; concrete instances become the `contrasttuning_calc` leaf.
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it. Its template is NDIcalc-vis-matlab's (00e3e0f,
%   ndi_common/database_documents/vision/contrast_tuning.json: superclass
%   `base` only, no `app` block; edges element_id and stimulus_tuningcurve_id),
%   the commit the tuning family's fixtures are taken from. Its writer is
%   ndi.calc.vis.contrast_tuning calculate_contrast_indexes
%   (contrast_tuning.m): ndi.document('contrast_tuning', 'contrast_tuning', <block>), then
%   element_id and stimulus_tuningcurve_id. The calculator adds that document
%   to its contrasttuning_calc output rather than storing it alone, so the block
%   is the one contrasttuning_calc holds.
%   Identity through jRawBody; depends_on and the result fields read in
%   either spelling by jCalculation / jTuningCurve, as for contrasttuning_calc.
%   Every other field is accounted for (jCalculation
%   'AccountForEveryField', as for the calculator outputs: carry-100 for a
%   field outside the NDI template, carry-056 for a template field with no
%   home; [tuning stray fields are malformed]).
%   A carry is the untouched v1 source. did2.convert.roundtrip.contrast_tuning
%   rebuilds the v1 document; testRawV1RoundTripTuningBlocks compares the two.
arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'contrast_tuning');
bodies = jCalculation(body, 'contrast_tuning_calculation', 'contrast', ...
    'contrast_tuning', 'contrast tuning', 'ndi.calc.vis.contrast', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry or passthrough is the untouched v1 source
end
end
