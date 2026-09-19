function v2Body = simple_calc(preBody)
%SIMPLE_CALC Migrate a did_v1 simple_calc body to V_delta.
%
%   a simple example calculator. The v1 form
%   carries `input_parameters` directly on the simple_calc block;
%   V_delta moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'simple_calc');
end
