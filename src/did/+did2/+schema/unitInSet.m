function [tf, reason, governed] = unitInSet(variable, unit, registry)
%UNITINSET Is UNIT one of the source units its VARIABLE's unit binding admits?
%
%   [TF, REASON, GOVERNED] = did2.schema.unitInSet(VARIABLE, UNIT, REGISTRY)
%
%   Decided by Jess Haley, 2026-10-27 [allowed units are closed source_unit
%   lists] and 2026-10-29 [allowed units are source units] (did-schema
%   V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G4): which units a
%   variable admits is a closed list of the units a SOURCE may give its value
%   in (the value's `source_unit`), each converted to the value class's
%   canonical unit. The lists are did-schema binding_registry_meta.json
%   `unit_bindings`, one row per variable, {variable, source_units}.
%
%   VARIABLE is a {node, name} term (or a name). UNIT is the `source_unit`
%   as written: a {node, name} term, or text (the schema before
%   [source unit is a term]). REGISTRY is the parsed
%   binding_registry_meta.json ([] = the shared schema cache's).
%
%   The row is found by the variable's node (did2.schema.curieKey: prefix by
%   key, spelling or synonym, ignoring case), else, for a variable with no
%   node, by its name ignoring case -- as did2.schema.valueInSet finds a
%   `values` row. A unit matches a member by node the same way; a unit with
%   no node matches a member by name, ignoring case.
%
%   GOVERNED is false when the variable has no unit_bindings row, or UNIT is
%   blank (no unit stated: what a unitless number needs is
%   [canonical absent only as needs info], not this list); TF is then true.
%   REASON says why TF is false ('' when true).
%
%   See also did2.schema.unitBindingProblems, did2.schema.valueInSet.

arguments
    variable
    unit
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
[unitNode, unitName] = termParts(unit);
if isempty(unitNode) && isempty(unitName)
    return;
end
row = findRow(registry, variable);
if isempty(row) || ~isfield(row, 'source_units')
    return;
end
governed = true;
members = asTerms(row.source_units);
ok = false;
for k = 1:numel(members)
    [mNode, mName] = termParts(members{k});
    if ~isempty(unitNode)
        ok = ~isempty(mNode) && strcmp(did2.schema.curieKey(mNode), did2.schema.curieKey(unitNode));
    else
        ok = strcmpi(mName, unitName);
    end
    if ok
        break;
    end
end
if ok
    return;
end
tf = false;
[~, varName] = termParts(row.variable);
shown = unitNode;
if isempty(shown)
    shown = ['"' unitName '"'];
end
names = cellfun(@(m) secondOut(m), members, 'UniformOutput', false);
reason = sprintf(['source unit %s is not one of the %d unit(s) a source may give ' ...
    '"%s" in (%s)'], shown, numel(members), varName, strjoin(names, ', '));
end

% ===================== helpers =============================================

function row = findRow(registry, variable)
row = [];
if ~isstruct(registry) || ~isfield(registry, 'unit_bindings')
    return;
end
rows = asTerms(registry.unit_bindings);
[node, name] = termParts(variable);
byName = [];
for k = 1:numel(rows)
    r = rows{k};
    if ~isstruct(r) || ~isfield(r, 'variable')
        continue;
    end
    [rnode, rname] = termParts(r.variable);
    if ~isempty(node)
        if ~isempty(rnode) && strcmp(did2.schema.curieKey(rnode), did2.schema.curieKey(node))
            row = r;
            return;
        end
    elseif isempty(byName) && ~isempty(name) && strcmpi(rname, name)
        byName = r;
    end
end
row = byName;
end

function [node, name] = termParts(t)
node = '';
name = '';
if ischar(t) || (isstring(t) && isscalar(t))
    name = strtrim(char(t));
elseif isstruct(t) && isscalar(t)
    node = textOf(t, 'node');
    name = textOf(t, 'name');
end
end

function n = secondOut(t)
[~, n] = termParts(t);
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

function v = textOf(s, f)
v = '';
if isstruct(s) && isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = strtrim(char(s.(f)));
end
end
