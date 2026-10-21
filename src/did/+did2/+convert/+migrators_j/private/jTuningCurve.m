function [value, keys, leafFields, dropped] = jTuningCurve(srcBlk, family)
%JTUNINGCURVE A v1 tuning-curve result block as did-schema #88's
%   `tuning_curve` value, its `keys`, and the named calculation's own blocks.
%
%   [VALUE, KEYS, LEAFFIELDS, DROPPED] = jTuningCurve(SRCBLK, FAMILY)
%
%   SRCBLK is the v1 result block (`orientation_direction_tuning`,
%   `contrast_tuning`, `spatial_frequency_tuning`, `temporal_frequency_tuning`,
%   `speed_tuning`) or `stimulus_tuningcurve` (FAMILY 'stimulus'). The mapping
%   is the signed tuning model (did-schema V_eta_tuning_model_plan.md:
%   2026-09-21 restructure, the #73 amendment of 2026-09-23 and the audit-2
%   amendment signed 2026-09-29):
%
%     VALUE (`tuning_curve.value`)   mean, stddev, stderr, individual,
%       raw_individual, control {mean, stddev, stderr, individual},
%       response_unit (a term), response_type (a bound term), coordinates.
%       Per-trial arrays take the stimulus dimension FIRST and the trial
%       dimension last (audit 2, D3: "individual / raw_individual add one
%       trailing trial dimension"); v1 stored them trials x stimuli.
%     KEYS   the stimulus dimensions (audit 2, D3: `independent_variables[]`
%       is dropped, the dimensions are the value's keys). One independent
%       variable: one key, its positions the values. SEVERAL (a tuningcurve
%       over spatial x temporal frequency, a speed tuning): the curve is
%       sampled at n points of a d-dimensional space, which is ONE array
%       dimension of length n, so ONE key whose variable names the d
%       variables and whose positions are n LABELS, each naming its point
%       ('spatial frequency 0.05, temporal frequency 1') -- a CONSERVATIVE
%       CHOICE recorded with the port: the schema has no multi-variable key
%       and `quantity.value` must hold exactly n numbers, so labels are the
%       one form that keeps every position.
%     LEAFFIELDS   the named calculation's blocks: `significance` and
%       `model_fit[]` (tuning_curve_calculation); `circular_statistics`
%       (orientation/direction, v1 `vector`); `interpolated_values`
%       (contrast, SF, TF, v1 `fitless`). Field names per the #73 naming pass.
%     DROPPED   cellstr naming every v1 field this mapping has no home for
%       (reported by the port, never silently): e.g. contrast fits'
%       relative_max_gain / saturation_index / sensitivity, SF/TF's `abs`
%       block, stimulus_tuningcurve's stimid / presentation numbers / imaginary
%       parts.
%
%   Fit coefficients are a vector in v1 with no names; each becomes a
%   `{variable, value}` entry named '<model> parameter k' (a label) -- a
%   CONSERVATIVE CHOICE, recorded.

arguments
    srcBlk
    family (1,:) char
end

value = struct();
keys = [];
leafFields = struct();
dropped = {};
if ~isstruct(srcBlk) || ~isscalar(srcBlk)
    return;
end

if strcmp(family, 'stimulus')
    [value, keys, dropped] = rawCurve(srcBlk);
    return;
end

% ---- properties -----------------------------------------------------------
props = sub(srcBlk, 'properties');
value = putUnit(value, getf(props, {'response_units', 'responseUnits'}));
rt = getf(props, {'response_type', 'responseType'});
if ischar(rt) && ~isempty(rt); value.response_type = did2.build.label(rt); end
co = getf(props, {'coordinates'});
if ischar(co) && ~isempty(co); value.coordinates = co; end

% ---- the curve ------------------------------------------------------------
tc = sub(srcBlk, 'tuning_curve');
axesNames = {'direction', 'angle', 'contrast', 'spatial_frequency', ...
    'temporal_frequency', 'speed'};
present = {};
cols = {};
for k = 1:numel(axesNames)
    v = getf(tc, axesNames(k));
    if isnumeric(v) && ~isempty(v)
        present{end+1} = axesNames{k}; %#ok<AGROW>
        cols{end+1} = double(v(:)); %#ok<AGROW>
    end
end
keys = makeKeys(present, cols);
used = [present, {'mean', 'stddev', 'stderr', 'individual', 'raw_individual', ...
    'control_mean', 'control_stddev', 'control_stderr', 'control_individual'}];
value = putArr(value, 'mean', getf(tc, {'mean'}), false);
value = putArr(value, 'stddev', getf(tc, {'stddev'}), false);
value = putArr(value, 'stderr', getf(tc, {'stderr'}), false);
value = putArr(value, 'individual', getf(tc, {'individual'}), true);
value = putArr(value, 'raw_individual', getf(tc, {'raw_individual'}), true);
ctl = struct();
ctl = putArr(ctl, 'mean', getf(tc, {'control_mean'}), false);
ctl = putArr(ctl, 'stddev', getf(tc, {'control_stddev'}), false);
ctl = putArr(ctl, 'stderr', getf(tc, {'control_stderr'}), false);
ctl = putArr(ctl, 'individual', getf(tc, {'control_individual'}), true);
if ~isempty(fieldnames(ctl)); value.control = ctl; end
dropped = [dropped, prefixed('tuning_curve.', setdiff(fieldnames(tc), used))];

% ---- significance (tuning_curve_calculation) -----------------------------
sig = sub(srcBlk, 'significance');
s = struct();
for f = {'visual_response_anova_p', 'across_stimuli_anova_p'}
    x = getf(sig, f);
    if isnumeric(x) && isscalar(x); s.(f{1}) = double(x); end
end
if ~isempty(fieldnames(s)); leafFields.significance = s; end

% ---- circular statistics (orientation / direction: v1 `vector`) -----------
vec = sub(srcBlk, 'vector');
if ~isempty(fieldnames(vec))
    map = {'circular_variance', {'circular_variance'}; ...
        'direction_circular_variance', {'direction_circular_variance'}; ...
        'hotelling_t2_p', {'hotelling2test', 'Hotelling2Test'}; ...
        'direction_hotelling_t2_p', {'direction_hotelling2test', 'direction_Hotelling2Test'}; ...
        'direction_dot_product_p', {'dot_direction_significance'}; ...
        'orientation_preference', {'orientation_preference'}; ...
        'direction_preference', {'direction_preference'}};
    [cs, usedV] = scalarMap(vec, map);
    if ~isempty(fieldnames(cs)); leafFields.circular_statistics = cs; end
    dropped = [dropped, prefixed('vector.', setdiff(fieldnames(vec), usedV))];
end

% ---- interpolated values (contrast / SF / TF: v1 `fitless`) ---------------
fl = sub(srcBlk, 'fitless');
if ~isempty(fieldnames(fl))
    map = {'half_maximum_below', {'L50', 'l50', 'interpolated_c50'}; ...
        'preferred_value', {'Pref', 'pref'}; ...
        'half_maximum_above', {'H50', 'h50'}; ...
        'bandwidth', {'bandwidth'}; ...
        'low_pass_index', {'low_pass_index'}; ...
        'high_pass_index', {'high_pass_index'}};
    if strcmp(family, 'contrast')
        map = map(1, :);   % contrast declares only the lower half-max point
    end
    [iv, usedF] = scalarMap(fl, map);
    if ~isempty(fieldnames(iv)); leafFields.interpolated_values = iv; end
    dropped = [dropped, prefixed('fitless.', setdiff(fieldnames(fl), usedF))];
end

% ---- model fits -------------------------------------------------------------
fits = {};
names = fieldnames(srcBlk);
for k = 1:numel(names)
    nm = names{k};
    if ~(strcmp(nm, 'fit') || startsWith(nm, 'fit_')) || ~isstruct(srcBlk.(nm))
        continue;
    end
    [entries, d] = fitEntries(srcBlk.(nm), nm);
    fits = [fits, entries]; %#ok<AGROW>
    dropped = [dropped, d]; %#ok<AGROW>
end
if ~isempty(fits)
    leafFields.model_fit = did2.build.list(fits{:});
end

known = [{'properties', 'tuning_curve', 'significance', 'vector', 'fitless'}, ...
    names(strcmp(names, 'fit') | startsWith(names, 'fit_'))'];
rest = setdiff(names, known);
dropped = [dropped, reshape(rest, 1, [])];
end

% =============================================================================

function [value, keys, dropped] = rawCurve(st)
% v1 `stimulus_tuningcurve` (tuningcurve_calc, and the raw pre-calculator curve)
value = struct();
labels = getf(st, {'independent_variable_label'});
if ischar(labels); labels = {labels}; end
if isstring(labels); labels = cellstr(labels); end
if ~iscell(labels); labels = {}; end
iv = double(getf(st, {'independent_variable_value'}));
if isvector(iv); iv = iv(:); end
cols = {};
for d = 1:size(iv, 2)
    cols{end+1} = iv(:, d); %#ok<AGROW>
end
names = labels;
if numel(names) < numel(cols)
    % one label naming several columns ('spatial_frequency, temporal_frequency')
    if isscalar(names) && contains(names{1}, ',')
        names = strtrim(strsplit(names{1}, ','));
    end
    for d = numel(names) + 1:numel(cols)
        names{d} = sprintf('independent variable %d', d);
    end
end
keys = makeKeys(names(1:numel(cols)), cols);
value = putArr(value, 'mean', getf(st, {'response_mean'}), false);
value = putArr(value, 'stddev', getf(st, {'response_stddev'}), false);
value = putArr(value, 'stderr', getf(st, {'response_stderr'}), false);
value = putArr(value, 'individual', getf(st, {'individual_responses_real', 'individual_responses'}), true);
ctl = struct();
ctl = putArr(ctl, 'mean', getf(st, {'control_response_mean'}), false);
ctl = putArr(ctl, 'stddev', getf(st, {'control_response_stddev'}), false);
ctl = putArr(ctl, 'stderr', getf(st, {'control_response_stderr'}), false);
ctl = putArr(ctl, 'individual', getf(st, {'control_individual_responses_real'}), true);
if ~isempty(fieldnames(ctl)); value.control = ctl; end
value = putUnit(value, getf(st, {'response_units'}));
used = {'independent_variable_label', 'independent_variable_value', 'response_mean', ...
    'response_stddev', 'response_stderr', 'individual_responses_real', ...
    'individual_responses', 'control_response_mean', 'control_response_stddev', ...
    'control_response_stderr', 'control_individual_responses_real', 'response_units'};
rest = setdiff(fieldnames(st), used);
% an imaginary part that is all zero carries nothing; a non-zero one has no home
keep = true(size(rest));
for k = 1:numel(rest)
    x = st.(rest{k});
    if contains(rest{k}, 'imaginary') && isnumeric(x) && all(x(:) == 0 | isnan(x(:)))
        keep(k) = false;
    end
end
dropped = prefixed('stimulus_tuningcurve.', rest(keep));
end

function keys = makeKeys(names, cols)
keys = [];
if isempty(cols)
    return;
end
if isscalar(cols)
    v = cols{1};
    keys = did2.build.key(did2.build.label(strrep(names{1}, '_', ' ')), numel(v), 'Values', v');
    return;
end
n = numel(cols{1});
if any(cellfun(@numel, cols) ~= n)
    return;   % ragged: no honest key; the values stay, unkeyed
end
M = [cols{:}];
label = strjoin(strrep(names, '_', ' '), ' x ');
pos = cell(1, n);
for i = 1:n
    parts = cell(1, numel(cols));
    for d = 1:numel(cols)
        parts{d} = sprintf('%s %.17g', strrep(names{d}, '_', ' '), M(i, d));
    end
    pos{i} = strjoin(parts, ', ');
end
keys = did2.build.key(did2.build.label(label), n, 'Labels', pos);
end

function [entries, dropped] = fitEntries(blk, blockName)
% one v1 fit block -> one or more model_fit entries
entries = {};
dropped = {};
fn = fieldnames(blk);
% groups: prefixes P such that P_parameters (any case) is a field
prefixes = {};
for k = 1:numel(fn)
    t = regexp(fn{k}, '^(.*_)?parameters$', 'tokens', 'once', 'ignorecase');
    if ~isempty(t)
        prefixes{end+1} = t{1}; %#ok<AGROW>
    end
end
if isempty(prefixes)
    prefixes = {''};
end
claimed = false(size(fn));
for g = 1:numel(prefixes)
    P = prefixes{g};
    mine = false(size(fn));
    for k = 1:numel(fn)
        if ~isempty(P)
            mine(k) = startsWith(fn{k}, P);
        end
    end
    if isscalar(prefixes)
        mine = true(size(fn));   % the only group owns the unprefixed fields too
    end
    claimed = claimed | mine;
    grp = struct();
    for k = find(mine)'
        nm = fn{k};
        if ~isempty(P) && startsWith(nm, P)
            nm = nm(numel(P) + 1:end);
        end
        grp.(lower(nm)) = blk.(fn{k});
    end
    model = strtrim(regexprep(P, '_+$', ''));
    if isempty(model)
        model = blockName;
        if startsWith(model, 'fit_'); model = model(5:end); end
    end
    [e, d] = oneFit(grp, model);
    entries{end+1} = e; %#ok<AGROW>
    dropped = [dropped, prefixed([blockName '.' P], d)]; %#ok<AGROW>
end
dropped = [dropped, prefixed([blockName '.'], fn(~claimed))];
end

function [e, dropped] = oneFit(s, model)
e = struct('model', did2.build.label(strrep(model, '_', ' ')));
used = {};
p = getf(s, {'parameters'});
if isnumeric(p) && ~isempty(p)
    c = cell(1, numel(p));
    for k = 1:numel(p)
        c{k} = struct('variable', did2.build.label(sprintf('%s parameter %d', ...
            strrep(model, '_', ' '), k)), 'value', double(p(k)));
    end
    e.coefficients = did2.build.list(c{:});
    used{end+1} = 'parameters';
end
gd = struct();
for f = {{'r2', {'r2', 'r_squared'}}, {'sse', {'sse'}}, {'sse_per_point', {'sse_per_point', 'sse_perpoint'}}}
    [x, nm] = getfn(s, f{1}{2});
    if isnumeric(x) && isscalar(x); gd.(f{1}{1}) = double(x); used{end+1} = nm; end %#ok<AGROW>
end
if ~isempty(fieldnames(gd)); e.goodness = gd; end
mmap = {'preferred_value', {'pref'}; 'half_maximum_below', {'l50', 'empirical_c50'}; ...
    'half_maximum_above', {'h50'}; 'bandwidth', {'bandwidth'}; ...
    'half_width_at_half_maximum', {'hwhh'}; ...
    'orientation_preference', {'orientation_angle_preference'}; ...
    'direction_preference', {'direction_angle_preference'}; ...
    'orientation_preferred_orthogonal_ratio', {'orientation_preferred_orthogonal_ratio'}; ...
    'orientation_preferred_orthogonal_ratio_rectified', {'orientation_preferred_orthogonal_ratio_rectified'}; ...
    'direction_preferred_null_ratio', {'direction_preferred_null_ratio'}; ...
    'direction_preferred_null_ratio_rectified', {'direction_preferred_null_ratio_rectified'}; ...
    'speed_tuning_index', {'speed_tuning_index'}; ...
    'spatial_frequency_preference', {'spatial_frequency_preference'}; ...
    'temporal_frequency_preference', {'temporal_frequency_preference'}; ...
    'partial_r2', {'partial_r2'}; 'nested_f_test_p', {'nested_f_test_p_value'}};
[m, um] = scalarMap(s, mmap);
used = [used, um];
if ~isempty(fieldnames(m)); e.metrics = m; end
% the sampled fit: x then y, as v1 stored them
xNames = {{'values', 'fit_angles', 'contrast'}, {'spatial_frequencies'}, {'temporal_frequencies'}};
yNames = {'fit', 'fit_values', 'values'};
[y, yn] = getfn(s, yNames);
xs = {};
for k = 1:numel(xNames)
    [x, xn] = getfn(s, setdiff(xNames{k}, {yn}));
    if isnumeric(x) && ~isempty(x) && ~strcmp(xn, yn)
        xs{end+1} = double(x(:)); %#ok<AGROW>
        used{end+1} = xn; %#ok<AGROW>
    end
end
if isnumeric(y) && ~isempty(y) && ~isempty(xs) && all(cellfun(@numel, xs) == numel(y))
    e.sampled_fit = struct('independent_values', [xs{:}], 'response', double(y(:)));
    used{end+1} = yn;
end
dropped = setdiff(fieldnames(s), used);
dropped = reshape(dropped, 1, []);
end

function [out, used] = scalarMap(s, map)
out = struct();
used = {};
for k = 1:size(map, 1)
    [x, nm] = getfn(s, map{k, 2});
    if isnumeric(x) && isscalar(x)
        out.(map{k, 1}) = double(x);
        used{end+1} = nm; %#ok<AGROW>
    end
end
end

function v = putUnit(v, u)
if isstring(u) && isscalar(u); u = char(u); end
if ischar(u) && ~isempty(strtrim(u))
    v.response_unit = did2.build.label(strtrim(u));
end
end

function s = putArr(s, name, x, trialsLast)
if isnumeric(x) && ~isempty(x)
    x = double(x);
    if trialsLast && ismatrix(x) && ~isvector(x)
        x = x.';   % v1: trials x stimuli; #88: stimuli x trials (D3)
    end
    s.(name) = x;
end
end

function b = sub(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)) && isscalar(s.(name))
    b = s.(name);
end
end

function v = getf(s, names)
v = getfn(s, names);
end

function [v, nm] = getfn(s, names)
v = [];
nm = '';
if ~isstruct(s); return; end
fn = fieldnames(s);
for i = 1:numel(names)
    hit = find(strcmpi(fn, names{i}), 1);
    if ~isempty(hit)
        nm = fn{hit};
        v = s.(nm);
        return;
    end
end
end

function c = prefixed(p, names)
c = cellfun(@(n) [p n], reshape(names, 1, []), 'UniformOutput', false);
end
