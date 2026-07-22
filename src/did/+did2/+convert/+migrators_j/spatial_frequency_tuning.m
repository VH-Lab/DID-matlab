function bodies = spatial_frequency_tuning(preBody)
%SPATIAL_FREQUENCY_TUNING Brainstorm-J migrator: did_v1 spatial_frequency_tuning ->
%   the subject_calculation LEAF `spatial_frequency_tuning_calculation` (id-preserved)
%   + a session anchor. Calculator composite-leaf model (Lepsky et al.): the
%   structured result (tuning_curve / significance / fitless / fit_*) is kept verbatim
%   as the composite value; 1 -> 1 with base.id + depends_on preserved, the raw
%   stimulus_tuningcurve -> derived_from_1. Supersedes the grain-A decomposition.
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'spatial_frequency_tuning_calculation', ...
    'spatial_frequency_tuning', 'spatial frequency tuning', ...
    'ndi.calc.vis.spatialfrequency');
end
