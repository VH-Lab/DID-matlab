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
%   A passthrough is safe: `daqreader` is in build_v_eta.py's (deleted 2026-10-21) `_KEEP_INFRA` and
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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI daqreader.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+daq/reader.m newdocument writes it).
%   Every v1 field and where it goes; did2.convert.roundtrip.daqreader rebuilds
%   the v1 document and testRawV1RoundTripDaq compares the two:
%
%     base.id, session_id, datestamp  -> the acquisition_reader's (the session
%                                        is often ndi.session.empty_id())
%     base.name                       -> not written (the writer leaves '')
%     daqreader.ndi_daqreader_class   -> the software entity's name
%
%   What the renamed path would have discarded is carried, carry-049, as
%   before; a field or edge no part of this migrator reads now carries the
%   document whole as v1 (private/jRawAccount, jRawCarry; no register row yet).

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above). `reader_string` is not a field of
% NDI's daqreader template; it is what daqreader_ndr.m de-encodes onto the
% block before it hands the document on, and it is placed below.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct('daqreader', ...
    {{'ndi_daqreader_class', 'reader_string'}}), {});
if jRawCarry('daqreader', src, collision, unplaced)
    bodies = {src};
    return;
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
    bodies = {src};
    return;
end

sessionId = jSid(preBody);
datestamp = jStamp(preBody);
srcId = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    srcId = jGetChar(preBody.base, 'id');
end
[software, swId] = jSoftware(implClass, '', '', sessionId, datestamp);
edges = struct();
if ~isempty(swId); edges.software_id = swId; end
f = struct();
if ~isempty(readerString); f.reader_string = readerString; end
o = jOpts(preBody, 'Edges', edges, 'Id', srcId);
reader = did2.build.document('acquisition_reader', f, o{:});
bodies = [{reader}, software];
end
