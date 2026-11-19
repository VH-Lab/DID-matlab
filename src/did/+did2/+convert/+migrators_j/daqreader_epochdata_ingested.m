function bodies = daqreader_epochdata_ingested(preBody, delegated)
%DAQREADER_EPOCHDATA_INGESTED Brainstorm-J migrator: lift the epoch's clock
%   extents out of `epochtable` into `relative_time_reference` documents.
%
%   Routed from did2.convert.v1_to_v2. The sibling migrator
%   daqreader_mfdaq_epochdata_ingested.m called it after de-encoding the mfdaq
%   subtype until it began handing its v1 document on unchanged ([retired
%   classes leave V2], Jess Haley, 2026-10-25).
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
%   emitter rather than against memory: did2.convert.epochClockReferences.m builds
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
%   by decomposing into relative_reference + sampled_body + image_observation"),  (pre-#88)
%   and the plan attaches an explicit gate to that half: "A cannot be built until
%   #65 and #30 land -- it decomposes into `relative_reference` documents AND a
%   `sampled_body` on an observation".
%
%   The document is TWO TIERS FUSED, and each now has a target:
%
%     epochtable                      -> relative_reference     BUILT BELOW
%     the attached recording archives -> opaque_body data bodies of the
%                                        epoch's recording observations,
%                                        BUILT by did2.convert.resolveEpochProbemap
%
%   (Until 2026-11-19 this table marked the archive tier as still to be built
%   under did-schema OPEN_WORK #30; HISTORICAL-BUILD-CLAIM, corrected here.)
%   What #30 became is in did-schema `did_v2_recording_observation_plan.md`:
%   TEAM-SIGN-OFF [raw recording observation] (2026-08-10, 2026-08-13), amended
%   by "Decided by Jess Haley, 2026-10-27 [Guard A amended]" (did-schema #104,
%   closed 2026-10-29), and, for these archives, [epoch files as data bodies],
%   [ingested epochs use the archive] and [ingested epoch documents retired]
%   (Jess Haley, 2026-10-21). All of it is built: an element's recording
%   observation is assembled by `private/jRecordingObservation.m` (called from
%   `element.m`, covered by testMigratorsJRecordingObservation); the per-epoch
%   observations, with this document's archive segments as their
%   `opaque_body` data bodies, are minted by the batch post-pass
%   did2.convert.resolveEpochProbemap (covered by testResolveEpochProbemap and
%   testIngestedArchiveFiles), which does the epoch<->element join a
%   per-document migrator cannot.
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
%   So THIS migrator never retires the document: it lifts `epochtable` and
%   preserves the source. The retirement is resolveEpochProbemap's, and it
%   retires a `daqreader_*_epochdata_ingested` document only when every file it
%   holds is carried by a surviving per-epoch data body and every clock it
%   states with times is on an emitted time reference ([ingested epoch
%   documents retired], [clock only on the time reference]); a document with an
%   unowned file is kept and counted. Nothing is duplicated at the byte level --
%   only `epochtable`, which is cheap.
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
%   did2.convert.epochClockReferences (NO TIMES => NO REFERENCE: `no_time` and NaN intervals
%   are both real, reachable values here).
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (daqreader_epochdata_ingested.json + epochid.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+daq/reader.m ingest_epochfiles: the epochtable and
%   daqreader_id; that writer names an undefined ndi_daqreader_mfdaq_obj and
%   cannot run at that `main`, so its shape is the only evidence writes it). Its blocks are snake_case already and it has no `app`
%   block, so the raw shape is the renamed one but for v1's `value` edge key,
%   which every reader here takes (jEpochDocId, did2.convert.epochMint, NDI's
%   sliceTetanus). In pass 1 there is no epoch_id edge, so the document passes
%   through as before. What the renamed path would have discarded is carried,
%   carry-100, [rename clashes are malformed]; a field, block or edge outside the template (which
%   the passthrough met as an undeclared field) carries the document whole as
%   v1 (private/jRawAccount, jRawCarry; [fields outside the template are
%   malformed], carry-100). did2.convert.roundtrip.daqreader_epochdata_ingested rebuilds the v1
%   document; testRawV1RoundTripIngestedEpochs compares the two.
%
%   DELEGATED (the second argument, true): the raw read is skipped, for a
%   caller that accounted for every raw field itself. No migrator delegates
%   since daqreader_mfdaq_epochdata_ingested hands its v1 document on
%   unchanged ([retired classes leave V2], Jess Haley, 2026-10-25).
arguments
    preBody (1,1) struct
    delegated (1,1) logical = false
end

if ~delegated
    % THE RAW READ (see READS RAW v1 above)
    [~, collision, unplaced] = jRawAccount(preBody, struct( ...
        'daqreader_epochdata_ingested', {{'epochtable'}}, ...
        'epochid', {{'epochid'}}, 'files', {{'file_list', 'file_info'}}), ...
        {'^daqreader_id$', '^epoch_id$'});
    if jRawCarry('daqreader_epochdata_ingested', preBody, collision, unplaced, 'carry-100')
        bodies = preBody;
        return;
    end
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
refs = did2.convert.epochClockReferences(getSubStruct(blk, 'epochtable'), epochDocId, ...
    baseField(preBody, 'session_id', ''), ...
    baseField(preBody, 'datestamp', did2.convert.migrationTime()));

if isempty(refs)
    bodies = preBody;
    return;
end
% the document is kept beside its clock references, so it is emitted
% complete: the superclass list of its class, from the schema
% (did2.build.superclasses; [early migration pieces fixed] (2), Jess Haley,
% 2026-10-26: "the builder produces a complete document"; before,
% v1_to_v2's ensureClassBlocks rewrote v1's list)
kept = preBody;
kept.document_class.superclasses = did2.build.superclasses('daqreader_epochdata_ingested');
bodies = [{kept}, refs];
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
