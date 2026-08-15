function bodies = daqreader_epochdata_ingested(preBody)
%DAQREADER_EPOCHDATA_INGESTED Brainstorm-J migrator: lift the epoch's clock
%   extents out of `epochtable` into `relative_reference` documents.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta', and
%   also called directly by the sibling migrator
%   daqreader_mfdaq_epochdata_ingested.m after it de-encodes the mfdaq subtype.
%
%   1 -> 1 + N. The source document is PRESERVED and N `relative_reference`
%   documents are added, one per (clock, interval) pair in `epochtable`:
%
%       epochtable.epochclock{i} + t0_t1(:,i)
%          -> relative_reference   relative_to -> the epoch document
%                                  value { clock, start, duration }
%
%   THIS LINE READ `value { start, end, clock, approximate }` UNTIL 2026-08-11
%   and named three fields the emitter does not write. Corrected against the
%   emitter rather than against memory: jEpochClockReferences.m builds
%   `relative_reference.value` as {clock, start, duration} (its CHANGE 1 --
%   `end` became `duration`) and puts the approximation on the ROOT block as
%   `time_reference.clock_tolerance` (its CHANGE 2 and 4 -- `approximate` on the
%   value cell is a claim about the NUMBER and is always false there; a boolean
%   `is_approximate` was deleted outright because it threw away the five seconds
%   NDI states). A header that names a field the code does not emit is the
%   stale-header defect this project has now found seven times; it is corrected
%   here rather than left for the next reader to trust.
%
%   ---------------------------------------------------------------------
%   WHY THE SOURCE IS PRESERVED RATHER THAN RETIRED
%   ---------------------------------------------------------------------
%   The signed decision retires this class ("the reader and image classes RETIRE
%   by decomposing into relative_reference + sampled_body + image_observation"),
%   and the plan attaches an explicit gate to that half: "A cannot be built until
%   #65 and #30 land -- it decomposes into `relative_reference` documents AND a
%   `sampled_body` on an observation".
%
%   That gate is load-bearing here, because the document is TWO TIERS FUSED and
%   only one of them has a target today:
%
%     epochtable                     -> relative_reference     BUILT BELOW
%     the attached recording archives -> sampled_body on a
%                                        <modality>_observation  #30, NOT BUILT
%
%   "#30, NOT BUILT" IS TOO BROAD AND IS CORRECTED HERE, 2026-08-15. #30 is
%   SIGNED (2026-08-10 and 2026-08-13) and its assembler is LIVE:
%   `private/jRecordingObservation.m`, called from `element.m:118`, covered by
%   `tests/+did2/+unittest/testMigratorsJRecordingObservation.m`. What is not
%   built is the NARROWER thing this line is really about -- RE-POINTING THESE
%   ARCHIVES onto such an observation -- and the reason is in the assembler's
%   own signature: the subject is an INPUT it is handed, not something it
%   resolves, so an ingested payload needs the epoch<->element join first, i.e.
%   the second pass. `daqreader_image_epochdata_ingested.m` already carries this
%   correction in its own header; `jRecordingObservation.m:118` QUOTES the stale
%   line above as evidence, which is how a wrong claim in one file becomes a
%   citation in another.
%
%   And for an INGESTED session those archives are the only copy of the
%   recording. From the writer, attached under runtime-computed names the
%   template never declares (#64, the undeclared-file gap):
%
%     git show origin/main:src/ndi/+ndi/+daq/+reader/mfdaq.m
%       829  d = d.add_file('channel_list.bin', channel_file_name);
%       916  d = d.add_file([fileprefix '_group' int2str(groups(g)) '_seg.nbf_' ...
%       955  d = d.add_file(['evmktx_group' ...], [filename_here '.nbf.tgz']);
%
%   Retiring the document before #30 exists would drop those bytes on the floor.
%   So this migrator is ADDITIVE and TRANSITIONAL: it lifts the half that has a
%   home, changes nothing about the half that does not, and leaves the source
%   class to be deleted by whoever builds #30 and can prove the bytes landed.
%   Nothing is duplicated at the byte level -- only `epochtable`, which is cheap
%   and which the retiring commit removes.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NO EPOCH DOCUMENT => NO REFERENCE. Pass the document through.
%   ---------------------------------------------------------------------
%   `relative_reference.relative_to` is REQUIRED -- the team call recorded in the
%   time model plan, "a relative time with no referent is not interpretable" --
%   and the referent is the epoch. jEpochDocId answers '' for every did_v1
%   document today (its header carries the two independent reasons and the
%   commands), so today this migrator is a pure passthrough and the corpus sees
%   it as `unconverted`, which is the honest signal. It converts the moment
%   #60's epoch pass stamps an `epoch_id` edge, with no further change.
%
%   The alternative -- anchoring to the SESSION instead -- was considered and
%   REJECTED as a false assertion, not merely a weaker one. The base mfdaq
%   reader's only clock is `dev_local_time`
%   (+ndi/+daq/+reader/mfdaq.m:57: `ec = {ndi.time.clocktype('dev_local_time')}`),
%   whose times are the DEVICE's own, scoped to the epoch; measuring them
%   against the session would state an offset that is not the one stored.
%
%   Which entries become documents, and which correctly become nothing, is in
%   jEpochClockReferences (NO TIMES => NO REFERENCE: `no_time` and NaN intervals
%   are both real, reachable values here).

arguments
    preBody (1,1) struct
end

epochDocId = jEpochDocId(preBody);
if isempty(epochDocId)
    % Guarded passthrough. Returned as a bare struct, not a 1-cell: the sibling
    % mfdaq migrator delegates to this function and its caller may be either
    % did2.convert.v1_to_v2 (which accepts both) or a test calling the migrator
    % function directly (which expects the struct).
    bodies = preBody;
    return;
end

blk = getBlock(preBody, 'daqreader_epochdata_ingested');
refs = jEpochClockReferences(getSubStruct(blk, 'epochtable'), epochDocId, ...
    baseField(preBody, 'session_id', ''), ...
    baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'));

if isempty(refs)
    bodies = preBody;
    return;
end
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
