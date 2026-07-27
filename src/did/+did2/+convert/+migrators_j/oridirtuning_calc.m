function bodies = oridirtuning_calc(preBody)
%ORIDIRTUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.oridir calculator OUTPUT
%   document -> the subject_calculation LEAF orientation_direction_tuning_calculation
%   (id-preserved) + a session anchor. Un-defers this calculator: the 1 -> 1,
%   id-preserving fold means downstream calc references resolve (Lepsky et al.). The
%   result composite (orientation_direction_tuning) is kept verbatim; the calc block's
%   input_parameters -> method_parameters; the app block is kept; the raw
%   stimulus_tuningcurve -> derived_from_1. Same leaf as its result-class sibling
%   migrators_j.orientation_direction_tuning. See ...migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
    'orientation/direction tuning', ...
    'ndi.calc.vis.oridir', 'orientation_direction_tuning');
end
