function bodies = speed_tuning_calc(preBody)
%SPEED_TUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.speed calculator OUTPUT
%   document -> the subject_calculation LEAF speed_tuning_calculation (id-preserved)
%   + a session anchor. Un-defers the calculator (1 -> 1, id-preserved -> downstream
%   refs resolve). Result composite kept verbatim; input_parameters ->
%   method_parameters; app kept; stimulus_tuningcurve -> derived_from_1.
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'speed_tuning_calculation', 'speed_tuning', ...
    'speed tuning', 'ndi.calc.vis.speed');
end
