function bodies = speed_tuning(preBody)
%SPEED_TUNING Brainstorm-J migrator -> speed_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: did_v1 speed_tuning (raw NDIcalc-vis result
%   class) -> the CONCRETE V_eta leaf `speedtuning_calc`
%   (⊂ [tuning_curve_calculation, speed_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `speedtuning_calc` (no interior underscore) per Lepsky et al.
%   2026. speed_tuning is nominally 2-D via independent_variables[] cardinality.
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it. Its template is NDIcalc-vis-matlab's (00e3e0f,
%   ndi_common/database_documents/vision/speed_tuning.json: superclass
%   `base` only, no `app` block; edges element_id and stimulus_tuningcurve_id),
%   the commit the tuning family's fixtures are taken from. Its writer is
%   ndi.calc.vis.speed_tuning calculate_speed_indexes
%   (speed_tuning.m): ndi.document('speed_tuning', 'speed_tuning', <block>), then
%   element_id and stimulus_tuningcurve_id. The calculator adds that document
%   to its speedtuning_calc output rather than storing it alone, so the block
%   is the one speedtuning_calc holds.
%   The fold is the one speed_tuning_calc runs (private/jSpeedTuning): the
%   collision check of the renamed path (carry-049), jCalculation
%   'AccountForEveryField', and a document whose fit blocks would become
%   model_fit entries no reader can tell apart (`fit`, `fit_no_speed`,
%   `fit_fullspeed`, all 'Priebe fit') carried whole as v1 (carry-056).
%   A carry is the untouched v1 source. did2.convert.roundtrip.speed_tuning
%   rebuilds the v1 document; testRawV1RoundTripTuningBlocks compares the two.
arguments
    preBody (1,1) struct
end
bodies = jSpeedTuning(preBody, 'speed_tuning');   % private/jSpeedTuning
end
