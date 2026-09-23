function bodies = temporal_frequency_tuning_calc(preBody)
%TEMPORAL_FREQUENCY_TUNING_CALC Brainstorm-J migrator: the
%   ndi.calc.vis.temporalfrequency calculator OUTPUT document -> the CONCRETE
%   V_eta leaf `temporal_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, temporal_frequency_tuning]) + a session
%   anchor + minted `software` and `runtime_environment` entities.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'temporal_frequency_tuning_calc', ...
    {'tuning_curve_calculation', 'temporal_frequency_tuning'}, ...
    'tuning_curve', ...
    'temporal frequency tuning', ...
    'ndi.calc.vis.temporalfrequency', 'temporal_frequency_tuning');
end
