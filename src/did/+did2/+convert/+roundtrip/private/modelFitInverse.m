function [v1, spec] = modelFitInverse(bodies, v1Class, inputEdges, templateInputs, fitFields)
%MODELFITINVERSE The v1 curve fit (`fitcurve`, `vmspikefit`) that
%   +migrators_j/<V1CLASS> converted through private/jModelFit.
%
%   [V1, SPEC] = modelFitInverse(BODIES, V1CLASS, INPUTEDGES, TEMPLATEINPUTS,
%   FITFIELDS). BODIES is what jModelFit emitted for one v1 fit: the
%   `calculation` (value kind `model_fit`, id preserved), its session anchor,
%   the `software` entity (named by the v1 `app` block, else minted with the
%   fit's name, else 'curve fit') and the run's operating system and
%   interpreter entities. INPUTEDGES are the v1 edge names whose ids jModelFit
%   made the calculation's `input_id`, in its order; the first TEMPLATEINPUTS
%   of them are the template's own edges, rebuilt even when empty. FITFIELDS
%   are the v1 block fields to rebuild (the class's template fields).
%
%   V1 holds, in NDI's v1 shape (<V1CLASS>.json + base.json (+ epochid.json,
%   app.json for vmspikefit) at the locked NDI-matlab `main`):
%     base, app                 private/calcParts (an `app` block only when the
%                               calculation names software jModelFit did not
%                               mint)
%     depends_on                INPUTEDGES from `input_id`, in order (an input
%                               the migrator did not have is ''), then
%                               `element_id` from `entity_id`
%     fit_name                  the value's `model` label
%     fit_equation              `equation`
%     fit_parameters            the `coefficients` values, as a column (the
%                               shape jsondecode gives a JSON number list)
%     fit_parameter_names       the coefficients' names, space-separated (a
%                               coefficient jModelFit named 'parameter <k>'
%                               because v1 named none is not a name)
%     fit_independent_variable_names  `independent_variables`, space-separated
%     fit_dependent_variable_names    `dependent_variable`
%     fit_sse, fit_sse_perpoint `goodness.sse`, `goodness.sse_per_point`
%     fit_constraints           `constraints`, {fit_constraint_name,
%                               fit_constraint_value} each
%     fit_data                  {input_data_field, output_data_field}
%
%   NOT REBUILT, and so reported by the round trip when v1 states them (today's
%   behaviour, unchanged by the raw read; questions for the team): a subject
%   edge named `subject_id` (rebuilt as `element_id`); an input stated only
%   under the second input edge name (rebuilt under the first);
%   `fit_data.output_number_examples`; a dependent variable after the first; a
%   constraint with no name or a non-scalar value; names separated by commas
%   (rebuilt with spaces); `epochid.epochid` (the calculation is anchored to
%   the session, jSessionAnchor 'during'); text in a numeric field.
%
%   See also did2.convert.roundtrip.fitcurve, did2.convert.roundtrip.vmspikefit,
%            calcParts.

leafAt = find(cellfun(@(b) strcmp(classNameOf(b), 'calculation'), bodies), 1);
model = '';
if ~isempty(leafAt)
    [~, model] = termParts(getIn(bodies{leafAt}, 'model_fit', 'value', 'model'));
end
minted = strtrim(model);
if isempty(minted)
    minted = 'curve fit';   % jModelFit's software name when v1 names none
end
[v1, leaf, inputs, spec] = calcParts(bodies, 'calculation', v1Class, minted);
if isempty(leaf)
    return;
end
[kind, value] = statementValue(leaf);
if ~strcmp(kind, 'model_fit')
    spec.unplaced{end+1} = sprintf('the calculation''s value kind is "%s", not model_fit', kind);
end

blk = struct();
if any(strcmp(fitFields, 'fit_name'))
    blk.fit_name = strtrim(model);
end
if any(strcmp(fitFields, 'fit_equation'))
    blk.fit_equation = fieldText(value, 'equation');
end
coef = asCell(getIn(value, 'coefficients'));
vals = zeros(numel(coef), 1);
names = cell(1, numel(coef));
for k = 1:numel(coef)
    x = numberOf(getIn(coef{k}, 'value'));
    if isempty(x)
        spec.unplaced{end+1} = sprintf('coefficient %d has no number', k); %#ok<AGROW>
        x = NaN;
    end
    vals(k) = x;
    [~, names{k}] = termParts(getIn(coef{k}, 'variable'));
end
% jModelFit names coefficient k 'parameter <k>' only past the end of v1's names
last = numel(names);
while last > 0 && strcmp(names{last}, sprintf('parameter %d', last))
    last = last - 1;
end
if any(strcmp(fitFields, 'fit_parameters'))
    blk.fit_parameters = vals;
end
if any(strcmp(fitFields, 'fit_parameter_names'))
    blk.fit_parameter_names = strjoin(names(1:last), ' ');
end
if any(strcmp(fitFields, 'fit_independent_variable_names'))
    ind = asCell(getIn(value, 'independent_variables'));
    n = cell(1, numel(ind));
    for k = 1:numel(ind)
        [~, n{k}] = termParts(getIn(ind{k}, 'variable'));
    end
    blk.fit_independent_variable_names = strjoin(n, ' ');
end
if any(strcmp(fitFields, 'fit_dependent_variable_names'))
    [~, dep] = termParts(getIn(value, 'dependent_variable', 'variable'));
    blk.fit_dependent_variable_names = dep;
end
if any(strcmp(fitFields, 'fit_sse'))
    blk.fit_sse = numberOf(getIn(value, 'goodness', 'sse'));
end
if any(strcmp(fitFields, 'fit_sse_perpoint'))
    blk.fit_sse_perpoint = numberOf(getIn(value, 'goodness', 'sse_per_point'));
end
if any(strcmp(fitFields, 'fit_constraints'))
    cons = asCell(getIn(value, 'constraints'));
    c = struct('fit_constraint_name', {}, 'fit_constraint_value', {});
    for k = 1:numel(cons)
        [~, cn] = termParts(getIn(cons{k}, 'variable'));
        c(end+1) = struct('fit_constraint_name', cn, ...
            'fit_constraint_value', numberOf(getIn(cons{k}, 'value'))); %#ok<AGROW>
    end
    blk.fit_constraints = c;
end
if any(strcmp(fitFields, 'fit_data'))
    blk.fit_data = struct('input_data_field', fieldText(value, 'input_field'), ...
        'output_data_field', fieldText(value, 'output_field'));
end
v1.(v1Class) = blk;

% the edges: the inputs in jModelFit's order, then the subject
names = {};
ids = {};
for k = 1:numel(inputEdges)
    if k <= numel(inputs)
        names{end+1} = inputEdges{k}; %#ok<AGROW>
        ids{end+1} = inputs{k}; %#ok<AGROW>
    elseif k <= templateInputs
        names{end+1} = inputEdges{k}; %#ok<AGROW>
        ids{end+1} = ''; %#ok<AGROW>
    end
end
for k = numel(inputEdges) + 1:numel(inputs)
    spec.unplaced{end+1} = sprintf('input %d (%s) names no v1 edge of a %s', ...
        k, inputs{k}, v1Class); %#ok<AGROW>
end
about = edgeIds(leaf, 'entity_id');
if isempty(about)
    spec.unplaced{end+1} = 'the calculation is about nothing';
    about = {''};
end
names{end+1} = 'element_id';
ids{end+1} = about{1};
v1.depends_on = struct('name', names, 'value', ids);
end
