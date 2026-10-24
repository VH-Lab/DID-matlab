function v2Body = spatial_frequency_tuning_calc(preBody)
%SPATIAL_FREQUENCY_TUNING_CALC Base migrator: did_v1 spatial_frequency_tuning_calc body -> the class-preserving V2 shape.
%
%   a spatial-frequency tuning fit. The v1 form
%   carries `input_parameters` directly on the spatial_frequency_tuning_calc block;
%   V2 moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'spatial_frequency_tuning_calc');
end
