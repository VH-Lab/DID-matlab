function bodies = contrast_tuning_calc(preBody)
%CONTRAST_TUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.contrast
%   calculator OUTPUT document -> the CONCRETE V_eta leaf `contrasttuning_calc`
%   (⊂ [tuning_curve_calculation, contrast_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `contrasttuning_calc` (no interior underscore) as the concrete
%   class per Lepsky et al. 2026. universalRenames maps the v1 body's class_name
%   from `contrasttuning_calc` -> `contrast_tuning_calc` for dispatcher routing;
%   the emitted body carries the V_eta spelling.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'contrasttuning_calc', ...
    {'tuning_curve_calculation', 'contrast_tuning'}, ...
    'tuning_curve', ...
    'contrast tuning', 'ndi.calc.vis.contrast', 'contrast_tuning');
end
