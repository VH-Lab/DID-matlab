function v2Body = oridirtuning_calc(preBody)
%ORIDIRTUNING_CALC Base migrator: did_v1 oridirtuning_calc body -> the class-preserving V2 shape.
%
%   an orientation/direction tuning fit. The v1 form
%   carries `input_parameters` directly on the oridirtuning_calc block;
%   V2 moves it to the inherited `calculator` block. The
%   calculator-identity string lives in `app.app_name` and is
%   handled by the universal `app`-block field rename in
%   did2.convert.universalRenames -- not here.

arguments
    preBody (1,1) struct
end

v2Body = did2.convert.calcCommon(preBody, 'oridirtuning_calc');
end
