function bodies = daqreader(preBody)
%DAQREADER Brainstorm-J migrator: did_v1 daqreader DISSOLVES into a `software`
%   entity. 1 -> 1, base.id PRESERVED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: NOT VERIFIED BY EXECUTION. There is no MATLAB in the authoring
%   environment, so not one line of this file has been run.
%
%   TEAM-SIGN-OFF [daq configuration]: jess@walthamdatascience.com / 2026-08-08
%   (did-schema schemas/V_eta_daq_family_decisions.md:471)
%     "daqreader DISSOLVES into a `software` entity (base.id preserved);
%      daqmetadatareader -> `acquisition_metadata_reader`; daqsystem ->
%      `acquisition_system` <- entity, base.id AND base.name preserved because
%      the name is the join key; the invented `file_extension` and
%      `metadata_names` are DELETED; `reader_string` is KEPT as the de-encoded
%      daqreader_ndr.ndr_reader_string."
%
%   and the model block it signs (V_eta_daq_family_decisions.md:195-196):
%     "daqreader -> DISSOLVES into the software entity, base.id PRESERVED.
%      It has NO parameters -- the only one of the four that fully collapses."
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main -- TEMPLATE, SCHEMA AND WRITER AGREE
%   ---------------------------------------------------------------------
%   git show origin/main:src/ndi/ndi_common/database_documents/daq/daqreader.json
%      superclasses  base
%      depends_on    (none declared)
%      daqreader { "ndi_daqreader_class": "ndi_daqreader" }
%
%   git show origin/main:src/ndi/+ndi/+daq/reader.m        (newdocument, :264-267)
%      ndi_document_obj = ndi.document('daqreader',...
%          'daqreader.ndi_daqreader_class',class(ndi_daqreader_obj),...
%          'base.id', ndi_daqreader_obj.id(),...
%          'base.session_id',ndi.session.empty_id());
%
%   So a real document carries EXACTLY ONE fact -- a MATLAB class name -- plus
%   base identity. Note `base.session_id` is `ndi.session.empty_id()`, the
%   sentinel '0000000000000000_0000000000000000' ("applies in any session",
%   +ndi/+session/empty_id.m), not an empty string: it is carried verbatim and
%   satisfies base.session_id's mustBeNonEmpty.
%
%   The class name is the WHOLE content, and it maps to a `software` entity's
%   name -- which is why the fold is a dissolution rather than a rename.
%
%   ---------------------------------------------------------------------
%   base.id IS PRESERVED -- FOUR CLASSES REFERENCE IT
%   ---------------------------------------------------------------------
%   `daqreader_id` is declared as a dependency on four NDI templates:
%
%     git grep -l '"daqreader_id"' origin/main -- \
%         'src/ndi/ndi_common/database_documents/*'
%        daq/daqsystem.json
%        ingestion/daqreader_epochdata_ingested.json
%        ingestion/daqreader_image_epochdata_ingested.json
%        ingestion/daqreader_mfdaq_epochdata_ingested.json
%
%   Minting a fresh id would dangle every one of them -- the 11,448-orphan
%   mistake. `must_refer_to_document_class` is DECLARATIVE (existence-only, not
%   type-checked), so those edges resolve against the `software` document the
%   same id now names.
%
%   ---------------------------------------------------------------------
%   TWO GUARDS, BOTH "A FACT WITH NO HOME MEANS PASS THE DOCUMENT THROUGH"
%   ---------------------------------------------------------------------
%   1. NO CLASS NAME => NO ENTITY. `software` is identified by its name; an
%      entity with no name is a hollow document, and jSoftware returns [] for an
%      empty name precisely so a caller cannot mint one.
%
%   2. A POPULATED `reader_string` => PASS THROUGH. `software` declares name /
%      version / local_identifier and nothing else, so a reader's file-type
%      string ('intan', 'SpikeGadgets') has nowhere to go. It reaches a
%      `daqreader` body only through the chunk-(c) de-encode
%      (migrators_j/daqreader_ndr.m, ndr_reader_string -> daqreader.reader_string,
%      a field the signed decision explicitly KEEPS), and this migrator is not on
%      that path today -- v1_to_v2 routes by the SOURCE class name, so a
%      daqreader_ndr document is handed to daqreader_ndr.m and never to this
%      function. The guard is here so the fact stays safe if that ever changes.
%
%   A passthrough is safe: `daqreader` is in build_v_eta.py's `_KEEP_INFRA` and
%   NOT in `_DELETE_PHASE8`, so the V_eta source tombstone still exists and the
%   document validates as itself, visible in `unconverted_by_class`.
%
%   ---------------------------------------------------------------------
%   DEDUPLICATION IS DEFERRED, AND THAT IS NOT THIS MIGRATOR'S CALL
%   ---------------------------------------------------------------------
%   The signed model says software entities are "DEDUPLICATED across sessions".
%   A single-document migrator cannot see another session's reader, so pass 1
%   mints one entity per source document and the merge is the NDI second pass --
%   the reasoning, and the precedent (ndi.migrate.internal.pathSPromotion), are
%   in private/jSoftware.m. Here the merge is additionally CONSTRAINED: base.id
%   is preserved, so this software document's id is load-bearing for four other
%   classes and a merger must RETARGET rather than delete.

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'daqreader') && isstruct(preBody.daqreader) ...
        && isscalar(preBody.daqreader)
    blk = preBody.daqreader;
end

implClass    = jGetChar(blk, 'ndi_daqreader_class');
readerString = jGetChar(blk, 'reader_string');

if isempty(implClass) || ~isempty(readerString)
    bodies = {preBody};     % see THE GUARDS above
    return;
end

sessionId = '';
datestamp = '';
srcName   = '';
srcId     = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    sessionId = jGetChar(preBody.base, 'session_id');
    datestamp = jGetChar(preBody.base, 'datestamp');
    srcName   = jGetChar(preBody.base, 'name');
    srcId     = jGetChar(preBody.base, 'id');
end

% v1 records no version for a reader -- the template has no version field -- so
% the entity carries a name only and jSoftware's local_identifier is the bare
% class name, which is the dedup key the second pass will merge on.
software = jSoftware(implClass, '', '', sessionId, datestamp);

% base.id PRESERVED (see above). jSoftware mints a fresh id because most of its
% callers need one; here the id is the point of the fold, so it is overwritten
% rather than left to drift.
if ~isempty(srcId)
    software.base.id = srcId;
end
% base.name: v1's reader writer sets none (only base.id and base.session_id), so
% jSoftware's default -- the class name -- normally stands. A document that DOES
% carry a name keeps it rather than having it replaced by the class string.
if ~isempty(srcName)
    software.base.name = srcName;
end

bodies = {software};
end
