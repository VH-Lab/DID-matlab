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
%     method             {term: METHODNAME, parameters: v1 input_parameters};
%                        the fitted families' and 'csf' term is OBI:0200072
%                        ([method terms are general], Jess Haley, 2026-10-26)
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
%   ACCOUNTED FOR ('AccountForEveryField', true; the migrators switched to raw
%   v1, did2.convert.rawV1Classes, [migrators read raw v1]): the fields the
%   value mapping does not read are checked too, so that a folded document
%   drops nothing ([generic stage is lossless], Jess Haley, 2026-10-25). Each
%   of these, when it holds a value, is unplaced and carries the document whole
%   as v1 (carry-100 outside the class's NDI template, carry-056 inside it:
%   UNPLACED, BY THE TEMPLATE, below):
%     - a top-level block other than document_class, depends_on, base, app,
%       calculator, the calculator's own block, SOURCEBLOCK and OPTS.OtherBlocks
%       (blocks whose fields the caller accounts for itself: hartley_calc's
%       files, hartley_reverse_correlation, ngrid, reverse_correlation);
%     - a field of the calculator's own block other than input_parameters and
%       depends_on (tuningcurve_calc's `log` and `stim_property_list`); for
%       'csf' (the block IS the result), a field jContrastSensitivityValue
%       does not read;
%     - a field of the `calculator` block (NDI's calculator.json declares none);
%     - an `app` field outside NDI's app.json, or `name` / `version` stated in
%       both spellings with different values (did2.convert.v1read.readApp);
%     - a depends_on edge the calculation does not write: one outside the
%       subject edge and the input edges inputIds reads (and, for 'csf',
%       stimulus_presentation_id), or a `subject_id` beside an `element_id`.
%   Off by default: the classes not yet switched run exactly as before.
%
%   UNPLACED, BY THE TEMPLATE (Decided by Jess Haley, 2026-10-27 [tuning stray
%   fields are malformed]; did2.convert.v1read.calculatorTemplate). Each
%   unplaced field is cited by what the class's NDI template (with its
%   writer's additions) says of it:
%     carry-100  outside the template: a top-level block it does not declare,
%                any `calculator` field, an `app` field outside app.json (or
%                the `app_name` / `app_version` spelling beside a differing
%                `name` / `version`), a depends_on edge it does not name, a
%                field of a declared block it does not declare (a field of a
%                declared block that is itself a struct is walked: each
%                non-empty leaf outside the template is cited on its own);
%     carry-056  inside the template: a field the writer writes that the fold
%                has no home for (contrast fits' relative_max_gain, the SF /
%                TF `abs` block, stimulus_tuningcurve.stimid, a recognised
%                response_units spelling, tuningcurve_calc.log, ...).
%   Field names are compared case-insensitively (the fold lower-cases fit
%   field names). The note is jRawCarry's, as for every other family.
%
%   THE 2026-10-27 TUNING DECISIONS (Jess Haley, did-schema
%   V_eta_go_forward_class_audit.md), built here for the tuning families:
%     [tuning fits use curve fitting now]  a fitted family's ('oridir',
%         'contrast', 'sf', 'tf', 'speed') `method.term` is OBI:0200072
%         "curve fitting data transformation" (building [method terms are
%         general]). METHODNAME stays the calculator: the `software`
%         entity. (Until 2026-10-29 the fitted function was also the method
%         parameter {variable 'function', text <model>} when all fits were
%         of one model; see [fit model stated once] below.)
%     [one calculation per named calculator output] (2026-10-28; amends the
%         decision above): one v1 calculator output is ONE calculation, its
%         fits entries of value.model_fit, each naming its own model; the
%         method holds no `function` list, so fits of several models (the SF /
%         TF writers' five) write no `function` parameter.
%     [fit model stated once] (Jess Haley, 2026-10-29, did-schema
%         V_eta_go_forward_class_audit.md): a calculation whose fits share
%         one model writes no {function: <model>} method parameter either;
%         the model is stated in each fit entry (value.model_fit{k}.model),
%         and the round trip rebuilds v1 from those entries (fitBlocks). The
%         method keeps its term OBI:0200072 and its other parameters.
%     [absolute-value fits are a second calculation]  an SF / TF `abs` block
%         is a SECOND calculation of LEAFCLASS (its id minted, role
%         'absolute value calculation'), the same subject, anchor, inputs and
%         software, its value the abs fits, with the method parameter
%         {variable 'response transform', text 'absolute value'}.
%         SUPERSEDED 2026-10-28 by [absolute-value fits are fit entries]
%         (`model_fit` entries with `response_transform`), which is NOT YET
%         BUILT here: that decision asked for what the `abs` block holds
%         beyond the fits to be brought back first, and it holds `fitless`
%         too (the interpolated values of |response|; NDIcalc-vis-matlab
%         00e3e0f spatial_frequency_tuning.m / temporal_frequency_tuning.m
%         write abs.fitless beside the five abs fits), which a fit entry
%         cannot hold. Until the team answers, the second calculation stays.
%     [interpolated values are a list] (Jess Haley, 2026-10-30; answers G5)
%         `interpolated_values` is a list of entries with an optional
%         `response_transform`; v1 `abs.fitless` is the 'absolute value'
%         entry on the MAIN calculation. Written as a list only once the
%         loaded schema declares `response_transform` on the field
%         (siblings first); until then the one structure, as before, with
%         `abs.fitless` on the absolute-value calculation.
%     [parameter names map by table]  the tuning families' v1 settings
%         (input_parameters) are named through did2.convert.tuningNames; a
%         setting the table does not hold carries the document (carry-056).
%     [tuning log in notes]  tuningcurve_calc's `log`, verbatim, is the
%         statement's `notes`.
%     [tuning best value is a condition] (2026-10-28)  each `best` selection
%         of tuningcurve_calc's input_parameters.selection: the value it chose,
%         read once from the log (did2.convert.tuningBestValues), is a
%         condition named by the V2 stimulus variable (e.g. orientation = 90),
%         after the stim_property_list conditions, and the rule is the method
%         parameter {'<V2 name> selection', text 'best'} after the v1
%         settings; the stimid rebuild reads these conditions too. A curve
%         whose log does not state the value (or names a property the table
%         does not hold) is carried (carry-056).
%     [varied properties are conditions by V2 name]  each property in
%         tuningcurve_calc's `stim_property_list` is a condition, its variable
%         the V2 stimulus method's (did2.convert.tuningNames), its value the
%         v1 value; a name the table does not hold carries the curve
%         (carry-056).
%     [tuning stimids rebuild]  a raw curve's `stimid` and
%         `stimulus_presentation_number` are not written: when
%         did2.convert.tuningStimids rebuilds them exactly from the batch's
%         presentation and response and the curve's conditions, they are
%         placed; otherwise the curve is carried (carry-056). Every curve
%         leaves one did2.convert.reportNote('tuning_stimid_rebuild', ...):
%         'rebuilt exactly', 'not rebuilt' or 'none stated' (the count).
%     [input names rebuild from the input class]  the input edges' v1 names
%         must be what did2.convert.inputEdgeNames rebuilds from the classes
%         of the documents they point at (two inputs of one class under
%         different names cannot be); a document whose names are not is
%         carried, kind malformed (carry-100).
%
%   Returns {leaf, anchor, software..., run entities...} ({leaf, abs leaf,
%   anchor, ...} when an `abs` block was folded).

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
    opts.AccountForEveryField (1,1) logical = false   % see ACCOUNTED FOR below
    opts.OtherBlocks = {}        % more top-level blocks the CALLER accounts for
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
tuningExtra = struct('abs', struct('present', false));
isFit = any(strcmp(family, {'oridir', 'contrast', 'sf', 'tf', 'speed'}));
% (the contrast-sensitivity calculator writes no settings, NDIcalc-vis-matlab
% 00e3e0f contrast_sensitivity.m: input_parameters struct([]); it is not a
% tuning curve and keeps its settings' names as before)
useTable = isFit || strcmp(family, 'stimulus');
% the raw curve's notes, conditions and rebuilt stimids (family 'stimulus')
curve = struct('rebuilt', {{}}, 'notes', '', 'conditions', [], 'reasons', {{}}, ...
    'outcome', '', 'parameters', []);
if strcmp(family, 'stimulus')
    curve = curveContext(preBody, sourceBlock, srcBlk);
end
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
    [value, valueAxes, leafFields, dropped, response, tuningExtra] = ...
        jTuningCurve(srcBlk, family, 'Rebuilt', curve.rebuilt);
end
% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): a v1 field the value
% mapping has no home for (DROPPED, from jTuningCurve /
% jContrastSensitivityValue, or the caller's own OPTS.Dropped) is no longer
% dropped with a `field_dropped` note: the document is carried WHOLE as v1 for
% the dataset's map, with one `carried_as_v1` note naming every such field.
% (rawCurve already names its paths from the block, 'stimulus_tuningcurve.x':
% those are not prefixed a second time)
% Each such field cites ONE carry register row, by what the class's NDI
% template says of it (Decided by Jess Haley, 2026-10-27 [tuning stray fields
% are malformed], did-schema V_eta_go_forward_class_audit.md;
% did2.convert.v1read.calculatorTemplate):
%   - a field, block or edge the template (or its writer) does not define:
%     carry-100 ([fields outside the template are malformed]), through
%     jRawCarry exactly as the other families cite it;
%   - a field the template defines, which the writer writes, that the fold has
%     no home for: carry-056 ([lossless first, homes after]).
unplaced = [cellfun(@(d) underBlock(sourceBlock, d), reshape(dropped, 1, []), ...
    'UniformOutput', false), cellfun(@char, reshape(opts.Dropped, 1, []), ...
    'UniformOutput', false)];
if opts.AccountForEveryField
    unplaced = [unplaced, unaccounted(preBody, sourceBlock, family, opts.OtherBlocks)];
end
[outside, inside] = splitByTemplate(preBody, unplaced);
reasons = cellfun(@(x) ['[carry-056] ' x], inside, 'UniformOutput', false);
reasons = [reasons, curve.reasons];
% [parameter names map by table] (Jess Haley, 2026-10-27): the tuning
% families' settings are named through did2.convert.tuningNames
if useTable
    [params, unknownSettings] = jParameterList(calcInputParameters(preBody), '', ...
        @(n) did2.convert.tuningNames('v2', n));
    for k = 1:numel(unknownSettings)
        reasons{end+1} = sprintf(['[carry-056] input_parameters.%s (no V2 name in ' ...
            'the table: [parameter names map by table])'], unknownSettings{k}); %#ok<AGROW>
    end
else
    params = jParameterList(calcInputParameters(preBody));
end
% [tuning best value is a condition] (Jess Haley, 2026-10-28): the rule of each
% `best` selection, after the v1 settings
if ~isempty(curve.parameters)
    if isempty(params)
        params = curve.parameters;
    else
        params = did2.build.list(params, curve.parameters);
    end
end
% [input names rebuild from the input class] (Jess Haley, 2026-10-27)
reasons = [reasons, inputNameReasons(preBody, family)];
% a held-fixed property that is also a varied variable cannot be both a
% condition and a covariate (did2.build.statement refuses it)
if ~isempty(curve.conditions)
    clash = intersect(lower(variableNames(curve.conditions)), ...
        lower(variableNames(axisPart(valueAxes, 'covariates'))));
    if ~isempty(clash)
        reasons{end+1} = sprintf(['[carry-056] %s.stim_property_list (%s is also ' ...
            'a varied variable)'], classNameOf(preBody), strjoin(clash, ', '));
    end
end
% [absolute-value fits are a second calculation]: abs fitless values with no
% fit have no value to state
% (once the loaded schema declares `interpolated_values` a list, they are its
% 'absolute value' entry: [interpolated values are a list], below)
if isFit && tuningExtra.abs.present && isempty(fieldnames(tuningExtra.abs.value)) ...
        && ~isempty(fieldnames(tuningExtra.abs.leafFields)) ...
        && ~jSchemaHasPath(leafClass, {'interpolated_values', 'response_transform'})
    reasons{end+1} = sprintf('[carry-056] %s.abs (fitless values with no fit)', sourceBlock);
end
% The calculator block's inner `depends_on` copy (e.g.
% `oridirtuning_calc.depends_on`) is left unwritten only when it restates the
% top-level edges ([restated values checked], Jess Haley, 2026-10-26; measured
% equal on every held document). One that differs is carried whole as v1.
differing = innerDependsOnDiffers(preBody, classNameOf(preBody));
if ~isempty(differing)
    reasons{end+1} = sprintf('[carry-016] %s.depends_on (%s differs from the top-level edge)', ...
        classNameOf(preBody), strjoin(differing, ', '));
end
% [tuning stimids rebuild]: the count over all curves, one note per curve
if strcmp(family, 'stimulus')
    did2.convert.reportNote('tuning_stimid_rebuild', classNameOf(preBody), ...
        char(preBody.base.id), curve.outcome);
end
% One `carried_as_v1` note (jRawCarry): '[carry-100] malformed: outside the NDI
% template, unplaced: <paths>' first when there are any, then 'unplaced:
% [carry-056] <path>, [carry-016] <path>' (each reason tagged with its row).
if jRawCarry(classNameOf(preBody), preBody, {}, outside, 'carry-100', reasons)
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
if ~isempty(opts.ExtraParameters)
    if isempty(params)
        params = opts.ExtraParameters;
    else
        params = did2.build.list(params, opts.ExtraParameters);
    end
end
if isFit
    % [tuning fits use curve fitting now] (Jess Haley, 2026-10-27)
    f.method = fitMethod(value, params, {});
elseif strcmp(family, 'csf')
    % [method terms are general] (Jess Haley, 2026-10-26, did-schema
    % V_eta_go_forward_class_audit.md): the method term names the general
    % procedure, not the calculator class. A contrast sensitivity result is
    % Naka-Rushton fits (jContrastSensitivityValue: one model_fit entry per
    % RB / RBN / RBNS variant), so its term is OBI:0200072 "curve fitting
    % data transformation"; the calculator (METHODNAME) is the `software`
    % entity on software_id. The parameters are the v1 settings, as before.
    f.method = jMethod(did2.convert.registeredTerm('OBI:0200072', ...
        'curve fitting data transformation'), params);
else
    % [data analysis is the general method] (Decided by Jess Haley, 2026-10-30,
    % did-schema V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G29): a
    % calculation that is not a fit (a tuning curve with no fit, hartley_calc)
    % takes EDAM:operation_2945 "Data analysis", per [method terms are
    % general]; the calculator (METHODNAME) stays the `software` entity on
    % software_id. The parameters are the v1 settings, as before.
    f.method = jMethod(DATA_ANALYSIS(), params);
end
% [interpolated values are a list] (Decided by Jess Haley, 2026-10-30, did-schema
% V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G5): a tuning calculation's
% `interpolated_values` becomes a list of entries, each with the optional
% `response_transform`, and the v1 `abs.fitless` (the values read off
% |response|) its second entry, 'absolute value'. Siblings first: did-schema
% still declares ONE structure, so the list is written only once the loaded
% schema declares `response_transform` on the field (jSchemaHasPath); until
% then the structure is written as before and `abs.fitless` stays on the
% absolute-value calculation ([absolute-value fits are a second calculation]).
absIvOnList = false;
absLeafFields = struct();
if tuningExtra.abs.present && isfield(tuningExtra.abs, 'leafFields')
    absLeafFields = tuningExtra.abs.leafFields;
end
hasMain = isfield(f, 'interpolated_values') && ~isempty(f.interpolated_values);
hasAbs = isfield(absLeafFields, 'interpolated_values') ...
    && ~isempty(absLeafFields.interpolated_values);
if (hasMain || hasAbs) ...
        && jSchemaHasPath(leafClass, {'interpolated_values', 'response_transform'})
    entries = {};
    if hasMain
        entries{end+1} = f.interpolated_values;
    end
    if hasAbs
        e = absLeafFields.interpolated_values;
        e.response_transform = 'absolute value';
        entries{end+1} = e;
        absIvOnList = true;
    end
    f.interpolated_values = did2.build.list(entries{:});
end
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
    'Conditions', curve.conditions, ...
    'Notes', curve.notes, ...
    'Id', char(preBody.base.id));   % id preserved -> inbound references resolve

leaves = {leaf};
if isFit && tuningExtra.abs.present && ~isempty(fieldnames(tuningExtra.abs.value))
    % [absolute-value fits are a second calculation] (Jess Haley, 2026-10-27):
    % the `abs` block is a second calculation of the same class, its method
    % saying the response was transformed to its absolute value
    fa = tuningExtra.abs.leafFields;
    if absIvOnList && isfield(fa, 'interpolated_values')
        % on the main calculation's list ([interpolated values are a list])
        fa = rmfield(fa, 'interpolated_values');
    end
    fa.method = fitMethod(tuningExtra.abs.value, params, ...
        {did2.build.parameter(jLabel('response transform'), 'Text', 'absolute value')});
    leaves{end+1} = jStatement(preBody, leafClass, subjectId, ...
        variable, tuningExtra.abs.value, ...
        'TimeReferenceIds', {anchor.base.id}, ...
        'InputIds', inputs, ...
        'SoftwareId', swId, ...
        'OperatingSystemId', osId, ...
        'InterpreterId', interpreterId, ...
        'Fields', fa, ...
        'Id', did2.convert.mintId('absolute value calculation'));
end

bodies = [leaves, {anchor}, software, runDocs];

% (a field the value mapping had no home for carried the document as v1 above:
% a folded document dropped nothing)
className = classNameOf(preBody);
% the response variable: one note per folded document, the denominator
if isstruct(response)
    did2.convert.reportNote('tuning_response_variable', className, ...
        char(preBody.base.id), response.outcome);
end
end

function c = unaccounted(preBody, sourceBlock, family, otherBlocks)
%UNACCOUNTED The fields of PREBODY the fold does not read and that hold a
%   value, each as a path (see ACCOUNTED FOR in the header); splitByTemplate
%   gives each its carry register row.
c = {};
leaf = classNameOf(preBody);
known = [{'document_class', 'depends_on', 'base', 'app', 'calculator', leaf, sourceBlock}, ...
    reshape(cellstr(otherBlocks), 1, [])];
top = fieldnames(preBody);
for k = 1:numel(top)
    if ~any(strcmp(top{k}, known)) && ~isEmptyValue(preBody.(top{k}))
        c{end+1} = top{k}; %#ok<AGROW>
    end
end
if strcmp(family, 'csf')
    read = {'input_parameters', 'depends_on', 'spatial_frequencies', ...
        'fitless_interpolated_c50', 'is_modulated_response', ...
        'visual_response_p_bonferroni', 'response_varies_p_bonferroni', 'response_type'};
    for v = {'rb', 'rbn', 'rbns'}
        for m = {'sensitivity', 'relative_max_gain', 'empirical_c50', 'saturation_index', 'parameters'}
            read{end+1} = [m{1} '_' v{1}]; %#ok<AGROW>
        end
    end
    c = [c, blockRest(preBody, leaf, read, true)];
elseif ~strcmp(leaf, sourceBlock) || strcmp(family, 'rf')
    % (receptive field: the calculator's own block is also its source block,
    % and holds only input_parameters and depends_on)
    read = {'input_parameters', 'depends_on'};
    if strcmp(family, 'stimulus')
        % [tuning log in notes], [varied properties are conditions by V2 name]
        % (Jess Haley, 2026-10-27): read by curveContext
        read = [read, {'log', 'stim_property_list'}];
    end
    c = [c, blockRest(preBody, leaf, read, false)];
end
c = [c, blockRest(preBody, 'calculator', {}, false)];
a = did2.convert.v1read.readApp(preBody);
for k = 1:numel(a.conflicts)
    c{end+1} = sprintf('app.%s (app_%s differs)', a.conflicts{k}, a.conflicts{k}); %#ok<AGROW>
end
ex = fieldnames(a.extra);
for k = 1:numel(ex)
    if ~isEmptyValue(a.extra.(ex{k}))
        c{end+1} = ['app.' ex{k}]; %#ok<AGROW>
    end
end
inputs = {'element_id', 'stimulus_tuningcurve_id', 'stimulus_response_scalar_id', ...
    'stimulus_response_id'};
if any(strcmp(family, {'csf', 'rf'}))
    % (the receptive field writes it through OPTS.ExtraInputs: hartley_calc)
    inputs{end+1} = 'stimulus_presentation_id';
end
% the contrast tuning inputs inputIds reads: contrasttuning_id_1, _2, ... up
% to the first one missing
for k = 1:64
    if isempty(jDependency(preBody, sprintf('contrasttuning_id_%d', k)))
        break;
    end
    inputs{end+1} = sprintf('contrasttuning_id_%d', k); %#ok<AGROW>
end
deps = did2.convert.v1read.readDependsOn(preBody);
for k = 1:numel(deps)
    nm = deps(k).name;
    if isempty(deps(k).document_id) || any(strcmp(nm, inputs))
        continue;
    end
    if strcmp(nm, 'subject_id') && isempty(jDependency(preBody, 'element_id'))
        continue;   % the subject when there is no element (jSubjectOf)
    end
    c{end+1} = ['depends_on ' nm]; %#ok<AGROW>
end
end

function c = blockRest(preBody, block, read, ignoreCase)
%BLOCKREST The fields of PREBODY.(BLOCK) outside READ that hold a value, as
%   'BLOCK.field'.
c = {};
if ~isfield(preBody, block) || ~isstruct(preBody.(block)) || ~isscalar(preBody.(block))
    return;
end
b = preBody.(block);
fns = fieldnames(b);
for k = 1:numel(fns)
    if ignoreCase
        isRead = any(strcmpi(fns{k}, read));
    else
        isRead = any(strcmp(fns{k}, read));
    end
    if ~isRead && ~isEmptyValue(b.(fns{k}))
        c{end+1} = [block '.' fns{k}]; %#ok<AGROW>
    end
end
end

function tf = isEmptyValue(v)
%ISEMPTYVALUE A value that states nothing: '', [], {}, an empty string, or a
%   struct that is empty or has only empty fields (NDI's template blanks,
%   e.g. stim_property_list {names: [], values: []}).
if isstruct(v)
    tf = true;
    for k = 1:numel(v)
        fns = fieldnames(v(k));
        for j = 1:numel(fns)
            if ~isEmptyValue(v(k).(fns{j}))
                tf = false;
                return;
            end
        end
    end
elseif isstring(v)
    tf = isempty(v) || all(strlength(v) == 0);
else
    tf = isempty(v);
end
end

function m = fitMethod(~, params, more)
%FITMETHOD The method of a tuning fit calculation ([tuning fits use curve
%   fitting now], Jess Haley, 2026-10-27): term OBI:0200072 "curve fitting
%   data transformation"; parameters: MORE (a cell of entries), then the v1
%   settings PARAMS. No `function` parameter is written: fits of several
%   models write none (Decided by Jess Haley, 2026-10-28 [one calculation
%   per named calculator output]: "the method holds no `function` list"),
%   and fits that share one model write none either ([fit model stated
%   once] (Jess Haley, 2026-10-29, did-schema
%   V_eta_go_forward_class_audit.md): the model is stated once, in each
%   fit's model_fit entry, which is what a query reads). The first input
%   (the fits' value) is unused since then; it is kept so the two call sites
%   stay as they were.
entries = reshape(more, 1, []);
if ~isempty(params)
    entries{end+1} = params;
end
p = [];
if ~isempty(entries)
    p = did2.build.list(entries{:});
end
m = jMethod(did2.convert.registeredTerm('OBI:0200072', ...
    'curve fitting data transformation'), p);
end

function reasons = inputNameReasons(preBody, family)
%INPUTNAMEREASONS [input names rebuild from the input class] (Jess Haley,
%   2026-10-27): the v1 names of the input edges must be what
%   did2.convert.inputEdgeNames rebuilds from the classes of the documents
%   they point at (DEFAULTS: the writer's name when the class is not in the
%   batch). A document whose names are not is carried, kind malformed
%   (carry-100). The contrast-sensitivity and receptive-field families name
%   their inputs by their writers' fixed layout (tuningInverse 'csf',
%   hartley_calc) and are not checked here.
reasons = {};
switch family
    case 'stimulus'
        defaults = {'stimulus_response_scalar_id'};
    case {'oridir', 'contrast', 'sf', 'tf', 'speed'}
        defaults = {'stimulus_tuningcurve_id'};
    otherwise
        return;
end
[names, ids] = inputEdges(preBody);
if isempty(ids)
    return;
end
rebuilt = did2.convert.inputEdgeNames(ids, defaults);
if ~isequal(names, rebuilt)
    reasons{end+1} = sprintf(['[carry-100] malformed: input edges %s do not rebuild ' ...
        'from the classes they point at (as %s): [input names rebuild from the ' ...
        'input class]'], strjoin(names, ', '), strjoin(rebuilt, ', '));
end
end

function c = variableNames(entries)
%VARIABLENAMES The variable names of a list of entries (conditions,
%   covariates).
c = {};
if isempty(entries); return; end
if isstruct(entries); entries = num2cell(reshape(entries, 1, [])); end
for k = 1:numel(entries)
    e = entries{k};
    if isstruct(e) && isfield(e, 'variable') && isstruct(e.variable) ...
            && isfield(e.variable, 'name')
        c{end+1} = char(e.variable.name); %#ok<AGROW>
    end
end
end

function [names, ids] = inputEdges(preBody)
%INPUTEDGES The input edges inputIds reads, with their v1 names, in its order.
names = {};
ids = {};
for nm = {'stimulus_tuningcurve_id', 'stimulus_response_scalar_id', 'stimulus_response_id'}
    v = jDependency(preBody, nm{1});
    if ~isempty(v)
        names{end+1} = nm{1}; %#ok<AGROW>
        ids{end+1} = v; %#ok<AGROW>
    end
end
for k = 1:64
    nm = sprintf('contrasttuning_id_%d', k);
    v = jDependency(preBody, nm);
    if isempty(v); break; end
    names{end+1} = nm; %#ok<AGROW>
    ids{end+1} = v; %#ok<AGROW>
end
end

function curve = curveContext(preBody, sourceBlock, srcBlk)
%CURVECONTEXT A raw tuning curve's notes, conditions and rebuilt stimids
%   (family 'stimulus'; Jess Haley, 2026-10-27: [tuning log in notes],
%   [varied properties are conditions by V2 name], [tuning stimids rebuild]).
%   CURVE.reasons are tagged carry reasons; CURVE.rebuilt the raw-curve fields
%   placed by the rebuild; CURVE.outcome the tuning_stimid_rebuild note.
%   CURVE.parameters are the method parameters of its `best` selections
%   ([tuning best value is a condition], Jess Haley, 2026-10-28).
curve = struct('rebuilt', {{}}, 'notes', '', 'conditions', [], 'reasons', {{}}, ...
    'outcome', 'none stated', 'parameters', []);
cls = classNameOf(preBody);
own = struct();
if ~strcmp(cls, sourceBlock) && isfield(preBody, cls) && isstruct(preBody.(cls)) ...
        && isscalar(preBody.(cls))
    own = preBody.(cls);
end
% the log, verbatim
if isfield(own, 'log') && ~isEmptyValue(own.log)
    lg = own.log;
    if isstring(lg) && isscalar(lg); lg = char(lg); end
    if ischar(lg) && (isrow(lg) || isempty(lg))
        curve.notes = lg;
    else
        curve.reasons{end+1} = sprintf('[carry-056] %s.log (not one text)', cls);
    end
end
% the held-fixed properties, as conditions by their V2 names
condNames = {};
condValues = [];
conds = {};
if isfield(own, 'stim_property_list') && ~isEmptyValue(own.stim_property_list)
    [condNames, condValues, why] = propertyList(own.stim_property_list);
    for k = 1:numel(condNames)
        [v2, found] = did2.convert.tuningNames('v2', condNames{k});
        if ~found
            why = sprintf('no V2 name in the table for "%s": [varied properties are conditions by V2 name]', ...
                condNames{k});
            break;
        end
        conds{end+1} = did2.build.condition(jLabel(v2), 'Value', condValues(k)); %#ok<AGROW>
    end
    if ~isempty(why)
        curve.reasons{end+1} = sprintf('[carry-056] %s.stim_property_list (%s)', cls, why);
        condNames = {};
        condValues = [];
        conds = {};
    end
end
% [tuning best value is a condition] (Jess Haley, 2026-10-28): the value each
% `best` selection chose, read once from the log, is a condition too, and the
% rule is the method parameter '<V2 name> selection' = 'best'; a curve whose
% log does not state it is carried (carry-056)
ip = struct();
if isfield(own, 'input_parameters') && isstruct(own.input_parameters) ...
        && isscalar(own.input_parameters)
    ip = own.input_parameters;
end
[bestNames, bestValues, why] = did2.convert.tuningBestValues(ip, fieldOr(own, 'log'));
if ~isempty(bestNames)
    rules = {};
    bestConds = {};
    for k = 1:numel(bestNames)
        if ~isempty(why); break; end
        [v2, found] = did2.convert.tuningNames('v2', bestNames{k});
        if ~found
            why = sprintf('no V2 name in the table for "%s"', bestNames{k});
        elseif any(strcmp(bestNames{k}, condNames))
            why = sprintf('"%s" is both a best selection and in stim_property_list', bestNames{k});
        else
            bestConds{end+1} = did2.build.condition(jLabel(v2), 'Value', bestValues(k)); %#ok<AGROW>
            rules{end+1} = did2.build.parameter(jLabel([v2 ' selection']), 'Text', 'best'); %#ok<AGROW>
        end
    end
    if ~isempty(why)
        curve.reasons{end+1} = sprintf(['[carry-056] %s.log (%s: [tuning best value is ' ...
            'a condition])'], cls, why);
    else
        conds = [conds, bestConds];
        condNames = [condNames, bestNames];
        condValues = [condValues, bestValues];
        curve.parameters = did2.build.list(rules{:});
    end
end
if ~isempty(conds)
    curve.conditions = did2.build.list(conds{:});
end
% the stimids, rebuilt from the presentation and the conditions
v1Stimid = fieldOr(srcBlk, 'stimid');
v1Spn = fieldOr(srcBlk, 'stimulus_presentation_number');
stated = ~isEmptyValue(v1Stimid) || ~isEmptyValue(v1Spn);
params = independentParameters(own, srcBlk);
[rs, rspn, why] = did2.convert.tuningStimids(fieldOr(srcBlk, 'independent_variable_value'), ...
    params, condNames, condValues, jDependency(preBody, 'stimulus_response_scalar_id'));
ran = isempty(why);
if ran && ~(isequaln(rs, normalised(v1Stimid)) && isequaln(rspn, normalised(v1Spn)))
    % (a curve stating none whose presentation gives some is carried too: its
    % round trip would write what v1 did not state)
    why = 'the presentation and the response give other values';
end
if isempty(why)
    if stated
        curve.rebuilt = {'stimid', 'stimulus_presentation_number'};
        curve.outcome = 'rebuilt exactly';
    end
elseif stated || ran
    curve.outcome = 'not rebuilt';
    curve.reasons{end+1} = sprintf(['[carry-056] %s.stimid, stimulus_presentation_number ' ...
        '(do not rebuild exactly: %s; [tuning stimids rebuild])'], sourceBlock, why);
end
end

function [names, values, why] = propertyList(spl)
%PROPERTYLIST tuningcurve_calc's stim_property_list {names, values}: the
%   names (cellstr) and their numeric values, or WHY it cannot be read.
names = {};
values = [];
why = '';
if ~isstruct(spl) || ~isscalar(spl) || ~isfield(spl, 'names') || ~isfield(spl, 'values')
    why = 'not {names, values}';
    return;
end
n = spl.names;
if ischar(n); n = {n}; end
if isstring(n); n = cellstr(n); end
if ~iscell(n) || ~all(cellfun(@(x) ischar(x) && ~isempty(x), n(:)))
    why = 'names are not text';
    return;
end
v = spl.values;
if ~(isnumeric(v) || islogical(v)) || numel(v) ~= numel(n)
    why = 'values are not one number per name';
    return;
end
names = reshape(n, 1, []);
values = reshape(double(v), 1, []);
end

function p = independentParameters(own, srcBlk)
%INDEPENDENTPARAMETERS The stimulus parameters the curve varies:
%   tuningcurve_calc's input_parameters.independent_parameter (split at ',',
%   as ndi.calc.stimulus.tuningcurve splits it), else the curve's label.
p = {};
src = [];
if isfield(own, 'input_parameters') && isstruct(own.input_parameters) ...
        && isscalar(own.input_parameters) ...
        && isfield(own.input_parameters, 'independent_parameter')
    src = own.input_parameters.independent_parameter;
elseif isstruct(srcBlk) && isfield(srcBlk, 'independent_variable_label')
    src = srcBlk.independent_variable_label;
end
if iscell(src)
    src = strjoin(cellfun(@char, src(:)', 'UniformOutput', false), ',');
end
if isstring(src); src = char(strjoin(src, ',')); end
if ~ischar(src) || isempty(src)
    return;
end
p = strtrim(strsplit(src, ','));
p = p(~cellfun(@isempty, p));
end

function v = fieldOr(s, name)
v = [];
if isstruct(s) && isscalar(s) && isfield(s, name)
    v = s.(name);
end
end

function v = normalised(v)
%NORMALISED A value as JSON stores it and jsondecode reads it back.
if isempty(v)
    v = [];
    return;
end
v = jsondecode(jsonencode(v));
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

function p = underBlock(block, name)
%UNDERBLOCK NAME as a path from the document: BLOCK.NAME, unless NAME already
%   starts with BLOCK.
name = char(name);
if startsWith(name, [block '.'])
    p = name;
else
    p = [block '.' name];
end
end

function differing = innerDependsOnDiffers(preBody, blockName)
%INNERDEPENDSONDIFFERS The names of the inner depends_on entries of block
%   BLOCKNAME whose id is not the top-level edge's of the same name ({} when
%   the block has no inner copy, or every entry restates the top level).
%   Both spellings of an entry's id are read ({name, value} and
%   {name, document_id}), as jDependency reads the top level.
differing = {};
if isempty(blockName) || ~isfield(preBody, blockName) ...
        || ~isstruct(preBody.(blockName)) || ~isscalar(preBody.(blockName)) ...
        || ~isfield(preBody.(blockName), 'depends_on')
    return;
end
inner = preBody.(blockName).depends_on;
if isempty(inner)
    return;
end
if isstruct(inner)
    inner = num2cell(inner);
elseif ~iscell(inner)
    differing = {'(not a list of edges)'};
    return;
end
for k = 1:numel(inner)
    d = inner{k};
    if ~isstruct(d) || ~isscalar(d) || ~isfield(d, 'name')
        differing{end+1} = sprintf('entry %d', k); %#ok<AGROW>
        continue;
    end
    v = '';
    for key = {'document_id', 'value', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            v = char(d.(key{1}));
            break;
        end
    end
    if ~strcmp(v, jDependency(preBody, char(d.name)))
        differing{end+1} = char(d.name); %#ok<AGROW>
    end
end
end

function cn = classNameOf(preBody)
cn = '';
if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
    cn = char(preBody.document_class.class_name);
end
end

function [outside, inside] = splitByTemplate(preBody, items)
%SPLITBYTEMPLATE Split the unplaced ITEMS (paths from the document, some with a
%   parenthesised reason after them, or 'depends_on <name>') into those
%   OUTSIDE the class's NDI template (carry-100) and those INSIDE it
%   (carry-056). See UNPLACED, BY THE TEMPLATE in the header.
outside = {};
inside = {};
if isempty(items)
    return;
end
cls = classNameOf(preBody);
t = did2.convert.v1read.calculatorTemplate(cls);
if ~t.found
    error('did2:convert:jCalculation:noTemplate', ...
        ['jCalculation has no NDI template for v1 class "%s" ' ...
         '(did2.convert.v1read.calculatorTemplate), so it cannot tell a field ' ...
         'outside the template (carry-100) from a writer field with no home ' ...
         '(carry-056).'], cls);
end
defs = lower([t.paths, t.writer_paths]);
edges = [t.edges, t.writer_edges];
for k = 1:numel(items)
    s = char(items{k});
    if startsWith(s, 'depends_on ')
        nm = strtrim(s(numel('depends_on ') + 1:end));
        if any(cellfun(@(re) ~isempty(regexp(nm, re, 'once')), edges))
            inside{end+1} = s; %#ok<AGROW>
        else
            outside{end+1} = s; %#ok<AGROW>
        end
        continue;
    end
    if ~isempty(regexp(s, '^app\.\w+ \(app_\w+ differs\)$', 'once'))
        % the app_name / app_version spelling: not a field app.json declares
        outside{end+1} = s; %#ok<AGROW>
        continue;
    end
    p = regexprep(s, ' \(.*$', '');   % the path, without its reason
    switch templateRelation(lower(p), defs)
        case 'inside'
            inside{end+1} = s; %#ok<AGROW>
        case 'container'
            % a declared block or sub-block reported whole (e.g. SF / TF `abs`):
            % its non-empty leaves outside the template are cited on their own
            v = valueAtPath(preBody, p);
            if ~isstruct(v)
                inside{end+1} = s; %#ok<AGROW>
                continue;
            end
            leaves = nonEmptyLeaves(v, p);
            isIn = cellfun(@(x) strcmp(templateRelation(lower(x), defs), 'inside'), leaves);
            outside = [outside, leaves(~isIn)]; %#ok<AGROW>
            if any(isIn) || isempty(leaves)
                % (a block of template blanks the fold still reported stays
                % cited, so the outcome is what it was)
                inside{end+1} = s; %#ok<AGROW>
            end
        otherwise
            outside{end+1} = s; %#ok<AGROW>
    end
end
end

function r = templateRelation(p, defs)
%TEMPLATERELATION 'inside' when the (lower-case) path P is a template leaf or
%   lies under one (a leaf such as input_parameters or tuning_curve.individual
%   holds free content); 'container' when template leaves lie under P;
%   'outside' otherwise.
if any(strcmp(p, defs)) || any(startsWith(p, strcat(defs, '.')))
    r = 'inside';
elseif any(startsWith(defs, [p '.']))
    r = 'container';
else
    r = 'outside';
end
end

function v = valueAtPath(s, p)
%VALUEATPATH The value at the dotted path P of struct S, each part matched
%   case-insensitively; [] when it is not there.
v = s;
parts = strsplit(p, '.');
for k = 1:numel(parts)
    if ~isstruct(v) || isempty(v)
        v = [];
        return;
    end
    fns = fieldnames(v);
    ix = find(strcmpi(fns, parts{k}), 1);
    if isempty(ix)
        v = [];
        return;
    end
    v = v(1).(fns{ix});
end
end

function c = nonEmptyLeaves(v, p)
%NONEMPTYLEAVES The paths under P of every leaf of V that holds a value (a
%   struct array's elements are read under the same path).
c = {};
if isstruct(v)
    for e = 1:numel(v)
        fns = fieldnames(v(e));
        for k = 1:numel(fns)
            c = [c, nonEmptyLeaves(v(e).(fns{k}), [p '.' fns{k}])]; %#ok<AGROW>
        end
    end
    if ~isempty(c)
        c = reshape(unique(c, 'stable'), 1, []);
    end
elseif ~isEmptyValue(v)
    c = {p};
end
end

function t = DATA_ANALYSIS()
%DATA_ANALYSIS The method term of a calculation that is not a fit:
%   EDAM:operation_2945 "Data analysis" ([data analysis is the general method],
%   Jess Haley, 2026-10-30; registry row built in did-schema).
t = did2.convert.registeredTerm('EDAM:operation_2945', 'Data analysis');
end
