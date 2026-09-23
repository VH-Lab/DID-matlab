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
%   file. Pass 1 cannot emit an `ingestion_manifest` without breaking a rule this
%   project has paid for twice. Two blockers are measured below, not argued.
%
%   ONE OF THE TWO HAS SINCE FALLEN, AND IT IS SAID HERE RATHER THAN ONLY IN ITS
%   OWN SECTION, so the summary a reader stops at does not overstate the wall.
%   BLOCKER 1 (nothing for `epoch_id` to point at) was DISMANTLED 2026-08-10 by
%   `did2.convert.epochMint`; BLOCKER 2 (`epochprobemap` has no home on
%   `ingestion_manifest`) STANDS and is now the whole of what stops the fold. It
%   is not a build choice: it is the one TEAM question this file carries, stated
%   at the end of BLOCKER 2.
%
%   AND THE FOLD DOES NOT BELONG IN THIS FILE EVEN AFTER IT UNBLOCKS. The mint
%   is a grouping over the whole corpus, so the emitter must be a BATCH POST-PASS
%   ordered after `epochMint`, the way `foldGenericFiles` and
%   `resolveResponseParameters` are. A reader looking for
%   `+migrators_j/ingestion_manifest.m` on the day it lands will not find one,
%   and that will be the design rather than an omission.
%
%   ---------------------------------------------------------------------------
%   BLOCKER 1 -- DISMANTLED 2026-08-10, AND THIS FILE SAID OTHERWISE UNTIL
%                2026-08-12. IT IS NO LONGER A REASON NOT TO FOLD.
%   ---------------------------------------------------------------------------
%   THE PARAGRAPH BELOW IS CORRECTED RATHER THAN DELETED, because its last
%   sentence is the dangerous half: it sends the reader to build the mint in
%   the WRONG REPOSITORY. It read, verbatim:
%
%     "The `epoch` entities are MINTED, one per epoch, and that is a grouping
%      over the whole corpus -- a single-document migrator cannot see it. It is
%      the NDI second pass (ndi.migrate.local, alongside
%      ndi.migrate.internal.pathSPromotion)."
%
%   The first sentence is still exactly right and is why this is not a migrator
%   job. The second is wrong: the mint landed DID-SIDE, as
%   `did2.convert.epochMint`, a batch post-pass in this very package. The dates
%   say why this file never heard about it -- the mint did not exist when this
%   file was written and arrived 45 minutes later:
%
%     $ git log -1 --format="%h %ai" -- <this file>
%     981ce04 2026-08-10 20:46:31 +0000
%     $ git log --format="%h %ai" --diff-filter=A -- \
%           src/did/+did2/+convert/epochMint.m
%     27af359 2026-08-10 21:31:35 +0000
%     $ git cat-file -e 981ce04:src/did/+did2/+convert/epochMint.m
%     fatal: path '...' exists on disk, but not in '981ce04'
%
%   AND THIS CLASS IS ONE OF THE MINT'S KEY SOURCES, not a bystander. Its epoch
%   id is a plain char field in its OWN block rather than an `epochid` mixin, so
%   did2.validate.sourceCensus's reader does not see it -- but
%   did2.validate.epochStrings does, by name:
%
%     src/did/+did2/+validate/epochStrings.m:146-151
%       if isfield(body, 'epochfiles_ingested') && ...
%           v = charField(body.epochfiles_ingested, {'epoch_id', ...});
%           hits(end+1) = struct('source', 'epochfiles_ingested', 'value', v);
%
%   and that is asserted executably, not merely written:
%   +unittest/testEpochMint.m:409 `testTheIngestedManifestIsAKeySource`.
%
%   SO AN `epoch` DOCUMENT EXISTS FOR THESE DOCUMENTS AFTER THE MINT, and the
%   right home for the fold is a BATCH POST-PASS ORDERED AFTER `epochMint` --
%   not this file, and not the NDI second pass. `epochMint` says the same from
%   its side ("Its epoch id IS read as a mint key, so the epochs exist for the
%   fold the day it can be done losslessly"). What still stops it is BLOCKER 2
%   alone, and one build note that belongs with it: `ingestion_manifest.epoch_id`
%   is REQUIRED, the mint legitimately REFUSES some pairs (no session document,
%   ambiguous session, synthetic id -- each counted), and
%   strictMode('RequiredDependencies') is ARMED, so a fold must pass those
%   documents through rather than emit the class with the edge unfilled.
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
%                AND SINCE BLOCKER 1 FELL, THIS IS THE ONLY ONE LEFT.
%   ---------------------------------------------------------------------------
%   `ingestion_manifest` declares no `epochprobemap` field (build_v_eta.py drops
%   it), because under option B each row becomes real edges. The plan's own
%   decision is *"B as the model, A as pass-1 behaviour"* -- A being *"keep as
%   infra, repaired ... keep the probemap as text"*.
%
%   RE-CHECKED 2026-08-12, BOTH SIDES, because one clause of the sentence above
%   used to read "option B is blocked on the raw-recording observation model
%   (#30), which is UNSIGNED" and that clause is STALE. #30 IS SIGNED:
%   HISTORICAL-BUILD-CLAIM -- the quoted "which is UNSIGNED" above is history.
%
%     $ grep -c TEAM-SIGN-OFF DID-schema/schemas/V_eta_recording_observation_plan.md
%     1                       (the line is at :99, dated 2026-08-10)
%     2  <- RE-DERIVED 2026-08-15. A SECOND signature landed on 2026-08-13 (the
%           pyraview clause: "`pyraview` ENDS AS a `voltage_observation` + one
%           `sampled_body` PER STORED RESOLUTION LEVEL + a `frequency_filter`,
%           and that is the end state"). The `1` is kept as the 2026-08-12
%           reading rather than overwritten -- a dated measurement is a
%           measurement -- but do not quote it as current. The CONCLUSION is
%           unaffected and is now doubly supported.
%
%   THE BLOCKER SURVIVES THE CORRECTION, AND THE CORRECTION MATTERS ANYWAY --
%   a reader who checked that clause would find it false and could read the
%   whole blocker as lapsed. It has not lapsed, for two measured reasons.
%
%   (a) THE SIGNED #30 BUILD DOES NOT CONSUME THE PROBEMAP. Its assembler is
%   +migrators_j/private/jRecordingObservation.m, and the one place it mentions
%   the probemap is a note explaining why a channel axis carries no LENGTH
%   (:53, "the device string lives in the epochprobemap ... The count is a
%   second-pass fill"). Reading it is deferred; decomposing it is not started.
%
%   (b) NOTHING ANYWHERE DECOMPOSES IT, and the query is proven able to match:
%
%     DENOMINATOR: 1002 .m file(s) on NDI-matlab origin/main; 369 .m file(s)
%                  under DID-matlab src/ + tests/
%       NDI .m naming `epochprobemap`                        : 67   <- can match
%       NDI .m naming `epochprobemap` under +ndi/+migrate/   :  0
%       NDI .m naming `ingestion_manifest`                   :  0
%       DID-matlab .m EMITTING an `ingestion_manifest` body  :  0
%         (7 files name the class: epochMint, epochIndex, silentLoss, this
%          file, and three tests -- every one of them describing or counting
%          it, none constructing one)
%
%   So option B has no emitter on either side of the boundary, and the signed
%   decision routes the decomposition to the SECOND PASS while pass 1 behaves
%   as A. Folding here or in a batch pass today drops the probemap.
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
%   [The clause "until #30 lands" is superseded: #30 is signed and its build
%    does not touch the probemap. The call itself is unchanged and is restated
%    immediately below.]
%
%   THE SAME DISAGREEMENT, RESTATED AS THE ONE OPEN QUESTION (2026-08-12), so
%   the next reader is not left to re-derive which half of a signature to
%   follow. TEAM-SIGN-OFF [epoch] in V_eta_epoch_plan.md -- cited by grep
%   pattern, not by line, because that file is under active edit -- carries BOTH
%   *"epochfiles_ingested becomes `ingestion_manifest` with filenavigator_id
%   RESTORED"* and, in the section it signs, *"B as the model, A as pass-1
%   behaviour"*. Those two cannot both hold at pass-1 time, because
%   `ingestion_manifest` has nowhere to put the probemap -- not on itself and
%   not on `base`:
%
%     DENOMINATOR: 247 JSON file(s) under DID-schema schemas/V_eta
%       ingestion_manifest  fields ['files']
%                           deps   filenavigator_id (required),
%                                  epoch_id -> epoch (required)
%       base                fields ['id','session_id','name','datestamp']
%       schemas naming `epochprobemap`: 4 -- epochfiles_ingested, filenavigator,
%                           epoch_file_pattern, syncrule_mapping. NOT
%                           ingestion_manifest.
%
%   THE THREE WAYS OUT ARE ALL TEAM CALLS, NOT BUILDS, and are listed only so
%   the question is answerable rather than re-opened: give
%   `ingestion_manifest` a home for the probemap (which contradicts the plan's
%   own *"epochprobemap REMOVED"*); build the second-pass decomposition first
%   and fold behind it; or accept the drop. Operating Rule 4 -- nothing here
%   chooses, and a future reader must not read this list as a menu it may pick
%   from unilaterally.
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
%   did2.convert.epochMint (the mint -- DID-side, and the pass a fold would be
%   ordered after; this line named ndi.migrate.internal.pathSPromotion until
%   2026-08-12, which is the corpus-wide find-or-create the mint is MODELLED on,
%   not where it lives), did2.validate.epochStrings (which reads this class's
%   `epoch_id` as a mint key).

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
