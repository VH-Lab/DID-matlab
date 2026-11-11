function [blk, bad] = csfBlock(leaf)
%CSFBLOCK The v1 contrastsensitivity_calc result fields rebuilt from the
%   converted calculation (the inverse of jContrastSensitivityValue), in the
%   writer's spelling (ndi.calc.vis.contrast_sensitivity, NDIcalc-vis-matlab):
%
%     spatial_frequencies            the covariate along the one dimension
%     response_type                  value.response_type's label
%     fitless_interpolated_c50       value.interpolated_values.half_maximum_below
%                                    or .c50 (the
%                                    structure, or in a list the entry with
%                                    no response_transform: [interpolated
%                                    values are a list], interpolatedEntry)
%     visual_response_p_bonferroni, response_varies_p_bonferroni
%                                    value.significance.*
%     is_modulated_response          value.significance.modulated_response
%                                    (0/1; v1 wrote 0 or 1)
%     parameters_<V>                 column j: the coefficients of the j-th
%                                    fit of variant V
%     sensitivity_<V>, relative_max_gain_<V>, empirical_c50_<V> (v2
%     half_maximum_below or c50),
%     saturation_index_<V>           element (or column) j: that fit's field
%   for each variant V of RB, RBN, RBNS.
%
%   ONE FIT PER SPATIAL FREQUENCY (Decided by Jess Haley, 2026-11-11,
%   did-schema docs/plans/did_v2_go_forward_class_audit.md [tuning fit
%   coefficients named by symbol]; the inverse of jContrastSensitivityValue):
%   each entry is the Naka-Rushton model (EMPTY:0000416), its variant told
%   by its constraints (n = 1 and s = 1: RB; s = 1: RBN; none: RBNS), its
%   coefficients named [Rm c50 n s] in stored order
%   (did2.convert.tuningFitModels, fitModelRow, fitRowCoefficients). The
%   j-th entry of a variant is spatial frequency j. A per-SF value that is one
%   number per fit is rebuilt as a column (as v1 JSON reads back); one that is
%   a column per fit (sensitivity, one value per contrast) as the matrix of
%   those columns.
%
%   Both spellings of the half-maximum point are read: `half_maximum_below`
%   (Decided by Jess Haley, 2026-11-10 [one spelling for the half-maximum
%   point]) and `c50`, which did-schema declares until it renames the two
%   fields and which documents migrated before then carry. One entry holding
%   both is reported, not chosen.

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
    [hm, b] = halfMaximum(iv, 'value.interpolated_values');
    bad = [bad, b];
    if ~isempty(hm); blk.fitless_interpolated_c50 = hm{1}; end
    bad = [bad, others(iv, HALF_MAXIMUM_NAMES(), 'value.interpolated_values')];
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
    map = {'sensitivity', 'sensitivity'; 'relative_max_gain', 'relative_max_gain'; ...
        'saturation_index', 'saturation_index'};
    perV = struct();   % variant -> struct of cells, one piece per fit
    for k = 1:numel(fits)
        e = fits{k};
        where = sprintf('model_fit %d', k);
        [node, model] = termParts(getIn(e, 'model'));
        row = fitModelRow(node, 'contrast', e);
        if ~(isstruct(row) && isscalar(row))
            bad{end+1} = sprintf('%s: model "%s" (%s) with these constraints is not a Naka-Rushton variant', ...
                where, model, node); %#ok<AGROW>
            continue;
        end
        V = regexprep(row.stem, '^naka_rushton_', '');
        if ~isfield(perV, V)
            perV.(V) = struct('n', 0, 'parameters', {{}}, 'sensitivity', {{}}, ...
                'relative_max_gain', {{}}, 'saturation_index', {{}}, 'empirical_c50', {{}});
        end
        acc = perV.(V);
        acc.n = acc.n + 1;
        j = acc.n;
        if isfield(e, 'coefficients') && ~isempty(e.coefficients)
            [p, b] = fitRowCoefficients(e, row, where);
            bad = [bad, b]; %#ok<AGROW>
            acc.parameters{j} = p;
        end
        for m = 1:size(map, 1)
            if isfield(e, map{m, 1})
                acc.(map{m, 2}){j} = nanIfEmpty(e.(map{m, 1}));
            end
        end
        [hm, b] = halfMaximum(e, where);
        bad = [bad, b]; %#ok<AGROW>
        if ~isempty(hm); acc.empirical_c50{j} = nanIfEmpty(hm{1}); end
        bad = [bad, others(e, [{'model', 'equation', 'coefficients', 'constraints'}, ...
            map(:, 1)', HALF_MAXIMUM_NAMES()], where)]; %#ok<AGROW>
        perV.(V) = acc;
    end
    vs = fieldnames(perV);
    for i = 1:numel(vs)
        V = vs{i};
        acc = perV.(V);
        for f = {'parameters', 'sensitivity', 'relative_max_gain', 'saturation_index', 'empirical_c50'}
            [x, b] = joinPieces(acc.(f{1}), acc.n, sprintf('%s_%s', f{1}, V));
            bad = [bad, b]; %#ok<AGROW>
            if ~isempty(x) || ~isempty(b)
                blk.([f{1} '_' V]) = x;
            end
        end
    end
end
bad = [bad, others(value, {'response_type', 'interpolated_values', 'significance', ...
    'model_fit'}, 'contrast_sensitivity.value')];
end

function s = HALF_MAXIMUM_NAMES()
% the two spellings of the half-maximum point, new first ([one spelling for
% the half-maximum point], Jess Haley, 2026-11-10)
s = {'half_maximum_below', 'c50'};
end

function [hm, bad] = halfMaximum(st, where)
% {value} of the one half-maximum field ST holds, or {} when it holds none;
% both spellings present is reported, and the new one is read
hm = {};
bad = {};
names = HALF_MAXIMUM_NAMES();
present = names(isfield(st, names));
if isempty(present)
    return;
end
if numel(present) > 1
    bad{end+1} = sprintf('%s holds both half_maximum_below and c50', where);
end
hm = {st.(present{1})};
end

function [x, bad] = joinPieces(pieces, n, name)
% the v1 array of one variant field from its N fits' pieces: [] when no fit
% holds it; a column when every piece is one number; else the matrix whose
% column j is fit j's piece. A field some fits hold and others do not, or
% columns of different lengths, is reported.
x = [];
bad = {};
if isempty(pieces) || all(cellfun(@isempty, pieces))
    return;
end
if numel(pieces) < n
    pieces{n} = [];
end
if any(cellfun(@isempty, pieces))
    bad{end+1} = sprintf('%s: held by %d of the variant''s %d fits', name, ...
        sum(~cellfun(@isempty, pieces)), n);
    return;
end
lens = cellfun(@numel, pieces);
if all(lens == 1)
    x = reshape(cellfun(@(p) double(p), pieces), [], 1);
elseif all(lens == lens(1))
    x = cell2mat(cellfun(@(p) reshape(double(p), [], 1), pieces, 'UniformOutput', false));
else
    bad{end+1} = sprintf('%s: its fits'' columns differ in length', name);
end
end

function x = nanIfEmpty(x)
% a per-SF value a fit holds but that reads back empty (a NaN written as JSON
% null) is NaN, so it keeps its place
if isempty(x)
    x = NaN;
end
end
