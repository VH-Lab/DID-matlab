function [v1, spec] = spatial_frequency_tuning(bodies)
%SPATIAL_FREQUENCY_TUNING Rebuild a v1 `spatial_frequency_tuning` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.spatial_frequency_tuning(BODIES). V1 is the
%   document in its v1 shape (NDIcalc-vis-matlab 00e3e0f,
%   vision/spatial_frequency_tuning.json over NDI's base.json, as
%   ndi.calc.vis.spatial_frequency_tuning writes it: the result block, then
%   element_id and stimulus_tuningcurve_id; no `app` block). BODIES holds the
%   `spatial_frequency_tuning_calculation` (id preserved), the session anchor and the
%   software entity jCalculation mints for ndi.calc.vis.spatial_frequency_tuning:
%
%     identity                     calcParts (no `app`: the minted software
%                                  entity writes none)
%     depends_on                   element_id, stimulus_tuningcurve_id
%                                  (tuningInverse)
%     spatial_frequency_tuning     tuningBlock (family 'sf')
%
%   as for spatial_frequency_tuning_calc (did2.convert.roundtrip.spatial_frequency_tuning_calc), whose result block
%   is this class.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.spatial_frequency_tuning.

arguments
    bodies cell
end

[v1, spec] = tuningInverse(bodies, 'spatial_frequency_tuning_calculation', 'spatial_frequency_tuning', ...
    'ndi.calc.vis.spatial_frequency_tuning', 'sf', 'spatial_frequency_tuning', 'stimulus_tuningcurve_id');
end
