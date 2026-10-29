function [tf, reason] = termRegistered(t, ix)
%TERMREGISTERED Is the term T the one the term registry holds?
%
%   [TF, REASON] = did2.schema.termRegistered(T, IX). T is a {node, name}
%   struct; IX a did2.schema.termIndex ([] = the shared cache's). TF is true
%   when:
%     - T has a node the registry holds (prefix read by key, spelling or
%       synonym: did2.schema.curieKey), and T's name, when given, is the name
%       registered for it, exactly; or
%     - T has no node and its name is a registered term that has no node
%       either (a STAGED term: named, its node still to be found or minted).
%   A name registered WITH a node, given without it, is not the registered
%   term: the node is what makes two datasets' terms the same.
%   REASON says why TF is false ('' when true). A schema with no registry
%   (IX.present false) registers nothing, so the caller decides whether to ask.
%
%   See also did2.schema.termIndex, did2.build.unregisteredTerms.

arguments
    t struct
    ix = []   % a did2.schema.termIndex, or [] for the shared cache's
end

if isempty(ix)
    ix = did2.schema.termIndex();
end
node = textOf(t, 'node');
name = textOf(t, 'name');
tf = false;
reason = '';
if ~isempty(node)
    key = did2.schema.curieKey(node);
    if ~isKey(ix.byNode, key)
        reason = sprintf('node %s is not in the term registry', node);
        return;
    end
    e = ix.byNode(key);
    if ~isempty(name) && ~strcmp(name, e.name)
        reason = sprintf('node %s is registered as "%s", not "%s"', node, e.name, name);
        return;
    end
    tf = true;
    return;
end
if ~isKey(ix.byName, did2.schema.termNameKey(name))
    reason = sprintf('"%s" is not in the term registry', name);
    return;
end
e = ix.byName(did2.schema.termNameKey(name));
if ~isempty(e.node)
    reason = sprintf('"%s" is registered with node %s; give the node', name, e.node);
    return;
end
if ~strcmp(name, e.name)
    reason = sprintf('"%s" is registered as "%s"', name, e.name);
    return;
end
tf = true;
end

function v = textOf(s, f)
arguments
    s struct
    f {mustBeText}
end

v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = strtrim(char(s.(f)));
end
end
