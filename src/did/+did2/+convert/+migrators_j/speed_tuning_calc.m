function bodies = speed_tuning_calc(preBody)
%SPEED_TUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.speed calculator
%   OUTPUT document -> the CONCRETE V_eta leaf `speedtuning_calc`
%   (⊂ [tuning_curve_calculation, speed_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `speedtuning_calc` (no interior underscore) per Lepsky et al.
%   2026. speed_tuning has TWO independent variables (temporal + spatial
%   frequency), first-class via independent_variables[] cardinality.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'speedtuning_calc', ...
    {'tuning_curve_calculation', 'speed_tuning'}, ...
    'tuning_curve', ...
    'speed tuning', 'ndi.calc.vis.speed', 'speed_tuning');
end
