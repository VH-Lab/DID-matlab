function bodies = orientation_direction_tuning(preBody)
%ORIENTATION_DIRECTION_TUNING Brainstorm-J migrator: did_v1
%   orientation_direction_tuning (raw NDI-matlab result class) -> the CONCRETE
%   V_eta leaf `oridirtuning_calc` (⊂ [tuning_curve_calculation,
%   orientation_direction_tuning]) + a session anchor + minted `software` and
%   `runtime_environment` entities.
%
%   PR #68 keeps the class name `orientation_direction_tuning` as a THIN MARKER
%   composite (⊂ tuning_curve) with no new fields; the actual instances become
%   concrete calc leaves. Same emit target as the raw-app sibling
%   migrators_j.stimulus_tuningcurve (which becomes `tuningcurve_calc`) and the
%   calc sibling migrators_j.oridirtuning_calc: one v1 class per source, one
%   V_eta concrete leaf per family.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'oridirtuning_calc', ...
    {'tuning_curve_calculation', 'orientation_direction_tuning'}, ...
    'tuning_curve', ...
    'orientation/direction tuning', ...
    'ndi.calc.vis.oridir', 'orientation_direction_tuning');
end
