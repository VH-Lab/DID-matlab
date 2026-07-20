function bodies = temporal_frequency_tuning(preBody)
%TEMPORAL_FREQUENCY_TUNING Brainstorm-J migrator: did_v1 temporal_frequency_tuning
%   -> the response curve as a frequency_observation PLUS its interpretable
%   computed scalars, each a data-type observation of the neuron (D-C analysis-tier
%   decomposition, grain A).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. Curve
%   (mean vs temporal frequency, temporal frequency on the D10 axis) via jTuningFold;
%   scalars decompose onto the same neuron, method = algorithm, derived_from_1 ->
%   the curve obs.
%
%   Scalar mapping mirrors spatial_frequency_tuning (empirical fitless + canonical
%   difference-of-gaussians fit; other fits + fit CURVES deferred). Temporal
%   frequencies (preferred / 50%% cutoffs) -> frequency_observation in Hz (a
%   genuine temporal frequency); bandwidth / pass indices / ANOVA p / r2 ->
%   score_observation.
%
%   1 -> (2 + N). Grain A: no derived subject, no directed_relation.
arguments
    preBody (1,1) struct
end
base = jTuningFold(preBody, 'temporal_frequency_tuning', 'temporal frequency', ...
    'Hz', 'temporal_frequency');
if numel(base) < 2
    bodies = base;
    return;
end
curveId  = base{1}.base.id;
anchorId = base{2}.base.id;

blk = subBlk(preBody, 'temporal_frequency_tuning');
sig = subBlk(blk, 'significance');
fl  = subBlk(blk, 'fitless');
dog = subBlk(blk, 'fit_dog');

specs = {
    sig, 'visual_response_anova_p', 'score',     'visual response anova p',               'anova',                 '';
    sig, 'across_stimuli_anova_p',  'score',     'across stimuli anova p',                'anova',                 '';
    fl,  'pref',                    'frequency', 'preferred temporal frequency',          'empirical',             'Hz';
    fl,  'l50',                     'frequency', 'low temporal-frequency 50% cutoff',     'empirical',             'Hz';
    fl,  'h50',                     'frequency', 'high temporal-frequency 50% cutoff',    'empirical',             'Hz';
    fl,  'bandwidth',               'score',     'temporal-frequency bandwidth (octaves)', 'empirical',            '';
    fl,  'low_pass_index',          'score',     'low-pass index',                        'empirical',             '';
    fl,  'high_pass_index',         'score',     'high-pass index',                       'empirical',             '';
    dog, 'r2',                      'score',     'fit r-squared',                         'difference of gaussians', '';
    dog, 'pref',                    'frequency', 'fitted preferred temporal frequency',   'difference of gaussians', 'Hz';
};

bodies = [base, jDecomposeScalars(preBody, curveId, anchorId, specs)];
end

function b = subBlk(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end
