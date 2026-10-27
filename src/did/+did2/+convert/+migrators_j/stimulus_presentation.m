function bodies = stimulus_presentation(preBody)
%STIMULUS_PRESENTATION Brainstorm-J migrator: did_v1 stimulus_presentation --
%   the decomposition is DONE BY THE NDI SECOND PASS; pass 1 is a GUARDED
%   PASSTHROUGH that carries the document intact.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHAT THIS DOCUMENT BECOMES (in NDI's second pass, not here)
%   ---------------------------------------------------------------------
%   ndi.migrate.internal.stimulusPresentationToItem decomposes each
%   presentation into the did-schema #88 stimulus shape:
%
%     method            one standalone document per DISTINCT stimulus, given
%                       as a recipe {term, parameters}, deduplicated by the
%                       recipe (V_eta_method_plan.md: "recipe stimuli are
%                       method documents referenced by item"; visual_grating
%                       is deleted)
%     manipulation      ONE per presentation, value kind `item`
%                       (V_eta_study_plan.md: `item` replaces `timed_sequence`):
%                         base.id         THE V1 PRESENTATION id, kept
%                         entity_id       the animal, or the session's cohort
%                         instrument_id   the stimulator, v1 stimulus_element_id (T7)
%                         item_id         the distinct method documents
%                         item.value.item the playlist into them, 0-based
%                         covariates      onset time / offset time / control
%                                         condition along the presentation
%                                         dimension
%
%   A presentation whose subject cannot be resolved becomes a standalone
%   item with no manipulation (V_eta_stimulus_model_plan.md, Decided by Jess
%   Haley, 2026-10-21 [presentation with no subject]). A Hartley presentation
%   carries only the generator spec; its basis comes from the hartley_calc
%   documents through ndi.migrate.internal.hartleyBasisGratings.
%
%   The presentation is DECOMPOSED AROUND ITS PRESERVED ID, NOT DISSOLVED, so
%   every fan-in dependent still resolves. The fan-in is real and large --
%   `stimulus_response_scalar` carries `stimulus_presentation_id`
%   (+ndi/+app/+stimulus/tuning_response.m:326) and `control_stimulus_ids`
%   carries it too (:656). Reassigning that id is the mistake that produced
%   11,448 orphans on Soph.
%
%   ---------------------------------------------------------------------
%   WHY PASS 1 CANNOT DO IT -- three independent blockers
%   ---------------------------------------------------------------------
%   1. NO SUBJECT IS KNOWABLE FROM THIS DOCUMENT. The v1 document names a
%      STIMULATOR, not a subject: NDI's only dependency on this class is
%      `stimulus_element_id`, set from `ndi_element_stim.id()`
%      (+ndi/+app/+stimulus/decoder.m:138) and from the mock's
%      `stimulus_element_id` argument (+ndi/+mock/+fun/stimulus_presentation.m).
%      Who WATCHED the sequence is recoverable only through the migrated graph
%      (stimulus_response -> element -> subject, the epoch's elements, the
%      probe map) -- the resolution order in V_eta_stimulus_model_plan.md,
%      "Who received a presentation". Minting the manipulation here would emit
%      an EMPTY REQUIRED `entity_id`, which `+did2/+validate/references.m`
%      skips, so it would validate clean and be invisible: the image_stack
%      husk (4,563 documents) and the fitcurve husk, one more time.
%
%   2. DEDUPLICATION OF THE DISTINCT STIMULI IS A WHOLE-CORPUS OPERATION. Each
%      distinct recipe is stored ONCE and referenced. A single-document
%      migrator can only dedupe within one presentation, so it would mint the
%      same 225 Hartley stimuli again for every presentation -- corpus Dab
%      alone has 1,242 presentations.
%
%   3. THE TIMING IS IN AN ATTACHED FILE. The current writer puts per-trial
%      timing in presentation_time.bin (see TWO VINTAGES below). Reading it
%      needs the session's .ndi directory on disk
%      (ndi.migrate.internal.v1AttachedFile); a per-document migrator is
%      handed the document only.
%
%   DECISION, stated plainly so it is not re-litigated: the decomposition is
%   NDI's second pass. Pass 1 emits nothing new and loses nothing.
%
%   ---------------------------------------------------------------------
%   THE GUARD: `element_id` IS AN INVENTION
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
%   There is no `element_id` anywhere in the class. An earlier V_eta class
%   declared `element_id` as a REQUIRED dependency, and nothing ever filled it:
%   the census reported it empty on 2,670 of 2,670 documents (B 1242 /
%   Dab 1242 / Soph 175 / 20211116 11). V_eta's stimulus_presentation now
%   declares `stimulus_element_id` instead.
%
%   So a body that arrives HERE carrying an `element_id` dependency cannot have
%   come from a real did_v1 document; it came from DID-schema's old V_alpha/
%   V_zeta snapshot, or from a fixture built against it. Reject it by name --
%   the same stance as openminds_stimulus (`stimulus_id`) and
%   epochfiles_ingested (`epochid`).
%
%   ---------------------------------------------------------------------
%   WHAT THE PASSTHROUGH MUST CARRY, AND WHY EACH PIECE MATTERS
%   ---------------------------------------------------------------------
%     base.id                  the manipulation's id (inbound edges resolve)
%     stimulus_element_id      -> instrument_id on the manipulation (T7)
%     epochid.epochid          -> the epoch the timing is relative to, and the
%                                 elements used to find the subject; the
%                                 epochid superclass is on the NDI template
%     presentation_order       -> the playlist, item.value.item
%     stimuli(k).parameters    -> the distinct method documents
%     files: presentation_time.bin  -> onset / offset covariates
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
%   class must declare it or those documents quarantine on
%   `did2:validation:undeclaredField`.
%
%   See also: ndi.migrate.internal.stimulusPresentationToItem (the
%   decomposition), ndi.migrate.internal.hartleyBasisGratings,
%   did2.convert.migrators_j.control_stimulus_ids,
%   did2.convert.migrators_j.openminds_stimulus (the invented-edge guard),
%   did2.convert.migrators_j.epochfiles_ingested (the guarded-passthrough shape).
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI stimulus_presentation.json + epochid.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, with the `app` block
%   newdocument() adds, as +ndi/+app/+stimulus/decoder.m and
%   +ndi/+mock/+fun/stimulus_presentation.m write it), and pass 1 carries it
%   UNTOUCHED, whatever it holds, citing carry-045: every field reaches NDI's
%   second pass, which reads the presentation from the v1 input documents
%   (ndi.migrate.local resolveStimulusPresentations), not from this pass's
%   output, so what NDI receives does not change. The pass-1 carry is now the
%   v1 source itself (before: the universalRenames output, also stamped
%   did_v1). The renamed path carried a document universalRenames would have
%   changed with carry-049 instead; both carry it. The edges are read with
%   did2.convert.v1read.readDependsOn (either key, a struct or a cell), the id
%   with readBase (a legacy `ndi_document` identity too).
%   did2.convert.roundtrip.stimulus_presentation holds no inverse of a
%   conversion, because pass 1 converts nothing: testRawV1RoundTripSession
%   checks the carry.

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
% deferral is visible. NDI's second pass (stimulusPresentationToItem) does the
% decomposition.
% [stimulus_presentation retired] (Decided by Jess Haley, 2026-10-26, did-schema
% V_eta_go_forward_class_audit.md): not a V2 class; pass 1 carries the v1
% document UNCHANGED as v1 ([passthrough stays v1]) -- stamped did_v1 by
% v1_to_v2, never read against V_eta -- for NDI's second pass.
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: carry-045
did2.convert.reportNote('carried_as_v1', 'stimulus_presentation', ...
    id, ['[carry-045] retired class: decomposed by the NDI second ' ...
    'pass ([stimulus_presentation retired])']);
bodies = {preBody};
end

% ===================== small helpers =======================================

function tf = hasDependency(bodyStruct, name)
%HASDEPENDENCY True when a depends_on entry with NAME is present (empty or not).
%   Presence is the signal here, not the value: the invented edge is empty on
%   100% of the documents that carry it, so testing the value would never fire.
%   Read with did2.convert.v1read.readDependsOn: a struct array or the cell
%   jsondecode gives for entries with different keys.
tf = false;
if ~isfield(bodyStruct, 'depends_on') || isempty(bodyStruct.depends_on) ...
        || ~(isstruct(bodyStruct.depends_on) || iscell(bodyStruct.depends_on))
    return;
end
deps = did2.convert.v1read.readDependsOn(bodyStruct);
tf = any(strcmp({deps.name}, name));
end
