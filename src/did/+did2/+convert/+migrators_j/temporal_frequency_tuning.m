function bodies = temporal_frequency_tuning(preBody)
%TEMPORAL_FREQUENCY_TUNING Brainstorm-J migrator: did_v1 temporal_frequency_tuning
%   (raw NDIcalc-vis result class) -> the CONCRETE V_eta leaf
%   `temporal_frequency_tuning_calc`
%   (⊂ [tuning_curve_calculation, temporal_frequency_tuning]) + a session anchor
%   + minted `software` and `runtime_environment` entities.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'temporal_frequency_tuning_calc', ...
    {'tuning_curve_calculation', 'temporal_frequency_tuning'}, ...
    'tuning_curve', ...
    'temporal frequency tuning', ...
    'ndi.calc.vis.temporalfrequency', 'temporal_frequency_tuning');
end
