function v2Body = ontology_image(preBody)
%ONTOLOGY_IMAGE Brainstorm-J migrator: did_v1 ontology_image.
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
end

% ===================== local helpers ===================================

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
