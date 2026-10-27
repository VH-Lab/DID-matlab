function [v1, spec] = oridirtuning_calc(bodies)
%ORIDIRTUNING_CALC Rebuild a v1 `oridirtuning_calc` from what
%   did2.convert.migrators_j.oridirtuning_calc emitted when it CONVERTED it: the
%   `orientation_direction_tuning_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.oridirtuning_calc(BODIES). V1 is the document in
%   the shape NDIcalc-vis-matlab ndi.calc.vis.oridir_tuning (oridirtuning_calc.json over NDI's
%   orientation_direction_tuning.json, calculator.json, app.json, base.json)
%   writes it:
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id, stimulus_tuningcurve_id
%                                         (tuningInverse)
%     orientation_direction_tuning      tuningBlock (family 'oridir')
%
%   The calculator block's inner depends_on copy is stated as restating the
%   top-level edges (SPEC.equivalents); the v1 document_class beyond its
%   class name is exempt (did2.convert.roundtrip.check).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.oridirtuning_calc.

[v1, spec] = tuningInverse(bodies, 'orientation_direction_tuning_calculation', 'oridirtuning_calc', ...
    'ndi.calc.vis.oridir', 'oridir', 'orientation_direction_tuning', 'stimulus_tuningcurve_id');
end
