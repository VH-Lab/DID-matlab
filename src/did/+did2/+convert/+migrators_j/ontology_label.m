function bodies = ontology_label(preBody)
%ONTOLOGY_LABEL Brainstorm-J migrator: did_v1 ontology_label -- DEFERRED to the
%   NDI second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   STATUS: this file's BEHAVIOUR is unchanged by the 2026-08-11 re-derivation
%   below -- only the header and the tests changed. Nothing in this repository
%   was EXECUTED for that pass: there is no MATLAB and no Octave in the
%   environment it was written in (`which matlab octave octave-cli` printed
%   nothing). CI is the gate.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION: THE LABEL WAS FINE, THE REFERENT WAS LOST
%   ---------------------------------------------------------------------
%   This class was previously assessed BENIGN because the migrator reads the right
%   property field. It does. THE DEPENDENCY IS THE BUG, and it was never checked.
%   The real NDI class (ndi_common/database_documents/data/ontologyLabel.json) is:
%
%       ontologyLabel: { ontologyNode }      -> ontology_label.ontology_node
%       depends_on:    document_id           <- mustbenotempty: 1
%
%   ONE property field, ONE dependency. The migrator asked for
%   {'element_id','subject_id','probe_id'} -- none of which the class has -- and
%   jStartInteraction ASSIGNS `body.depends_on = jCarrySubject(...)` rather than
%   extending it. So on every real document:
%
%       subject_id  came out EMPTY   (declared mustBeNonEmpty, enforced nowhere)
%       document_id was DISCARDED    (the only link to the labelled thing)
%
%   The term survived; what the term was about did not. That is roughly 7,000
%   documents asserting a label about nobody, and it validated cleanly at every
%   gate -- `did2.validate.silentLoss` was written to make exactly this visible.
%
%   The two extra property fields the migrator also reads -- `ontology_name` and
%   `label_id`, with `label` -- do not exist either. They came from the false
%   provenance line in the V_delta conversion doc, which has since been corrected.
%
%   WHY THIS CANNOT BE FIXED BY RENAMING THE EDGE. `document_id` points at the
%   document being labelled, which is NOT a subject -- typically an image stack.
%   Renaming it to subject_id would assert that an image stack is a subject. The
%   subject is one hop further on, through the migrated-id graph:
%
%       ontology_label --document_id--> imageStack --migrates-->
%           image_observation --subject_id--> subject
%
%   DECIDED TARGET for the second pass (which can see that graph): emit a
%   term_observation about the resolved subject, with `derived_from` pointing at
%   the migrated data statement. That keeps BOTH facts -- the term, and what it
%   was about -- and asserts nothing false. Until then the document is carried
%   through intact, so nothing is lost and no false claim is minted.
%
%   THE SECOND PASS IS NOW BUILT: ndi.migrate.internal.ontologyLabelSubjects,
%   registered in ndi.migrate.local's V_eta branch (step 1c). THIS FILE DOES NOT
%   CHANGE, and that is the design: the passthrough is what makes the label
%   available to a pass that can see the graph, and it stays correct for every
%   label the graph cannot attribute.
%
%   IT ONLY RESOLVES HALF, AND THE OTHER HALF IS THE SOURCE'S DOING, NOT OURS:
%
%     git show origin/main:src/ndi/+ndi/+setup/+conv/+haley/doImport.m
%       BEHAVIOUR  :430 :464 :480 :499  set_dependency_value('document_id', ...)
%                  :432 :466 :482 :501  set_dependency_value('subject_id', subjectGroup_id)
%       E. COLI    :794 :814 :830       set_dependency_value('document_id', ...)
%                                       -- and NO subject_id line at all
%
%   The E. coli images are bacterial patches on plates; that session has no
%   subject, so those labels resolve to a referent with nothing to inherit. The
%   second pass COUNTS them (`blocked_target_has_no_subject`, split by referent
%   class) and leaves them passing through. Whether such a document ever gets a
%   subject is a TEAM MODELLING CALL, deliberately not made.
%
%   V_eta's tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py.
%
%   ---------------------------------------------------------------------
%   RE-DERIVED 2026-08-11: THE `document_id` EDGE IS CARRIED, AND THE WRITER
%   CENSUS IS BIGGER THAN THIS HEADER SAID
%   ---------------------------------------------------------------------
%   The recorded loss ("discards the `document_id` edge ... and emits an empty
%   `subject_id`") was REAL and is now FIXED -- by THIS FILE becoming a
%   passthrough, not by a guard on an edge. Both halves died in the same commit:
%
%     git log --oneline --follow -- .../+migrators_j/ontology_label.m
%       3d67017 WIP: ontology_label DID-side half + silentLoss counter
%       5d22f22 migrators_j: defer the seven fabricating migrators as guarded
%               passthroughs                                      <- THE FIX
%       a81b275 Emit term/date values on the composite block
%       14f5c6f Add flat-table-free J migrators: ... ontology_label
%
%     git show a81b275:.../ontology_label.m   (the pre-fix body)
%       :48  obs = jStartInteraction(preBody, 'term_observation', ...
%       :49      {'element_id', 'subject_id', 'probe_id'});
%     .../+migrators_j/private/jStartInteraction.m:38
%       body.depends_on = jCarrySubject(preBody, subjectSrc);   % ASSIGN, not extend
%     .../+migrators_j/private/jCarrySubject.m (last line)
%       deps = struct('name', 'subject_id', 'value', subjectVal);
%
%   None of {element_id, subject_id, probe_id} exists on this class, so
%   subjectVal came out '' and the assignment REPLACED the one real edge. Today
%   the function returns `{preBody}` and nothing touches `depends_on` at all.
%
%   THE EDGE ALSO SURVIVES THE PIPELINE, not just this function. universalRenames
%   is the only step that rewrites `depends_on`, and it rewrites the VALUE key
%   while preserving the NAME:
%
%     universalRenames.m:307-308
%       % (document_class, depends_on, file, files) are skipped.
%       skip = {'document_class', 'depends_on', 'file', 'files'};
%     universalRenames.m:369+  renameDependsOnEntries  -- id/value -> document_id,
%       `name` untouched. So a v1 {name:'document_id', value:X} arrives here as
%       {name:'document_id', document_id:X} and leaves unchanged.
%
%   THE WRITER CENSUS. Bare class name, every extension, no assumed call shape
%   (`git grep -c -i ontologylabel origin/main -- '*'` in NDI-matlab):
%
%     DENOMINATOR: 6 files match on origin/main; 3 are .m; 10 construction sites.
%
%       +setup/+conv/+haley/doImport.m   7 sites  445 470 486 505 | 799 816 832
%       +setup/+conv/+babu/import.m      3 sites  487 534 583
%       +setup/+NDIMaker/stimulusDocMaker.m  0 sites -- FALSE POSITIVE. `:382`
%           `[ontologyNode,ontologyLabel,...] = ndi.ontology.lookup(...)` is a
%           LOCAL VARIABLE. No ndi.document('ontologyLabel') anywhere in it.
%
%     10 of 10 sites call set_dependency_value('document_id', ...). ZERO set any
%     other dependency. The template's one edge is the one the writers write.
%
%     REFERENT CLASS, per site:
%       imageStack    8   haley all 7; babu :487
%       generic_file  2   babu :534 (plasmid), :583 (LC-MS)
%
%   `+setup/+conv/+babu/import.m` WAS NOT NAMED IN THIS HEADER BEFORE, and its
%   two `generic_file` referents are a case the second pass's imageStack chain
%   does not cover.
%
%   THE NEXT SENTENCE USED TO READ: "`generic_file` has NO V_eta home and NO
%   migrator (it is one of the 4 UNVERIFIED coverage rows)". BOTH HALVES ARE NOW
%   STALE, and the second half was misleading even when it was written.
%   `generic_file` HAS a V_eta home: it folds to a `term_observation` +
%   `opaque_body`, signed 2026-08-11, and the fold ran in 6 of 6 corpora in
%   corpus run 31522068566. It has no MIGRATOR because it was never going to
%   have one -- it is handled by a BATCH POST-PASS,
%   did2.convert.foldGenericFiles, one of the nine the harness composes. Looking
%   for +migrators_j/generic_file.m finds nothing and always will, so absence
%   there is the design and not a gap. The "4 UNVERIFIED coverage rows" bucket
%   no longer exists either: coverage.py now reports `gap` False on all 102 rows.
%
%   What remains true and is the reason this paragraph stays: a Babu dataset's
%   plasmid and LC-MS labels point at their referent through `document_id`, and
%   that edge is this migrator's business rather than the fold's.
%
%   NO COUNTER WATCHES THIS EDGE. `did2.validate.silentLoss` counts EMPTY
%   REQUIRED edges only -- `requiredDependencies` (silentLoss.m:930-961) returns
%   a name only `if ~logical(dep.mustBeNonEmpty); return; end`. The V_eta
%   tombstone declares `"mustBeNonEmpty": false` on `document_id` (NDI's own
%   schema_documents/data/ontologyLabel_schema.json declares
%   `"mustbenotempty": 1`), so an empty or absent `document_id` on a migrated
%   `ontology_label` would NOT appear in the empty-required-edge census. A corpus
%   run reporting 0 empty required edges is therefore NOT evidence about this
%   edge; the tests below are. Raising the tombstone to required is a SCHEMA
%   change and is not made here -- a new required edge is exactly what produced
%   the six 100%-empty-edge classes.
%
%   INDEPENDENT OF THE E. COLI QUESTION. The blocked half recorded at
%   ndi.migrate.internal.ontologyLabelSubjects.m:59-73 is about whether the
%   REFERENT has a subject to inherit; this is about whether the edge TO the
%   referent exists at all. The E. coli labels at doImport.m 799/816/832 set
%   `document_id` exactly like the behaviour ones -- the difference is entirely
%   on the imageStack, which sets `subject_id` at 432/466/482/501 and not at all
%   in Step 8. Carrying `document_id` is what makes that pass POSSIBLE to run;
%   it does not decide it, and the team call is untouched.
%
%   THE GUARD. A body carrying `ontology_name`, `label_id` or `label` is REJECTED
%   BY NAME: those are DID-side inventions, so their presence means a fixture or a
%   caller has been built against our schema instead of the real document. (Note
%   the default +migrators/ontology_label, on the V_delta path, still reads those
%   names; this guard is on the V_eta path only.)
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'ontology_label');
if isfield(blk, 'ontology_name') || isfield(blk, 'label_id') || isfield(blk, 'label')
    error('did2:convert:ontologyLabelInventedShape', ...
        ['ontology_label body carries `ontology_name`/`label_id`/`label`, ' ...
         'which no did_v1 document has -- the class has exactly one property ' ...
         'field, `ontology_node` (`ontologyNode` before universalRenames), and ' ...
         'one dependency, `document_id`. This shape can only come from the ' ...
         'V_alpha snapshot or a fixture built against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
