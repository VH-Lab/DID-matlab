function [v1, spec] = temporal_frequency_tuning(bodies)
%TEMPORAL_FREQUENCY_TUNING Rebuild a v1 `temporal_frequency_tuning` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.temporal_frequency_tuning(BODIES). V1 is the
%   document in its v1 shape (NDIcalc-vis-matlab 00e3e0f,
%   vision/temporal_frequency_tuning.json over NDI's base.json, as
%   ndi.calc.vis.temporal_frequency_tuning writes it: the result block, then
%   element_id and stimulus_tuningcurve_id; no `app` block). BODIES holds the
%   `temporal_frequency_tuning_calculation` (id preserved), the session anchor and the
%   software entity jCalculation mints for ndi.calc.vis.temporal_frequency_tuning:
%
%     identity                     calcParts (no `app`: the minted software
%                                  entity writes none)
%     depends_on                   element_id, stimulus_tuningcurve_id
%                                  (tuningInverse)
%     temporal_frequency_tuning    tuningBlock (family 'tf')
%
%   as for temporal_frequency_tuning_calc (did2.convert.roundtrip.temporal_frequency_tuning_calc), whose result block
%   is this class.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.temporal_frequency_tuning.

arguments
    bodies cell
end

[v1, spec] = tuningInverse(bodies, 'temporal_frequency_tuning_calculation', 'temporal_frequency_tuning', ...
    'ndi.calc.vis.temporal_frequency_tuning', 'tf', 'temporal_frequency_tuning', 'stimulus_tuningcurve_id');
end
