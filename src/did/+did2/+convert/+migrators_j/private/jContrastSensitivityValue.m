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
%   interpolated_values {c50}, significance {visual_response_p_bonferroni,
%   response_varies_p_bonferroni, modulated_response}, response_type (a bound
%   term)}; AXES {dimensions, covariates}: one `spatial frequency` dimension
%   the per-SF arrays are indexed by, the frequencies a quantity covariate
%   along it (data_body AMENDMENT 6; one key before). v1 `is_modulated_response`
%   (0/1) -> significance.modulated_response (boolean; Jess Haley 2026-10-23
%   [contrast sensitivity lossless]); absent or empty writes nothing. DROPPED:
%   nothing, unless is_modulated_response is present but not a scalar 0/1.
%
%   ONE FIT PER SPATIAL FREQUENCY, NAMED BY SYMBOL (Decided by Jess Haley,
%   2026-11-11, did-schema docs/plans/did_v2_go_forward_class_audit.md [tuning
%   fit coefficients named by symbol], proposal 3): a Naka-Rushton variant's
%   v1 parameters are a parameters x SF matrix, column j the fit at spatial
%   frequency j. Each column is ONE model_fit entry: the model EMPTY:0000416
%   "Naka-Rushton function", `equation` its formula, the coefficients named by
%   symbol [Rm c50 n s] in stored order, and the variant's fixed values as
%   constraints (RB n = 1 and s = 1, RBN s = 1, RBNS none), as contrast_tuning
%   writes them (did2.convert.tuningFitModels). The variant's per-SF values
%   go on the fit of their spatial frequency: sensitivity column j (one value
%   per contrast), relative_max_gain, the half-maximum point and
%   saturation_index element j. The value model has no per-fit spatial
%   frequency field, so a fit's spatial frequency is its POSITION: the j-th
%   fit of a variant is the one at the j-th position of the value's one
%   spatial frequency dimension (whose covariate holds the frequencies). The
%   entries are written variant by variant (RB, RBN, RBNS), each in
%   spatial-frequency order. A variant array that cannot be split that way (a
%   parameters matrix whose columns are not one per spatial frequency, or more
%   than four rows; a per-SF value of another length) stays unplaced and
%   carries the document (carry-056). Until 2026-11-11 one entry per variant
%   held the whole matrix, its coefficients named '<model> parameter k,
%   spatial frequency j'.
%
%   THE HALF-MAXIMUM POINT: Decided by Jess Haley, 2026-11-10 [one spelling
%   for the half-maximum point] (did-schema did_v2_go_forward_class_audit.md):
%   `value.interpolated_values.c50` and `value.model_fit.c50` become
%   `half_maximum_below`, the spelling every other tuning class uses. DID-matlab
%   follows first, so the name written is the one the LOADED schema declares
%   (jSchemaHasPath): `half_maximum_below` once did-schema
%   renames the two fields, `c50` until then. halfMaximumName below.

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
% [response type harmonics are integers] (Decided by Jess Haley, 2026-11-12):
% `mean` is NCIT:C53319 Arithmetic Mean, `peak` STATO:0000151 (jResponseType)
if ischar(rt) && ~isempty(rt); value.response_type = jResponseType(rt); end
c50 = getf(block, {'fitless_interpolated_c50'});
if isnumeric(c50) && ~isempty(c50)
    value.interpolated_values = struct(halfMaximumName('interpolated_values'), double(c50));
end
sig = struct();
for nm = {'visual_response_p_bonferroni', 'response_varies_p_bonferroni'}
    v = getf(block, nm);
    if isnumeric(v) && ~isempty(v); sig.(nm{1}) = double(v); end
end
% v1 is_modulated_response (scalar 0/1) -> significance.modulated_response
% (boolean). Jess Haley 2026-10-23 [contrast sensitivity lossless]. Absent or
% empty writes NOTHING (the schema's blank is null, so missing never reads as
% false). A present value that is not a scalar 0/1 has no faithful boolean
% spelling, so it is still reported as dropped rather than coerced.
imr = getf(block, {'is_modulated_response'});
if ~isempty(imr)
    if (isnumeric(imr) || islogical(imr)) && isscalar(imr) && any(double(imr) == [0 1])
        sig.modulated_response = logical(imr);
    else
        dropped{end+1} = 'is_modulated_response';
    end
end
if ~isempty(fieldnames(sig)); value.significance = sig; end
[fits, dropFits] = collectVariantFits(block, sf);
dropped = [dropped, dropFits];
if ~isempty(fits); value.model_fit = did2.build.list(fits{:}); end
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

function name = halfMaximumName(block)
% the name the loaded schema declares for contrast_sensitivity.value.<BLOCK>'s
% half-maximum point ([one spelling for the half-maximum point]):
% `half_maximum_below` once did-schema renames it, else `c50`
name = 'c50';
if jSchemaHasPath('contrast_sensitivity', {'value', block, 'half_maximum_below'})
    name = 'half_maximum_below';
end
end

function [fits, dropped] = collectVariantFits(block, sf)
% one model_fit entry per variant and spatial frequency ([tuning fit
% coefficients named by symbol]); DROPPED names a variant field that cannot be
% split one value (or column) per spatial frequency
fits = {};
dropped = {};
fitC50 = halfMaximumName('model_fit');
variants = {'RB', 'RBN', 'RBNS'};
metrics  = {'sensitivity', 'relative_max_gain', 'empirical_c50', 'saturation_index'};
nSF = [];
if isnumeric(sf) && ~isempty(sf)
    nSF = numel(sf);
end
for i = 1:numel(variants)
    V = variants{i};
    row = did2.convert.tuningFitModels('contrast', ['naka_rushton_' V]);
    [coeff, coeffName] = getfn(block, {['parameters_' V]});
    if ~(isnumeric(coeff) && ~isempty(coeff))
        coeff = [];
        coeffName = '';
    end
    vals = cell(1, numel(metrics));
    valNames = cell(1, numel(metrics));
    for m = 1:numel(metrics)
        [mv, nm] = getfn(block, {[metrics{m} '_' V]});
        if isnumeric(mv) && ~isempty(mv)
            vals{m} = double(mv);
            valNames{m} = nm;
        end
    end
    if isempty(coeff) && all(cellfun(@isempty, vals))
        continue;
    end
    n = nSF;
    if isempty(n)
        if ~isempty(coeff)
            n = size(coeff, 2);
        else
            first = vals{find(~cellfun(@isempty, vals), 1)};
            n = numel(first);
            if ~isvector(first); n = size(first, 2); end
        end
    end
    [coeffCols, ok] = perFrequency(double(coeff), n);
    if ~isempty(coeff) && (~ok || any(cellfun(@numel, coeffCols) > numel(row.symbols)))
        dropped{end+1} = coeffName; %#ok<AGROW>
        continue;
    end
    pieces = cell(1, numel(metrics));
    bad = false;
    for m = 1:numel(metrics)
        if isempty(vals{m}); continue; end
        [pieces{m}, ok] = perFrequency(vals{m}, n);
        if ~ok
            dropped{end+1} = valNames{m}; %#ok<AGROW>
            bad = true;
        end
    end
    if bad
        continue;
    end
    for j = 1:n
        entry = struct('model', did2.convert.registeredTerm(row.node, row.name), ...
            'equation', row.equation);
        if ~isempty(coeff)
            p = coeffCols{j};
            c = cell(1, numel(p));
            for k = 1:numel(p)
                c{k} = struct('variable', struct('node', '', 'name', row.symbols{k}), ...
                    'value', double(p(k)));
            end
            entry.coefficients = did2.build.list(c{:});
        end
        if ~isempty(row.constraints)
            c = cell(1, size(row.constraints, 1));
            for k = 1:size(row.constraints, 1)
                c{k} = struct('variable', struct('node', '', 'name', row.constraints{k, 1}), ...
                    'value', row.constraints{k, 2});
            end
            entry.constraints = did2.build.list(c{:});
        end
        for m = 1:numel(metrics)
            if isempty(pieces{m}); continue; end
            % v1 empirical_c50_<variant> -> c50 (Jess Haley 2026-10-22
            % [significance with results]), half_maximum_below once the schema
            % declares it ([one spelling for the half-maximum point])
            entry.(strrep(metrics{m}, 'empirical_c50', fitC50)) = pieces{m}{j};
        end
        fits{end+1} = entry; %#ok<AGROW>
    end
end
end

function [pieces, ok] = perFrequency(x, n)
% X split one piece per spatial frequency: column j when X has N columns (a
% row vector, or a matrix such as sensitivity's contrasts x SF or the
% parameters x SF), element j when X is a column of N values. OK is false
% when X is neither (an empty X is OK with no pieces).
pieces = {};
ok = true;
if isempty(x)
    return;
end
if size(x, 2) == n && ismatrix(x)
    pieces = arrayfun(@(j) x(:, j), 1:n, 'UniformOutput', false);
elseif isvector(x) && numel(x) == n
    pieces = num2cell(x(:)');
else
    ok = false;
end
end

function [v, nm] = getfn(s, names)
% the first of NAMES S carries (any case), and its name as spelled
v = [];
nm = '';
if ~isstruct(s); return; end
fn = fieldnames(s);
for i = 1:numel(names)
    hit = find(strcmpi(fn, names{i}), 1);
    if ~isempty(hit); nm = fn{hit}; v = s.(nm); return; end
end
end
