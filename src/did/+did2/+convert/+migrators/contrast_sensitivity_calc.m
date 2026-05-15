function v2Body = contrast_sensitivity_calc(preBody)
%CONTRAST_SENSITIVITY_CALC Migrate a did_v1 contrast_sensitivity_calc body to V_delta.
%
%   a contrast-sensitivity analysis. The v1 form
%   carries `input_parameters` directly on the contrast_sensitivity_calc block;
%   V_delta moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'contrast_sensitivity_calc');
end
