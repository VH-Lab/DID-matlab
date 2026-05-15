function v2Body = spatial_frequency_tuning_calc(preBody)
%SPATIAL_FREQUENCY_TUNING_CALC Migrate a did_v1 spatial_frequency_tuning_calc body to V_delta.
%
%   a spatial-frequency tuning fit. The v1 form
%   carries `input_parameters` directly on the spatial_frequency_tuning_calc block and
%   does not include a `calculator_name` field at all. V_delta moves
%   `input_parameters` to the inherited `calculator` block and adds
%   `calculator.calculator_name = 'ndi.calc.vis.spatial_frequency_tuning'` -- the
%   NDI calculator class identity that v1 left implicit.
%
%   All structural work lives in did2.convert.calcCommon; this file
%   is a thin wrapper that pins the calculator_name string.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, ...
    'spatial_frequency_tuning_calc', 'ndi.calc.vis.spatial_frequency_tuning');
end
