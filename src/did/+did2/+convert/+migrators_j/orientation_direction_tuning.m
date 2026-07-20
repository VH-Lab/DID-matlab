function bodies = orientation_direction_tuning(preBody)
%ORIENTATION_DIRECTION_TUNING Brainstorm-J migrator: did_v1
%   orientation_direction_tuning -> the raw tuning curve as a frequency_observation
%   PLUS its interpretable computed scalars, each as a data-type observation of the
%   neuron (D-C analysis-tier decomposition, grain A).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The
%   source doc "jams three kinds of thing into one" (the plan's cited exhibit): a
%   response curve, vector-sum indices, and double-gaussian fit parameters. J
%   decomposes it by OUTPUT KIND onto the neuron subject:
%
%     frequency_observation   the response curve (tuning_curve.mean vs direction),
%                             the stimulus direction on the D10 axis qualifier
%                             (via jTuningFold) + a derived_from directed_relation
%                             to the raw stimulus_tuningcurve + the session anchor.
%     <angle|score>_observation   each interpretable scalar (orientation/direction
%                             preference & fitted preference -> angle; HWHH tuning
%                             width -> angle; circular variance & OSI/DSI ratios &
%                             ANOVA p-values -> score). Each carries
%                             subject_interaction.method = the algorithm (vector
%                             sum / double gaussian fit / anova) marking it COMPUTED,
%                             and derived_from_1 -> the curve observation it was
%                             computed from (statement -> statement provenance).
%
%   1 -> (2 + N). Grain A: NO derived subject, NO new entity -- a tuning result is
%   a property of the neuron. The double-gaussian fit CURVE (angles vs values) is
%   DEFERRED to the 2.D data_body fold; here we surface the interpretable scalars.
arguments
    preBody (1,1) struct
end

% ---- the response curve + anchor (+ the raw-tuningcurve derived_from relation) --
base = jTuningFold(preBody, 'orientation_direction_tuning', 'direction', 'deg', 'direction');
if numel(base) < 2
    bodies = base;   % nothing to fold (no curve) -> carry unchanged
    return;
end
curveId  = base{1}.base.id;    % the frequency_observation the scalars derive from
anchorId = base{2}.base.id;    % the shared session anchor

% ---- decompose the interpretable computed scalars -> observations of the neuron -
blk = subBlk(preBody, 'orientation_direction_tuning');
vec = subBlk(blk, 'vector');
sig = subBlk(blk, 'significance');
fit = subBlk(blk, 'fit');

% {block, field, dim ('angle'|'score'), variable label, algorithm (method)}
specs = {
    vec, 'orientation_preference',              'angle', 'orientation preference',          'vector sum';
    vec, 'direction_preference',                'angle', 'direction preference',            'vector sum';
    vec, 'circular_variance',                   'score', 'orientation circular variance',   'circular variance';
    vec, 'direction_circular_variance',         'score', 'direction circular variance',     'circular variance';
    fit, 'orientation_angle_preference',        'angle', 'fitted orientation preference',   'double gaussian fit';
    fit, 'direction_angle_preference',          'angle', 'fitted direction preference',     'double gaussian fit';
    fit, 'hwhh',                                'angle', 'tuning half-width half-height',    'double gaussian fit';
    fit, 'orientation_preferred_orthogonal_ratio', 'score', 'orientation selectivity index', 'double gaussian fit';
    fit, 'direction_preferred_null_ratio',      'score', 'direction selectivity index',     'double gaussian fit';
    sig, 'visual_response_anova_p',             'score', 'visual response anova p',          'anova';
    sig, 'across_stimuli_anova_p',              'score', 'across stimuli anova p',           'anova';
};

extra = {};
for i = 1:size(specs, 1)
    v = numScalar(specs{i, 1}, specs{i, 2});
    if isempty(v); continue; end                 % scalar absent -> skip, don't invent
    dim = specs{i, 3};
    if strcmp(dim, 'angle')
        valueBlock = jMeasureArray(v, 'deg');
    else
        valueBlock = struct('value', double(v), 'scale', jOntologyTerm('', ''), ...
            'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
    end
    extra{end+1} = jComputedScalar(preBody, anchorId, curveId, [dim '_observation'], ...
        dim, specs{i, 4}, specs{i, 5}, valueBlock); %#ok<AGROW>
end

bodies = [base, extra];
end

% ===================== small helpers =======================================

function b = subBlk(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end

function v = numScalar(blk, name)
v = [];
if isstruct(blk) && isfield(blk, name)
    x = blk.(name);
    if isnumeric(x) && isscalar(x) && ~isnan(x); v = double(x); end
end
end
