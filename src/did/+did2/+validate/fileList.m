function report = fileList(docs, opts)
%FILELIST Do the documents carry the files their class declares?
%
%   REPORT = did2.validate.fileList(DOCS) compares each document's
%   `files.file_list` against the file names declared by its class chain, and
%   reports both directions.
%
%   ---------------------------------------------------------------------
%   WHY THIS EXISTS  (#64)
%   ---------------------------------------------------------------------
%   A V_eta class declares its payload files (`spike_cluster.bin`, `data.bin`,
%   `level_k.bin`, ...) and a document carries them in `files.file_list`. NOTHING
%   compares the two. `+did2/+schema/cache.m:598` allows `file`/`files` as a
%   top-level key and never looks inside, so:
%
%     DECLARED BUT ABSENT   a migrator that forgets to carry the attachment
%                           produces a document whose class says the bytes are
%                           there and which has none. It validates. The payload
%                           is gone and no counter sees it -- the same shape as
%                           the invented-empty-edge pattern, one tier over.
%     PRESENT BUT UNDECLARED  a migrator carries bytes the target class does not
%                           declare. They survive but nothing can find them, and
%                           the tombstone is wrong about what the class holds.
%
%   The first direction is the one that loses data. `data.bin` was dropped from
%   `daqmetadatareader_epochdata_ingested` exactly this way and was found by hand.
%
%   ---------------------------------------------------------------------
%   REPORT FIELDS
%   ---------------------------------------------------------------------
%     total_docs             documents inspected (HANDED IN, not parsed -- an
%                            unreadable document is counted and reported, never
%                            silently dropped; see +validate/private/vBodies.m)
%     skipped_docs           documents whose class or schema could not be resolved
%     docs_with_files        documents carrying a non-empty file_list
%     declared_but_absent    struct array {class_name, file_name, count}
%     present_but_undeclared struct array {class_name, file_name, count}
%     declared_absent_count / present_undeclared_count  total occurrences
%
%   A CLASS THAT DECLARES NO FILES AND CARRIES NONE IS NOT REPORTED -- that is
%   the overwhelming majority, and a report that lists it says nothing.
%
%   Name/value:
%     'SchemaCache'  a did2.schema.cache (defaults to the shared singleton)

arguments
    docs
    opts.SchemaCache = []
end

report = struct( ...
    'total_docs',              0, ...
    'skipped_docs',            0, ...
    'docs_with_files',         0, ...
    'declared_but_absent',     struct('class_name', {}, 'file_name', {}, 'count', {}), ...
    'present_but_undeclared',  struct('class_name', {}, 'file_name', {}, 'count', {}), ...
    'declared_absent_count',   0, ...
    'present_undeclared_count', 0);

[bodies, unreadable] = vBodies(docs);   % shared with silentLoss (+validate/private)
report.total_docs = numel(bodies) + unreadable;
report.skipped_docs = unreadable;
if isempty(bodies); return; end

cache = opts.SchemaCache;
if isempty(cache)
    try
        cache = did2.schema.cache.shared();
    catch
        report.skipped_docs = numel(bodies);
        return;   % no schema available -- report nothing rather than guess
    end
end

absKeys = {}; absCounts = [];
undKeys = {}; undCounts = [];

for k = 1:numel(bodies)
    body = bodies{k};
    % The audit must never be able to break a migration -- anything unresolvable
    % is counted as skipped, exactly as silentLoss does.
    try
        className = classNameOf(body);
        if isempty(className)
            report.skipped_docs = report.skipped_docs + 1; continue;
        end
        declared = declaredFiles(cache, className);
        carried  = carriedFiles(body);
        if ~isempty(carried); report.docs_with_files = report.docs_with_files + 1; end
        if isempty(declared) && isempty(carried); continue; end

        for d = 1:numel(declared)
            if ~any(strcmp(declared{d}, carried))
                [absKeys, absCounts] = bump(absKeys, absCounts, ...
                    sprintf('%s|%s', className, declared{d}));
            end
        end
        for c = 1:numel(carried)
            if ~any(strcmp(carried{c}, declared))
                [undKeys, undCounts] = bump(undKeys, undCounts, ...
                    sprintf('%s|%s', className, carried{c}));
            end
        end
    catch
        report.skipped_docs = report.skipped_docs + 1;
    end
end

report.declared_but_absent = explode(absKeys, absCounts);
report.present_but_undeclared = explode(undKeys, undCounts);
report.declared_absent_count = sum(absCounts);
report.present_undeclared_count = sum(undCounts);
end

% ===================== helpers =============================================

function names = declaredFiles(cache, className)
%DECLAREDFILES Every file name declared anywhere in the class chain.
names = {};
try
    chain = cache.classChain(className);
catch
    chain = {className};
end
for i = 1:numel(chain)
    try
        c = cache.getClass(chain{i});
    catch
        continue;
    end
    if ~isstruct(c) || ~isfield(c, 'file'); continue; end
    f = c.file;
    for j = 1:numel(f)
        entry = f(j);
        if iscell(entry); entry = entry{1}; end
        if isstruct(entry) && isfield(entry, 'name')
            names{end+1} = char(entry.name); %#ok<AGROW>
        elseif ischar(entry)
            names{end+1} = entry; %#ok<AGROW>
        end
    end
end
names = unique(names);
end

function names = carriedFiles(body)
%CARRIEDFILES The document's own file_list, accepting both spellings NDI uses.
names = {};
raw = [];
if isfield(body, 'files') && isstruct(body.files) && isfield(body.files, 'file_list')
    raw = body.files.file_list;
elseif isfield(body, 'file') && isstruct(body.file) && isfield(body.file, 'file_list')
    raw = body.file.file_list;
end
if isempty(raw); return; end
if ischar(raw); raw = {raw}; end
if ~iscell(raw); return; end
for i = 1:numel(raw)
    v = raw{i};
    if isstruct(v) && isfield(v, 'name'); v = v.name; end
    if ischar(v) && ~isempty(v); names{end+1} = v; end %#ok<AGROW>
end
names = unique(names);
end

function cn = classNameOf(body)
cn = '';
if isfield(body, 'document_class') && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    cn = char(body.document_class.class_name);
end
end

function [keys, counts] = bump(keys, counts, key)
idx = find(strcmp(key, keys), 1);
if isempty(idx)
    keys{end+1} = key; counts(end+1) = 1; %#ok<AGROW>
else
    counts(idx) = counts(idx) + 1;
end
end

function out = explode(keys, counts)
out = struct('class_name', {}, 'file_name', {}, 'count', {});
for i = 1:numel(keys)
    parts = strsplit(keys{i}, '|');
    out(end+1) = struct('class_name', parts{1}, 'file_name', parts{2}, ...
        'count', counts(i)); %#ok<AGROW>
end
end
