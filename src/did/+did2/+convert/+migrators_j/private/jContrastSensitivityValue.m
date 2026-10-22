function [value, valueAxes, dropped] = jContrastSensitivityValue(block)
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
%
%   did-schema #88 (contrast_sensitivity.value, the #73 audit-2 amendment):
%   VALUE {model_fit[] {model, coefficients[] {variable, value}, goodness,
%   sensitivity, relative_max_gain, c50 (v1 empirical_c50; empirical_c50 until
%   2026-10-22), saturation_index},
%   interpolated_values {c50}, significance {...}, response_type (a bound
%   term)}; AXES {dimensions, covariates}: one `spatial frequency` dimension
%   the per-SF arrays are indexed by, the frequencies a quantity covariate
%   along it (data_body AMENDMENT 6; one key before); DROPPED the v1 fields with no home (`is_modulated_response`).
%   A Naka-Rushton variant's v1 parameters are a parameters x SF matrix; each
%   element is one coefficient entry named '<model> parameter k, spatial
%   frequency j' -- every number kept, a CONSERVATIVE CHOICE recorded.

arguments
    block struct
end

value = struct();
valueAxes = [];
dropped = {};
if ~isstruct(block) || ~isscalar(block); return; end
sf = getf(block, {'spatial_frequencies'});
if isnumeric(sf) && ~isempty(sf)
    valueAxes = struct( ...
        'dimensions', did2.build.dimension(jLabel('spatial frequency'), numel(sf)), ...
        'covariates', did2.build.covariate(jLabel('spatial frequency'), 0, 'Value', double(sf(:))'));
end
rt = getf(block, {'response_type'});
if isstring(rt) && isscalar(rt); rt = char(rt); end
if ischar(rt) && ~isempty(rt); value.response_type = jLabel(rt); end
c50 = getf(block, {'fitless_interpolated_c50'});
if isnumeric(c50) && ~isempty(c50); value.interpolated_values = struct('c50', double(c50)); end
sig = struct();
for nm = {'visual_response_p_bonferroni', 'response_varies_p_bonferroni'}
    v = getf(block, nm);
    if isnumeric(v) && ~isempty(v); sig.(nm{1}) = double(v); end
end
if ~isempty(fieldnames(sig)); value.significance = sig; end
fits = collectVariantFits(block);
if ~isempty(fits); value.model_fit = did2.build.list(fits{:}); end
imr = getf(block, {'is_modulated_response'});
if ~isempty(imr); dropped{end+1} = 'is_modulated_response'; end
end

function v = getf(s, names)
v = [];
if ~isstruct(s); return; end
fn = fieldnames(s);
for i = 1:numel(names)
    hit = find(strcmpi(fn, names{i}), 1);
    if ~isempty(hit); v = s.(fn{hit}); return; end
end
end

function fits = collectVariantFits(block)
fits = {};
variants = {'rb', 'rbn', 'rbns'};
metrics  = {'sensitivity', 'relative_max_gain', 'empirical_c50', 'saturation_index'};
for i = 1:numel(variants)
    v = variants{i};
    model = ['naka rushton ' upper(v)];
    entry = struct('model', jLabel(model));
    present = false;
    coeff = getf(block, {['parameters_' v]});
    if isnumeric(coeff) && ~isempty(coeff)
        c = {};
        for j = 1:size(coeff, 2)
            for k = 1:size(coeff, 1)
                c{end+1} = struct('variable', jLabel(sprintf( ...
                    '%s parameter %d, spatial frequency %d', model, k, j)), ...
                    'value', double(coeff(k, j))); %#ok<AGROW>
            end
        end
        entry.coefficients = did2.build.list(c{:});
        present = true;
    end
    for m = 1:numel(metrics)
        mv = getf(block, {[metrics{m} '_' v]});
        if isnumeric(mv) && ~isempty(mv)
            % v1 empirical_c50_<variant> -> c50 (Jess Haley 2026-10-22
            % [significance with results])
            entry.(strrep(metrics{m}, 'empirical_c50', 'c50')) = double(mv);
            present = true;
        end
    end
    if present
        fits{end+1} = entry; %#ok<AGROW>
    end
end
end
