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
