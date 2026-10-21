function bodies = contrast_tuning(preBody)
%CONTRAST_TUNING Brainstorm-J migrator -> contrast_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: did_v1 contrast_tuning (raw NDIcalc-vis
%   result class) -> the CONCRETE V_eta leaf `contrasttuning_calc`
%   (⊂ [tuning_curve_calculation, contrast_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   In V_eta the class name `contrast_tuning` survives as a THIN MARKER
%   composite; concrete instances become the `contrasttuning_calc` leaf.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'contrast_tuning_calculation', 'contrast', ...
    'contrast_tuning', 'contrast tuning', 'ndi.calc.vis.contrast');
end
