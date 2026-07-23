function v2Body = temporal_frequency_tuning_calc(preBody)
%TEMPORAL_FREQUENCY_TUNING_CALC Migrate a did_v1 temporal_frequency_tuning_calc body to V_delta.
%
%   a temporal-frequency tuning fit. The v1 form
%   carries `input_parameters` directly on the temporal_frequency_tuning_calc block;
%   V_delta moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'temporal_frequency_tuning_calc');
end
