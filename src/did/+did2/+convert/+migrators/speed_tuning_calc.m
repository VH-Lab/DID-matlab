function v2Body = speed_tuning_calc(preBody)
%SPEED_TUNING_CALC Migrate a did_v1 speed_tuning_calc body to V_delta.
%
%   a speed tuning fit. The v1 form
%   carries `input_parameters` directly on the speed_tuning_calc block;
%   V_delta moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'speed_tuning_calc');
end
