function t = registeredTerm(node, name)
%REGISTEREDTERM A term as the schema's term registry writes it (tenet T19).
%
%   T = did2.convert.registeredTerm(NODE, NAME). The name a migrator writes for
%   a registered term is the REGISTRY'S LABEL, not the migrator's spelling: a
%   NODE the registry holds returns {its node, its registered name} (so
%   'NCIT:C16608' 'gene expression' becomes 'Gene Expression'); with no NODE,
%   a NAME the registry holds (ignoring case) returns that registered term; any
%   other term is returned as given, {NODE, NAME}. A schema with no registry
%   (did-schema main) changes nothing. The same rule as NDI's import
%   (ndi.setup.V2.registeredTerm).

arguments
    node {mustBeText} = ''
    name {mustBeText} = ''
end

node = strtrim(char(node));
name = strtrim(char(name));
t = struct('node', node, 'name', name);
try
    ix = did2.schema.termIndex();
catch
    return;
end
if ~isstruct(ix) || ~isfield(ix, 'present') || ~ix.present
    return;
end
if ~isempty(node)
    key = did2.schema.curieKey(node);
    if isKey(ix.byNode, key)
        e = ix.byNode(key);
        t = struct('node', char(e.node), 'name', char(e.name));
    end
elseif ~isempty(name) && isKey(ix.byName, did2.schema.termNameKey(name))
    e = ix.byName(did2.schema.termNameKey(name));
    t = struct('node', char(e.node), 'name', char(e.name));
end
end
