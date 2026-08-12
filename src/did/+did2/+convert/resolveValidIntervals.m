function [result, report] = resolveValidIntervals(result, options)
%RESOLVEVALIDINTERVALS DORMANT BY DECISION -- census only; emits nothing.
%
%   ---------------------------------------------------------------------
%   READ THIS FIRST: THIS PASS DOES NOT EMIT. IT IS NOT BROKEN.
%   ---------------------------------------------------------------------
%   TEAM DECISION 2026-08-12, jess@walthamdatascience.com, verbatim: *"Axes is
%   the decision... I'd rather wait until axes is built and it can be migrated
%   properly."* The TARGET MODEL is ONE statement per source document carrying
%   an ARRAY of booleans with the intervals on a TIME AXIS. The 1->N
%   decomposition written in this file -- one statement per interval -- is NOT
%   that model, and the team declined to ship it as an interim step. So the
%   emission path is guarded OFF and this pass runs as a CENSUS.
%
%   WHAT UNBLOCKS IT: `axes[]` on `subject_statement` -- DID-schema
%   `V_eta_data_body_model_plan.md`, OPEN_WORK #45, itself blocked on #32.
%   Until that lands there is nowhere to put a time axis, and a boolean array
%   with no axis cannot say WHICH stretch each element of it is about.
%
%   WHY THE CODE IS STILL HERE. The anchor resolution, the (session, epoch-id)
%   pair keying, Decision C's split-anchor branch, the verb resolution and
%   every refusal reason are the parts that will be needed unchanged when the
%   array model is built; only the SHAPE of the emitted body changes. Deleting
%   them and rewriting from the header later is how a repository loses the
%   evidence its decisions were made on. They are preserved behind
%   `options.Decompose`, which is FALSE by default and which
%   `testValidIntervalDecompose.m` sets to true so the logic keeps being
%   exercised rather than rotting unreferenced.
%
%   [RESULT, REPORT] = did2.convert.resolveValidIntervals(RESULT) takes the
%   struct returned by did2.convert.v1_to_v2 (after did2.convert.epochMint),
%   COUNTS the `valid_interval` documents in the batch and the intervals they
%   hold, and returns RESULT with NOTHING APPENDED. REPORT is also attached as
%   RESULT.valid_interval_decompose, so a caller that ignores the second output
%   still carries the measurement. `dormant` is TRUE in that report and
%   `statements_emitted` / `references_emitted` / `intervals_decomposed` /
%   `documents_appended` are 0 BY DECISION, not by accident -- a zero with no
%   `sources_seen` beside it is exactly the silence Operating Rule 5 exists to
%   forbid, so `sources_seen` and `intervals_seen` are counted in the dormant
%   path and are the whole point of still running it.
%
%   WHERE THE DOCUMENTS GO MEANWHILE: nowhere. Each `valid_interval` passes
%   through to its own v1 tombstone (`schemas/V_eta/stable/valid_interval.json`,
%   restated from the WRITER in DID-schema build_v_eta.py), which declares
%   nothing required and an OPTIONAL `element_id`, so a passthrough cannot trip
%   `mustBeNonEmpty` or `undeclaredField`. That is the same pattern every other
%   deferred family uses.
%
%   WHEN `axes[]` LANDS, the class this emits is `logical_observation`
%   (over {subject_observation, logical}) and NOT `validity_observation` -- see
%   THE CLASS NAMING below. The dormant emission path already names it, so the
%   rename does not have to be rediscovered later.
%
%   THE DECOMPOSING PATH, for when it is re-armed: for every `valid_interval`
%   document it emits ONE `logical_observation` per interval -- a boolean
%   statement about the element-subject -- plus the `relative_reference` each
%   statement is anchored to.
%
%   STATUS: WRITTEN 2026-08-11 IN A CONTAINER WITH NO MATLAB AND NO OCTAVE
%   (`command -v matlab octave octave-cli` returns nothing). NOTHING IN THIS
%   FILE HAS BEEN RUN. test-migrators-quick.yml is the first thing that will
%   have an opinion about it. Read it as a specification, not as a passing pass.
%   AMENDED 2026-08-11 to populate `subject_interaction.method` (see "THE VERB"
%   below), in the same container, under the same condition: `command -v matlab
%   octave octave-cli` still returns nothing, so that amendment has not been run
%   either. CI is its first execution.
%
%   ---------------------------------------------------------------------
%   THE DECISION THIS IMPLEMENTS
%   ---------------------------------------------------------------------
%   THREE DIFFERENT THINGS, AND THIS HEADER USED TO CONFLATE THE FIRST TWO.
%
%   THE MODEL -- ASKED, DECLINED. On 2026-08-11 the team ASKED, verbatim:
%   *"Should valid interval be a new class that takes a subject statement,
%   shares its time reference and states true or false for each value?"* -- and
%   then said *"Can we skip this decision for now?"*. This header used to quote
%   the question under the words "TEAM DECISION 2026-08-11", which is exactly
%   the error DID-schema `V_eta_OPEN_WORK.md` #103 records: a question written
%   up as an answer. NOT SIGNED, NOT AGREED. No TEAM-SIGN-OFF line exists for
%   this family, the status board renders it as BUILT AHEAD OF THE DECISION,
%   and this pass is built to be reversible rather than to pre-empt that.
%   RESOLVED 2026-08-12 IN THE OTHER DIRECTION: the team chose the ARRAY model
%   (one statement, N booleans, a time axis) and chose to WAIT for `axes[]`
%   rather than ship this 1->N shape as an interim. Hence the dormancy at the
%   top of this file. "Built ahead of the decision" is no longer the state --
%   the decision arrived and it was "not this shape, and not yet".
%
%   THE CLASS NAMING -- DECIDED 2026-08-12 by jess@walthamdatascience.com:
%   `validity` and `validity_observation` are REPLACED by `logical` and
%   `logical_observation`. The 32 `*_observation` data_types name a KIND OF
%   VALUE (length, intensity, count, score, term, image); `validity` was the
%   only one naming a SEMANTIC -- what the measurement is ABOUT -- and the
%   semantic belongs in `subject_statement.variable`. That is not a proposal:
%   `resolveLawnPlateSubjects.m:1106-1113` already sends six distinct
%   fluorescence semantics to ONE `intensity_observation`, told apart only by
%   `variable` (`:689 variableTerm(c{1})` -> `:1317`). It is also the error
%   R2/R3 fixed for tuning, where six classes named by their independent
%   variable collapsed into one `tuning_curve`. `boolean` was impossible as the
%   class name -- it is a hard-coded primitive in the validator's type switch
%   (`+did2/+schema/cache.m:1793`) -- so `logical` follows the existing
%   `term`/`ontology_term` precedent: the data_type name differs from the field
%   type it wraps. The `variable` this pass emits is UNCHANGED and is now the
%   only thing carrying the semantic: `data validity`.
%
%   ---------------------------------------------------------------------
%   IT ADDS. IT NEVER REMOVES. THE SOURCE DOCUMENT IS KEPT.
%   ---------------------------------------------------------------------
%   The `valid_interval` document stays in the batch, validating against its own
%   V_eta tombstone, exactly as it does today. Three reasons, none of them
%   timidity:
%
%     1. VERIFY BEFORE DELETE. `did2.convert.resolveResponseParameters` leaves
%        11,440 parameters documents in place and MEASURES the deletion gate
%        instead of pre-empting it; this does the same, with
%        `sources_fully_decomposed`. Removing a source class ahead of the
%        evidence is the `epochfiles_ingested` regression (2,484 quarantines).
%     2. NOTHING THE DECOMPOSITION CANNOT CARRY IS LOST WHILE THE SOURCE IS
%        THERE. The v1 `app` block (which app marked these intervals), the raw
%        `referent_epochsetname` / `referent_classname` pair, and the timeref's
%        own `session_ID` have no slot on the statement. They ride on the
%        retained source. `sources_with_app_block` counts the first of those so
%        the gap is a number rather than a silence.
%     3. NOTHING REFERENCES `valid_interval` BY ID, so keeping it strands
%        nothing and removing it later strands nothing either. Re-derived
%        rather than quoted, on NDI origin/main:
%
%          git ls-tree -r --name-only origin/main -- .../database_documents
%              | grep -c '\.json$'                     ->  91 templates
%          ...none of the 91 declares a valid_interval_id / validInterval_id dep
%          git grep -c -I -i "validinterval" origin/main
%              +ndi/+app/+stimulus/tuning_response.m   2
%              +ndi/+app/markgarbage.m                40
%              +ndi/+test/+app/markgarbage.m           3
%              +ndi/+test/+app/spikeextractor.m        1
%              tests/.../TestMarkGarbage.m            15
%          81 .m files in +migrators_j, 0 referencing the class outside comments
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A BATCH PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   The same structural wall `did2.convert.resolveSessionAnchors` documents, one
%   referent over:
%
%     * `relative_reference.relative_to` is REQUIRED (team call, fork A of
%       V_eta_time_reference_model_plan.md).
%     * The v1 anchor is `ndi.time.timereference`'s struct, and the thing it
%       names is an EPOCH -- by the STRING `epoch`, plus `session_ID`
%       (timereference.m:106-111).
%     * V_eta reifies the epoch as a DOCUMENT, and that document's `base.id`
%       exists only after `did2.convert.epochMint` has done its corpus-wide
%       find-or-create on the (session, epoch-string) PAIR.
%
%   A single-document migrator holds the string and cannot map it to an id. The
%   alternative -- emit `relative_to` empty in pass 1 -- is not an alternative:
%   `+did2/+validate/references.m:90` SKIPS empty edges, so the husks would
%   validate clean and no gate would see them, which is the invented-empty-edge
%   pattern this project has now counted 26,406 documents of.
%
%   ORDER IS LOAD-BEARING HERE, UNLIKE THE SIBLING PASSES. resolveSessionAnchors
%   and resolveLawnPlateSubjects commute with their neighbours; this one does
%   NOT. It reads the `epoch` documents epochMint appends, so it MUST run after
%   epochMint. It reads them out of `result.migrated` rather than out of
%   `result.epoch_mint.epoch_index` deliberately: one source of truth (the
%   batch) cannot drift from itself, and the pass then behaves identically
%   whether the epochs were minted this run or were already there.
%
%   ---------------------------------------------------------------------
%   HAZARD 1 -- ABSENCE MUST KEEP MEANING "VALID"
%   ---------------------------------------------------------------------
%   `ndi.app.markgarbage` is OPT-IN. Today, NO `valid_interval` document for an
%   element means the WHOLE epoch is good data -- markgarbage.m:172-176:
%
%       vi = ndi_app_markgarbage_obj.loadvalidinterval(ndi_epochset_obj);
%       if isempty(vi)
%           intervals = [t0 t1];
%           return;
%       end
%
%   So a dataset that never ran markgarbage must migrate to a dataset with ZERO
%   validity statements, NOT to one where every epoch is "unknown". (The
%   absence rule is scoped BY `variable` now that the class is generic: a
%   subject with no `logical` statement about SOME OTHER boolean says nothing
%   about its data validity.) This pass
%   reads `valid_interval` documents and nothing else; with none in the batch
%   every counter below reads 0, `documents_appended` is 0, and `result.migrated`
%   is returned unchanged. It NEVER mints a statement for an element that has no
%   source document, and the DID-schema half declares the absence rule on the
%   class so a consumer that never read this file still reads it right.
%
%   NOTHING WE GATE ON WOULD CATCH THE OTHER BEHAVIOUR. A corpus with no
%   markgarbage documents is 0 quarantine / 0 orphans before and after a change
%   that reclassifies every epoch in it.
%
%   ---------------------------------------------------------------------
%   HAZARD 2 -- ORDER IS *NOT* LOAD-BEARING. THIS SECTION SAID THE OPPOSITE.
%   ---------------------------------------------------------------------
%   IT USED TO READ "ORDER IS LOAD-BEARING, AND THE CONSUMER IS AN ANALYSIS",
%   and every statement carried `validity_observation.sequence` = its 1-based
%   position in the v1 array because of it. The premise was one unchecked
%   reading of a call site, and it is FALSE. Positive evidence, from NDI
%   `origin/main` (42c94e53b):
%
%       +ndi/+app/+stimulus/tuning_response.m:253-256
%         vi       = gapp.loadvalidinterval(ndi_timeseries_obj);
%         interval = gapp.identifyvalidintervals(ndi_timeseries_obj,timeref,0,Inf);
%         [data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, ...
%             ts_epoch_timeref.epoch, interval(1,1), interval(1,2));
%
%   `interval` is the RETURN VALUE of `identifyvalidintervals`. The stored array
%   `vi` is loaded at :253 into a variable that is then NEVER READ AGAIN -- the
%   old text read `interval(1,1)` as indexing the stored array, and it does not.
%   And `identifyvalidintervals` (markgarbage.m:178-204) is:
%
%       for i=1:size(vi,1)
%           ...
%           explicitly_good_intervals = vlt.math.interval_add( ...
%               explicitly_good_intervals, [epoch_t0_out epoch_t1_out]);
%       end
%
%   -- it iterates EVERY row and accumulates through a SET UNION. It never
%   indexes `vi` by position. So v1's append order is invisible to every reader
%   of the class: it is a storage artifact, not a fact. `sequence` IS DELETED
%   and `logical_observation` declares NO FIELDS AT ALL, like
%   `length_observation` and `count_observation`.
%
%   LIMIT OF THIS CHECK, STATED RATHER THAN GLOSSED. `vlt.math.interval_add` is
%   in vhlab-toolbox-matlab, which was not available when this was re-verified,
%   so whether the union SORTS its output was not read from source. The
%   conclusion does not rest on it -- `interval(1,1)` indexes the union's
%   output either way, and one source document's rows are unordered INPUT to
%   that union -- but the sort behaviour itself is unverified.
%
%   THE SHAPE OF THE ERROR IS THE PART WORTH KEEPING. The schema declared
%   `sequence`, this pass emitted it, and `testValidIntervalDecompose.m`
%   asserted it -- three artifacts written from ONE unchecked premise, which is
%   CLAUDE.md's "a test written from the same premise as the code cannot catch
%   the code". The premise was never re-read until it was re-read.
%
%   ---------------------------------------------------------------------
%   HAZARD 3 -- VALIDITY INHERITS, AND THAT IS NOT DECIDED HERE
%   ---------------------------------------------------------------------
%   `loadvalidinterval` falls back to the `underlying_element` when a derived
%   element has no intervals of its own (markgarbage.m:146-155):
%
%       if isempty(vi)   % underlying elements could still have garbage intervals
%           if isprop(ndi_epochset_obj,'underlying_element')
%               ... loadvalidinterval(ndi_epochset_obj.underlying_element)
%
%   That is a QUERY-TIME rule in NDI. Whether V_eta re-derives it through the
%   `derived_from` chain or MATERIALISES copies onto derived subjects is an OPEN
%   SUB-QUESTION for the team. THIS PASS DOES NOT PICK ONE, and is built so that
%   neither is foreclosed:
%
%     * the statement's `subject_id` is the element the v1 document named and
%       nothing else, so a re-deriving answer still has the exact v1 graph --
%       `migrators_j/element.m:131` already emits the
%       `child --derived_from--> parent` relation it would walk;
%     * `subject_observation.derived_from_#` exists, is OPTIONAL, and is left
%       EMPTY here, so a materialising answer needs no schema change and pass 1
%       has invented no edge it would have to undo;
%     * there is no per-statement ordinal to reconcile across a merged set --
%       `sequence` was deleted with HAZARD 2, so a materialising answer has one
%       fewer thing to define.
%
%   WHAT A LATER DECISION WOULD HAVE TO CHANGE, so the size of it is on the
%   record rather than discovered later:
%
%     RE-DERIVE AT QUERY TIME   nothing here. A reader walks
%                               `derived_from` upward from the subject until it
%                               finds a subject with validity statements. The
%                               cost is that the rule lives in readers, which is
%                               the thing T14 exists to dislike, and NDI's own
%                               fallback is single-hop (it recurses on
%                               `underlying_element`, which is itself recursive)
%                               while `derived_from` chains can be longer.
%     MATERIALISE               this pass gains a second emission loop: for each
%                               subject with an incoming `derived_from` edge to
%                               an element that HAS statements and none of its
%                               own, emit a copy with a fresh id,
%                               `derived_from_#` pointing at the original, and
%                               (per T6's cache rule) an `is_cache`-style marker
%                               -- which `subject_observation` does NOT declare
%                               today, so the schema half would need it, or the
%                               copies would be indistinguishable from primary
%                               curation.
%
%   `inheritance_candidates` below MEASURES how big that question is on real
%   data: the number of subjects in the batch holding a `derived_from` edge to
%   an element this pass just wrote statements for. It is REPORT-ONLY and
%   changes nothing.
%
%   ---------------------------------------------------------------------
%   THE ANCHOR, AND DECISION C
%   ---------------------------------------------------------------------
%   Each v1 interval carries TWO independent anchors --
%   `markvalidinterval(epochset, t0, timeref_t0, t1, timeref_t1)` stores
%   `{timeref_structt0, t0, timeref_structt1, t1}`. Decision C of the signed
%   time model governs, and a nested anchor block per end is explicitly
%   rejected:
%
%     ends AGREE     ONE `relative_reference`: start = t0, duration = t1 - t0.
%     ends DIFFER    TWO `relative_reference` documents on the statement, each
%                    an instant (start only, no duration).
%
%   THE SECOND BRANCH IS EXPECTED NEVER TO FIRE, and its counter is how we find
%   out. CHANGE 5 of the same plan measured every call site --
%   markgarbage.m:10 (the docstring), +test/+app/markgarbage.m:49 and all six
%   calls in TestMarkGarbage.m -- and every one passes the SAME reference for
%   both ends. `split_anchor_intervals` is therefore a prediction under test.
%
%   AND IT INTERACTS WITH #52, WHICH IS NOT CLOSED. The signed rule is that
%   within a `time_reference_#` family every member describes the same instant
%   or extent and `value.clock` is UNIQUE across the family. Two anchors that
%   differ by EPOCH but share a CLOCK satisfy neither half. That is reported
%   (did2.validate.silentLoss counts `family_uniqueness_violation`), not
%   silently accepted, and it is the reason the counter exists rather than a
%   quiet emit.
%
%   ---------------------------------------------------------------------
%   "EACH VALUE" IS PER INTERVAL, NOT PER SAMPLE
%   ---------------------------------------------------------------------
%   Per-interval is migratable: the intervals are literally in the document. A
%   per-sample validity mask is NOT -- it needs the sample grid, and a migrator
%   does not read file bytes to learn it. No `sample_time` cadence is emitted
%   for the same reason: there is no sampling here, and stating `kind: point`
%   would assert a cadence the source never described.
%
%   ---------------------------------------------------------------------
%   WHAT IT REFUSES TO DO, AND COUNTS INSTEAD
%   ---------------------------------------------------------------------
%   An interval it cannot decompose HONESTLY is left alone and counted. The
%   source document is untouched in every one of these cases, so a refusal
%   degrades to "not decomposed", never to a loss:
%
%     no element_id on the source           -> refused_no_element_id
%     block holds no readable interval      -> refused_no_intervals
%     an entry carries no timeref block     -> refused_no_anchor_block
%     an anchor names no epoch string       -> refused_no_epoch_string
%     no `epoch` document for (session, id) -> refused_no_epoch_document
%     two `epoch` documents claim the pair  -> refused_ambiguous_epoch
%     clocktypestring absent or `no_time`   -> refused_no_clock
%     t0 or t1 non-finite                   -> refused_non_finite_times
%     t1 < t0                               -> refused_negative_extent
%
%   `no_time` is a real, reachable value, not defensiveness: `ndi.time.clocktype`
%   lists it and NDI's own readers fall back to it. NO TIMES => NO REFERENCE is
%   the signed rule (V_eta_time_reference_model_plan.md); a NaN-valued reference
%   is the hollow document silentLoss and isFragment exist to catch.
%
%   ---------------------------------------------------------------------
%   THE VERB -- WHY `method` IS STATED, AND WITH WHAT
%   ---------------------------------------------------------------------
%   A validity `logical_observation` records a CURATORIAL JUDGEMENT: a person ran
%   `ndi.app.markgarbage` and marked which stretches of a recording are good
%   data. It is NOT a measurement taken from the subject. V_eta's four statement
%   directions are assertion / observation / manipulation / calculation and none
%   of them is "a human judged this", which the team raised as an objection to
%   this family. The resolution does not add a fifth direction: T2's declared
%   slot for THE VERB -- how was this known -- is `subject_interaction.method`,
%   and that is where the epistemic stance is stated.
%
%   THIS FIELD USED TO BE EMITTED EMPTY (`{node: '', name: ''}`), which made a
%   curation judgement INDISTINGUISHABLE FROM AN INSTRUMENT READING. Nothing
%   would ever have caught it: `method` is `mustBeNonEmpty: false`, so a blank
%   term validates, and subject_interaction.json's own documentation says the
%   observation verb "is nearly always 'measurement'" -- so a blank reads as the
%   default, and the default is the one thing this statement is not.
%
%   THE NAME IS `curation`, ONE WORD, and the alternatives were rejected on the
%   tenets rather than on taste:
%
%     markgarbage / ndi_app_markgarbage   names the TOOL, not the act, and
%                                         `ndi_app_` is a namespace wrapper
%                                         (T13 wrapper-free; T11 forbids a
%                                         device/method subtype in a name). The
%                                         tool is PROVENANCE -- it belongs on
%                                         the `app` block / `software_id`, which
%                                         subject_interaction.json says in its
%                                         own words supersedes the v1 `app`.
%     manual curation / expert annotation /
%     visual inspection                   each adds a claim the source never
%                                         makes -- that a human, an expert, or
%                                         an eye did it. `markvalidinterval` is
%                                         a plain API a script can call. T13:
%                                         the stance word must be TRUE, not
%                                         convenient.
%     data curation                       `data` is altitude noise beside
%                                         `variable = 'data validity'` on the
%                                         same statement (T13, name the content
%                                         not the container).
%     garbage marking / interval marking  the tool's UI gesture, and its
%                                         polarity is inverted from what the
%                                         statement asserts (the migrated value
%                                         is TRUE = valid).
%     measurement                         false here, and it is exactly what a
%                                         blank `method` already reads as.
%
%   Being ONE WORD, `curation` is identical in snake_case and as a
%   human-readable label, so it satisfies T13's case rule without having to
%   settle which of the two applies to a term `name`. That question is real: of
%   the 18 `jOntologyTerm('', <literal>)` sites in +did2/+convert, 6 are empty
%   and 12 carry a name -- 11 of the 12 are space-separated labels
%   ('anatomical location', 'spike cluster assignment') and the twelfth is
%   'dev_local_time', an NDI-authored identifier carried verbatim, which is
%   T13's own stated exemption. This term needs neither ruling.
%
%   WHERE THE TERM COMES FROM, PER DOCUMENT, AND BOTH CASES ARE COUNTED. The v1
%   `app` block was read as the WRITER produces it, not as the template shows
%   it: `markgarbage.m`'s constructor sets `name = 'ndi_app_markgarbage'` (NOT
%   the `ndi.app.markgarbage` its own docstring claims), `savevalidinterval`
%   adds `+ ndi_app_markgarbage_obj.newdocument()`, and `ndi.app/newdocument`
%   (app.m:105-114) writes `app.name` from that property alongside version, url,
%   os, os_version, interpreter and interpreter_version. So THE DOCUMENT NAMES A
%   TOOL AND NEVER A VERB -- there is no term in it to copy. The verb is
%   therefore a CONSTANT in both branches, and what the branch records is the
%   EVIDENCE for it, the same way `anchor_session_from_timeref` /
%   `anchor_session_from_document` already do one field over:
%
%     method_from_app_block      the source names a producer, so the claim
%                                "this was curation" rests on the document.
%     method_from_class_default  no app block, or an `app_name` that is present
%                                but empty (the template's default is ""), so
%                                nothing in the document names a producer. The
%                                verb is asserted from the CLASS instead:
%                                nothing but markgarbage writes `valid_interval`
%                                (the writer grep at the top of this file). A
%                                statement in this branch still STATES its
%                                method -- a blank would be the defect above.
%
%   ---------------------------------------------------------------------
%   THE STAGED ONTOLOGY NODES
%   ---------------------------------------------------------------------
%   `variable`, `clock` and `method` are emitted as `{node: '', name: ...}`.
%   That is the standing practice (jEpochClockReferences stages `clock` the same
%   way; the NDIC identifier authority is in no repository in scope since
%   NDIC.txt left NDI-matlab at 2c19bf24c) -- but `tools/check_empty_ontology_nodes.py`
%   walks ONLY `+migrators_j` and matches ONLY `jOntologyTerm('', ...)`
%   (its `sweep()`, and `sweep_schemas()` reads built schemas), so a term staged
%   HERE is invisible to the one instrument built to make staged terms visible.
%   RE-CHECKED WHEN `method` WAS POPULATED: still true. `staged_ontology_nodes`
%   in the report is the local stand-in -- it counts THREE per decomposed
%   interval (clock, variable, method; four when the split-anchor branch emits
%   two references), reaches the corpus report via runCorpusDiscovery and the
%   cross-corpus census via tools/census_digest.py, so the debt is a number in
%   two printed reports rather than a silence. Widening that tool is a separate
%   change. NO CURIE IS INVENTED for `method`: the node stays empty and joins
%   the same ratchet as everything else here.
%
%   Options (name-value), mirroring the sibling passes:
%     Validate       (1,1 logical, default true)  validate emitted bodies
%     SchemaCache    ([] or a did2.schema.cache)  override the shared cache
%     TargetVersion  (1,:) char, default 'V_eta'  no-op on other targets
%     Decompose      (1,1 logical, default FALSE) arm the 1->N emission path.
%                    DORMANT BY TEAM DECISION 2026-08-12 -- see the top of this
%                    file. The default is FALSE and no production caller passes
%                    it; `testValidIntervalDecompose.m` passes true so the
%                    preserved logic stays exercised. Do NOT flip the default
%                    to re-arm the pass: the shape it emits is not the model
%                    the team chose, so re-arming is a rewrite (array + time
%                    axis), not a boolean.
%
%   See also: did2.convert.v1_to_v2, did2.convert.epochMint,
%   did2.convert.resolveSessionAnchors, did2.convert.resolveResponseParameters,
%   did2.convert.resolveLawnPlateSubjects.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
    options.Decompose (1,1) logical = false
end

% DENOMINATOR FIRST, and unconditionally. Every field is defined before a single
% document is read, so "did not run" and "ran and found nothing" are different
% readings of the same struct rather than the same reading. Operating Rule 5;
% silentLoss is what happens without it.
report = struct( ...
    'documents_inspected',            0, ...
    'documents_unreadable',           0, ...
    'epoch_documents_seen',           0, ...
    'sources_seen',                   0, ...
    'sources_with_app_block',         0, ...
    'intervals_seen',                 0, ...
    'intervals_decomposed',           0, ...
    'statements_emitted',             0, ...
    'references_emitted',             0, ...
    'split_anchor_intervals',         0, ...
    'sources_fully_decomposed',       0, ...
    'sources_partly_decomposed',      0, ...
    'anchor_session_from_timeref',    0, ...
    'anchor_session_from_document',   0, ...
    'method_from_app_block',          0, ...
    'method_from_class_default',      0, ...
    'staged_ontology_nodes',          0, ...
    'inheritance_candidates',         0, ...
    'refused_no_element_id',          0, ...
    'refused_no_intervals',           0, ...
    'refused_no_anchor_block',        0, ...
    'refused_no_epoch_string',        0, ...
    'refused_no_epoch_document',      0, ...
    'refused_ambiguous_epoch',        0, ...
    'refused_no_clock',               0, ...
    'refused_non_finite_times',       0, ...
    'refused_negative_extent',        0, ...
    'refused_total',                  0, ...
    'references_quarantined',         0, ...
    'statements_quarantined',         0, ...
    'statements_withheld_lost_anchor', 0, ...
    'documents_appended',             0, ...
    'dormant',                        true, ...
    'ran',                            false);
result.valid_interval_decompose = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % `logical_observation` exists only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.valid_interval_decompose = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ---------------------------------------------
% A document this cannot read is COUNTED, never dropped.
bodies = cell(1, n);
classes = repmat({''}, 1, n);
sessionIds = repmat({''}, 1, n);
docIds = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k} = b;
        classes{k} = classNameOf(b);
        sessionIds{k} = baseField(b, 'session_id');
        docIds{k} = baseField(b, 'id');
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- index the `epoch` documents ------------------------------------------
% Keyed on the PAIR (base.session_id, epoch.local_identifier), never on the
% string alone. did2.convert.epochMint measured why: an `epochid.epochid` string
% is REUSED ACROSS SESSIONS -- 142 of corpus B's 149 distinct ids -- so keying
% on the string would fuse epochs belonging to different sessions, and this pass
% would then anchor a probe's valid interval to a recording from another animal.
% A pair claimed by two epoch documents is REFUSED rather than guessed at.
epochIdByKey = containers.Map('KeyType', 'char', 'ValueType', 'char');
epochCountByKey = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~strcmp(classes{k}, 'epoch'); continue; end
    report.epoch_documents_seen = report.epoch_documents_seen + 1;
    lid = '';
    if isfield(bodies{k}, 'epoch') && isstruct(bodies{k}.epoch)
        lid = charField(bodies{k}.epoch, {'local_identifier'});
    end
    if isempty(lid) || isempty(docIds{k}); continue; end
    key = pairKey(sessionIds{k}, lid);
    if isKey(epochCountByKey, key)
        epochCountByKey(key) = epochCountByKey(key) + 1;
    else
        epochCountByKey(key) = 1;
        epochIdByKey(key) = docIds{k};
    end
end

% --- DORMANT BY DECISION: census only, then stop ---------------------------
% TEAM DECISION 2026-08-12 (see the top of this file). The ARRAY model is the
% target and it waits for `axes[]`; the 1->N shape below is not it and does not
% run. This branch is deliberately placed AFTER the document read and the epoch
% index so `documents_inspected`, `documents_unreadable` and
% `epoch_documents_seen` are real numbers rather than structural zeros.
%
% WHAT IT COUNTS AND WHAT THOSE COUNTS DO NOT MEAN.
%   sources_seen    the `valid_interval` documents in the batch. THE
%                   DENOMINATOR. Every emission counter below is 0 by
%                   decision, and a 0 with no denominator beside it is
%                   indistinguishable from an instrument reading nothing --
%                   which is exactly what silentLoss did for two days.
%   intervals_seen  the intervals those documents hold. This is a CEILING on
%                   what a re-armed pass would decompose, NOT a prediction of
%                   it: the eight `refused_*` reasons are computable only by
%                   the path that is switched off, so they stay 0 and mean
%                   "not evaluated", not "none".
% Everything else -- intervals_decomposed, statements_emitted,
% references_emitted, documents_appended, sources_fully_decomposed -- is 0
% STRUCTURALLY: there is no code path from here that can raise them.
if ~options.Decompose
    for k = 1:n
        if ~strcmp(classes{k}, 'valid_interval'); continue; end
        report.sources_seen = report.sources_seen + 1;
        report.intervals_seen = report.intervals_seen + ...
            numel(intervalEntries(blockOf(bodies{k}, 'valid_interval')));
    end
    report.dormant = true;
    result.valid_interval_decompose = report;
    return;
end
report.dormant = false;

% --- decompose every interval we can decompose honestly --------------------
refBodies = {};
stmtBodies = {};
stmtRefIds = {};        % the reference ids each statement depends on
elementsWritten = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:n
    if ~strcmp(classes{k}, 'valid_interval'); continue; end
    report.sources_seen = report.sources_seen + 1;
    src = bodies{k};
    blk = blockOf(src, 'valid_interval');
    if isfield(src, 'app') && isstruct(src.app) && ~isempty(fieldnames(src.app))
        % Counted, not carried: the app provenance stays on the retained source
        % document. Minting a `software` entity per statement here would produce
        % one undeduplicated entity per interval --
        % did2.convert.resolveDatasetEntities, which does the software dedup,
        % has already run by this point.
        report.sources_with_app_block = report.sources_with_app_block + 1;
    end
    % THE VERB, resolved ONCE PER SOURCE because the app block is per source.
    % Computed before the refusals below so that the two evidence counters
    % describe the statements that were actually written and nothing else.
    [methodTerm, methodEvidence] = curationMethod(src);

    elementId = depValue(src, 'element_id');
    entries = intervalEntries(blk);
    report.intervals_seen = report.intervals_seen + numel(entries);
    if isempty(elementId)
        report.refused_no_element_id = report.refused_no_element_id + 1;
        continue;
    end
    if isempty(entries)
        report.refused_no_intervals = report.refused_no_intervals + 1;
        continue;
    end

    doneHere = 0;
    for i = 1:numel(entries)
        e = entries{i};
        % THE ORDER IS THE LOOP INDEX AND NOTHING ELSE. No sort, no dedup, no
        % reorder -- see HAZARD 2 in the header.
        [a0, why0] = resolveAnchor(subStruct(e, {'timeref_structt0'}), ...
            sessionIds{k}, epochIdByKey, epochCountByKey);
        [a1, why1] = resolveAnchor(subStruct(e, {'timeref_structt1'}), ...
            sessionIds{k}, epochIdByKey, epochCountByKey);
        why = why0; if isempty(why); why = why1; end
        if ~isempty(why)
            report.(why) = report.(why) + 1;
            continue;
        end
        % Counted ONCE PER INTERVAL, not once per anchor: both ends of one
        % interval come off the same source document, so a split anchor would
        % otherwise double-count the same fact about where the session id
        % was read from.
        report.(a0.session_source) = report.(a0.session_source) + 1;

        t0 = numericField(e, {'t0'});
        t1 = numericField(e, {'t1'});
        if isempty(t0) || isempty(t1) || ~isfinite(t0) || ~isfinite(t1)
            report.refused_non_finite_times = report.refused_non_finite_times + 1;
            continue;
        end
        if t1 < t0
            report.refused_negative_extent = report.refused_negative_extent + 1;
            continue;
        end

        if sameAnchor(a0, a1)
            % DECISION C, the agreeing case: ONE anchor governs both ends.
            % CHANGE 1 of the signed walkthrough -- the EXTENT is a duration,
            % not the raw t1, so a fuzzy anchor cannot contaminate the span.
            refs = {makeReference(src, a0, t0, t1 - t0)};
        else
            % DECISION C, the disagreeing case: TWO reference documents, each an
            % INSTANT. Never a nested anchor block per end -- that is the inline
            % structure removed from acquisition_epoch.clocks, epochclocktimes,
            % distance_metadata and the tuning bag.
            refs = {makeReference(src, a0, t0, []), ...
                    makeReference(src, a1, t1, [])};
            report.split_anchor_intervals = report.split_anchor_intervals + 1;
        end

        refIds = cell(1, numel(refs));
        for r = 1:numel(refs)
            refIds{r} = refs{r}.base.id;
            refBodies{end+1} = refs{r}; %#ok<AGROW>
            report.staged_ontology_nodes = report.staged_ontology_nodes + 1;  % clock
        end
        stmtBodies{end+1} = makeLogicalObservation( ...
            src, elementId, true, refIds, methodTerm); %#ok<AGROW>
        stmtRefIds{end+1} = refIds; %#ok<AGROW>
        report.staged_ontology_nodes = report.staged_ontology_nodes + 1;      % variable
        report.staged_ontology_nodes = report.staged_ontology_nodes + 1;      % method
        % WHICH BRANCH BACKED THE VERB, per statement. Counted separately from
        % `sources_with_app_block` (which is per SOURCE) so the two cannot be
        % mistaken for each other, and so the sum is checkable against
        % `intervals_decomposed`.
        report.(methodEvidence) = report.(methodEvidence) + 1;
        doneHere = doneHere + 1;
    end

    report.intervals_decomposed = report.intervals_decomposed + doneHere;
    if doneHere == numel(entries)
        report.sources_fully_decomposed = report.sources_fully_decomposed + 1;
        elementsWritten(elementId) = true;
    elseif doneHere > 0
        report.sources_partly_decomposed = report.sources_partly_decomposed + 1;
        elementsWritten(elementId) = true;
    end
end

report.refused_total = report.refused_no_element_id ...
    + report.refused_no_intervals ...
    + report.refused_no_anchor_block ...
    + report.refused_no_epoch_string ...
    + report.refused_no_epoch_document ...
    + report.refused_ambiguous_epoch ...
    + report.refused_no_clock ...
    + report.refused_non_finite_times ...
    + report.refused_negative_extent;

% --- HAZARD 3, MEASURED ONLY ----------------------------------------------
% How many subjects in this batch hold a `derived_from` edge to an element this
% pass just wrote statements for -- i.e. the population NDI's `underlying_element`
% fallback serves. REPORT-ONLY: nothing is emitted for them, because which of the
% two answers is right is a TEAM decision. The number is here so the decision can
% be made against a size rather than against an intuition.
if elementsWritten.Count > 0
    for k = 1:n
        if ~strcmp(classes{k}, 'directed_relation'); continue; end
        blk = blockOf(bodies{k}, 'directed_relation');
        rel = '';
        if isstruct(blk) && isfield(blk, 'relation') && isstruct(blk.relation)
            rel = charField(blk.relation, {'name'});
        end
        if ~strcmp(rel, 'derived_from'); continue; end
        parent = depValue(bodies{k}, 'parent');
        if ~isempty(parent) && isKey(elementsWritten, parent)
            report.inheritance_candidates = report.inheritance_candidates + 1;
        end
    end
end

if isempty(stmtBodies)
    result.valid_interval_decompose = report;
    return;
end

% --- validate the ANCHORS FIRST, then the statements that still have one ---
% Two rounds, deliberately. A statement whose anchor quarantined would carry a
% `time_reference_1` edge pointing at a document that is not in the batch -- an
% ORPHAN, and the corpus gate is 0 orphans. So a statement is emitted only when
% EVERY reference it names survived; otherwise it is WITHHELD and counted, and
% the source document (still present) remains the record of that interval.
[refSurvived, refQuarantined] = validateBodies(refBodies, options);
report.references_quarantined = numel(refQuarantined);
if ~isempty(refQuarantined)
    result = appendQuarantine(result, refQuarantined);
end

keptStmts = {};
keptRefIds = {};
for s = 1:numel(stmtBodies)
    ids = stmtRefIds{s};
    ok = true;
    for r = 1:numel(ids)
        if ~isKey(refSurvived, ids{r}); ok = false; break; end
    end
    if ~ok
        report.statements_withheld_lost_anchor = ...
            report.statements_withheld_lost_anchor + 1;
        continue;
    end
    keptStmts{end+1} = stmtBodies{s}; %#ok<AGROW>
    keptRefIds{end+1} = ids;          %#ok<AGROW>
end

appended = {};
usedRefIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if ~isempty(keptStmts)
    [stmtSurvived, stmtQuarantined] = validateBodies(keptStmts, options);
    report.statements_quarantined = numel(stmtQuarantined);
    if ~isempty(stmtQuarantined)
        result = appendQuarantine(result, stmtQuarantined);
    end
    % COUNTED FROM WHAT LANDED, never from what was intended.
    for s = 1:numel(keptStmts)
        id = keptStmts{s}.base.id;
        if ~isKey(stmtSurvived, id); continue; end
        appended{end+1} = stmtSurvived(id); %#ok<AGROW>
        report.statements_emitted = report.statements_emitted + 1;
        for r = 1:numel(keptRefIds{s})
            usedRefIds(keptRefIds{s}{r}) = true;
        end
    end
end

% Only the references a SURVIVING statement points at are appended. A reference
% nothing points at is a document that says "some interval, somewhere" -- the
% hollow-document shape, and it would also make `references_emitted` a count of
% intentions rather than of anchors in use.
refKeys = keys(usedRefIds);
for r = 1:numel(refKeys)
    appended{end+1} = refSurvived(refKeys{r}); %#ok<AGROW>
    report.references_emitted = report.references_emitted + 1;
end

if isempty(appended)
    result.valid_interval_decompose = report;
    return;
end

result.migrated = [docs, appended];
report.documents_appended = numel(appended);
result.summary = recountSummary(result);
result.valid_interval_decompose = report;
end

% ===================== the anchor ==========================================

function [anchor, why] = resolveAnchor(timeref, docSessionId, epochIdByKey, epochCountByKey)
%RESOLVEANCHOR One v1 `ndi_timereference_struct` -> the epoch document + clock.
%   ANCHOR is a struct {epoch_document_id, clock, tolerance_seconds,
%   session_source}; WHY is '' on success, otherwise the name of the report
%   counter to bump. Returning the counter NAME rather than a boolean is what
%   keeps every refusal reason distinct -- a single `false` collapses eight
%   different facts into one.
anchor = struct('epoch_document_id', '', 'clock', '', ...
    'tolerance_seconds', [], 'session_source', '');
why = 'refused_no_anchor_block';
if ~isstruct(timeref) || isempty(timeref)
    return;
end

clockName = charField(timeref, {'clocktypestring', 'clockTypeString'});
if isempty(clockName) || strcmp(clockName, 'no_time')
    % NO TIMES => NO REFERENCE (signed). `no_time` is reachable, not
    % hypothetical: ndi.time.clocktype lists it among its nine values.
    why = 'refused_no_clock';
    return;
end

epochString = charField(timeref, {'epoch'});
if isempty(epochString)
    % timereference.m:71 leaves `epoch` EMPTY whenever the clock does not
    % needsepoch(). There is then no epoch document to anchor to, and inventing
    % a session anchor instead would silently change what the interval is
    % measured against. Refused, counted, source kept.
    why = 'refused_no_epoch_string';
    return;
end

% THE SESSION HALF OF THE KEY. The timeref carries its own `session_ID`
% (timereference.m:110, via ndi_timereference_struct) and the document carries
% `base.session_id`. They are the same session for every markgarbage write we
% can see, but the timeref's is the AUTHORITATIVE one -- it names the session the
% REFERENT lives in -- so it wins where present. Which one was used is counted,
% so "they agreed" and "we fell back" stay distinguishable.
sessionId = charField(timeref, {'session_ID', 'session_id'});
anchor.session_source = 'anchor_session_from_timeref';
if isempty(sessionId)
    sessionId = docSessionId;
    anchor.session_source = 'anchor_session_from_document';
end

key = pairKey(sessionId, epochString);
if ~isKey(epochIdByKey, key)
    why = 'refused_no_epoch_document';
    return;
end
if epochCountByKey(key) > 1
    why = 'refused_ambiguous_epoch';
    return;
end

[bare, tolerance] = deEncodeApprox(clockName);
anchor.epoch_document_id = epochIdByKey(key);
anchor.clock = bare;
anchor.tolerance_seconds = tolerance;
why = '';
end

function tf = sameAnchor(a, b)
%SAMEANCHOR Do two ends resolve to the SAME anchor?
%   Same epoch document, same clock, same stated tolerance. Anything else is the
%   split case, which gets two reference documents (Decision C).
tf = strcmp(a.epoch_document_id, b.epoch_document_id) ...
    && strcmp(a.clock, b.clock) ...
    && isequal(a.tolerance_seconds, b.tolerance_seconds);
end

function [bare, toleranceSeconds] = deEncodeApprox(clockName)
%DEENCODEAPPROX Split NDI's `approx_` prefix into a bare clock + a TOLERANCE.
%   CHANGE 4 of the signed time model. The magnitude is stated by NDI only in
%   prose -- +ndi/+time/clocktype.m:21,23,26 say "within 5 seconds" / "within 5s"
%   / "within 5 s" -- so the 5 is TRANSCRIBED, not invented. Folding the prefix
%   into a boolean would throw the number away, which is the error CHANGE 4
%   records.
%
%   Returns [] (not 0) when the clock states no tolerance, so "no stated
%   tolerance" and "stated as zero" stay distinguishable.
%
%   DUPLICATED FROM +migrators_j/private/jEpochClockReferences.m, and said out
%   loud rather than hidden: `private/` is not reachable from +did2/+convert, and
%   the two are twelve lines. If a third copy is ever wanted, that is the signal
%   to promote it to a shared function instead.
bare = clockName;
toleranceSeconds = [];
if numel(clockName) >= 7 && strcmp(clockName(1:7), 'approx_')
    bare = clockName(8:end);
    toleranceSeconds = 5;
end
end

% ===================== body builders =======================================

function ref = makeReference(src, anchor, startSeconds, durationSeconds)
%MAKEREFERENCE One `relative_reference` anchored to an epoch document.
%   DURATIONSECONDS empty => an INSTANT (the split-anchor case). `relation` is
%   deliberately OMITTED: it is optional and carries the qualitative Allen
%   relation used when there is NO metric offset, and here the offsets are the
%   whole content.
ref = struct();
ref.document_class = struct('class_name', 'relative_reference', ...
    'class_version', '2.0.0', ...
    'superclasses', struct('class_name', 'time_reference', ...
        'class_version', '4.0.0'), ...
    'schema_version', 'V_eta');
ref.depends_on = struct('name', {'relative_to'}, ...
    'value', {anchor.epoch_document_id});
ref.base = freshBase(src, 'migrated_valid_interval_anchor');
if ~isempty(anchor.tolerance_seconds)
    % Written ONLY when the source clock stated a tolerance. An empty tolerance
    % cell would assert "the timeline is good to 0 s", which the source never
    % said; with no block, ensureClassBlocks pads it.
    ref.time_reference = struct('clock_tolerance', ...
        durationCell(anchor.tolerance_seconds));
end
value = struct('clock', struct('node', '', 'name', anchor.clock), ...
    'start', durationCell(startSeconds));
if ~isempty(durationSeconds)
    value.duration = durationCell(durationSeconds);
end
ref.relative_reference = struct('value', value);
end

function body = makeLogicalObservation(src, elementId, isValid, refIds, methodTerm)
%MAKELOGICALOBSERVATION One boolean statement about one element-subject.
%
%   `subject_id` IS THE ELEMENT, UNQUALIFIED. `element_id` on the v1 document
%   names the element (in practice a PROBE -- savevalidinterval errors on
%   anything else, markgarbage.m:76-78), and `migrators_j/element.m` promotes
%   elements to subjects with their ids PRESERVED, so the edge lands without a
%   lookup. This is the recurring trap CLAUDE.md names: `element_id` is NOT a
%   dangling non-subject edge.
%
%   ISVALID IS ALWAYS TRUE ON THE MIGRATION PATH, and that is a property of the
%   SOURCE, not a default. did_v1 encoded validity in the CLASS NAME, so "this
%   stretch is bad" was expressible only as absence -- markgarbage.m:40 is its
%   own author writing the gap down ("it would be great to have a
%   'markinvalidinterval' companion"). The parameter exists because the CLASS
%   can say false; nothing in v1 can.
%
%   THE STATEMENT CARRIES NO FIELDS OF ITS OWN. `logical_observation` declares
%   none (`sequence` went with HAZARD 2), so everything here is inherited:
%   `subject_id` + `variable` from subject_statement, `method` +
%   `time_reference_#` from subject_interaction, the boolean from `logical`.
%   THE SEMANTIC IS IN `variable`, NOT IN THE CLASS NAME -- `data validity` --
%   which is the whole reason the class is `logical` and not `validity`.
%
%   NO `sample_time`: there is no sampling here (the value is per INTERVAL), and
%   `kind: point` would assert a cadence the source never described.
%   NO `derived_from_#`: see HAZARD 3 in the header -- leaving it empty is what
%   keeps both answers to the inheritance question buildable.
%
%   METHODTERM IS STATED, NEVER BLANK. It is the epistemic stance -- this value
%   came from a curatorial judgement, not from an instrument -- and it arrives
%   already resolved from `curationMethod`, which is where the naming argument
%   and the two evidence branches live. See "THE VERB" in the header.
%
%   REFIDS are the `relative_reference` documents this statement is anchored to
%   -- ONE in the agreeing case, TWO in the split case (Decision C). They are
%   numbered `time_reference_1..N` in the order given, which for the split case
%   is (start anchor, end anchor). #52 has not decided what a bare index MEANS
%   when a family has more than one member, so that ordering is a convention
%   this pass records rather than a rule it can rely on -- which is exactly what
%   #52 exists to fix, and why `split_anchor_intervals` is counted.
body = struct();
body.document_class = struct('class_name', 'logical_observation', ...
    'class_version', '1.0.0', ...
    'superclasses', supersOf({'subject_observation', 'logical'}), ...
    'schema_version', 'V_eta');
deps = struct('name', {'subject_id'}, 'value', {elementId});
for r = 1:numel(refIds)
    deps(end+1) = struct('name', sprintf('time_reference_%d', r), ...
        'value', refIds{r}); %#ok<AGROW>
end
body.depends_on = deps;
body.base = freshBase(src, 'migrated_valid_interval');
body.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'data validity'), ...
    'storage_mode', 'inline');
body.subject_interaction = struct('method', methodTerm);
body.subject_observation = struct();
% NO NESTED CELL: `logical.value` is a bare `boolean` array. The old
% `validity` shape wrapped it in a one-field struct -- `value.value`, a wrapper
% around nothing -- and the composites that DO nest are the ones carrying
% provenance (canonical + source_unit + source_value, or count's semantic
% unit), which a truth value has none of.
body.logical = struct('value', logical(isValid));
end

function name = curationMethodName()
%CURATIONMETHODNAME The ONE spelling of the verb, in exactly one place.
%   T11: one canonical spelling per concept. Every emitter and every test reads
%   the name from here, so a rename is a one-line change that the pinning test
%   in testValidIntervalDecompose.m then fails loudly on rather than a silent
%   drift into two spellings.
%
%   `curation`, and NOT `markgarbage` / `manual curation` / `measurement`. The
%   full rejection list with its reasons is in "THE VERB" in the file header;
%   it is there and not here because it is an argument, not a value.
name = 'curation';
end

function [term, evidence] = curationMethod(src)
%CURATIONMETHOD The verb for a validity statement, and WHERE IT CAME FROM.
%
%   TERM is the staged ontology term `{node: '', name: 'curation'}` -- the same
%   empty-node staging `variable` and `clock` use here, so the debt joins the
%   one ratchet rather than pretending to be resolved. NO CURIE IS INVENTED.
%
%   EVIDENCE is the name of the report counter to bump, and the two branches are
%   about WHERE THE CLAIM RESTS, not about what it says:
%
%     method_from_app_block      the source names a producer. The v1 `app` block
%                                as the WRITER makes it -- markgarbage.m sets
%                                `name = 'ndi_app_markgarbage'` and
%                                ndi.app/newdocument (app.m:105-114) copies it
%                                to `app.name`, which did2.convert.
%                                universalRenames:152 then renames to `app_name`
%                                -- so both spellings are read, per the standing
%                                nested-read rule.
%     method_from_class_default  no app block, or an `app_name` that is present
%                                but EMPTY (the template ships ""). Nothing in
%                                the document names a producer, so the verb is
%                                asserted from the CLASS: nothing but
%                                markgarbage writes `valid_interval` (the writer
%                                grep at the top of this file). It is a fall
%                                back to a CONSTANT and it is counted as one.
%
%   THE VALUE IS THE SAME IN BOTH BRANCHES, and that is deliberate rather than a
%   missing feature: the document names a TOOL and never a verb, so there is no
%   term in it to copy. A tool name in `method` would be the T13/T11 error the
%   header lists first. What the branch buys is that a `valid_interval` written
%   by something OTHER than markgarbage lands in the app-block branch with a
%   different `app_name` on its retained source, so the distinction stays
%   recoverable instead of being flattened into one unconditional constant.
%
%   Read through `subStruct` rather than off `src.app` directly: it is the
%   helper that already takes element (1) of a non-scalar block, and a v1 `app`
%   block that arrived as a 1xN struct array would otherwise make `charField`
%   index a comma-separated list.
term = struct('node', '', 'name', curationMethodName());
if isempty(charField(subStruct(src, {'app'}), {'app_name', 'name'}))
    evidence = 'method_from_class_default';
else
    evidence = 'method_from_app_block';
end
end

function base = freshBase(src, name)
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isstruct(src) && isfield(src, 'base') && isstruct(src.base)
    if isfield(src.base, 'session_id'); sessionId = src.base.session_id; end
    if isfield(src.base, 'datestamp') && ~isempty(src.base.datestamp)
        ds = src.base.datestamp;
    end
end
base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end

function supers = supersOf(chain)
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
end

function c = durationCell(seconds)
%DURATIONCELL The T14 one-`value` duration cell: canonical + source provenance.
%   NDI times are already in SECONDS, so `seconds` and `source_value` coincide
%   and `source_unit` is 's'. `approximate` is FALSE, and that is a claim about
%   the NUMBER: the t0/t1 the writer stored are exact as recorded. Whatever slop
%   the clock has is on the TIMELINE and is carried by `clock_tolerance`.
c = struct('seconds', double(seconds), ...
    'source_unit', 's', ...
    'source_value', double(seconds), ...
    'approximate', false);
end

% ===================== shape readers =======================================

function entries = intervalEntries(blk)
%INTERVALENTRIES The intervals in a `valid_interval` block, IN SOURCE ORDER.
%
%   `valid_interval` is the ONLY one of NDI's 91 production templates whose
%   property block is a JSON ARRAY rather than an object, and the writer APPENDS
%   (markgarbage.m:89), so a probe with three marked intervals is ONE document
%   holding a 3-element struct array. Accumulation is the normal path, not an
%   edge case.
%
%   THREE SHAPES ARE ACCEPTED, and none of them is a guess: a 1xN struct array
%   (what the writer produces), a cell of scalar structs (what jsondecode
%   returns when the entries are not field-homogeneous), and a scalar struct
%   (the single-interval document, which is also the template's own shape).
%   Order is preserved exactly in all three; nothing here sorts.
entries = {};
if isempty(blk)
    return;
end
if iscell(blk)
    for k = 1:numel(blk)
        if isstruct(blk{k}) && isscalar(blk{k}); entries{end+1} = blk{k}; end %#ok<AGROW>
    end
    return;
end
if ~isstruct(blk)
    return;
end
for k = 1:numel(blk)
    entries{end+1} = blk(k); %#ok<AGROW>
end
end

function s = subStruct(e, names)
%SUBSTRUCT First present sub-struct among NAMES ([] if none).
%   The snake/camelCase fallback is the standing migrator rule, applied here
%   even though these particular names have no camel variant: the rule exists so
%   the next nested read does not have to remember it.
s = [];
for k = 1:numel(names)
    if isfield(e, names{k}) && isstruct(e.(names{k}))
        s = e.(names{k});
        if ~isscalar(s) && ~isempty(s); s = s(1); end
        return;
    end
end
end

function v = numericField(s, names)
v = [];
for k = 1:numel(names)
    if isfield(s, names{k})
        x = s.(names{k});
        if isnumeric(x) && ~isempty(x); v = double(x(1)); end
        return;
    end
end
end

function c = charField(s, names)
c = '';
if ~isstruct(s) || isempty(s); return; end
for k = 1:numel(names)
    if isfield(s, names{k})
        x = s.(names{k});
        if ischar(x); c = x; elseif isstring(x) && isscalar(x); c = char(x); end
        return;
    end
end
end

function v = depValue(body, name)
%DEPVALUE The target id of dependency NAME on BODY, or ''.
%   Read tolerantly: a raw migrator body spells the target `value`, a body that
%   has been through did2.convert.universalRenames spells it `document_id`, and
%   an unconverted v1 body spells it `id` -- the same three keys
%   +migrators_j/private/jEpochDocId.m reads, for the same reason.
v = '';
if ~isfield(body, 'depends_on') || isempty(body.depends_on); return; end
deps = body.depends_on;
if isstruct(deps); items = num2cell(deps(:)'); elseif iscell(deps); items = deps;
else; return; end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name); continue; end
    for key = {'document_id', 'value', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            v = char(d.(key{1}));
            return;
        end
    end
    return;
end
end

function blk = blockOf(body, className)
blk = [];
if isstruct(body) && isfield(body, className)
    blk = body.(className);
end
end

function cn = classNameOf(b)
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function v = baseField(b, name)
v = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, name)
    x = b.base.(name);
    if ischar(x); v = x; elseif isstring(x) && isscalar(x); v = char(x); end
end
end

function k = pairKey(sessionId, epochString)
%PAIRKEY The anchor key, length-prefixed so no separator can be forged.
%   Identical to did2.convert.epochMint/pairKey ON PURPOSE: this pass looks up
%   what that pass minted, and two different key functions over one index is a
%   silent miss, not an error.
k = sprintf('%d:%s|%s', numel(sessionId), sessionId, epochString);
end

% ===================== validation plumbing =================================

function [survived, quarantined] = validateBodies(newBodies, options)
%VALIDATEBODIES Push bodies through v1_to_v2 and return what survived, by id.
%   SURVIVED is a containers.Map from base.id to the produced did2.document, so
%   a caller can ask "did THIS body land" rather than matching on position -- a
%   quarantined body leaves no slot, and the id is the one thing this pass
%   guarantees is unchanged. Mirrors the helper of the same name in
%   did2.convert.resolveLawnPlateSubjects.
survived = containers.Map('KeyType', 'char', 'ValueType', 'any');
quarantined = {};
if isempty(newBodies); return; end
out = did2.convert.v1_to_v2(newBodies, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);
for k = 1:numel(out.migrated)
    try
        survived(char(out.migrated{k}.get('base.id'))) = out.migrated{k};
    catch
    end
end
quarantined = out.quarantine;
end

function result = appendQuarantine(result, quarantined)
if isfield(result, 'quarantine') && ~isempty(result.quarantine)
    result.quarantine = [result.quarantine, quarantined];
else
    result.quarantine = quarantined;
end
end

function summary = recountSummary(result)
summary = struct();
if isfield(result, 'summary') && isstruct(result.summary); summary = result.summary; end
summary.migrated_count = numel(result.migrated);
if isfield(result, 'quarantine'); summary.quarantine_count = numel(result.quarantine); end
byClass = struct();
for k = 1:numel(result.migrated)
    fieldName = matlab.lang.makeValidName(result.migrated{k}.className());
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end
