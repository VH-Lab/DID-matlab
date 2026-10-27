function [v1, spec] = stimulus_tuningcurve(bodies)
%STIMULUS_TUNINGCURVE Rebuild a v1 `stimulus_tuningcurve` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.stimulus_tuningcurve(BODIES). V1 is the
%   document in NDI's v1 shape (stimulus_tuningcurve.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as ndi.app.stimulus.tuning_response
%   writes it). BODIES holds the `tuning_curve_calculation` (id preserved), the
%   session anchor and the software entity jCalculation mints for
%   ndi.app.stimulus.tuning_response: the curve is rebuilt by
%   private/rawCurveBlock and the edges by private/tuningInverse, as for
%   tuningcurve_calc (did2.convert.roundtrip.tuningcurve_calc), whose result
%   block is this class.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.stimulus_tuningcurve.

arguments
    bodies cell
end

[v1, spec] = tuningInverse(bodies, 'tuning_curve_calculation', 'stimulus_tuningcurve', ...
    'ndi.app.stimulus.tuning_response', 'stimulus', 'stimulus_tuningcurve', ...
    'stimulus_response_scalar_id');
end
