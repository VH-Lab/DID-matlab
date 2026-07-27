function bodies = speed_tuning(preBody)
%SPEED_TUNING Brainstorm-J migrator: did_v1 speed_tuning -> the subject_calculation
%   LEAF `speed_tuning_calculation` (id-preserved) + a session anchor. Calculator
%   composite-leaf model (Lepsky et al.): the structured result (tuning_curve over
%   spatial x temporal frequency / significance / fit_*) is kept verbatim as the
%   composite value; 1 -> 1 with base.id + depends_on preserved, the raw
%   stimulus_tuningcurve -> derived_from_1. Supersedes the grain-A decomposition
%   (which derived a speed axis and folded to observations).
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
        'speed tuning', 'ndi.calc.vis.speed', 'speed_tuning');
end
