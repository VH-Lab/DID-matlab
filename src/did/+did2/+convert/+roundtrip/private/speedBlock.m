function [blk, bad] = speedBlock(leaf)
%SPEEDBLOCK The v1 `speed_tuning` block rebuilt from a converted
%   speed_tuning_calculation (the inverse of +migrators_j/private/jTuningCurve
%   for the two-variable speed curve).
%
%   [BLK, BAD] = speedBlock(LEAF). Field names are the WRITER's spellings
%   (NDIcalc-vis-matlab ndi.calc.vis.speed_tuning, mock/speed_tuning/mock.N.json):
%
%     properties.response_units, response_type   value.response_unit / response_type
%                                (response_units by responseUnitsBack: a
%                                recognised spelling comes back as its
%                                registered term's name, [spelling is notation])
%     tuning_curve.spatial_frequency,
%       temporal_frequency       one condition per grid cell, in the WRITER's
%                                order: spatial frequency outer, temporal
%                                frequency inner (speed_tuning.m loops sf, then
%                                tf). jTuningCurve's grid ([tuning grid]) keeps
%                                each condition's values, not the order the
%                                conditions were listed in, so a document listed
%                                in another order is reported lost.
%     tuning_curve.mean, stddev, stderr   the grid arrays in that order
%     tuning_curve.individual    trials x conditions, in that order
%     tuning_curve.control_*     value.control.*
%     significance.*             value.significance
%     fit, fit_no_speed, fit_fullspeed   the model_fit entries of model
%                                'Priebe fit', each block named by its
%                                constraints ([Priebe fits are one function],
%                                Jess Haley, 2026-10-27): none -> fit;
%                                parameter 3 (xi) held at 0 -> fit_no_speed;
%                                at 1 -> fit_fullspeed. Priebe_fit_*, sse,
%                                r_squared, partial_r2,
%                                Priebe_fit_nested_F_test_p_value.
%
%   BAD lists what is emitted but has no place in the block.

bad = {};
blk = struct();
value = getIn(leaf, 'tuning_curve', 'value');
if ~isstruct(value)
    bad{end+1} = 'the calculation has no tuning_curve.value';
    return;
end
props = struct();
if isfield(value, 'response_unit')
    props.response_units = responseUnitsBack(leaf, value);
end
if isfield(value, 'response_type')
    [~, props.response_type] = termParts(value.response_type);
end
if ~isempty(fieldnames(props))
    blk.properties = props;
end

% ---- the grid ------------------------------------------------------------------
dims = asCell(getIn(leaf, 'data', 'dimensions'));
covs = asCell(getIn(leaf, 'data', 'covariates'));
labels = cell(1, numel(dims));
levels = cell(1, numel(dims));
for k = 1:numel(dims)
    [~, labels{k}] = termParts(getIn(dims{k}, 'term'));
end
for k = 1:numel(covs)
    a = numberOf(getIn(covs{k}, 'along'));
    if ~isempty(a) && a >= 0 && a < numel(dims)
        levels{a + 1} = column(getIn(covs{k}, 'quantity', 'value'));
    end
end
if ~isequal(lower(labels), {'spatial frequency', 'temporal frequency'}) ...
        || any(cellfun(@isempty, levels))
    bad{end+1} = sprintf('the dimensions are {%s}, not spatial x temporal frequency', ...
        strjoin(labels, ', '));
    return;
end
n1 = numel(levels{1});
n2 = numel(levels{2});
% writer order: sf outer, tf inner -> condition (i, j) is at (i - 1) * n2 + j
[J, I] = meshgrid(1:n2, 1:n1);   % I(i,j) = i, J(i,j) = j
order = sub2ind([n1, n2], reshape(I.', [], 1), reshape(J.', [], 1));
tc = struct();
tc.spatial_frequency = levels{1}(reshape(I.', [], 1));
tc.temporal_frequency = levels{2}(reshape(J.', [], 1));
for f = {'mean', 'stddev', 'stderr'}
    if isfield(value, f{1})
        tc.(f{1}) = flat(value.(f{1}), order, n1 * n2);
    end
end
if isfield(value, 'individual')
    x = value.individual;
    nT = numel(x) / (n1 * n2);
    x = reshape(x, n1 * n2, nT);   % grid cells (column-major) x trials
    tc.individual = x(order, :).';  % v1: trials x conditions
end
if isfield(value, 'raw_individual')
    bad{end+1} = 'value.raw_individual has no place in the speed writer''s block';
end
if isfield(value, 'control') && isstruct(value.control)
    ctl = value.control;
    map = {'mean', 'control_mean'; 'stddev', 'control_stddev'; 'stderr', 'control_stderr'};
    for k = 1:size(map, 1)
        if isfield(ctl, map{k, 1})
            tc.(map{k, 2}) = flat(ctl.(map{k, 1}), order, n1 * n2);
        end
    end
    bad = [bad, others(ctl, map(:, 1)', 'value.control')];
end
blk.tuning_curve = tc;
if isfield(value, 'significance') && isstruct(value.significance)
    blk.significance = value.significance;
end

% ---- the fit -------------------------------------------------------------------
if isfield(value, 'model_fit')
    mf = asCell(value.model_fit);
    for k = 1:numel(mf)
        [b, why, block] = oneFit(mf{k});
        bad = [bad, why]; %#ok<AGROW>
        if isempty(block)
            continue;
        end
        if isfield(blk, block)
            bad{end+1} = sprintf('model_fit %d: a second %s', k, block); %#ok<AGROW>
        else
            blk.(block) = b;
        end
    end
end
bad = [bad, others(value, {'response_unit', 'response_type', 'mean', 'stddev', ...
    'stderr', 'individual', 'raw_individual', 'control', 'significance', 'model_fit'}, ...
    'tuning_curve.value')];
end

function y = flat(x, order, n)
% a grid array (or a pooled scalar) in the writer's condition order
if isnumeric(x) && numel(x) == n
    y = x(:);
    y = y(order);
else
    y = x;
end
end

function [b, bad, block] = oneFit(e)
bad = {};
b = struct();
block = '';
[~, model] = termParts(getIn(e, 'model'));
if ~strcmp(model, 'Priebe fit')
    bad{end+1} = sprintf('model_fit "%s" is not the Priebe fit', model);
    return;
end
held = zeros(0, 2);
c = asCell(getIn(e, 'constraints'));
for k = 1:numel(c)
    [~, name] = termParts(getIn(c{k}, 'variable'));
    t = regexp(name, '^Priebe fit parameter (\d+)$', 'tokens', 'once');
    v = getIn(c{k}, 'value');
    if isempty(t) || ~isnumeric(v) || ~isscalar(v)
        bad{end+1} = sprintf('Priebe fit constraint "%s" is not a parameter held at a value', name); %#ok<AGROW>
        return;
    end
    held(end+1, :) = [str2double(t{1}), double(v)]; %#ok<AGROW>
end
if isempty(held)
    block = 'fit';
elseif isequal(held, [3 0])
    block = 'fit_no_speed';
elseif isequal(held, [3 1])
    block = 'fit_fullspeed';
else
    bad{end+1} = 'Priebe fit constraints name none of fit, fit_no_speed, fit_fullspeed';
    return;
end
P = 'Priebe_fit_';
if isfield(e, 'coefficients') && ~isempty(e.coefficients)
    c = asCell(e.coefficients);
    b.([P 'parameters']) = cellfun(@(x) numberOf(x.value), c(:));
end
if isfield(e, 'sampled_fit') && isstruct(e.sampled_fit)
    x = e.sampled_fit.independent_values;
    if size(x, 2) == 2
        b.([P 'spatial_frequencies']) = column(x(:, 1));
        b.([P 'temporal_frequencies']) = column(x(:, 2));
    else
        bad{end+1} = 'the Priebe fit is not sampled over (spatial, temporal) frequency';
    end
    b.([P 'values']) = column(e.sampled_fit.response);
end
mmap = {'speed_tuning_index', [P 'speed_tuning_index']; ...
    'spatial_frequency_preference', [P 'spatial_frequency_preference']; ...
    'temporal_frequency_preference', [P 'temporal_frequency_preference']; ...
    'partial_r2', 'partial_r2'; 'nested_f_test_p', [P 'nested_F_test_p_value']};
if isfield(e, 'metrics') && isstruct(e.metrics)
    for k = 1:size(mmap, 1)
        if isfield(e.metrics, mmap{k, 1})
            b.(mmap{k, 2}) = e.metrics.(mmap{k, 1});
        end
    end
    bad = [bad, others(e.metrics, mmap(:, 1)', 'model_fit.metrics')];
end
if isfield(e, 'goodness') && isstruct(e.goodness)
    if isfield(e.goodness, 'sse'); b.sse = e.goodness.sse; end
    if isfield(e.goodness, 'r2'); b.r_squared = e.goodness.r2; end
    bad = [bad, others(e.goodness, {'sse', 'r2'}, 'model_fit.goodness')];
end
bad = [bad, others(e, {'model', 'coefficients', 'sampled_fit', 'metrics', 'goodness', ...
    'constraints'}, 'model_fit')];
end
