function v2Body = ontology_image(preBody)
%ONTOLOGY_IMAGE Brainstorm-J migrator: did_v1 ontology_image, dispatched ON SHAPE.
%   The current NDI shape (`ontology_nodes` + an `ontologyTableRow_id` edge + the
%   `ngrid` raster) is a GUARDED PASSTHROUGH deferred to the NDI second pass: a table
%   row is not a subject, so pass 1 cannot fill `subject_statement.subject_id` without
%   minting the husk the image_stack guard exists to stop. The legacy
%   `ontology_name` + `ontology_region` shape (which the correction below shows has
%   never existed in NDI) would migrate 1 -> 2 to a term_observation about the
%   element-subject + a session anchor. Any third shape ERRORS rather than emitting.
%   The raster and the provenance edge are deferred with the passthrough (#47).
%
%   THIS SUMMARY LINE READ ONLY "did_v1 ontology_image." until 2026-08-12 -- a
%   placeholder that said nothing, in a file whose whole point is that the dispatch
%   is the interesting part. The body below was already correct and is unchanged.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS MIGRATOR IS VINTAGE-AWARE, AND WHY ONE VINTAGE IS DEFERRED
%   ---------------------------------------------------------------------
%   CORRECTION, 2026-08-09 -- READ THIS BEFORE THE TWO-VINTAGE STORY BELOW.
%   This header says NDI REDEFINED `ontologyImage`, giving two did_v1 shapes.
%   That is FALSE. NDI never redefined it and VINTAGE A HAS NEVER EXISTED:
%   `git log --all --diff-filter=A -- '*ontologyImage.json'` returns exactly
%   one commit, every revision of the file carries `ontologyTableRow_id` +
%   `ontologyNode`, and searching all of NDI history for `ontologyRegion` /
%   `ontology_region` matches only DID-side alias-table commits. NDI-matlab
%   `04dcdf9` had already established this while deleting four fabricated
%   alias rows: "ontologyImage created 2025-07-03, three commits total,
%   always {ontologyNode} with an ontologyTableRow_id dependency. Never had
%   ontology_name or ontology_region."
%
%   Vintage A is DID-schema's own V_alpha/V_beta snapshot -- which the very
%   next comment block states outright ("legacy; DID-schema V_alpha/V_beta
%   ancestry") while still calling it a did_v1 vintage. Same fabrication the
%   ground-truth track exists to remove, wearing the word "legacy".
%
%   THE CODE IS LEFT EXACTLY AS IT IS, deliberately. This migrator branches
%   on SHAPE and errors when nothing matches, so a branch for a shape that
%   cannot occur simply never fires; it costs nothing and it is the safe
%   direction to be wrong in. Only the claim was wrong, and only the claim is
%   corrected. Do not plan further work around a second vintage.
%
%   The original text follows, with vintage A now understood as fabricated:
%
%   NDI REDEFINED `ontologyImage` upstream, so two incompatible shapes are
%   both "did_v1". Any migrator here has to say which one it is looking at:
%
%     VINTAGE A (legacy; DID-schema V_alpha/V_beta ancestry)
%         ontology_image.ontology_name    char  -- the CURIE
%         ontology_image.ontology_region  char  -- the human-readable label
%         depends_on: element_id                -- a subject-bearing edge
%         file:       ontology_image_file
%         superclasses: base
%
%     VINTAGE B (current NDI production; ndi_common/database_documents/
%                data/ontologyImage.json + +ndi/+setup/+NDIMaker/imageDocMaker)
%         ontology_image.ontology_nodes   char  -- a COMMA-JOINED, sorted list
%                                                 of one or more CURIEs, each
%                                                 normalised by ndi.ontology.lookup
%                                                 (the template's singular
%                                                 `ontologyNode` is STALE; the
%                                                 writer and its own lookup query
%                                                 both use the plural)
%         depends_on: ontologyTableRow_id       -- NOT a subject
%         file:       ontologyImage.ngrid
%         superclasses: base, ngrid             -- the raster rides an ngrid block
%
%   The PREVIOUS implementation read `preBody.ontology_image.region`. That
%   field exists in NEITHER vintage -- it is the *output* of the V_delta
%   migrator (+did2/+convert/+migrators/ontology_image.m), which composes
%   `region` from vintage A's two chars. But v1_to_v2 routes a class to
%   migrators_j INSTEAD OF the V_delta migrator (see v1_to_v2.m, the
%   splitPackage branch), so a J migrator receives a body that has only been
%   through universalRenames -- never the V_delta reshape. The read therefore
%   never matched a real document; it matched only the unit fixture, which had
%   been built to the V_delta output shape. The result was silent: an empty
%   ontology_term still has fieldnames, so it satisfies `mustBeNonEmpty`, and
%   an empty depends_on edge is skipped by did2.validate.references. Every
%   ontologyImage document therefore migrated to a content-free husk that
%   passed both the quarantine gate and the orphan gate.
%
%   DISPOSITION, decided with the team (V_eta_ngrid_family_findings.md):
%
%     VINTAGE A -> MIGRATED HERE. Everything needed is on the document: the
%                  term comes from the two coordinated chars (the same idiom
%                  as +migrators_j/ontology_label.m), and `element_id` supplies
%                  the subject. 1 -> 2 (the observation + the session anchor).
%
%     VINTAGE B -> DEFERRED TO THE NDI SECOND PASS; passed through UNCHANGED.
%                  The terms are resolvable here, but the SUBJECT is not: the
%                  document's only edge is `ontologyTableRow_id`, and a table
%                  row is not a subject (subject_statement.subject_id declares
%                  must_refer_to_document_class: subject). The subject is
%                  reachable only THROUGH the table row, which requires the
%                  migrated-id graph that a single-document migrator cannot
%                  see. Emitting a term_observation with an empty subject_id
%                  is exactly the husk this fix exists to stop -- so we do not
%                  emit one. The document is left intact so the second pass can
%                  decompose it with the graph in hand (the same strategy
%                  stimulus_presentation uses: no pass-1 migrator, assembled
%                  entirely in the second pass).
%
%                  A passthrough MUST validate, so V_eta's `ontology_image`
%                  schema declares vintage B faithfully (ngrid superclass,
%                  ontology_nodes, ontology_table_row_id). See build_v_eta.py.
%
%                  Deferred with it: the raster itself (the ngrid block + the
%                  .ngrid file) and the ontologyTableRow_id provenance edge.
%                  Under R6 the natural target is an image_observation beside
%                  the term observations; that is part of the ngrid work, not
%                  this fix.
%
%   #47 UPDATE, 2026-08-10 -- THE RASTER'S HOME, AND WHAT CHANGED UNDERNEATH.
%   The R6 home is confirmed and it is a SECOND-PASS target, not a pass-1 one:
%   an `image_observation` (+ a data_body) beside the term observations. It
%   cannot be minted here for the same reason the term observation cannot --
%   `subject_statement.subject_id` declares `must_refer_to_document_class:
%   subject`, and this document's only edge is a table row. Emitting one would
%   reproduce, exactly, the 4,563-document `image_observation.subject_id` husk
%   that the image_stack guard was just added to stop.
%
%   So the pass-1 obligation is to carry the raster INTACT, and until 2026-08-10
%   it was not being met. This migrator strips nothing -- but the SUPERCLASS
%   pass runs first (v1_to_v2.applySuperclassMigrators) and was never bypassed
%   by the migrators_j split, so +migrators/ngrid.m deleted `coordinates` and
%   `data_size` on every one of these documents before this function was
%   called. Fixed by +migrators_j/+super/ngrid.m, which carries the v1 block
%   verbatim, plus the matching V_eta `ngrid` tombstone. `coordinates` has no
%   HOME yet (its decided destination, `axes[k].values`, belongs to #45, which
%   is blocked on #32) -- it is carried, not placed.
%
%   NOT FIXED, and it needs a human: the tombstone declares the provenance edge
%   as `ontology_table_row_id`, while NDI's template and schema both name it
%   `ontologyTableRow_id` -- and universalRenames does NOT rename depends_on
%   entry names (it skips the whole key, universalRenames.m:308; only `id` /
%   `value` -> `document_id` is rewritten). So the name a real document carries
%   is the camelCase one. It is not a quarantine (nothing validates dependency
%   names) and it is not an orphan (references.m walks the document's edges,
%   not the schema's), but the second pass has to FOLLOW this edge to reach the
%   subject, and the schema is currently describing a key no document has.
%   Two of NDI's 37 distinct `*_id` names are camelCase and both are in this
%   family (`ontologyTableRow_id`, `imageCollection_id`), so whether V_eta
%   tombstones spell NDI's edge names verbatim or snake_case them is a
%   one-off convention call, not a typo. Left as declared; raised, not decided.
%
%   THE GUARD. If the block matches neither vintage, this errors rather than
%   emitting anything. Quarantine is visible; a husk is not. In particular a
%   body presenting `region` is REJECTED BY NAME -- that shape can only come
%   from V_delta output or from a fixture built against our own schema instead
%   of the real v1 document, which is the precise mistake being corrected here
%   (and the same mistake that hid the distance_metadata bug).
%
%   ---------------------------------------------------------------------
%   #47, 2026-08-11 -- THE RASTER FOLD, AND WHY IT CANNOT FIRE ON NDI
%   PRODUCTION DOCUMENTS TODAY. READ THIS BEFORE READING IT AS "ngrid IS DONE".
%   ---------------------------------------------------------------------
%   TEAM DECISION (jess, in session, 2026-08-11): "The ngrid documents should be
%   migrated into sampled_bodys. However, the sampled_body needs a corresponding
%   subject_statement. For ontology_image, that's most likely an
%   image_observation." That SUPERSEDES the older sign-off in
%   V_eta_image_model_plan.md, which reads "ngrid is DISSOLVED (deleted, not
%   migrated)"; the direction now confirmed is that document's own R4 section,
%   "`ngrid` -> phases into `sampled_body`".
%
%   Built below as a THIRD arm: subject + raster -> the term_observation this
%   migrator already emitted, PLUS an image_observation whose value is body-
%   backed, PLUS the sampled_body carrying the grid, PLUS the shared anchor.
%   1 -> 4. The mapping itself lives in jNgridBody (shared, so the RF fold can
%   reuse it), and the sampled_body is bound to the image_observation, not to the
%   term_observation: the body IS the picture, and the term says what the picture
%   depicts.
%
%   THE ARM IS KEYED ON THE SUBJECT, NOT ON THE VINTAGE, because "can we name
%   who this is an observation OF" is the only question that decides whether an
%   observation may be minted at all. That is the image_stack guard restated
%   (migrators_j/image_stack.m:248) and it is the lesson of the 4,563
%   subject-less image_observations.
%
%   AND ON REAL DOCUMENTS THAT ARM DOES NOT FIRE. Stated plainly because the
%   opposite is the reassuring reading:
%
%     - The ONLY vintage that exists is B, and B's only edge is
%       `ontologyTableRow_id`. NDI's writer takes no subject at all:
%
%         $ git show origin/main:src/ndi/+ndi/+setup/+NDIMaker/imageDocMaker.m
%           createOntologyImageDoc(obj, image, ontologyNodes, options)
%             options.ontologyTableRow_id {mustBeText} = ''      <- the only edge
%           doc.set_dependency_value('ontologyTableRow_id', ...) <- the only call
%
%     - THE SUBJECT IS NOT REACHABLE THROUGH THAT EDGE EITHER, so a batch pass
%       would not rescue it. An `ontologyTableRow` never carries a subject:
%
%         $ git show origin/main:src/ndi/+ndi/+setup/+NDIMaker/tableDocMaker.m \
%               | grep -n 'set_dependency_value'
%           231:  doc = doc.set_dependency_value('document_id',value);
%
%       one call, and it is `document_id`. +migrators_j/ontology_table_row.m
%       guards on `resolvedSubject(preBody)`, which reads the SOURCE document's
%       `subject_id` dependency -- so those rows take the passthrough arm with no
%       subject to read off. image_stack.m's header records the same finding
%       independently (fact 2).
%
%     - Vintage A, the shape that DOES carry `element_id`, HAS NEVER EXISTED
%       (see the correction at the top of this file) and carries no `ngrid` block
%       even in our own fixture.
%
%   So today every real ontologyImage takes the PASSTHROUGH arm, the ngrid block
%   rides through, and `ontology_image` therefore still needs its `ngrid`
%   superclass. **RETIRING `ngrid` IS NOT UNBLOCKED BY THIS CHANGE.** What is
%   built is the fold and its guard, so that the arm exists, is tested, and is
%   the thing a future subject-minting decision switches on -- not a claim that
%   the fold has happened. The remaining options are the same three the E. coli
%   lawn plates got (mint a subject for what the image is of; resolve it in the
%   NDI second pass; accept the deferral), and they are a team call.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_image') || ~isstruct(preBody.ontology_image)
    error('did2:convert:missingBlock', ...
        'ontology_image body is missing the ontology_image property block.');
end
block = preBody.ontology_image;

isVintageB = hasText(block, 'ontology_nodes') || hasText(block, 'ontology_node');
isVintageA = hasText(block, 'ontology_name') || hasText(block, 'ontology_region');

if isVintageB
    % Deferred to the NDI second pass -- pass the document through intact.
    % Deliberately NOT emitting a term_observation: see the header. Vintage B
    % wins when both are somehow present, because its terms are authoritative.
    v2Body = {preBody};
    return;
end

if ~isVintageA
    if isfield(block, 'region')
        error('did2:convert:ontologyImageVDeltaShape', ...
            ['ontology_image body presents the V_delta output shape ' ...
             '(`region`), which no did_v1 document has. A migrators_j ' ...
             'migrator receives a universalRenames-only body, so it must ' ...
             'read the did_v1 fields (`ontology_name`/`ontology_region`, or ' ...
             '`ontology_nodes`) -- not the V_delta reshape.']);
    end
    error('did2:convert:ontologyImageUnknownShape', ...
        ['ontology_image body matches no known did_v1 vintage: expected ' ...
         '`ontology_name`/`ontology_region` (legacy) or `ontology_nodes` ' ...
         '(current NDI production). Refusing to emit an empty observation.']);
end

% --- vintage A: the term is fully resolvable on this document -----------
node = jGetChar(block, 'ontology_name');
regionName = jGetChar(block, 'ontology_region');

obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
    {}, jOntologyTerm('', 'imaged region'), {'element_id', 'subject_id'});
obs.term = struct('value', jOntologyTerm(node, regionName));

anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

v2Body = {obs, anchor};

% --- the raster, when there IS one and we can say whose it is ------------
% BOTH conditions, and neither is redundant. Without a subject an
% image_observation is an observation about nobody -- the 4,563-document husk.
% Without an `ngrid` block there is no raster to fold, and minting an empty body
% would be the same husk one tier down. See the #47 block in the header for why
% the pair does not occur on any NDI production document today.
subjectId = subjectOf(preBody);
if ~isempty(subjectId) && isfield(preBody, 'ngrid') && isstruct(preBody.ngrid)
    [imgObs, imgBody] = rasterBodies(preBody, subjectId, ...
        jOntologyTerm(node, regionName), anchor.base.id);
    v2Body = {obs, imgObs, imgBody, anchor};
end
end

% ===================== the raster fold =====================================

function [imgObs, imgBody] = rasterBodies(preBody, subjectId, depicted, anchorId)
%RASTERBODIES The image_observation + its sampled_body.
%
%   The observation gets a FRESH id: the source id stays on the term_observation,
%   which is the primary body of this split (the primary/sibling convention
%   jStartInteraction already uses, and the one ontology_table_row.m follows so
%   that an inbound edge lands on exactly one document).
%
%   `variable` is the DEPICTED TERM, not a placeholder. This is the one thing
%   this fold can do that image_stack cannot: image_stack.m:328-331 emits
%   `{node:'', name:'image'}` and defers to a second-pass join because the
%   ontology label lives on another document. Here the term is ON the document
%   being migrated, so there is nothing to defer -- and nothing to invent either,
%   which is why an empty `node` stays empty rather than being filled.
%
%   `storage_mode: 'body'` is what says the pixels are in the sampled_body rather
%   than inline, so `image.value.pixels` is deliberately left empty. The
%   descriptors stay explicit on the composite (R6 decision 4: dtype is NOT
%   recoverable from an inline matrix) -- dtype from the v1 `ngrid.data_type`.
imgObs = jStartInteraction(preBody, 'image_observation', 'subject_observation', ...
    {'image'}, depicted, {'element_id', 'subject_id'}, true);

% ---------------------------------------------------------------------
% THE GUARDED VALUE IS AUTHORITATIVE. TWO READERS WOULD BE TWO DECISIONS.
% ---------------------------------------------------------------------
% jStartInteraction fills `subject_id` by calling jCarrySubject, which RE-READS
% the source edge -- so without this line the subject the caller GUARDED on and
% the subject that reaches the document are produced by two different functions.
% They already disagree, and the disagreement is not hypothetical:
%
%   jCarrySubject.m:20-22      accepts  d.value , d.document_id
%   subjectOf/dependencyValue  accepts  d.value , d.document_id , d.id
%
% A document whose edge value lives only under `.id` therefore PASSES the guard
% ("there is a subject, fold it") and then receives an EMPTY `subject_id` from
% jCarrySubject -- an image_observation about nobody, which validates clean
% because +did2/+validate/references.m:90 skips empty edges. That is the
% 4,563-document husk, rebuilt from a spelling mismatch.
%
% Overwriting with the guarded value collapses it to ONE reading. Deliberately
% NOT fixed by narrowing `dependencyValue` to match jCarrySubject: image_stack.m
% reads all three spellings, so narrowing would make this migrator refuse
% documents its sibling folds -- inventing a failure instead of removing one.
% The slot is located BY NAME, not by index. jStartInteraction happens to put
% `subject_id` first today; an index would silently overwrite whatever moved
% into position 1 if that ever changed.
slot = find(strcmp({imgObs.depends_on.name}, 'subject_id'), 1);
if isempty(slot)
    imgObs.depends_on(end+1) = struct('name', 'subject_id', 'value', char(subjectId));
    slot = numel(imgObs.depends_on);
else
    imgObs.depends_on(slot).value = char(subjectId);
end

% BELT AND BRACES, and cheap. The caller has already guarded, so reaching here
% with an empty subject is a wiring bug rather than a data condition -- and a
% wiring bug that produces a husk is invisible to every gate. Fail loudly at the
% point where the cause is known.
if isempty(imgObs.depends_on(slot).value)
    error('did2:convert:ontologyImageRasterWithoutASubject', ...
        ['ontology_image "%s" reached the raster fold with an empty ' ...
         '`subject_id`. The caller guards on subjectOf() before folding, so ' ...
         'this is a wiring defect, not a document: an image_observation with ' ...
         'an empty required edge validates clean (references.m skips empty ' ...
         'edges) and would be counted as a successful migration.'], ...
        sourceId(preBody));
end

imgObs.subject_statement.storage_mode = 'body';
% storage_mode 'body' means the BODY owns the cadence, so the statement carries
% no sample_time (D1: one home for a body-backed value). jStartInteraction seeds
% a single-point cadence for the inline case, which is the wrong half here.
if isfield(imgObs.subject_interaction, 'sample_time')
    imgObs.subject_interaction = rmfield(imgObs.subject_interaction, 'sample_time');
end
imgObs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchorId);
imgObs.base.name = 'migrated_ontology_image';

% The provenance edge, when the source has one. CONDITIONAL, never blank: a
% declared-but-empty edge is the invented-empty-edge pattern (7,233 documents).
% The slot exists on image_observation for exactly this relationship
% (did-schema 6cf31f2), and `ontology_image` already declared the same edge.
tableRowId = dependencyValue(preBody, 'ontology_table_row_id');
if ~isempty(tableRowId)
    imgObs.depends_on(end+1) = struct('name', 'ontology_table_row_id', ...
        'value', tableRowId);
end

% `color_model` and `channels` are OMITTED, not emitted blank, and the axes live
% on the body rather than here. Three reasons, none of them tidiness:
%   - An ngrid is a bare N-D numeric grid. It has no colour model and no channel
%     list, so a blank `color_model` ontology_term would assert "we looked and
%     found nothing" using the same shape that means "not yet minted" -- a
%     fragment, and a new row on the #70 unminted-term backlog for a fact that
%     does not exist rather than one awaiting a CURIE.
%   - Both sub-fields are mustBeNonEmpty false, so omission validates.
%   - `value.axes` belongs to the BODY when storage_mode is 'body'
%     (V_eta_data_body_model_plan.md: the axis entry mounts on subject_statement
%     for inline pixels, on sampled_body for body-backed), and jNgridBody puts
%     it there. Declaring it twice is the drift T14 exists to prevent.
% `dtype` stays explicit because R6 decision 4 turns on it specifically: a dtype
% is not recoverable from the raster.
imgObs.image = struct();
imgObs.image.value = struct( ...
    'pixels', [], ...
    'dtype', jGetChar(preBody.ngrid, 'data_type'));

imgBody = jNgridBody(preBody, imgObs.base.id, 'migrated_ontology_image_raster');
% The raster bytes move WITH the grid. The file name is NDI's own
% (`ontologyImage.ngrid`): universalRenames.m:308 skips the structural keys
% outright, so file/files arrive verbatim and must be carried verbatim -- the
% image_stack tombstone's `imagestack_file` was exactly this mistake.
if isfield(preBody, 'files'); imgBody.files = preBody.files; end
if isfield(preBody, 'file');  imgBody.file  = preBody.file;  end
end

function v = subjectOf(preBody)
%SUBJECTOF The subject-bearing edge, or '' when there is none.
%
%   `element_id` FIRST and `subject_id` second, matching the order every other
%   call in this file passes to jStartInteraction. `element_id` is a SUBJECT
%   edge, not a dangling non-subject one -- +migrators_j/element.m promotes
%   elements to subjects with their ids PRESERVED. That is a recurring trap in
%   this repo and it is recorded here so a reader does not re-derive it wrongly.
%
%   `ontology_table_row_id` is DELIBERATELY NOT in this list. A table row is not
%   a subject (subject_statement.subject_id declares must_refer_to_document_class
%   'subject'), and the row does not carry one either -- see the #47 block in the
%   header for the writer evidence. Accepting it here would mint observations
%   attributed to a metadata row.
v = '';
for nm = {'element_id', 'subject_id'}
    v = dependencyValue(preBody, nm{1});
    if ~isempty(v)
        return;
    end
end
end

function v = dependencyValue(preBody, name)
%DEPENDENCYVALUE The value of a named edge, '' when absent OR present-and-empty.
%
%   Three spellings are accepted because universalRenames rewrites `id`/`value`
%   to `document_id` on some paths and not others; image_stack.m's reader makes
%   the same allowance, and a copy that missed one would silently drop an edge.
v = '';
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
for k = 1:numel(preBody.depends_on)
    d = preBody.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        elseif isfield(d, 'id') && ~isempty(d.id)
            v = char(d.id);
        end
        return;
    end
end
end

% ===================== local helpers ===================================

function id = sourceId(preBody)
%SOURCEID The document's own id, for a diagnosable message. '<no base.id>' is
%   spelled out rather than left blank so an unidentifiable document reads as
%   unidentifiable instead of as an empty string someone forgot to fill.
id = '<no base.id>';
if isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isfield(preBody.base, 'id') && ~isempty(preBody.base.id)
    id = char(preBody.base.id);
end
end

function tf = hasText(block, name)
%HASTEXT True when the block carries NAME as a non-empty char/string.
tf = false;
if ~isfield(block, name); return; end
v = block.(name);
if ischar(v)
    tf = ~isempty(v);
elseif isstring(v) && isscalar(v)
    tf = strlength(v) > 0;
end
end
