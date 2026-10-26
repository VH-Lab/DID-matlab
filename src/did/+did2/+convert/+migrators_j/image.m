function bodies = image(preBody)
%IMAGE Brainstorm-J migrator: did_v1 `image` -> through image_stack: a
%   body-backed `observation` with value kind `intensity` (a mask: a
%   `calculation` with value kind `logical` or `label`) + a sampled_body
%   (+ the shared session anchor). 1 -> 3.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   THIS MIGRATOR EXISTS TO RESOLVE A NAME COLLISION
%   ---------------------------------------------------------------------
%   did_v1 has a class called `image` -- a stored image file:
%
%       image:        { label, format, compression }
%       depends_on:   subject_id, imageCollection_id
%       files:        imageFile
%       superclasses: base, imageStack_parameters
%
%   V_eta ALSO has a class called `image`, and it is a completely different
%   thing: the standalone raster `data_type` from the R6 image model, whose only
%   field is `value` (the raster cell) and whose parent is `data_type`. The two
%   share NOT ONE FIELD.
%
%   A schema name resolves to exactly one schema. Before this migrator existed
%   there was no `image` entry in +migrators_j, so a did_v1 image document passed
%   through by default and met the V_eta data_type -- a schema describing a
%   different concept -- whose required `value` guaranteed a quarantine.
%
%   Two ways out. RENAMING THE V_eta DATA_TYPE was rejected: R6 chose `image`
%   deliberately (it killed `array` to get there, because a bare N-D numeric grid
%   duplicates sampled_body and names a container), and the name is load-bearing
%   across image_observation, image_manipulation and the tenets. CONSUMING THE v1
%   CLASS is better: once every did_v1 image document migrates, no document can
%   reach that schema under that name, so the collision is gone BY CONSTRUCTION
%   rather than by moving the problem to a new name.
%
%   ---------------------------------------------------------------------
%   "ONCE EVERY did_v1 image DOCUMENT MIGRATES" IS NOT EVERY DOCUMENT.
%   THE SENTENCE ABOVE IS KEPT BECAUSE IT IS THE PREMISE THIS GUARD BREAKS.
%   ---------------------------------------------------------------------
%   STATUS 2026-08-11: written in a container with neither MATLAB nor Octave, so
%   not one line below was executed there. CI is the first run, and the refusal
%   was PROVEN there by mutation, one mutation per run, on throwaway branches.
%   Every other claim is read off NDI `origin/main`, this repo's sources or the
%   did-schema working tree, with the command named inline.
%
%       CONTROL     31518220849  b0fd606  SUCCESS   120 run / 120 passed / 0 FAILED
%       MUTATION A  31518325139  c25c9d9  FAILURE   refusal disabled ->
%           120 run / 118 passed / 2 FAILED
%           testDidV1ImageWithNoSubjectIsRefusedLoudlyBecauseItsNameIsTaken
%           testDidV1ImageWithABlankSubjectEdgeIsRefusedToo
%       MUTATION B  31518348782  a2325ff  FAILURE   refusal UNCONDITIONAL ->
%           120 run / 117 passed / 3 FAILED
%           testFixtureCorpus/testFixturesMigrateCleanUnderValidation
%           testDidV1ImageMigratesSoTheNameCollisionCannotBite
%           testDidV1ImageDoesNotMintADanglingCollectionEdge
%
%   TWO MUTATIONS, NOT ONE, AND IN OPPOSITE DIRECTIONS. A proves the tests see
%   the REFUSAL; B proves they see its CONDITION -- a guard that fires on
%   everything would have passed A's tests perfectly. Two results are worth
%   naming. B reddened `testDidV1ImageDoesNotMintADanglingCollectionEdge` ONLY
%   because its sweep over `out.migrated` now asserts its denominator first; over
%   an empty batch the old loop was vacuously true, so B would have looked
%   half-harmless. And B reddened the FIXTURE CORPUS itself -- `fx_image`
%   (testFixtureCorpus.m:1215) is subject-BEARING, so an over-broad refusal
%   quarantines a document that migrates today. That is the third independent
%   detector, and it is the one that would catch this on real data.
%
%   image_stack HAS AN ARM THAT DOES NOT MIGRATE. `migrators_j/image_stack.m`
%   :248-251 is the subject-less guard -- `if isempty(subjectId); bodies =
%   {preBody}; return; end` -- and this file delegates into it UNCONDITIONALLY,
%   so a did_v1 `image` with no subject is handed straight back wearing the
%   class name `image`. It does not migrate, and it does reach that schema under
%   that name. The collision is therefore NOT gone by construction; it is gone
%   on the fold arm only.
%
%   AND THE ARM IS REACHABLE. NDI's own schema makes the edge optional:
%
%     $ git show origin/main:src/ndi/ndi_common/schema_documents/data/ \
%           image_schema.json
%       "depends_on": [
%         { "name": "subject_id",         "mustbenotempty": 0},
%         { "name": "imageCollection_id", "mustbenotempty": 0} ]
%
%   and the template's own default for both is the empty string
%   (database_documents/data/image.json:13-16). So a subject-less did_v1 `image`
%   is a document NDI is entitled to write, not a malformed one.
%
%   WHY THE image_stack REMEDY IS NOT AVAILABLE HERE. image_stack's passthrough
%   is safe only because `image_stack` came back out of _DELETE_PHASE8 and has a
%   TOMBSTONE to validate against (did-schema schemas/V_eta/deprecated/
%   image_stack.json -- concrete, `subject_id` mustBeNonEmpty false). There is no
%   such tombstone for `image`, and there cannot be one under that name, because
%   R6 spends the name on the raster data_type:
%
%     $ python3 -c "import json; d=json.load(open( \
%         'schemas/V_eta/stable/image.json')); print(d['document_class'] \
%         ['abstract'], [f['name'] for f in d['fields']])"
%       True ['value']
%     $ ls schemas/V_eta/deprecated/ | grep -x image.json   # exit 1, no such file
%
%   So the passthrough meets an ABSTRACT class and dies at
%   +did2/+schema/cache.m:672 with `did2:validation:abstractInstantiation`,
%   "Class "image" is declared abstract" -- a message that names the schema and
%   says nothing about the cause. Worse, that error only fires when validation is
%   ON: with 'Validate', false (which every fast fixture test uses) the body
%   survives as a did2.document named `image` carrying did_v1 fields, counted in
%   `by_class` under a name that in V_eta means something else entirely.
%
%   THE DISPOSITION. The image_stack precedent gives two acceptable outcomes for
%   a subject-less document -- refused loudly, or passed through under a
%   tombstone -- and never a third. Passthrough is unavailable (no tombstone, and
%   the name is taken), so this migrator takes the other one: it REFUSES, at the
%   point where the cause is known, with an identifier of its own so the census
%   groups it apart from real abstract-instantiation mistakes.
%
%   THIS IS NOT THE MODEL DECISION. What a subject-less did_v1 `image` SHOULD
%   become is a team call and is stated, not taken: an `image` with no subject is
%   a raster belonging to nobody, and V_eta has no home for one (`image_observation`
%   and `image_manipulation` both inherit `subject_statement.subject_id`,
%   mustBeNonEmpty TRUE). The options are the same three the E. coli lawn plates
%   got: mint a subject for whatever the image is of, restore a v1-shaped
%   tombstone under a DIFFERENT class name, or accept the refusal. Until then a
%   loud refusal loses exactly as much as the silent one and says why.
%
%   WHAT THE GREEN CORPUS GATE DOES AND DOES NOT SAY. The last full run was
%   green on all six corpora with quarantine 0 (test-code.yml 31464483119). A
%   SUBJECT-LESS did_v1 `image` would have quarantined there, so that green is
%   positive evidence none of the six holds one. It says NOTHING about a
%   subject-bearing one, which folds cleanly and leaves no trace in a quarantine
%   count -- do not read the gate as "no v1 image documents exist". And THE
%   CORPORA ARE A SAMPLE OF DATASETS, NOT THE UNIVERSE. No in-tree NDI writer
%   constructs this class at all:
%
%     $ git grep -n -E "['\"]image['\"]" origin/main -- '*.m' | wc -l
%       12          # DENOMINATOR: 1002 .m files on origin/main
%                   # all 12 are daq CHANNEL-TYPE mentions ('analogin',
%                   # 'digitalin', 'image', 'timestamp'); zero are a document
%                   # construction. No doc_document_types entry names it either.
%
%   which is exactly the condition under which a class arrives from a dataset
%   nobody has migrated yet.
%
%   ---------------------------------------------------------------------
%   WHY THIS DELEGATES TO image_stack
%   ---------------------------------------------------------------------
%   did_v1 `image` is the single-image SIBLING of `image_stack`: same
%   `imageStack_parameters` superclass (so the same geometry block after
%   universalRenames), same file-backed pixels, plus a direct `subject_id`.
%   migrators_j.image_stack already folds exactly that shape into
%   image_observation + sampled_body + anchor with the source id PRESERVED, and
%   it reads only the parameters block, the dependencies, base and files -- never
%   its own `image_stack` property block. So it applies to this class verbatim,
%   and duplicating ~200 lines to say the same thing would be two places to keep
%   right instead of one.
%
%   ---------------------------------------------------------------------
%   WHAT IS DEFERRED, STATED RATHER THAN DROPPED
%   ---------------------------------------------------------------------
%   `format` + `compression` -- the FILE encoding of the carried bytes (e.g.
%   'tiff', 'lzw'). PLACED since 2026-10-26 on the body's `format` and
%   `compression` ([image file details placed], Jess Haley, 2026-10-26), by
%   image_stack, which reads this class's `image` block for them. (This read
%   "sampled_body has no encoding field"; data_body declares both.)
%
%   `imageCollection_id` -- becomes a `member_of` relation to a group entity
%   (T20) under [image file details placed]; that is a later step, so until it
%   lands an image that names a collection is CARRIED WHOLE AS V1 by
%   image_stack (it was deliberately not carried: `imageCollection` has no
%   V_eta class, so the edge would dangle).
%
%   `label` (this class's `image.label`) has no home decided yet: an image
%   that states one is CARRIED WHOLE AS V1 (2026-10-26). It used to be dropped
%   for the reason image_stack documents: it is a templated
%   prose definition of the image TYPE, reconstructable as a projection of the
%   ontology term, not a per-document fact.

arguments
    preBody (1,1) struct
end

% The fold is identical; see the header for why. image_stack reads only the
% shared `image_stack_parameters` block, the dependencies, base and files, all of
% which a did_v1 `image` body carries.
% `image.label` has no V2 home decided yet (image_stack reads its own block's
% label, not this one), so an image that states one is carried whole as v1
% ([generic stage is lossless], Jess Haley, 2026-10-25) instead of losing it.
if isfield(preBody, 'image') && isstruct(preBody.image) && isfield(preBody.image, 'label') ...
        && ~isempty(strtrim(char(string(preBody.image.label))))
    % carry-register: carry-051
    did2.convert.reportNote('carried_as_v1', 'image', sourceId(preBody), ...
        '[carry-051] unplaced: image.label');
    bodies = {preBody};
    return;
end
bodies = did2.convert.migrators_j.image_stack(preBody);
% did-schema #88 restated `image` as the did_v1 tombstone (deprecated/image,
% #73 review item 51), so a document image_stack hands back unchanged now
% validates under its own name: the name-collision refusal that stood here is
% no longer needed (the ledger's own words) and is removed.
end

function tf = tookThePassthroughArm(preBody, bodies)
%TOOKTHEPASSTHROUGHARM True when image_stack returned the body unchanged.
%
%   DETECTED FROM THE RETURN SHAPE, NOT BY RE-READING `subject_id`, and that is
%   deliberate. A second reading of the edge here would be a second
%   IMPLEMENTATION of the same decision: image_stack's `dependencyValue` accepts
%   three spellings of an edge value (`.value`, `.document_id`, `.id`), so a copy
%   that missed one would refuse a document image_stack would have folded --
%   inventing a failure instead of reporting one. Asking what image_stack
%   actually DID cannot diverge from what image_stack did.
%
%   The fold arm returns three bodies (observation + sampled_body + anchor) and
%   none of them keeps the source class name; the guard arm returns `{preBody}`
%   verbatim. Both halves are checked rather than just the count, so a future
%   single-body fold is not mistaken for a passthrough.
tf = false;
if numel(bodies) ~= 1
    return;
end
srcName = classNameOf(preBody);
if isempty(srcName)
    return;
end
tf = strcmp(classNameOf(bodies{1}), srcName);
end

function nm = classNameOf(b)
nm = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    nm = char(b.document_class.class_name);
end
end

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
