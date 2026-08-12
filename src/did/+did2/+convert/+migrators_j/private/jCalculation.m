function bodies = jCalculation(preBody, leafClass, composite, variableName, methodName, sourceBlock, valueOverride)
%JCALCULATION Fold a calculator output document 1 -> 1 (id-preserved) into a V_eta
%   subject_calculation LEAF, plus a session anchor. Shared by the calculator
%   composite-leaf family (Lepsky et al., the calculator-motif paper): a calculator
%   produces ONE output document type; in V_eta that is a leaf pairing the
%   `subject_calculation` direction with a result composite `data_type` -- exactly as
%   visual_grating_manipulation pairs subject_manipulation with visual_grating.
%
%   The migration is 1 -> 1 with base.id PRESERVED and depends_on carried, so
%   downstream calc -> calc references resolve (un-defers calculators without the
%   orphan explosion that dissolution caused). The structured result block is kept
%   VERBATIM as the composite value; the calculator's input_parameters ->
%   `subject_interaction.method_parameters`; the generating program -> a `software`
%   ENTITY referenced by a `software_id` edge + the per-run `execution_environment`
%   (superseding the v1 `app` mixin, Item-1 decision); and the input document(s) it
%   consumed -> `derived_from_#` provenance. Emits {leaf, anchor[, software]}.
%
%   leafClass     the concrete leaf class (e.g. 'tuning_curve_calculation').
%   composite     the result composite data_type = the leaf's other superclass and its
%                 value block (e.g. 'tuning_curve'). Kept VERBATIM only when no
%                 reshape applies; the two families below hand `value` to a reshaper.
%   variableName  the subject_statement.variable label (what was computed).
%   methodName    the algorithm identity for subject_interaction.method (the applet).
%
%   Emits {leaf, anchor}. Shared helper for the Brainstorm-J (+migrators_j) migrators.
%
%   CORRECTED 2026-08-12. The two examples above read
%   'orientation_direction_tuning_calculation' and 'orientation_direction_tuning'.
%   NEITHER CLASS EXISTS: the R2/R3 tuning collapse folded the six per-tuning result
%   classes and their leaves into ONE `tuning_curve` composite + ONE
%   `tuning_curve_calculation` leaf, and no caller has passed the old names since.
%   The example was the SOURCE of the same stale claim in twelve migrator headers.
%
%       $ find DID-schema/schemas/V_eta -name 'orientation_direction_tuning*.json'
%         (no match)
%       $ find DID-schema/schemas/V_eta -name 'tuning_curve*.json'
%         schemas/V_eta/draft/tuning_curve.json
%         schemas/V_eta/draft/tuning_curve_calculation.json
%
%   "kept verbatim" was stale in the same direction: the switch below hands every
%   `tuning_curve` and `contrast_sensitivity` composite to a reshaper.
arguments
    preBody (1,1) struct
    leafClass (1,:) char
    composite (1,:) char
    variableName (1,:) char
    methodName (1,:) char
    % The source block holding the result fields. Defaults to the composite name (the
    % result classes carry their own self-named block). A calc whose result fields sit
    % on its concrete `*_calc` block instead (e.g. contrast_sensitivity_calc) passes
    % that block name; input_parameters is stripped from it (-> method_parameters).
    sourceBlock (1,:) char = composite
    % Optional pre-reshaped composite VALUE. When non-empty, the composite block is
    % written as struct('value', valueOverride) instead of carrying sourceBlock
    % verbatim. Used by the tuning collapse (R2/R3): the 6 v1 tuning result blocks are
    % reshaped into the one `tuning_curve` value (model_fit array + typed metric
    % sub-blocks) by jTuningCurveValue before the fold.
    valueOverride = []
end
TV = 'V_eta';

% Composites whose v1 result block is a FLAT bag get reshaped into a `value` cell before
% the fold. Both reshapes follow the same model -- a `model_fit` ARRAY plus typed
% `significance` / `interpolated_values` sub-blocks -- so the two calc families stay
% consistent with each other (and neither flattens queryable scalars into a bag, T13).
if isempty(valueOverride)
    srcBlk = struct();
    if isfield(preBody, sourceBlock) && isstruct(preBody.(sourceBlock))
        srcBlk = preBody.(sourceBlock);
    end
    switch composite
        case 'tuning_curve'          % R2/R3: the 6 tuning families collapse to one
            valueOverride = jTuningCurveValue(srcBlk);
        case 'contrast_sensitivity'  % RB/RBN/RBNS are Naka-Rushton fit variants
            valueOverride = jContrastSensitivityValue(srcBlk);
    end
end

% subject_interaction requires a time_reference; a computed result has no DAQ epoch,
% so 'during' the session is the honest anchor (mirrors the observation migrators).
anchor = jSessionAnchor(preBody, 'during');

leaf = struct();
leaf.document_class = struct('class_name', leafClass, 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_calculation', 'class_version', '1.0.0'), ...
        struct('class_name', composite,             'class_version', '1.0.0')], ...
    'schema_version', TV);

% Document-generation provenance: the v1 `app` block becomes a `software` ENTITY
% (name + version + citation id) referenced by a typed `software_id` edge, plus the
% per-run `execution_environment` on the interaction -- superseding the app mixin
% (Item-1 decision, V_eta_tenet_audit.md R1). One software doc is emitted per calc; a
% corpus-wide dedup by (name, version) is a follow-up second pass.
[software, swId, execEnv] = jSoftwareFromApp(preBody);

% subject_id (from the recording element) + the required time anchor + derived_from
% the input document (the raw curve the calculator consumed) + the generating software.
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
leaf.depends_on = deps;

leaf.base = preBody.base;   % id preserved -> inbound references resolve to the leaf

leaf.subject_statement = struct('variable', jOntologyTerm('', variableName), ...
    'storage_mode', 'inline');
leaf.subject_interaction = struct('method', jOntologyTerm('', methodName), ...
    'method_parameters', calcInputParameters(preBody), ...
    'sample_time', struct('kind', 'point'), ...
    'execution_environment', execEnv);

% the composite value block: the calculator's structured result. Read from
% sourceBlock (the composite's own block, or the concrete `*_calc` block); strip
% input_parameters if it materialized there (it goes to method_parameters instead).
leaf.(composite) = struct();
if ~isempty(valueOverride)
    % Reshaped value (e.g. the tuning collapse): the composite carries a `value` block.
    leaf.(composite) = struct('value', valueOverride);
elseif isfield(preBody, sourceBlock) && isstruct(preBody.(sourceBlock))
    srcBlk = preBody.(sourceBlock);
    if isfield(srcBlk, 'input_parameters')
        srcBlk = rmfield(srcBlk, 'input_parameters');
    end
    leaf.(composite) = srcBlk;
end

bodies = {leaf, anchor};
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== helpers =============================================

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
% The calculator's input_parameters (Fig 3E) materialize on the source's concrete
% `*_calc` block (calculator.input_parameters, placement concrete_class -- the block
% name is the abbreviated calc class, e.g. `oridirtuning_calc`). Scan every block for
% the one that carries them; also accept a top-level `input_parameters`. Absent on a
% bare result doc -> an empty struct (method_parameters is optional).
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

% NOTE: the `app` -> `software` fold used to live here as a LOCAL function, which
% shadowed anything of the same name in private/. It read `app.name` / `app.version`
% only -- names that universalRenames has already rewritten to `app_name` /
% `app_version` by the time any migrator runs (universalRenames.m:145-164), so on the
% real v1_to_v2 pipeline it minted NOTHING. It now lives in
% private/jSoftwareFromApp.m, reads both spellings, and is shared with the
% filenavigator fold. See that file's header for the full account.
