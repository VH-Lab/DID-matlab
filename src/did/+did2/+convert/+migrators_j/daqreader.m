function bodies = daqreader(preBody)
%DAQREADER Brainstorm-J migrator: did_v1 daqreader folds to an
%   `acquisition_reader` + a `software` entity. 1 -> 2, base.id PRESERVED ON
%   THE READER.
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
%   ONE GUARD, AND THE SECOND ONE'S REMOVAL IS RECORDED BECAUSE IT MATTERED
%   ---------------------------------------------------------------------
%   NOTHING TO SAY => PASS THROUGH. A body with neither a class name nor a
%   reader string carries no fact, and minting entities from it is the
%   hollow-document defect. `software` is identified by its name, and
%   jSoftware returns [] for an empty name precisely so a caller cannot mint a
%   nameless one -- so a reader string with no class name still emits the
%   reader, with its `software_id` edge ABSENT rather than blank.
%
%   THE SECOND GUARD IS GONE (2026-08-13). It read "a POPULATED `reader_string`
%   => PASS THROUGH", because `software` declares name / version /
%   local_identifier and had nowhere to put a file-type string. That was true
%   and its effect was perverse: exactly the documents carrying the field the
%   signed decision KEEPS were the ones that never folded, and they came to
%   rest as `daqreader`, a class the same decision retires. `acquisition_reader`
%   (did-schema 69fa66d) gives the string a home, so the guard would now only
%   preserve the gap it documented.
%
%   AND THE DISPATCH GAP IS CLOSED. This header used to say a daqreader_ndr
%   document "is handed to daqreader_ndr.m and never to this function", which
%   was true and was the bug: v1_to_v2 dispatches ONCE on the source class and
%   never re-dispatches after a rename. daqreader_ndr.m now delegates here
%   after de-encoding.
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

% GUARD 2 IS GONE, and its removal is the point of this change. It read
% `|| ~isempty(readerString)` and passed the document through because
% `software` had nowhere to put a reader string. `acquisition_reader` now
% does (did-schema b014e27), so the fact has a home and the guard would only
% preserve the gap it documented. Guard 1 survives in the weaker form below:
% a body with NEITHER a class name NOR a reader string says nothing at all,
% and minting entities from it would be the hollow-document defect.
if isempty(implClass) && isempty(readerString)
    bodies = {preBody};
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
[software, swId] = jSoftware(implClass, '', '', sessionId, datestamp);

% THE PRESERVED id MOVES TO THE READER, AND THAT IS A DELIBERATE REVERSAL.
% It used to sit on the `software` body, because `software` was what
% `acquisition_system.reader_id` pointed at. That edge now points at
% `acquisition_reader` (did-schema b014e27), and v1's `daqsystem.daqreader_id`
% names the v1 DAQREADER document -- so the reader is the body that must carry
% the id forward or every reader_id edge dangles. `software` keeps the fresh
% id jSoftware minted, which is also what lets the deferred dedup pass merge
% two rigs sharing one implementation class (#25).
readerId = srcId;
if isempty(readerId)
    readerId = did.ido.unique_id();
end

reader = struct();
reader.document_class = struct('class_name', 'acquisition_reader', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
% NEVER AN EMPTY EDGE. `software_id` is optional on `acquisition_reader`, and
% #37 RequiredDependencies is armed, so an absent software is an ABSENT edge
% rather than a present-but-blank one -- the invented-empty-edge pattern this
% repository has paid for six times.
if isempty(swId)
    reader.depends_on = struct('name', {}, 'value', {});
else
    reader.depends_on = struct('name', {'software_id'}, 'value', {swId});
end
reader.base = jBase(readerId, char(sessionId), srcName, datestamp);
reader.acquisition_reader = struct('reader_string', readerString);

% The reader leads: it is the body that keeps the source id, so a caller
% reading bodies{1} gets the document the graph still points at.
bodies = {reader};
if ~isempty(software)
    bodies{end+1} = software;
end
end
