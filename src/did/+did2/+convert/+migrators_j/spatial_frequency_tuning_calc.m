function bodies = spatial_frequency_tuning_calc(preBody)
%SPATIAL_FREQUENCY_TUNING_CALC Brainstorm-J migrator: the
%   ndi.calc.vis.spatialfrequency calculator OUTPUT document -> the CONCRETE
%   V_eta leaf `spatial_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, spatial_frequency_tuning]) + a session anchor
%   + minted `software` and `runtime_environment` entities.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'spatial_frequency_tuning_calc', ...
    {'tuning_curve_calculation', 'spatial_frequency_tuning'}, ...
    'tuning_curve', ...
    'spatial frequency tuning', ...
    'ndi.calc.vis.spatialfrequency', 'spatial_frequency_tuning');
end
