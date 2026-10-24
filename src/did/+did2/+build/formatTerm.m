function f = formatTerm(format, schemaCache)
%FORMATTERM A body's `format`, in the form the schema in use declares.
%
%   F = did2.build.formatTerm(FORMAT) returns FORMAT ready to write into
%   `data_body.format`. THE ONE PLACE that decides the format's form, by
%   reading the field's DECLARED TYPE through the schema cache -- the same way
%   NDI's Haley import does (ndi.setup.conv.haley private/fileFormat.m):
%
%     ontology_term  (did-schema 877bbde on, lightsheet point 4, Jess
%                    2026-10-14): a {node, name} struct
%     char           (the pre-#73 tag v_eta-pre73, which test-fixtures.yml
%                    pinned until the 2026-10-21 migrator port):
%                    the media-type string the older schema expects
%
%   FORMAT may be:
%     a {node, name} struct   used as given (a missing half becomes '')
%     a CURIE char/string     the node; the name is filled from the table
%                             below when the CURIE is one of these, else ''
%     any other char/string   the NAME, no node -- the rule did2.build.document
%                             applies to every ontology_term given as text
%     '' or []                returned as [] (absent), so a caller's
%                             required-field check sees it missing
%
%   KNOWN FORMAT TERMS (checked on OLS by Jess, 2026-10-14; OME-Zarr minted in
%   EMPTY, Waltham-Data-Science/empty-ontology#22, not yet released), and the
%   media type each is written as on a char-format schema:
%     EDAM:format_3591  TIFF            image/tiff
%     EDAM:format_3997  MPEG-4          video/mp4
%     EDAM:format_2333  Binary format   application/octet-stream
%     EDAM:format_3915  Zarr            application/x-zarr
%     EMPTY:0000259     OME-Zarr        application/x-ome-zarr
%   On a char-format schema a term not in the table is written as its node (a
%   CURIE, as generic_file's format_ontology always was) or, with no node, as
%   its name (jSorterOutput's 'directory').
%
%   A CURIE is written as its registry entry's `spelling` (DID-schema
%   V_eta_prefix_spelling_plan.md, signed 2026-10-19), so the old EDAM form
%   'format:3591' is written 'EDAM:format_3591', and the table below is
%   matched by did2.schema.curieKey (prefix by key, spelling or synonym,
%   ignoring case).
%
%   SCHEMACACHE ([] = the shared one) is the cache whose `data_body` is read.
%   If the declared type cannot be read, the term form is used: it is the
%   current schema's.

arguments
    format = []
    schemaCache = []
end

f = [];
t = asTerm(format, prefixIndex(schemaCache));
if isempty(t)
    return;
end
if declaresCharFormat(schemaCache)
    f = mediaType(t, prefixIndex(schemaCache));
else
    f = t;
end
end

% ===================== helpers =============================================

function t = asTerm(format, index)
arguments
    format % a {node, name} struct, a CURIE or name as text, or empty
    index struct % a did2.schema.curiePrefixIndex
end

t = [];
if isempty(format)
    return;
end
if isstruct(format)
    t = struct('node', did2.schema.curieSpelling(textOf(format, 'node'), index), ...
        'name', textOf(format, 'name'));
    if isempty(t.name); t.name = knownName(t.node, index); end
    return;
end
if isstring(format) && isscalar(format), format = char(format); end
if ~ischar(format) || size(format, 1) > 1
    error('did2:build:typeMismatch', ...
        'A body''s format is a term: a {node, name} struct or a CURIE.');
end
format = strtrim(format);
if isempty(format)
    return;
end
if ~isempty(regexp(format, '^[A-Za-z][A-Za-z0-9_.-]*:[^\s/]+$', 'once'))
    node = did2.schema.curieSpelling(format, index);
    t = struct('node', node, 'name', knownName(node, index));
else
    t = struct('node', '', 'name', format);
end
end

function tf = declaresCharFormat(schemaCache)
%DECLARESCHARFORMAT True when the loaded schema types data_body.format as char.
arguments
    schemaCache % a did2.schema.cache, or [] for the shared one
end

tf = false;
try
    if isempty(schemaCache)
        schemaCache = did2.schema.cache.shared();
    end
    for cls = {'data_body', 'opaque_body', 'sampled_body'}
        try
            s = schemaCache.getClass(cls{1});
        catch
            continue;
        end
        if ~isfield(s, 'fields'); continue; end
        fields = s.fields;
        if isstruct(fields); fields = num2cell(fields); end
        for k = 1:numel(fields)
            fd = fields{k};
            if isfield(fd, 'name') && strcmp(fd.name, 'format') && isfield(fd, 'type')
                tf = any(strcmp(char(fd.type), {'char', 'string'}));
                return;
            end
        end
    end
catch
    tf = false;
end
end

function m = mediaType(t, index)
arguments
    t (1,1) struct
    index struct % a did2.schema.curiePrefixIndex
end

k = knownRow(t.node, index);
table = knownTable();
if ~isempty(k)
    m = table{k, 3};
elseif ~isempty(t.node)
    m = t.node;
else
    m = t.name;
end
end

function v = textOf(s, f)
arguments
    s struct
    f {mustBeText}
end

v = '';
if isfield(s, f) && ~isempty(s.(f))
    v = char(s.(f));
end
end

function name = knownName(curie, index)
arguments
    curie {mustBeText}
    index struct % a did2.schema.curiePrefixIndex
end

name = '';
if isempty(curie); return; end
table = knownTable();
k = knownRow(curie, index);
if ~isempty(k)
    name = table{k, 2};
end
end

function k = knownRow(curie, index)
%KNOWNROW The row of knownTable naming CURIE, [] if none. Compared by
%   did2.schema.curieKey, so a prefix matches by key, spelling or synonym.
arguments
    curie {mustBeText}
    index struct % a did2.schema.curiePrefixIndex
end

k = [];
if isempty(curie); return; end
table = knownTable();
want = did2.schema.curieKey(curie, index);
for r = 1:size(table, 1)
    if strcmpi(did2.schema.curieKey(table{r, 1}, index), want)
        k = r;
        return;
    end
end
end

function index = prefixIndex(schemaCache)
%PREFIXINDEX The CURIE prefix index of SCHEMACACHE, or of the shared cache.
arguments
    schemaCache % a did2.schema.cache, or [] for the shared one
end

index = did2.schema.curiePrefixIndex(struct());
try
    if isempty(schemaCache)
        index = did2.schema.curiePrefixIndex();
    else
        index = did2.schema.curiePrefixIndex(schemaCache.curieRegistry);
    end
catch
    % no readable registry: prefixes are still compared ignoring case
end
end

function table = knownTable()
table = { ...
    'EDAM:format_3591', 'TIFF',          'image/tiff'; ...
    'EDAM:format_3997', 'MPEG-4',        'video/mp4'; ...
    'EDAM:format_2333', 'Binary format', 'application/octet-stream'; ...
    'EDAM:format_3915', 'Zarr',          'application/x-zarr'; ...
    'EMPTY:0000259',    'OME-Zarr',      'application/x-ome-zarr'};
end
