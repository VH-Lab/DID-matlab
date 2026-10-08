function bodies = stimulus_presentation(preBody)
%STIMULUS_PRESENTATION Brainstorm-J migrator: did_v1 stimulus_presentation --
%   the decomposition is DEFERRED to the NDI second pass; pass 1 is a GUARDED
%   PASSTHROUGH that carries the document intact.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   THE SIGNED MODEL (what this document eventually becomes)
%   ---------------------------------------------------------------------
%   V_eta_stimulus_model_plan.md, TEAM-SIGN-OFF [stimulus] 2026-08-08. A
%   presentation is an ordered, timed list of references to DEDUPED stimulus
%   VALUE documents -- the ensemble pattern applied to stimulation:
%
%     timed_sequence                  (3) data_type, DIRECTION-NEUTRAL
%        value.presentation_order     an INDEX ARRAY into the presented_id refs
%        depends_on presented_id -> data_type   BROAD, MULTIPLE, one per DISTINCT
%                                               stimulus (visual_grating, image, ...)
%        per-trial timing             -> sampled_body, irregular time axis (rev 2)
%     timed_sequence_manipulation     (4) leaf = subject_manipulation + timed_sequence
%        depends_on subject_id     -> subject             who was shown the sequence
%                   instrument_id  -> entity              THE STIMULATOR (T7) --
%                                                         this is where v1's
%                                                         stimulus_element_id goes
%                   time_reference -> relative_reference  relative_to -> epoch (rev 1)
%
%   The presentation is DECOMPOSED AROUND ITS PRESERVED ID, NOT DISSOLVED: the
%   v1 id stays on the body-of-record (the timed_sequence) so every fan-in
%   dependent still resolves. The fan-in is real and large --
%   `stimulus_response_scalar` carries `stimulus_presentation_id`
%   (+ndi/+app/+stimulus/tuning_response.m:326) and `control_stimulus_ids`
%   carries it too (:656). Reassigning that id is the mistake that produced
%   11,448 orphans on Soph.
%
%   ---------------------------------------------------------------------
%   WHY PASS 1 CANNOT BUILD ANY OF IT -- four independent blockers
%   ---------------------------------------------------------------------
%   1. NO SUBJECT IS KNOWABLE FROM THIS DOCUMENT. `timed_sequence_manipulation`
%      is a subject_manipulation, so `subject_id` is required by tier. The v1
%      document names a STIMULATOR, not a subject: NDI's only dependency on this
%      class is `stimulus_element_id`, set from `ndi_element_stim.id()`
%      (+ndi/+app/+stimulus/decoder.m:138) and from the mock's
%      `stimulus_element_id` argument (+ndi/+mock/+fun/stimulus_presentation.m).
%      Who WATCHED the sequence is recoverable only through the response link
%      (stimulus_response -> element -> subject), i.e. the whole migrated graph.
%      NDI already has that resolver -- ndi.migrate.internal.bodyResolver's
%      `subjectsForPresentation` -- and it lives in the second pass for exactly
%      this reason. Minting the leaf here would emit an EMPTY REQUIRED
%      `subject_id`, which `+did2/+validate/references.m:90` skips, so it would
%      validate clean and be invisible: the image_stack husk (4,563 documents)
%      and the fitcurve husk, one more time.
%
%   2. MINTING THE `timed_sequence` HERE WOULD DESTROY THE STIMULUS DICTIONARY.
%      `timed_sequence` declares exactly one field, `value.presentation_order`.
%      The v1 block also carries `stimuli`, a struct ARRAY of per-stimulus
%      `parameters` (decoder.m:103-106 builds one entry per `data.parameters{k}`;
%      the Hartley case is 225 of them). Those parameters have no slot on
%      `timed_sequence` -- by design, because they belong in the referenced
%      `visual_grating`/`image`/... documents, which do not exist yet. Emitting
%      a timed_sequence in pass 1 therefore drops the entire dictionary while
%      producing a document that validates.
%
%   3. DEDUPLICATION OF THE DISTINCT STIMULI IS A WHOLE-CORPUS OPERATION. The
%      signed model stores each distinct config ONCE and references it. A
%      single-document migrator can only dedupe within one presentation, so it
%      would mint the same 225 basis gratings again for every presentation --
%      corpus Dab alone has 1,242 presentations. The precedent for putting a
%      corpus-wide mint in the second pass is
%      ndi.migrate.internal.pathSPromotion, which promotes loci to Path-S
%      subjects using "the whole migrated body set ... that a single-document
%      migrator cannot see", with a find-or-create keyed on (animal, site).
%      The stimulus dedup is the same shape keyed on (content hash of
%      `stimuli(k).parameters`).
%
%   4. `timed_sequence` IS DECLARED ABSTRACT TODAY. V_eta/draft/timed_sequence.json
%      carries `"abstract": true`, and +did2/+schema/cache.m raises
%      `did2:validation:abstractInstantiation` for any document naming an
%      abstract class. So a standalone timed_sequence body-of-record -- which
%      the signed multi-subject `storage_mode: reference` case requires -- cannot
%      be instantiated at all until that flag is reconsidered. Recorded, not
%      worked around.
%
%   DECISION, stated plainly so it is not re-litigated: the decomposition
%   (distinct-stimulus minting + dedup, the timed_sequence, the manipulation
%   leaf, the relative_reference and the per-trial sampled_body) is DEFERRED TO
%   THE NDI SECOND PASS. Pass 1 emits nothing new and loses nothing.
%
%   ---------------------------------------------------------------------
%   THE GUARD: `element_id` IS AN INVENTION, AND IT IS THE LARGEST REMAINING
%   INSTANCE OF THE INVENTED-EMPTY-EDGE PATTERN
%   ---------------------------------------------------------------------
%   NDI names this edge `stimulus_element_id` in all four places that could
%   settle it, on origin/main:
%
%     ndi_common/database_documents/stimulus/stimulus_presentation.json
%         depends_on: [ { "name": "stimulus_element_id", "value": "" } ]
%     ndi_common/schema_documents/stimulus/stimulus_presentation_schema.json
%         depends_on: [ { "name": "stimulus_element_id", "mustbenotempty": 1 } ]
%     +ndi/+app/+stimulus/decoder.m:138
%         nd = set_dependency_value(nd,'stimulus_element_id',ndi_element_stim.id());
%     +ndi/+mock/+fun/stimulus_presentation.m
%         stim_pres_doc.set_dependency_value('stimulus_element_id',stimulus_element_id);
%
%   There is no `element_id` anywhere in the class. V_eta's tombstone
%   nevertheless declares `element_id` as a REQUIRED dependency, and because
%   universalRenames normalises a depends_on entry's SHAPE (id/value ->
%   document_id) and NEVER its NAME, nothing ever filled it: the census reports
%   `stimulus_presentation.element_id` empty on 2,670 of 2,670 documents
%   (B 1242 / Dab 1242 / Soph 175 / 20211116 11). Every one validated clean
%   because references.m skips empty edges.
%
%   So a body that arrives HERE carrying an `element_id` dependency cannot have
%   come from a real did_v1 document; it came from DID-schema's own V_alpha/
%   V_zeta snapshot, or from a fixture built against it. Reject it by name --
%   the same stance as openminds_stimulus (`stimulus_id`) and
%   epochfiles_ingested (`epochid`).
%
%   NOTE what this guard does NOT do. It cannot take the 2,670-document census
%   row to zero: that row is produced by the TOMBSTONE declaring `element_id`
%   required, not by anything a migrator emits. The repair is schema-side
%   (build_v_eta.py) and is reported alongside this build.
%
%   ---------------------------------------------------------------------
%   WHAT THE PASSTHROUGH MUST CARRY, AND WHY EACH PIECE MATTERS
%   ---------------------------------------------------------------------
%     base.id                  the anchor the whole decomposition hangs on
%     stimulus_element_id      -> instrument_id on the future manipulation (T7)
%     epochid.epochid          -> the relative_reference's `relative_to` epoch;
%                                 the epochid superclass is on the NDI template
%     presentation_order       -> timed_sequence.value.presentation_order
%     stimuli(k).parameters    -> the distinct presented data_type documents
%     files: presentation_time.bin  -> the irregular time axis (revision 2)
%     presentation_time (block)     the DEPRECATED vintage, see below
%     app                      added by the writer via `+ ..._obj.newdocument()`
%                              (decoder.m:135-137; ndi.app/newdocument fills
%                              app.name/version/url/os/...) even though the
%                              template does not list `app` as a superclass.
%
%   TWO VINTAGES OF `presentation_time`, BOTH REAL. The current writer puts the
%   per-trial timing in a FILE (decoder.m:127-131 writes presentation_time.bin;
%   the `'presentation_time', presentation_time` line is commented out at :133
%   with "we now put this in a file"). But the READER still branches:
%
%     decoder.m:154-157
%       if isfield(...stimulus_presentation,'presentation_time')   % old way
%           warning('... uses deprecated form of presentation_time storage.');
%
%   -- and the shipped TEMPLATE still declares the block with all six sub-fields
%   (clocktype, stimopen, onset, offset, stimclose, stimevents). NDI even keeps a
%   migration checklist for the change (docs/developer_notes/
%   stimulus_presentation_change.m). That is positive evidence that documents
%   carrying the inline block exist; a passthrough must not drop it, and the
%   tombstone must declare it or those documents quarantine on
%   `did2:validation:undeclaredField`.
%
%   ---------------------------------------------------------------------
%   ONE MORE THING THE SECOND PASS MUST NOT DO
%   ---------------------------------------------------------------------
%   `ndi.migrate.internal.stimulusPresentationToManipulation` still implements
%   the SUPERSEDED #19 dissolve: one `visual_grating_manipulation` per
%   presentation with a per-trial `sampled_body`, reading `block.presentation_time`
%   (the deprecated vintage only) and calling `gratingValueFromParameters`. The
%   signed plan supersedes it -- stimuli are REFERENCED, not folded into the
%   manipulation, and the presentation keeps its id. That file is in NDI-matlab
%   and out of this build's scope; it is named here so the second-pass build
%   replaces it rather than extending it.
%
%   See also: did2.convert.migrators_j.control_stimulus_ids (the sibling that
%   DOES fold, because its whole content is local),
%   did2.convert.migrators_j.openminds_stimulus (the invented-edge guard),
%   did2.convert.migrators_j.epochfiles_ingested (the guarded-passthrough shape),
%   ndi.migrate.internal.pathSPromotion (the second-pass harness this belongs in).

arguments
    preBody (1,1) struct
end

% ---------------------------------------------------------------------------
% SHAPE ASSERTION -- a body that could only come from the V_alpha/V_zeta snapshot.
% ---------------------------------------------------------------------------
if hasDependency(preBody, 'element_id')
    error('did2:convert:stimulusPresentationInventedEdge', ...
        ['stimulus_presentation body carries an `element_id` dependency. No ' ...
         'did_v1 document has one -- NDI''s template, its schema, ' ...
         '+ndi/+app/+stimulus/decoder.m:138 and +ndi/+mock/+fun/' ...
         'stimulus_presentation.m all name the edge `stimulus_element_id`. ' ...
         '`element_id` is the V_eta invention that was empty on 2,670 of 2,670 ' ...
         'corpus documents, so a body carrying it came from the V_alpha/V_zeta ' ...
         'snapshot or a fixture built against it.']);
end

% Deliberate passthrough. `bodies = {preBody}` is how a migrator says "nothing to
% do here"; v1_to_v2 counts it in `unconverted_by_class`, which is where this
% deferral should be visible -- and where it will stop being visible the day the
% second-pass decompose lands.
bodies = {preBody};
end

% ===================== small helpers =======================================

function tf = hasDependency(bodyStruct, name)
%HASDEPENDENCY True when a depends_on entry with NAME is present (empty or not).
%   Presence is the signal here, not the value: the invented edge is empty on
%   100% of the documents that carry it, so testing the value would never fire.
tf = false;
if ~isfield(bodyStruct, 'depends_on'); return; end
deps = bodyStruct.depends_on;
if ~isstruct(deps); return; end
for k = 1:numel(deps)
    d = deps(k);
    if isfield(d, 'name') && strcmp(char(d.name), name); tf = true; return; end
end
end
