function [blk, bad] = rawCurveBlock(leaf, own, responseId)
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
%     stimid, stimulus_presentation_number   rebuilt from the presentation
%                                 and the curve's conditions
%                                 (did2.convert.tuningStimids; Decided by Jess
%                                 Haley, 2026-10-27 [tuning stimids rebuild]):
%                                 OWN is the calculator's rebuilt block (its
%                                 input_parameters.independent_parameter names
%                                 the varied parameters; else the label),
%                                 RESPONSEID the curve's response input. When
%                                 the presentation or the response is not in
%                                 the batch, nothing is written (the migrator
%                                 converted such a curve only when it stated
%                                 neither).
%   control_stimid has no V2 home: a document stating it is carried, so a
%   converted one stated none.

if nargin < 2; own = struct(); end
if nargin < 3; responseId = ''; end
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

% [tuning stimids rebuild]
if isfield(blk, 'independent_variable_value')
    [names, values] = conditionsOf(leaf);
    [stimid, spn, why] = did2.convert.tuningStimids(blk.independent_variable_value, ...
        varied(own, blk), names, values, responseId);
    if isempty(why)
        blk.stimid = stimid;
        blk.stimulus_presentation_number = spn;
    end
end
end

function p = varied(own, blk)
%VARIED The stimulus parameters the curve varies (as jCalculation reads them).
src = getIn(own, 'input_parameters', 'independent_parameter');
if isempty(src) && isfield(blk, 'independent_variable_label')
    src = blk.independent_variable_label;
end
if iscell(src)
    src = strjoin(cellfun(@char, reshape(src, 1, []), 'UniformOutput', false), ',');
end
p = {};
if ~ischar(src) || isempty(src)
    return;
end
p = strtrim(strsplit(src, ','));
p = p(~cellfun(@isempty, p));
end

function [names, values] = conditionsOf(leaf)
%CONDITIONSOF The curve's conditions as v1 stim_property_list names/values.
names = {};
values = [];
conds = asCell(getIn(leaf, 'statement', 'conditions'));
for k = 1:numel(conds)
    [~, v2] = termParts(getIn(conds{k}, 'variable'));
    [v1Name, found] = did2.convert.tuningNames('v1', v2);
    q = numberOf(getIn(conds{k}, 'quantity', 'value'));
    if found && ~isempty(q)
        names{end+1} = v1Name; %#ok<AGROW>
        values(end+1) = q; %#ok<AGROW>
    end
end
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
