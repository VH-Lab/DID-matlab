function value = jTuningCurveValue(block)
%JTUNINGCURVEVALUE Reshape a v1 tuning result block into the unified `tuning_curve`
%   value (R2/R3 collapse, V_eta_tuning_model_plan.md). Emits ONLY the declared
%   tuning_curve sub-fields so the strict-fields validator is satisfied; reads the v1
%   block defensively (isfield-guarded) so an imperfect field name yields an empty
%   (but declared) slot rather than a validation failure.
%
%   The 6 v1 families differ: the fitted composites nest the curve under `tuning_curve`
%   and carry `significance` / `vector` / `fitless` / `fit*`; the raw
%   stimulus_tuningcurve is flat. Mapping:
%     v1 `vector`   -> circular_statistics   (circular_variance, preference, Hotelling)
%     v1 `fitless`  -> interpolated_values   (c50, l50, pref, bandwidth, …)
%     v1 `fit`/`fit_*` -> model_fit ARRAY    (each {model, coefficients, goodness})
%   The empirical curve (independent axis + mean/stddev/stderr/individual/control) maps
%   to the response_* fields.
%
%   "Field-name refinement (exact v1 keys) is a follow-up" -- PARTLY DONE, AND THE PART
%   THAT IS NOT DONE IS NAMED HERE RATHER THAN LEFT AS A BLANKET DISCLAIMER. ONE read
%   was corrected against the writers (NDIcalc-vis 65718ed); its evidence sits on the
%   helper that does it, so it is next to the code it justifies:
%     * controlBlock  read control_mean/_stddev/_stderr at BLOCK level, a level 0 of the
%                     writer's 64 mock documents populate, and never named
%                     control_mean_stddev / control_mean_stderr at all. Now reads the
%                     `tuning_curve` level, all six names.
%
%   STILL UNREFINED, and deliberately untouched by this change -- two further defects,
%   each reported so that a repair arrives on its own rather than folded in here:
%     * `response_units` is read at BLOCK level. Correct for the FLAT raw
%       stimulus_tuningcurve; WRONG for all five fitted composites, which spell it
%       `properties.response_units` (contrast_tuning.m:213, oridir_tuning.m:207,
%       spatial_frequency_tuning.m:234, speed_tuning.m:245,
%       temporal_frequency_tuning.m:237). Correcting the LEVEL alone is not enough:
%       the writer's real value there is the numeric EMPTY MATRIX in 64/64 mock
%       documents, while V_eta types the slot `char`.
%     * the FLAT raw stimulus_tuningcurve names its control fields
%       control_response_mean / control_response_stddev / control_response_stderr /
%       control_individual_responses_real / _imaginary (NDI-matlab
%       +ndi/+app/+stimulus/tuning_response.m:400-405), NONE of which is in the name
%       list controlBlock searches -- so that shape still contributes no control block.
arguments
    block struct
end

% NOTE: build the scalar `value` WITHOUT passing a non-scalar struct array to struct()
% (that would distribute and make `value` itself an array). model_fit (a struct array) is
% assigned separately below.
value = struct( ...
    'independent_values', [], 'response_mean', [], 'response_stddev', [], ...
    'response_stderr', [], 'individual_responses', [], 'control_response', struct(), ...
    'response_units', '', 'model_fit', [], 'significance', struct(), ...
    'circular_statistics', struct(), 'interpolated_values', struct());
value.model_fit = emptyFits();

if ~isstruct(block) || ~isscalar(block); return; end

% The curve: fitted composites nest it under `tuning_curve`; the raw curve is flat.
tc = block;
if isfield(block, 'tuning_curve') && isstruct(block.tuning_curve)
    tc = block.tuning_curve;
end

value.response_mean       = getf(tc, {'mean', 'response_mean'});
value.response_stddev     = getf(tc, {'stddev', 'response_stddev'});
value.response_stderr     = getf(tc, {'stderr', 'response_stderr'});
value.individual_responses = getf(tc, {'individual', 'individual_responses', ...
                                       'individual_responses_real'});
value.independent_values  = independentAxis(tc, block);
value.response_units      = getf(block, {'response_units'});
value.control_response    = controlBlock(tc, block);

if isfield(block, 'significance') && isstruct(block.significance)
    value.significance = block.significance;
end
if isfield(block, 'vector') && isstruct(block.vector)
    value.circular_statistics = block.vector;
end
if isfield(block, 'fitless') && isstruct(block.fitless)
    value.interpolated_values = block.fitless;
end
value.model_fit = collectFits(block);
end

% ===================== helpers =============================================

function v = getf(s, names)
v = [];
if ~isstruct(s); return; end
for i = 1:numel(names)
    if isfield(s, names{i}); v = s.(names{i}); return; end
end
end

function ax = independentAxis(tc, block)
% The independent variable is named per family (direction / contrast / spatial_frequency
% / temporal_frequency / speed) and, for the raw curve, `independent_variable_value`.
ax = getf(tc, {'independent_variable_value', 'direction', 'contrast', ...
    'spatial_frequency', 'temporal_frequency', 'speed', 'independent_variable'});
if isempty(ax)
    ax = getf(block, {'independent_variable_value', 'independent_variable'});
end
end

function c = controlBlock(tc, block)
% EVERY CONTROL FIELD LIVES INSIDE `tuning_curve`, IN ALL FIVE did_v1 FITTED TUNING
% WRITERS. This read used to take control_mean/_stddev/_stderr off the BLOCK, a level
% no writer populates, and never named the other two at all. Measured over the
% writer's own mock corpus (NDIcalc-vis 65718ed, +ndi/+calc/+vis/mock/):
%
%   DENOMINATOR: 64 mock document(s), 5 families; control_* at BLOCK level: 0/64
%   contrast_tuning       9/9   tuning_curve: control_stddev, control_stderr
%   orientation_direction 7/7   tuning_curve: control_individual
%   spatial_frequency    22/22  tuning_curve: control_mean, control_stddev,
%                               control_stderr, control_mean_stddev, control_mean_stderr
%   speed_tuning         18/18  tuning_curve: control_stddev, control_stderr
%   temporal_frequency    8/8   the same five as spatial_frequency
%
% Writer lines, one per family: contrast_tuning.m:237-238, oridir_tuning.m:232,
% spatial_frequency_tuning.m:258-262, speed_tuning.m:276-277,
% temporal_frequency_tuning.m:261-265 -- every one of them inside the
% `tuning_curve = struct(...)` call, none beside it.
%
% `tc` is block.tuning_curve when that sub-struct exists and `block` itself otherwise
% (the flat raw curve), so reading tc first and falling back to block covers both
% shapes without inventing a level. The camelCase fallback is the repo's standing rule
% for a NESTED read: universalRenames.m:32-37 snake_cases only the IMMEDIATE field
% names of a property block and leaves nested struct values alone.
c = struct();
names = {'control_individual', 'control_mean', 'control_stddev', 'control_stderr', ...
         'control_mean_stddev', 'control_mean_stderr'};
for i = 1:numel(names)
    nm = names{i};
    v = getf(tc, {nm, camelOf(nm)});
    if isempty(v); v = getf(block, {nm, camelOf(nm)}); end
    if ~isempty(v); c.(nm) = v; end
end
end

function out = camelOf(nm)
% snake_case -> lowerCamelCase, for the nested-field fallback described above.
parts = strsplit(nm, '_');
out = parts{1};
for k = 2:numel(parts)
    p = parts{k};
    if isempty(p); continue; end
    p(1) = upper(p(1));
    out = [out p]; %#ok<AGROW>
end
end

function fits = collectFits(block)
% Every field whose name is `fit` or starts with `fit_` becomes one model_fit entry.
fits = emptyFits();
if ~isstruct(block); return; end
fns = fieldnames(block);
for i = 1:numel(fns)
    nm = fns{i};
    if strcmp(nm, 'fit') || (numel(nm) > 4 && strncmp(nm, 'fit_', 4))
        b = block.(nm);
        if ~isstruct(b); continue; end
        modelName = nm;
        if strcmp(nm, 'fit'); modelName = 'fit'; else; modelName = nm(5:end); end
        entry = struct('model', jOntologyTerm('', modelName), ...
            'coefficients', b, 'goodness', struct());
        if isempty(fits); fits = entry; else; fits(end+1) = entry; end %#ok<AGROW>
    end
end
end

function e = emptyFits()
e = struct('model', {}, 'coefficients', {}, 'goodness', {});
end
