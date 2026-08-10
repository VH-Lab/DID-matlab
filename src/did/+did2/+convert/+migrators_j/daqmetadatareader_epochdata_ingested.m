function bodies = daqmetadatareader_epochdata_ingested(preBody)
%DAQMETADATAREADER_EPOCHDATA_INGESTED Brainstorm-J migrator: the per-epoch
%   companion-spreadsheet bytes -> `acquisition_metadata_file`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   1 -> 1, base.id PRESERVED. The signed decision
%   (`V_eta_ingested_payload_findings.md`, TEAM-SIGN-OFF [daq ingested
%   payloads], 2026-08-08):
%
%       acquisition_metadata_file  <- base            base.id PRESERVED
%          (NO FIELDS -- its entire content is the file)
%          FILE  data.bin                                    REQUIRED
%          depends_on
%             acquisition_metadata_reader_id -> acquisition_metadata_reader  REQ
%             epoch_id                       -> epoch                        REQ
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM THE TEMPLATE AND THE WRITER (THEY AGREE)
%   ---------------------------------------------------------------------
%   git show origin/main:src/ndi/ndi_common/database_documents/ingestion/\
%       daqmetadatareader_epochdata_ingested.json
%      superclasses  base, epochid
%      depends_on    [ { "name": "daqmetadatareader_id", "value": "" } ]
%      files         { "file_list": [ "data.bin" ] }
%      daqmetadatareader_epochdata_ingested { }            <- NO FIELDS AT ALL
%
%   git show origin/main:src/ndi/+ndi/+daq/metadatareader.m  (ingest_epochfiles)
%      126  function d = ingest_epochfiles(obj, epochfiles, epoch_id)
%      134     epochid_struct.epochid = epoch_id;
%      136     d = ndi.document('daqmetadatareader_epochdata_ingested', ...
%                               'epochid', epochid_struct);
%      137     d = d.set_dependency_value('daqmetadatareader_id', obj.id());
%      144     d = d.add_file('data.bin',[metadatafile '.nbf.tgz']);
%
%   So the writer sets exactly: the `epochid` STRING block, the
%   `daqmetadatareader_id` edge, and one file. Nothing else exists to carry, and
%   `data.bin`'s bytes are a `.nbf.tgz` ARCHIVE stored under a generic name.
%   THE PAYLOAD IS NOT TYPED HERE, deliberately: `ndi.daq.metadatareader`'s own
%   doc calls it "a tab-separated-value file", but nothing DECLARES that, and
%   proposing a shape from a template alone is what produced the ~2,078
%   distance_metadata quarantines.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NO EPOCH DOCUMENT => NO METADATA FILE. Pass the document through.
%   ---------------------------------------------------------------------
%   `acquisition_metadata_file` declares BOTH its edges REQUIRED, and it does NOT
%   inherit `epochid` -- so the epoch-id STRING has nowhere to live on it. The
%   epoch attribution survives the fold ONLY as the `epoch_id` edge. Emitting the
%   class before an `epoch` document exists would therefore do two bad things at
%   once: leave a required edge empty (which validates clean --
%   `+did2/+validate/references.m:90` skips empty edges, the mechanism behind the
%   whole invented-empty-edge census), AND destroy the only record of which epoch
%   the bytes belong to. That second half is the FRAGMENT mode that no counter
%   sees, and it is the exact mistake the sibling migrator
%   daqreader_mfdaq_epochdata_ingested.m had to have reverted out of it.
%
%   jEpochDocId answers '' for every did_v1 document today (see its header for
%   the two independent reasons and the commands that establish them), so on the
%   corpora this migrator passes 2,659 documents through UNCHANGED --
%   B 1,242 / Dab 1,242 / Soph 175, the volumes recorded in the findings
%   document. Passing through is safe: the V_eta source tombstone was repaired
%   from the real template during the schema half (it declares `data.bin` and the
%   `daqmetadatareader_id` edge again), so those documents validate as themselves.
%
%   The reader edge needs NO such guard and is not the blocker: `daqreader`/
%   `daqmetadatareader` migrate 1 -> 1 with base.id preserved, and must_refer is
%   existence-only (declarative), so the edge resolves against the migrated
%   reader document whatever the target class ends up being called.

arguments
    preBody (1,1) struct
end

readerId   = dependencyValue(preBody, 'daqmetadatareader_id');
epochDocId = jEpochDocId(preBody);
carried    = carriedFiles(preBody);

if isempty(readerId) || isempty(epochDocId) || isempty(carried)
    % Guarded passthrough. Note the file check is part of the guard, not
    % politeness: `data.bin` is declared REQUIRED on both the NDI schema
    % document and the V_eta class, and unlike `depends_on` NOTHING skips an
    % empty `file` -- so a byte-less carrier is a hollow document with no
    % excuse. A source document with no bytes has nothing this class can hold.
    bodies = {preBody};
    return;
end

out = struct();
out.document_class = struct('class_name', 'acquisition_metadata_file', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
out.depends_on = [ ...
    struct('name', 'acquisition_metadata_reader_id', 'value', readerId), ...
    struct('name', 'epoch_id',                       'value', epochDocId)];
% base.id PRESERVED (T10). Nothing in NDI points at this class by id -- the
% id-reference check in the findings document found 0 references across 91
% templates and 1,002 .m files -- but preserving it costs nothing and keeps the
% migrated document traceable to its source.
out.base = struct('id', baseField(preBody, 'id', did.ido.unique_id()), ...
    'session_id', baseField(preBody, 'session_id', ''), ...
    'name', 'migrated_acquisition_metadata', ...
    'datestamp', baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));
% acquisition_metadata_file declares NO fields, but it is a CONCRETE class, so
% resolvePlacement still lists it in blocksContributed and validateDocument
% requires the (empty) block to be present.
out.acquisition_metadata_file = struct();
% Carry the bytes. This is the whole content of the document.
out.files = struct('file_list', {carried});

bodies = {out};
end

% ===================== small helpers =======================================

function names = carriedFiles(bodyStruct)
%CARRIEDFILES The document's own file list, accepting both spellings NDI uses.
%   Mirrors did2.validate.fileList's reader so the audit and the migrator agree
%   on what "carries files" means.
names = {};
raw = [];
if isfield(bodyStruct, 'files') && isstruct(bodyStruct.files) ...
        && isfield(bodyStruct.files, 'file_list')
    raw = bodyStruct.files.file_list;
elseif isfield(bodyStruct, 'file') && isstruct(bodyStruct.file) ...
        && isfield(bodyStruct.file, 'file_list')
    raw = bodyStruct.file.file_list;
end
if isempty(raw)
    return;
end
if iscell(raw)
    names = raw(:)';
elseif isstring(raw)
    names = cellstr(raw(:)');
elseif ischar(raw)
    names = {raw};
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            elseif isfield(d, 'id') && ~isempty(d.id)
                v = char(d.id);
            end
            return;
        end
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end
