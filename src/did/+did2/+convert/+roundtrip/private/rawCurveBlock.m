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
%     response_units              responseUnitsBack: the registered term's
%                                 name for a spelling jTuningCurve recognised
%                                 (compared through its registry `synonyms`,
%                                 [spelling is notation]), else the unit's label
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
%
%   SEVERAL STIMULUS VARIABLES ON A FULL GRID ([tuning grid], Jess Haley,
%   2026-10-22): jTuningCurve makes one dimension per variable, a `quantity`
%   covariate along each (its distinct values, ascending), `datum_order` 'F',
%   and reshapes every per-condition array onto the grid (column-major, first
%   variable fastest). The writer (NDI-matlab locked `main`,
%   +ndi/+app/+stimulus/tuning_response.m `tuning_curve`) stores the label as
%   ONE cell, the variable names joined by ',' (`strjoin(independent_label,
%   ',')`), and the points as `unique(independent_variable_value, 'rows')`:
%   every combination, rows in sorted (lexicographic) order. So the inverse
%   enumerates the grid's points, sorts them as rows, and flattens every
%   per-condition array in that order (Test code run 41322059537: 20211116's
%   42 two-variable curves were reported "2 covariates: only one stimulus
%   variable is rebuilt"). Covariates that are not one per dimension (the
%   `experimental condition` shape) are still reported.

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
    [labels, points, order, why] = gridPoints(covs);
    if isempty(why)
        blk.independent_variable_label = {strjoin(labels, ',')};
        blk.independent_variable_value = points;
        value = flattenGrid(value, cellfun(@numel, gridLevels(covs)), order);
    else
        bad{end+1} = sprintf('%d covariates: %s', numel(covs), why);
    end
end
blk = take(blk, 'response_mean', value, 'mean');
blk = take(blk, 'response_stddev', value, 'stddev');
blk = take(blk, 'response_stderr', value, 'stderr');
blk = halves(blk, 'individual_responses', value, 'individual');
if isfield(value, 'response_unit')
    blk.response_units = responseUnitsBack(leaf, value);
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

function levels = gridLevels(covs)
% each covariate's values, in the order of the dimension it lies along
levels = cell(1, numel(covs));
for d = 1:numel(covs)
    levels{d} = column(getIn(covs(d), 'quantity', 'value'));
end
end

function [labels, points, order, why] = gridPoints(covs)
%GRIDPOINTS The writer's points of a full-grid curve (SEVERAL STIMULUS
%   VARIABLES above): LABELS the variable names in dimension order, POINTS the
%   n x k combinations in sorted-row order, ORDER the column-major grid
%   position of each row. WHY is '' when the covariates are one per dimension
%   (along 0..k-1, each a `quantity`), else why not.
k = numel(covs);
labels = cell(1, k);
points = [];
order = [];
why = '';
levels = cell(1, k);
for d = 1:k
    along = numberOf(getIn(covs(d), 'along'));
    if ~isequal(along, d - 1)
        why = 'the covariates are not one per dimension (only a full grid is rebuilt)';
        return;
    end
    [~, label] = termParts(covs(d).variable);
    labels{d} = lower(strrep(strtrim(label), ' ', '_'));
    levels{d} = column(getIn(covs(d), 'quantity', 'value'));
    if isempty(levels{d}) || ~isnumeric(levels{d})
        why = sprintf('covariate %d holds no numbers', d);
        return;
    end
end
ext = cellfun(@numel, levels);
n = prod(ext);
subs = cell(1, k);
[subs{:}] = ind2sub([ext, 1], (1:n)');
cm = zeros(n, k);
for d = 1:k
    cm(:, d) = levels{d}(subs{d});
end
[points, order] = sortrows(cm);
end

function value = flattenGrid(value, ext, order)
% every per-condition array, from the grid back to one row per point, in the
% writer's order (ORDER: the column-major grid position of each point)
for f = {'mean', 'stddev', 'stderr', 'individual'}
    if isfield(value, f{1}); value.(f{1}) = flatOne(value.(f{1}), ext, order); end
end
if isfield(value, 'control') && isstruct(value.control)
    for f = {'mean', 'stddev', 'stderr', 'individual'}
        if isfield(value.control, f{1})
            value.control.(f{1}) = flatOne(value.control.(f{1}), ext, order);
        end
    end
end
end

function y = flatOne(x, ext, order)
% an array whose first numel(EXT) dimensions are the grid -> n rows (the
% remaining dimensions kept), rows in ORDER; anything else is left as it is
k = numel(ext);
sz = size(x);
if ~isnumeric(x) || numel(sz) < k || ~isequal(sz(1:k), ext)
    y = x;
    return;
end
n = prod(ext);
rest = sz(k+1:end);
flat = reshape(x, [n, prod(rest)]);
flat = flat(order, :);
if isempty(rest) || prod(rest) == 1
    y = flat(:, 1);
else
    y = reshape(flat, [n, rest]);
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
