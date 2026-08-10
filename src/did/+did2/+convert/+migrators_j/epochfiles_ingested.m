function bodies = epochfiles_ingested(preBody)
%EPOCHFILES_INGESTED Brainstorm-J migrator: DELIBERATE GUARDED PASSTHROUGH.
%
%   The signed model (#60, V_eta_epoch_plan.md, TEAM-SIGN-OFF [epoch] 2026-08-08)
%   renames this class to `ingestion_manifest`:
%
%       ingestion_manifest  <- base
%          files  string[]
%          depends_on
%             filenavigator_id -> filenavigator   REQUIRED (restored; NDI writes it)
%             epoch_id         -> epoch           REQUIRED (replaces the invented
%                                                  `epochid` edge, empty on 6,921 docs)
%          epochprobemap  REMOVED -- decomposes into edges (option B)
%
%   THIS MIGRATOR DOES NOT PERFORM THAT FOLD, and the refusal is the point of the
%   file. Pass 1 cannot emit an `ingestion_manifest` without breaking one of the
%   two rules this project has paid for twice. Both blockers are measured below,
%   not argued.
%
%   ---------------------------------------------------------------------------
%   BLOCKER 1 -- `epoch_id` HAS NOTHING TO POINT AT IN PASS ONE
%   ---------------------------------------------------------------------------
%   `ingestion_manifest.epoch_id` is REQUIRED and must refer to an `epoch`
%   document. No `epoch` document exists in did_v1: an epoch is only a shared
%   STRING, which is exactly why every v1 epoch join is a string match. The
%   `epoch` entities are MINTED, one per epoch, and that is a grouping over the
%   whole corpus -- a single-document migrator cannot see it. It is the NDI
%   second pass (ndi.migrate.local, alongside ndi.migrate.internal.pathSPromotion).
%
%   Emitting the class anyway, with the edge left '', is THE INVENTED-EMPTY-EDGE
%   PATTERN -- the one this class is the poster child for. V_eta used to declare
%   `epochid -> acquisition_epoch` REQUIRED on it and drop `filenavigator_id`;
%   the edge was empty on 6,921 of 6,921 documents (Dab 4,088 / B 2,484 /
%   Soph 349) and every one of them validated clean, because
%   +did2/+validate/references.m:90 skips empty edges. Re-creating that under a
%   new class name would be the same defect wearing the repair's name.
%
%   THE GROUPING KEY IS NOT THE ID STRING. Measured on corpus B (2,484
%   epochfiles_ingested documents of 12,917 read, 0 unreadable):
%
%       distinct epoch_id strings         149
%       distinct (base.session_id, epoch_id)  1,242
%
%   i.e. grouping on the string alone FUSES 1,242 real epochs into 149 -- an 8.3x
%   collapse. did2.validate.sourceCensus independently reports 142 of B's 149 ids
%   as spanning more than one session (CI run 31415147934 / 02854c7); the same
%   check reports 142 for Dab and 12 for Soph. These are vhlab-style ids (`t00070`)
%   which restart at t00001 in every session directory. The plan's recorded hazard
%   was the SYNTHETIC `whole_session_` id (ndi.element.oneepoch.m:42); that one
%   measures ZERO in all six corpora, and this one -- larger, and certain -- was
%   not on the list. Any mint MUST key on (session, id).
%
%   AND THE SESSION EDGE NEEDS A LOOKUP TOO. `epoch.session_id` is REQUIRED and
%   must refer to a `session` DOCUMENT, whose `base.id` is a fresh uid
%   (ndi.document.m:58, `document_properties.base.id = ndiido.id()`) and is NOT
%   the session identifier every other document carries in `base.session_id`.
%   Measured: in corpus B, base.id == base.session_id in 0 of 14 session
%   documents. So `base.session_id -> the session document's base.id` is itself a
%   whole-corpus join. (The referent does exist: all 13 session ids appearing on
%   B's epochfiles_ingested documents have a session document in the batch, and
%   sourceCensus reports session_doc_count == distinct base.session_id in all six
%   corpora -- 1/1, 14/14, 16/16, 3/3, 1/1, 33/33.)
%
%   ---------------------------------------------------------------------------
%   BLOCKER 2 -- THE FOLD WOULD DESTROY `epochprobemap`, WITH NOWHERE TO PUT IT
%   ---------------------------------------------------------------------------
%   `ingestion_manifest` declares no `epochprobemap` field (build_v_eta.py drops
%   it), because under option B each row becomes real edges. But option B is
%   blocked on the raw-recording observation model (#30), which is UNSIGNED, and
%   the plan's own decision for now is *"B as the model, A as pass-1 behaviour"* --
%   A being *"keep as infra, repaired ... keep the probemap as text"*.
%
%   The probemap is not a manifest detail. It deserialises to
%   (name, reference, type, devicestring, subjectstring) -- how the archive knows
%   whose neurons a recording belongs to, per epoch. A real corpus-B row:
%
%       name  reference  type     devicestring       subjectstring
%       tet   7          n-trode  vhspike2:ai11-14   ts0820@fitzpatrick_duke
%
%   Measured: non-empty on 2,484 of 2,484 corpus-B documents. Folding today is
%   loss with no destination, which is what the source tombstone's own field
%   documentation forbids in as many words.
%
%   SO THE SCHEMA HALF AND THE PASS-1 DECISION CURRENTLY DISAGREE: the class was
%   built in B's shape while the decision says pass 1 behaves as A. That needs a
%   human call (keep `epochprobemap` on `ingestion_manifest` until #30 lands, or
%   hold the fold) -- it is not a build choice, so nothing here makes it.
%
%   ---------------------------------------------------------------------------
%   WHAT PASSING THROUGH COSTS: NOTHING. IT IS ALREADY THE MEASURED BEHAVIOUR.
%   ---------------------------------------------------------------------------
%   There was no migrator for this class before this file, so these documents
%   already fell through to the identity path and validated against the restored
%   `epochfiles_ingested` source tombstone. Corpus run 31415147934 (02854c7):
%   quarantine 0 on all six corpora, with 2,484 (B) / 4,088 (Dab) / 349 (Soph)
%   counted as `unconverted`. This file changes NO behaviour. It exists to make
%   the deferral legible at the place someone will look, and to hold the shape
%   guard below, so the next person does not "finish" #60 by emitting the class
%   with an empty edge.
%
%   `filenavigator_id` needs no restoring here: NDI writes it
%   (+ndi/+file/navigator.m:707, set_dependency_value('filenavigator_id', ...)),
%   universalRenames carries it to {name, document_id}, and it is non-empty on
%   2,484 of 2,484 corpus-B documents. It survives untouched by passing through.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   See also: did2.convert.migrators_j.fitcurve (the guarded-passthrough shape),
%   did2.convert.migrators_j.ontology_label (the V_alpha shape assertion),
%   ndi.migrate.internal.pathSPromotion (the second-pass harness a mint belongs in).

arguments
    preBody (1,1) struct
end

% ---------------------------------------------------------------------------
% SHAPE ASSERTION -- a body that could only come from the V_alpha snapshot.
% ---------------------------------------------------------------------------
% NDI origin/main declares exactly one dependency on this class,
% `filenavigator_id` (ndi_common/database_documents/ingestion/
% epochfiles_ingested.json + its schema, `"mustbenotempty": 1`). The `epochid`
% edge was DID-side only. Measured across corpus B: the dependency name set is
% `{filenavigator_id}` on 2,484 of 2,484 documents and the block key set is
% `{epoch_id, epochprobemap, files}` on 2,484 of 2,484 -- so this cannot fire on
% a real document, and if it does fire the fixture is built from our own schema
% rather than from the writer. Same stance as ontology_label.
%
% ONLY `epochid` IS REJECTED, DELIBERATELY -- NOT `epoch_id`. They are opposites:
% `epochid` is the V_alpha invention that was empty on every document that ever
% carried it, while `epoch_id` is the edge the second pass will legitimately
% stamp once `epoch` documents exist. The sibling helper
% +migrators_j/private/jEpochDocId.m already reads `epoch_id` tolerantly for
% exactly that future, so erroring on it here would make this migrator the one
% thing that breaks on the day #60 lands.
if hasDependency(preBody, 'epochid')
    error('did2:convert:epochfilesIngestedInventedEdge', ...
        ['epochfiles_ingested body carries an `epochid` dependency. ' ...
         'No did_v1 document has one -- NDI declares only `filenavigator_id` ' ...
         '(+ndi/+file/navigator.m:707). This edge is the V_eta invention that ' ...
         'was empty on 6,921 of 6,921 corpus documents, so a body carrying it ' ...
         'came from the V_alpha snapshot or a fixture built against it.']);
end

% Deliberate passthrough. `bodies = {preBody}` is how a migrator says
% "nothing to do here"; v1_to_v2 counts it in `unconverted_by_class`, which is
% where this deferral should be visible.
bodies = {preBody};
end

% ===================== small helpers =======================================

function tf = hasDependency(bodyStruct, name)
%HASDEPENDENCY True when a depends_on entry with NAME is present (empty or not).
%   Reads the entry NAME only, so it is indifferent to whether the value is
%   spelled `value` (a raw v1 body, or one a migrator built) or `document_id`
%   (post-universalRenames). Tolerant of the scalar-struct depends_on real v1
%   bodies carry when they declare exactly one edge, and of a cell, which
%   jsondecode produces whenever entries do not all carry the same keys.
tf = false;
if ~isfield(bodyStruct, 'depends_on'); return; end
deps = bodyStruct.depends_on;
if isstruct(deps)
    for k = 1:numel(deps)
        if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
            tf = true; return;
        end
    end
elseif iscell(deps)
    for k = 1:numel(deps)
        d = deps{k};
        if isstruct(d) && isscalar(d) && isfield(d, 'name') ...
                && strcmp(char(d.name), name)
            tf = true; return;
        end
    end
end
end
