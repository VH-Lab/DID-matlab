function [blk, bad] = rawCurveBlock(leaf)
%RAWCURVEBLOCK The v1 `stimulus_tuningcurve` block rebuilt from a converted
%   tuningcurve_calc (the inverse of jTuningCurve's rawCurve, one stimulus
%   variable).
%
%   [BLK, BAD] = rawCurveBlock(LEAF), in NDI's stimulus_tuningcurve.json shape
%   as ndi.app.stimulus.tuning_response writes it (NDI-matlab locked `main`,
%   3cb19a8):
%
%     independent_variable_label  the dimension's term label, lower case, ' '
%                                 as '_' (the writer labels by the stimulus
%                                 parameter's name: 'contrast'), one cell
%     independent_variable_value  the covariate's values
%     response_mean, response_stddev, response_stderr   value.*
%     individual_responses_real / _imaginary            value.individual,
%                                 keys x trials x [real, imag] (or keys x
%                                 trials), back to trials x keys per half
%     control_response_*, control_individual_responses_*   value.control.*
%     response_units              value.response_unit's label (a spelling
%                                 jTuningCurve recognised carries the document)
%   stimid, control_stimid and stimulus_presentation_number have no V2 home: a
%   document stating them is carried, so a converted one stated none.

bad = {};
blk = struct();
value = getIn(leaf, 'tuning_curve', 'value');
if ~isstruct(value)
    bad{end+1} = 'the calculation has no tuning_curve.value';
    return;
end
covs = getIn(leaf, 'data', 'covariates');
if iscell(covs); covs = [covs{:}]; end
if isscalar(covs)
    [~, label] = termParts(covs.variable);
    blk.independent_variable_label = {lower(strrep(strtrim(label), ' ', '_'))};
    blk.independent_variable_value = column(getIn(covs, 'quantity', 'value'));
elseif numel(covs) > 1
    bad{end+1} = sprintf('%d covariates: only one stimulus variable is rebuilt', numel(covs));
end
blk = take(blk, 'response_mean', value, 'mean');
blk = take(blk, 'response_stddev', value, 'stddev');
blk = take(blk, 'response_stderr', value, 'stderr');
blk = halves(blk, 'individual_responses', value, 'individual');
if isfield(value, 'response_unit')
    [~, blk.response_units] = termParts(value.response_unit);
end
if isfield(value, 'control') && isstruct(value.control)
    ctl = value.control;
    blk = take(blk, 'control_response_mean', ctl, 'mean');
    blk = take(blk, 'control_response_stddev', ctl, 'stddev');
    blk = take(blk, 'control_response_stderr', ctl, 'stderr');
    blk = halves(blk, 'control_individual_responses', ctl, 'individual');
    bad = [bad, others(ctl, {'mean', 'stddev', 'stderr', 'individual'}, 'tuning_curve.value.control')];
end
bad = [bad, others(value, {'mean', 'stddev', 'stderr', 'individual', 'control', ...
    'response_unit'}, 'tuning_curve.value')];
end

function blk = take(blk, name, src, field)
if isfield(src, field)
    blk.(name) = column(src.(field));
end
end

function blk = halves(blk, stem, src, field)
% keys x trials x 2 ([real, imaginary] last) -> the two v1 halves
if ~isfield(src, field)
    return;
end
x = src.(field);
if ndims(x) == 3 && size(x, 3) == 2
    blk.([stem '_real']) = trialsFirstOrient(x(:, :, 1));
    blk.([stem '_imaginary']) = trialsFirstOrient(x(:, :, 2));
else
    blk.([stem '_real']) = trialsFirstOrient(x);
end
end
