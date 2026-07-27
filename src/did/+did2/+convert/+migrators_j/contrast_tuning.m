function bodies = contrast_tuning(preBody)
%CONTRAST_TUNING Brainstorm-J migrator: did_v1 contrast_tuning -> the
%   subject_calculation LEAF `contrast_tuning_calculation` (id-preserved) + a session
%   anchor. Calculator composite-leaf model (Lepsky et al.): the structured result
%   (tuning_curve / significance / fitless / fit) is kept verbatim as the composite
%   value; 1 -> 1 with base.id + depends_on preserved (downstream refs resolve), the
%   raw stimulus_tuningcurve -> derived_from_1. Supersedes the grain-A decomposition.
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuning_curve_calculation', 'tuning_curve', ...
        'contrast tuning', 'ndi.calc.vis.contrast', 'contrast_tuning');
end
