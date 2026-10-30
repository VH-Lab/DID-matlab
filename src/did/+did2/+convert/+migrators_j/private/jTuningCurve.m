function [value, valueAxes, leafFields, dropped, response, extra] = jTuningCurve(srcBlk, family, opts)
%JTUNINGCURVE A v1 tuning-curve result block as did-schema #88's
%   `tuning_curve` value, its dimensions and covariates, and the named
%   calculation's own blocks.
%
%   [VALUE, AXES, LEAFFIELDS, DROPPED, RESPONSE] = jTuningCurve(SRCBLK, FAMILY)
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
%       response_unit is the PLAIN unit read from v1 `response_units`
%       (jResponseVariable): om:hertz for a spike rate, om:one for dF/F; any
%       other non-empty spelling is kept as its label, as before; an empty
%       one leaves the field out.
%       Per-trial arrays take the stimulus dimension FIRST and the trial
%       dimension last (audit 2, D3: "individual / raw_individual add one
%       trailing trial dimension"); v1 stored them trials x stimuli.
%     AXES   struct {dimensions, covariates, datum_order} of the stimulus
%       dimensions, or [] (audit 2, D3: `independent_variables[]` is dropped,
%       the dimensions are the value's; did-schema data_body AMENDMENT 6, Jess
%       Haley 2026-10-22 [covariates], `keys` before). One independent
%       variable: one dimension, its term the variable, and one `quantity`
%       covariate along it holding the values. SEVERAL (a tuningcurve over
%       spatial x temporal frequency, a speed tuning), per Jess Haley
%       2026-10-22 [tuning grid] (answer "4c"):
%         - the conditions form a FULL GRID (every combination of the
%           variables' distinct values present exactly once): one dimension
%           PER VARIABLE, in the order v1 lists the variables, its term the
%           variable and its n the number of distinct values, with one
%           `quantity` covariate along its own dimension holding those values
%           (ascending). Every per-condition array (mean, stddev, stderr,
%           individual, raw_individual, the control's) is reshaped from one
%           condition axis to the grid; the grid is laid out column-major
%           (`datum_order` 'F', the first variable fastest), which AXES states.
%         - otherwise: ONE dimension of n conditions, its term XCO:0000000
%           "experimental condition" (Jess Haley 2026-10-22 [stimulus
%           condition term]), with one `quantity` covariate
%           PER VARIABLE along it (the long format AMENDMENT 6 gives sparse
%           data); the arrays keep their one condition axis.
%       The joined 'a x b' label the dimension carried until 2026-10-22 is
%       gone. No corpus holds such a curve (34,690 tuning curves in the six
%       corpora, all over one variable; [tuning grid]), so both paths are
%       proven on synthetic fixtures only (testTuningCurveLevels).
%     VALUE also carries `significance` and `model_fit[]` on a fitted curve
%       (Jess Haley 2026-10-22 [significance with results], [one fit entry];
%       on tuning_curve_calculation until then).
%     LEAFFIELDS   the named calculation's blocks: `circular_statistics`
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
%   RESPONSE   struct {variable, outcome}: what the response measured, from
%     the same `response_units` (Jess Haley 2026-10-22 [response variable],
%     [dF/F as variable], [response variable nodes]; jResponseVariable).
%     VARIABLE is the registered term for the statement's `variable`: the
%     measured quantity, or EMPTY:0000398 "neural response" when the source
%     does not say ([unstated response variable], 2026-10-23); OUTCOME names
%     the case for the report.
%
%   Fit coefficients are a vector in v1 with no names; each becomes a
%   `{variable, value}` entry named '<model> parameter k' (a label) -- a
%   CONSERVATIVE CHOICE, recorded.
%
%   ONE FUNCTION, TOLD APART BY ITS CONSTRAINTS (Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md):
%     contrast  [Naka-Rushton is one function] (2026-10-26), built by [tuning
%               fits use curve fitting now]: the writer's naka_rushton_RB_,
%               _RBN_ and _RBNS_ fits are ONE model, 'Naka-Rushton'
%               (R(c) = Rm c^n / (c^(n s) + c50^(n s)); NDIcalc-vis-matlab
%               00e3e0f ndi.calc.vis.contrast_tuning writes the parameters as
%               [Rm c50], [Rm c50 n], [Rm c50 n s]), RB written as the
%               constraints n = 1 and s = 1, RBN as s = 1, in the fit entry's
%               `constraints`: {variable 'Naka-Rushton parameter 3' (n), value
%               1} and {'Naka-Rushton parameter 4' (s), 1}. The model is the
%               term EMPTY:0000416 "Naka-Rushton function" (Decided by Jess
%               Haley, 2026-10-30 [Naka-Rushton function minted]), not the
%               bare label 'Naka-Rushton' written before; the coefficients
%               keep their names, 'Naka-Rushton parameter k'.
%     speed     [Priebe fits are one function]: the writer's `fit`,
%               `fit_no_speed` and `fit_fullspeed` are one equation
%               (NDIcalc-vis-matlab 00e3e0f: vis.speed.fit, fit_nospeed and
%               fit_fullspeed all fit vis.speed.tuningfunc, with the speed
%               index xi, parameter 3, bounded to [min_xi, max_xi], held at 0,
%               and held at 1): model 'Priebe fit' each, `fit_no_speed`
%               constrained {'Priebe fit parameter 3', 0} and `fit_fullspeed`
%               {'Priebe fit parameter 3', 1}.
%
%   CONTRAST METRICS ([contrast metrics added], 2026-10-27): a contrast fit's
%   relative_max_gain, saturation_index and sensitivity (10 entries) go in the
%   fit entry's `metrics`, named as on `contrast_sensitivity`. The fields are a
%   did-schema change (Build pending there): each is written only when the
%   schema in use declares it (jSchemaHasPath); until then it stays unplaced
%   and carries the document (carry-056), as before.
%
%   THE `abs` BLOCK ([absolute-value fits are fit entries], Decided by Jess
%   Haley, 2026-10-28, with [interpolated values are a list], 2026-10-30): an
%   SF or TF result's `abs` block (its fitless values and fits of the absolute
%   response) is folded the same way, ALONE, and returned in EXTRA.abs
%   {present, value, leafFields}; jCalculation places its fits as model_fit
%   entries and its fitless as an interpolated_values entry of the SAME
%   calculation, each with response_transform 'absolute value'. Its unplaced
%   fields are listed in DROPPED under 'abs.'.
%
%   OPTS.Rebuilt (family 'stimulus'): raw-curve fields the caller rebuilds
%   from other documents, so they are placed ([tuning stimids rebuild]:
%   stimid, stimulus_presentation_number).

arguments
    srcBlk
    family (1,:) char
    opts.Rebuilt = {}
end

value = struct();
valueAxes = [];
leafFields = struct();
dropped = {};
extra = struct('abs', struct('present', false, 'value', struct(), 'leafFields', struct()));
[v0, ~, o0] = jResponseVariable([]);   % no block: the source does not say
response = struct('variable', v0, 'outcome', o0);
if ~isstruct(srcBlk) || ~isscalar(srcBlk)
    return;
end

if strcmp(family, 'stimulus')
    [value, valueAxes, dropped, response] = rawCurve(srcBlk, opts.Rebuilt);
    return;
end

% ---- properties -----------------------------------------------------------
props = sub(srcBlk, 'properties');
[value, response] = putUnit(value, getf(props, {'response_units', 'responseUnits'}));
if spellingReplaced(response)
    dropped{end+1} = 'properties.response_units';
end
rt = getf(props, {'response_type', 'responseType'});
if ischar(rt) && ~isempty(rt); value.response_type = jLabel(rt); end
co = getf(props, {'coordinates'});
if ischar(co) && ~isempty(co); value.coordinates = co; end
% every other `properties` field was read by nothing and listed nowhere: it is
% unplaced too ([generic stage is lossless], Jess Haley, 2026-10-25)
readProps = {'response_units', 'responseUnits', 'response_type', 'responseType', 'coordinates'};
otherProps = setdiff(fieldnames(props), readProps);
for k = 1:numel(otherProps)
    if ~isempty(props.(otherProps{k}))
        dropped{end+1} = ['properties.' otherProps{k}]; %#ok<AGROW>
    end
end

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
valueAxes = makeAxes(present, cols);
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
value = toGrid(value, valueAxes);
dropped = [dropped, prefixed('tuning_curve.', stated(tc, setdiff(fieldnames(tc), used)))];

% ---- significance (tuning_curve_calculation) -----------------------------
sig = sub(srcBlk, 'significance');
s = struct();
usedS = {};
for f = {'visual_response_anova_p', 'across_stimuli_anova_p'}
    [x, nm] = getfn(sig, f);
    if isnumeric(x) && isscalar(x)
        s.(f{1}) = double(x);
        usedS{end+1} = nm; %#ok<AGROW>
    end
end
% any other `significance` field (or one of the two that is not one number)
% was read by nothing and listed nowhere: it is unplaced too ([generic stage
% is lossless], Jess Haley, 2026-10-25; found by the round trip,
% testRawV1RoundTripTuning)
dropped = [dropped, prefixed('significance.', stated(sig, setdiff(fieldnames(sig), usedS)))];
if ~isempty(fieldnames(s))
    % in the value, beside the fits (Jess Haley 2026-10-22 [significance
    % with results]; tuning_curve_calculation.significance until then)
    value.significance = s;
end

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
    dropped = [dropped, prefixed('vector.', stated(vec, setdiff(fieldnames(vec), usedV)))];
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
    dropped = [dropped, prefixed('fitless.', stated(fl, setdiff(fieldnames(fl), usedF)))];
end

% ---- model fits -------------------------------------------------------------
fits = {};
names = fieldnames(srcBlk);
for k = 1:numel(names)
    nm = names{k};
    if ~(strcmp(nm, 'fit') || startsWith(nm, 'fit_')) || ~isstruct(srcBlk.(nm))
        continue;
    end
    [entries, d] = fitEntries(srcBlk.(nm), nm, family);
    fits = [fits, entries]; %#ok<AGROW>
    dropped = [dropped, d]; %#ok<AGROW>
end
if ~isempty(fits)
    % one fit entry, in the curve's value (Jess Haley 2026-10-22 [one fit
    % entry]; tuning_curve_calculation.model_fit until then)
    value.model_fit = did2.build.list(fits{:});
end

% ---- the absolute-value fits (SF / TF: v1 `abs`) ---------------------------
% [absolute-value fits are fit entries] (Decided by Jess Haley, 2026-10-28):
% folded alone, returned in EXTRA.abs; jCalculation marks its entries
% 'absolute value' on the one calculation
absHandled = false;
if any(strcmp(family, {'sf', 'tf'}))
    [ab, abName] = getfn(srcBlk, {'abs'});
    if ~isempty(abName) && isstruct(ab) && isscalar(ab)
        absHandled = true;
        [av, ~, alf, ad] = jTuningCurve(ab, family);
        dropped = [dropped, prefixed('abs.', ad)];
        extra.abs = struct('present', true, 'value', av, 'leafFields', alf);
    end
end

known = [{'properties', 'tuning_curve', 'significance', 'vector', 'fitless'}, ...
    names(strcmp(names, 'fit') | startsWith(names, 'fit_'))'];
if absHandled
    known{end+1} = 'abs';
end
fold = @(c) lower(strrep(c, '_', ''));
rest = names(~ismember(fold(names), fold(known)));
dropped = [dropped, reshape(stated(srcBlk, rest), 1, [])];
end

% =============================================================================

function [value, valueAxes, dropped, response] = rawCurve(st, rebuilt)
% v1 `stimulus_tuningcurve` (tuningcurve_calc, and the raw pre-calculator curve).
% REBUILT: fields the caller rebuilds from other documents (placed here).
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
valueAxes = makeAxes(names(1:numel(cols)), cols);
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
value = toGrid(value, valueAxes);
[u, nm] = getfn(st, {'response_units'}); used{end+1} = nm;
[value, response] = putUnit(value, u);
if spellingReplaced(response)
    used = setdiff(used, {nm}, 'stable');   % its spelling is not kept
end
for k = 1:numel(rebuilt)
    [~, nm] = getfn(st, rebuilt(k));
    used{end+1} = nm; %#ok<AGROW>
end
used = used(~cellfun(@isempty, used));
rest = setdiff(fieldnames(st), used);
dropped = prefixed('stimulus_tuningcurve.', reshape(stated(st, rest), 1, []));
end

function names = stated(s, names)
%STATED Of NAMES (fields of S), the ones that hold a value. An empty field (the
%   writers' template blank, e.g. control_stimid = []) states nothing, so leaving
%   it out loses nothing ([generic stage is lossless], Jess Haley, 2026-10-25).
if isempty(names); return; end
keep = true(size(names));
for k = 1:numel(names)
    keep(k) = isfield(s, names{k}) && ~isempty(s.(names{k}));
end
names = names(keep);
end

function tf = spellingReplaced(response)
%SPELLINGREPLACED A recognised `response_units` spelling is written as the
%   registered unit (om:hertz, om:one) and variable, and the v1 spelling itself
%   is kept nowhere (putUnit). [generic stage is lossless] (Jess Haley,
%   2026-10-25) lists that rewrite: the field counts as unplaced, so
%   jCalculation carries the document whole as v1. An unrecognised spelling is
%   kept as the unit's label and is placed.
tf = isstruct(response) && isfield(response, 'outcome') ...
    && any(strcmp(response.outcome, {'neural firing rate', 'dF/F'}));
end

function valueAxes = makeAxes(names, cols)
%MAKEAXES The value's stimulus dimension(s) and the covariates along them.
%   One column: dimension term = the variable, one quantity covariate.
%   Several columns of one length n (Jess Haley 2026-10-22 [tuning grid]):
%     a FULL GRID -> one dimension per variable (n_d = its distinct values),
%       one quantity covariate along each, `datum_order` 'F', and the field
%       `grid` (the column-major position of each condition) for toGrid;
%     otherwise -> ONE 'experimental condition' (XCO:0000000) dimension of n, one quantity
%       covariate per variable along it.
%   Ragged columns: no honest dimension; the values stay, without one.
valueAxes = [];
if isempty(cols)
    return;
end
n = numel(cols{1});
if any(cellfun(@numel, cols) ~= n)
    return;   % ragged: no honest dimension; the values stay, without one
end
labels = cellfun(@(nm) strrep(nm, '_', ' '), names, 'UniformOutput', false);
if isscalar(cols)
    valueAxes = struct('dimensions', did2.build.dimension(jLabel(labels{1}), n), ...
        'covariates', did2.build.covariate(jLabel(labels{1}), 0, ...
            'Value', reshape(cols{1}, 1, [])));
    return;
end
[isGrid, levels, position] = fullGrid(cols);
k = numel(cols);
if isGrid
    dims = cell(1, k);
    covs = cell(1, k);
    for d = 1:k
        dims{d} = did2.build.dimension(jLabel(labels{d}), numel(levels{d}));
        covs{d} = did2.build.covariate(jLabel(labels{d}), d - 1, ...
            'Value', reshape(levels{d}, 1, []));
    end
    valueAxes = struct('dimensions', did2.build.list(dims{:}), ...
        'covariates', did2.build.list(covs{:}), 'datum_order', 'F', ...
        'grid', struct('extents', cellfun(@numel, levels), 'position', position));
    return;
end
% The `stimulus condition` dimension of [tuning grid] is XCO:0000000
% "experimental condition" (Jess Haley 2026-10-22 [stimulus condition term],
% did-schema V_eta_data_body_model_plan.md, answer "A").
covs = cell(1, k);
for d = 1:k
    covs{d} = did2.build.covariate(jLabel(labels{d}), 0, 'Value', reshape(cols{d}, 1, []));
end
valueAxes = struct('dimensions', did2.build.dimension( ...
    struct('node', 'XCO:0000000', 'name', 'experimental condition'), n), ...
    'covariates', did2.build.list(covs{:}));
end

function [tf, levels, position] = fullGrid(cols)
%FULLGRID Do the n conditions (one row per condition across COLS) form a full
%   grid: every combination of the columns' distinct values present exactly
%   once? LEVELS{d} are column d's distinct values, ascending; POSITION(i) is
%   condition i's column-major (first variable fastest) linear index in the
%   grid of extents numel(LEVELS{d}).
k = numel(cols);
n = numel(cols{1});
levels = cell(1, k);
subs = zeros(n, k);
for d = 1:k
    c = double(cols{d}(:));
    if any(isnan(c))
        tf = false; position = []; return;
    end
    [levels{d}, ~, subs(:, d)] = unique(c);
    levels{d} = levels{d}(:);
end
ext = cellfun(@numel, levels);
position = zeros(n, 1);
stride = 1;
for d = 1:k
    position = position + (subs(:, d) - 1) * stride;
    stride = stride * ext(d);
end
position = position + 1;
tf = prod(ext) == n && numel(unique(position)) == n;
if ~tf
    position = [];
end
end

function value = toGrid(value, valueAxes)
%TOGRID Reshape every per-condition array of VALUE from one condition axis to
%   the grid makeAxes found ([tuning grid]); a no-op without one. An array is
%   per-condition when it is a vector of n (mean, stddev, stderr, the
%   control's) or has n rows (individual, raw_individual: n x trials, then
%   [real, imaginary]); anything else (a pooled scalar) is left as it is.
if ~isstruct(valueAxes) || ~isfield(valueAxes, 'grid')
    return;
end
g = valueAxes.grid;
for f = {'mean', 'stddev', 'stderr', 'individual', 'raw_individual'}
    if isfield(value, f{1}); value.(f{1}) = gridArray(value.(f{1}), g); end
end
if isfield(value, 'control') && isstruct(value.control)
    for f = {'mean', 'stddev', 'stderr', 'individual'}
        if isfield(value.control, f{1})
            value.control.(f{1}) = gridArray(value.control.(f{1}), g);
        end
    end
end
end

function y = gridArray(x, g)
n = numel(g.position);
if ~isnumeric(x) || isempty(x)
    y = x;
    return;
end
if isvector(x) && numel(x) == n
    y = zeros(g.extents);
    y(g.position) = x(:);
elseif size(x, 1) == n
    sz = size(x);
    flat = reshape(x, n, []);
    out = zeros(prod(g.extents), size(flat, 2));
    out(g.position, :) = flat;
    y = reshape(out, [g.extents, sz(2:end)]);
else
    y = x;
end
end

function [entries, dropped] = fitEntries(blk, blockName, family)
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
    [model, constraints, modelTerm] = oneFunction(model, blockName, family);
    [e, d] = oneFit(grp, model, constraints, family, modelTerm);
    entries{end+1} = e; %#ok<AGROW>
    dropped = [dropped, prefixed([blockName '.' P], d)]; %#ok<AGROW>
end
dropped = [dropped, prefixed([blockName '.'], stated(blk, fn(~claimed)))];
end

function [model, constraints, modelTerm] = oneFunction(model, blockName, family)
%ONEFUNCTION The one model a fit is, and the constraints that tell it apart
%   ({coefficient number, value} rows): see ONE FUNCTION in the header.
%   MODELTERM is the model's term when it has one ([] otherwise: oneFit
%   writes the label of MODEL); MODEL stays the stem of the coefficient names.
constraints = zeros(0, 2);
modelTerm = [];
switch family
    case 'contrast'
        t = regexp(model, '^naka_rushton_(RB|RBN|RBNS)$', 'tokens', 'once', 'ignorecase');
        if ~isempty(t)
            model = 'Naka-Rushton';
            % Decided by Jess Haley, 2026-10-30, did-schema
            % V_eta_go_forward_class_audit.md [Naka-Rushton function minted]:
            % the model is EMPTY:0000416 "Naka-Rushton function" (empty-ontology
            % #32), not a bare label. Written by its node even where the term
            % registry in use does not hold the row yet (did-schema #242); a
            % migration runs with the TermRegistry check off.
            modelTerm = did2.convert.registeredTerm('EMPTY:0000416', 'Naka-Rushton function');
            switch upper(t{1})
                case 'RB'
                    constraints = [3 1; 4 1];   % n = 1, s = 1
                case 'RBN'
                    constraints = [4 1];        % s = 1
            end
        end
    case 'speed'
        if strcmpi(model, 'Priebe_fit')
            switch blockName
                case 'fit_no_speed'
                    constraints = [3 0];        % xi = 0
                case 'fit_fullspeed'
                    constraints = [3 1];        % xi = 1
            end
        end
end
end

function [e, dropped] = oneFit(s, model, constraints, family, modelTerm)
label = strrep(model, '_', ' ');
if nargin >= 5 && ~isempty(modelTerm)
    e = struct('model', modelTerm);   % [Naka-Rushton function minted]
else
    e = struct('model', jLabel(label));
end
used = {};
p = getf(s, {'parameters'});
if isnumeric(p) && ~isempty(p)
    c = cell(1, numel(p));
    for k = 1:numel(p)
        c{k} = struct('variable', jLabel(sprintf('%s parameter %d', ...
            label, k)), 'value', double(p(k)));
    end
    e.coefficients = did2.build.list(c{:});
    used{end+1} = 'parameters';
end
if ~isempty(constraints)
    c = cell(1, size(constraints, 1));
    for k = 1:size(constraints, 1)
        c{k} = struct('variable', jLabel(sprintf('%s parameter %d', label, ...
            constraints(k, 1))), 'value', constraints(k, 2));
    end
    e.constraints = did2.build.list(c{:});
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
if strcmp(family, 'contrast')
    % [contrast metrics added] (Jess Haley, 2026-10-27): named as on
    % contrast_sensitivity; written only once the schema declares them
    for f = {'relative_max_gain', 'saturation_index', 'sensitivity'}
        [x, nm] = getfn(s, f);
        if isempty(nm) || ~isnumeric(x) || isempty(x) ...
                || ~jSchemaHasPath('tuning_curve', {'value', 'model_fit', 'metrics', f{1}})
            continue;
        end
        if strcmp(f{1}, 'sensitivity')
            m.(f{1}) = double(x(:));
        elseif isscalar(x)
            m.(f{1}) = double(x);
        else
            continue;
        end
        used{end+1} = nm; %#ok<AGROW>
    end
end
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
dropped = stated(s, setdiff(fieldnames(s), used));
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

function [v, response] = putUnit(v, u)
% The plain unit and the response variable, both from v1 `response_units`
% (jResponseVariable). A recognised spelling writes the registered unit
% (om:hertz, om:one); any other non-empty spelling keeps its label, as before;
% an empty one writes nothing.
if isstring(u) && isscalar(u); u = char(u); end
[variable, unit, outcome] = jResponseVariable(u);
response = struct('variable', variable, 'outcome', outcome);
if ~isempty(unit)
    v.response_unit = unit;
elseif ischar(u) && ~isempty(strtrim(u))
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
