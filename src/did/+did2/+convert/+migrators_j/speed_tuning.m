function bodies = speed_tuning(preBody)
%SPEED_TUNING Brainstorm-J migrator: did_v1 speed_tuning -> an inline tuning
%   observation (response vs stimulus SPEED) + a derived_from relation to the raw
%   stimulus_tuningcurve + the session anchor. 1 -> 2/3.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. Unlike
%   the single-axis tuning classes, speed is DERIVED: the tuning_curve stores the
%   defining (spatial_frequency, temporal_frequency) pair per point, and speed
%   (deg/s) = temporal_frequency (Hz = cycles/s) / spatial_frequency (cycles/deg).
%   That derived vector is passed to jTuningFold as the axis override so the
%   stimulus SPEED rides on the D10 `parameters` axis qualifier. When the pair is
%   unusable (length mismatch / a zero spatial frequency) it falls back to the
%   temporal-frequency axis. DEFERRED: the separable SF/TF surface (a 2-D map ->
%   two qualifiers) is a follow-up; the marginal speed axis is the honest scalar.
arguments
    preBody (1,1) struct
end
curve = struct();
if isfield(preBody, 'speed_tuning') && isstruct(preBody.speed_tuning) ...
        && isfield(preBody.speed_tuning, 'tuning_curve') ...
        && isstruct(preBody.speed_tuning.tuning_curve)
    curve = preBody.speed_tuning.tuning_curve;
end
sf = getVec(curve, 'spatial_frequency');
tf = getVec(curve, 'temporal_frequency');
if ~isempty(sf) && numel(sf) == numel(tf) && all(sf ~= 0)
    speed = tf ./ sf;               % deg/s = TF (Hz) / SF (cyc/deg)
else
    speed = tf;                     % fallback: the temporal-frequency axis
end
bodies = jTuningFold(preBody, 'speed_tuning', 'speed', 'deg/s', '', speed);
end

function v = getVec(s, name)
v = [];
if isfield(s, name) && isnumeric(s.(name)); v = double(s.(name)(:)'); end
end
