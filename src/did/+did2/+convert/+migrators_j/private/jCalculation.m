function bodies = jCalculation(preBody, concreteClass, superclasses, valueTargetBlock, variableName, methodName, sourceBlock, valueOverride, familyLeafFields)
%JCALCULATION Fold a calculator output document 1 -> 1 (id-preserved) into a V_eta
%   concrete calc leaf, plus a session anchor + minted `software` and
%   `runtime_environment` entities.
%
%   PR #68 (Waltham-Data-Science/DID-schema): reverses R2/R3's leaf collapse.
%   A calc doc no longer ends up on the abstract `tuning_curve_calculation` leaf
%   with a raw `tuning_curve` composite value. It ends up on a CONCRETE per-family
%   leaf whose class_name is the v1 spelling (e.g. `oridirtuning_calc`), inheriting
%   from BOTH a calc-family abstract leaf (which carries significance + model_fit)
%   AND a specific composite marker (which inherits value fields from
%   `tuning_curve`). "Every concrete calc doc inherits from both a calc-family
%   leaf and a specific composite. Emitted doc has one class-named property
%   block per class in the inheritance chain." (Lepsky et al. 2026 Fig. 4.)
%
%   Also: the `calculator` schema now declares REQUIRED edges `software_id` +
%   `runtime_environment_id`. The per-run os / interpreter facts move OUT of an
%   inline `subject_interaction.execution_environment` sub-block and INTO a
%   standalone `runtime_environment` entity. This helper mints that entity from
%   the same v1 `app` block jSoftwareFromApp already reads.
%
%   Arguments:
%     concreteClass       the concrete emitted class name (v1 spelling per paper;
%                         e.g. 'oridirtuning_calc', 'contrasttuning_calc',
%                         'speedtuning_calc', 'tuningcurve_calc').
%     superclasses        cellstr of direct superclasses on the emitted body's
%                         document_class.superclasses list, in order. Typical
%                         tuning shape: {'tuning_curve_calculation', <marker>}.
%                         Contrast-sensitivity shape:
%                         {'subject_calculation', 'contrast_sensitivity'}.
%     valueTargetBlock    the block name where the reshaped value lands as
%                         `.value` (e.g. 'tuning_curve' for the tuning family;
%                         'contrast_sensitivity' for CSF). This is typically
%                         either the marker's parent (e.g. tuning_curve is the
%                         PARENT of the marker orientation_direction_tuning) or
%                         the marker itself when it is not thin.
%     variableName        the subject_statement.variable label (what was
%                         computed).
%     methodName          the algorithm identity for subject_interaction.method
%                         (the applet name).
%     sourceBlock         the v1 block holding result fields to reshape.
%                         Defaults to a marker with the same name as
%                         valueTargetBlock.
%     valueOverride       optional pre-reshaped value struct; when non-empty,
%                         becomes `body.(valueTargetBlock).value`. When empty,
%                         the source block is used verbatim (with input_parameters
%                         stripped).
%     familyLeafFields    optional struct whose fields are merged into the first
%                         superclass block that names a `_calculation` leaf
%                         (typically 'tuning_curve_calculation'). Used to lift
%                         `significance` and `model_fit` off the composite value
%                         and onto the calc-family abstract leaf per V_eta's
%                         schema split (see tuning_curve_calculation.json).
%
%   Returns {leaf, anchor[, software][, runtime_environment]}. The leaf preserves
%   base.id and depends_on so downstream calc references resolve.

arguments
    preBody (1,1) struct
    concreteClass (1,:) char
    superclasses (1,:) cell
    valueTargetBlock (1,:) char
    variableName (1,:) char
    methodName (1,:) char
    sourceBlock (1,:) char = valueTargetBlock
    valueOverride = []
    familyLeafFields (1,1) struct = struct()
end
TV = 'V_eta';

% The result composites whose v1 result block is a FLAT bag get reshaped into a
% (value, familyLeafFields) pair. Both reshapers name a `_calculation` leaf slot
% (significance / model_fit) that lives on the family abstract per V_eta's split.
if isempty(valueOverride)
    srcBlk = struct();
    if isfield(preBody, sourceBlock) && isstruct(preBody.(sourceBlock))
        srcBlk = preBody.(sourceBlock);
    end
    switch valueTargetBlock
        case 'tuning_curve'
            [valueOverride, familyLeafFields] = jTuningCurveValue(srcBlk);
        case 'contrast_sensitivity'
            valueOverride = jContrastSensitivityValue(srcBlk);
    end
end

anchor = jSessionAnchor(preBody, 'during');

leaf = struct();
scList = cell(1, numel(superclasses));
for k = 1:numel(superclasses)
    scList{k} = struct('class_name', superclasses{k}, 'class_version', '1.0.0');
end
leaf.document_class = struct('class_name', concreteClass, 'class_version', '1.0.0', ...
    'superclasses', [scList{:}], ...
    'schema_version', TV);

[software, swId, execEnv] = jSoftwareFromApp(preBody);

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = char(preBody.base.session_id); end
    if isfield(preBody.base, 'datestamp');  datestamp = char(preBody.base.datestamp);  end
end
[rtEnv, rtId] = jRuntimeEnvironment(execEnv, sessionId, datestamp);

deps = jCarrySubject(preBody, {'element_id', 'subject_id'});
deps(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
srcId = firstDepValue(preBody, {'stimulus_tuningcurve_id', ...
    'stimulus_response_scalar_id', 'stimulus_response_id'});
if ~isempty(srcId)
    deps(end+1) = struct('name', 'derived_from_1', 'value', srcId);
end
if ~isempty(swId)
    deps(end+1) = struct('name', 'software_id', 'value', swId);
end
if ~isempty(rtId)
    deps(end+1) = struct('name', 'runtime_environment_id', 'value', rtId);
end
leaf.depends_on = deps;

leaf.base = preBody.base;   % id preserved -> inbound references resolve to the leaf

leaf.subject_statement = struct('variable', jOntologyTerm('', variableName), ...
    'storage_mode', 'inline');
leaf.subject_interaction = struct('method', jOntologyTerm('', methodName), ...
    'method_parameters', calcInputParameters(preBody), ...
    'sample_time', struct('kind', 'point'), ...
    'execution_environment', execEnv);

% An empty concrete block reserves the class's own property slot for the
% ensureClassBlocks pass, which walks the inheritance chain. Family-specific
% scalars (oridir's `vector`, CSF's per-frequency arrays) belong here in a
% follow-up; keeping it empty today matches the schema's own `"fields": []`.
if ~isfield(leaf, concreteClass)
    leaf.(concreteClass) = struct();
end

% The value block: the calculator's structured result. Read from sourceBlock (the
% marker's own block, or the concrete `*_calc` block); strip input_parameters if
% it materialised there (it goes to subject_interaction.method_parameters).
leaf.(valueTargetBlock) = struct();
if ~isempty(valueOverride)
    leaf.(valueTargetBlock) = struct('value', valueOverride);
elseif isfield(preBody, sourceBlock) && isstruct(preBody.(sourceBlock))
    srcBlk = preBody.(sourceBlock);
    if isfield(srcBlk, 'input_parameters')
        srcBlk = rmfield(srcBlk, 'input_parameters');
    end
    leaf.(valueTargetBlock) = srcBlk;
end

% Family-leaf fields (significance / model_fit) go onto the first *_calculation
% superclass named in the chain. V_eta's tuning_curve_calculation declares them
% as top-level fields, not under a `value` wrapper (tuning_curve_calculation.json).
if ~isempty(fieldnames(familyLeafFields))
    familyLeaf = pickCalculationSuper(superclasses);
    if ~isempty(familyLeaf)
        block = struct();
        if isfield(leaf, familyLeaf) && isstruct(leaf.(familyLeaf))
            block = leaf.(familyLeaf);
        end
        fns = fieldnames(familyLeafFields);
        for i = 1:numel(fns)
            block.(fns{i}) = familyLeafFields.(fns{i});
        end
        leaf.(familyLeaf) = block;
    end
end

bodies = {leaf, anchor};
if ~isempty(software)
    bodies{end+1} = software;
end
if ~isempty(rtEnv)
    bodies{end+1} = rtEnv;
end
end

% ===================== helpers =============================================

function nm = pickCalculationSuper(superclasses)
% First superclass whose name ends in '_calculation' -- the abstract calc-family
% leaf per V_eta's naming rule (`_calculation` suffix reserved for calculator
% outputs, issue #67 decision 13).
nm = '';
for k = 1:numel(superclasses)
    s = superclasses{k};
    if numel(s) > 12 && strcmp(s(end-11:end), '_calculation')
        nm = s;
        return;
    end
end
end

function v = firstDepValue(preBody, names)
v = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for s = 1:numel(names)
        for k = 1:numel(preBody.depends_on)
            d = preBody.depends_on(k);
            if isfield(d, 'name') && strcmp(d.name, names{s})
                if isfield(d, 'value') && ~isempty(d.value); v = char(d.value); return;
                elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                    v = char(d.document_id); return; end
            end
        end
    end
end
end

function p = calcInputParameters(preBody)
% The calculator's input_parameters (Fig 3E) materialise on the source's concrete
% `*_calc` block. Scan every block for the one that carries them; also accept a
% top-level `input_parameters`. Absent on a bare result doc -> an empty struct
% (method_parameters is optional).
p = struct();
fns = fieldnames(preBody);
for i = 1:numel(fns)
    b = preBody.(fns{i});
    if isstruct(b) && isscalar(b) && isfield(b, 'input_parameters') ...
            && isstruct(b.input_parameters)
        p = b.input_parameters; return;
    end
end
if isfield(preBody, 'input_parameters') && isstruct(preBody.input_parameters)
    p = preBody.input_parameters;
end
end
