function bodies = spatial_frequency_tuning(preBody)
%SPATIAL_FREQUENCY_TUNING Brainstorm-J migrator: did_v1
%   spatial_frequency_tuning -> an inline tuning observation (response vs spatial
%   frequency) + a derived_from relation to the raw stimulus_tuningcurve + the
%   session anchor. 1 -> 2/3.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. A thin
%   wrapper over jTuningFold: tuning_curve.mean is the response curve (the leaf's
%   length-N inline value); the stimulus spatial frequency (cycles/deg) is the
%   D10 `parameters` axis qualifier. The response leaf is frequency_observation
%   (a firing rate) -- the spatial-frequency AXIS is just a labeled quantity in
%   the qualifier, not a second leaf.
arguments
    preBody (1,1) struct
end
bodies = jTuningFold(preBody, 'spatial_frequency_tuning', 'spatial frequency', ...
    'cyc/deg', 'spatial_frequency');
end
