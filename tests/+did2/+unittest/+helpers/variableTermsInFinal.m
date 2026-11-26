function rep = variableTermsInFinal(docs, ix)
%VARIABLETERMSINFINAL Every variable term in a run's final documents, against the term registry.
%
%   REP = did2.unittest.helpers.variableTermsInFinal(DOCS, IX) walks DOCS, a
%   run's FINAL documents (did2.document, struct or cell of either), and reads
%   every variable term at
%     statement.variable                     (every statement)
%     <...>method.parameters[].variable      (a standalone `method` document's
%                                             `method.parameters`, and an
%                                             interaction's inline
%                                             `interaction.method.parameters`)
%   It is the instrument for did-schema #89 / [variable terms registered before
%   required]: a corpus's variable bindings switch to required once it reads 0
%   unregistered.
%
%   IX is a did2.schema.termIndex ([] = the shared schema cache's).
%
%   A variable is UNREGISTERED when its node is not empty and the registry holds
%   no term with that node (did2.schema.termIndex byNode, compared by
%   did2.schema.curieKey). A variable with an EMPTY node (no `node` field, an
%   empty one, or a variable that is not a {node, name} struct) is counted as
%   `empty_node` and NOT as unregistered: it has no node to look up. The two
%   counts are disjoint.
%
%   REP fields:
%     registry_present  false when the schema in use has no term registry;
%                       then `unregistered` was not measured
%     docs_walked       the final documents read (THE DENOMINATOR)
%     docs_unread       documents that could not be read as a struct
%     variables_read    variable terms read (the second denominator)
%     empty_node        of those, how many have an empty node
%     unregistered      of those, how many have a node the registry lacks
%     offenders         struct array {name, node, kind, count}, one per
%                       distinct (name, node) that is empty-node or
%                       unregistered; kind is 'empty node' or 'unregistered'
%
%   REPORT ONLY; it asserts nothing.

arguments
    docs
    ix = []   % a did2.schema.termIndex, or [] for the shared cache's
end

if isempty(ix)
    ix = did2.schema.termIndex();
end
rep = struct('registry_present', logical(ix.present), 'docs_walked', 0, ...
    'docs_unread', 0, 'variables_read', 0, 'empty_node', 0, 'unregistered', 0, ...
    'offenders', struct('name', {}, 'node', {}, 'kind', {}, 'count', {}));
if isa(docs, 'did2.document') || isstruct(docs)
    docs = num2cell(docs(:));
end
off = containers.Map('KeyType', 'char', 'ValueType', 'any');
for d = 1:numel(docs)
    s = docs{d};
    try
        if isa(s, 'did2.document')
            s = s.toStruct();
        end
    catch
        rep.docs_unread = rep.docs_unread + 1;
        continue;
    end
    if ~isstruct(s)
        rep.docs_unread = rep.docs_unread + 1;
        continue;
    end
    rep.docs_walked = rep.docs_walked + 1;
    vars = {};
    vars = collect(s, '', vars);
    for v = 1:numel(vars)
        [name, node] = termOf(vars{v});
        rep.variables_read = rep.variables_read + 1;
        if isempty(node)
            rep.empty_node = rep.empty_node + 1;
            kind = 'empty node';
        elseif rep.registry_present && ~isKey(ix.byNode, did2.schema.curieKey(node))
            rep.unregistered = rep.unregistered + 1;
            kind = 'unregistered';
        else
            continue;
        end
        k = sprintf('%s|%s|%s', kind, name, node);
        if isKey(off, k)
            e = off(k);
            e.count = e.count + 1;
        else
            e = struct('name', name, 'node', node, 'kind', kind, 'count', 1);
        end
        off(k) = e;
    end
end
if off.Count > 0
    vals = values(off);
    rep.offenders = [vals{:}];
end
end

function vars = collect(x, path, vars)
% Every value at a variable path, one cell per element.
if iscell(x)
    for c = 1:numel(x)
        vars = collect(x{c}, path, vars);
    end
    return;
end
if ~isstruct(x)
    return;
end
f = fieldnames(x);
for e = 1:numel(x)
    for j = 1:numel(f)
        if isempty(path)
            p = f{j};
        else
            p = [path '.' f{j}];
        end
        v = x(e).(f{j});
        if strcmp(f{j}, 'variable') && isVariablePath(p)
            if iscell(v)
                vars = [vars, reshape(v, 1, [])]; %#ok<AGROW>
            elseif isstruct(v) && ~isempty(v)
                vars = [vars, reshape(num2cell(v), 1, [])]; %#ok<AGROW>
            else
                vars{end+1} = v; %#ok<AGROW>
            end
            continue;
        end
        if isstruct(v) || iscell(v)
            vars = collect(v, p, vars);
        end
    end
end
end

function tf = isVariablePath(p)
tf = strcmp(p, 'statement.variable') ...
    || ~isempty(regexp(p, '(^|\.)method\.parameters\.variable$', 'once'));
end

function [name, node] = termOf(v)
name = '';
node = '';
if isstruct(v) && isscalar(v)
    if isfield(v, 'name') && (ischar(v.name) || isstring(v.name)) && ~isempty(v.name)
        name = strtrim(char(v.name));
    end
    if isfield(v, 'node') && (ischar(v.node) || isstring(v.node)) && ~isempty(v.node)
        node = strtrim(char(v.node));
    end
elseif (ischar(v) || isstring(v)) && ~isempty(v)
    name = strtrim(char(v));
end
end
