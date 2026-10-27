function [blocks, bad] = fitBlocks(modelFit, family)
%FITBLOCKS The v1 fit block(s) rebuilt from a tuning curve's model_fit list
%   (the inverse of jTuningCurve's fitEntries / oneFit).
%
%   [BLOCKS, BAD] = fitBlocks(MODELFIT, FAMILY). BLOCKS is a struct of v1
%   blocks by name. Each entry's model label (spaces as '_') is the v1 field
%   prefix or block name, in the writers' layouts (NDIcalc-vis-matlab):
%
%     oridir    block `fit`; <model>_parameters, <model>_fit_angles (x),
%               <model>_fit_values (y); metrics unprefixed: hwhh,
%               orientation_angle_preference, direction_angle_preference,
%               orientation_preferred_orthogonal_ratio(_rectified),
%               direction_preferred_null_ratio(_rectified)
%     contrast  block `fit`; naka_rushton_<V>_parameters, _contrast (x),
%               _values (y), _pref, _empirical_c50, _r2
%     sf, tf    block `fit_<model>`; parameters, values (x), fit (y), Pref,
%               L50, H50, R2, bandwidth
%
%   Coefficients are read back in order as a column (v1 stored an unnamed
%   vector; jTuningCurve named entry k '<model> parameter k'). BAD lists what
%   an entry holds that has no place in these layouts.

blocks = struct();
bad = {};
if isempty(modelFit)
    return;
end
if isstruct(modelFit)
    modelFit = num2cell(reshape(modelFit, 1, []));
end
for k = 1:numel(modelFit)
    e = modelFit{k};
    [~, model] = termParts(getIn(e, 'model'));
    stem = strrep(strtrim(model), ' ', '_');
    if isempty(stem) || ~isvarname(['x' stem])
        bad{end+1} = sprintf('model_fit %d: model "%s" names no v1 fit', k, model); %#ok<AGROW>
        continue;
    end
    switch family
        case 'oridir'
            block = 'fit'; P = [stem '_']; M = '';
            names = {'parameters', [P 'parameters']; 'x', [P 'fit_angles']; 'y', [P 'fit_values']; ...
                'r2', 'r2'};
            metrics = {'half_width_at_half_maximum', 'hwhh'; ...
                'orientation_preference', 'orientation_angle_preference'; ...
                'direction_preference', 'direction_angle_preference'; ...
                'orientation_preferred_orthogonal_ratio', 'orientation_preferred_orthogonal_ratio'; ...
                'orientation_preferred_orthogonal_ratio_rectified', 'orientation_preferred_orthogonal_ratio_rectified'; ...
                'direction_preferred_null_ratio', 'direction_preferred_null_ratio'; ...
                'direction_preferred_null_ratio_rectified', 'direction_preferred_null_ratio_rectified'};
        case 'contrast'
            block = 'fit'; P = [stem '_']; M = P;
            names = {'parameters', [P 'parameters']; 'x', [P 'contrast']; 'y', [P 'values']; ...
                'r2', [P 'r2']};
            metrics = {'preferred_value', 'pref'; 'half_maximum_below', 'empirical_c50'};
        otherwise   % 'sf', 'tf'
            block = ['fit_' stem]; M = '';
            names = {'parameters', 'parameters'; 'x', 'values'; 'y', 'fit'; 'r2', 'R2'};
            metrics = {'preferred_value', 'Pref'; 'half_maximum_below', 'L50'; ...
                'half_maximum_above', 'H50'; 'bandwidth', 'bandwidth'};
    end
    where = sprintf('model_fit %d (%s)', k, model);
    b = struct();
    if isfield(blocks, block)
        b = blocks.(block);
    end
    if isfield(e, 'coefficients') && ~isempty(e.coefficients)
        c = e.coefficients;
        if iscell(c); c = [c{:}]; end
        b.(names{1, 2}) = reshape([c.value], [], 1);
    end
    if isfield(e, 'goodness') && isstruct(e.goodness)
        if isfield(e.goodness, 'r2')
            b.(names{4, 2}) = e.goodness.r2;
        end
        bad = [bad, others(e.goodness, {'r2'}, [where '.goodness'])]; %#ok<AGROW>
    end
    if isfield(e, 'sampled_fit') && isstruct(e.sampled_fit)
        sf = e.sampled_fit;
        if isfield(sf, 'independent_values')
            x = sf.independent_values;
            if size(x, 2) == 1 || isvector(x)
                b.(names{2, 2}) = column(x);
            else
                bad{end+1} = [where '.sampled_fit.independent_values (more than one column)']; %#ok<AGROW>
            end
        end
        if isfield(sf, 'response')
            b.(names{3, 2}) = column(sf.response);
        end
        bad = [bad, others(sf, {'independent_values', 'response'}, [where '.sampled_fit'])]; %#ok<AGROW>
    end
    if isfield(e, 'metrics') && isstruct(e.metrics)
        for j = 1:size(metrics, 1)
            if isfield(e.metrics, metrics{j, 1})
                b.([M metrics{j, 2}]) = e.metrics.(metrics{j, 1});
            end
        end
        bad = [bad, others(e.metrics, metrics(:, 1)', [where '.metrics'])]; %#ok<AGROW>
    end
    bad = [bad, others(e, {'model', 'coefficients', 'goodness', 'sampled_fit', 'metrics'}, where)]; %#ok<AGROW>
    blocks.(block) = b;
end
end
