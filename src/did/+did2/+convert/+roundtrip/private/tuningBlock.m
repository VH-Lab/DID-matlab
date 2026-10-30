function [blk, bad, absFitless, absFits] = tuningBlock(leaf, family)
%TUNINGBLOCK A v1 tuning result block rebuilt from the converted calculation
%   (the inverse of +migrators_j/private/jTuningCurve for one stimulus
%   variable).
%
%   [BLK, BAD] = tuningBlock(LEAF, FAMILY). FAMILY is 'oridir' (block
%   orientation_direction_tuning), 'contrast' (contrast_tuning), 'sf'
%   (spatial_frequency_tuning) or 'tf' (temporal_frequency_tuning). Field
%   names are the WRITERS' spellings (NDIcalc-vis-matlab ndi.calc.vis.*; the
%   writer wins over the template): `Hotelling2Test`, `L50` / `Pref` / `H50` /
%   `R2`. BAD lists what is emitted but has no place in the block.
%
%     properties.response_units   responseUnitsBack: the registered term's
%                                 name for a spelling jTuningCurve recognised
%                                 (compared through its registry `synonyms`,
%                                 [spelling is notation]), else the unit's label
%     properties.response_type    value.response_type (its label)
%     properties.coordinates      value.coordinates
%     tuning_curve.<variable>     the covariate along the one dimension: its
%                                 term's label, lower case, ' ' as '_'
%                                 ('Direction' -> direction, 'Spatial
%                                 Frequency' -> spatial_frequency)
%     tuning_curve.mean, stddev, stderr, individual, raw_individual
%                                 value.*; the per-trial arrays back to trials
%                                 x stimuli (v1's order)
%     tuning_curve.control_mean, control_stddev, control_stderr,
%       control_individual        value.control.*
%     tuning_curve.control_mean_stddev, control_mean_stderr
%                                 value.control.pooled.*
%     significance.*              value.significance
%     vector.* (oridir)           the calculation's circular_statistics
%     fitless.* (contrast, sf, tf) the calculation's interpolated_values: the
%                                 structure, or in a list the entry with no
%                                 response_transform ([interpolated values
%                                 are a list], Jess Haley, 2026-10-30;
%                                 interpolatedEntry reads both shapes)
%   ABSFITLESS is the list's 'absolute value' entry in v1's `fitless`
%   spelling (v1 `abs.fitless`, SF / TF), struct() when there is none.
%     fit / fit_<model>           value.model_fit (fitBlocks): the entries
%                                 with no response_transform
%   ABSFITS is v1 `abs.fit_<model>` (SF / TF), struct() when there is none:
%   the model_fit entries whose response_transform is 'absolute value'
%   ([absolute-value fits are fit entries], Decided by Jess Haley,
%   2026-10-28), rebuilt by fitBlocks.

bad = {};
blk = struct();
absFitless = struct();
absFits = struct();
value = getIn(leaf, 'tuning_curve', 'value');
if ~isstruct(value)
    bad{end+1} = 'the calculation has no tuning_curve.value';
    return;
end
seen = {};

props = struct();
if isfield(value, 'response_unit')
    props.response_units = responseUnitsBack(leaf, value);
end
if isfield(value, 'response_type')
    [~, props.response_type] = termParts(value.response_type);
end
if isfield(value, 'coordinates')
    props.coordinates = char(value.coordinates);
end
seen = [seen, {'response_unit', 'response_type', 'coordinates'}];
if ~isempty(fieldnames(props))
    blk.properties = props;
end

tc = struct();
[axisName, axisValues, axisBad] = oneAxis(leaf);
bad = [bad, axisBad];
if ~isempty(axisName)
    tc.(axisName) = axisValues;
end
tc = put(tc, 'mean', value, {'mean'}, false);
tc = put(tc, 'stddev', value, {'stddev'}, false);
tc = put(tc, 'stderr', value, {'stderr'}, false);
tc = put(tc, 'individual', value, {'individual'}, true);
tc = put(tc, 'raw_individual', value, {'raw_individual'}, true);
seen = [seen, {'mean', 'stddev', 'stderr', 'individual', 'raw_individual'}];
if isfield(value, 'control')
    ctl = value.control;
    tc = put(tc, 'control_mean', ctl, {'mean'}, false);
    tc = put(tc, 'control_stddev', ctl, {'stddev'}, false);
    tc = put(tc, 'control_stderr', ctl, {'stderr'}, false);
    tc = put(tc, 'control_individual', ctl, {'individual'}, true);
    tc = put(tc, 'control_mean_stddev', ctl, {'pooled', 'stddev'}, false);
    tc = put(tc, 'control_mean_stderr', ctl, {'pooled', 'stderr'}, false);
    bad = [bad, others(ctl, {'mean', 'stddev', 'stderr', 'individual', 'pooled'}, 'value.control')];
    seen{end+1} = 'control';
end
if ~isempty(fieldnames(tc))
    blk.tuning_curve = tc;
end

if isfield(value, 'significance') && isstruct(value.significance)
    blk.significance = value.significance;
    seen{end+1} = 'significance';
end

own = calcBlock(leaf);
if strcmp(family, 'oridir')
    map = {'circular_variance', 'circular_variance'; ...
        'direction_circular_variance', 'direction_circular_variance'; ...
        'hotelling_t2_p', 'Hotelling2Test'; ...
        'direction_hotelling_t2_p', 'direction_hotelling2test'; ...
        'direction_dot_product_p', 'dot_direction_significance'; ...
        'orientation_preference', 'orientation_preference'; ...
        'direction_preference', 'direction_preference'};
    [vec, b] = renamed(getIn(own, 'circular_statistics'), map, 'circular_statistics');
    bad = [bad, b];
    if ~isempty(fieldnames(vec)); blk.vector = vec; end
else
    if strcmp(family, 'contrast')
        map = {'half_maximum_below', 'interpolated_c50'};
    else
        map = {'preferred_value', 'Pref'; 'half_maximum_below', 'L50'; ...
            'half_maximum_above', 'H50'; 'bandwidth', 'bandwidth'; ...
            'low_pass_index', 'low_pass_index'; 'high_pass_index', 'high_pass_index'};
    end
    iv = getIn(own, 'interpolated_values');
    [main, b] = interpolatedEntry(iv, '', 'interpolated_values');
    bad = [bad, b];
    [fl, b] = renamed(main, map, 'interpolated_values');
    bad = [bad, b];
    if ~isempty(fieldnames(fl)); blk.fitless = fl; end
    [absEntry, b] = interpolatedEntry(iv, 'absolute value', 'interpolated_values');
    bad = [bad, b];
    if ~isempty(fieldnames(absEntry))
        if any(strcmp(family, {'sf', 'tf'}))
            [absFitless, b] = renamed(absEntry, map, 'interpolated_values(absolute value)');
            bad = [bad, b];
        else
            bad{end+1} = sprintf(['an absolute-value interpolated_values entry ' ...
                'has no place in a %s block'], family);
        end
    end
end

if isfield(value, 'model_fit')
    [asStated, absEntries, b] = fitsByTransform(value.model_fit, family);
    bad = [bad, b];
    [fits, b] = fitBlocks(asStated, family);
    bad = [bad, b];
    names = fieldnames(fits);
    for k = 1:numel(names)
        blk.(names{k}) = fits.(names{k});
    end
    if ~isempty(absEntries)
        % [absolute-value fits are fit entries] (Decided by Jess Haley,
        % 2026-10-28): v1 `abs.fit_<model>`
        [absFits, b] = fitBlocks(absEntries, family);
        bad = [bad, cellfun(@(x) ['abs: ' x], b, 'UniformOutput', false)];
    end
    seen{end+1} = 'model_fit';
end
bad = [bad, others(value, seen, 'tuning_curve.value')];
end

% =============================================================================

function [asStated, absEntries, bad] = fitsByTransform(modelFit, family)
%FITSBYTRANSFORM The model_fit entries fit to the responses as stated
%   (ASSTATED: no, or an empty, response_transform) and to |response|
%   (ABSENTRIES: response_transform 'absolute value'; SF / TF only, v1 `abs`),
%   each as a cell of structs without the `response_transform` field, so
%   fitBlocks sees the fields it knows. BAD names an entry with any other
%   transform, or an absolute-value entry in a family whose v1 block has no
%   `abs`.
asStated = {};
absEntries = {};
bad = {};
c = asCell(modelFit);
for k = 1:numel(c)
    e = c{k};
    t = '';
    if isstruct(e) && isscalar(e) && isfield(e, 'response_transform')
        if ~isempty(e.response_transform)
            t = strtrim(char(e.response_transform));
        end
        e = rmfield(e, 'response_transform');
    end
    switch t
        case ''
            asStated{end+1} = e; %#ok<AGROW>
        case 'absolute value'
            if any(strcmp(family, {'sf', 'tf'}))
                absEntries{end+1} = e; %#ok<AGROW>
            else
                bad{end+1} = sprintf(['model_fit %d: an absolute-value fit has no ' ...
                    'place in a %s block'], k, family); %#ok<AGROW>
            end
        otherwise
            bad{end+1} = sprintf('model_fit %d: response_transform "%s" has no place in v1', ...
                k, t); %#ok<AGROW>
    end
end
end

function own = calcBlock(leaf)
% the named calculation's own block (circular_statistics / interpolated_values)
own = struct();
fns = fieldnames(leaf);
for k = 1:numel(fns)
    b = leaf.(fns{k});
    if isstruct(b) && isscalar(b) && (isfield(b, 'circular_statistics') ...
            || isfield(b, 'interpolated_values'))
        own = b;
        return;
    end
end
end

function [name, values, bad] = oneAxis(leaf)
% the one stimulus dimension: its covariate's label and values
name = '';
values = [];
bad = {};
covs = getIn(leaf, 'data', 'covariates');
dims = getIn(leaf, 'data', 'dimensions');
if isempty(covs)
    return;
end
if iscell(covs); covs = [covs{:}]; end
if iscell(dims); dims = [dims{:}]; end
if numel(covs) ~= 1 || numel(dims) > 1
    bad{end+1} = sprintf('%d dimensions and %d covariates: only one stimulus variable is rebuilt', ...
        numel(dims), numel(covs));
    return;
end
[~, label] = termParts(covs.variable);
name = lower(strrep(strtrim(label), ' ', '_'));
values = column(getIn(covs, 'quantity', 'value'));
if isempty(name) || ~isvarname(name)
    bad{end+1} = sprintf('the stimulus variable "%s" is not a v1 field name', label);
    name = '';
end
end

function s = put(s, name, src, steps, trialsFirst)
% S.(NAME) = SRC.(STEPS...) in v1's orientation, when SRC holds it
x = src;
for k = 1:numel(steps)
    if ~(isstruct(x) && isscalar(x) && isfield(x, steps{k}))
        return;
    end
    x = x.(steps{k});
end
if trialsFirst
    s.(name) = trialsFirstOrient(x);
else
    s.(name) = column(x);
end
end

function [out, bad] = renamed(s, map, where)
% OUT.(v1 name) = S.(V2 name) for each row of MAP; the rest of S is BAD
out = struct();
bad = {};
if ~isstruct(s) || isempty(fieldnames(s))
    return;
end
for k = 1:size(map, 1)
    if isfield(s, map{k, 1})
        out.(map{k, 2}) = s.(map{k, 1});
    end
end
bad = others(s, map(:, 1)', where);
end
