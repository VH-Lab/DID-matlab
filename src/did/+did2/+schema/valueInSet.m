function [tf, reason, governed] = valueInSet(variable, value, registry)
%VALUEINSET Is VALUE in the closed value list its VARIABLE's binding names?
%
%   [TF, REASON, GOVERNED] = did2.schema.valueInSet(VARIABLE, VALUE, REGISTRY)
%
%   A `subject_statement_bindings` row of DID-schema's
%   binding_registry_meta.json may carry `values`, a CLOSED list of
%   {node, name} terms (Jess Haley, 2026-10-21; DID-schema
%   V_eta_term_registry_plan.md, "Closed value sets"). A statement whose
%   variable has such a row may only take a value from it. An EMPTY list is
%   legal and admits nothing yet.
%
%   VARIABLE is the statement's variable, a {node, name} struct (or a
%   name). VALUE is the value term, or a struct array of them (a keyed
%   term.value); each must be in the list. REGISTRY is the parsed
%   binding_registry_meta.json ([] = the shared schema cache's).
%
%   The row is found by the variable's node (did2.schema.curieKey: prefix by
%   key, spelling or synonym, ignoring case), else by its name ignoring case.
%   A value matches a member by node the same way; a value with no node
%   matches a member by name.
%
%   GOVERNED is false when the variable has no row, or its row lists no
%   `values` (a subtree, any registered term, or `term_valued: false`):
%   then TF is true, since there is no closed list to be outside.
%   REASON says why TF is false ('' when true).
%
%   See also did2.schema.termRegistered, did2.build.statement.

arguments
    variable
    value
    registry = []
end

tf = true;
reason = '';
governed = false;
if isempty(registry)
    try
        registry = did2.schema.cache.shared().bindingRegistry;
    catch
        return;
    end
end
row = findRow(registry, variable);
if isempty(row) || ~isfield(row, 'values')
    return;
end
governed = true;
members = asTerms(row.values);
memberKeys = cellfun(@keyOf, members, 'UniformOutput', false);
memberNames = cellfun(@(m) lower(textOf(m, 'name')), members, 'UniformOutput', false);
values = asTerms(value);
varName = textOf(row.variable, 'name');
for k = 1:numel(values)
    v = values{k};
    node = textOf(v, 'node');
    if ~isempty(node)
        ok = any(strcmp(memberKeys, did2.schema.curieKey(node)));
    else
        ok = any(strcmp(memberNames, lower(textOf(v, 'name'))));
    end
    if ~ok
        tf = false;
        shown = node;
        if isempty(shown)
            shown = ['"' textOf(v, 'name') '"'];
        end
        if isempty(members)
            reason = sprintf(['%s is not an admitted value of "%s": its closed list is ' ...
                'empty (nothing admitted yet; add a value through review)'], shown, varName);
        else
            reason = sprintf('%s is not one of the %d admitted value(s) of "%s"', ...
                shown, numel(members), varName);
        end
        return;
    end
end
end

% ===================== helpers =============================================

function row = findRow(registry, variable)
row = [];
if ~isstruct(registry) || ~isfield(registry, 'subject_statement_bindings')
    return;
end
rows = registry.subject_statement_bindings;
if isstruct(rows)
    rows = num2cell(rows);
end
if ischar(variable) || isstring(variable)
    variable = struct('node', '', 'name', char(variable));
end
node = textOf(variable, 'node');
name = lower(textOf(variable, 'name'));
key = '';
if ~isempty(node)
    key = did2.schema.curieKey(node);
end
byName = [];
for k = 1:numel(rows)
    r = rows{k};
    if ~isstruct(r) || ~isfield(r, 'variable')
        continue;
    end
    rnode = textOf(r.variable, 'node');
    if ~isempty(key) && ~isempty(rnode) && strcmp(did2.schema.curieKey(rnode), key)
        row = r;
        return;
    end
    if isempty(byName) && isempty(key) && ~isempty(name) ...
            && strcmp(lower(textOf(r.variable, 'name')), name)
        byName = r;
    end
end
row = byName;
end

function c = asTerms(x)
if isempty(x)
    c = {};
elseif iscell(x)
    c = reshape(x, 1, []);
elseif isstruct(x)
    c = reshape(num2cell(x), 1, []);
else
    c = {};
end
end

function k = keyOf(t)
k = textOf(t, 'node');
if ~isempty(k)
    k = did2.schema.curieKey(k);
end
end

function v = textOf(s, f)
v = '';
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = strtrim(char(s.(f)));
end
end
