function bodies = jCalculation(preBody, leafClass, family, sourceBlock, variableName, methodName, opts)
%JCALCULATION Fold a v1 calculator output 1 -> 1 (id preserved) into its
%   named did-schema #88 calculation.
%
%   BODIES = jCalculation(PREBODY, LEAFCLASS, FAMILY, SOURCEBLOCK,
%   VARIABLENAME, METHODNAME)
%
%   LEAFCLASS   the #88 class: every v1 calculator keeps a named class
%               (V_eta_entity_composition_plan.md sec. 1, Jess 2026-10-08):
%               tuning_curve_calculation, orientation_direction_tuning_calculation,
%               contrast_tuning_calculation, spatial_frequency_tuning_calculation,
%               temporal_frequency_tuning_calculation, speed_tuning_calculation,
%               contrast_sensitivity_calculation. Its own chain already holds
%               its value kind (tuning_curve / contrast_sensitivity), so it
%               takes no value-kind mixin.
%   FAMILY      'oridir' | 'contrast' | 'sf' | 'tf' | 'speed' | 'stimulus'
%               (the tuning value, jTuningCurve) or 'csf'
%               (jContrastSensitivityValue).
%   SOURCEBLOCK the v1 block holding the result.
%   VARIABLENAME the statement's variable (a label); METHODNAME the
%               calculator, the inline `method.term` (a label).
%
%   What the calculation carries (did-schema #88):
%     entity_id          the element (v1 element_id; subject_id as fallback)
%     time_reference_id  the session anchor (jSessionAnchor)
%     input_id           the v1 input edges (stimulus_tuningcurve_id,
%                        stimulus_response_scalar_id, contrasttuning_id_*,
%                        stimulus_response_id), in order -- `derived_from_1`
%                        (the first only) before
%     software_id        the calculator, from the v1 `app` block (or a
%                        software entity named METHODNAME when it has none)
%     operating_system_id / interpreter_id   from the same `app` block
%                        (jRunEntities; REQUIRED / optional)
%     method             {term: METHODNAME, parameters: v1 input_parameters}
%     value, dimensions, covariates   the result (jTuningCurve /
%                        jContrastSensitivityValue; `keys` until data_body
%                        AMENDMENT 6)
%     + the named class's own blocks (significance, model_fit[],
%       circular_statistics, interpolated_values)
%
%   V1 FIELDS WITH NO HOME are listed by jTuningCurve / jContrastSensitivityValue
%   and dropped; each one is REPORTED, never silently: one
%   did2.convert.reportNote('field_dropped', <v1 class>, <id>, <field path>)
%   per dropped field of a document that folds (a document that passes through
%   drops nothing, so it leaves no note). The report's
%   summary.migration_notes.field_dropped carries them.
%
%   Returns {leaf, anchor, software..., run entities...}.

arguments
    preBody (1,1) struct
    leafClass (1,:) char
    family (1,:) char
    sourceBlock (1,:) char
    variableName (1,:) char
    methodName (1,:) char
    opts.ExtraParameters = []    % more method.parameters entries (did2.build.list)
    opts.ExtraInputs = {}        % more input_id ids, after the standard ones
    opts.DataBody = []           % true: the value lives in bodies (receptive field)
    opts.DatumType = ''
    opts.SourceDatumType = ''
    opts.Dropped = {}            % more dropped v1 field paths, reported verbatim
end

srcBlk = struct();
if isfield(preBody, sourceBlock) && isstruct(preBody.(sourceBlock))
    srcBlk = preBody.(sourceBlock);
end
% did-schema #88: a calculation REQUIRES an entity (its subject). A source that
% names none cannot be stated as one, so it PASSES THROUGH on its v1 tombstone
% (Jess Haley, 2026-10-21: what #88 cannot express passes through, per class).
% Its operating_system_id is OPTIONAL (Jess Haley, 2026-10-21
% [calculation-os-optional], did-schema f8ab172): "required when the operating
% system is known, absent when the source never recorded it" -- so a missing
% OS no longer passes the document through; the edge is simply omitted.
subjectId = jSubjectOf(preBody, {'element_id', 'subject_id'});
[software, swId, execEnv] = jSoftwareFromApp(preBody);
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
if isempty(subjectId)
    bodies = {preBody};
    return;
end

leafFields = struct();
dropped = {};
if strcmp(family, 'csf')
    [value, valueAxes, dropped] = jContrastSensitivityValue(srcBlk);
elseif strcmp(family, 'rf')
    % receptive_field.value declares no sub-fields: the volume is in bodies
    value = struct();
    valueAxes = [];
else
    [value, valueAxes, leafFields, dropped] = jTuningCurve(srcBlk, family);
end

anchor = jSessionAnchor(preBody, 'during');
if isempty(swId)
    [software, swId] = jSoftware(methodName, '', '', jSid(preBody), jStamp(preBody));
end

inputs = [inputIds(preBody), reshape(opts.ExtraInputs, 1, [])];
f = leafFields;
params = jParameterList(calcInputParameters(preBody));
if ~isempty(opts.ExtraParameters)
    if isempty(params)
        params = opts.ExtraParameters;
    else
        params = did2.build.list(params, opts.ExtraParameters);
    end
end
f.method = jMethod(methodName, params);
if isempty(fieldnames(value)) && ~strcmp(family, 'rf')
    % did-schema #88: the result composite's `value` is REQUIRED (tuning_curve,
    % contrast_sensitivity). A calculator document with no curve has nothing to
    % state there, and inventing one is not allowed, so it passes through
    % unchanged rather than quarantining (Jess's rule; listed in the report).
    bodies = {preBody};
    return;
end
leaf = jStatement(preBody, leafClass, subjectId, ...
    jLabel(variableName), value, ...
    'Dimensions', axisPart(valueAxes, 'dimensions'), ...
    'Covariates', axisPart(valueAxes, 'covariates'), ...
    'DatumOrder', datumOrderOf(valueAxes), ...
    'TimeReferenceIds', {anchor.base.id}, ...
    'InputIds', inputs, ...
    'SoftwareId', swId, ...
    'OperatingSystemId', osId, ...
    'InterpreterId', interpreterId, ...
    'Fields', f, ...
    'DataBody', opts.DataBody, 'DatumType', opts.DatumType, ...
    'SourceDatumType', opts.SourceDatumType, ...
    'Id', char(preBody.base.id));   % id preserved -> inbound references resolve

bodies = [{leaf, anchor}, software, runDocs];

% the v1 fields the value mapping had no home for: reported, one note each
className = '';
if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
    className = char(preBody.document_class.class_name);
end
for k = 1:numel(dropped)
    did2.convert.reportNote('field_dropped', className, ...
        char(preBody.base.id), [sourceBlock '.' dropped{k}]);
end
for k = 1:numel(opts.Dropped)   % the caller's own drops, full paths
    did2.convert.reportNote('field_dropped', className, ...
        char(preBody.base.id), char(opts.Dropped{k}));
end
end

function ids = inputIds(preBody)
ids = {};
names = {'stimulus_tuningcurve_id', 'stimulus_response_scalar_id', 'stimulus_response_id'};
for k = 1:numel(names)
    v = jDependency(preBody, names{k});
    if ~isempty(v); ids{end+1} = v; end %#ok<AGROW>
end
for k = 1:64
    v = jDependency(preBody, sprintf('contrasttuning_id_%d', k));
    if isempty(v); break; end
    ids{end+1} = v; %#ok<AGROW>
end
end

function p = calcInputParameters(preBody)
p = struct();
fns = fieldnames(preBody);
for i = 1:numel(fns)
    b = preBody.(fns{i});
    if isstruct(b) && isscalar(b) && isfield(b, 'input_parameters') ...
            && isstruct(b.input_parameters) && isscalar(b.input_parameters)
        p = b.input_parameters; return;
    end
end
if isfield(preBody, 'input_parameters') && isstruct(preBody.input_parameters)
    p = preBody.input_parameters;
end
end

function v = axisPart(valueAxes, name)
%AXISPART AXES.(NAME), or [] when the result has no dimension.
v = [];
if isstruct(valueAxes) && isfield(valueAxes, name)
    v = valueAxes.(name);
end
end

function o = datumOrderOf(valueAxes)
%DATUMORDEROF The order of a multi-dimension value's arrays ('F' for a tuning
%   grid, jTuningCurve [tuning grid]); '' (the schema's "empty means F", one
%   dimension or none) otherwise.
o = '';
if isstruct(valueAxes) && isfield(valueAxes, 'datum_order')
    o = char(valueAxes.datum_order);
end
end
