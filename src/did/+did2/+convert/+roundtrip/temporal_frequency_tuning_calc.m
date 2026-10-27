function [v1, spec] = temporal_frequency_tuning_calc(bodies)
%TEMPORAL_FREQUENCY_TUNING_CALC Rebuild a v1 `temporal_frequency_tuning_calc` from what
%   did2.convert.migrators_j.temporal_frequency_tuning_calc emitted when it CONVERTED it: the
%   `temporal_frequency_tuning_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.temporal_frequency_tuning_calc(BODIES). V1 is the document in
%   the shape NDIcalc-vis-matlab ndi.calc.vis.temporal_frequency_tuning (temporal_frequency_tuning_calc.json
%   over temporal_frequency_tuning.json and NDI's calculator.json, app.json, base.json)
%   writes it:
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id, stimulus_tuningcurve_id
%                                         (tuningInverse)
%     temporal_frequency_tuning         tuningBlock (family 'tf')
%
%   The calculator block's inner depends_on copy is stated as restating the
%   top-level edges (SPEC.equivalents); the v1 document_class beyond its
%   class name is exempt (did2.convert.roundtrip.check).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.temporal_frequency_tuning_calc.

[v1, spec] = tuningInverse(bodies, 'temporal_frequency_tuning_calculation', 'temporal_frequency_tuning_calc', ...
    'ndi.calc.vis.temporal_frequency_tuning', 'tf', 'temporal_frequency_tuning', 'stimulus_tuningcurve_id');
end
