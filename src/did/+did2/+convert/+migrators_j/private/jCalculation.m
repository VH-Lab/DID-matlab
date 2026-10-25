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
%   VARIABLENAME the statement's variable (a label) when the source does
%               not say what was measured; METHODNAME the calculator, the
%               inline `method.term` (a label).
%
%   THE RESPONSE VARIABLE (tuning families and 'csf'; Jess Haley 2026-10-22
%   [response variable], [dF/F as variable], [response variable nodes],
%   did-schema V_eta_data_body_model_plan.md): `variable` names what the
%   response measured, read from v1 `response_units` by jTuningCurve /
%   jResponseVariable -- wikidata:Q71762818 "neural firing rate" for a
%   spikes-per-second spelling, EMPTY:0000397 "dF/F" for a dF/F spelling.
%   Where the source does not say (empty response_units, an unrecognised
%   spelling, and every contrast_sensitivity_calc, which carries no
%   response_units), `variable` is the general term EMPTY:0000398 "neural
%   response" (Jess Haley 2026-10-23 [unstated response variable]): not
%   empty, because `statement.variable` is mustBeNonEmpty and an all-blank
%   term is refused (did2:validation:vacuousField), and not the VARIABLENAME
%   calculator label, which is not what was measured. VARIABLENAME remains
%   the variable only for the receptive-field family, which reads no
%   response_units. Every folded document of
%   these families leaves ONE did2.convert.reportNote('tuning_response_variable',
%   <v1 class>, <id>, <outcome>): the count is the denominator, the DETAIL
%   'neural firing rate' | 'dF/F' | 'not stated' | 'unrecognised: <spelling>'.
%
%   What the calculation carries (did-schema #88):
%     entity_id          the element (v1 element_id; subject_id as fallback)
%     time_reference_id  the session anchor (jSessionAnchor)
%     input_id           the v1 input edges (stimulus_tuningcurve_id,
%                        stimulus_response_scalar_id, stimulus_response_id,
%                        contrasttuning_id_*), in order, then for 'csf' only
%                        stimulus_presentation_id (Jess Haley 2026-10-23
%                        [contrast sensitivity lossless]) -- `derived_from_1`
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
%   (and OPTS.Dropped). Until 2026-10-25 they were dropped with one
%   `field_dropped` note each. Since [generic stage is lossless] and [partly
%   placed is carried as v1] (Jess Haley, 2026-10-25) a document with any such
%   field is NOT folded: it is carried whole as v1 (returned unchanged), with
%   one did2.convert.reportNote('carried_as_v1', <v1 class>, <id>,
%   'unplaced: <field paths>'). A folded document drops nothing.
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
response = [];   % no response variable read (receptive field)
csfInputs = {};  % the contrast-sensitivity family's extra input (stimulus_presentation_id)
if strcmp(family, 'csf')
    [value, valueAxes, dropped] = jContrastSensitivityValue(srcBlk);
    % contrast_sensitivity_calc carries no response_units (NDIcalc-vis mock):
    % the source does not say what the response measured -> "neural response"
    [rv, ~, ro] = jResponseVariable([]);
    response = struct('variable', rv, 'outcome', ro);
    % the stimulus presentation the responses were measured against is an
    % input too (Jess Haley 2026-10-23 [contrast sensitivity lossless]):
    % after the responses, for the contrast-sensitivity family only
    sp = jDependency(preBody, 'stimulus_presentation_id');
    if ~isempty(sp); csfInputs = {sp}; end
elseif strcmp(family, 'rf')
    % receptive_field.value declares no sub-fields: the volume is in bodies
    value = struct();
    valueAxes = [];
else
    [value, valueAxes, leafFields, dropped, response] = jTuningCurve(srcBlk, family);
end
% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): a v1 field the value
% mapping has no home for (DROPPED, from jTuningCurve /
% jContrastSensitivityValue, or the caller's own OPTS.Dropped) is no longer
% dropped with a `field_dropped` note: the document is carried WHOLE as v1 for
% the dataset's map, with one `carried_as_v1` note naming every such field.
unplaced = [prefixed([sourceBlock '.'], reshape(dropped, 1, [])), ...
    cellfun(@char, reshape(opts.Dropped, 1, []), 'UniformOutput', false)];
if ~isempty(unplaced)
    did2.convert.reportNote('carried_as_v1', classNameOf(preBody), ...
        char(preBody.base.id), ['unplaced: ' strjoin(unplaced, ', ')]);
    bodies = {preBody};
    return;
end
variable = jLabel(variableName);
if isstruct(response) && isstruct(response.variable)
    variable = response.variable;   % [response variable]: what was measured
end

anchor = jSessionAnchor(preBody, 'during');
if isempty(swId)
    [software, swId] = jSoftware(methodName, '', '', jSid(preBody), jStamp(preBody));
end

inputs = [inputIds(preBody), csfInputs, reshape(opts.ExtraInputs, 1, [])];
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
    variable, value, ...
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

% (a field the value mapping had no home for carried the document as v1 above:
% a folded document dropped nothing)
className = classNameOf(preBody);
% the response variable: one note per folded document, the denominator
if isstruct(response)
    did2.convert.reportNote('tuning_response_variable', className, ...
        char(preBody.base.id), response.outcome);
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

function c = prefixed(p, names)
%PREFIXED Each name in NAMES with the prefix P.
c = cellfun(@(n) [p char(n)], names, 'UniformOutput', false);
end

function cn = classNameOf(preBody)
cn = '';
if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
    cn = char(preBody.document_class.class_name);
end
end
