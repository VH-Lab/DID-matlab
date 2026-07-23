function bodies = temporal_frequency_tuning_calc(preBody)
%TEMPORAL_FREQUENCY_TUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.temporalfrequency
%   calculator OUTPUT document -> the subject_calculation LEAF
%   temporal_frequency_tuning_calculation (id-preserved) + a session anchor. Un-defers
%   the calculator (1 -> 1, id-preserved -> downstream refs resolve). Result composite
%   kept verbatim; input_parameters -> method_parameters; app kept; stimulus_tuningcurve
%   -> derived_from_1. See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'temporal_frequency_tuning_calculation', ...
    'temporal_frequency_tuning', 'temporal frequency tuning', ...
    'ndi.calc.vis.temporalfrequency');
end
