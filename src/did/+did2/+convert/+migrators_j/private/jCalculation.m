function bodies = jCalculation(preBody, leafClass, composite, variableName, methodName)
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
%   VERBATIM as the composite value; the calculator's app -> the `app` block, its
%   input_parameters -> `subject_interaction.method_parameters`, and the input
%   document(s) it consumed -> `derived_from_#` provenance.
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
end
TV = 'V_eta';

% subject_interaction requires a time_reference; a computed result has no DAQ epoch,
% so 'during' the session is the honest anchor (mirrors the observation migrators).
anchor = jSessionAnchor(preBody, 'during');

leaf = struct();
leaf.document_class = struct('class_name', leafClass, 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_calculation', 'class_version', '1.0.0'), ...
        struct('class_name', composite,             'class_version', '1.0.0')], ...
    'schema_version', TV);

% subject_id (from the recording element) + the required time anchor + derived_from
% the input document (the raw curve the calculator consumed, its provenance).
deps = jCarrySubject(preBody, {'element_id', 'subject_id'});
deps(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
srcId = firstDepValue(preBody, {'stimulus_tuningcurve_id', 'stimulus_response_id'});
if ~isempty(srcId)
    deps(end+1) = struct('name', 'derived_from_1', 'value', srcId);
end
leaf.depends_on = deps;

leaf.base = preBody.base;   % id preserved -> inbound references resolve to the leaf

leaf.subject_statement = struct('variable', jOntologyTerm('', variableName), ...
    'storage_mode', 'inline');
leaf.subject_interaction = struct('method', jOntologyTerm('', methodName), ...
    'method_parameters', calcInputParameters(preBody, leafClass), ...
    'sample_time', struct('kind', 'point'));
leaf.app = calcApp(preBody);

% the composite value block: the calculator's structured result, kept verbatim.
if isfield(preBody, composite) && isstruct(preBody.(composite))
    leaf.(composite) = preBody.(composite);
else
    leaf.(composite) = struct();
end

bodies = {leaf, anchor};
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

function p = calcInputParameters(preBody, leafClass)
% The calculator's input_parameters (Fig 3E) live in the source's own calc block
% (e.g. an `oridirtuning_calc` block on the calculator-output doc). Absent on a bare
% result doc -> an empty struct (method_parameters is optional).
p = struct();
calcBlock = regexprep(leafClass, '_calculation$', '_calc');   % leaf -> source calc class
for cand = {calcBlock, 'input_parameters'}
    b = cand{1};
    if isfield(preBody, b) && isstruct(preBody.(b))
        if isfield(preBody.(b), 'input_parameters') && isstruct(preBody.(b).input_parameters)
            p = preBody.(b).input_parameters; return;
        elseif strcmp(b, 'input_parameters')
            p = preBody.(b); return;
        end
    end
end
end

function a = calcApp(preBody)
% Keep the program+version reproducibility record if the source carried an `app`
% block (paper Fig 4 / FAIR); otherwise an empty app block (fields optional).
a = struct();
if isfield(preBody, 'app') && isstruct(preBody.app)
    a = preBody.app;
end
end
