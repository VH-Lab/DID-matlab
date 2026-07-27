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
%   to the response_* fields. Field-name refinement (exact v1 keys) is a follow-up; this
%   pass lands the class collapse + 0-orphan id preservation.
arguments
    block struct
end

value = struct( ...
    'independent_values', [], 'response_mean', [], 'response_stddev', [], ...
    'response_stderr', [], 'individual_responses', [], 'control_response', struct(), ...
    'response_units', '', 'model_fit', emptyFits(), 'significance', struct(), ...
    'circular_statistics', struct(), 'interpolated_values', struct());

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
c = struct();
cv = getf(tc, {'control_individual'});
if ~isempty(cv); c.control_individual = cv; end
for nm = {'control_mean', 'control_stddev', 'control_stderr'}
    v = getf(block, nm);
    if ~isempty(v); c.(nm{1}) = v; end
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
