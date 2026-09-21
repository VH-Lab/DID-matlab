function [value, calcFields] = jTuningCurveValue(block)
%JTUNINGCURVEVALUE Reshape a v1 tuning result block into V_eta's split shape.
%
%   V_eta (PR #68) splits the collapsed value across two class blocks:
%     tuning_curve (composite; abstract): value = { independent_variables[],
%         mean, stddev, stderr, individual, raw_individual, control{...},
%         response_units, response_type, coordinates }
%     tuning_curve_calculation (abstract calc leaf): significance{...},
%         model_fit[]
%
%   Returns TWO structs so jCalculation can distribute them across the right
%   emitted blocks:
%     value       -> body.tuning_curve.value
%     calcFields  -> merged into body.tuning_curve_calculation
%
%   Reads the v1 block defensively (isfield-guarded) so a missing field yields
%   an empty (but declared) slot rather than a validation failure.
arguments
    block struct
end

% BUILD SCALAR STRUCTS WITHOUT DISTRIBUTING A NON-SCALAR ARRAY. model_fit (a
% struct array) is assigned separately below.
value = struct( ...
    'independent_variables', [], ...
    'mean', [], 'stddev', [], 'stderr', [], ...
    'individual', [], 'raw_individual', [], ...
    'control', struct(), ...
    'response_units', '', 'response_type', '', ...
    'coordinates', '');
calcFields = struct('significance', struct(), 'model_fit', emptyFits());

if ~isstruct(block) || ~isscalar(block); return; end

% Fitted composites nest the curve under `tuning_curve`; the raw curve is flat.
tc = block;
if isfield(block, 'tuning_curve') && isstruct(block.tuning_curve)
    tc = block.tuning_curve;
end

value.mean       = getf(tc, {'mean', 'response_mean'});
value.stddev     = getf(tc, {'stddev', 'response_stddev'});
value.stderr     = getf(tc, {'stderr', 'response_stderr'});
value.individual = getf(tc, {'individual', 'individual_responses'});
raw = getf(tc, {'raw_individual', 'individual_responses_raw'});
if ~isempty(raw); value.raw_individual = raw; end
value.independent_variables = independentAxes(tc, block);
value.response_units = responseUnits(block);
rt = getf(block, {'response_type', 'responseType'});
if ischar(rt); value.response_type = rt;
elseif isstring(rt) && isscalar(rt); value.response_type = char(rt); end
value.control = controlBlock(tc, block);

% Calc-family fields (moved onto tuning_curve_calculation per V_eta):
if isfield(block, 'significance') && isstruct(block.significance)
    calcFields.significance = block.significance;
end
calcFields.model_fit = collectFits(block);
end

% ===================== helpers =============================================

function v = getf(s, names)
v = [];
if ~isstruct(s); return; end
for i = 1:numel(names)
    if isfield(s, names{i}); v = s.(names{i}); return; end
end
end

function axes = independentAxes(tc, block)
%INDEPENDENTAXES Build the V_eta independent_variables[] array.
%
%   Each entry is {variable, values, unit}. This helper detects the v1 axis
%   fields present (direction, contrast, spatial_frequency, temporal_frequency,
%   speed, or a bare independent_variable_value) and emits ONE entry per
%   distinct axis found. speed_tuning nominally has TWO axes (temporal +
%   spatial); when both fields are present, both are emitted.
axesList = {};
knownAxes = { ...
    'direction',            'direction',            'radian'; ...
    'contrast',             'contrast',             ''; ...
    'spatial_frequency',    'spatial frequency',    'cycles_per_degree'; ...
    'temporal_frequency',   'temporal frequency',   'Hz'; ...
    'speed',                'speed',                'degrees_per_second'};
for k = 1:size(knownAxes, 1)
    fn = knownAxes{k, 1};
    v = getf(tc, {fn});
    if isempty(v); v = getf(block, {fn}); end
    if isempty(v); continue; end
    axesList{end+1} = struct( ...
        'variable', jOntologyTerm('', knownAxes{k, 2}), ...
        'values',   v, ...
        'unit',     jOntologyTerm('', knownAxes{k, 3})); %#ok<AGROW>
end
if isempty(axesList)
    v = getf(tc, {'independent_variable_value', 'independent_variable'});
    if isempty(v); v = getf(block, {'independent_variable_value', 'independent_variable'}); end
    if ~isempty(v)
        axesList{end+1} = struct( ...
            'variable', jOntologyTerm('', ''), ...
            'values',   v, ...
            'unit',     jOntologyTerm('', ''));
    end
end
if isempty(axesList)
    axes = [];
    return;
end
axes = axesList{1};
for k = 2:numel(axesList)
    axes(end+1) = axesList{k}; %#ok<AGROW>
end
end

function u = responseUnits(block)
% See jTuningCurveValue history for the two-level read (block-level for the flat
% raw curve, `properties.response_units` for the five fitted composites), and the
% char-guard against tuning_response.m's declared-and-unassigned '' pattern.
u = '';
levels = {block, subStruct(block, 'properties')};
for k = 1:numel(levels)
    v = getf(levels{k}, {'response_units', 'responseUnits'});
    if ischar(v) && ~isempty(v); u = v; return; end
    if isstring(v) && isscalar(v) && strlength(v) > 0; u = char(v); return; end
end
end

function c = controlBlock(tc, block)
% All control fields live inside `tuning_curve` in the five did_v1 fitted tuning
% writers; the flat raw curve carries per-block `control_response_*` variants.
% V_eta nests control under `control.{mean,stddev,stderr,individual}`.
c = struct();
spec = { ...
    'mean',        {'control_mean',        'control_response_mean'}; ...
    'stddev',      {'control_stddev',      'control_response_stddev'}; ...
    'stderr',      {'control_stderr',      'control_response_stderr'}; ...
    'individual',  {'control_individual'}};
for i = 1:size(spec, 1)
    cands = spec{i, 2};
    search = cell(1, 2 * numel(cands));
    for k = 1:numel(cands)
        search{2*k - 1} = cands{k};
        search{2*k}     = camelOf(cands{k});
    end
    v = getf(tc, search);
    if isempty(v); v = getf(block, search); end
    % An invented empty control field is the "invented-empty-field" pattern.
    if ~isempty(v); c.(spec{i, 1}) = v; end
end
end

function b = subStruct(s, name)
b = struct();
if isstruct(s) && isfield(s, name) && isstruct(s.(name)); b = s.(name); end
end

function out = camelOf(nm)
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
