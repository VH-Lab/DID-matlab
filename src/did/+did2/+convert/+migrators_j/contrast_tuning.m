function bodies = contrast_tuning(preBody)
%CONTRAST_TUNING Brainstorm-J migrator: did_v1 contrast_tuning -> the response
%   curve as a frequency_observation PLUS its interpretable computed scalars, each
%   a data-type observation of the neuron (D-C analysis-tier decomposition, grain A).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The curve
%   (tuning_curve.mean vs contrast, contrast on the D10 axis) folds via jTuningFold;
%   the interpretable scalars decompose onto the same neuron, each carrying
%   subject_interaction.method = the algorithm and derived_from_1 -> the curve obs.
%
%   Scalar mapping (empirical + the canonical 4-parameter Naka-Rushton fit; the
%   other fits rb/rbn and the fit CURVES are deferred to a later fit/2.D pass):
%     significance ANOVA p-values      -> score_observation (method 'anova')
%     fitless.interpolated_c50         -> score_observation (empirical C50, 0-1)
%     naka_rushton_rbns C50 / pref / r2 / relative_max_gain / saturation_index
%                                      -> score_observation (method 'naka-rushton (rbns)')
%
%   1 -> (2 + N). Grain A: no derived subject, no directed_relation.
arguments
    preBody (1,1) struct
end
base = jTuningFold(preBody, 'contrast_tuning', 'contrast', '', 'contrast');
if numel(base) < 2
    bodies = base;   % nothing to fold (no curve) -> carry unchanged
    return;
end
curveId  = base{1}.base.id;
anchorId = base{2}.base.id;

blk     = subBlk(preBody, 'contrast_tuning');
sig     = subBlk(blk, 'significance');
fitless = subBlk(blk, 'fitless');
nr      = subBlk(subBlk(blk, 'fit'), 'naka_rushton_rbns');

specs = {
    sig,     'visual_response_anova_p', 'score', 'visual response anova p',  'anova',              '';
    sig,     'across_stimuli_anova_p',  'score', 'across stimuli anova p',   'anova',              '';
    fitless, 'interpolated_c50',        'score', 'interpolated c50',         'empirical',          '';
    nr,      'empirical_c50',           'score', 'c50',                      'naka-rushton (rbns)', '';
    nr,      'pref',                    'score', 'preferred contrast',       'naka-rushton (rbns)', '';
    nr,      'r2',                      'score', 'fit r-squared',            'naka-rushton (rbns)', '';
    nr,      'relative_max_gain',       'score', 'relative max gain',        'naka-rushton (rbns)', '';
    nr,      'saturation_index',        'score', 'saturation index',         'naka-rushton (rbns)', '';
};

bodies = [base, jDecomposeScalars(preBody, curveId, anchorId, specs)];
end

function b = subBlk(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end
