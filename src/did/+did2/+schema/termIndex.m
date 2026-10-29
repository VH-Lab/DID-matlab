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
%     byNode   curieKey(node) -> the registered term {node, name, status,
%              number_unit, equivalent} (number_unit: [] or the {node, name}
%              of the unit the term's number takes; equivalent: a cellstr of
%              the ids in other vocabularies that mean the same thing, {} when
%              the row states none or the registry predates the column --
%              [term equivalents recorded], Jess Haley, 2026-10-27)
%     byName   did2.schema.termNameKey(name) -> the registered term, for every
%              term (case, spaces, underscores and hyphens ignored: [term
%              names match ignoring spacing], Jess Haley, 2026-10-29)
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
if isstruct(terms)
    terms = num2cell(terms);   % one row per cell: rows may differ in keys
end
ix.present = true;
for k = 1:numel(terms)
    t = terms{k};
    if ~isstruct(t) || ~isscalar(t)
        continue;
    end
    e = struct('node', textOf(t, 'node'), 'name', textOf(t, 'name'), ...
        'status', textOf(t, 'status'), 'number_unit', unitOf(t), ...
        'equivalent', {equivalentOf(t)});
    if ~isempty(e.node)
        ix.byNode(did2.schema.curieKey(e.node)) = e;
    end
    if ~isempty(e.name)
        ix.byName(did2.schema.termNameKey(e.name)) = e;
    end
end
ix.count = numel(terms);
end

function c = equivalentOf(s)
% The row's `equivalent` list as a cellstr ({} when none).
c = {};
if ~isfield(s, 'equivalent') || isempty(s.equivalent)
    return;
end
v = s.equivalent;
if ischar(v) || isstring(v)
    c = cellstr(v);
elseif iscell(v)
    c = v(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v));
    c = cellfun(@char, c, 'UniformOutput', false);
end
c = reshape(c, 1, []);
end

function u = unitOf(s)
% The term's `number_unit` ({node, name}: the unit its number takes, [term-stated
% unit is generic], Jess Haley, 2026-10-26), or [] when the row states none
% (false, absent, or a registry that predates the field).
u = [];
if isfield(s, 'number_unit') && isstruct(s.number_unit) && isscalar(s.number_unit) ...
        && isfield(s.number_unit, 'name')
    u = struct('node', textOf(s.number_unit, 'node'), 'name', textOf(s.number_unit, 'name'));
end
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
