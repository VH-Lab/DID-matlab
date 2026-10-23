function [bodies, retireObserves, unresolvedLabel] = jRecordingObservation(preBody, instrumentId, subjectId, elementType, bestKnownLabel)
%JRECORDINGOBSERVATION The pass-1 half of a recording element's observation:
%   the modality disposition and Guard A's worklist label. SINCE 2026-10-21 IT
%   EMITS NO OBSERVATION.
%
%   ---------------------------------------------------------------------
%   2026-10-21: ONE OBSERVATION PER ELEMENT PER EPOCH, WITH ITS FILES AS BODIES
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-21 (did-schema
%   V_eta_recording_observation_plan.md): migrated recordings link their epoch
%   files as data bodies, matching native V2 (NDI ndi.setup.V2.recordingDocuments):
%   one observation per element PER EPOCH, `data_body` true, an `opaque_body` per
%   epoch file recorded by location (ingested archives as attached), shared by
%   the electrodes recorded in it, with the channel map.
%
%   This function used to emit ONE observation per element across all its
%   epochs, with a session 'during' anchor and NO value and NO body. Rule
%   `value_inline_or_body` (data_body AMENDMENT 5, signed 2026-10-21) refuses
%   exactly that document, so every direct element QUARANTINED whole. And an
%   `element` document names no epochs and carries no files (the measurement
%   below), so pass 1 cannot build the decided shape. The per-epoch observation
%   is minted where the epoch and its files ARE known:
%
%     did2.convert.resolveEpochProbemap   the DID batch pass, over the cached
%                                         `epochfiles_ingested` documents (each
%                                         names its epoch, its probe-map rows,
%                                         its files) and the ingested archives
%     ndi.migrate.local (second pass)     sessions with no such cache: the file
%                                         navigator names the epoch's files
%
%   So here: RETIREOBSERVES is always false (no `instrument_id` edge exists yet,
%   so the loose `observes` relation is KEPT; the batch pass retires it when it
%   emits the replacement), BODIES is always empty, and UNRESOLVEDLABEL is
%   unchanged (Guard A's worklist entry still belongs to the element).
%
%   The derived (`spikes`) branch emits nothing either: its per-epoch samples
%   live on `element_epoch` documents (one attached `epoch_binary_data.vhsb`
%   each), and how those become the spike train's body is an OPEN question,
%   not decided here.
%
%   The rest of this header is the history of the pass-1 observation, kept for
%   its reasoning (ID preservation, multi-channel cardinality, Guard A).
%
%   ---------------------------------------------------------------------
%   HISTORY: open item #30, SIGNED 2026-08-10 in V_eta_recording_observation_plan.md.
%
%   [BODIES, RETIREOBSERVES, UNRESOLVEDLABEL] = jRecordingObservation(PREBODY,
%       INSTRUMENTID, SUBJECTID, ELEMENTTYPE, BESTKNOWNLABEL)
%
%   The signed model, one line: a raw continuous recording IS a
%   `<modality>_observation` of the SPECIMEN, taken WITH the electrode.
%
%       <modality>_observation   subject_id    = SUBJECTID (the slice/animal --
%                                                v1's element.subject_id)
%                                instrument_id = INSTRUMENTID  (the electrode, its
%                                                own subject, in the instrument
%                                                role -- T7)
%
%   THE TWO ID ARGUMENTS ARE NAMED FOR THEIR ROLES, NOT FOR THE DOCUMENTS THEY
%   USUALLY COME FROM, AND THAT MATTERS AS OF 2026-08-18. They were
%   `elementId` / `specimenId`, which read as "the element document's id" and
%   "the animal's id" -- true for every DIRECT element and false for the second
%   caller. A per-neuron spike train (TEAM-SIGN-OFF [spike train leaf],
%   V_eta_ensemble_plan.md:218) is an observation OF THE NEURON, taken with the
%   probe underneath it, so `element.m` passes the ELEMENT's own id as
%   SUBJECTID and its `underlying_element_id` as INSTRUMENTID -- the exact
%   opposite assignment. Under the old names that call site read like a bug.
%   Nothing about the emitted document changed with the rename; both callers
%   are positional.
%                                variable      = the modality, from the element
%                                                type via jRecordingModality
%                                storage_mode  = 'reference'
%       session_relative_reference  the 'during' anchor (see TIMING below)
%
%   NO `sampled_body` IS EMITTED, AND THAT IS THE POINT -- CHANGED 2026-08-14,
%   team decision "a body means bytes" (V_eta_data_body_model_plan.md, the
%   storage-mode walkthrough addendum).
%
%   This function is reached from ONE place -- `+migrators_j/element.m:118` --
%   and the v1 `element` template DECLARES NO FILES AT ALL. Measured:
%
%       DENOMINATOR: 91 v1 template(s) on NDI origin/main
%         declare a file_list : 15
%         `element` among them: NO
%
%   So an element document NEVER carries bytes, in ANY session. Ingestion does
%   not change it: ingesting attaches files to `epochfiles_ingested` and
%   `daqreader_*_epochdata_ingested`, which are DIFFERENT documents with their
%   own migrators. A body minted here was empty by construction and always
%   would have been -- 11 of them in one PRED-like session, each with dtype '',
%   shape [] and an empty sample_time.
%
%   V1'S OWN ANSWER IS THE ONE TAKEN. `ndi.file.navigator` has exactly two
%   states (`navigator.m:218`, `:795-807`): not ingested -> the files are on
%   disk, located BY PATTERN through the file navigator, and no document points
%   at them; ingested -> an `epochfiles_ingested` document carries them. No v1
%   template names a raw acquisition file (0 hits for `rhd` across all 91). The
%   observation is still emitted -- it is the true and valuable half, and the
%   whole reason #30 exists -- and the route to the bytes stays the route v1
%   uses: epoch -> file pattern -> navigator.
%
%   and the loose `probe observes specimen` directed_relation RETIRES -- the
%   `instrument_id` edge says the same thing inside a statement that also says
%   WHAT was recorded. RETIREOBSERVES is true exactly when this function emitted
%   an observation carrying that edge, so the relation is never dropped without
%   its replacement being present (the guarded idiom used by fitcurve.m).
%
%   ---------------------------------------------------------------------
%   ID PRESERVATION -- READ BEFORE CHANGING ANYTHING HERE
%   ---------------------------------------------------------------------
%   INSTRUMENTID stays on the SUBJECT that migrators_j.element mints. It is NOT
%   reused here: the observations get FRESH ids. That is deliberate and it is the
%   safe direction. ~50 v1 classes reference the element document
%   (`element_id` / `underlying_element_id` / `stimulator_id`) and every one of
%   them means "the recording element", which after migration is the subject.
%   Moving that id onto an observation would silently re-point all of them and
%   strand the subject -- the shape that cost 11,448 orphans (CLAUDE.md,
%   CALCULATORS). Nothing referenced these observations before they existed, so a
%   fresh id can dangle nothing.
%
%   ---------------------------------------------------------------------
%   MULTI-CHANNEL: ONE OBSERVATION, A CHANNEL AXIS ON THE BODY
%   ---------------------------------------------------------------------
%   Signed: "a 32-site probe is ONE observation whose sampled_body carries a
%   channel axis, NOT N observations". Implemented as one `axes` entry
%   {name 'channel', kind 'index'} on the body for the multi-site families
%   (n-trode, electrode-*).
%
%   The axis carries NO `length`. The channel count is NOT on the element
%   document -- PROBE-TYPES.md says of 'n-trode' that "the number of channels is
%   calculated from the number of channels specified in the device string", the
%   device string lives in the epochprobemap, and +ndi/+fun/+probe/channelCount.m
%   reads it through `probe.getchanneldevinfo(epoch)`. Declaring the DIMENSION
%   without inventing its EXTENT is the whole difference between this and the
%   spikewaves bug (a body that declared zero spikes of zero samples each and
%   validated cleanly). The count is a second-pass fill.
%
%   TWO QUANTITIES ARE NOT MULTI-CHANNEL. `patch` and `sharp` are documented as
%   two channels of DIFFERENT quantities (Vm and I). Two quantities are two
%   `variable`s and therefore two statements, so those types produce a
%   voltage_observation AND a current_observation, each single-channel. This is a
%   refinement of the signed multi-channel rule, not a contradiction of it: that
%   rule is about N SITES OF ONE MODALITY. Flagged for the team in the build
%   report -- labelling a current trace 'voltage' to keep the document count at
%   one would be a silent unit error of the kind fitcurve's SSE/goodness-of-fit
%   swap already cost us once.
%
%   ---------------------------------------------------------------------
%   TIMING: A SESSION 'during' ANCHOR, NOT THE EPOCH -- AND WHY
%   ---------------------------------------------------------------------
%   The plan says "timing = the acquisition_epoch / time_reference anchor". A
%   single-document migrator cannot reach it. Epoch timing lives on SEPARATE
%   documents (element_epoch -> acquisition_epoch) that depend_on the element;
%   the element document itself carries no epoch field, and jEpochDocId answers
%   '' for every did_v1 document today (its header carries the two independent
%   reasons and the commands). So one observation per element is emitted, with
%   the shared session 'during' anchor -- coarse but true. Per-epoch observations
%   are the second pass, which can group element_epoch by element_id; recorded
%   here as deferred, not overlooked.
%
%   ---------------------------------------------------------------------
%   THE BODY CARRIES NO BYTES IN PASS 1, ON PURPOSE
%   ---------------------------------------------------------------------
%   The element document has no attachments. For an INGESTED session the
%   recording archives hang off `daqreader_epochdata_ingested`, whose migrator
%   says so in its own header:
%
%       src/did/+did2/+convert/+migrators_j/daqreader_epochdata_ingested.m
%         "epochtable                      -> relative_reference     BUILT BELOW
%          the attached recording archives -> sampled_body on a
%                                             <modality>_observation  #30, NOT BUILT"
%
%   THAT QUOTE IS STALE IN THE SOURCE AND HAS BEEN CORRECTED THERE (2026-08-15);
%   it is kept here because the SECOND sentence below is what this file relies
%   on and that half is still true. "#30, NOT BUILT" is too broad -- #30 is
%   signed (2026-08-10, 2026-08-13) and THIS FUNCTION is its assembler, live
%   from `element.m:118`. Quoting a sibling's build claim as evidence is how a
%   wrong sentence in one file becomes a citation in another; cite the SIGNATURE
%   or the emitter, not another comment.
%
%   This function builds the landing pad that quote names. Re-pointing the bytes
%   onto it is the other half of #30 and needs the epoch<->element join, i.e. the
%   second pass -- because the subject is an INPUT to this function, not
%   something it resolves.
%
%   THE PARAGRAPH THAT STOOD HERE CHOSE THE WRONG ONE OF TWO BAD OPTIONS, and it
%   is replaced rather than deleted because its REASONING was right. It said a
%   body declaring an absent `body_data` file is a VISIBLE, counted state
%   (`declared_but_absent` in did2.validate.fileList, #64) while "an observation
%   with storage_mode 'body' and no body is an invisible one, and this project's
%   entire error history is invisible states winning." Both halves true. What it
%   missed is that there was a THIRD option: emit no body and say
%   `storage_mode: 'reference'`, which is neither invisible NOR a false promise
%   -- the document states plainly that the value is outside the database, which
%   is exactly what v1 says. A body that can never be filled is not a landing
%   pad; it is a declaration that something is here when nothing is.
%
%   `datum.unit` is left EMPTY for the same class of reason: the modality is
%   known, the per-sample unit is not (raw ADC counts, mV and V are all live
%   possibilities and NDI records none of them on the element). The quantity is
%   carried where the plan puts it -- the observation CLASS and `variable`.
%
%   ---------------------------------------------------------------------
%   GUARD A IS NOT FULLY BUILDABLE TODAY. WHAT IS BUILT INSTEAD.
%   ---------------------------------------------------------------------
%   Signed Guard A: an unmapped type still yields a VALUED observation over a
%   bare self-describing `sampled_body` with a queryable `modality_unresolved`
%   flag -- "no dimensioned data_type, since `array` is killed".
%
%   Both halves of that need V_eta classes/fields that DO NOT EXIST, verified
%   rather than assumed:
%
%     1. AN UNDIMENSIONED CONCRETE OBSERVATION LEAF. `subject_observation`
%        carries "abstract": true in
%        schemas/V_eta/stable/subject_observation.json, and
%        +did2/+schema/cache.m:507-511 raises
%        `did2:validation:abstractInstantiation` for any document naming an
%        abstract class. Every concrete leaf under it
%        (`*_observation`, 31 of them) mixes in a data_type -- there is no
%        undimensioned one. So the fallback observation has no class to be.
%     2. THE FLAG. `modality_unresolved` appears NOWHERE in the schema:
%          grep -rn "modality_unresolved" /home/user/DID-schema/schemas/
%          -> matches only V_eta_recording_observation_plan.md (4 lines) and
%             V_eta_tenet_audit.md (1 line) -- i.e. the decision documents
%             themselves. No class, no field.
%
%   Both are DID-schema changes, which this build may not make (CLAUDE.md
%   operating rule 1: DO NOT WRITE TO `schemas/`). Picking a dimensioned leaf
%   anyway would assert a physical quantity we do not know -- precisely what
%   migrators_j/pyraview.m:99-103 already had to flag about itself ("the physical
%   quantity is not carried on the doc; voltage is the dominant NDI case ... but
%   a non-voltage pyraview would need per-signal quantity typing"), and #30
%   exists to END that, not to spread it.
%
%   So the unresolved path emits NO observation and instead returns
%   UNRESOLVEDLABEL, which migrators_j.element records as a `term_assertion` on
%   the element-subject:
%
%       subject_statement.variable.name = 'modality unresolved'
%       term.value.name                 = the element type (or the best-known label)
%
%   That is built entirely from DECLARED, queryable fields, on the class
%   element.m already uses for its kind assertions. It gives the plan's bullet 3
%   -- "surfaced as a queryable worklist, resolved by extending the map (+ re-run)"
%   -- with the exact search the plan's wording implies, and it costs nothing to
%   replace with the real flag once the two schema pieces land. RETIREOBSERVES is
%   false on this path, so the `observes` relation is KEPT and nothing is lost.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

arguments
    preBody (1,1) struct
    instrumentId = ''
    subjectId = ''
    elementType = ''
    bestKnownLabel = ''
end
% Deliberately unsized/untyped above: every one of these can legitimately be the
% empty char '' (0x0), which does not satisfy a `(1,:) char` declaration -- an
% element with no `subject_id`, or with an empty `type`, is a real did_v1 shape.
instrumentId      = char(instrumentId);
subjectId     = char(subjectId);
elementType    = char(elementType);
bestKnownLabel = char(bestKnownLabel);

bodies = {};
retireObserves = false;
unresolvedLabel = '';

% NO SUBJECT => NO OBSERVATION. `subject_statement.subject_id` is the ONE
% required edge on this chain (measured: subject_observation declares only
% `derived_from_#`, subject_interaction only optional edges), and an empty
% required edge validates clean because +did2/+validate/references.m:90 skips
% empty edges -- the invented-empty-edge pattern, 7,233 documents and counting.
if isempty(subjectId)
    return;
end

% NO INSTRUMENT => THE EDGE IS OMITTED, NOT EMITTED EMPTY. This used to be a
% second `return`, which was safe only because the caller passed `base.id` and
% that is never empty. The spike-train caller passes `underlying_element_id`,
% which CAN be absent, and the two wrong answers are both available here: an
% empty `instrument_id` is the invented-empty-edge defect, and dropping the
% observation entirely would lose a real spike train because we do not know
% which probe recorded it. `instrument_id` is optional in the schema
% (subject_interaction, mustBeNonEmpty false), so saying nothing is expressible
% and is what the source actually says.
hasInstrument = ~isempty(instrumentId);

[entries, disposition] = jRecordingModality(elementType);

switch disposition
    case 'stimulator'
        return;              % the other direction; `observes` stays for now
    case 'unresolved'
        unresolvedLabel = firstNonEmptyChar(elementType, bestKnownLabel, '(unspecified)');
        return;
    case 'recording'
        % resolved; the observation itself is minted per epoch (see below)
    otherwise
        return;              % an unknown disposition is never guessed at
end

% 2026-10-21: NOTHING IS EMITTED HERE (see the header). The modality is
% resolved -- `entries` is the type's observation leaf(s) -- but the
% observation belongs to an EPOCH and owns that epoch's files, neither of which
% an element document carries; the batch pass (resolveEpochProbemap) or the
% NDI second pass mints it. `hasInstrument` and `entries` are kept so the
% dispositions above stay exactly what they were.
%#ok<*NASGU>
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

function s = firstNonEmptyChar(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = char(varargin{k}); return; end
end
end
