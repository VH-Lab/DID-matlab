function [v1, spec] = contrast_tuning(bodies)
%CONTRAST_TUNING Rebuild a v1 `contrast_tuning` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.contrast_tuning(BODIES). V1 is the
%   document in its v1 shape (NDIcalc-vis-matlab 00e3e0f,
%   vision/contrast_tuning.json over NDI's base.json, as
%   ndi.calc.vis.contrast_tuning writes it: the result block, then
%   element_id and stimulus_tuningcurve_id; no `app` block). BODIES holds the
%   `contrast_tuning_calculation` (id preserved), the session anchor and the
%   software entity jCalculation mints for ndi.calc.vis.contrast:
%
%     identity                     calcParts (no `app`: the minted software
%                                  entity writes none)
%     depends_on                   element_id, stimulus_tuningcurve_id
%                                  (tuningInverse)
%     contrast_tuning              tuningBlock (family 'contrast')
%
%   as for contrasttuning_calc (did2.convert.roundtrip.contrasttuning_calc), whose result block
%   is this class.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.contrast_tuning.

arguments
    bodies cell
end

[v1, spec] = tuningInverse(bodies, 'contrast_tuning_calculation', 'contrast_tuning', ...
    'ndi.calc.vis.contrast', 'contrast', 'contrast_tuning', 'stimulus_tuningcurve_id');
end
