function v2Body = contrast_sensitivity_calc(preBody)
%CONTRAST_SENSITIVITY_CALC Migrate a did_v1 contrast_sensitivity_calc body to V_delta.
%
%   a contrast-sensitivity analysis. The v1 form
%   carries `input_parameters` directly on the contrast_sensitivity_calc block and
%   does not include a `calculator_name` field at all. V_delta moves
%   `input_parameters` to the inherited `calculator` block and adds
%   `calculator.calculator_name = 'ndi.calc.vis.contrast_sensitivity'` -- the
%   NDI calculator class identity that v1 left implicit.
%
%   All structural work lives in did2.convert.calcCommon; this file
%   is a thin wrapper that pins the calculator_name string.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, ...
    'contrast_sensitivity_calc', 'ndi.calc.vis.contrast_sensitivity');
end
