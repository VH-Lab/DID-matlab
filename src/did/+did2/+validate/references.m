function report = references(docs, opts)
%REFERENCES Validate did2 document `depends_on` referential integrity.
%
%   REPORT = did2.validate.references(DOCS) checks that every
%   non-empty `depends_on[i].document_id` on every document in
%   DOCS resolves to the id of another document in DOCS. Edges
%   whose document_id is empty (the schema's `mustBeNonEmpty=false`
%   case) are skipped — they represent intentionally unfilled
%   optional dependencies. The function also tolerates the earlier
%   draft key `value` and the raw v1 key `id` on input, so it
%   works on bodies at any stage of the migration pipeline.
%
%   REPORT = did2.validate.references(DOCS, 'Database', DB) also
%   accepts edges that resolve to documents already stored in DB
%   (a `did2.database.sqlitedb` instance). Use this when validating
%   an incremental import batch against a populated database.
%
%   REPORT = did2.validate.references(..., 'KnownIds', IDS) lets
%   the caller pass a cell array of additional `did_uid` strings
%   that should be treated as resolvable (e.g., IDs from a prior
%   batch that has not yet been committed).
%
%   REPORT is a struct with fields:
%       total_docs       - number of documents inspected
%       edges_examined   - number of non-empty depends_on edges
%       orphans          - struct array (one entry per dangling
%                          edge) with fields:
%                              doc_id          - id of the source document
%                              doc_class       - className() of the source
%                              edge_name       - depends_on[i].name
%                              edge_document_id - the unresolved id string
%       orphan_count     - numel(orphans)
%
%   The function does not throw on orphan edges — it returns a
%   report so callers can decide how to react (quarantine the batch,
%   log + continue, etc).
%
%   Example
%   -------
%       result = did2.convert.v1_to_v2(v1Docs);
%       refReport = did2.validate.references(result.migrated);
%       if refReport.orphan_count > 0
%           error('Migration would create %d orphan depends_on edges.', ...
%               refReport.orphan_count);
%       end
%
%   See also: did2.document, did2.database.sqlitedb,
%             did2.convert.v1_to_v2.

arguments
    docs
    opts.Database = []
    opts.KnownIds (1,:) cell = {}
end

list = normaliseDocList(docs);

knownIds = struct();
for k = 1:numel(list)
    id = docId(list{k});
    if ~isempty(id)
        knownIds.(idKey(id)) = true;
    end
end
for k = 1:numel(opts.KnownIds)
    extra = char(opts.KnownIds{k});
    if ~isempty(extra)
        knownIds.(idKey(extra)) = true;
    end
end

useDb = ~isempty(opts.Database);
if useDb
    dbIds = opts.Database.allIds();
    for k = 1:numel(dbIds)
        knownIds.(idKey(dbIds{k})) = true;
    end
end

orphans = struct('doc_id', {}, 'doc_class', {}, ...
    'edge_name', {}, 'edge_document_id', {});
edgesExamined = 0;
for k = 1:numel(list)
    doc = list{k};
    deps = dependsOnEntries(doc);
    sourceId = docId(doc);
    sourceClass = docClass(doc);
    for j = 1:numel(deps)
        documentId = char(deps{j}.document_id);
        if isempty(documentId)
            continue;
        end
        edgesExamined = edgesExamined + 1;
        if isfield(knownIds, idKey(documentId))
            continue;
        end
        orphans(end+1) = struct( ...
            'doc_id',           sourceId, ...
            'doc_class',        sourceClass, ...
            'edge_name',        char(deps{j}.name), ...
            'edge_document_id', documentId); %#ok<AGROW>
    end
end

report = struct( ...
    'total_docs',     numel(list), ...
    'edges_examined', edgesExamined, ...
    'orphans',        orphans, ...
    'orphan_count',   numel(orphans));
end

function list = normaliseDocList(docOrList)
if isa(docOrList, 'did2.document')
    list = num2cell(docOrList(:));
    return;
end
if iscell(docOrList)
    list = docOrList(:);
    return;
end
if isstruct(docOrList)
    list = num2cell(docOrList(:));
    return;
end
error('did2:validate:invalidInput', ...
    'docs must be a did2.document array, cell array, or struct array.');
end

function id = docId(doc)
if isa(doc, 'did2.document')
    id = char(doc.get('base.id'));
elseif isstruct(doc) && isfield(doc, 'base') && isfield(doc.base, 'id')
    id = char(doc.base.id);
else
    id = '';
end
end

function cls = docClass(doc)
if isa(doc, 'did2.document')
    cls = doc.className();
elseif isstruct(doc) && isfield(doc, 'document_class') ...
        && isfield(doc.document_class, 'class_name')
    cls = char(doc.document_class.class_name);
else
    cls = '';
end
end

function entries = dependsOnEntries(doc)
entries = {};
if isa(doc, 'did2.document')
    s = doc.toStruct();
elseif isstruct(doc)
    s = doc;
else
    return;
end
if ~isfield(s, 'depends_on') || isempty(s.depends_on)
    return;
end
d = s.depends_on;
for k = 1:numel(d)
    if isstruct(d)
        e = d(k);
    elseif iscell(d)
        e = d{k};
    else
        continue;
    end
    if ~isstruct(e) || ~isfield(e, 'name')
        continue;
    end
    % Tolerate V_delta canonical, the earlier `value` draft, and the
    % raw v1 `id` key so the validator can run mid-migration.
    if isfield(e, 'document_id')
        documentId = char(e.document_id);
    elseif isfield(e, 'value')
        documentId = char(e.value);
    elseif isfield(e, 'id')
        documentId = char(e.id);
    else
        continue;
    end
    entries{end+1} = struct( ...
        'name',        char(e.name), ...
        'document_id', documentId); %#ok<AGROW>
end
end

function key = idKey(id)
% Did uids are 16-hex_16-hex; struct fieldnames can't start with
% a digit. Prefix with 'k_' so any did_uid becomes a valid key.
key = ['k_', id];
end
