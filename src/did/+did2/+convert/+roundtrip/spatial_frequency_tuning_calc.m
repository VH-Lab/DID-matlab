function [v1, spec] = spatial_frequency_tuning_calc(bodies)
%SPATIAL_FREQUENCY_TUNING_CALC Rebuild a v1 `spatial_frequency_tuning_calc` from what
%   did2.convert.migrators_j.spatial_frequency_tuning_calc emitted when it CONVERTED it: the
%   `spatial_frequency_tuning_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.spatial_frequency_tuning_calc(BODIES). V1 is the document in
%   the shape NDIcalc-vis-matlab ndi.calc.vis.spatial_frequency_tuning (spatial_frequency_tuning_calc.json
%   over spatial_frequency_tuning.json and NDI's calculator.json, app.json, base.json)
%   writes it:
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id, stimulus_tuningcurve_id
%                                         (tuningInverse)
%     spatial_frequency_tuning          tuningBlock (family 'sf')
%
%   The calculator block's inner depends_on copy is stated as restating the
%   top-level edges (SPEC.equivalents); the v1 document_class beyond its
%   class name is exempt (did2.convert.roundtrip.check).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.spatial_frequency_tuning_calc.

[v1, spec] = tuningInverse(bodies, 'spatial_frequency_tuning_calculation', 'spatial_frequency_tuning_calc', ...
    'ndi.calc.vis.spatial_frequency_tuning', 'sf', 'spatial_frequency_tuning', 'stimulus_tuningcurve_id');
end
