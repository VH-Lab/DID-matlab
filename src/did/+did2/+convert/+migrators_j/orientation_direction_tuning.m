function bodies = orientation_direction_tuning(preBody)
%ORIENTATION_DIRECTION_TUNING Brainstorm-J migrator: did_v1
%   orientation_direction_tuning -> an inline tuning observation (response vs
%   stimulus direction) + a derived_from relation to the raw stimulus_tuningcurve
%   + the session anchor. 1 -> 2/3.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. A thin
%   wrapper over jTuningFold: tuning_curve.mean is the response curve (the leaf's
%   length-N inline value); the stimulus direction (degrees) is the D10
%   `parameters` axis qualifier. DEFERRED: the vector-sum tuning indices (OSI/DSI,
%   pref, etc.) -> score observations / fitless summary.
arguments
    preBody (1,1) struct
end
bodies = jTuningFold(preBody, 'orientation_direction_tuning', 'direction', 'deg', 'direction');
end
