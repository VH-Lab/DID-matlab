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
%
%   D-C analysis-tier decomposition (grain A): the interpretable computed scalars
%   also fold onto the neuron, each with subject_interaction.method = the algorithm
%   and derived_from_1 -> the curve obs. speed_tuning has NO fitless block, so the
%   scalars come from the canonical Priebe `fit` (the other Priebe variants
%   fit_no_speed / fit_fullspeed and the fit CURVES are deferred): the speed tuning
%   index -> score, the preferred SF/TF -> frequency_observation (cyc/deg | Hz),
%   ANOVA p / r_squared -> score.
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'speed_tuning') && isstruct(preBody.speed_tuning)
    blk = preBody.speed_tuning;
end
curve = subBlk(blk, 'tuning_curve');
sf = getVec(curve, 'spatial_frequency');
tf = getVec(curve, 'temporal_frequency');
if ~isempty(sf) && numel(sf) == numel(tf) && all(sf ~= 0)
    speed = tf ./ sf;               % deg/s = TF (Hz) / SF (cyc/deg)
else
    speed = tf;                     % fallback: the temporal-frequency axis
end
base = jTuningFold(preBody, 'speed_tuning', 'speed', 'deg/s', '', speed);
if numel(base) < 2
    bodies = base;
    return;
end
curveId  = base{1}.base.id;
anchorId = base{2}.base.id;

sig = subBlk(blk, 'significance');
fit = subBlk(blk, 'fit');
specs = {
    sig, 'visual_response_anova_p',                  'score',     'visual response anova p',      'anova',       '';
    sig, 'across_stimuli_anova_p',                   'score',     'across stimuli anova p',       'anova',       '';
    fit, 'priebe_fit_speed_tuning_index',            'score',     'speed tuning index',           'priebe fit',  '';
    fit, 'priebe_fit_spatial_frequency_preference',  'frequency', 'preferred spatial frequency',  'priebe fit',  'cyc/deg';
    fit, 'priebe_fit_temporal_frequency_preference', 'frequency', 'preferred temporal frequency', 'priebe fit',  'Hz';
    fit, 'r_squared',                                'score',     'fit r-squared',                'priebe fit',  '';
};

bodies = [base, jDecomposeScalars(preBody, curveId, anchorId, specs)];
end

function b = subBlk(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end

function v = getVec(s, name)
v = [];
if isstruct(s) && isfield(s, name) && isnumeric(s.(name)); v = double(s.(name)(:)'); end
end
