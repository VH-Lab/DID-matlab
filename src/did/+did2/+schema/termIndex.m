function ix = termIndex(registry)
%TERMINDEX The term registry, indexed by node and by name.
%
%   IX = did2.schema.termIndex(REGISTRY) reads a parsed term_registry_meta.json
%   (DID-schema V_eta_term_registry_plan.md; tenet T19: a term already used in
%   an NDI dataset first, then an existing ontology, then a new EMPTY term) and
%   returns a struct:
%     present  false when the schema in use has no term registry (did-schema
%              main): nothing can be checked against it
%     count    the number of registered terms
%     byNode   curieKey(node) -> the registered term {node, name, status}
%     byName   lower(name) -> the registered term, for every term
%
%   REGISTRY ([] = the shared schema cache's) is the struct jsondecode makes of
%   the file. With REGISTRY empty the index is built once per shared cache.
%
%   See also did2.schema.termRegistered, did2.build.unregisteredTerms.

arguments
    registry = []   % a parsed term_registry_meta.json, or [] for the shared cache's
end

persistent lastCache lastIx
if isempty(registry)
    try
        c = did2.schema.cache.shared();
    catch
        ix = buildIndex(struct());
        return;
    end
    if ~isempty(lastCache) && isvalid(lastCache) && lastCache == c && ~isempty(lastIx)
        ix = lastIx;
        return;
    end
    ix = buildIndex(c.termRegistry);
    lastCache = c;
    lastIx = ix;
    return;
end
ix = buildIndex(registry);
end

% ===================== helpers =============================================

function ix = buildIndex(registry)
arguments
    registry % a parsed term_registry_meta.json
end

ix = struct('present', false, 'count', 0, ...
    'byNode', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'byName', containers.Map('KeyType', 'char', 'ValueType', 'any'));
if ~isstruct(registry) || ~isscalar(registry) || ~isfield(registry, 'terms')
    return;
end
terms = registry.terms;
if iscell(terms)
    terms = [terms{:}];
end
ix.present = true;
for k = 1:numel(terms)
    e = struct('node', textOf(terms(k), 'node'), 'name', textOf(terms(k), 'name'), ...
        'status', textOf(terms(k), 'status'));
    if ~isempty(e.node)
        ix.byNode(did2.schema.curieKey(e.node)) = e;
    end
    if ~isempty(e.name)
        ix.byName(lower(e.name)) = e;
    end
end
ix.count = numel(terms);
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
