function [blk, bad] = csfBlock(leaf)
%CSFBLOCK The v1 contrastsensitivity_calc result fields rebuilt from the
%   converted calculation (the inverse of jContrastSensitivityValue), in the
%   writer's spelling (ndi.calc.vis.contrast_sensitivity, NDIcalc-vis-matlab):
%
%     spatial_frequencies            the covariate along the one dimension
%     response_type                  value.response_type's label
%     fitless_interpolated_c50       value.interpolated_values.c50 (the
%                                    structure, or in a list the entry with
%                                    no response_transform: [interpolated
%                                    values are a list], interpolatedEntry)
%     visual_response_p_bonferroni, response_varies_p_bonferroni
%                                    value.significance.*
%     is_modulated_response          value.significance.modulated_response
%                                    (0/1; v1 wrote 0 or 1)
%     parameters_<V>                 the 'naka rushton <V>' fit's coefficients,
%                                    'parameter k, spatial frequency j' at (k, j)
%     sensitivity_<V>, relative_max_gain_<V>, empirical_c50_<V> (V2 c50),
%     saturation_index_<V>           that fit's fields, as stored
%   for each variant V of RB, RBN, RBNS.

bad = {};
blk = struct();
value = getIn(leaf, 'contrast_sensitivity', 'value');
if ~isstruct(value)
    bad{end+1} = 'the calculation has no contrast_sensitivity.value';
    return;
end
covs = getIn(leaf, 'data', 'covariates');
if iscell(covs); covs = [covs{:}]; end
if isscalar(covs)
    blk.spatial_frequencies = column(getIn(covs, 'quantity', 'value'));
elseif numel(covs) > 1
    bad{end+1} = sprintf('%d covariates: one spatial frequency axis is rebuilt', numel(covs));
end
if isfield(value, 'response_type')
    [~, blk.response_type] = termParts(value.response_type);
end
if isfield(value, 'interpolated_values') && ~isempty(value.interpolated_values)
    [iv, b] = interpolatedEntry(value.interpolated_values, '', 'value.interpolated_values');
    bad = [bad, b];
    if isfield(iv, 'c50'); blk.fitless_interpolated_c50 = iv.c50; end
    bad = [bad, others(iv, {'c50'}, 'value.interpolated_values')];
    [ab, ~] = interpolatedEntry(value.interpolated_values, 'absolute value', ...
        'value.interpolated_values');
    if ~isempty(fieldnames(ab))
        bad{end+1} = ['an absolute-value interpolated_values entry has no place ' ...
            'in a contrastsensitivity_calc'];
    end
end
if isfield(value, 'significance') && isstruct(value.significance)
    sig = value.significance;
    for f = {'visual_response_p_bonferroni', 'response_varies_p_bonferroni'}
        if isfield(sig, f{1}); blk.(f{1}) = sig.(f{1}); end
    end
    if isfield(sig, 'modulated_response')
        blk.is_modulated_response = double(sig.modulated_response);
    end
    bad = [bad, others(sig, {'visual_response_p_bonferroni', ...
        'response_varies_p_bonferroni', 'modulated_response'}, 'value.significance')];
end
if isfield(value, 'model_fit') && ~isempty(value.model_fit)
    fits = value.model_fit;
    if isstruct(fits); fits = num2cell(reshape(fits, 1, [])); end
    for k = 1:numel(fits)
        e = fits{k};
        [~, model] = termParts(getIn(e, 'model'));
        tok = regexp(model, '^naka rushton (RB|RBN|RBNS)$', 'tokens', 'once', 'ignorecase');
        if isempty(tok)
            bad{end+1} = sprintf('model_fit %d: model "%s" is not a Naka-Rushton variant', k, model); %#ok<AGROW>
            continue;
        end
        V = upper(tok{1});
        if isfield(e, 'coefficients') && ~isempty(e.coefficients)
            [blk.(['parameters_' V]), b] = coefficientMatrix(e.coefficients, model);
            bad = [bad, b]; %#ok<AGROW>
        end
        map = {'sensitivity', 'sensitivity'; 'relative_max_gain', 'relative_max_gain'; ...
            'c50', 'empirical_c50'; 'saturation_index', 'saturation_index'};
        for j = 1:size(map, 1)
            if isfield(e, map{j, 1})
                blk.([map{j, 2} '_' V]) = e.(map{j, 1});
            end
        end
        bad = [bad, others(e, [{'model', 'coefficients'}, map(:, 1)'], ...
            sprintf('model_fit %d', k))]; %#ok<AGROW>
    end
end
bad = [bad, others(value, {'response_type', 'interpolated_values', 'significance', ...
    'model_fit'}, 'contrast_sensitivity.value')];
end

function [m, bad] = coefficientMatrix(c, model)
% '<model> parameter k, spatial frequency j' -> M(k, j)
m = [];
bad = {};
if iscell(c); c = [c{:}]; end
for i = 1:numel(c)
    [~, name] = termParts(c(i).variable);
    tok = regexp(name, 'parameter (\d+), spatial frequency (\d+)$', 'tokens', 'once');
    if isempty(tok) || ~startsWith(name, model)
        bad{end+1} = sprintf('coefficient "%s" is not "%s parameter k, spatial frequency j"', ...
            name, model); %#ok<AGROW>
        continue;
    end
    m(str2double(tok{1}), str2double(tok{2})) = c(i).value; %#ok<AGROW>
end
end
