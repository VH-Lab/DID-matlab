function ix = retiredIndex(meta)
%RETIREDINDEX The classes the schema retires, indexed by class name.
%
%   IX = did2.schema.retiredIndex(META) reads a parsed
%   class_disposition_meta.json (did-schema stable/, derived from the
%   hand-written `disposition` column of schemas/V_eta/index.json) of the shape
%
%       {"retired": [{"class_name": "...", "replaced_by": ["..."] or [],
%                     "decision": "<document> [<tag>]" or ""}, ...]}
%
%   and returns a struct:
%     present  false when the schema in use has no such file (or the file has
%              no `retired` list): nothing is retired, nothing is refused
%     count    the number of retired classes listed (0 for an empty list)
%     byName   class_name -> struct('class_name', char, 'replaced_by', cellstr,
%              'decision', char)
%
%   META ([] = the shared schema cache's) is the struct jsondecode makes of
%   the file. With META empty the index is built once per shared cache.
%
%   Decided by Jess Haley, 2026-10-24 [V2 builder refuses retired]
%   (did-schema V_eta_go_forward_class_audit.md): "did2.build refuses to
%   create a new document of a class whose disposition is retire, naming its
%   replacement where one is recorded; reading v1 and the generic migration
%   are not affected."
%
%   See also did2.build.document, did2.schema.cache/strictMode.

arguments
    meta = []   % a parsed class_disposition_meta.json, or [] for the shared cache's
end

persistent lastCache lastIx
if isempty(meta)
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
    ix = buildIndex(c.classDisposition);
    lastCache = c;
    lastIx = ix;
    return;
end
ix = buildIndex(meta);
end

% ===================== helpers =============================================

function ix = buildIndex(meta)
arguments
    meta % a parsed class_disposition_meta.json
end

ix = struct('present', false, 'count', 0, ...
    'byName', containers.Map('KeyType', 'char', 'ValueType', 'any'));
if ~isstruct(meta) || ~isscalar(meta) || ~isfield(meta, 'retired')
    return;
end
ix.present = true;
rows = meta.retired;
if isempty(rows)
    return;   % "retired": [] decodes to [] -- nothing is retired
end
if iscell(rows)
    rows = rows(:)';
else
    rows = arrayfun(@(r) r, rows(:)', 'UniformOutput', false);
end
for k = 1:numel(rows)
    r = rows{k};
    if ~isstruct(r)
        continue;
    end
    name = textOf(r, 'class_name');
    if isempty(name)
        continue;
    end
    e = struct('class_name', name, ...
        'replaced_by', {namesOf(r, 'replaced_by')}, ...
        'decision', textOf(r, 'decision'));
    ix.byName(name) = e;
end
ix.count = ix.byName.Count;
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

function c = namesOf(s, f)
% a list of class names: jsondecode gives [] for [], a cell of char for a
% list of strings, and (for a lone string written without brackets) a char
arguments
    s struct
    f {mustBeText}
end

c = {};
if ~isfield(s, f) || isempty(s.(f))
    return;
end
v = s.(f);
if ischar(v) || (isstring(v) && isscalar(v))
    c = {strtrim(char(v))};
elseif isstring(v)
    c = cellstr(v(:)');
elseif iscell(v)
    c = cellfun(@(x) strtrim(char(x)), v(:)', 'UniformOutput', false);
end
c = c(~cellfun(@isempty, c));
end
