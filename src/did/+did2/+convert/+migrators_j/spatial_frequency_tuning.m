function bodies = spatial_frequency_tuning(preBody)
%SPATIAL_FREQUENCY_TUNING Brainstorm-J migrator: did_v1 spatial_frequency_tuning
%   -> the response curve as a frequency_observation PLUS its interpretable
%   computed scalars, each a data-type observation of the neuron (D-C analysis-tier
%   decomposition, grain A).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. Curve
%   (mean vs spatial frequency, spatial frequency on the D10 axis) via jTuningFold;
%   the scalars decompose onto the same neuron, method = algorithm, derived_from_1
%   -> the curve obs.
%
%   Scalar mapping (empirical fitless block + the canonical difference-of-gaussians
%   fit; the other fits movshon/movshon_c/spline/gausslog and the fit CURVES are
%   deferred). Spatial frequencies (preferred / 50%% cutoffs) -> frequency_observation
%   in cyc/deg [DOMAIN NOTE: a spatial frequency is dimensionally 1/angle, mapped to
%   the frequency composite via the source_unit string; revisit if a distinct
%   spatial-frequency dimension is added]. Bandwidth / pass indices / ANOVA p / r2
%   -> score_observation.
%
%   1 -> (2 + N). Grain A: no derived subject, no directed_relation.
arguments
    preBody (1,1) struct
end
base = jTuningFold(preBody, 'spatial_frequency_tuning', 'spatial frequency', ...
    'cyc/deg', 'spatial_frequency');
if numel(base) < 2
    bodies = base;
    return;
end
curveId  = base{1}.base.id;
anchorId = base{2}.base.id;

blk = subBlk(preBody, 'spatial_frequency_tuning');
sig = subBlk(blk, 'significance');
fl  = subBlk(blk, 'fitless');
dog = subBlk(blk, 'fit_dog');

specs = {
    sig, 'visual_response_anova_p', 'score',     'visual response anova p',              'anova',                 '';
    sig, 'across_stimuli_anova_p',  'score',     'across stimuli anova p',               'anova',                 '';
    fl,  'pref',                    'frequency', 'preferred spatial frequency',          'empirical',             'cyc/deg';
    fl,  'l50',                     'frequency', 'low spatial-frequency 50% cutoff',     'empirical',             'cyc/deg';
    fl,  'h50',                     'frequency', 'high spatial-frequency 50% cutoff',    'empirical',             'cyc/deg';
    fl,  'bandwidth',               'score',     'spatial-frequency bandwidth (octaves)', 'empirical',            '';
    fl,  'low_pass_index',          'score',     'low-pass index',                       'empirical',             '';
    fl,  'high_pass_index',         'score',     'high-pass index',                      'empirical',             '';
    dog, 'r2',                      'score',     'fit r-squared',                        'difference of gaussians', '';
    dog, 'pref',                    'frequency', 'fitted preferred spatial frequency',   'difference of gaussians', 'cyc/deg';
};

bodies = [base, jDecomposeScalars(preBody, curveId, anchorId, specs)];
end

function b = subBlk(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end
