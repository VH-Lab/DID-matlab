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
%   leafClass     the concrete leaf class (e.g. 'orientation_direction_tuning_calculation').
%   composite     the result composite data_type = the leaf's other superclass and its
%                 value block (e.g. 'orientation_direction_tuning'); kept verbatim.
%   variableName  the subject_statement.variable label (what was computed).
%   methodName    the algorithm identity for subject_interaction.method (the applet).
%
%   Emits {leaf, anchor}. Shared helper for the Brainstorm-J (+migrators_j) migrators.
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

function [software, swId, execEnv] = jSoftwareFromApp(preBody)
% The v1 `app` block -> a `software` ENTITY (identity: name + version + citation id) +
% the per-run `execution_environment` (os / interpreter). Returns [] software and ''
% swId when the app block carries no software name (no identity -> no entity, and
% software_id is omitted; execution_environment may still carry env fields if present).
% Supersedes the old `app` superclass block (Item-1 decision, paper Fig 4 / FAIR §4.2).
software = []; swId = ''; execEnv = struct();
app = struct();
if isfield(preBody, 'app') && isstruct(preBody.app)
    app = preBody.app;
end
% per-run environment (the actual os/interpreter this run used)
envFields = {'os', 'os_version', 'interpreter', 'interpreter_version'};
for i = 1:numel(envFields)
    if isfield(app, envFields{i}) && ~isempty(app.(envFields{i}))
        execEnv.(envFields{i}) = char(app.(envFields{i}));
    end
end
name = '';
if isfield(app, 'name') && ~isempty(app.name); name = char(app.name); end
if isempty(name)
    return;   % no software identity -> no entity, software_id omitted
end
TV = 'V_eta';
sessionId = ''; datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp');  datestamp  = preBody.base.datestamp;  end
end
sid = did.ido.unique_id();
% citation id / homepage ride on global_identifier (scheme='URL' for the repo/homepage).
gids = struct('scheme', {}, 'value', {});
if isfield(app, 'url') && ~isempty(app.url)
    gids(end+1) = struct('scheme', 'URL', 'value', char(app.url));
end
version = '';
if isfield(app, 'version') && ~isempty(app.version); version = char(app.version); end
software = struct();
software.document_class = struct('class_name', 'software', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', TV);
software.depends_on = struct('name', {}, 'value', {});
software.base = struct('id', sid, 'session_id', sessionId, ...
    'name', name, 'datestamp', datestamp);
software.entity = struct('global_identifier', {gids});
software.software = struct('name', name, 'version', version);
swId = sid;
end
