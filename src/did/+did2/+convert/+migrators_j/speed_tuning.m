function bodies = speed_tuning(preBody)
%SPEED_TUNING Brainstorm-J migrator: did_v1 speed_tuning (raw NDIcalc-vis result
%   class) -> the CONCRETE V_eta leaf `speedtuning_calc`
%   (⊂ [tuning_curve_calculation, speed_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `speedtuning_calc` (no interior underscore) per Lepsky et al.
%   2026. speed_tuning is nominally 2-D via independent_variables[] cardinality.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'speedtuning_calc', ...
    {'tuning_curve_calculation', 'speed_tuning'}, ...
    'tuning_curve', ...
    'speed tuning', 'ndi.calc.vis.speed', 'speed_tuning');
end
