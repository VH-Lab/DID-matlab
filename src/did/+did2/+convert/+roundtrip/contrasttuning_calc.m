function [v1, spec] = contrasttuning_calc(bodies)
%CONTRASTTUNING_CALC Rebuild a v1 `contrasttuning_calc` from what
%   did2.convert.migrators_j.contrast_tuning_calc emitted when it CONVERTED it: the
%   `contrast_tuning_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.contrasttuning_calc(BODIES). V1 is the document in
%   the shape NDIcalc-vis-matlab ndi.calc.vis.contrast_tuning (contrasttuning_calc.json over contrast_tuning.json
%   and NDI's calculator.json, app.json, base.json)
%   writes it:
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id, stimulus_tuningcurve_id
%                                         (tuningInverse)
%     contrast_tuning                   tuningBlock (family 'contrast')
%
%   The calculator block's inner depends_on copy is stated as restating the
%   top-level edges (SPEC.equivalents); the v1 document_class beyond its
%   class name is exempt (did2.convert.roundtrip.check).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.contrast_tuning_calc.

[v1, spec] = tuningInverse(bodies, 'contrast_tuning_calculation', 'contrasttuning_calc', ...
    'ndi.calc.vis.contrast', 'contrast', 'contrast_tuning', 'stimulus_tuningcurve_id');
end
