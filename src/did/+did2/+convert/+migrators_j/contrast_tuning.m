function bodies = contrast_tuning(preBody)
%CONTRAST_TUNING Brainstorm-J migrator: did_v1 contrast_tuning -> an inline
%   tuning observation (response vs contrast) + a derived_from relation to the
%   raw stimulus_tuningcurve + the session anchor. 1 -> 2/3.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. A thin
%   wrapper over the shared jTuningFold: the response curve (tuning_curve.mean)
%   is the leaf's length-N inline value; the stimulus parameter (contrast, a
%   0-1 fraction) is the D10 `parameters` axis qualifier. DEFERRED: significance
%   (-> score observation) and the Naka-Rushton fit blocks (-> method).
arguments
    preBody (1,1) struct
end
bodies = jTuningFold(preBody, 'contrast_tuning', 'contrast', '', 'contrast');
end
