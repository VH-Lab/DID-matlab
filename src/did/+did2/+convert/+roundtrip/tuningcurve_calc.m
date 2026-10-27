function [v1, spec] = tuningcurve_calc(bodies)
%TUNINGCURVE_CALC Rebuild a v1 `tuningcurve_calc` from what
%   did2.convert.migrators_j.tuningcurve_calc emitted when it CONVERTED it: the
%   `tuning_curve_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.tuningcurve_calc(BODIES). V1 is the document in
%   the shape NDI-matlab ndi.calc.stimulus.tuningcurve (tuningcurve_calc.json over stimulus_tuningcurve.json,
%   calculator.json, app.json and base.json at the locked `main`, 3cb19a8)
%   writes it:
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id, stimulus_response_scalar_id
%                                         (tuningInverse)
%     stimulus_tuningcurve              rawCurveBlock
%
%   The calculator block's inner depends_on copy is stated as restating the
%   top-level edges (SPEC.equivalents); the v1 document_class beyond its
%   class name is exempt (did2.convert.roundtrip.check).
%   tuningcurve_calc.log and stim_property_list are not rebuilt: a converted
%   document stated neither (jCalculation 'AccountForEveryField' carries one
%   that does).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.tuningcurve_calc.

[v1, spec] = tuningInverse(bodies, 'tuning_curve_calculation', 'tuningcurve_calc', ...
    'ndi.calc.stimulus.tuningcurve', 'stimulus', 'stimulus_tuningcurve', 'stimulus_response_scalar_id');
end
