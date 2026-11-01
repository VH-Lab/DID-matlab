function [spelling, settings] = compressionCodec(value, options)
%COMPRESSIONCODEC Read a body's `compression` in either shape: the codec's
%   spelling and its settings.
%
%   [SPELLING, SETTINGS] = did2.build.compressionCodec(VALUE). VALUE is a
%   body's `data_body.compression` as stored:
%
%     char        (did-schema before [compression block and empty levels]):
%                 the codec's spelling; SETTINGS is struct()
%     {term, parameters} block ([compression block and empty levels] (1),
%                 Decided by Jess Haley, 2026-10-26, did-schema
%                 V_eta_go_forward_class_audit.md; issue #137): SPELLING is the
%                 term's source spelling and SETTINGS one key -> value per
%                 parameter, in order
%     a bare {node, name} term   as a block with no parameters
%     '' / [] / an absent field  '' and struct(): stored uncompressed
%
%   The inverse of did2.build.compression; both read one table
%   (+build/private/compressionTable.m). The term is matched to a spelling by
%   its name, its registered name and its registry `synonyms` (node first);
%   an unknown term reads as its own name. A Blosc term reads as
%   'blosc-<inner compressor>' when an `inner compressor` (cname) parameter
%   says which ('blosc-zstd'), else as the term's name. A parameter's variable
%   is read back to the setting key the table names for it ('compression
%   level' -> clevel), else to the variable's own name. A parameter's value is
%   its text, logical, count, quantity.value or term name; an inner
%   compressor written as a term reads back to the table's spelling
%   (Zstandard -> 'zstd').
%
%   Readers call this, never `strcmp` on the field, so they read both shapes
%   while the siblings move first (CLAUDE.md section 3, rule 2).
%
%   Options:
%     'SchemaCache'   a did2.schema.cache whose term registry resolves the
%                     term; default the shared one. Without a readable
%                     registry the term is matched by its own name.
%
%   Errors did2:build:typeMismatch when VALUE is none of the above.
%
%   See also did2.build.compression, did2.build.compressionBlockDeclared.

arguments
    value = []
    options.SchemaCache = []
end

spelling = '';
settings = struct();
if isempty(value)
    return;
end
if isstring(value) && isscalar(value)
    value = char(value);
end
if ischar(value)
    spelling = strtrim(value);
    return;
end
if iscell(value) && isscalar(value)
    value = value{1};
end
if ~isstruct(value) || ~isscalar(value)
    error('did2:build:typeMismatch', ...
        'A body''s compression is a codec name (char) or a {term, parameters} block.');
end
if isfield(value, 'term')
    term = value.term;
    params = [];
    if isfield(value, 'parameters'); params = value.parameters; end
elseif isfield(value, 'name') || isfield(value, 'node')
    term = value;   % a bare term
    params = [];
else
    error('did2:build:typeMismatch', ...
        'A body''s compression block has no `term`.');
end
if iscell(term) && isscalar(term); term = term{1}; end
if ~isstruct(term) || ~isscalar(term)
    term = struct('node', '', 'name', textOf(struct('v', term), 'v'));
end
name = textOf(term, 'name');
node = textOf(term, 'node');

t = compressionTable();
settings = settingsOf(params, t, options.SchemaCache);
if isempty(name) && isempty(node)
    if ~isempty(fieldnames(settings))
        error('did2:build:typeMismatch', ...
            'A body''s compression block has settings but no codec term.');
    end
    return;
end

keys = cellfun(@did2.schema.termNameKey, namesFor(name, node, options.SchemaCache), ...
    'UniformOutput', false);
rows = [];
for r = 1:size(t.codecs, 1)
    if any(strcmp(did2.schema.termNameKey(t.codecs{r, 2}), keys)) ...
            || any(strcmp(did2.schema.termNameKey(t.codecs{r, 1}), keys))
        rows(end+1) = r; %#ok<AGROW>
    end
end
if isempty(rows)
    spelling = name;
    if isempty(spelling); spelling = node; end
    return;
end
inners = t.codecs(rows, 3);
if all(cellfun(@isempty, inners))
    spelling = t.codecs{rows(1), 1};
    return;
end
% a codec whose spelling names its inner compressor (Blosc)
cname = '';
if isfield(settings, 'cname')
    cname = lower(strtrim(char(settings.cname)));
end
hit = find(strcmpi(inners, cname), 1);
if ~isempty(cname) && ~isempty(hit)
    spelling = t.codecs{rows(hit), 1};
elseif ~isempty(cname)
    spelling = [lower(t.codecs{rows(1), 2}) '-' cname];
else
    spelling = name;
end
end

% ===================== helpers =============================================

function s = settingsOf(params, t, schemaCache)
s = struct();
if isempty(params)
    return;
end
if isstruct(params); params = num2cell(reshape(params, 1, [])); end
if ~iscell(params)
    error('did2:build:typeMismatch', 'A compression block''s parameters are a list of entries.');
end
for k = 1:numel(params)
    e = params{k};
    if ~isstruct(e) || ~isfield(e, 'variable'); continue; end
    v = e.variable;
    if isstruct(v)
        label = textOf(v, 'name');
    else
        label = strtrim(char(v));
    end
    key = label;
    row = find(strcmp(cellfun(@did2.schema.termNameKey, t.settings(:, 2), 'UniformOutput', false), ...
        did2.schema.termNameKey(label)), 1);
    if ~isempty(row)
        key = t.settings{row, 1};
    end
    key = matlab.lang.makeValidName(key);
    v = valueOf(e);
    if strcmp(key, 'cname') && isfield(e, 'term') && isstruct(e.term)
        v = compressorSpelling(e.term, t, schemaCache);
    end
    s.(key) = v;
end
end

function spelling = compressorSpelling(term, t, schemaCache)
%COMPRESSORSPELLING An inner compressor written as a term, read back to the
%   spelling the table gives it ('Zstandard' or wikidata:Q26737171 -> 'zstd'),
%   by its name, its registered name and synonyms; else the term's name.
name = textOf(term, 'name');
node = textOf(term, 'node');
keys = cellfun(@did2.schema.termNameKey, namesFor(name, node, schemaCache), ...
    'UniformOutput', false);
spelling = name;
for r = 1:size(t.compressors, 1)
    if any(strcmp(did2.schema.termNameKey(t.compressors{r, 2}), keys)) ...
            || any(strcmp(did2.schema.termNameKey(t.compressors{r, 1}), keys))
        spelling = t.compressors{r, 1};
        return;
    end
end
end

function v = valueOf(e)
v = [];
if isfield(e, 'text') && ~isempty(e.text)
    v = char(e.text);
elseif isfield(e, 'logical') && ~isempty(e.logical)
    v = logical(e.logical);
elseif isfield(e, 'count') && ~isempty(e.count)
    v = double(e.count);
elseif isfield(e, 'quantity') && isstruct(e.quantity) && isfield(e.quantity, 'value') ...
        && ~isempty(e.quantity.value)
    v = double(e.quantity.value);
elseif isfield(e, 'term') && isstruct(e.term)
    v = textOf(e.term, 'name');
elseif isfield(e, 'text')
    v = '';
end
end

function names = namesFor(name, node, schemaCache)
%NAMESFOR The term's own name, plus the registry row's name and synonyms for
%   its node (or, with no node, for its name).
names = {};
if ~isempty(name); names{end+1} = name; end
try
    cache = schemaCache;
    if isempty(cache); cache = did2.schema.cache.shared(); end
    reg = cache.termRegistry;
catch
    return;
end
if ~isstruct(reg) || ~isscalar(reg) || ~isfield(reg, 'terms') || isempty(reg.terms)
    return;
end
rows = reg.terms;
if isstruct(rows); rows = num2cell(rows); end
for k = 1:numel(rows)
    r = rows{k};
    if ~isstruct(r); continue; end
    rnode = textOf(r, 'node');
    rname = textOf(r, 'name');
    if (~isempty(node) && ~isempty(rnode) && strcmpi(did2.schema.curieKey(rnode), did2.schema.curieKey(node))) ...
            || (isempty(node) && ~isempty(rname) && strcmp(did2.schema.termNameKey(rname), did2.schema.termNameKey(name)))
        if ~isempty(rname); names{end+1} = rname; end %#ok<AGROW>
        if isfield(r, 'synonyms') && ~isempty(r.synonyms)
            syn = r.synonyms;
            if ischar(syn) || isstring(syn); syn = cellstr(syn); end
            if iscell(syn)
                syn = syn(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), syn));
                names = [names, cellfun(@char, reshape(syn, 1, []), 'UniformOutput', false)]; %#ok<AGROW>
            end
        end
        return;
    end
end
end

function v = textOf(s, f)
v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = strtrim(char(s.(f)));
end
end
