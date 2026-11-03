function [records, report] = migrationRecord(docs, options)
%MIGRATIONRECORD The run's `migration` document and its report, an attached JSON file.
%
%   [RECORDS, REPORT] = did2.convert.migrationRecord(DOCS) returns the record
%   of the migration run that produced DOCS (a cell of did2.document: every
%   document the run writes), as two documents to write with them:
%
%     RECORDS{1}  a `migration` document: only its `method`, the term
%                 EDAM:operation_3434 "Conversion" and the run's parameters:
%                 software (IAO:0000010) "DID-matlab", version number
%                 (IAO:0000129) the DID-matlab commit, source format "did_v1"
%                 and target format "did_v2" (both plain text: their variables
%                 are not decided, [migration record details] (b)).
%     RECORDS{2}  an `opaque_body` owned by it, `format` EDAM:format_3464
%                 "JSON", whose file `body_data_0` is REPORT written as JSON
%                 (ingested when the documents are added to a
%                 did2.database.sqlitedb).
%
%   REPORT is did2.convert.migrationReport('collect', DOCS): `gaps`,
%   `carried_as_v1` and `counts`, with options.Counts added to `counts`.
%
%   Decided by Jess Haley, 2026-11-01 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md):
%     [migration record]   one standalone `migration` document per run, its
%                          method the conversion with the tool and its exact
%                          commit, the report its data body;
%     [migration method is conversion]  EDAM:operation_3434 "Conversion";
%     [migration report is an attached file]  the report is a JSON file
%                          attached as an opaque_body (owner_id the migration,
%                          format JSON) holding gaps, carried_as_v1 and
%                          counts, not fields on the migration document;
%     [migration record points at the dataset]  the record's required edge
%                          names the dataset the run migrated when there is
%                          one, and otherwise the session;
%     [migration record writer]  NDI-matlab writes it for an NDI migration,
%                          DID-matlab (did2.convert.fromV1Database) for a run
%                          that is DID-only.
%
%   THE EDGE. The record's `session_id` names the one dataset entity in DOCS
%   (an `entity` of type dataset). With none, the one session the documents
%   belong to: the one session entity in DOCS, else the one id their
%   `session_id` edges (or v1 base.session_id) name.
%
%   ONE RECORD PER DATASET (Decided by Jess Haley, 2026-11-03 [one migration
%   document per dataset]): "a run that migrates two or more datasets writes
%   one `migration` document per dataset, each pointing at its dataset with
%   its own attached report; a run with two or more sessions and no dataset
%   writes one per session". DOCS is split by the anchor each document belongs
%   to and each part gets its own record and report (RECORDS holds the pairs in
%   anchor order: {migration 1, report 1, migration 2, report 2, ...}; REPORT is
%   then a struct array, one per record, each with `anchor`). A document
%   belongs to a DATASET when it is that dataset entity, its `session_id` edge
%   names the dataset, or it (or its session) is a session that an
%   `included_in` directed_relation places in the dataset; to a SESSION when it
%   is that session entity or its `session_id` edge (v1 base.session_id) names
%   it. A document that belongs to none of them is not decided:
%   did2:convert:migrationAnchor, and nothing is written (pass 'Anchor' to
%   write one record for the whole run). options.Counts are the caller's
%   whole-run counts; with two or more records each report carries them under
%   `counts.run` instead of beside the record's own counts.
%
%   Options:
%     'Anchor'       the id the record's session_id edge names (default: as
%                    above)
%     'Counts'       a struct of run counts to add to REPORT.counts (a
%                    caller's own: source documents read, quarantined, ...)
%     'ReportFile'   where the JSON file is written (default: a file in
%                    tempdir named by the SHA-256 of its content; the
%                    database deletes it once ingested)
%     'Version'      the DID-matlab commit (default: read with git from this
%                    file's checkout; when it cannot be read the parameter is
%                    left out and REPORT.notes says why)
%     'Validate', 'SchemaCache'  as did2.build.document
%
%   An empty DOCS gives no records and an empty report.
%
%   See also did2.convert.migrationReport, did2.convert.fromV1Database.

arguments
    docs
    options.Anchor (1,:) char = ''
    options.Counts (1,1) struct = struct()
    options.ReportFile (1,:) char = ''
    options.Version (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

if ~iscell(docs)
    docs = num2cell(docs);
end
records = {};
report = did2.convert.migrationReport('collect', docs);
extra = fieldnames(options.Counts);
for k = 1:numel(extra)
    report.counts.(extra{k}) = options.Counts.(extra{k});
end
report.notes = {};
if isempty(docs)
    return;
end

anchor = options.Anchor;
if isempty(anchor)
    [anchors, groupOf] = anchorsOf(docs);
    if numel(anchors) > 1
        % [one migration document per dataset]: one record per anchor, each
        % from its own documents; the caller's counts are the whole run's
        parts = {};
        reports = [];
        for g = 1:numel(anchors)
            o = options;
            o.Anchor = anchors{g};
            o.Counts = struct();
            if ~isempty(options.ReportFile)
                [d, n, e] = fileparts(options.ReportFile);
                o.ReportFile = fullfile(d, sprintf('%s_%d%s', n, g, e));
            end
            args = namedArgs(o);
            [recs, rep1] = did2.convert.migrationRecord(docs(groupOf == g), args{:});
            rep1.counts.run = options.Counts;
            rep1.anchor = anchors{g};
            rep1 = orderfields(rep1);
            if ~isempty(recs)
                recs = rewriteReport(recs, rep1, o);
            end
            parts = [parts, recs]; %#ok<AGROW>
            if isempty(reports); reports = rep1; else; reports(end+1) = rep1; end %#ok<AGROW>
        end
        records = parts;
        report = reports;
        return;
    end
    anchor = anchors{1};
end

% the record is migration output: its plain-text parameter labels (source
% and target format, not decided) are not registry terms, as a migrator's own
% terms are not (did2.convert.v1_to_v2 disarms the check the same way)
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>

version = options.Version;
if isempty(version)
    [version, why] = toolCommit();
    if isempty(version)
        report.notes{end+1} = ['the DID-matlab commit could not be read (' why ...
            '), so the version number parameter is left out'];
    end
end
params = {did2.build.parameter(did2.build.term('IAO:0000010', 'software'), ...
    'Text', 'DID-matlab', 'SchemaCache', options.SchemaCache)};
if ~isempty(version)
    params{end+1} = did2.build.parameter(did2.build.term('IAO:0000129', 'version number'), ...
        'Text', version, 'SchemaCache', options.SchemaCache);
end
params{end+1} = did2.build.parameter('source format', 'Text', 'did_v1', ...
    'SchemaCache', options.SchemaCache);
params{end+1} = did2.build.parameter('target format', 'Text', 'did_v2', ...
    'SchemaCache', options.SchemaCache);
method = struct('term', did2.build.term('EDAM:operation_3434', 'Conversion'), ...
    'parameters', {did2.build.list(params{:})});

ts = did2.convert.migrationTime();
migrationId = did2.convert.mintId('migration', anchor);
rec = did2.build.document('migration', struct('method', method), ...
    'SessionId', anchor, 'Id', migrationId, 'CreationTimestamp', ts, ...
    'Validate', options.Validate, 'SchemaCache', options.SchemaCache);

file = options.ReportFile;
if isempty(file)
    % named by its content, so two runs that write the same report write the
    % same document (its location included)
    scratch = [tempname() '.json'];
    writeJson(scratch, report);
    file = fullfile(tempdir, ['did2_migration_report_' contentKey(scratch) '.json']);
    movefile(scratch, file, 'f');
else
    writeJson(file, report);
end
bodyId = did2.convert.mintId('migration report', migrationId);
body = did2.build.opaqueBody(migrationId, ...
    did2.build.term('EDAM:format_3464', 'JSON'), 'SessionId', anchor, ...
    'Id', bodyId, 'CreationTimestamp', ts, ...
    'Validate', options.Validate, 'SchemaCache', options.SchemaCache);
% the file's bytes: ingested (copied into the database's file store, then the
% temporary file deleted) when the documents are added to a
% did2.database.sqlitedb
% the file's uid is minted from its content: the same report is the same file,
% and a different report (another run on the same anchor, whose record ids
% are the same) is never refused as a uid stored with different bytes when
% two databases share a file store
fileUid = did2.convert.mintId('migration report file', contentKey(file));
body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 1, 'uid', fileUid, 'location', file, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
records = {did2.document(rec), did2.document(body)};
end

% =============================================================================

function [anchors, groupOf] = anchorsOf(docs)
% [migration record points at the dataset]: the dataset, else the session;
% [one migration document per dataset]: with two or more, every document's
% own (GROUPOF(k) indexes ANCHORS; all 1 with one anchor)
n = numel(docs);
structs = cell(1, n);
ids = repmat({''}, 1, n);
kinds = repmat({''}, 1, n);
sids = repmat({''}, 1, n);
datasets = {};
sessions = {};
edges = {};
datasetOfSession = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:n
    s = docs{k};
    if isa(s, 'did2.document')
        s = s.toStruct();
    end
    structs{k} = s;
    if ~isstruct(s) || ~isfield(s, 'base') || ~isfield(s.base, 'id')
        continue;
    end
    ids{k} = char(s.base.id);
    kinds{k} = entityKind(s);
    if strcmp(kinds{k}, 'dataset')
        datasets{end+1} = ids{k}; %#ok<AGROW>
    elseif strcmp(kinds{k}, 'session')
        sessions{end+1} = ids{k}; %#ok<AGROW>
    end
    sids{k} = sessionIdOf(s);
    if ~isempty(sids{k})
        edges{end+1} = sids{k}; %#ok<AGROW>
    end
    if isIncludedIn(s)
        c = edgeOf(s, 'child_id');
        p = edgeOf(s, 'parent_id');
        if ~isempty(c) && ~isempty(p)
            datasetOfSession(c) = p;
        end
    end
end
datasets = unique(datasets);
sessions = unique(sessions);
edges = unique(edges);
groupOf = ones(1, n);
if isscalar(datasets)
    anchors = datasets;
    return;
elseif numel(datasets) > 1
    anchors = datasets;
    for k = 1:n
        g = find(strcmp(datasets, ids{k}), 1);                        % the dataset
        if isempty(g); g = find(strcmp(datasets, sids{k}), 1); end    % names it
        if isempty(g)
            for sess = {ids{k}, sids{k}}                              % a session in it
                if ~isempty(sess{1}) && isKey(datasetOfSession, sess{1})
                    g = find(strcmp(datasets, datasetOfSession(sess{1})), 1);
                    if ~isempty(g); break; end
                end
            end
        end
        if isempty(g)
            unplacedError('dataset', datasets, ids{k});
        end
        groupOf(k) = g;
    end
    return;
end
if isscalar(sessions)
    anchors = sessions;
    return;
end
if isempty(sessions) && isscalar(edges)
    anchors = edges;
    return;
end
anchors = unique([sessions, edges]);
if isempty(anchors)
    error('did2:convert:migrationAnchor', ...
        ['The run''s documents name no dataset and no session, so its migration ' ...
         'record has nothing to point at. Pass ''Anchor''.']);
end
for k = 1:n
    g = [];
    if strcmp(kinds{k}, 'session'); g = find(strcmp(anchors, ids{k}), 1); end
    if isempty(g); g = find(strcmp(anchors, sids{k}), 1); end
    if isempty(g)
        unplacedError('session', anchors, ids{k});
    end
    groupOf(k) = g;
end
end

function unplacedError(kind, anchors, id)
error('did2:convert:migrationAnchor', ...
    ['This run holds %d %ss (%s), so it writes one migration record per %s ' ...
     '([one migration document per dataset], Jess Haley, 2026-11-03), and ' ...
     'document "%s" belongs to none of them, so which record reports it is ' ...
     'not decided. Pass ''Anchor''.'], numel(anchors), kind, ...
    strjoin(anchors(1:min(5, end)), ', '), kind, id);
end

function tf = isIncludedIn(s)
% a directed_relation `included_in` (a session's membership in its dataset)
tf = false;
if ~isfield(s, 'document_class') || ~isfield(s.document_class, 'class_name') ...
        || ~strcmp(char(s.document_class.class_name), 'directed_relation') ...
        || ~isfield(s, 'directed_relation') || ~isfield(s.directed_relation, 'relation')
    return;
end
r = s.directed_relation.relation;
tf = isstruct(r) && did2.build.isVocabulary(r, 'relation', 'included_in');
end

function v = edgeOf(s, name)
% the document id a V2 edge (or a v1 depends_on entry) of NAME names
v = '';
if ~isfield(s, 'depends_on') || ~isstruct(s.depends_on) || ~isfield(s.depends_on, 'name')
    return;
end
hit = find(strcmp({s.depends_on.name}, name), 1);
if isempty(hit); return; end
e = s.depends_on(hit);
if isfield(e, 'document_id')
    v = char(e.document_id);
elseif isfield(e, 'value')
    v = char(e.value);
end
end

function args = namedArgs(o)
% OPTIONS back as name-value pairs for the per-anchor call
args = {'Anchor', o.Anchor, 'Counts', o.Counts, 'ReportFile', o.ReportFile, ...
    'Version', o.Version, 'Validate', o.Validate, 'SchemaCache', o.SchemaCache};
end

function recs = rewriteReport(recs, report, o)
% the report file of a per-anchor record, rewritten with what the split adds
% (`anchor`, `counts.run`), under a new content-named file
body = recs{2}.toStruct();
loc = body.files.file_info.locations;
old = loc.location;
if isempty(o.ReportFile)
    scratch = [tempname() '.json'];
    writeJson(scratch, report);
    file = fullfile(tempdir, ['did2_migration_report_' contentKey(scratch) '.json']);
    movefile(scratch, file, 'f');
    if ~strcmp(old, file) && isfile(old)
        delete(old);
    end
else
    file = o.ReportFile;
    writeJson(file, report);
end
loc.location = file;
loc.uid = did2.convert.mintId('migration report file', contentKey(file));
body.files.file_info.locations = loc;
recs{2} = did2.document(body);
end

function kind = entityKind(s)
% 'dataset' or 'session' for an entity (or a pre-#88 dataset/session class)
kind = '';
cls = '';
if isfield(s, 'document_class') && isfield(s.document_class, 'class_name')
    cls = char(s.document_class.class_name);
end
if any(strcmp(cls, {'dataset', 'session'}))
    kind = cls;
    return;
end
if ~strcmp(cls, 'entity') || ~isfield(s, 'entity') || ~isfield(s.entity, 'type')
    return;
end
t = s.entity.type;
if ~isstruct(t)
    return;
end
if did2.build.isVocabulary(t, 'entity_type', 'dataset')
    kind = 'dataset';
elseif did2.build.isVocabulary(t, 'entity_type', 'session')
    kind = 'session';
end
end

function sid = sessionIdOf(s)
% the session_id edge, else a v1 base.session_id
sid = '';
if isfield(s, 'depends_on') && isstruct(s.depends_on) && isfield(s.depends_on, 'name')
    hit = find(strcmp({s.depends_on.name}, 'session_id'), 1);
    if ~isempty(hit)
        e = s.depends_on(hit);
        if isfield(e, 'document_id')        % a V2 edge
            sid = char(e.document_id);
        elseif isfield(e, 'value')          % a v1 depends_on entry
            sid = char(e.value);
        end
        if ~isempty(sid)
            return;
        end
    end
end
if isfield(s.base, 'session_id') && (ischar(s.base.session_id) || isstring(s.base.session_id))
    sid = char(s.base.session_id);
end
end

function [commit, why] = toolCommit()
% the DID-matlab commit this file is checked out at
commit = '';
why = '';
here = fileparts(mfilename('fullpath'));
try
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', here));
    out = strtrim(out);
    if status == 0 && ~isempty(regexp(out, '^[0-9a-f]{40}$', 'once'))
        commit = out;
    else
        why = sprintf('git rev-parse exited %d: %s', status, out);
    end
catch ME
    why = ME.message;
end
end

function key = contentKey(file)
% the SHA-256 of FILE's bytes, as hex
fid = fopen(file, 'r');
bytes = fread(fid, Inf, 'uint8=>int8');
fclose(fid);
md = java.security.MessageDigest.getInstance('SHA-256');
h = typecast(md.digest(bytes), 'uint8');
key = lower(reshape(dec2hex(h, 2)', 1, []));
end

function writeJson(file, report)
fid = fopen(file, 'w');
if fid < 0
    error('did2:convert:migrationRecord', ...
        'Cannot write the migration report to "%s".', file);
end
closer = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(report), 'char');
end
