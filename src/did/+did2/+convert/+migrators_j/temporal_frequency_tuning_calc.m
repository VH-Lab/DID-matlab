function bodies = temporal_frequency_tuning_calc(preBody)
%TEMPORAL_FREQUENCY_TUNING_CALC Brainstorm-J migrator -> temporal_frequency_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the
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
bodies = jCalculation(preBody, 'temporal_frequency_tuning_calculation', 'tf', ...
    'temporal_frequency_tuning', 'temporal frequency tuning', 'ndi.calc.vis.temporal_frequency_tuning');
end
