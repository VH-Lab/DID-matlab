function f = fitEntry(model, options)
%FITENTRY One model fit: {model, coefficients, goodness, ...}.
%
%   F = did2.build.fitEntry(MODEL, 'Coefficients', C, ...) builds one entry of
%   a fit list -- by default `tuning_curve_calculation.model_fit`, an ARRAY of
%   these because one curve can carry several co-existing fits (tuning model
%   plan: a fit is an entry, not a class). MODEL is a term (or a name) naming
%   the fitted model; a bare bound term, not `model_name`.
%
%   The entry's fields are read from the target's schema, so 'Metrics' and
%   friends are accepted exactly where the target declares them.
%
%   Options:
%     'Coefficients'   an N x 2 cell {variable, value; ...} (variable a term or
%                      a name), or a struct array {variable, value}
%     'Goodness'       struct, e.g. struct('r2', 0.93, 'sse', 1.2)
%     'Metrics'        struct of the fit's derived metrics (tuning curves)
%     'SampledFit'     struct {independent_values, response}
%     'Fields'         any other field the target declares (a struct)
%     'Target'         'class.field' of the fit list; default
%                      'tuning_curve_calculation.model_fit'. Use
%                      'model_fit.value' for a standalone model_fit document,
%                      'contrast_sensitivity.<field>' etc. as declared.
%     'SchemaCache'    a did2.schema.cache; default the shared one.
%
%   Example:
%     f = did2.build.fitEntry('von Mises', ...
%         'Coefficients', {'amplitude', 12.1; 'preferred direction', 90}, ...
%         'Goodness', struct('r2', 0.91));
%
%   See also did2.build.list, did2.build.composite.

arguments
    model
    options.Coefficients = []
    options.Goodness = []
    options.Metrics = []
    options.SampledFit = []
    options.Fields (1,1) struct = struct()
    options.Target (1,:) char = 'tuning_curve_calculation.model_fit'
    options.SchemaCache = []
end

dot = find(options.Target == '.', 1);
if isempty(dot)
    error('did2:build:badTarget', '''Target'' is ''class.field'', got "%s".', options.Target);
end
className = options.Target(1:dot-1);
fieldPath = options.Target(dot+1:end);

s = options.Fields;
s.model = model;
coef = options.Coefficients;
if iscell(coef) && ~isempty(coef)
    if size(coef, 2) ~= 2
        error('did2:build:typeMismatch', '''Coefficients'' as a cell is N x 2: {variable, value}.');
    end
    coef = struct('variable', coef(:, 1)', 'value', coef(:, 2)');
end
if ~isempty(coef);               s.coefficients = coef;               end
if ~isempty(options.Goodness);   s.goodness = options.Goodness;       end
if ~isempty(options.Metrics);    s.metrics = options.Metrics;         end
if ~isempty(options.SampledFit); s.sampled_fit = options.SampledFit;  end
f = did2.build.composite(className, fieldPath, s, 'SchemaCache', options.SchemaCache);
end
