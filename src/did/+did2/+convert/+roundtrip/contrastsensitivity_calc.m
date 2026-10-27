function [v1, spec] = contrastsensitivity_calc(bodies)
%CONTRASTSENSITIVITY_CALC Rebuild a v1 `contrastsensitivity_calc` from what
%   did2.convert.migrators_j.contrast_sensitivity_calc emitted when it CONVERTED it: the
%   `contrast_sensitivity_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.contrastsensitivity_calc(BODIES). V1 is the document in
%   the shape NDIcalc-vis-matlab ndi.calc.vis.contrast_sensitivity (contrastsensitivity_calc.json over NDI's
%   calculator.json, app.json, base.json)
%   writes it:
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id, the csf inputs
%                                         (tuningInverse)
%     contrastsensitivity_calc          csfBlock
%
%   The calculator block's inner depends_on copy is stated as restating the
%   top-level edges (SPEC.equivalents); the v1 document_class beyond its
%   class name is exempt (did2.convert.roundtrip.check).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.contrast_sensitivity_calc.

[v1, spec] = tuningInverse(bodies, 'contrast_sensitivity_calculation', 'contrastsensitivity_calc', ...
    'ndi.calc.vis.contrast_sensitivity', 'csf', 'contrastsensitivity_calc', 'csf');
end
