function report = silentLoss(docs, opts)
%SILENTLOSS Report-only audit for data that migrates away without a trace.
%
%   REPORT = did2.validate.silentLoss(DOCS) inspects already-migrated
%   documents and counts two things the existing gates CANNOT see:
%
%     1. a REQUIRED depends_on edge that is empty
%     2. a REQUIRED field whose value is present but VACUOUS -- a struct
%        whose every leaf is blank, e.g. an ontology_term {node:'', name:''}
%
%   WHY THIS EXISTS
%   ---------------
%   A migrator that reads a field the source document does not have emits an
%   EMPTY BUT PERFECTLY VALID document. Two independent holes let it through:
%
%     did2.schema.cache/isEmptyValue calls a struct empty only when it has NO
%     FIELDNAMES, so {node:'',name:''} satisfies mustBeNonEmpty.
%
%     depends_on non-emptiness is enforced NOWHERE: the schema cache never
%     checks dependencies, and did2.validate.references deliberately SKIPS
%     empty edges as "intentionally unfilled optional dependencies".
%
%   So the corpus reports 0 quarantine and 0 orphans while the content is
%   gone. That is how ontology_image migrated every document to an
%   observation about nobody, of nothing, for months without a red test.
%
%   REPORT-ONLY, ON PURPOSE
%   -----------------------
%   This RAISES NOTHING and CHANGES NO OUTCOME. Turning these into hard
%   failures today would quarantine a large, unknown number of documents and
%   block the 0-quarantine gate before a single migrator has been fixed. The
%   census comes first: it says which migrators are losing data and how many
%   real documents each one touches, which is what ranks the repair work.
%   Enforcement lands only once these counts reach zero.
%
%   See did-schema/schemas/V_eta_ground_truth_plan.md, Phase 1.
%
%   REPORT fields:
%     total_docs                  documents inspected
%     empty_required_dependency   struct array {class_name, edge_name, count}
%     vacuous_required_field      struct array {class_name, block, field_name, count}
%     empty_dependency_count      total occurrences
%     vacuous_field_count         total occurrences
%     family_count_violation      #63: struct array {class_name, edge_name,
%                                 declared, found, count} -- a NUMBERED edge
%                                 family whose instance count falls outside the
%                                 declared min_count/max_count. REPORT ONLY.
%     family_violation_count      total occurrences
%     family_uniqueness_violation #52: struct array {class_name, edge_name,
%                                 unique_by, key, count} -- two members of one
%                                 numbered family referring to documents that
%                                 AGREE on the family's `referent_unique_by`
%                                 path, i.e. two members nothing distinguishes.
%                                 REPORT ONLY.
%     family_uniqueness_violation_count   total occurrences
%     uniqueness_denominator      #52's own denominators (see below)
%     epoch_association           MEASUREMENT ONLY: does a statement actually
%                                 reach an epoch? See the block below.
%     ndi_required_dependency     THE BLIND SPOT BELOW: struct array
%                                 {class_name, edge_name, count} -- an edge NDI
%                                 declares REQUIRED, V_eta declares OPTIONAL,
%                                 and the document leaves BLANK. REPORT ONLY,
%                                 AND NEVER SUMMED WITH empty_required_dependency.
%     ndi_required_dependency_count       total occurrences
%     ndi_required_denominator    that block's own denominators
%     edge_arity                  THE UNGATED EDGE-ARITY CENSUS (see below):
%                                 how many documents carry ONE member of an
%                                 edge family, how many carry TWO, how many
%                                 carry THREE OR MORE -- per (class, family),
%                                 for EVERY class. REPORT ONLY.
%     edge_arity_plural_count     (document, family) pairs carrying MORE THAN
%                                 ONE member. The headline number.
%     skipped_docs                documents whose schema could not be resolved
%
%   THE EDGE-ARITY CENSUS -- "HOW MANY DOCUMENTS CARRY A PLURAL EDGE"
%   -----------------------------------------------------------------
%   NOTHING IN THIS REPOSITORY OR IN NDI COULD ANSWER THAT QUESTION, and the
%   answer was being written down as UNMEASURED. Three counters could have and
%   each is out of reach:
%
%     ndi.migrate.internal.imagedEntitySubjects.blocked_plural_document_id
%         NDI-side. The DID corpus harness never invokes that pass, so its zero
%         means "not run", not "none".
%     ndi.migrate.internal.ontologyRowSubjects
%         has no plural counter at all. `resolved_via_document_id_edge` counts
%         RESOLUTIONS, not ARITY -- a row with three edges that resolves once
%         increments it once.
%     uniqueness_denominator.docs_multi_member (this file, #52)
%         IS an arity counter, and it is GATED: a family enters it only when the
%         schema declares `referent_unique_by` on it. DID-schema's
%         `_EDGE_REFERENT_UNIQUE` has THREE entries, all `time_reference_#`, so
%         every other family in the schema -- including `document_id` -- is
%         invisible to it. Not zero. NOT LOOKED AT.
%
%   SO THIS BLOCK IS GATED ON NOTHING. It reads the DOCUMENT's own `depends_on`
%   and asks how many entries fall in each family. No schema lookup, no marker,
%   no declaration required: a family exists here because a document carries it,
%   which is the only way to see an edge the schema never described. Scoping it
%   to `ontology_table_row` -- the class the question was asked about -- would
%   have rebuilt the same blind spot one name narrower.
%
%   WHAT COUNTS AS ONE FAMILY. An entry named `<stem>_<digits>` belongs to
%   family `<stem>`; an entry named `<stem>` with no index belongs to the SAME
%   family. That folding is not a convenience, it is REQUIRED for the
%   denominator to mean anything, and it is what the one real consumer of this
%   idiom already does (NDI `imagedEntitySubjects/dependencyValuesMatching`
%   matches `^<name>(_\d+)?$`). NDI's writer picks the spelling BY ARITY:
%
%       ndi/+setup/+NDIMaker/tableDocMaker.m:289
%           if isscalar(values); doc.set_dependency_value('document_id', v)
%       :291
%           else;               doc.add_dependency_value_n('document_id', v)
%
%   and `add_dependency_value_n` writes `<name>_1`, `<name>_2`, ...
%   (did/document.m:349). So the singular case is spelled `document_id` and the
%   plural case is spelled `document_id_1..n`. A census keyed on the INDEXED
%   spelling alone would report the plural rows with no singular rows beside
%   them -- a numerator with no denominator, which is the failure operating
%   rule 5 exists to stop.
%
%   The family is reported under its STEM (`document_id`), not the schema's
%   `document_id_#` spelling, precisely because the stem covers both spellings
%   and the schema spelling does not.
%
%   `edge_arity` fields. DENOMINATORS FIRST AND UNCONDITIONALLY (rule 5), and
%   stamped on every path out of this function including the early returns:
%     docs_inspected / docs_unreadable / docs_unclassifiable / docs_classified
%                                 the same three-way partition the NDI-required
%                                 block uses, and it holds here for the same
%                                 reason -- the classification counter is
%                                 incremented at the classification step, which
%                                 is the one point every document reaches once.
%     docs_errored                documents that THREW inside this block. It
%                                 OVERLAPS the three states above and is NOT
%                                 one of them: a document that classified and
%                                 then threw stays in `docs_classified`, so the
%                                 partition is exact and this is the separate
%                                 fact "and N of them did not finish". Summing
%                                 it into the partition would over-count.
%     docs_with_depends_on        documents carrying at least one edge at all
%                                 <-- AT ZERO THE CENSUS COULD NOT FIRE. It
%                                     means no document in the batch has a
%                                     `depends_on` block, not that none is
%                                     plural.
%     docs_with_indexed_edge      documents carrying at least one `_<digits>`
%                                 entry. A DIFFERENT fact from the line above
%                                 and from the line below: a document can carry
%                                 an indexed edge and still be singular
%                                 (`time_reference_1` alone).
%     docs_with_plural_family     documents carrying >1 member of SOME family
%     edges_examined              `depends_on` entries inspected
%     edges_unnamed               entries with no usable `name`. Dropped from
%                                 the tally and COUNTED, because a silent drop
%                                 is how a denominator stops meaning anything.
%     indexed_edges_examined      of those, entries whose name ended `_<digits>`
%     pairs_examined              (document, family) pairs -- the denominator
%                                 the arity distribution is taken over
%     pairs_plural                pairs with >1 member  <-- THE COUNT, restated
%                                 here so the row table, the headline
%                                 `edge_arity_plural_count` and the denominator
%                                 cannot drift apart without a test noticing
%     families_seen               distinct (class, family) pairs anywhere
%     plural_families_seen        distinct (class, family) pairs EVER plural
%     max_arity_seen              the largest arity anywhere in the batch
%     arity_distribution          {class_name, edge_name, arity, count} where
%                                 `arity` is '1', '2' or '3+' and `count` is
%                                 DOCUMENTS. The '1' rows are the denominator
%                                 for the '2' and '3+' rows on the same family;
%                                 they are emitted unconditionally for that
%                                 reason and are not noise.
%     plural_by_family            {class_name, edge_name, max_arity, count} --
%                                 one row per family EVER seen plural, `count`
%                                 being the documents that carried >1. Empty
%                                 when nothing is plural, which is a RESULT only
%                                 if `pairs_examined` is non-zero.
%
%   REPORT ONLY, like everything else in this file. It raises nothing,
%   quarantines nothing and arms nothing. An arity is not a violation: some
%   families are meant to be plural (`derived_from`, `syncrule_id`). The census
%   says which are and how often, and the disposition is a team call.
%
%   THE EDGES NDI REQUIRES AND V_eta DOES NOT -- A WHOLE CLASS OF BLIND SPOT
%   ------------------------------------------------------------------------
%   STATUS 2026-08-11: written without MATLAB (none in the authoring
%   environment), then EXECUTED BY CI -- quick migrator tests run 31463987352,
%   job 93692972908, head 8f0d255. EIGHT new cases; SEVEN passed, ONE failed.
%   (A first draft of this note said "nine of the ten", which was a number I
%   wrote from memory rather than from the run. Counted off the job log's
%   per-test table: testSilentLoss contributed 30 rows, 29 true / 1 false, and
%   8 of those rows are the new block's. An inflated progress figure is the
%   error this repository is most prone to, so it is stated from the table.)
%   The seven that passed include the ones proving the `ndi_mustBeNonEmpty`
%   marker reaches the schema cache and that the two buckets stay separate. The
%   one that failed: testTheDenominatorIsPresentOnEveryPathOut expected
%   `docs_unreadable = 2` for a batch of two class-less structs and got 0.
%
%   THE COUNTER WAS RIGHT AND THE TEST WAS WRONG. `asStruct` returns any struct
%   handed to it unchanged, so both parsed and `unreadable` was truthfully 0;
%   the test had borrowed the field name from epoch_association and assumed it
%   meant "not looked at". The repair was NOT to restate the number: the state
%   that did occur -- parsed, no `document_class`, never looked at -- had no
%   name and was visible only as a subtraction, so it is now counted as
%   `docs_unclassifiable` and the three states partition `docs_inspected`
%   exactly. The block is still report-only and still cannot move a gate.
%
%   `requiredDependencies` (this file, and did2.schema.cache's copy of the same
%   rule) returns names only for edges declared `mustBeNonEmpty` in the V_eta
%   class chain. So wherever V_eta RELAXED an edge NDI requires, that edge is
%   OUT OF SCOPE for the empty-edge census entirely. It is not counted as zero.
%   IT IS NOT LOOKED AT. "0 empty required edges across 627,526 documents" is
%   therefore SILENT about that whole set rather than reassuring about it, and
%   the set is not one class -- 26 edges across 26 classes at the time of
%   writing.
%
%   The motivating case, which is NOT about enforcement:
%
%     NDI    ndi_common/schema_documents/data/ontologyLabel_schema.json
%            {"name": "document_id", "mustbenotempty": 1}
%     V_eta  schemas/V_eta/stable/ontology_label.json
%            {"name": "document_id", "mustBeNonEmpty": false}  -> base
%
%   `ontology_label` is `disposition: retire` -- a GUARDED PASSTHROUGH deferred
%   to the NDI second pass, ~7,007 documents. `document_id` is the JOIN KEY
%   that pass needs: label -> document_id -> image_stack -> subject. If the
%   edge is blank on some fraction, the dissolution cannot resolve those
%   documents, and we would find out only after building it. SO THIS CENSUS IS
%   AN INPUT TO PLANNING, NOT A GATE.
%
%   WHY IT CANNOT MOVE THE CORPUS RESULT. The fact arrives as a SEPARATE schema
%   key, `ndi_mustBeNonEmpty`, stamped at build time by DID-schema's
%   tools/ndi_required_stamp.py from NDI's own schema documents. Nothing reads
%   it except the block below. The armed DID_ENFORCE_REQUIRED_DEPENDENCIES gate
%   calls did2.schema.cache/requiredDependencies, which tests
%   `dep.mustBeNonEmpty` and nothing else; did2.validate.references skips empty
%   edges regardless. This block raises nothing, quarantines nothing and arms
%   nothing -- exactly like every other block in this file.
%
%   THE TWO BUCKETS ARE DIFFERENT FACTS AND ARE NEVER ADDED TOGETHER.
%   `empty_required_dependency` is "an edge OUR schema requires is blank" --
%   the number the team armed a gate on. This one is "an edge NDI requires is
%   blank while WE permit it". Merging them would make the armed gate's figure
%   unreadable, so they are separate fields, separate counts, separate lines in
%   the digest, and an edge falls in exactly one of them by construction (the
%   test below is `ndi_mustBeNonEmpty && ~mustBeNonEmpty`).
%
%   `ndi_required_denominator` fields. DENOMINATORS FIRST (rule 5):
%     docs_inspected / docs_unreadable / docs_unclassifiable / docs_classified
%                                 restated inside the block, on every path out
%                                 of this function including the early returns,
%                                 so a zero here can never be read out of
%                                 context of total_docs. THE THREE OUTCOMES
%                                 PARTITION THE DENOMINATOR EXACTLY:
%
%                                   unreadable + unclassifiable + classified
%                                       == inspected
%
%                                 and they are three DIFFERENT facts:
%                                   unreadable      vBodies could not parse a
%                                                   body out of it at all
%                                   unclassifiable  it parsed, and carries no
%                                                   `document_class`, so there
%                                                   is nothing to look up
%                                   classified      it has a class name, so
%                                                   there was something to look
%                                                   up. NOT a claim that every
%                                                   later check completed -- a
%                                                   document that throws further
%                                                   down is still classified and
%                                                   is separately visible in
%                                                   `skipped_docs`. The counter
%                                                   is incremented AT the
%                                                   classification step for
%                                                   exactly that reason: it is
%                                                   the only point every
%                                                   document reaches once, so it
%                                                   is the only one that can
%                                                   make the partition exact.
%
%                                 `docs_unclassifiable` was ADDED after CI ran
%                                 this file for the first time (run 31463987352).
%                                 A test here asserted that a batch of two
%                                 class-less structs reported `docs_unreadable
%                                 = 2`; it reports 0, and 0 is CORRECT -- both
%                                 parsed fine, `asStruct` returns any struct
%                                 handed to it unchanged. The test had borrowed
%                                 the field name from epoch_association and
%                                 assumed it meant "not looked at". It does not.
%                                 But the state that DID occur had no name and
%                                 was readable only as a subtraction, so the
%                                 repair was to name it rather than to restate
%                                 the assertion. NOTE the sibling
%                                 `epoch_association` block has the identical
%                                 unnamed residual and is deliberately NOT
%                                 changed here -- out of scope, recorded so it
%                                 is not mistaken for a checked property.
%     marker_key                  THE KEY THIS BLOCK FOLLOWED, printed as data.
%                                 If the build stops stamping it, or renames
%                                 it, every count below goes to zero and the
%                                 report would otherwise read clean. That is
%                                 the demo_ndi failure -- a query against a
%                                 string the schema has never contained,
%                                 reported as "this does not exist".
%     classes_carrying_the_marker distinct classes IN THIS BATCH whose chain
%                                 declares the marker at all, either value.
%                                 <-- AT ZERO THE BLOCK IS VACUOUS. It means
%                                     the schema was not stamped, not that NDI
%                                     and V_eta agree.
%     relaxed_classes             distinct classes whose chain declares at
%                                 least one RELAXED edge (marker true, ours
%                                 false)
%     relaxed_edges_declared      distinct (class, edge) pairs so declared
%                                 <-- AT ZERO THE COUNTER COULD NOT FIRE, and a
%                                     zero violation count says only that
%     relaxed_class_names         the class names behind `relaxed_classes`,
%                                 SORTED. A cell, empty when nothing was seen.
%     relaxed_edge_names          the pairs behind `relaxed_edges_declared`,
%                                 SORTED, spelled `class.edge` -- the same
%                                 spelling an `ndi_required_dependency` row
%                                 renders in, so the two are comparable
%                                 <-- WITHOUT THESE THE BLOCK COULD SAY HOW
%                                     MANY DIVERGENCES A CORPUS EXERCISED AND
%                                     NOT WHICH, so the COMPLEMENT -- the
%                                     divergences no corpus touches, which are
%                                     unmeasured rather than clean -- was not
%                                     nameable from any artifact. The counts
%                                     above are unchanged and still mean what
%                                     they meant; these are additional, and
%                                     numel(names) == the paired count.
%     docs_declaring_a_relaxed_edge   documents whose class declares >=1
%     edges_examined              (document, relaxed edge) pairs inspected
%     edges_populated             the edge carried a non-blank referent
%     edges_empty                 blank -- THE COUNT, restated so the row table
%                                 and the denominator cannot disagree silently
%
%   THE EPOCH ASSOCIATION -- MEASUREMENT ONLY, NOTHING IS TIGHTENED
%   ---------------------------------------------------------------
%   The team settled (2026-08-10) that a statement reaches its epoch through a
%   REFERENCE CHAIN and not a direct edge:
%
%       subject_interaction --time_reference_#--> relative_reference
%                           --relative_to-------> epoch
%
%   `V_eta_epoch_plan.md` asks for this in as many words: *the first corpus run
%   must check `epoch_id` by name in `silentLoss` rather than trusting it*.
%
%   THE HOLE, read off the built schema (245 schema files, 13 numbered edge
%   families, 4 `epoch_id` edges):
%
%       subject_interaction  time_reference_#  mustBeNonEmpty=false  min_count 1
%       directed_relation    epoch_id          mustBeNonEmpty=false
%
%   `min_count: 1` guarantees the family EXISTS; `relative_reference.relative_to`
%   is REQUIRED, so a POPULATED reference resolves. But `mustBeNonEmpty` is
%   false, so `time_reference_1 = ''` SATISFIES the family and reaches nothing --
%   and the armed RequiredDependencies gate keys on `mustBeNonEmpty`, so it will
%   not catch it. That is the invented-empty-edge pattern one link along the
%   chain, and no counter in this file could see it: the family-count check asks
%   HOW MANY members exist and deliberately ignores whether one is blank
%   (countFamily's own comment says so), and the empty-edge check excludes
%   numbered families by construction (addRequired: `if contains(n,'#'); return`).
%   So between them the two existing checks step over exactly this case.
%
%   THIS ADDS COUNTERS AND CHANGES NO OUTCOME. It raises nothing, quarantines
%   nothing and arms nothing, exactly like every other block in this file.
%
%   `epoch_association` fields. DENOMINATORS FIRST, unconditionally (rule 5):
%     docs_inspected / docs_unreadable / docs_classified
%                                 restated inside the block so it carries its
%                                 own denominator and cannot be read out of
%                                 context of total_docs
%     anchor_edge / reference_root / terminal_class / max_depth
%                                 THE NAMES THIS BLOCK FOLLOWED. Printed as
%                                 data because they are the one part that is
%                                 not schema-driven: if the schema renames
%                                 `relative_to` or `epoch`, every count below
%                                 goes to zero, and a zero that is a property
%                                 of the query is the demo_ndi failure. The
%                                 two flags below make that renaming VISIBLE
%                                 rather than reassuring.
%     terminal_class_in_schema    1 when a class named `terminal_class` loads.
%                                 0 means every "reaches an epoch" count is
%                                 vacuous.
%     reference_root_in_schema    1 when a class named `reference_root` loads.
%
%   (1) DOES THE FAMILY REACH ANYTHING AT ALL
%     family_docs_declaring       documents whose CLASS declares a
%                                 time_reference family (the denominator: how
%                                 many documents could carry one)
%     family_docs_absent          declares it, carries no member
%     family_docs_present         carries >= 1 concrete member, any value
%     family_docs_all_empty       carries >= 1 member and EVERY member is blank
%                                 <-- THE HOLE. Present, satisfies min_count,
%                                     reaches nothing.
%     family_docs_populated       >= 1 member with a non-blank id
%     family_members_total / _empty / _populated
%     family_all_empty_by_class   {class_name, edge_name, count}
%
%   (2) EPOCH DOCUMENTS AND `epoch_id` EDGES -- THREE DISTINCT STATES
%     epoch_documents             documents whose class chain contains `epoch`
%     epoch_id_docs_declaring     documents whose CLASS declares an `epoch_id`
%                                 edge (so "no edges present" and "no class
%                                 declares one" are different output)
%     epoch_id_edges_present      concrete edges found
%     epoch_id_empty              edge present, value blank
%     epoch_id_resolved           value names a document IN THIS BATCH
%     epoch_id_resolved_not_epoch of those, the target is not an `epoch`
%                                 <-- a resolving edge pointing at the wrong
%                                     kind of thing is not a healthy edge
%     epoch_id_unresolved_in_batch  value names a document NOT in this batch
%     epoch_id_by_class           {class_name, state, count}
%
%     WHY THE THIRD STATE IS NOT CALLED "DANGLING". A batch is a SAMPLE. An
%     edge naming a document that is not in THIS batch may resolve perfectly in
%     a full migration -- jSessionAnchor's discovery-mode orphans were exactly
%     that, and calling them broken is the error operating rule 3 names. The
%     three states are kept distinct as asked; the third is named for what was
%     actually measured.
%
%   (3) THE CHAIN, END TO END -- the number the decision rests on
%     chain_docs_examined         documents with >= 1 POPULATED member
%     chain_docs_reaching_epoch   >= 1 member whose chain terminates at an
%                                 `epoch` document            <-- THE NUMBER
%     chain_docs_reaching_no_epoch  every member terminated at a definite
%                                 non-epoch document
%     chain_docs_undetermined     no member reached an epoch AND at least one
%                                 left the batch or hit the depth limit --
%                                 NOT MEASURED, not a failure
%     chain_members_examined      and, summing to it exactly:
%       chain_member_unresolved       target not in this batch
%       chain_member_not_a_reference  target resolved, but its class chain does
%                                     not contain `reference_root` -- the family
%                                     points at something that is not a time
%                                     reference at all
%       chain_member_anchor_absent    the reference's CLASS declares no
%                                     `anchor_edge` (absolute_reference,
%                                     session_relative_reference): terminal by
%                                     design, reaches no epoch
%       chain_member_anchor_empty     the class declares it, the document
%                                     leaves it blank
%       chain_member_reaches_epoch
%       chain_member_reaches_other    terminated at a definite non-epoch doc
%       chain_member_incomplete       every branch left the batch
%       chain_member_depth_exceeded   chain longer than max_depth
%     chain_terminus_by_class     {class_name, count} for reaches_other
%
%   The eight member states are EXHAUSTIVE and their sum equals
%   chain_members_examined -- locked by test, so a member cannot fall out of
%   the accounting into a silence.
%
%   STATUS OF THE #72 BLOCK: WRITTEN WITHOUT MATLAB AND NOT EXECUTED. No MATLAB
%   or Octave was available in the container it was written in, so the only
%   checks performed on this file were structural (block balance, helper
%   resolution) -- NOT a run. The tests in
%   tests/+did2/+unittest/testSilentLoss.m are the first execution of it, and
%   they are the gate, not a formality: this counter's older siblings shipped
%   with no tests and measured nothing for two days. The PYTHON half of the
%   path (tools/census_digest.py, which renders every field below) IS executed
%   and mutation-checked by tools/test_census_digest.py.
%
%   #52 -- WHAT MAKES TWO MEMBERS OF A FAMILY DIFFERENT
%   ---------------------------------------------------
%   #63 declared HOW MANY members a family may carry. It could not say what
%   makes two of them distinct, so `time_reference_1` and `time_reference_2` on
%   one document were undefined in meaning: a bare index cannot tell a
%   start-anchor from a same-instant-other-clock from a recurrence.
%
%   The signed time model (`V_eta_time_reference_model_plan.md` CHANGE 5) closed
%   that by ELIMINATION -- split-anchored intervals have no instance, recurrence
%   dissolves into N statements, epoch extent and statement time live on
%   different documents -- leaving ONE live case, SAME EXTENT / N CLOCKS, whose
%   discriminator already exists INSIDE THE REFERENCED DOCUMENT as `value.clock`.
%   The schema now says so machine-readably, as `referent_unique_by` on the
%   family (did-schema tools/build_v_eta.py, `_EDGE_REFERENT_UNIQUE`). This
%   function reads that key; it does not know the word "time_reference".
%
%   WHY IT LIVES HERE AND NOWHERE ELSE. The path is evaluated on the REFERENCED
%   document, so checking it needs the other documents.
%     * did2.schema.cache sees ONE document. It cannot resolve a target, and a
%       version that passed whenever it could not is the all-zero census one
%       more time.
%     * did2.validate.references walks edges but is handed IDS, not bodies (its
%       'Database' mode has only ids), so it can say an edge resolves and not
%       what it resolves TO.
%     * silentLoss is handed the whole migrated batch. That is where the data
%       is, so that is where the check is. It is therefore a BATCH property and
%       is stated as one -- there is no per-document form of this rule.
%
%   THE DENOMINATORS ARE THE POINT (operating rule 5). A zero here can mean four
%   different things and they must be distinguishable from the report alone:
%     families_declared              distinct (class, family) pairs carrying
%                                    the rule anywhere in the batch
%     docs_with_family               (document, family) pairs with >=1 member
%     docs_multi_member              (document, family) pairs with >1 member
%                                    <-- AT ZERO THE RULE CANNOT FIRE AT ALL,
%                                    and a zero violation count says only that
%     members_examined               family members inspected
%     members_resolved               target found in this batch
%     members_unresolved             target NOT in the batch -- NOT CHECKED
%     members_no_key                 target resolved but the path is absent or
%                                    blank -- NOT CHECKED
%     members_keyed_by_node          compared on the ontology CURIE
%     members_keyed_by_name          compared on the label, because the node is
%                                    empty (the NDIC clocktype terms are not
%                                    minted -- #67)
%
%   Name/value:
%     'SchemaCache'  a did2.schema.cache (defaults to the shared singleton)

arguments
    docs
    opts.SchemaCache = []
end

report = struct( ...
    'total_docs',                0, ...
    'empty_required_dependency', struct('class_name', {}, 'edge_name', {}, 'count', {}), ...
    'vacuous_required_field',    struct('class_name', {}, 'block', {}, 'field_name', {}, 'count', {}), ...
    'empty_dependency_count',    0, ...
    'vacuous_field_count',       0, ...
    'family_count_violation',    struct('class_name', {}, 'edge_name', {}, ...
                                        'declared', {}, 'found', {}, 'count', {}), ...
    'family_violation_count',    0, ...
    'family_uniqueness_violation', struct('class_name', {}, 'edge_name', {}, ...
                                        'unique_by', {}, 'key', {}, 'count', {}), ...
    'family_uniqueness_violation_count', 0, ...
    'uniqueness_denominator',    struct( ...
        'families_declared',     0, ...
        'docs_with_family',      0, ...
        'docs_multi_member',     0, ...
        'members_examined',      0, ...
        'members_resolved',      0, ...
        'members_unresolved',    0, ...
        'members_no_key',        0, ...
        'members_keyed_by_node', 0, ...
        'members_keyed_by_name', 0), ...
    'epoch_association',         eaNewReport(), ...
    'ndi_required_dependency',   struct('class_name', {}, 'edge_name', {}, ...
                                        'count', {}), ...
    'ndi_required_dependency_count', 0, ...
    'ndi_required_denominator',  nrNewReport(), ...
    'edge_arity',                arNewReport(), ...
    'edge_arity_plural_count',   0, ...
    'skipped_docs',              0);

[bodies, unreadable] = vBodies(docs);
% total_docs counts what was HANDED IN, not what could be parsed. Counting the
% survivors made an all-zero report indistinguishable from a clean one -- see
% the note in +validate/private/vBodies.m.
report.total_docs = numel(bodies) + unreadable;
report.skipped_docs = unreadable;
% The epoch-association block restates the denominator INSIDE itself, and does
% so on every path out of this function including the early returns below. A
% block whose denominator is only set on the happy path is a block that reports
% zeros for a batch it never opened -- which is the original silentLoss defect,
% verbatim.
report.epoch_association.docs_inspected = report.total_docs;
report.epoch_association.docs_unreadable = unreadable;
% Same rule, same reason, for the NDI-required block: a denominator set only on
% the happy path is a block that reports zeros for a batch it never opened.
report.ndi_required_denominator.docs_inspected = report.total_docs;
report.ndi_required_denominator.docs_unreadable = unreadable;
% And the edge-arity block, for the third time and for the third identical
% reason. This one is the block whose whole purpose is to answer a question
% currently recorded as UNMEASURED, so a zero it prints without a denominator
% beside it would close that question with the wrong answer.
report.edge_arity.docs_inspected = report.total_docs;
report.edge_arity.docs_unreadable = unreadable;
% RUN BEFORE THE SCHEMA CACHE IS EVEN ASKED FOR, and deliberately so. Every
% other block below dies on the `no schema available` return a few lines down
% and reports zeros for a batch it did open. This census reads the DOCUMENT and
% nothing else -- no class chain, no marker, no declaration -- so there is no
% reason for it to share that fate, and making it structurally independent is
% the strongest available statement that it is ungated. It also means its
% three document states partition its denominator on EVERY path, not just the
% happy one.
report.edge_arity = arityCensus(bodies, report.edge_arity);
report.edge_arity_plural_count = report.edge_arity.pairs_plural;
if isempty(bodies)
    return;
end

cache = opts.SchemaCache;
if isempty(cache)
    try
        cache = did2.schema.cache.shared();
    catch
        report.skipped_docs = numel(bodies);
        report.epoch_association.docs_unreadable = report.total_docs;
        return;   % no schema available -- report nothing rather than guess
    end
end

% #72. The names this block follows, recorded as DATA in the report, plus
% whether the schema still has classes by those names. Everything else in this
% block is schema-driven; these four strings are not, so a rename would send
% every count to zero and the report would read clean. It says so instead.
% (The four names themselves are stamped by eaNewReport, so they are present
% even on the early returns above.) These two flags need the cache:
report.epoch_association.terminal_class_in_schema  = ...
    double(eaClassLoads(cache, eaTerminalClass()));
report.epoch_association.reference_root_in_schema  = ...
    double(eaClassLoads(cache, eaReferenceRoot()));

depKeys = {}; depCounts = [];
fldKeys = {}; fldCounts = [];
famKeys = {}; famCounts = [];
uniKeys = {}; uniCounts = [];
% #72 row tables. Accumulated here and ASSIGNED at the bottom -- the one bug
% this file has already shipped (famKeys accumulated, never assigned, so the
% report read 0 on a document the detector had just flagged) is the reason
% these three assignments are tested individually rather than assumed.
eaEmptyKeys = {}; eaEmptyCounts = [];
eaEdgeKeys  = {}; eaEdgeCounts  = [];
eaTermKeys  = {}; eaTermCounts  = [];
% The NDI-required-but-V_eta-optional rows. Accumulated here, ASSIGNED at the
% bottom -- the fourth accumulator in this file, and the reason it is called
% out is that the first one (famKeys) shipped accumulated-and-never-assigned,
% so the report read 0 on a document the detector had just flagged.
nrKeys = {}; nrCounts = [];
% className -> the relaxed-edge names its chain declares, plus whether the
% chain carries the marker at all. Memoised: the chain walk is per-class and
% this runs over 336k-document corpora.
nrClassMemo = containers.Map('KeyType', 'char', 'ValueType', 'any');
% The distinct-thing denominators, as MAPS rather than growing cell arrays.
% `any(strcmp(list, key))` over a few hundred class names, once per document,
% is ~10^8 string compares on a 562,448-document census -- a report-only
% counter must not make the corpus job measurably slower.
nrSeenClasses = containers.Map('KeyType', 'char', 'ValueType', 'logical');
nrSeenRelaxed = containers.Map('KeyType', 'char', 'ValueType', 'logical');
nrSeenEdges   = containers.Map('KeyType', 'char', 'ValueType', 'logical');

% #52. The id -> body index the uniqueness check resolves through. Built ONCE,
% up front, over the whole batch -- this is the thing a per-document validator
% does not have and cannot fake. Documents with no `base.id` simply do not enter
% it; they can still REFER, they just cannot be referred to.
idIndex = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    thisId = bodyId(bodies{k});
    if ~isempty(thisId) && ~idIndex.isKey(thisId)
        idIndex(thisId) = bodies{k};
    end
end
uniqueFamilySeen = {};   % (class|family) pairs that actually carry the rule

% #72 memos. eaClassMemo: className -> what the SCHEMA says about that class
% (is it an epoch, is it a time reference, does it declare the anchor edge,
% does it declare epoch_id). eaWalkMemo: a reference document's id -> the
% outcome of walking the chain from it, because many statements anchor to the
% same reference and the walk is the expensive part.
eaClassMemo = containers.Map('KeyType', 'char', 'ValueType', 'any');
eaWalkMemo  = containers.Map('KeyType', 'char', 'ValueType', 'any');

for k = 1:numel(bodies)
    body = bodies{k};
    % The audit must never be able to break a migration. Any document we
    % cannot resolve is counted as skipped, not failed.
    try
        className = classNameOf(body);
        if isempty(className)
            report.skipped_docs = report.skipped_docs + 1;
            % NAMED, not left to subtraction. A body that PARSED but carries no
            % `document_class` is neither `docs_unreadable` (vBodies read it
            % fine) nor `docs_classified` (nothing could be looked up for it).
            % Until this line it fell between the two and was visible only as
            % the residual `inspected - unreadable - classified`, which is a
            % denominator a reader has to compute rather than read. See the
            % note on `docs_unclassifiable` in nrNewReport.
            report.ndi_required_denominator.docs_unclassifiable = ...
                report.ndi_required_denominator.docs_unclassifiable + 1;
            continue;
        end
        % INCREMENTED HERE, at the classification step itself, and NOT further
        % down beside the block that uses it. Every document passes through
        % this exact point once, so
        %     docs_unreadable + docs_unclassifiable + docs_classified
        %         == docs_inspected
        % holds EXACTLY. When this lived after section 1, a document that threw
        % in section 1 was classified, was counted in neither, and the three
        % states silently stopped adding up to the denominator -- an accounting
        % hole of the same shape as the one this whole block exists to close.
        report.ndi_required_denominator.docs_classified = ...
            report.ndi_required_denominator.docs_classified + 1;

        % --- 1. required depends_on edges that are empty -----------------
        required = requiredDependencies(cache, className);
        for d = 1:numel(required)
            name = required{d};
            if ~edgeIsPopulated(body, name)
                key = sprintf('%s|%s', className, name);
                [depKeys, depCounts] = bump(depKeys, depCounts, key);
            end
        end

        % --- 1a2. EDGES NDI REQUIRES AND V_eta DOES NOT -------------------
        % REPORT ONLY, and a SEPARATE BUCKET from 1 above. See the block
        % comment at the top of the file: an edge V_eta relaxed is invisible to
        % `requiredDependencies` by construction, so the census above is silent
        % about it rather than clean. This counts it without touching the
        % `mustBeNonEmpty` that 1 and the armed gate both key on.
        nrInfo = relaxedDependencies(cache, className, nrClassMemo);
        % These three are containers.Map, a HANDLE class, so the assignments
        % mutate the maps created above -- the analyser calls the local name
        % unused because the effect is on the shared object. Same note as the
        % memo sites below; do not delete them to silence it.
        if nrInfo.marker_present
            nrSeenClasses(className) = true;
        end
        if ~isempty(nrInfo.names)
            nrSeenRelaxed(className) = true;
            report.ndi_required_denominator.docs_declaring_a_relaxed_edge = ...
                report.ndi_required_denominator.docs_declaring_a_relaxed_edge + 1;
        end
        for d = 1:numel(nrInfo.names)
            name = nrInfo.names{d};
            pairKey = sprintf('%s|%s', className, name);
            nrSeenEdges(pairKey) = true;
            report.ndi_required_denominator.edges_examined = ...
                report.ndi_required_denominator.edges_examined + 1;
            if edgeIsPopulated(body, name)
                report.ndi_required_denominator.edges_populated = ...
                    report.ndi_required_denominator.edges_populated + 1;
            else
                report.ndi_required_denominator.edges_empty = ...
                    report.ndi_required_denominator.edges_empty + 1;
                [nrKeys, nrCounts] = bump(nrKeys, nrCounts, pairKey);
            end
        end

        % --- 1b. NUMBERED families: is the INSTANCE COUNT in range? -------
        % #63. `mustBeNonEmpty` cannot describe a family -- a missing instance
        % is not a blank one -- so three families were declared REQUIRED and
        % verified by nothing. What is checkable is how many instances exist.
        % REPORT ONLY: the counts have never been measured, and enforcing a
        % minimum before knowing them is how a gate turns red on real data.
        families = declaredFamilies(cache, className);
        for f = 1:numel(families)
            fam = families(f);
            found = countFamily(body, fam.name);
            bad = found < fam.min_count || ...
                  (~isnan(fam.max_count) && found > fam.max_count);
            if bad
                key = sprintf('%s|%s|%s|%d', className, fam.name, ...
                    describeRange(fam), found);
                [famKeys, famCounts] = bump(famKeys, famCounts, key);
            end
        end

        % --- 1c. NUMBERED families: are the members DISTINGUISHABLE? ------
        % #52. Everything above this line is about ONE document. This is not:
        % the discriminator lives on the REFERENCED document, so the family is
        % resolved through idIndex and read there. A member whose target is not
        % in this batch is counted as UNRESOLVED and compared with nothing --
        % it is NOT silently treated as unique, which would turn an incremental
        % import into a clean bill of health it did not earn.
        for f = 1:numel(families)
            fam = families(f);
            if isempty(fam.unique_by); continue; end
            famKey = sprintf('%s|%s', className, fam.name);
            if ~any(strcmp(uniqueFamilySeen, famKey))
                uniqueFamilySeen{end+1} = famKey; %#ok<AGROW>
            end
            memberIds = familyMemberIds(body, fam.name);
            if isempty(memberIds); continue; end
            report.uniqueness_denominator.docs_with_family = ...
                report.uniqueness_denominator.docs_with_family + 1;
            if numel(memberIds) > 1
                report.uniqueness_denominator.docs_multi_member = ...
                    report.uniqueness_denominator.docs_multi_member + 1;
            end
            seenKeys = {};
            for m = 1:numel(memberIds)
                report.uniqueness_denominator.members_examined = ...
                    report.uniqueness_denominator.members_examined + 1;
                if ~idIndex.isKey(memberIds{m})
                    report.uniqueness_denominator.members_unresolved = ...
                        report.uniqueness_denominator.members_unresolved + 1;
                    continue;
                end
                report.uniqueness_denominator.members_resolved = ...
                    report.uniqueness_denominator.members_resolved + 1;
                [dkey, how] = referentKey(idIndex(memberIds{m}), fam.unique_by);
                switch how
                    case 'node'
                        report.uniqueness_denominator.members_keyed_by_node = ...
                            report.uniqueness_denominator.members_keyed_by_node + 1;
                    case 'name'
                        report.uniqueness_denominator.members_keyed_by_name = ...
                            report.uniqueness_denominator.members_keyed_by_name + 1;
                    otherwise
                        % The path is absent or blank on the referent. NOT a
                        % violation and NOT a pass: there is nothing to compare.
                        % Today this is the COMMON case -- only
                        % `relative_reference` declares `value.clock`, and every
                        % live anchor is still a session_*_reference.
                        report.uniqueness_denominator.members_no_key = ...
                            report.uniqueness_denominator.members_no_key + 1;
                        continue;
                end
                if any(strcmp(seenKeys, dkey))
                    % One occurrence per DUPLICATE member, not per pair: the
                    % second member sharing a clock is the one nothing
                    % distinguishes from the first.
                    key = sprintf('%s|%s|%s|%s', className, fam.name, ...
                        sanitise(fam.unique_by), sanitise(dkey));
                    [uniKeys, uniCounts] = bump(uniKeys, uniCounts, key);
                else
                    seenKeys{end+1} = dkey; %#ok<AGROW>
                end
            end
        end

        % --- 1d. THE EPOCH ASSOCIATION (#72) ------------------------------
        % MEASUREMENT ONLY. Nothing below tightens a schema, arms a gate or
        % changes what quarantines. See the block comment at the top of the
        % file for what each counter means and why the third `epoch_id` state
        % is not called "dangling".
        info = eaClassInfo(cache, className, eaClassMemo);
        report.epoch_association.docs_classified = ...
            report.epoch_association.docs_classified + 1;
        if info.is_terminal
            report.epoch_association.epoch_documents = ...
                report.epoch_association.epoch_documents + 1;
        end

        % (1) the time_reference family: does it reach anything at all?
        % A family qualifies by what the SCHEMA says it refers to -- a class
        % whose chain contains `time_reference` -- not by being spelled
        % "time_reference_#". Three families qualify today (subject_interaction,
        % directed_relation, epoch) and a fourth would qualify by being
        % declared, not by being added to a list here.
        for f = 1:numel(families)
            fam = families(f);
            if ~any(strcmp(info.time_families, fam.name)); continue; end
            report.epoch_association.family_docs_declaring = ...
                report.epoch_association.family_docs_declaring + 1;
            memberVals = familyMemberValues(body, fam.name);
            if isempty(memberVals)
                report.epoch_association.family_docs_absent = ...
                    report.epoch_association.family_docs_absent + 1;
                continue;
            end
            report.epoch_association.family_docs_present = ...
                report.epoch_association.family_docs_present + 1;
            blank = cellfun(@isempty, memberVals);
            report.epoch_association.family_members_total = ...
                report.epoch_association.family_members_total + numel(memberVals);
            report.epoch_association.family_members_empty = ...
                report.epoch_association.family_members_empty + sum(blank);
            report.epoch_association.family_members_populated = ...
                report.epoch_association.family_members_populated + sum(~blank);
            if all(blank)
                % THE HOLE. min_count is satisfied, mustBeNonEmpty is false, the
                % armed gate keys on mustBeNonEmpty -- so this document reaches
                % no epoch and nothing else in the pipeline says so.
                report.epoch_association.family_docs_all_empty = ...
                    report.epoch_association.family_docs_all_empty + 1;
                key = sprintf('%s|%s', className, fam.name);
                [eaEmptyKeys, eaEmptyCounts] = bump(eaEmptyKeys, eaEmptyCounts, key);
                continue;
            end
            report.epoch_association.family_docs_populated = ...
                report.epoch_association.family_docs_populated + 1;

            % (3) the chain, end to end, from the POPULATED members only.
            report.epoch_association.chain_docs_examined = ...
                report.epoch_association.chain_docs_examined + 1;
            reached = false; undetermined = false;
            live = memberVals(~blank);
            for m = 1:numel(live)
                report.epoch_association.chain_members_examined = ...
                    report.epoch_association.chain_members_examined + 1;
                [state, terminus] = eaMemberOutcome(live{m}, idIndex, cache, ...
                    eaClassMemo, eaWalkMemo);
                fieldName = ['chain_member_' state];
                if isfield(report.epoch_association, fieldName)
                    report.epoch_association.(fieldName) = ...
                        report.epoch_association.(fieldName) + 1;
                else
                    % An outcome the report has no counter for would vanish and
                    % break the exhaustiveness the test locks. Count it visibly.
                    report.epoch_association.chain_member_unclassified = ...
                        report.epoch_association.chain_member_unclassified + 1;
                end
                switch state
                    case 'reaches_epoch'
                        reached = true;
                    case 'reaches_other'
                        if ~isempty(terminus)
                            [eaTermKeys, eaTermCounts] = bump(eaTermKeys, ...
                                eaTermCounts, sanitise(terminus));
                        end
                    case {'unresolved', 'incomplete', 'depth_exceeded'}
                        undetermined = true;
                end
            end
            if reached
                report.epoch_association.chain_docs_reaching_epoch = ...
                    report.epoch_association.chain_docs_reaching_epoch + 1;
            elseif undetermined
                % NOT MEASURED, not a failure: the batch is a sample and the
                % rest of the chain may be outside it.
                report.epoch_association.chain_docs_undetermined = ...
                    report.epoch_association.chain_docs_undetermined + 1;
            else
                report.epoch_association.chain_docs_reaching_no_epoch = ...
                    report.epoch_association.chain_docs_reaching_no_epoch + 1;
            end
        end

        % (2) `epoch_id` edges -- checked BY NAME, which is what the epoch plan
        % asked for. Three DISTINCT states; conflating them is an error this
        % project has made before.
        if info.declares_epoch_id
            report.epoch_association.epoch_id_docs_declaring = ...
                report.epoch_association.epoch_id_docs_declaring + 1;
        end
        epochEdges = edgeValues(body, eaEpochEdge());
        for e = 1:numel(epochEdges)
            report.epoch_association.epoch_id_edges_present = ...
                report.epoch_association.epoch_id_edges_present + 1;
            v = epochEdges{e};
            if isempty(v)
                state = 'empty';
                report.epoch_association.epoch_id_empty = ...
                    report.epoch_association.epoch_id_empty + 1;
            elseif ~idIndex.isKey(v)
                state = 'unresolved_in_batch';
                report.epoch_association.epoch_id_unresolved_in_batch = ...
                    report.epoch_association.epoch_id_unresolved_in_batch + 1;
            else
                state = 'resolved';
                report.epoch_association.epoch_id_resolved = ...
                    report.epoch_association.epoch_id_resolved + 1;
                targetInfo = eaClassInfo(cache, classNameOf(idIndex(v)), eaClassMemo);
                if ~targetInfo.is_terminal
                    state = 'resolved_not_epoch';
                    report.epoch_association.epoch_id_resolved_not_epoch = ...
                        report.epoch_association.epoch_id_resolved_not_epoch + 1;
                end
            end
            [eaEdgeKeys, eaEdgeCounts] = bump(eaEdgeKeys, eaEdgeCounts, ...
                sprintf('%s|%s', className, state));
        end

        % --- 2. required fields whose value is vacuous -------------------
        tagged = cache.fieldsFor(className);
        for f = 1:numel(tagged)
            fd = tagged(f).fieldDef;
            if ~isstruct(fd) || ~isfield(fd, 'name') || ~isfield(fd, 'mustBeNonEmpty')
                continue;
            end
            if ~logical(fd.mustBeNonEmpty); continue; end
            fname = char(fd.name);
            % look for the field in whichever block hosts it -- placement
            % rules mean it is not always the declaring class's block
            blocks = fieldnames(body);
            for b = 1:numel(blocks)
                bn = blocks{b};
                if any(strcmp(bn, {'document_class', 'depends_on', 'file', 'files'}))
                    continue;
                end
                blk = body.(bn);
                if ~isstruct(blk) || ~isscalar(blk) || ~isfield(blk, fname)
                    continue;
                end
                if isVacuous(blk.(fname))
                    key = sprintf('%s|%s|%s', className, bn, fname);
                    [fldKeys, fldCounts] = bump(fldKeys, fldCounts, key);
                end
            end
        end
    catch
        report.skipped_docs = report.skipped_docs + 1;
    end
end

report.empty_required_dependency = explode(depKeys, depCounts, ...
    {'class_name', 'edge_name'});
report.vacuous_required_field = explode(fldKeys, fldCounts, ...
    {'class_name', 'block', 'field_name'});
% #63. THE BUG THIS LINE PAIR FIXES: famKeys/famCounts were accumulated in the
% loop and then never assigned, so the counter measured correctly and threw the
% answer away -- the report read `family_violation_count: 0` on a document the
% detector had just flagged. It is the silentLoss failure mode one level up: a
% zero that means "not reported", not "nothing wrong". Two CI rounds and a
% revert were spent on the detector before a probe printed the report itself.
report.family_count_violation = explode(famKeys, famCounts, ...
    {'class_name', 'edge_name', 'declared', 'found'});
% #52, assigned in the SAME place and for the same reason the line above exists:
% a counter that accumulates and never assigns reports a zero that means "not
% reported". That bug has been shipped once in this file already.
report.family_uniqueness_violation = explode(uniKeys, uniCounts, ...
    {'class_name', 'edge_name', 'unique_by', 'key'});
report.empty_dependency_count = sum(depCounts);
report.vacuous_field_count = sum(fldCounts);
report.family_violation_count = sum(famCounts);
report.family_uniqueness_violation_count = sum(uniCounts);
report.uniqueness_denominator.families_declared = numel(uniqueFamilySeen);
% #72, assigned HERE and for the third time for the same reason: an accumulator
% that is never assigned reports a zero meaning "not reported". That bug has
% shipped in this file once already (famKeys), and each of these three lines
% has its own test asserting a non-zero row arrives in the report.
report.epoch_association.family_all_empty_by_class = ...
    explode(eaEmptyKeys, eaEmptyCounts, {'class_name', 'edge_name'});
report.epoch_association.epoch_id_by_class = ...
    explode(eaEdgeKeys, eaEdgeCounts, {'class_name', 'state'});
report.epoch_association.chain_terminus_by_class = ...
    explode(eaTermKeys, eaTermCounts, {'class_name'});
% The NDI-required block, assigned HERE and for the fourth time for the same
% reason: an accumulator that is never assigned reports a zero meaning "not
% reported". Note the count is taken from the SAME accumulator as the rows, and
% `edges_empty` in the denominator is incremented on the same branch -- so the
% headline number, the row table and the denominator cannot drift apart without
% a test noticing.
report.ndi_required_dependency = explode(nrKeys, nrCounts, ...
    {'class_name', 'edge_name'});
report.ndi_required_dependency_count = sum(nrCounts);
% `.Count` is uint64; every other counter in this report is a double, and a
% mixed-type struct encodes inconsistently. Cast at the boundary.
report.ndi_required_denominator.classes_carrying_the_marker = double(nrSeenClasses.Count);
report.ndi_required_denominator.relaxed_classes = double(nrSeenRelaxed.Count);
report.ndi_required_denominator.relaxed_edges_declared = double(nrSeenEdges.Count);
% THE IDENTITIES, beside the counts that were already here. Until this line the
% two maps above were built over the whole batch and then reduced to `.Count`,
% so a six-corpus run could report "7 of the schema's divergences were seen"
% and NOTHING ANYWHERE said WHICH SEVEN -- the keys existed in memory for the
% length of the run and were dropped at the end, recoverable from no log and no
% artifact. That made the complement, the divergences no corpus exercises,
% unnameable: the only thing derivable from two integers is that a class with
% more than one divergent edge must be among them, which is inference, not
% measurement.
%
% THE COUNTS ARE UNCHANGED AND KEEP THEIR MEANING. Prior corpus reports carry
% them and are compared against; these are ADDITIONAL fields, never a
% repurposing. `numel(names) == count` is therefore an invariant, and the digest
% checks it rather than assuming it.
report.ndi_required_denominator.relaxed_class_names = nrClassNames(nrSeenRelaxed);
report.ndi_required_denominator.relaxed_edge_names  = nrPairNames(nrSeenEdges);
end

% ===================== helpers =========================================

function cn = classNameOf(body)
cn = '';
if isfield(body, 'document_class') && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    cn = char(body.document_class.class_name);
end
end

function fams = declaredFamilies(cache, className)
%DECLAREDFAMILIES #63/#52: numbered edge families in the class chain, with the
%   instance counts they declare. A family entry is `name_#`; `min_count` /
%   `max_count` say how many concrete instances a valid document carries.
%   `mustBeNonEmpty` is NOT consulted -- it cannot describe a family, which is
%   the whole reason these fields exist.
%
%   #52 adds `unique_by`, read from the schema key `referent_unique_by`: a
%   dotted path evaluated ON THE REFERENCED document that no two members of the
%   family may agree on. '' when the family declares none, which is most of
%   them -- `derived_from_#` members are N different inputs and no uniqueness
%   rule has been decided for them. NOTHING HERE KNOWS THE WORD
%   `time_reference`: the rule is data in the schema, exactly as min_count is,
%   so a fourth family acquires it by being declared and not by being special-
%   cased here.
%
%   #72 adds `refers_to`, read from `must_refer_to_document_class`. It is how
%   the epoch-association block picks out the TIME REFERENCE families without
%   knowing the string "time_reference_#" either: a family qualifies when the
%   class it refers to has `time_reference` in its chain. `epoch`'s family
%   refers to `relative_reference`, a subclass, and qualifies for that reason
%   rather than by being listed anywhere.
fams = struct('name', {}, 'min_count', {}, 'max_count', {}, 'unique_by', {}, ...
    'refers_to', {});
try
    chain = cache.classChain(className);
catch
    return;
end
for k = 1:numel(chain)
    try
        c = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isfield(c, 'depends_on'); continue; end
    % jsondecode returns a CELL when the dependency objects in one class do not all
    % carry the same keys -- which is normal now that only NUMBERED families declare
    % min_count/max_count. `[deps{:}]` throws on mismatched fieldnames, and the throw
    % was swallowed by the caller's try/catch, so the census went quiet exactly where
    % it should have spoken. Iterate element-wise, as requiredDependencies does.
    deps = c.depends_on;
    if isstruct(deps)
        items = num2cell(deps(:)');
    elseif iscell(deps)
        items = deps(:)';
    else
        continue;
    end
    for d = 1:numel(items)
        dep = items{d};
        if ~isstruct(dep) || ~isfield(dep, 'name'); continue; end
        n = char(dep.name);
        if ~contains(n, '#'); continue; end
        lo = 0; hi = NaN; uq = ''; rt = '';
        if isfield(dep, 'min_count') && ~isempty(dep.min_count); lo = double(dep.min_count); end
        if isfield(dep, 'max_count') && ~isempty(dep.max_count); hi = double(dep.max_count); end
        if isfield(dep, 'referent_unique_by') && ~isempty(dep.referent_unique_by)
            uq = char(dep.referent_unique_by);
        end
        if isfield(dep, 'must_refer_to_document_class') && ...
                ~isempty(dep.must_refer_to_document_class)
            rt = char(dep.must_refer_to_document_class);
        end
        if any(strcmp({fams.name}, n)); continue; end
        fams(end+1) = struct('name', n, 'min_count', lo, 'max_count', hi, ...
            'unique_by', uq, 'refers_to', rt); %#ok<AGROW>
    end
end
end

function ids = familyMemberIds(body, famName)
%FAMILYMEMBERIDS #52: the referent ids of `prefix_#`, in the order the document
%   carries them. Members with a BLANK id are dropped: an edge naming no
%   document cannot be compared with anything, and the empty-edge census
%   already counts it. Tolerant of all three id spellings the pipeline uses at
%   different stages, exactly as edgeIsPopulated is.
%
%   #72 needs the SAME members INCLUDING the blank ones -- a family whose every
%   member is blank is the hole it measures -- so the parsing lives once, in
%   familyMemberValues, and this is the non-blank subset of it. Two copies of a
%   depends_on parser is two chances to re-introduce the shape bug that made
%   edgeIsPopulated answer "not populated" for every edge of a cell-valued
%   depends_on without looking at one of them.
ids = familyMemberValues(body, famName);
if isempty(ids); return; end
ids = ids(~cellfun(@isempty, ids));
end

function vals = familyMemberValues(body, famName)
%FAMILYMEMBERVALUES Every concrete member of `prefix_#`, in document order,
%   with '' for a member that is PRESENT AND BLANK.
%
%   The distinction is the whole point of #72: `time_reference_1 = ''` is a
%   member (it satisfies `min_count: 1`) that names no document. countFamily
%   sees it and deliberately does not care what it holds; familyMemberIds drops
%   it; the empty-edge census excludes numbered families by construction. So
%   before this function nothing in the pipeline could tell "one anchor" from
%   "one blank where an anchor goes".
vals = {};
if ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
prefix = strrep(famName, '#', '');
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name'); continue; end
    nm = char(d.name);
    if ~startsWith(nm, prefix); continue; end
    tail = nm(numel(prefix)+1:end);
    if isempty(tail) || ~all(isstrprop(tail, 'digit')); continue; end
    vals{end+1} = depValue(d); %#ok<AGROW>
end
end

function vals = edgeValues(body, name)
%EDGEVALUES Every value carried under exactly NAME, '' for a present-but-blank
%   edge. The un-numbered sibling of familyMemberValues, and the function that
%   makes "checked `epoch_id` BY NAME" true rather than asserted: it reports
%   the edge as present-and-blank instead of skipping it, so an empty edge and
%   an absent edge are different output.
vals = {};
if ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    vals{end+1} = depValue(d); %#ok<AGROW>
end
end

function v = depValue(d)
%DEPVALUE The referent id of one depends_on entry, or '' when it names nothing.
%   Tolerant of all three id spellings the pipeline uses at different stages
%   (`value`, `document_id`, raw v1 `id`) -- the same tolerance
%   edgeIsPopulated applies, expressed once.
v = '';
if ~isstruct(d); return; end
for key = {'value', 'document_id', 'id'}
    if isfield(d, key{1}) && ~isempty(d.(key{1}))
        v = char(d.(key{1})); return;
    end
end
end

function [key, how] = referentKey(referent, dottedPath)
%REFERENTKEY #52: the comparison key for one family member, read from the
%   REFERENCED document at DOTTEDPATH ('value.clock').
%
%   WHAT WE COMPARE ON TODAY, AND WHY IT IS NOT THE CURIE. `value.clock` is an
%   `ontology_term` {node, name} and its terms are STAGED WITH EMPTY NODES --
%   the NDIC clocktype identifiers are #67 and the authority is in no repository
%   in scope (NDIC.txt was removed from NDI-matlab in 2c19bf24c). So:
%
%       node non-empty   -> key on the CURIE      how = 'node'
%       node empty       -> key on the LABEL      how = 'name'
%       both blank/absent-> NO KEY, not compared  how = ''
%
%   The two are counted separately in uniqueness_denominator so the transition
%   is visible in the report rather than inferred. WHEN #67 MINTS THE TERMS the
%   keys move from label to CURIE on their own, and the one thing to watch is a
%   MIXED family -- one member minted, one not -- which would key the same clock
%   two ways and read as unique. That is a report to look for, not a silent
%   improvement; it is why `members_keyed_by_name` is printed even at zero.
%
%   Falls back to the whole value when the path does not land on a {node,name}
%   cell, so the mechanism is not specific to ontology terms.
key = ''; how = '';
v = pathValue(referent, dottedPath);
if isempty(v); return; end
if isstruct(v) && isscalar(v)
    if isfield(v, 'node') && ischar(v.node) && ~isempty(strtrim(v.node))
        key = ['node:' lower(strtrim(v.node))]; how = 'node'; return;
    end
    if isfield(v, 'name') && ischar(v.name) && ~isempty(strtrim(v.name))
        key = ['name:' lower(strtrim(v.name))]; how = 'name'; return;
    end
    return;   % an all-blank ontology_term -- nothing to compare
end
if ischar(v) && ~isempty(strtrim(v))
    key = ['name:' lower(strtrim(v))]; how = 'name'; return;
end
if isnumeric(v) && isscalar(v) && isfinite(v)
    key = ['name:' num2str(v)]; how = 'name'; return;
end
end

function v = pathValue(body, dottedPath)
%PATHVALUE Resolve a dotted path against a document body, searching the
%   PROPERTY BLOCKS for the first segment.
%
%   The first segment is a FIELD name ('value'), not a block name, because that
%   is what a schema declares. Which block hosts it depends on `placement` and
%   on which class in the chain declared it, so the block is searched for rather
%   than assumed -- the same approach the vacuous-field loop above takes, and
%   for the same reason: assuming the declaring class's block is how a field
%   goes unread.
v = [];
if ~isstruct(body) || ~isscalar(body); return; end
parts = strsplit(char(dottedPath), '.');
if isempty(parts); return; end
blocks = fieldnames(body);
for b = 1:numel(blocks)
    bn = blocks{b};
    if any(strcmp(bn, {'document_class', 'depends_on', 'file', 'files'}))
        continue;
    end
    blk = body.(bn);
    if ~isstruct(blk) || ~isscalar(blk) || ~isfield(blk, parts{1}); continue; end
    cur = blk.(parts{1});
    ok = true;
    for p = 2:numel(parts)
        if isstruct(cur) && isscalar(cur) && isfield(cur, parts{p})
            cur = cur.(parts{p});
        else
            ok = false; break;
        end
    end
    if ok
        v = cur;
        return;
    end
end
end

function id = bodyId(body)
%BODYID The document's own id, or '' -- the key the batch index is built on.
id = '';
if isstruct(body) && isscalar(body) && isfield(body, 'base') ...
        && isstruct(body.base) && isscalar(body.base) && isfield(body.base, 'id')
    v = body.base.id;
    if ischar(v); id = v; elseif isstring(v) && isscalar(v); id = char(v); end
end
end

function s = sanitise(s)
%SANITISE `explode` splits report keys on '|', so a value carrying one would
%   silently shift every field after it. Replace rather than error: the audit
%   must never be able to break a migration.
s = strrep(char(s), '|', '/');
end

function n = countFamily(body, famName)
%COUNTFAMILY How many concrete instances of `prefix_#` the document carries.
%   Counts the EDGES PRESENT, whatever their value: a family violation is about
%   how many instances exist, not whether one of them is blank (that is the
%   separate, and separately reported, empty-edge check).
n = 0;
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on); return; end
prefix = strrep(famName, '#', '');
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if ~isfield(d, 'name'); continue; end
    nm = char(d.name);
    if ~startsWith(nm, prefix); continue; end
    tail = nm(numel(prefix)+1:end);
    if ~isempty(tail) && all(isstrprop(tail, 'digit')); n = n + 1; end
end
end

function s = describeRange(fam)
if isnan(fam.max_count)
    s = sprintf('min %d', fam.min_count);
else
    s = sprintf('min %d max %d', fam.min_count, fam.max_count);
end
end

function r = nrNewReport()
%NRNEWREPORT The NDI-required block's denominators, with every field present
%   from the start. The block is stamped even on the early returns, so a batch
%   that was never opened prints the same SHAPE with zeros and its own
%   `docs_inspected` beside them -- rather than a missing field the digest
%   would render as "(absent)" in one run and 0 in the next.
%
%   `marker_key` is DATA, not a comment. Everything else here is schema-driven;
%   that one string is not, so if DID-schema stops stamping it or renames it,
%   every count goes to zero and the report would read clean. Printing the
%   string it followed is what makes a query-shaped zero visible -- the
%   demo_ndi failure was a grep against a string the repository has never
%   contained, reported as "this does not exist anywhere".
r = struct( ...
    'docs_inspected',                0, ...
    'docs_unreadable',               0, ...
    'docs_unclassifiable',           0, ...
    'docs_classified',               0, ...
    'marker_key',                    nrMarkerKey(), ...
    'classes_carrying_the_marker',   0, ...
    'relaxed_classes',               0, ...
    'relaxed_edges_declared',        0, ...
    'relaxed_class_names',           {{}}, ...
    'relaxed_edge_names',            {{}}, ...
    'docs_declaring_a_relaxed_edge', 0, ...
    'edges_examined',                0, ...
    'edges_populated',               0, ...
    'edges_empty',                   0);
end

function names = nrClassNames(m)
%NRCLASSNAMES The class names a seen-set map accumulated, SORTED.
%   `keys` on a containers.Map is documented to return char keys in sorted
%   order, and this sorts anyway: two reports from the same corpus must diff
%   cleanly, and an order that happens to be stable is not the same promise as
%   an order that is made stable. A spurious diff in a names list would be read
%   as "the corpus changed".
%
%   Always a CELL, including when empty -- `jsonencode` writes a cell as a JSON
%   array either way, so the digest sees `[]` for "seen nothing" and a MISSING
%   key for "this report predates the export". Those are different facts and
%   the encoding keeps them apart.
%
%   ORIENTATION IS PINNED TO A 1xN ROW, AND NOT BY TRANSPOSING THE INPUT TO
%   `sort`. Code scanning alert 196 flagged `sort(names(:)')` here and was
%   RIGHT on the facts: `keys` on a containers.Map returns a 1xN row already,
%   so `names(:)'` round-tripped a row back into a row and did no work on any
%   input this function can receive. What the round-trip was really doing was
%   asserting a SHAPE, and that is worth keeping -- so `reshape` states it
%   outright rather than leaving a reader to infer it from a transpose.
%
%   WHY A ROW, RATHER THAN "either is fine". `nrPairNames` builds a 1xN row by
%   construction, so a column here would make the report's two identity lists
%   different shapes for no reason at all. And whether `jsonencode` flattens a
%   COLUMN cell to the same JSON array is NOT VERIFIED -- there is no MATLAB in
%   the authoring container, and the only consumer is
%   writeCorpusReport's `jsonencode` followed by a Python `isinstance(v, list)`
%   in tools/census_digest.py. So the shape is pinned rather than assumed
%   harmless. If a column ever did encode differently, the digest would not go
%   quiet about it: its reader counts non-string entries and reports
%   "N of M entries in `<field>` are not strings" as a list/count disagreement.
%   testTheIdentitiesAreExportedAsSortedRowCells holds the orientation with
%   `verifyEqual` against a row literal, which is size-strict.
names = keys(m);
if isempty(names)
    names = {};
    return;
end
names = reshape(sort(names(:)), 1, []);
end

function names = nrPairNames(m)
%NRPAIRNAMES The (class, edge) pairs a seen-set map accumulated, SORTED.
%   Keys are stored `class|edge` and are exported `class.edge`, which is the
%   spelling `ndi_required_dependency` rows are rendered in -- so the union of
%   what was SEEN and the rows that were EMPTY are directly comparable strings
%   rather than two formats a reader has to reconcile.
%
%   THE SORT HAPPENS AFTER THE REWRITE, NOT BEFORE, and the order genuinely
%   differs: '|' is 0x7C and '.' is 0x2E, so a class named `a` with edge `b`
%   sorts after `a_c` as `a|b` and before it as `a.b`. Sorting the stored form
%   would export a list that is not sorted in the form it is exported in, which
%   is the same defect as not sorting at all.
%
%   NO TRANSPOSE IS NEEDED HERE and none is present: the row is built by
%   construction (`cell(1, numel(raw))` filled by linear index), so this
%   function has no orientation dependence on what `keys` returns, and
%   `sort` on a 1xN row sorts along dimension 2 and returns a 1xN row. Same
%   pinned shape as nrClassNames, arrived at without the operator alert 196
%   flagged there.
raw = keys(m);
if isempty(raw)
    names = {};
    return;
end
names = cell(1, numel(raw));
for k = 1:numel(raw)
    names{k} = strrep(raw{k}, '|', '.');
end
names = sort(names);
end

function k = nrMarkerKey()
%NRMARKERKEY The schema key carrying NDI's own required-ness verdict.
%   Written by DID-schema tools/ndi_required_stamp.py at build time from NDI's
%   schema documents. Named in ONE place so the report and the reader cannot
%   disagree about what was followed.
k = 'ndi_mustBeNonEmpty';
end

% ===================== the edge-arity census (ungated) =====================

function r = arNewReport()
%ARNEWREPORT The edge-arity block, with every field present from the start.
%   Same contract as nrNewReport: a batch that was never opened prints the same
%   SHAPE with zeros beside its own `docs_inspected`, rather than a missing key
%   the digest renders as "(absent)" in one run and 0 in the next.
r = struct( ...
    'docs_inspected',            0, ...
    'docs_unreadable',           0, ...
    'docs_unclassifiable',       0, ...
    'docs_classified',           0, ...
    'docs_errored',              0, ...
    'docs_with_depends_on',      0, ...
    'docs_with_indexed_edge',    0, ...
    'docs_with_plural_family',   0, ...
    'edges_examined',            0, ...
    'edges_unnamed',             0, ...
    'indexed_edges_examined',    0, ...
    'pairs_examined',            0, ...
    'pairs_plural',              0, ...
    'families_seen',             0, ...
    'plural_families_seen',      0, ...
    'max_arity_seen',            0, ...
    'arity_distribution',        struct('class_name', {}, 'edge_name', {}, ...
                                        'arity', {}, 'count', {}), ...
    'plural_by_family',          struct('class_name', {}, 'edge_name', {}, ...
                                        'max_arity', {}, 'count', {}));
end

function r = arityCensus(bodies, r)
%ARITYCENSUS How many members of each edge family each document carries.
%
%   THE ONE THING THIS FUNCTION MUST NOT DO IS CONSULT A SCHEMA. Every existing
%   arity-shaped counter in this pipeline is gated on a declaration --
%   `referent_unique_by` for #52, `min_count`/`max_count` for #63,
%   `mustBeNonEmpty` for the empty-edge census -- and a gated counter reports 0
%   for every family nobody declared anything about. `document_id` is such a
%   family, which is why "how many documents carry a plural document_id" had no
%   answer. So the input here is the BODY, and a family exists because a
%   document carries one.
%
%   Nothing is raised, nothing is skipped silently, and a document that throws
%   is counted where it throws -- see the catch below.
if isempty(bodies); return; end

% class|family -> documents at that arity bucket, and the two sparse
% side-tables. containers.Map rather than the `bump` cell scan used elsewhere in
% this file: `bump` is O(#keys) per call and fires only on violations, whereas
% this fires on EVERY document, and a report-only counter must not make a
% 633,432-document corpus job measurably slower.
arDocs      = containers.Map('KeyType', 'char', 'ValueType', 'double');
arPlural    = containers.Map('KeyType', 'char', 'ValueType', 'double');
arMax       = containers.Map('KeyType', 'char', 'ValueType', 'double');
arFamilies  = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for k = 1:numel(bodies)
    % Set the moment `docs_classified` is incremented, and read only by the
    % catch. WITHOUT IT THE PARTITION IS NOT A PARTITION: a document that
    % classified and then threw would land in `docs_classified` AND in the
    % catch's counter, and the three states would sum to MORE than the
    % denominator -- an over-count reading as more coverage than there is,
    % which is this project's characteristic error.
    classified = false;
    try
        body = bodies{k};
        className = classNameOf(body);
        if isempty(className)
            % PARSED, and there is nothing to attribute its edges to. Named
            % rather than left as a residual, so
            %   unreadable + unclassifiable + classified == inspected
            % holds exactly, which is the only way a zero further down can be
            % read in context.
            r.docs_unclassifiable = r.docs_unclassifiable + 1;
            continue;
        end
        r.docs_classified = r.docs_classified + 1;
        classified = true;

        [names, nUnnamed] = dependencyNames(body);
        r.edges_examined = r.edges_examined + numel(names) + nUnnamed;
        r.edges_unnamed  = r.edges_unnamed + nUnnamed;
        if isempty(names); continue; end
        r.docs_with_depends_on = r.docs_with_depends_on + 1;

        % Tally this document's families. A per-document cell scan, not a Map:
        % a document carries a handful of edges, and constructing a Map per
        % document over 633k documents costs more than the scan it replaces.
        famNames = {}; famCounts = [];
        sawIndexed = false;
        for e = 1:numel(names)
            [fam, indexed] = arityFamily(names{e});
            if indexed
                sawIndexed = true;
                r.indexed_edges_examined = r.indexed_edges_examined + 1;
            end
            idx = find(strcmp(famNames, fam), 1);
            if isempty(idx)
                famNames{end+1} = fam; %#ok<AGROW>
                famCounts(end+1) = 1;  %#ok<AGROW>
            else
                famCounts(idx) = famCounts(idx) + 1;
            end
        end
        if sawIndexed
            r.docs_with_indexed_edge = r.docs_with_indexed_edge + 1;
        end

        docPlural = false;
        for e = 1:numel(famNames)
            n = famCounts(e);
            r.pairs_examined = r.pairs_examined + 1;
            key = sprintf('%s|%s', sanitise(className), sanitise(famNames{e}));
            % A SET, not a counter: `families_seen` is how many distinct
            % (class, family) pairs exist, and it is the denominator that says
            % whether `plural_families_seen` being small is a finding or a
            % property of a batch that carries almost no edges.
            arFamilies(key) = true;
            if n > r.max_arity_seen; r.max_arity_seen = n; end
            bucket = arityBucket(n);
            bkey = [key '|' bucket];
            if arDocs.isKey(bkey)
                arDocs(bkey) = arDocs(bkey) + 1;
            else
                arDocs(bkey) = 1;
            end
            if n > 1
                docPlural = true;
                r.pairs_plural = r.pairs_plural + 1;
                if arPlural.isKey(key)
                    arPlural(key) = arPlural(key) + 1;
                else
                    arPlural(key) = 1;
                end
                % Only recorded for families that are EVER plural: max_arity is
                % 1 by construction for the rest, and touching the map on the
                % common path is the cost that matters at corpus scale.
                if ~arMax.isKey(key) || n > arMax(key)
                    arMax(key) = n;
                end
            end
        end
        if docPlural
            r.docs_with_plural_family = r.docs_with_plural_family + 1;
        end
    catch
        % `docs_errored` OVERLAPS the three partition states on purpose and is
        % NOT one of them: a document that classified and then threw stays in
        % `docs_classified`, exactly as the NDI-required block documents
        % ("classified is NOT a claim that every later check completed"). A
        % document that threw BEFORE it could be classified has reached no
        % partition state at all, so it takes the unclassifiable slot -- which
        % is what keeps
        %     unreadable + unclassifiable + classified == inspected
        % exact rather than approximately true.
        r.docs_errored = r.docs_errored + 1;
        if ~classified
            r.docs_unclassifiable = r.docs_unclassifiable + 1;
        end
    end
end

r.families_seen = double(arFamilies.Count);
r.plural_families_seen = double(arPlural.Count);
% ASSIGNED HERE, and this file has shipped an accumulator that was never
% assigned once already (#63's famKeys): the report read 0 on a document the
% detector had just flagged. Each assignment below has its own test.
[dk, dc] = mapEntries(arDocs);
r.arity_distribution = explode(dk, dc, {'class_name', 'edge_name', 'arity'});
r.plural_by_family = arPluralRows(arPlural, arMax);
end

function b = arityBucket(n)
%ARITYBUCKET The three buckets, named in ONE place so the counter and the
%   digest cannot disagree about what '3+' means.
if n <= 1
    b = '1';
elseif n == 2
    b = '2';
else
    b = '3+';
end
end

function [names, nUnnamed] = dependencyNames(body)
%DEPENDENCYNAMES Every `depends_on` entry name, in document order.
%
%   NUNNAMED counts the entries that carried no usable `name`. They are dropped
%   from the tally -- there is no family to attribute them to -- and a drop that
%   is not counted is how a denominator quietly stops describing the batch.
%
%   Tolerant of the struct-array AND cell forms of `depends_on`, like
%   familyMemberValues and edgeValues: jsondecode returns a CELL whenever the
%   entries do not all carry the same keys, and a struct-only reader answers
%   "no edges" for every one of those documents without looking at one.
names = {}; nUnnamed = 0;
if ~isstruct(body) || ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
names = cell(1, numel(items));
keep = false(1, numel(items));
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isscalar(d) || ~isfield(d, 'name')
        nUnnamed = nUnnamed + 1; continue;
    end
    nm = d.name;
    if isstring(nm) && isscalar(nm); nm = char(nm); end
    if ~ischar(nm) || isempty(nm)
        nUnnamed = nUnnamed + 1; continue;
    end
    names{k} = nm; keep(k) = true;
end
names = names(keep);
end

function [fam, indexed] = arityFamily(name)
%ARITYFAMILY The family an edge name belongs to, and whether it carried an index.
%
%   `document_id_2` -> ('document_id', true)
%   `document_id`   -> ('document_id', false)
%   `subject_id`    -> ('subject_id',  false)   -- `id` is not a digit run
%
%   THE BARE AND INDEXED SPELLINGS FOLD INTO ONE FAMILY, and that is the single
%   most important line in this census. NDI's writer chooses the spelling by
%   arity (tableDocMaker.m:289 vs :291 -- `set_dependency_value` for one
%   referent, `add_dependency_value_n` for several, and the latter writes
%   `<name>_1`, `<name>_2`). So the singular documents are spelled `document_id`
%   and only the plural ones are spelled `document_id_<n>`. Keying on the
%   indexed spelling alone would report every plural row with a ZERO singular
%   row beside it -- a numerator whose denominator had been defined away. The
%   one real consumer of the idiom folds them the same way, by regex
%   `^<name>(_\d+)?$` (NDI imagedEntitySubjects/dependencyValuesMatching).
%
%   THE COST OF THE FOLD, stated rather than hidden: an edge whose name simply
%   ends in `_<digits>` and is not a family member is folded with a family that
%   may not exist. Nothing in the built schema is spelled that way today, and
%   the alternative -- reading the schema to find out -- is the gating this
%   whole block exists to avoid.
fam = char(name); indexed = false;
u = find(fam == '_', 1, 'last');
if isempty(u) || u == numel(fam); return; end
tail = fam(u+1:end);
if ~all(isstrprop(tail, 'digit')); return; end
fam = fam(1:u-1);
indexed = true;
end

function [ks, vs] = mapEntries(m)
%MAPENTRIES A containers.Map as the (keys, counts) pair `explode` consumes.
%   `values` returns a cell; unwrapping it element-wise rather than with
%   cell2mat keeps the pairing with `keys` explicit and survives an empty map.
ks = keys(m);
vs = zeros(1, numel(ks));
if isempty(ks); ks = {}; return; end
raw = values(m);
for k = 1:numel(raw); vs(k) = raw{k}; end
end

function rows = arPluralRows(pluralMap, maxMap)
%ARPLURALROWS One row per family EVER seen plural: how many documents carried
%   more than one member, and the largest arity any of them reached.
%
%   Built by hand rather than through `explode` because `max_arity` is a MAXIMUM
%   and `explode` renders accumulated SUMS -- feeding a max through a counter
%   that adds is how a summary starts reporting a number nothing measured.
%   Sorted by document count descending, then by name, so two reports from the
%   same corpus diff cleanly.
rows = struct('class_name', {}, 'edge_name', {}, 'max_arity', {}, 'count', {});
ks = keys(pluralMap);
if isempty(ks); return; end
counts = zeros(1, numel(ks));
raw = values(pluralMap);
for k = 1:numel(raw); counts(k) = raw{k}; end
[~, order] = sort(counts, 'descend');
ks = ks(order); counts = counts(order);
for k = 1:numel(ks)
    parts = strsplit(ks{k}, '|');
    entry = struct();
    entry.class_name = parts{1};
    if numel(parts) > 1; entry.edge_name = parts{2}; else; entry.edge_name = ''; end
    if maxMap.isKey(ks{k}); entry.max_arity = maxMap(ks{k}); else; entry.max_arity = 0; end
    entry.count = counts(k);
    rows(end+1) = entry; %#ok<AGROW>
end
end

% ===================== end of the edge-arity census ========================

function info = relaxedDependencies(cache, className, memo)
%RELAXEDDEPENDENCIES Edges NDI declares REQUIRED that V_eta declares OPTIONAL.
%
%   INFO.names           the edge names, over the whole class chain
%   INFO.marker_present  true when ANY dependency in the chain carries the
%                        marker at all, either value. This is the difference
%                        between "V_eta relaxed nothing NDI requires" and "the
%                        schema was never stamped", and without it those two
%                        print as the same zero.
%
%   THE TEST IS A CONJUNCTION AND BOTH HALVES MATTER:
%       ndi_mustBeNonEmpty == true   AND   mustBeNonEmpty is absent or false
%   Dropping the second half would put every agreeing edge in this bucket as
%   well as in the real required-edge bucket, and the two are DIFFERENT FACTS
%   that must never be summed -- see the block comment at the top of the file.
%
%   ABSENCE OF THE MARKER IS NOT `false`. It means NDI stated nothing: the
%   class has no did_v1 source, or its NDI schema document is in the JSON
%   Schema form (which carries no `mustbenotempty` anywhere), or V_eta renamed
%   the edge. Treating absence as a verdict would manufacture agreement out of
%   silence, so an unmarked edge is simply not in this census -- and the
%   denominators say how many were unmarked.
%
%   NUMBERED FAMILIES ARE EXCLUDED, the same rule requiredDependencies applies
%   and for the same reason: a MISSING instance of a family is not a blank one.
%   Keeping the two rules identical is what lets the two buckets be compared.
if memo.isKey(className)
    info = memo(className);
    return;
end
info = struct('names', {{}}, 'marker_present', false);
marker = nrMarkerKey();
try
    chain = cache.classChain(className);
catch
    % DO NOT DELETE THIS LINE TO SILENCE THE ANALYSER -- same reason as the
    % note on the function's last line. `memo` is a containers.Map, a HANDLE
    % class, so this records the failure in the CALLER's map. Without it a
    % class whose chain lookup throws is re-attempted on every document.
    memo(className) = info;
    return;
end
for k = 1:numel(chain)
    try
        s = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isfield(s, 'depends_on'); continue; end
    deps = s.depends_on;
    % jsondecode returns a CELL when the dependency objects in one class do not
    % all carry the same keys -- which this marker makes MORE common, not less,
    % because it is stamped on some entries of a class and not others. Iterate
    % element-wise; `[deps{:}]` throws on mismatched fieldnames, and that throw
    % would be swallowed by the caller's try/catch, silencing the census
    % exactly where it should speak.
    if isstruct(deps)
        items = num2cell(deps(:)');
    elseif iscell(deps)
        items = deps(:)';
    else
        continue;
    end
    for d = 1:numel(items)
        dep = items{d};
        if ~isstruct(dep) || ~isfield(dep, 'name'); continue; end
        if ~isfield(dep, marker); continue; end
        info.marker_present = true;
        if ~logical(dep.(marker)); continue; end          % NDI says optional
        if isfield(dep, 'mustBeNonEmpty') && logical(dep.mustBeNonEmpty)
            continue;                                     % we agree: other bucket
        end
        n = char(dep.name);
        if contains(n, '#'); continue; end
        if ~any(strcmp(info.names, n)); info.names{end+1} = n; end
    end
end
% DO NOT DELETE THIS LINE TO SILENCE THE ANALYSER -- see the identical note on
% eaClassInfo's memo below. `memo` is a containers.Map, a HANDLE class, so this
% mutates the map the caller created and passed in. The analyser calls the
% local name unused because the effect is on the shared object.
memo(className) = info;
end

function names = requiredDependencies(cache, className)
%REQUIREDDEPENDENCIES Names of depends_on entries declared mustBeNonEmpty
%   anywhere in the class chain. Numbered edges (`derived_from_#`,
%   `time_reference_#`) are template names, not concrete edges, so they are
%   excluded -- a missing instance of one is not the same as a blank one.
names = {};
chain = cache.classChain(className);
for k = 1:numel(chain)
    try
        s = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isfield(s, 'depends_on'); continue; end
    deps = s.depends_on;
    if isstruct(deps)
        for d = 1:numel(deps)
            names = addRequired(names, deps(d));
        end
    elseif iscell(deps)
        for d = 1:numel(deps)
            names = addRequired(names, deps{d});
        end
    end
end
end

function names = addRequired(names, dep)
if ~isstruct(dep) || ~isfield(dep, 'name') || ~isfield(dep, 'mustBeNonEmpty')
    return;
end
if ~logical(dep.mustBeNonEmpty); return; end
n = char(dep.name);
if contains(n, '#'); return; end
if ~any(strcmp(names, n)); names{end+1} = n; end
end

function tf = edgeIsPopulated(body, name)
%EDGEISPOPULATED True when the body carries NAME with a non-empty value.
%   Tolerant of all three key spellings the pipeline uses at different
%   stages (`value`, `document_id`, raw v1 `id`) AND of both SHAPES a
%   body's `depends_on` takes.
%
%   THE SHAPE HALF WAS MISSING, and it broke the census/gate lock. This
%   function read `if ~isstruct(deps); return; end`, so a CELL-valued
%   `depends_on` made it answer "not populated" for EVERY edge without
%   looking at one of them -- while did2.schema.cache/edgeIsPopulated, the
%   gate's copy of this same rule, iterates the cell and answers correctly.
%   The census would then report empty edges the gate would not raise on,
%   which is the precise failure the two lock tests exist to prevent: the
%   number the team arms DID_ENFORCE_REQUIRED_DEPENDENCIES on stops
%   describing what enforcement would cost.
%
%   THE CELL SHAPE IS NOT HYPOTHETICAL, and it is not a schema-only shape.
%   jsondecode returns a CELL whenever the dependency objects in one array
%   do not all carry the same keys -- which is exactly what a body carrying
%   a mix of `document_id` and the raw v1 `id` spelling decodes to, i.e.
%   the same mid-migration mixture the key tolerance above exists for.
%   Three other readers of a BODY's depends_on in this pipeline already
%   handle it: silentLoss/familyMemberIds (whose comment claims it is
%   tolerant "exactly as edgeIsPopulated is" -- it was not),
%   did2.convert.epochMint and migrators_j.epochfiles_ingested.
%
%   The error ran in the SAFE direction -- over-reporting empty edges makes
%   the repair look bigger, never done -- which is why it survived: nothing
%   about it looked like progress. It is still a corrupt denominator.
tf = false;
if ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'value', 'document_id', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            tf = true; return;
        end
    end
end
end

function tf = isVacuous(value)
%ISVACUOUS Present, but carrying nothing -- a struct whose every leaf is
%   blank, recursively. This is the case did2.schema.cache/isEmptyValue
%   misses: it calls a struct empty only when it has NO FIELDNAMES, so an
%   all-blank ontology_term {node:'', name:''} passes a required check.
%
%   A plain empty value ('' or []) is NOT reported here -- the existing
%   validator already catches those, so counting them would drown the
%   signal we are actually after.
tf = false;
if ~isstruct(value) || isempty(value); return; end
fn = fieldnames(value);
if isempty(fn); return; end   % genuinely empty -- the validator sees this
for k = 1:numel(value)
    for f = 1:numel(fn)
        v = value(k).(fn{f});
        if isstruct(v)
            if ~isVacuous(v) && ~(isempty(v) || isempty(fieldnames(v)))
                return;
            end
        elseif ~isempty(v)
            if islogical(v) || isnumeric(v)
                return;   % a real 0/false is a value, not a blank
            end
            if ischar(v) && ~isempty(strtrim(v)); return; end
            if isstring(v) && any(strlength(strtrim(v)) > 0); return; end
        end
    end
end
tf = true;
end

% ============ #72: the epoch association ================================
%
% THE FOUR NAMES THIS BLOCK CANNOT DERIVE FROM THE SCHEMA, and what protects
% them. Everything else here is schema-driven -- which families exist, what
% they refer to, which classes declare `epoch_id` -- but the chain itself is a
% MODEL DECISION, so the edge it hops over and the class it terminates at are
% written down. A hard-coded name is how a counter becomes a zero that is a
% property of the query (the demo_ndi failure: a grep for a string the
% repository has never contained, reported as "this does not exist anywhere").
%
% So each name is (a) reported as DATA in the report, and (b) accompanied by a
% flag saying whether a class of that name still loads from the schema. If
% `epoch` is renamed, `terminal_class_in_schema` goes to 0 and every
% reaches-an-epoch count is legible as vacuous instead of clean.
%
% Measured from the built schema on 2026-08-10, 245 schema files:
%   * 13 numbered edge families; 3 of them refer to a `time_reference` class
%     (subject_interaction, directed_relation -> time_reference; epoch ->
%     relative_reference, a subclass).
%   * `relative_to` is declared by relative_reference alone, mustBeNonEmpty
%     true, must_refer_to_document_class `base`.
%   * 4 classes declare an `epoch_id` edge: acquisition_metadata_file
%     (required), ingestion_manifest (required), directed_relation (optional),
%     method_parameters (optional).

function s = eaAnchorEdge()
%EAANCHOREDGE The edge a time reference uses to name what it is measured
%   against. `relative_reference.relative_to`.
s = 'relative_to';
end

function s = eaReferenceRoot()
%EAREFERENCEROOT The root class of the time-reference tier. A family is a TIME
%   reference family when the class it must refer to has this in its chain.
s = 'time_reference';
end

function s = eaTerminalClass()
%EATERMINALCLASS What the chain is being asked to reach.
s = 'epoch';
end

function s = eaEpochEdge()
%EAEPOCHEDGE The direct epoch edge, checked BY NAME as the epoch plan asks.
s = 'epoch_id';
end

function n = eaMaxDepth()
%EAMAXDEPTH Hops followed before a chain is reported as too long. Chains are
%   normal and well founded (observation -> stimulus -> epoch), so a chain
%   deeper than this is a finding, not a limit to raise quietly: it is counted
%   as `chain_member_depth_exceeded` rather than resolved either way.
n = 8;
end

function r = eaNewReport()
%EANEWREPORT The epoch-association block, every counter present at zero.
%
%   EVERY FIELD IS CREATED HERE, including the ones that will usually stay at
%   zero. A counter that springs into existence only when it fires cannot be
%   told from a counter that was never wired -- and this project has shipped
%   that reading twice (`0 empty edges` while reading nothing; the digest
%   repeating it). The digest prints every field it is given.
r = struct( ...
    ... denominators, first and unconditionally (rule 5)
    'docs_inspected',              0, ...
    'docs_unreadable',             0, ...
    'docs_classified',             0, ...
    ... the names followed, as data, plus whether they still exist
    'anchor_edge',                 eaAnchorEdge(), ...
    'reference_root',              eaReferenceRoot(), ...
    'terminal_class',              eaTerminalClass(), ...
    'max_depth',                   eaMaxDepth(), ...
    'terminal_class_in_schema',    0, ...
    'reference_root_in_schema',    0, ...
    ... (1) does the family reach anything at all
    'family_docs_declaring',       0, ...
    'family_docs_absent',          0, ...
    'family_docs_present',         0, ...
    'family_docs_all_empty',       0, ...
    'family_docs_populated',       0, ...
    'family_members_total',        0, ...
    'family_members_empty',        0, ...
    'family_members_populated',    0, ...
    'family_all_empty_by_class',   struct('class_name', {}, 'edge_name', {}, ...
                                          'count', {}), ...
    ... (2) epoch documents and epoch_id edges -- three DISTINCT states
    'epoch_documents',             0, ...
    'epoch_id_docs_declaring',     0, ...
    'epoch_id_edges_present',      0, ...
    'epoch_id_empty',              0, ...
    'epoch_id_resolved',           0, ...
    'epoch_id_resolved_not_epoch', 0, ...
    'epoch_id_unresolved_in_batch', 0, ...
    'epoch_id_by_class',           struct('class_name', {}, 'state', {}, ...
                                          'count', {}), ...
    ... (3) the chain, statement through to its epoch
    'chain_docs_examined',         0, ...
    'chain_docs_reaching_epoch',   0, ...
    'chain_docs_reaching_no_epoch', 0, ...
    'chain_docs_undetermined',     0, ...
    'chain_members_examined',      0, ...
    'chain_member_unresolved',     0, ...
    'chain_member_not_a_reference', 0, ...
    'chain_member_anchor_absent',  0, ...
    'chain_member_anchor_empty',   0, ...
    'chain_member_reaches_epoch',  0, ...
    'chain_member_reaches_other',  0, ...
    'chain_member_incomplete',     0, ...
    'chain_member_depth_exceeded', 0, ...
    'chain_member_unclassified',   0, ...
    'chain_terminus_by_class',     struct('class_name', {}, 'count', {}));
end

function tf = eaClassLoads(cache, className)
%EACLASSLOADS Does the schema still have a class by this name? The guard on
%   the four hard-coded names above.
tf = false;
try
    s = cache.getClass(className);
    tf = isstruct(s) && ~isempty(fieldnames(s));
catch
    tf = false;
end
end

function info = eaClassInfo(cache, className, memo)
%EACLASSINFO What the SCHEMA says about one class, memoised per class name.
%   `is_terminal` -- an epoch (or a subclass of one)
%   `is_reference` -- a time reference (or a subclass)
%   `declares_anchor` -- its chain declares `relative_to`
%   `declares_epoch_id` -- its chain declares `epoch_id`
%   `time_families` -- the names of its numbered families that refer to a time
%                      reference class. Decided from the schema's
%                      `must_refer_to_document_class` and NOT from the family's
%                      name: `epoch.time_reference_#` refers to
%                      `relative_reference` and qualifies because that class has
%                      `time_reference` in its chain. A fourth family would
%                      qualify by being declared, not by being listed here.
%
%   A class whose chain cannot be resolved returns all-false AND is memoised as
%   all-false, because retrying it per document is slow and gives the same
%   answer. The documents that produce it are already counted in `skipped_docs`
%   when the failure is total.
info = struct('is_terminal', false, 'is_reference', false, ...
              'declares_anchor', false, 'declares_epoch_id', false);
info.time_families = {};
if isempty(className); return; end
if memo.isKey(className)
    info = memo(className);
    return;
end
chain = {};
try
    chain = cache.classChain(className);
catch
    chain = {};
end
if ~isempty(chain)
    info.is_terminal  = any(strcmp(chain, eaTerminalClass()));
    info.is_reference = any(strcmp(chain, eaReferenceRoot()));
    info.declares_anchor   = eaChainDeclaresEdge(cache, chain, eaAnchorEdge());
    info.declares_epoch_id = eaChainDeclaresEdge(cache, chain, eaEpochEdge());
    fams = declaredFamilies(cache, className);
    for f = 1:numel(fams)
        if eaRefersToReference(cache, fams(f).refers_to)
            info.time_families{end+1} = fams(f).name;
        end
    end
end
% DO NOT DELETE THIS LINE TO SILENCE THE ANALYSER. `memo` is a containers.Map,
% which is a HANDLE class: this mutates the map the CALLER created (line 334)
% and passed in, so the memoisation is real. The analyser reports "value
% assigned might be unused" because the local name is not read again, which it
% is not -- the effect is on the shared object. Deleting it would leave every
% class re-resolved per document on a 562,448-document census, which this
% function's own header calls the expensive part.
memo(className) = info;
end

function tf = eaRefersToReference(cache, refersTo)
%EAREFERSTOREFERENCE Does a family's declared referent class sit in the
%   time-reference tier? Resolves the referent's chain DIRECTLY rather than
%   through eaClassInfo, so no memo entry can ever depend on itself.
tf = false;
if isempty(refersTo); return; end
name = char(refersTo);
if strcmp(name, eaReferenceRoot()); tf = true; return; end
try
    chain = cache.classChain(name);
catch
    return;
end
tf = any(strcmp(chain, eaReferenceRoot()));
end

function tf = eaChainDeclaresEdge(cache, chain, edgeName)
%EACHAINDECLARESEDGE Does any class in CHAIN declare a depends_on named
%   EDGENAME? Iterates element-wise over both shapes for the reason
%   declaredFamilies documents: `[deps{:}]` throws on mismatched fieldnames and
%   the throw is swallowed upstream, which is how a census goes quiet exactly
%   where it should speak.
tf = false;
for k = 1:numel(chain)
    try
        c = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isstruct(c) || ~isfield(c, 'depends_on'); continue; end
    deps = c.depends_on;
    if isstruct(deps)
        items = num2cell(deps(:)');
    elseif iscell(deps)
        items = deps(:)';
    else
        continue;
    end
    for d = 1:numel(items)
        dep = items{d};
        if isstruct(dep) && isfield(dep, 'name') && strcmp(char(dep.name), edgeName)
            tf = true; return;
        end
    end
end
end

function [state, terminus] = eaMemberOutcome(memberId, idIndex, cache, ...
    classMemo, walkMemo)
%EAMEMBEROUTCOME Where does ONE populated family member end up?
%
%   Returns one of EIGHT states, and they are exhaustive by construction --
%   every path out of this function assigns one, and the caller's counters sum
%   to `chain_members_examined`. A member that fell out of the accounting would
%   be a silence, which is the thing this whole file exists to remove.
%
%     unresolved        the reference document is not in this batch. NOT a
%                       failure: a batch is a SAMPLE.
%     not_a_reference   it resolved, but its class is not a time reference at
%                       all -- the family points at the wrong kind of thing
%     anchor_absent     its CLASS declares no anchor edge. Terminal BY DESIGN
%                       (absolute_reference, session_relative_reference), so it
%                       reaches no epoch and that is not a defect of the
%                       document
%     anchor_empty      its class declares the anchor and the document carries
%                       no value for it -- blank, or the edge absent entirely.
%                       `relative_to` is mustBeNonEmpty TRUE, so either way it
%                       is a required edge with nothing in it
%     reaches_epoch     the chain terminates at an `epoch`      <-- THE ANSWER
%     reaches_other     it terminates at a definite non-epoch document
%     incomplete        every branch left the batch
%     depth_exceeded    the chain is longer than eaMaxDepth()
state = 'unresolved'; terminus = '';
if isempty(memberId) || ~idIndex.isKey(memberId)
    return;
end
refBody = idIndex(memberId);
refClass = classNameOf(refBody);
refInfo = eaClassInfo(cache, refClass, classMemo);
if refInfo.is_terminal
    % Degenerate but real: the family points straight at an epoch.
    state = 'reaches_epoch'; terminus = refClass; return;
end
if ~refInfo.is_reference
    state = 'not_a_reference'; terminus = refClass; return;
end
if ~refInfo.declares_anchor
    state = 'anchor_absent'; terminus = refClass; return;
end
anchors = edgeValues(refBody, eaAnchorEdge());
live = anchors(~cellfun(@isempty, anchors));
if isempty(live)
    state = 'anchor_empty'; terminus = refClass; return;
end
[state, terminus] = eaWalk(live, idIndex, cache, classMemo, walkMemo);
end

function [state, terminus] = eaWalk(startIds, idIndex, cache, classMemo, walkMemo)
%EAWALK Follow the chain breadth-first from a set of anchor targets.
%
%   WHY IT IS A WALK AND NOT ONE HOP. The signed model says chains are normal
%   and well founded -- observation -> stimulus -> epoch, every link a real
%   document -- terminating at an epoch, a session or an absolute reference. A
%   one-hop check would report every legitimate two-hop statement as reaching
%   no epoch, which is a wrong number in the reassuring direction for whichever
%   side you are arguing.
%
%   At each node the outgoing edges are the anchor edge AND the node's own
%   numbered time-reference members, because a statement anchored to a stimulus
%   reaches the epoch through the stimulus's own reference.
%
%   ANY branch reaching an epoch wins. Otherwise the strongest remaining fact
%   is reported, and "left the batch" is kept apart from "terminated here":
%   the batch is a sample and only one of those two is a statement about the
%   data.
state = 'incomplete'; terminus = '';
memoKey = strjoin(startIds, '|');
if walkMemo.isKey(memoKey)
    m = walkMemo(memoKey);
    state = m.state; terminus = m.terminus;
    return;
end
% A cell, not a containers.Map: a chain is at most eaMaxDepth() hops and a
% handful of nodes wide, and this function runs once per populated member --
% hundreds of thousands of times on a real corpus. A Map per call would be the
% expensive part of the whole census.
visited = {};
frontier = startIds;
depth = 0;
sawUnresolved = false;
sawTerminated = false;
firstTerminus = '';
while ~isempty(frontier)
    if depth >= eaMaxDepth()
        state = 'depth_exceeded'; terminus = '';
        walkMemo(memoKey) = struct('state', state, 'terminus', terminus);
        return;
    end
    next = {};
    for k = 1:numel(frontier)
        id = frontier{k};
        if isempty(id) || any(strcmp(visited, id)); continue; end
        visited{end+1} = id; %#ok<AGROW>
        if ~idIndex.isKey(id)
            sawUnresolved = true;
            continue;
        end
        node = idIndex(id);
        nodeClass = classNameOf(node);
        nodeInfo = eaClassInfo(cache, nodeClass, classMemo);
        if nodeInfo.is_terminal
            state = 'reaches_epoch'; terminus = nodeClass;
            walkMemo(memoKey) = struct('state', state, 'terminus', terminus);
            return;
        end
        outgoing = eaOutgoingIds(node, nodeInfo);
        if isempty(outgoing)
            sawTerminated = true;
            if isempty(firstTerminus); firstTerminus = nodeClass; end
        else
            next = [next, outgoing]; %#ok<AGROW>
        end
    end
    frontier = next;
    depth = depth + 1;
end
if sawTerminated
    state = 'reaches_other'; terminus = firstTerminus;
elseif sawUnresolved
    state = 'incomplete'; terminus = '';
else
    % Nothing unresolved and nothing terminated: every id was already visited,
    % i.e. the chain is a CYCLE. Reported as its own kind of nothing rather
    % than folded into "terminates elsewhere".
    state = 'reaches_other'; terminus = '<cycle>';
end
walkMemo(memoKey) = struct('state', state, 'terminus', terminus);
end

function ids = eaOutgoingIds(body, info)
%EAOUTGOINGIDS The ids a node continues the chain through: its anchor edge, and
%   the members of any time-reference family its class declares. Blank edges
%   are dropped here -- an edge naming nothing continues nothing -- and the
%   emptiness itself is already counted, per document, by the family block.
ids = {};
anchors = edgeValues(body, eaAnchorEdge());
for k = 1:numel(anchors)
    if ~isempty(anchors{k}); ids{end+1} = anchors{k}; end %#ok<AGROW>
end
for f = 1:numel(info.time_families)
    members = familyMemberIds(body, info.time_families{f});
    for m = 1:numel(members)
        ids{end+1} = members{m}; %#ok<AGROW>
    end
end
end

function [keys, counts] = bump(keys, counts, key)
idx = find(strcmp(keys, key), 1);
if isempty(idx)
    keys{end+1} = key; counts(end+1) = 1;
else
    counts(idx) = counts(idx) + 1;
end
end

function out = explode(keys, counts, partNames)
%EXPLODE Split "a|b|c" keys back into a struct array, highest count first.
args = {};
for p = 1:numel(partNames)
    args = [args, partNames(p), {{}}]; %#ok<AGROW>
end
args = [args, {'count'}, {{}}];
out = struct(args{:});     % 0x0 struct array with the right fields
if isempty(keys); return; end
[~, order] = sort(counts, 'descend');
for k = order(:)'
    parts = strsplit(keys{k}, '|');
    entry = struct();
    for p = 1:numel(partNames)
        if p <= numel(parts)
            entry.(partNames{p}) = parts{p};
        else
            entry.(partNames{p}) = '';
        end
    end
    entry.count = counts(k);
    out(end+1) = entry; %#ok<AGROW>
end
end
