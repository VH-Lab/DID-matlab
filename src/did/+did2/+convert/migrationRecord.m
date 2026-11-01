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
%   `session_id` edges (or v1 base.session_id) name. Two or more of either
%   is not decided: did2:convert:migrationAnchor, and nothing is written
%   (pass 'Anchor' to name it).
%
%   Options:
%     'Anchor'       the id the record's session_id edge names (default: as
%                    above)
%     'Counts'       a struct of run counts to add to REPORT.counts (a
%                    caller's own: source documents read, quarantined, ...)
%     'ReportFile'   where the JSON file is written (default: a new temporary
%                    file; the database deletes it once ingested)
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
    anchor = anchorOf(docs);
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
    file = [tempname() '.json'];
end
writeJson(file, report);
bodyId = did2.convert.mintId('migration report', migrationId);
body = did2.build.opaqueBody(migrationId, ...
    did2.build.term('EDAM:format_3464', 'JSON'), 'SessionId', anchor, ...
    'Id', bodyId, 'CreationTimestamp', ts, ...
    'Validate', options.Validate, 'SchemaCache', options.SchemaCache);
% the file's bytes: ingested (copied into the database's file store, then the
% temporary file deleted) when the documents are added to a
% did2.database.sqlitedb
body.files.file_info = struct('name', 'body_data_0', 'locations', struct( ...
    'delete_original', 1, 'uid', bodyId, 'location', file, ...
    'parameters', '', 'location_type', 'file', 'ingest', 1));
records = {did2.document(rec), did2.document(body)};
end

% =============================================================================

function anchor = anchorOf(docs)
% [migration record points at the dataset]: the dataset, else the session
datasets = {};
sessions = {};
edges = {};
for k = 1:numel(docs)
    s = docs{k};
    if isa(s, 'did2.document')
        s = s.toStruct();
    end
    if ~isstruct(s) || ~isfield(s, 'base') || ~isfield(s.base, 'id')
        continue;
    end
    kind = entityKind(s);
    if strcmp(kind, 'dataset')
        datasets{end+1} = char(s.base.id); %#ok<AGROW>
    elseif strcmp(kind, 'session')
        sessions{end+1} = char(s.base.id); %#ok<AGROW>
    end
    sid = sessionIdOf(s);
    if ~isempty(sid)
        edges{end+1} = sid; %#ok<AGROW>
    end
end
for c = {unique(datasets), unique(sessions), unique(edges)}
    ids = c{1};
    if isscalar(ids)
        anchor = ids{1};
        return;
    elseif numel(ids) > 1
        error('did2:convert:migrationAnchor', ...
            ['The run''s migration record names the dataset it migrated, else ' ...
             'the session ([migration record points at the dataset], Jess Haley, ' ...
             '2026-11-01), and this run holds %d of them (%s), so which one is ' ...
             'not decided. Pass ''Anchor''.'], numel(ids), strjoin(ids(1:min(5, end)), ', '));
    end
end
error('did2:convert:migrationAnchor', ...
    ['The run''s documents name no dataset and no session, so its migration ' ...
     'record has nothing to point at. Pass ''Anchor''.']);
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
        sid = char(s.depends_on(hit).document_id);
        return;
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

function writeJson(file, report)
fid = fopen(file, 'w');
if fid < 0
    error('did2:convert:migrationRecord', ...
        'Cannot write the migration report to "%s".', file);
end
closer = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(report), 'char');
end
