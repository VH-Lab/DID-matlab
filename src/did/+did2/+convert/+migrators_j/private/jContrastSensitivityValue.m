function value = jContrastSensitivityValue(block)
%JCONTRASTSENSITIVITYVALUE Reshape the v1 contrast_sensitivity_calc result bag into the
%   `contrast_sensitivity` value cell. Sibling of jTuningCurveValue; same principle,
%   different independent axis.
%
%   The v1 block is FLAT: 21 fields, five metric families each suffixed _rb / _rbn /
%   _rbns, plus `parameters_<variant>`. Those suffixes are not decoration -- per the
%   conversion doc, RB / RBN / RBNS are three **Naka-Rushton fit variants**. So they are
%   FITS, and each becomes one `model_fit` ARRAY entry carrying its own coefficients AND
%   the per-spatial-frequency metrics derived from that fit. The fit-less and
%   significance scalars move to the same TYPED sub-blocks tuning_curve uses
%   (`interpolated_values` / `significance`), which keeps them queryable rather than
%   flattening them into a bag (T13).
%
%   Every v1 field is preserved. Reads defensively (isfield-guarded) so an absent
%   variant yields no entry rather than a validation failure.
arguments
    block struct
end

% NOTE: build the scalar `value` WITHOUT passing a non-scalar struct array to struct()
% (that would distribute and make `value` itself an array). model_fit is assigned after.
value = struct( ...
    'spatial_frequencies', [], 'model_fit', [], ...
    'interpolated_values', struct(), 'significance', struct(), ...
    'is_modulated_response', false, 'response_type', '');
value.model_fit = emptyFits();

if ~isstruct(block) || ~isscalar(block); return; end

value.spatial_frequencies = getf(block, {'spatial_frequencies'});

rt = getf(block, {'response_type'});
if ischar(rt); value.response_type = rt;
elseif isstring(rt) && isscalar(rt); value.response_type = char(rt); end

imr = getf(block, {'is_modulated_response'});
if ~isempty(imr); value.is_modulated_response = logical(imr(1)); end

% fit-less interpolated summary -> the typed interpolated_values sub-block
c50 = getf(block, {'fitless_interpolated_c50'});
if ~isempty(c50); value.interpolated_values = struct('c50', c50); end

% the Bonferroni p-values -> the typed significance sub-block
sig = struct();
for nm = {'visual_response_p_bonferroni', 'response_varies_p_bonferroni'}
    v = getf(block, nm);
    if ~isempty(v); sig.(nm{1}) = v; end
end
value.significance = sig;

value.model_fit = collectVariantFits(block);
end

% ===================== helpers =============================================

function v = getf(s, names)
v = [];
if ~isstruct(s); return; end
for i = 1:numel(names)
    if isfield(s, names{i}); v = s.(names{i}); return; end
end
end

function fits = collectVariantFits(block)
% One model_fit entry per Naka-Rushton variant PRESENT on the source. The four metric
% families are per-spatial-frequency arrays derived from that specific fit, so they ride
% inside the entry rather than as parallel top-level arrays keyed by a variant index --
% that parallel-array coupling is exactly what the _rb/_rbn/_rbns suffixes encoded.
fits = emptyFits();
variants = {'rb', 'rbn', 'rbns'};
metrics  = {'sensitivity', 'relative_max_gain', 'empirical_c50', 'saturation_index'};
for i = 1:numel(variants)
    v = variants{i};
    entry = struct('model', jOntologyTerm('', ['naka_rushton_' v]), ...
        'coefficients', [], 'goodness', struct(), ...
        'sensitivity', [], 'relative_max_gain', [], ...
        'empirical_c50', [], 'saturation_index', []);
    present = false;
    coeff = getf(block, {['parameters_' v]});
    if ~isempty(coeff)
        entry.coefficients = coeff;
        present = true;
    end
    for m = 1:numel(metrics)
        mv = getf(block, {[metrics{m} '_' v]});
        if ~isempty(mv)
            entry.(metrics{m}) = mv;
            present = true;
        end
    end
    if ~present
        continue;   % variant absent on this doc -> no entry (not an empty one)
    end
    if isempty(fits); fits = entry; else; fits(end+1) = entry; end %#ok<AGROW>
end
end

function e = emptyFits()
e = struct('model', {}, 'coefficients', {}, 'goodness', {}, ...
    'sensitivity', {}, 'relative_max_gain', {}, ...
    'empirical_c50', {}, 'saturation_index', {});
end
