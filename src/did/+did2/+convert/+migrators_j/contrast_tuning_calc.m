function bodies = contrast_tuning_calc(preBody)
%CONTRAST_TUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.contrast calculator
%   OUTPUT document -> the subject_calculation LEAF contrast_tuning_calculation
%   (id-preserved) + a session anchor. Un-defers the calculator (1 -> 1, id-preserved
%   -> downstream refs resolve). Result composite kept verbatim; input_parameters ->
%   method_parameters; app kept; stimulus_tuningcurve -> derived_from_1.
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'contrast_tuning_calculation', 'contrast_tuning', ...
    'contrast tuning', 'ndi.calc.vis.contrast');
end
