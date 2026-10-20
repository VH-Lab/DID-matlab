function ix = curiePrefixIndex(registry)
%CURIEPREFIXINDEX Every name a reader accepts for each CURIE prefix.
%
%   IX = did2.schema.curiePrefixIndex(REGISTRY) reads a parsed
%   CURIE_lookups_meta.json and returns what did2.schema.curieKey and
%   did2.schema.curieSpelling need to read a prefix the way the schema says
%   to (DID-schema V_eta_prefix_spelling_plan.md, signed 2026-10-19):
%
%     "readers match a prefix by key, spelling or synonym, ignoring case;
%      registry keys stay the lowercase Bioregistry prefixes."
%
%   IX is a struct of four containers.Map:
%     names      lower(name) -> registry key, for the entry's key, its
%                `spelling` and every one of its `synonyms`
%     spelling   registry key -> the prefix as a document writes it
%     legacy     lower(old prefix) -> {registry key, id prefix}, from the
%                entry's `legacy_rewrite` (`WBStrain:00004246` is read as
%                `WormBase:WBStrain00004246`, `format:1929` as
%                `EDAM:format_1929`)
%     writtenAs  registry key -> {registry key, id prefix}, from the entry's
%                `written_as` (`cellosaurus:0030` is `RRID:CVCL_0030`)
%
%   REGISTRY ([] = the shared schema cache's) is the struct jsondecode makes
%   of CURIE_lookups_meta.json. jsondecode turns a key it cannot use as a
%   field name into one it can (`pubchem.compound` -> `pubchem_compound`), so
%   the keys here are those field names; curieKey compares a document's
%   prefix both as written and in that form.
%
%   A registry with no `prefixes`, or one written before entries carried a
%   `spelling` (V_delta's `_prefixes`, V_zeta), gives an index that knows
%   each entry by its key alone, so a reader still matches prefixes ignoring
%   case.
%
%   With REGISTRY empty the index is built once per shared cache and reused,
%   because the census calls curieKey once per document.
%
%   See also did2.schema.curieKey, did2.schema.curieSpelling.

arguments
    registry = []   % a parsed CURIE_lookups_meta.json, or [] for the shared cache's
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
    ix = buildIndex(c.curieRegistry);
    lastCache = c;
    lastIx = ix;
    return;
end
ix = buildIndex(registry);
end

% ===================== helpers =============================================

function ix = buildIndex(registry)
arguments
    registry % a parsed CURIE_lookups_meta.json
end

ix = struct( ...
    'names', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'spelling', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'legacy', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'writtenAs', containers.Map('KeyType', 'char', 'ValueType', 'any'));
if ~isstruct(registry) || ~isscalar(registry) || ~isfield(registry, 'prefixes') ...
        || ~isstruct(registry.prefixes)
    return;
end
keys = fieldnames(registry.prefixes);
for i = 1:numel(keys)
    k = keys{i};
    e = registry.prefixes.(k);
    sp = textOf(e, 'spelling');
    if isempty(sp)
        sp = k;
    end
    ix.spelling(k) = sp;
    names = [{k}, textList(e, 'synonyms')];
    if isfield(e, 'written_as') && isstruct(e.written_as)
        % spelled through another entry, so its spelling names that entry
        ix.writtenAs(k) = {matlab.lang.makeValidName(textOf(e.written_as, 'prefix')), ...
            textOf(e.written_as, 'id_prefix')};
    else
        names{end+1} = sp; %#ok<AGROW>
    end
    if isfield(e, 'legacy_rewrite') && isstruct(e.legacy_rewrite)
        old = textOf(e.legacy_rewrite, 'legacy_prefix');
        if ~isempty(old)
            ix.legacy(lower(old)) = {k, textOf(e.legacy_rewrite, 'id_prefix')};
        end
    end
    for n = 1:numel(names)
        nm = lower(names{n});
        if ~isempty(nm) && ~isKey(ix.names, nm)
            ix.names(nm) = k;
        end
    end
end
end

function v = textOf(s, f)
arguments
    s struct
    f {mustBeText}
end

v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = char(s.(f));
end
end

function list = textList(s, f)
arguments
    s struct
    f {mustBeText}
end

list = {};
if ~isfield(s, f) || isempty(s.(f))
    return;
end
v = s.(f);
if ischar(v) || isstring(v)
    list = cellstr(v);
elseif iscell(v)
    list = v(cellfun(@(x) ischar(x) || isstring(x), v));
    list = cellfun(@char, list, 'UniformOutput', false);
end
list = reshape(list, 1, []);
end
