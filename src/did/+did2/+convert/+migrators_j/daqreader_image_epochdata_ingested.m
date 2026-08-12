function bodies = daqreader_image_epochdata_ingested(preBody)
%DAQREADER_IMAGE_EPOCHDATA_INGESTED Brainstorm-J migrator: the camera's ingested
%   epoch. Lifts the inherited epoch clock extents; the image fold is BLOCKED and
%   the document is preserved.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   1 -> 1 + N, exactly as the parent class: the source document is PRESERVED and
%   N `relative_reference` documents are added from the INHERITED
%   `daqreader_epochdata_ingested.epochtable` block. Everything else stays put.
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM THE WRITER
%   ---------------------------------------------------------------------
%   git show origin/main:src/ndi/+ndi/+daq/+reader/image.m   (ingest_epochfiles)
%     176   sz     = obj.framesize(epochfiles);
%     177   dorder = obj.dimensionorder(epochfiles);
%     178   dtype  = obj.datatype(epochfiles);
%     179   n      = obj.numframes(epochfiles);
%     180   ft     = obj.frametimes(epochfiles, 1:n);
%     187   daqreader_epochdata_ingested.epochtable.epochclock = ec_;
%     188   daqreader_epochdata_ingested.epochtable.t0_t1 = ...
%     191-212  header.dimension_order / dimension_size / data_type / num_frames
%              / frametimes (1xN, NaN for clockless) / clocktype / metadata
%     214   epochid_struct.epochid = epoch_id;
%     216   d = ndi.document('daqreader_image_epochdata_ingested', ...)
%     220   d = d.set_dependency_value('daqreader_id', obj.id());
%     231   d = d.add_file('frames.bin', framesfile);
%
%   So it carries the SAME `epochtable` block as its parent -- which is why the
%   time half is shared with daqreader_epochdata_ingested.m rather than
%   reimplemented -- plus the raster header and the frames.
%
%   ---------------------------------------------------------------------
%   THE IMAGE FOLD IS NOT BUILT HERE, AND THAT IS DELIBERATE. THREE BLOCKERS.
%   ---------------------------------------------------------------------
%   The signed plan folds `frames.bin` + the raster header into
%   `image_observation` + `sampled_body`. Each of the three obstacles below is
%   sufficient on its own; together they make emitting the fold today a net loss.
%
%   1. NO REAL DOCUMENT HAS A SUBJECT, AND THE WRITER IS THE PROOF -- not the
%      template. `ingest_epochfiles` sets exactly ONE dependency, `daqreader_id`
%      (line 220 above). There is no `subject_id`, no `element_id`, and no other
%      construction site: `git grep -ln daqreader_image_epochdata_ingested
%      origin/main -- '*.m'` returns two files, this writer and
%      +ndi/+database/+fun/find_ingested_docs.m, which READS.
%
%      `image_observation` inherits `subject_id` from `subject_statement`, where
%      it is REQUIRED. Emitting it empty is not caught by anything --
%      `+did2/+validate/references.m:90` skips empty edges -- so it would produce
%      observations about nobody that pass every gate. That is not hypothetical:
%      it is the image_stack husk, 4,563 JH documents, and the guard that stopped
%      it landed three days ago (5e53f79, "image_stack: no subject means no
%      observation"). Rebuilding the same shape one class over would undo it.
%
%   2. `metadata` HAS NO HOME. The header carries a 7-field acquisition-metadata
%      struct -- israster, frame_period, line_period, dwell_time,
%      lines_per_frame, pixels_per_line, bidirectional
%      (+ndi/+daq/+reader/image.m:373-380, `emptymetadata`) -- which the V_eta
%      source tombstone declares field-for-field and which NEITHER
%      `image_observation` NOR `sampled_body` declares anywhere. The plan says as
%      much ("metadata[] -> UNTYPED ARRAY. Bag it honestly or read real documents
%      first") and leaves it open. Retiring the source therefore drops it
%      silently, and a passthrough keeps it losslessly.
%
%   3. #30 IS NOT BUILT. The raw-recording observation model
%      (`V_eta_recording_observation_plan.md`) is what says whose observation a
%      camera epoch is and what its `instrument_id` points at; the ingested-
%      payload plan gates this half on it explicitly.
%
%   Blocker 1 alone would justify a guarded passthrough in the fitcurve /
%   image_stack shape. What makes a passthrough SAFE here is that the V_eta
%   source tombstone still exists and was restated from the real template
%   (dimension_order / dimension_size / data_type / num_frames / frametimes /
%   clocktype / metadata, plus the inherited epochtable and the frames.bin file
%   declaration), so the document validates as itself. Deleting that tombstone
%   ahead of the fold is what put 2,484 corpus-B documents in quarantine once.
%
%   ---------------------------------------------------------------------
%   RE-INVESTIGATED 2026-08-12. BLOCKER 3 IS STALE; 1 AND 2 ARE NOW MEASURED;
%   A FOURTH IS ADDED BECAUSE IT WAS RECORDED NOWHERE. STILL NOT BUILDABLE.
%   ---------------------------------------------------------------------
%   THE SIGNATURE COVERS THIS CLASS. `V_eta_ingested_payload_findings.md:275`
%   -- "the reader and image classes RETIRE by decomposing into
%   relative_reference + sampled_body + image_observation" -- so the fold is
%   decided, not undecided, and what follows is about whether it can be BUILT.
%   The rejection at that document's `:339` is a NAMING decision about the two
%   parent classes' `_epoch_cache` rename and does not bear on the fold.
%
%   3'. #30 IS BUILT, and the sentence above is now false as written. The signed
%       assembler is live: `private/jRecordingObservation.m` exists, `element.m`
%       calls it at :117-120 for every isDirect element and withholds the loose
%       `probe observes specimen` relation at :133 only when it fired;
%       `tests/+did2/+unittest/testMigratorsJRecordingObservation.m` covers it.
%       IT LIFTS NOTHING HERE, and its own signature is why -- the subject is an
%       INPUT it is handed, not something it resolves:
%
%         function [bodies, retireObserves, unresolvedLabel] = ...
%             jRecordingObservation(preBody, elementId, specimenId, ...
%                                   elementType, bestKnownLabel)
%
%       An element supplies `specimenId` from its own `subject_id` edge. This
%       class has no element and no subject, so blocker 1 is what remains, and
%       #30 landing does not touch it. The correction is spelled out rather than
%       the old line quietly deleted, because a reader checking "has #30 landed?"
%       finds YES and would conclude the blocker fell.
%
%   1'. BLOCKER 1, MEASURED -- AND A BATCH POST-PASS IS NOT THE RESCUE EITHER.
%       The forward edge closure from this class over the NDI template graph is
%       one hop and one class:
%
%         DENOMINATOR: 91 NDI origin/main templates under
%                      ndi_common/database_documents/, all 91 parsed
%         daqreader_image_epochdata_ingested --daqreader_id--> daqreader
%         classes reachable forward: {daqreader_image_epochdata_ingested,
%                                     daqreader}
%         of those, declaring subject_id or element_id: NONE
%         classes pointing AT daqreader: the three ingested classes + daqsystem
%         daqsystem's own edges: filenavigator_id, daqreader_id,
%                                daqmetadatareader_id   -- no subject either
%         classes declaring a subject_id edge anywhere in the 91: 10
%           element, image, imageCollection, imageStack, measurement,
%           openminds_subject, subjectmeasurement, treatment, treatment_drug,
%           virus_injection
%         of those 10, declaring a daqreader_id or daqsystem_id edge: NONE
%
%       So there is no id path to a subject for ANY pass to walk. The v1 join
%       from a device to a subject is not in the database at all -- it is in the
%       EPOCHPROBEMAP files, read at +ndi/+daq/system.m:229-234:
%
%         myprobemap = ndi.daq.daqsystemstring(epc(ec).devicestring);
%         if strcmpi(myprobemap.devicename, ndi_daqsystem_obj.name)
%             newentry.subject_id = epc(ec).subjectstring;
%
%       and it is one-to-MANY: one daqsystem serves every probe its epochprobemap
%       names. Even with those files in hand the question becomes WHICH of those
%       subjects a camera epoch's frames are an observation of. That is a team
%       question, not a build.
%
%   2'. BLOCKER 2, MEASURED. The seven metadata field names are declared in
%       exactly one place in the whole built schema set -- this class's own
%       source tombstone:
%
%         DENOMINATOR: 245 json file(s) under did-schema schemas/V_eta/,
%                      241 carrying a document_class, 991 declared field paths
%                      walked including nested ones
%         israster / frame_period / line_period / dwell_time /
%         lines_per_frame / pixels_per_line / bidirectional
%             1 declaration each, all of them
%             daqreader_image_epochdata_ingested.metadata.*
%
%   4.  NEW, AND RECORDED NOWHERE UNTIL NOW: THE SIGNED FOLD'S OWN DESTINATIONS
%       DO NOT EXIST. Revision 2 of the signed plan
%       (`V_eta_ingested_payload_findings.md:307-317`) supersedes the section C
%       mapping and re-specifies it through the data_body AXIS ENTRY:
%       "dimension_order -> the ORDER OF THE axes[] ENTRIES", "dimension_size ->
%       each axis's n", "data_type -> `datum_type` ON THE STATEMENT",
%       "frametimes -> the time axis's `values` (irregular) or origin/spacing".
%       Re-derived from the built tree rather than from the prose, same 241
%       schemas:
%
%         leaf field `datum_type` : 0 declarations
%         `axes` declared by      : 4 classes -- sampled_body, acquisition_epoch,
%                                   image, zarr -- and NOT subject_statement,
%                                   which is where revision 2 puts the statement
%                                   half
%         a per-sample `values` slot on any axes shape : NONE
%           (sampled_body.axes is name/kind/length/regularity/spacing/unit;
%            image.value.axes is name/length/spacing/unit)
%
%       So IRREGULAR `frametimes` -- which is what the writer emits, one time per
%       frame, image.m:180 + :196-202 -- has no destination on an axis. The only slot in
%       the tree that could hold it is `sampled_body.sample_time.offsets`, and
%       that is the block the SAME signed data_body decision retires. This is the
%       `binaryseries_parameters` shape one class over (#45, blocked on #32;
%       #106): the ledger's rung 2, "decided targets EXIST in the build", is true
%       CLASS-wise and false FIELD-wise, so #45 landing is the beginning of this
%       fold and not the all-clear.
%
%   ---------------------------------------------------------------------
%   THE OPEN FACTUAL QUESTION IN OPEN_WORK #27, ANSWERED FROM THE WRITER
%   ---------------------------------------------------------------------
%   #27 asks whether `_image` is a distinct cache SHAPE or merely a modality
%   label -- the answer decides whether the class could fold into a shared
%   `<device>_epoch_cache` plus a modality field (`V_eta_tenet_audit.md:222`).
%   The three ingestion templates answer it:
%
%     DENOMINATOR: 3 ingestion template(s) on NDI origin/main
%     daqreader_epochdata_ingested        own block 1 field  (epochtable)
%                                         file_list []            reader.m:238
%     daqreader_mfdaq_epochdata_ingested  own block 1 field  (parameters)
%                                         file_list 62 pattern names  mfdaq.m:785
%     daqreader_image_epochdata_ingested  own block 7 fields (dimension_order,
%                                           dimension_size, data_type,
%                                           num_frames, frametimes, clocktype,
%                                           metadata)
%                                         file_list [frames.bin]     image.m:216
%
%   All three share exactly two things: the inherited `epochtable` block and the
%   single `daqreader_id` edge. So `_image` is a DISTINCT SHAPE -- folding it into
%   a shared class plus a modality field would drop seven queryable header fields
%   and a file declaration. That is the FACT; the disposition is the team's
%   (Operating Rule 4), and the rename half of #27 is separately REJECTED at
%   `V_eta_ingested_payload_findings.md:339` for the two parent classes.
%
%   NOTHING BELOW THIS LINE CHANGED. There is no MATLAB in the authoring
%   environment; this pass added evidence and tests, not behaviour.

arguments
    preBody (1,1) struct
end

epochDocId = jEpochDocId(preBody);
if isempty(epochDocId)
    bodies = {preBody};
    return;
end

% The clock extents live on the INHERITED parent block, not on this class's own
% block -- the writer builds `daqreader_epochdata_ingested.epochtable` and passes
% it as a separate property block (image.m:187-188, 216-219).
blk = getBlock(preBody, 'daqreader_epochdata_ingested');
refs = jEpochClockReferences(getSubStruct(blk, 'epochtable'), epochDocId, ...
    baseField(preBody, 'session_id', ''), ...
    baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));

% NOTE the asymmetry with the parent class's `clocktype` field: this document
% ALSO carries a scalar `clocktype` in its own header (image.m:203-207, the first
% epochclock or 'no_time'). It is a DUPLICATE of epochtable.epochclock{1}, not a
% second fact, so it produces no second reference. It stays on the preserved
% document rather than being deleted -- deciding it is redundant is the fold's
% call to make, not this one's.

bodies = [{preBody}, refs];
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name))
    b = bodyStruct.(name);
end
end

function s = getSubStruct(block, name)
s = struct();
if isfield(block, name) && isstruct(block.(name)) && isscalar(block.(name))
    s = block.(name);
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end
