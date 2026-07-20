function bodies = speed_tuning_calc(preBody)
%SPEED_TUNING_CALC Brainstorm-J migrator: did_v1 speed_tuning_calc -> the D-C analysis-tier
%   decomposition of its result, with the calculator's input_parameters retained.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. In did_v1
%   the calculator IS its result via superclass: a speed_tuning_calc document carries both a
%   `speed_tuning` result block (curve + interpretable scalars) and a `speed_tuning_calc` calc
%   block (input_parameters + input dependency). This is the class the REAL corpus
%   stores (the bare `speed_tuning` is rarely produced directly), so the decomposition
%   must be registered here, not only under the result name.
%
%   Delegates the fold to the result-class migrator (same curve + computed-scalar
%   decomposition, grain A), then retains the calc's input_parameters on the
%   packet-head (curve) observation as subject_interaction.method_parameters so the
%   graph packet stays reproducible (Option B). 1 -> (2 + N).
arguments
    preBody (1,1) struct
end
bodies = did2.convert.migrators_j.speed_tuning(preBody);
bodies = jAttachCalcParams(bodies, preBody, 'speed_tuning_calc');
end
