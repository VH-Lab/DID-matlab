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
%       block, stimulus_tuningcurve's stimid / presentation numbers.
%   The raw curve's per-trial responses keep BOTH halves NDI stores:
%   `individual` / `control.individual` are keys x trials x 2 ([real, imag]
%   last) when v1 carries the *_imaginary half, keys x trials otherwise (Jess
%   Haley, 2026-10-21, "a1").
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
if ischar(rt) && ~isempty(rt); value.response_type = jLabel(rt); end
co = getf(props, {'coordinates'});
if ischar(co) && ~isempty(co); value.coordinates = co; end

% ---- the curve ------------------------------------------------------------
tc = sub(srcBlk, 'tuning_curve');
axesNames = {'direction', 'angle', 'contrast', 'spatial_frequency', ...
    'temporal_frequency', 'speed'};
present = {};
cols = {};
used = {};   % the field names AS SPELLED in the document (snake or camelCase)
for k = 1:numel(axesNames)
    [v, nm] = getfn(tc, axesNames(k));
    if isnumeric(v) && ~isempty(v)
        present{end+1} = axesNames{k}; %#ok<AGROW>
        cols{end+1} = double(v(:)); %#ok<AGROW>
        used{end+1} = nm; %#ok<AGROW>
    end
end
keys = makeKeys(present, cols);
[value, used] = takeArr(value, used, 'mean', tc, {'mean'}, false);
[value, used] = takeArr(value, used, 'stddev', tc, {'stddev'}, false);
[value, used] = takeArr(value, used, 'stderr', tc, {'stderr'}, false);
[value, used] = takeArr(value, used, 'individual', tc, {'individual'}, true);
[value, used] = takeArr(value, used, 'raw_individual', tc, {'raw_individual'}, true);
ctl = struct();
[ctl, used] = takeArr(ctl, used, 'mean', tc, {'control_mean'}, false);
[ctl, used] = takeArr(ctl, used, 'stddev', tc, {'control_stddev'}, false);
[ctl, used] = takeArr(ctl, used, 'stderr', tc, {'control_stderr'}, false);
[ctl, used] = takeArr(ctl, used, 'individual', tc, {'control_individual'}, true);
% the pooled control statistics (SF / TF writers): control_mean_stddev /
% control_mean_stderr -> control.pooled.stddev / .stderr (Jess Haley,
% 2026-10-21, "b"); camelCase read through getfn
pooled = struct();
[pooled, used] = takeArr(pooled, used, 'stddev', tc, {'control_mean_stddev'}, false);
[pooled, used] = takeArr(pooled, used, 'stderr', tc, {'control_mean_stderr'}, false);
if ~isempty(fieldnames(pooled)); ctl.pooled = pooled; end
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
fold = @(c) lower(strrep(c, '_', ''));
rest = names(~ismember(fold(names), fold(known)));
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
used = {};   % the field names AS SPELLED in the document (snake or camelCase)
[~, nm] = getfn(st, {'independent_variable_label'}); used{end+1} = nm;
[~, nm] = getfn(st, {'independent_variable_value'}); used{end+1} = nm;
[value, used] = takeArr(value, used, 'mean', st, {'response_mean'}, false);
[value, used] = takeArr(value, used, 'stddev', st, {'response_stddev'}, false);
[value, used] = takeArr(value, used, 'stderr', st, {'response_stderr'}, false);
[value, used] = takeTrials(value, used, 'individual', st, ...
    {'individual_responses_real', 'individual_responses'}, {'individual_responses_imaginary'});
ctl = struct();
[ctl, used] = takeArr(ctl, used, 'mean', st, {'control_response_mean'}, false);
[ctl, used] = takeArr(ctl, used, 'stddev', st, {'control_response_stddev'}, false);
[ctl, used] = takeArr(ctl, used, 'stderr', st, {'control_response_stderr'}, false);
[ctl, used] = takeTrials(ctl, used, 'individual', st, ...
    {'control_individual_responses_real'}, {'control_individual_responses_imaginary'});
if ~isempty(fieldnames(ctl)); value.control = ctl; end
[u, nm] = getfn(st, {'response_units'}); used{end+1} = nm;
value = putUnit(value, u);
used = used(~cellfun(@isempty, used));
rest = setdiff(fieldnames(st), used);
dropped = prefixed('stimulus_tuningcurve.', reshape(rest, 1, []));
end

function keys = makeKeys(names, cols)
keys = [];
if isempty(cols)
    return;
end
if isscalar(cols)
    v = cols{1};
    keys = did2.build.key(jLabel(strrep(names{1}, '_', ' ')), numel(v), 'Values', v');
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
        parts{d} = sprintf('%s %s', strrep(names{d}, '_', ' '), shortestText(M(i, d)));
    end
    pos{i} = strjoin(parts, ', ');
end
keys = did2.build.key(jLabel(label), n, 'Labels', pos);
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
e = struct('model', jLabel(strrep(model, '_', ' ')));
used = {};
p = getf(s, {'parameters'});
if isnumeric(p) && ~isempty(p)
    c = cell(1, numel(p));
    for k = 1:numel(p)
        c{k} = struct('variable', jLabel(sprintf('%s parameter %d', ...
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
    v.response_unit = jLabel(strtrim(u));
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

function [s, used] = takeTrials(s, used, name, src, realNames, imagNames)
% A per-trial response that NDI stores as two halves (tuning_response.m
% :465-472, individual_responses_real / _imaginary, trials x points in v1):
% keys x trials x 2, [real, imaginary] in the LAST dimension, whenever the
% imaginary half is carried; keys x trials when it is absent (Jess Haley,
% 2026-10-21, "a1"). Both names as spelled are recorded as read.
[re, nmR] = getfn(src, realNames);
[im, nmI] = getfn(src, imagNames);
if ~isempty(nmR); used{end+1} = nmR; end
if ~isempty(nmI); used{end+1} = nmI; end
if ~(isnumeric(re) && ~isempty(re))
    return;
end
x = trialsLastOrient(double(re));
if isnumeric(im) && ~isempty(im) && isequal(size(im), size(re))
    x = cat(3, x, trialsLastOrient(double(im)));
end
s.(name) = x;
end

function x = trialsLastOrient(x)
% v1: trials x stimuli; #88: stimuli x trials (D3), as putArr does
if ismatrix(x) && ~isvector(x)
    x = x.';
end
end

function [s, used] = takeArr(s, used, name, src, names, trialsLast)
% putArr from the first of NAMES SRC carries, recording the name as spelled
[x, nm] = getfn(src, names);
s = putArr(s, name, x, trialsLast);
if ~isempty(nm)
    used{end+1} = nm;
end
end

function b = sub(s, name)
b = struct();
[v, nm] = getfn(s, {name});
if ~isempty(nm) && isstruct(v) && isscalar(v)
    b = v;
end
end

function v = getf(s, names)
v = getfn(s, names);
end

function [v, nm] = getfn(s, names)
% The first of NAMES that S carries. A NESTED field is not renamed by
% universalRenames (it snake_cases only a block's immediate field names), so
% each name is matched in any case AND in its camelCase spelling (controlMean
% for control_mean): case and underscores are ignored, an exact match first.
% NM is the field name as spelled in S.
v = [];
nm = '';
if ~isstruct(s); return; end
fn = fieldnames(s);
folded = lower(strrep(fn, '_', ''));
for i = 1:numel(names)
    hit = find(strcmpi(fn, names{i}), 1);
    if isempty(hit)
        hit = find(strcmp(folded, lower(strrep(names{i}, '_', ''))), 1);
    end
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

function t = shortestText(x)
% The shortest decimal text that reads back as exactly X (0.04, not
% 0.040000000000000001), so a label stays lossless and readable.
for p = 1:17
    t = sprintf('%.*g', p, x);
    if str2double(t) == x
        return;
    end
end
end
