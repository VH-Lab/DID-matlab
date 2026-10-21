function bodies = jModelFit(preBody, blk, inputEdges)
%JMODELFIT A v1 curve fit (`fitcurve`, `vmspikefit`) as did-schema #88's
%   `model_fit_calculation`: a generic `calculation` whose value kind is
%   `model_fit` (#73 review item 68, decided 2026-09-29: "fitcurve -> a
%   standalone model_fit data type ... model_fit + model_fit_calculation ...
%   no subject -> refused").
%
%   BODIES = jModelFit(PREBODY, BLK, INPUTEDGES). BLK is the v1 fit block
%   ({fit_name, fit_equation, fit_parameters, fit_parameter_names,
%   fit_independent_variable_names, fit_dependent_variable_names, fit_sse,
%   fit_sse_perpoint, fit_constraints, fit_data}); INPUTEDGES the v1 edge names
%   whose ids become `input_id`.
%
%   value: model (fit_name, a label), equation, coefficients[] {variable:
%   the named parameter, value}, constraints[] {variable, value},
%   independent_variables[] / dependent_variable (the names), goodness {sse,
%   sse_per_point}, input_field / output_field (fit_data).
%
%   PASSES THROUGH (returns {PREBODY}, the v1 tombstone validates it) when
%   the document has no subject (decided: "no subject -> refused"), or no
%   operating system in an `app` block: a #88 calculation REQUIRES
%   `operating_system_id` (#73 item 53) and nothing else says what the fit ran
%   on. Both are reported, never invented.

bodies = {preBody};
subjectId = jSubjectOf(preBody, {'element_id', 'subject_id'});
if isempty(subjectId)
    return;
end
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
if isempty(osId)
    return;
end

v = struct();
nm = charOf(blk, 'fit_name');
if ~isempty(nm); v.model = did2.build.label(nm); end
eq = charOf(blk, 'fit_equation');
if ~isempty(eq); v.equation = eq; end
p = numOf(blk, 'fit_parameters');
names = splitNames(charOf(blk, 'fit_parameter_names'));
if ~isempty(p)
    c = cell(1, numel(p));
    for k = 1:numel(p)
        label = sprintf('parameter %d', k);
        if k <= numel(names); label = names{k}; end
        c{k} = struct('variable', did2.build.label(label), 'value', p(k));
    end
    v.coefficients = did2.build.list(c{:});
end
ind = splitNames(charOf(blk, 'fit_independent_variable_names'));
if ~isempty(ind)
    c = cellfun(@(n) struct('variable', did2.build.label(n)), ind, 'UniformOutput', false);
    v.independent_variables = did2.build.list(c{:});
end
dep = splitNames(charOf(blk, 'fit_dependent_variable_names'));
if ~isempty(dep)
    v.dependent_variable = struct('variable', did2.build.label(dep{1}));
end
cons = {};
if isfield(blk, 'fit_constraints') && isstruct(blk.fit_constraints)
    for k = 1:numel(blk.fit_constraints)
        cn = charOf(blk.fit_constraints(k), 'fit_constraint_name');
        cv = numOf(blk.fit_constraints(k), 'fit_constraint_value');
        if ~isempty(cn) && isscalar(cv)
            cons{end+1} = struct('variable', did2.build.label(cn), 'value', cv); %#ok<AGROW>
        end
    end
end
if ~isempty(cons); v.constraints = did2.build.list(cons{:}); end
g = struct();
sse = numOf(blk, 'fit_sse');
if isscalar(sse); g.sse = sse; end
spp = numOf(blk, 'fit_sse_perpoint');
if isscalar(spp); g.sse_per_point = spp; end
if ~isempty(fieldnames(g)); v.goodness = g; end
if isfield(blk, 'fit_data') && isstruct(blk.fit_data)
    fi = charOf(blk.fit_data, 'input_data_field');
    if ~isempty(fi); v.input_field = fi; end
    fo = charOf(blk.fit_data, 'output_data_field');
    if ~isempty(fo); v.output_field = fo; end
end
value = did2.build.composite('model_fit', 'value', v);

inputs = {};
for k = 1:numel(inputEdges)
    id = jDependency(preBody, inputEdges{k});
    if ~isempty(id); inputs{end+1} = id; end %#ok<AGROW>
end
anchor = jSessionAnchor(preBody, 'during');
if isempty(swId)
    [software, swId] = jSoftware(char(jFirst(nm, 'curve fit')), '', '', jSid(preBody), jStamp(preBody));
end
calc = jStatement(preBody, 'model_fit_calculation', subjectId, ...
    did2.build.label('model fit'), value, ...
    'TimeReferenceIds', {anchor.base.id}, 'InputIds', inputs, ...
    'SoftwareId', swId, 'OperatingSystemId', osId, 'InterpreterId', interpreterId, ...
    'Id', char(preBody.base.id));
bodies = [{calc, anchor}, software, runDocs];
end

function s = jFirst(a, b)
s = a;
if isempty(s); s = b; end
end

function s = charOf(b, name)
s = '';
if isstruct(b) && isfield(b, name)
    x = b.(name);
    if ischar(x); s = strtrim(x); elseif isstring(x) && isscalar(x); s = strtrim(char(x)); end
end
end

function v = numOf(b, name)
v = [];
if isstruct(b) && isfield(b, name) && isnumeric(b.(name)) && ~isempty(b.(name))
    v = double(b.(name));
    v = v(:)';
end
end

function c = splitNames(s)
c = {};
if isempty(s); return; end
c = regexp(strtrim(s), '[\s,]+', 'split');
c = c(~cellfun(@isempty, c));
end
