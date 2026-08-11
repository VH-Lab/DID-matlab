function bodies = image(preBody)
%IMAGE Brainstorm-J migrator: did_v1 `image` -> a body-backed image_observation
%   + a sampled_body (+ the shared session anchor). 1 -> 3.
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
%   not one line below has been executed here. CI is the first run. Every claim
%   is read off NDI `origin/main`, this repo's sources or the did-schema working
%   tree, and the command that produced it is named inline.
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
%   NOTHING IN THE SIX CORPORA EXERCISES THIS. No corpus report has ever carried
%   an `image` row, and the last full run was green on all six
%   (test-code.yml 31464483119) -- which, since a subject-less one would
%   quarantine, is positive evidence that none of the six holds one. THE CORPORA
%   ARE A SAMPLE OF DATASETS, NOT THE UNIVERSE, and no in-tree NDI writer
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
%   'tiff', 'lzw'). These have no home yet: `sampled_body` has no encoding field,
%   and adding one is a data_body model change (the 2.D collapse decided every
%   format carrier phases into sampled_body/opaque_body with "encoding becomes a
%   field", but that field has not been built). Carried bytes remain readable --
%   a container format is recoverable from the file itself -- so this is a
%   deferral, not a loss. It should land with the data_body encoding field.
%
%   `imageCollection_id` -- DELIBERATELY NOT CARRIED, and this one is worth
%   knowing. `imageCollection` has NO V_eta class and NO migrator; the coverage
%   ledger grades it "dissolved (rename/decompose)", which is not what the code
%   does. Carrying the edge would therefore mint a reference to a document that
%   does not exist after migration -- a dangling edge, which is a GATING orphan
%   failure, not a cosmetic one (dissolving referenced documents without
%   preserving ids once cost 11,448 orphans). The grouping is a real fact and
%   wants the second pass, once imageCollection has a home. Emitting it now would
%   trade a silent gap for a red gate and record nothing true either way.
%
%   `label` is dropped for the reason image_stack documents: it is a templated
%   prose definition of the image TYPE, reconstructable as a projection of the
%   ontology term, not a per-document fact.

arguments
    preBody (1,1) struct
end

% The fold is identical; see the header for why. image_stack reads only the
% shared `image_stack_parameters` block, the dependencies, base and files, all of
% which a did_v1 `image` body carries.
bodies = did2.convert.migrators_j.image_stack(preBody);

% ---------------------------------------------------------------------
% THE REFUSAL: NO SUBJECT => NO OBSERVATION, AND NO PASSTHROUGH EITHER.
% ---------------------------------------------------------------------
% See the header. image_stack's subject-less guard hands the body back
% unchanged; for `image_stack` that lands on a tombstone, for `image` it lands
% on R6's abstract raster data_type. Refuse here, where the cause is known,
% rather than let the validator report a class name.
if tookThePassthroughArm(preBody, bodies)
    error('did2:convert:imageNoSubjectHasNoTombstone', ...
        ['did_v1 `image` document "%s" carries no `subject_id`, so ' ...
         'migrators_j.image_stack took its subject-less guard arm and handed ' ...
         'the document back unchanged. For `image_stack` that is safe -- it ' ...
         'has a tombstone in V_eta `deprecated/`. For `image` it is NOT: the ' ...
         'name belongs to R6''s raster `data_type`, which is ABSTRACT and ' ...
         'requires `value`, and no `deprecated/image.json` exists, so the ' ...
         'passthrough would quarantine as `did2:validation:abstractInstantiation` ' ...
         '-- an error naming the schema instead of the cause -- or, with ' ...
         'validation off, survive silently under a class name that means ' ...
         'something else in V_eta. NDI permits this document ' ...
         '(image_schema.json declares `subject_id` mustbenotempty 0), so it is ' ...
         'the MODEL that has no home for it, not the document that is ' ...
         'malformed. What a subject-less v1 `image` becomes is a team call: ' ...
         'mint a subject for what the image is of, restore a v1-shaped ' ...
         'tombstone under a DIFFERENT class name, or accept this refusal.'], ...
        sourceId(preBody));
end
end

% ===================== local helpers =======================================

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
