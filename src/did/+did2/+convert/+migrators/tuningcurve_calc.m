function v2Body = tuningcurve_calc(preBody)
%TUNINGCURVE_CALC Migrate a did_v1 tuningcurve_calc body to V_delta.
%
%   a generic tuning-curve calculation. The v1 form
%   carries `input_parameters` directly on the tuningcurve_calc block and
%   does not include a `calculator_name` field at all. V_delta moves
%   `input_parameters` to the inherited `calculator` block and adds
%   `calculator.calculator_name = 'ndi.calc.stimulus.tuningcurve'` -- the
%   NDI calculator class identity that v1 left implicit.
%
%   All structural work lives in did2.convert.calcCommon; this file
%   is a thin wrapper that pins the calculator_name string.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, ...
    'tuningcurve_calc', 'ndi.calc.stimulus.tuningcurve');
end
