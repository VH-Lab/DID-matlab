function v2Body = hartley_calc(preBody)
%HARTLEY_CALC Migrate a did_v1 hartley_calc body to V_delta.
%
%   a Hartley reverse-correlation analysis. The v1 form
%   carries `input_parameters` directly on the hartley_calc block;
%   V_delta moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'hartley_calc');
end
