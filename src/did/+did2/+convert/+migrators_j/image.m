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
end
