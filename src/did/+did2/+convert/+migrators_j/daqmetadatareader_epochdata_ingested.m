function bodies = daqmetadatareader_epochdata_ingested(preBody)
%DAQMETADATAREADER_EPOCHDATA_INGESTED Brainstorm-J migrator: the per-epoch
%   metadata archive. On did-schema #88 this PASSES THROUGH: #73 review item 61
%   retired `acquisition_metadata_file`, and the decided target, an
%   `opaque_body` owned by the epoch's stimulator manipulation, is built by the
%   batch pass did2.convert.resolveEpochProbemap (mkMetadataArchiveBodies).
%   The history below describes the retired 2026-08-08 fold.
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

% did-schema #88 RETIRED `acquisition_metadata_file` (#73 review item 61): the
% bytes become an opaque_body OWNED BY the stimulator term_manipulation of the
% same epoch, which resolveEpochProbemap mints in a batch pass. A single
% document cannot name that owner, so pass 1 PASSES IT THROUGH on its v1
% tombstone, unchanged; did2.convert.resolveEpochProbemap
% (mkMetadataArchiveBodies) joins it to that manipulation and replaces it with
% the opaque_body, id preserved, or keeps it and counts why.
bodies = {preBody};
end
