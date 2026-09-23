function bodies = spatial_frequency_tuning(preBody)
%SPATIAL_FREQUENCY_TUNING Brainstorm-J migrator: did_v1 spatial_frequency_tuning
%   (raw NDIcalc-vis result class) -> the CONCRETE V_eta leaf
%   `spatial_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, spatial_frequency_tuning]) + a session anchor
%   + minted `software` and `runtime_environment` entities.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'spatial_frequency_tuning_calc', ...
    {'tuning_curve_calculation', 'spatial_frequency_tuning'}, ...
    'tuning_curve', ...
    'spatial frequency tuning', ...
    'ndi.calc.vis.spatialfrequency', 'spatial_frequency_tuning');
end
