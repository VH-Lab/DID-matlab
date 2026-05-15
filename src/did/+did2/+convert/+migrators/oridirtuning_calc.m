function v2Body = oridirtuning_calc(preBody)
%ORIDIRTUNING_CALC Migrate a did_v1 oridirtuning_calc body to V_delta.
%
%   an orientation/direction tuning fit. The v1 form
%   carries `input_parameters` directly on the oridirtuning_calc block and
%   does not include a `calculator_name` field at all. V_delta moves
%   `input_parameters` to the inherited `calculator` block and adds
%   `calculator.calculator_name = 'ndi.calc.vis.oridir_tuning'` -- the
%   NDI calculator class identity that v1 left implicit.
%
%   All structural work lives in did2.convert.calcCommon; this file
%   is a thin wrapper that pins the calculator_name string.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, ...
    'oridirtuning_calc', 'ndi.calc.vis.oridir_tuning');
end
