function problems = unitBindingProblems(s, registry)
%UNITBINDINGPROBLEMS Every source unit in a document its variable's unit
%   binding does not admit.
%
%   PROBLEMS = did2.schema.unitBindingProblems(S, REGISTRY) reads the V2
%   document struct S and returns a cellstr, one line per quantity whose
%   `source_unit` is outside its variable's did-schema `unit_bindings` list
%   (did2.schema.unitInSet; Decided by Jess Haley, 2026-10-27 [allowed units
%   are closed source_unit lists] and 2026-10-29 [allowed units are source
%   units], did-schema V_eta_go_forward_class_audit.md). {} when there is
%   none. REGISTRY is the parsed binding_registry_meta.json ([] = the shared
%   schema cache's); a registry with no `unit_bindings` gives {}.
%
%   Where a quantity's variable is read:
%     - an ENTRY carrying both `variable` and `source_unit`, at any depth of
%       any block (statement.conditions, data.covariates, a method's
%       parameters): its own variable;
%     - a VALUE CELL (a struct with `source_unit` and no `variable`) under a
%       block's `value` (the value kind's block, e.g. time.value): the
%       statement's variable (statement.variable).
%   document_class, depends_on, base, file and files are not read.
%
%   See also did2.schema.unitInSet, did2.schema.cache/validateDocument.

arguments
    s
    registry = []
end

problems = {};
if isempty(registry)
    try
        registry = did2.schema.cache.shared().bindingRegistry;
    catch
        return;
    end
end
if ~isstruct(s) || ~isscalar(s) || ~isstruct(registry) ...
        || ~isfield(registry, 'unit_bindings') || isempty(registry.unit_bindings)
    return;
end
stmtVar = [];
if isfield(s, 'statement') && isstruct(s.statement) && isscalar(s.statement) ...
        && isfield(s.statement, 'variable')
    stmtVar = s.statement.variable;
end
skip = {'document_class', 'depends_on', 'base', 'file', 'files'};
blocks = fieldnames(s);
for k = 1:numel(blocks)
    b = blocks{k};
    if any(strcmp(b, skip))
        continue;
    end
    problems = [problems, entries(s.(b), b, registry)]; %#ok<AGROW>
    if ~strcmp(b, 'statement') && ~isempty(stmtVar) && isstruct(s.(b)) ...
            && isscalar(s.(b)) && isfield(s.(b), 'value')
        problems = [problems, valueCells(s.(b).value, [b '.value'], stmtVar, registry)]; %#ok<AGROW>
    end
end
end

% ===================== walkers =============================================

function p = entries(v, path, registry)
% {variable, source_unit} entries at any depth under V
p = {};
if iscell(v)
    for e = 1:numel(v)
        p = [p, entries(v{e}, sprintf('%s{%d}', path, e), registry)]; %#ok<AGROW>
    end
    return;
end
if ~isstruct(v)
    return;
end
for e = 1:numel(v)
    el = v(e);
    elPath = path;
    if numel(v) > 1
        elPath = sprintf('%s(%d)', path, e);
    end
    if isfield(el, 'variable') && isfield(el, 'source_unit')
        p = [p, check(el.variable, el.source_unit, elPath, registry)]; %#ok<AGROW>
    end
    fns = fieldnames(el);
    for f = 1:numel(fns)
        if any(strcmp(fns{f}, {'variable', 'source_unit'}))
            continue;
        end
        x = el.(fns{f});
        if isstruct(x) || iscell(x)
            p = [p, entries(x, [elPath '.' fns{f}], registry)]; %#ok<AGROW>
        end
    end
end
end

function p = valueCells(v, path, variable, registry)
% value cells (a `source_unit`, no `variable`) under a block's `value`
p = {};
if iscell(v)
    for e = 1:numel(v)
        p = [p, valueCells(v{e}, sprintf('%s{%d}', path, e), variable, registry)]; %#ok<AGROW>
    end
    return;
end
if ~isstruct(v)
    return;
end
for e = 1:numel(v)
    el = v(e);
    elPath = path;
    if numel(v) > 1
        elPath = sprintf('%s(%d)', path, e);
    end
    if isfield(el, 'variable')
        continue;   % an entry with its own variable: read by entries()
    end
    if isfield(el, 'source_unit')
        p = [p, check(variable, el.source_unit, elPath, registry)]; %#ok<AGROW>
    end
    fns = fieldnames(el);
    for f = 1:numel(fns)
        if strcmp(fns{f}, 'source_unit')
            continue;
        end
        x = el.(fns{f});
        if isstruct(x) || iscell(x)
            p = [p, valueCells(x, [elPath '.' fns{f}], variable, registry)]; %#ok<AGROW>
        end
    end
end
end

function p = check(variable, unit, path, registry)
p = {};
[tf, reason] = did2.schema.unitInSet(variable, unit, registry);
if ~tf
    p = {sprintf('%s: %s', path, reason)};
end
end
