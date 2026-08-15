function [bodies, retireObserves, unresolvedLabel] = jRecordingObservation(preBody, elementId, specimenId, elementType, bestKnownLabel)
%JRECORDINGOBSERVATION Assemble the typed observation(s) for a DIRECT recording
%   element -- open item #30, SIGNED 2026-08-10 in
%   V_eta_recording_observation_plan.md.
%
%   [BODIES, RETIREOBSERVES, UNRESOLVEDLABEL] = jRecordingObservation(PREBODY,
%       ELEMENTID, SPECIMENID, ELEMENTTYPE, BESTKNOWNLABEL)
%
%   The signed model, one line: a raw continuous recording IS a
%   `<modality>_observation` of the SPECIMEN, taken WITH the electrode.
%
%       <modality>_observation   subject_id    = SPECIMENID (the slice/animal --
%                                                v1's element.subject_id)
%                                instrument_id = ELEMENTID  (the electrode, its
%                                                own subject, in the instrument
%                                                role -- T7)
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
%   ELEMENTID stays on the SUBJECT that migrators_j.element mints. It is NOT
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
    elementId = ''
    specimenId = ''
    elementType = ''
    bestKnownLabel = ''
end
% Deliberately unsized/untyped above: every one of these can legitimately be the
% empty char '' (0x0), which does not satisfy a `(1,:) char` declaration -- an
% element with no `subject_id`, or with an empty `type`, is a real did_v1 shape.
elementId      = char(elementId);
specimenId     = char(specimenId);
elementType    = char(elementType);
bestKnownLabel = char(bestKnownLabel);

bodies = {};
retireObserves = false;
unresolvedLabel = '';

% NO SPECIMEN => NO OBSERVATION (subject_statement.subject_id is REQUIRED, and an
% empty required edge validates clean because +did2/+validate/references.m:90
% skips empty edges -- the invented-empty-edge pattern, 7,233 documents and
% counting). NO ELEMENT ID => no instrument to name either.
if isempty(specimenId) || isempty(elementId)
    return;
end

[entries, disposition] = jRecordingModality(elementType);

switch disposition
    case 'stimulator'
        return;              % the other direction; `observes` stays for now
    case 'unresolved'
        unresolvedLabel = firstNonEmptyChar(elementType, bestKnownLabel, '(unspecified)');
        return;
    case 'recording'
        % the assembler below runs
    otherwise
        return;              % an unknown disposition is never guessed at
end

sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');

% ---- the shared session-relative 'during' anchor -----------------------------
anchor = jSessionAnchor(preBody, 'during');
anchorId = anchor.base.id;

for k = 1:numel(entries)
    e = entries(k);
    obsId = did.ido.unique_id();

    obs = struct();
    obs.document_class = classBlock(e.class, {'subject_observation', e.mixin});
    obs.depends_on = [ ...
        struct('name', 'subject_id',       'value', specimenId), ...  % the SPECIMEN
        struct('name', 'instrument_id',    'value', elementId), ...   % the electrode (T7)
        struct('name', 'time_reference_1', 'value', anchorId)];
    obs.base = struct('id', obsId, 'session_id', sessionId, ...
        'name', 'migrated_recording_observation', 'datestamp', datestamp);
    % 'reference', not 'body': see the header. The samples live in the
    % acquisition files, reached the way v1 reaches them.
    obs.subject_statement = struct( ...
        'variable', jOntologyTerm('', e.variable), ...
        'storage_mode', 'reference');
    % `method` is left blank: the leaf class already names the act (the
    % jStartInteraction convention), and no algorithm produced this value.
    % No `sample_time` on the statement -- the body owns the cadence (D1).
    obs.subject_interaction = struct('method', jOntologyTerm('', ''));
    obs.subject_observation = struct();
    obs = attachQuantityBlock(obs, e.mixin);

    % NO BODY. The element document carries no files -- see the header -- so a
    % `sampled_body` minted here could only ever be empty. The observation
    % alone is the honest record: this electrode measured this modality from
    % this specimen, and the value is outside the database.
    bodies{end+1} = obs;  %#ok<AGROW>
end

if isempty(bodies)
    return;
end
bodies{end+1} = anchor;
retireObserves = true;   % the instrument_id edge is now present, so `observes` may go
end

% ===================== builders ============================================

function obs = attachQuantityBlock(obs, mixin)
%ATTACHQUANTITYBLOCK The data_type block, empty because the value is body-backed.
%   `image` declares `value` with "mustBeNonEmpty": true, so the
%   raster CELL must be present even when the pixels are not. Only DECLARED
%   subfields are written; `dtype` stays blank because R6 is right that dtype is
%   not recoverable from bytes we have not read, and a guess here would be the
%   thing R6 wrote the rule against.
%
%   THIS COMMENT SAID "(the only data_type that does)" AND CITED
%   schemas/V_eta/draft/image.json. Both were wrong; corrected 2026-08-11.
%   The path is stable/, not draft/, and the uniqueness claim is wrong by 8x:
%
%       DENOMINATOR: 243 V_eta class schemas parsed
%       declaring field `value` mustBeNonEmpty: 10
%         contrast_sensitivity  date  harmonic_component  image  polynomial
%         term  timed_sequence  tuning_curve        (8 data_type descendants)
%         absolute_reference  relative_reference   (time_reference, not data_type)
%
%   It matters because this comment states the RULE this function implements,
%   and the branch below fires for `image` and nothing else. The blast radius is
%   bounded today only because jRecordingModality reaches just
%   voltage/current/image/acceleration/temperature -- but a maintainer adding a
%   modality that maps to `date`, `term`, `tuning_curve` or `contrast_sensitivity`
%   would read "image is the only one", skip the cell, and emit a document that
%   fails mustBeNonEmpty. If you add such a modality, extend the branch.
%
%   Asserted twice, here and in testMigratorsJRecordingObservation.m:223 -- a
%   test written from the same premise as the code, so it pinned the error
%   rather than catching it.
if strcmp(mixin, 'image')
    obs.image = struct();
    obs.image.value = struct('pixels', [], 'dtype', '', ...
        'color_model', jOntologyTerm('', ''));
    return;
end
obs.(mixin) = struct();
end

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

% ===================== small helpers =======================================

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
