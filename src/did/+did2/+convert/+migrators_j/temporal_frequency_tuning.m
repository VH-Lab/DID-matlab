function bodies = temporal_frequency_tuning(preBody)
%TEMPORAL_FREQUENCY_TUNING Brainstorm-J migrator -> temporal_frequency_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: did_v1 temporal_frequency_tuning
%   (raw NDIcalc-vis result class) -> the CONCRETE V_eta leaf
%   `temporal_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, temporal_frequency_tuning]) + a session anchor
%   + minted `software` and `runtime_environment` entities.
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it. Its template is NDIcalc-vis-matlab's (00e3e0f,
%   ndi_common/database_documents/vision/temporal_frequency_tuning.json: superclass
%   `base` only, no `app` block; edges element_id and stimulus_tuningcurve_id),
%   the commit the tuning family's fixtures are taken from. Its writer is
%   ndi.calc.vis.temporal_frequency_tuning calculate_temporal_frequency_indexes
%   (temporal_frequency_tuning.m): ndi.document('temporal_frequency_tuning', 'temporal_frequency_tuning', <block>), then
%   element_id and stimulus_tuningcurve_id. The calculator adds that document
%   to its temporal_frequency_tuning_calc output rather than storing it alone, so the block
%   is the one temporal_frequency_tuning_calc holds.
%   Identity through jRawBody; depends_on and the result fields read in
%   either spelling by jCalculation / jTuningCurve, as for temporal_frequency_tuning_calc.
%   Every other field is accounted for (jCalculation
%   'AccountForEveryField', as for the calculator outputs: carry-100 for a
%   field outside the NDI template, carry-056 for a template field with no
%   home; [tuning stray fields are malformed]).
%   A carry is the untouched v1 source. did2.convert.roundtrip.temporal_frequency_tuning
%   rebuilds the v1 document; testRawV1RoundTripTuningBlocks compares the two.
arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'temporal_frequency_tuning');
bodies = jCalculation(body, 'temporal_frequency_tuning_calculation', 'tf', ...
    'temporal_frequency_tuning', 'temporal frequency tuning', 'ndi.calc.vis.temporal_frequency_tuning', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry or passthrough is the untouched v1 source
end
end
