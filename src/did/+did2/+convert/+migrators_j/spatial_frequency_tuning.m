function bodies = spatial_frequency_tuning(preBody)
%SPATIAL_FREQUENCY_TUNING Brainstorm-J migrator -> spatial_frequency_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: did_v1 spatial_frequency_tuning
%   (raw NDIcalc-vis result class) -> the CONCRETE V_eta leaf
%   `spatial_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, spatial_frequency_tuning]) + a session anchor
%   + minted `software` and `runtime_environment` entities.
%
%   See did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it. Its template is NDIcalc-vis-matlab's (00e3e0f,
%   ndi_common/database_documents/vision/spatial_frequency_tuning.json: superclass
%   `base` only, no `app` block; edges element_id and stimulus_tuningcurve_id),
%   the commit the tuning family's fixtures are taken from. Its writer is
%   ndi.calc.vis.spatial_frequency_tuning calculate_spatial_frequency_indexes
%   (spatial_frequency_tuning.m): ndi.document('spatial_frequency_tuning', 'spatial_frequency_tuning', <block>), then
%   element_id and stimulus_tuningcurve_id. The calculator adds that document
%   to its spatial_frequency_tuning_calc output rather than storing it alone, so the block
%   is the one spatial_frequency_tuning_calc holds.
%   Identity through jRawBody; depends_on and the result fields read in
%   either spelling by jCalculation / jTuningCurve, as for spatial_frequency_tuning_calc.
%   Every other field is accounted for (jCalculation
%   'AccountForEveryField', carry-056 as for the calculator outputs).
%   A carry is the untouched v1 source. did2.convert.roundtrip.spatial_frequency_tuning
%   rebuilds the v1 document; testRawV1RoundTripTuningBlocks compares the two.
arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'spatial_frequency_tuning');
bodies = jCalculation(body, 'spatial_frequency_tuning_calculation', 'sf', ...
    'spatial_frequency_tuning', 'spatial frequency tuning', 'ndi.calc.vis.spatial_frequency_tuning', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry or passthrough is the untouched v1 source
end
end
