function ctx = batchContext(docs)
%BATCHCONTEXT An index of a whole migrated batch, for inverses that read
%   documents other than the ones their source became.
%
%   CTX = batchContext(DOCS). DOCS is the FINAL batch, a cell of structs (each
%   did2.document's toStruct). CTX is a struct:
%
%     docs       DOCS itself
%     byId       containers.Map base.id -> position in DOCS (the first, when
%                an id repeats)
%     referrers  containers.Map id -> the positions of every document whose
%                depends_on names that id, in batch order. The `session_id`
%                edge is not indexed: every document has one, and no inverse
%                looks a document up by the session it is in.
%
%   WHY. Some v1 values are kept by V2 on documents a batch pass made and no
%   source became: the documents an ingested epoch's probe map decomposes
%   into (did2.convert.resolveEpochProbemap), the per-system time references
%   a clock mapping's ends are read from (did2.convert.epochMint). The
%   whole-batch round trip ([whole-batch round trip], Jess Haley, 2026-10-27)
%   hands such an inverse this index, so it reads them where they are rather
%   than from its own documents only. Read with ctxDoc and ctxReferrers.
%
%   See also did2.convert.roundtrip.wholeBatch, did2.convert.roundtrip.check.

n = numel(docs);
ctx = struct('docs', {docs}, ...
    'byId', containers.Map('KeyType', 'char', 'ValueType', 'double'), ...
    'referrers', containers.Map('KeyType', 'char', 'ValueType', 'any'));
perDoc = cell(1, n);
counts = zeros(1, n);
for k = 1:n
    b = docs{k};
    perDoc{k} = cell(1, 0);
    if ~isstruct(b) || ~isscalar(b)
        continue;
    end
    if isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
        id = char(b.base.id);
        if ~isempty(id) && ~isKey(ctx.byId, id)
            ctx.byId(id) = k;
        end
    end
    perDoc{k} = edgeTargets(b);
    counts(k) = numel(perDoc{k});
end
targets = [perDoc{:}];
from = repelem(1:n, counts);
if isempty(targets)
    return;
end
[u, ~, j] = unique(targets);
groups = accumarray(j(:), from(:), [numel(u), 1], @(x) {reshape(sort(x), 1, [])});
for g = 1:numel(u)
    ctx.referrers(u{g}) = groups{g};
end
end

function t = edgeTargets(b)
% every id B's depends_on names, except its session edge
t = cell(1, 0);
if ~isfield(b, 'depends_on') || isempty(b.depends_on)
    return;
end
deps = b.depends_on;
if isstruct(deps)
    deps = num2cell(reshape(deps, 1, []));
elseif ~iscell(deps)
    return;
end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || strcmp(char(d.name), 'session_id')
        continue;
    end
    v = '';
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = d.document_id;
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = d.value;
    end
    if ischar(v) || (isstring(v) && isscalar(v))
        t{end+1} = char(v); %#ok<AGROW>
    end
end
end
