function c = compression(codec, options)
%COMPRESSION A body's `compression`, in the form the schema in use declares.
%
%   C = did2.build.compression(CODEC) returns CODEC ready to write into
%   `data_body.compression`. THE ONE PLACE that decides the form, as
%   did2.build.formatTerm is for `format`:
%
%     the {term, parameters} block   once the loaded schema declares it
%                    ([compression block and empty levels] (1), Decided by
%                    Jess Haley, 2026-10-26, did-schema
%                    V_eta_go_forward_class_audit.md; did-schema issue #137;
%                    did2.build.compressionBlockDeclared): the codec as a
%                    term, its settings as parameters -- the entry shape of a
%                    method's parameters ({variable, ...} plus one value form)
%     char           while did-schema still types `compression` as `char`:
%                    the codec's spelling, verbatim ('blosc-zstd' stays
%                    'blosc-zstd', [lossless means round trip])
%
%   C = did2.build.compression(CODEC, 'Settings', S) also gives the codec's
%   settings: a scalar struct of key -> value as the source wrote them (a v1
%   lightsheetZarrLevel's decoded `codec_params`,
%   struct('cname','zstd','clevel',5,'shuffle',1,'blocksize',0)). Each
%   becomes one parameter, in order: the inner compressor (`cname`) as a
%   `term` (the table's term for its spelling, 'zstd' -> Zstandard, looked up
%   in the term registry; else its spelling as the name), any other char
%   value as `text`, a logical as `logical`, an integer as `count`, any other
%   real number as `quantity.value`. The parameter's variable is named by the key's row in
%   the shared table (cname -> 'inner compressor', clevel -> 'compression
%   level', shuffle -> 'shuffle filter', blocksize -> 'compression block
%   size': the labels of EMPTY:0000430, 0000427, 0000429 and 0000428,
%   [compression term definitions approved], Jess Haley, 2026-11-01), else by
%   the key itself.
%
%   CODEC may be:
%     a spelling (char/string)   'gzip', 'lzw', 'blosc-zstd', ...: the term is
%                                the table's term for it ('blosc-zstd' ->
%                                'Blosc', with the inner compressor 'zstd'
%                                written as a parameter), else the spelling as
%                                a name; either is looked up in the term
%                                registry (name, then `synonyms`) and written
%                                as the registered {node, name} when found
%     a {node, name} term        the codec's term, used as given
%     a {term, parameters} block as read from a V_eta document: checked and
%                                re-written for the schema in use
%     '' or []                   returned as [] (absent): stored uncompressed
%
%   On a schema that types `compression` as char, settings beyond what the
%   spelling itself states (a Blosc spelling's own inner compressor) have no
%   home: did2:build:compressionSettingsNotDeclared. A caller with such
%   settings asks did2.build.compressionBlockDeclared first and carries what
%   it cannot place (lightsheet_zarr_level).
%
%   Errors:
%     did2:build:compressionSettingsNotDeclared   settings on a char schema
%     did2:build:compressionConflict              a setting that contradicts
%                                                 the spelling ('blosc-zstd'
%                                                 with cname 'lz4')
%     did2:build:typeMismatch                     a CODEC or a setting value
%                                                 of a form not listed above
%
%   See also did2.build.compressionCodec, did2.build.compressionBlockDeclared,
%            did2.build.formatTerm.

arguments
    codec = []
    options.Settings = []
    options.SchemaCache = []
end

c = [];
settings = asSettings(options.Settings);
declared = did2.build.compressionBlockDeclared(options.SchemaCache);

% a block or a bare term as read from a V_eta document
if isstruct(codec)
    if ~isscalar(codec)
        error('did2:build:typeMismatch', ...
            'A body''s compression is one codec: a spelling, a {node, name} term or a {term, parameters} block.');
    end
    if declared && isfield(codec, 'term')
        if ~isempty(fieldnames(settings))
            error('did2:build:typeMismatch', ...
                'Give the settings in the block''s parameters or as ''Settings'', not both.');
        end
        c = did2.build.composite('sampled_body', 'compression', codec, ...
            'SchemaCache', options.SchemaCache);
        return;
    end
    if declared   % a bare {node, name} term
        block = struct('term', codec);
        entries = entriesOf(settings, options.SchemaCache);
        if ~isempty(entries)
            block.parameters = entries;
        end
        c = did2.build.composite('sampled_body', 'compression', block, ...
            'SchemaCache', options.SchemaCache);
        return;
    end
    % a char schema: the block's spelling (its settings must state nothing more)
    [spelling, fromBlock] = did2.build.compressionCodec(codec);
    settings = mergeSettings(fromBlock, settings);
    codec = spelling;
end

if isstring(codec) && isscalar(codec)
    codec = char(codec);
end
if isempty(codec)
    if ~isempty(fieldnames(settings))
        error('did2:build:typeMismatch', 'Codec settings were given with no codec.');
    end
    return;
end
if ~ischar(codec) || size(codec, 1) > 1
    error('did2:build:typeMismatch', ...
        'A body''s compression is one codec: a spelling, a {node, name} term or a {term, parameters} block.');
end
spelling = strtrim(codec);
[termName, inner] = codecRow(spelling);
if ~isempty(inner) && isfield(settings, 'cname') ...
        && ~strcmpi(strtrim(char(settings.cname)), inner)
    error('did2:build:compressionConflict', ...
        'The codec "%s" names the inner compressor "%s"; its settings say cname "%s".', ...
        spelling, inner, char(settings.cname));
end

if ~declared
    beyond = setdiff(fieldnames(settings), {'cname'}, 'stable');
    if ~isempty(beyond) || (isfield(settings, 'cname') && isempty(inner))
        if isempty(beyond); beyond = {'cname'}; end
        error('did2:build:compressionSettingsNotDeclared', ...
            ['The loaded schema types data_body.compression as char, which holds the ' ...
             'codec name only; the settings %s have no home until it declares the ' ...
             '{term, parameters} block ([compression block and empty levels]).'], ...
            strjoin(beyond, ', '));
    end
    c = spelling;
    return;
end

% the block: the codec as a term, its settings as parameters
if ~isempty(inner) && ~isfield(settings, 'cname')
    % the inner compressor the spelling names, written first
    settings = mergeSettings(struct('cname', inner), settings);
end
block = struct('term', registered(termName, spelling, options.SchemaCache));
entries = entriesOf(settings, options.SchemaCache);
if ~isempty(entries)
    block.parameters = entries;
end
c = did2.build.composite('sampled_body', 'compression', block, ...
    'SchemaCache', options.SchemaCache);
end

% ===================== helpers =============================================

function s = asSettings(v)
%ASSETTINGS The 'Settings' option as a scalar struct (struct() when none). A
%   JSON object as text (a v1 codec_params) is decoded.
if isempty(v)
    s = struct();
    return;
end
if ischar(v) || (isstring(v) && isscalar(v))
    try
        v = jsondecode(char(v));
    catch
        error('did2:build:typeMismatch', 'Codec settings given as text must be one JSON object.');
    end
    if isempty(v)
        s = struct();
        return;
    end
end
if ~isstruct(v) || ~isscalar(v)
    error('did2:build:typeMismatch', 'Codec settings are one struct of key -> value.');
end
s = v;
end

function s = mergeSettings(first, then)
s = first;
names = fieldnames(then);
for k = 1:numel(names)
    s.(names{k}) = then.(names{k});
end
end

function [termName, inner] = codecRow(spelling)
t = compressionTable();
termName = spelling;
inner = '';
for r = 1:size(t.codecs, 1)
    if strcmpi(t.codecs{r, 1}, spelling)
        termName = t.codecs{r, 2};
        inner = t.codecs{r, 3};
        return;
    end
end
end

function entries = entriesOf(settings, schemaCache)
%ENTRIESOF One parameter entry per setting, in order: {variable, <one value>}.
t = compressionTable();
names = fieldnames(settings);
entries = cell(1, numel(names));
for k = 1:numel(names)
    key = names{k};
    label = key;
    row = find(strcmp(t.settings(:, 1), key), 1);
    if ~isempty(row)
        label = t.settings{row, 2};
    end
    e = struct('variable', registered(label, '', schemaCache));
    v = settings.(key);
    if isstring(v) && isscalar(v); v = char(v); end
    if ischar(v) && strcmp(key, 'cname')
        % [compression terms registered] (Jess Haley, 2026-11-01): the inner
        % compressor is a codec, so a term (wikidata:Q26737171 Zstandard)
        e.term = registered(compressorName(t, v), strtrim(v), schemaCache);
    elseif ischar(v)
        e.text = v;
    elseif islogical(v) && isscalar(v)
        e.logical = v;
    elseif isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v == round(v)
        e.count = double(v);
    elseif isnumeric(v) && isscalar(v) && isreal(v)
        e.quantity = struct('value', double(v));
    else
        error('did2:build:typeMismatch', ...
            'Codec setting "%s" is a %s; a setting is one text, logical or number.', ...
            key, class(v));
    end
    entries{k} = e;
end
if isempty(entries)
    entries = [];
end
end

function name = compressorName(t, spelling)
% the term name the table gives an inner compressor's spelling, else the
% spelling itself
name = strtrim(spelling);
row = find(strcmpi(t.compressors(:, 1), name), 1);
if ~isempty(row)
    name = t.compressors{row, 2};
end
end

function t = registered(name, spelling, schemaCache)
%REGISTERED NAME as the term registry writes it: its registered {node, name}
%   when a row's name, or one of its `synonyms`, matches NAME or SPELLING
%   (ignoring case and spacing, did2.schema.termNameKey); else NAME with no
%   node (the builder's rule for a term given as text).
t = struct('node', '', 'name', name);
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
want = {did2.schema.termNameKey(name)};
if ~isempty(spelling)
    want{end+1} = did2.schema.termNameKey(spelling);
end
for pass = 1:2
    for k = 1:numel(rows)
        r = rows{k};
        if ~isstruct(r) || ~isfield(r, 'name'); continue; end
        if pass == 1
            names = {char(r.name)};
        else
            names = synonymsOf(r);
        end
        if any(ismember(cellfun(@did2.schema.termNameKey, names, 'UniformOutput', false), want))
            node = '';
            if isfield(r, 'node') && ~isempty(r.node); node = char(r.node); end
            t = struct('node', node, 'name', char(r.name));
            return;
        end
    end
end
end

function c = synonymsOf(r)
c = {};
if ~isfield(r, 'synonyms') || isempty(r.synonyms); return; end
v = r.synonyms;
if ischar(v) || isstring(v)
    c = cellstr(v);
elseif iscell(v)
    c = v(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v));
    c = cellfun(@char, c, 'UniformOutput', false);
end
c = reshape(c, 1, []);
end
