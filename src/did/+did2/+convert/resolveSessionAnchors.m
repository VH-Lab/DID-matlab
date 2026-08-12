function [result, report] = resolveSessionAnchors(result, options)
%RESOLVESESSIONANCHORS Fold the session_* time references into relative_reference.
%
%   [RESULT, REPORT] = did2.convert.resolveSessionAnchors(RESULT) takes the
%   struct returned by did2.convert.v1_to_v2 (after resolveDeferredBaths /
%   resolveDatasetEntities) and rewrites every `session_relative_reference` and
%   `session_bounded_reference` document into a `relative_reference` anchored to
%   the SESSION DOCUMENT, with its `base.id` PRESERVED.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: session_relative_reference, session_bounded_reference
%   BATCH-PASS-EMITS: session_relative_reference -> document: relative_reference
%   BATCH-PASS-EMITS: session_bounded_reference -> document: relative_reference
%
%   NEITHER CONSUMED NAME IS A did_v1 SOURCE CLASS. Both are DID-side
%   intermediates -- V_zeta/V_eta time_reference classes that the per-document
%   migrators and resolveDeferredBaths mint on the way through -- so neither
%   matches a row of the v1 coverage ledger and neither can move a rung. The
%   declaration is written anyway because the alternative is a pass with no
%   declaration, which is the state this mechanism exists to make impossible.
%   ---------------------------------------------------------------------
%
%   ---------------------------------------------------------------------
%   STATUS: EXECUTED ON A FULL CORPUS, 2026-08-11. Wired 2026-08-10 into all
%   four call sites; this header said "NEVER EXECUTED" until the run below,
%   which is the stale-header defect this repo keeps finding, in the direction
%   that understates. Measured, corpus run 31441923369 (`caf710b`), the
%   cross-corpus rollup over 6 corpora and 627,526 documents:
%
%       session_anchor_fold   ran in 6 of 6 report(s); 0 absent, 0 FAILED
%           640,651  documents inspected        0  UNREADABLE
%           106,639  anchors seen  =  86,228 session_relative_reference
%                                   + 20,411 session_bounded_reference
%           106,639  FOLDED to relative_reference
%                 0  REFUSED (total), across all six refusal reasons
%                 0  QUARANTINED by the fold
%
%   So the fold is exercised, not merely wired, and it refused nothing. Note
%   what that does NOT establish: the corpora are a SAMPLE, and `deletion gate:
%   refused_total=0, surviving session_*_reference in by_class=0` is one
%   corpus's evidence, not authorisation to delete the retiring classes.
%
%   AND IT DID NOT ESTABLISH THAT THE FOLD WAS CORRECT, which is a second and
%   larger caveat, added 2026-08-11 after the fact. All 20,411
%   `session_bounded_reference` documents in that rollup were folded WITH THEIR
%   onset/offset WINDOW DISCARDED -- see the REPAIR note on `cellField` below.
%   Every counter above is accurate and every one of them was blind to it: the
%   documents folded, so `anchors_folded` rose; no refusal fired, so
%   `refused_total` stayed 0; the result validated, so `fold_quarantined` stayed
%   0. A clean row of counters is evidence that the pass RAN, not that it did
%   the right thing. The repair landed after this run, so THESE NUMBERS PREDATE
%   IT -- a re-run is what re-measures them, and `refused_negative_extent` is
%   reachable for the first time.
%
%   THEY PREDATE A SECOND CHANGE TOO, 2026-08-11: there are now NINE refusal
%   reasons, not the six that rollup was summed over, plus ten bounded-extent
%   counters NO RUN HAS EVER REPORTED. The line "0 REFUSED (total), across all
%   six refusal reasons" is a correct quote of that run and is left as one; it
%   is not a statement about this file as it stands. Corpus run 31508009545 was
%   in flight from an older commit while this was written and contains none of
%   it.
%
%   The two classes it folds are exactly these, and no others --
%   `epoch_*`/`event_*`/`utc_reference` are NOT touched here. That mattered
%   because `ndi.migrate.internal.stimulusBathToBath` mints a populated
%   `epoch_bounded_reference` on the NDI path -- in its `if mintReference`
%   block. Cited by BLOCK NAME rather than by line, because the number this
%   sentence used to carry (:70-81) pointed into that file's OUTPUT DOCSTRING,
%   which merely describes the body, and not at the code that builds it; a line
%   citation across repositories goes stale on the next comment edit, and this
%   one did.
%
%   THE SECOND HALF OF THAT SENTENCE -- "that nothing folds" -- IS NO LONGER
%   TRUE, and is corrected here on positive evidence, not on a failed search.
%   `ndi.migrate.internal.epochAnchorFold` was added on this same branch
%   (NDI-matlab e3795c2f7, 2026-08-11) and is CALLED, not merely present:
%
%       $ git -C NDI-matlab log --diff-filter=A --format='%H %ad' --date=short \
%             -- src/ndi/+ndi/+migrate/+internal/epochAnchorFold.m
%       e3795c2f746e9abdeb63acb94bab73134b1cf3fc 2026-08-11
%
%       $ grep -n "resolveEpochAnchorFold" NDI-matlab/src/ndi/+ndi/+migrate/local.m
%       686:                resolveEpochAnchorFold(convertResult, epochMintReport, options);
%       1405:function [convertResult, report] = resolveEpochAnchorFold(convertResult, ...
%
%   It runs as step (5b) of ndi.migrate.local's V_eta second pass, immediately
%   after did2.convert.epochMint (step 5) and immediately before THIS pass
%   (step 7), and it folds to `relative_reference` with base.id PRESERVED, the
%   same guarantee this file makes.
%
%   WHAT IS STILL TRUE, AND IS THE REASON THIS PARAGRAPH IS NOT SIMPLY DELETED:
%   the fold is NDI-side, so it does not run in the DID corpus gate at all --
%   that gate runs the coarse did2.convert.resolveDeferredBaths, which NDI
%   deliberately substitutes stimulusBathToBath for, and which emits
%   `session_relative_reference` (resolveDeferredBaths.m:188,237) rather than an
%   epoch-bounded one. So no corpus number in this header speaks to the
%   epoch-bounded class, and none should be read as doing so.
%
%   THE FOLD IS NOT UNCONDITIONAL. epochMint refuses to mint an `epoch` for a
%   session id with no `session` DOCUMENT in the batch (epochMint.m:349-353,
%   `skipped_no_session_document`), and epochAnchorFold then refuses that anchor
%   (`refused_no_epoch_document`) and LEAVES IT AS AN `epoch_bounded_reference`,
%   which ndi.migrate.local writes to the destination database like any other
%   migrated document. Both branches are pinned end-to-end, from the real
%   emitter through the real pipeline, by
%   NDI-matlab tests/+ndi/+unittest/+migrate/TestMigrateLocalEta.m.
%   ---------------------------------------------------------------------
%   Written 2026-08-10 for #65 in an environment with NO MATLAB, so no line here
%   has been run. THAT IS STILL TRUE and is the main thing to know about it.
%
%   HEADER CORRECTED THE SAME DAY. This block previously read "NOT WIRED INTO
%   ANY PIPELINE", and the wiring act that followed did not update it -- which
%   is the stale-header defect exactly (a document's own summary disagreeing
%   with the record below it). It is now called from runCorpusDiscovery,
%   testCorpusPRED, testFixtureCorpus and ndi.migrate.local (V_eta second pass,
%   step 7), immediately after did2.convert.epochMint in all four.
%
%   THE AUTHOR'S CAUTION IS PRESERVED, NOT OVERRULED. They declined to wire it
%   because they could not run it and turning it on red-gates the corpus for
%   everyone if it is wrong. What changed is not that judgement but the shape of
%   the wiring, which is why turning it on is now the smaller risk:
%
%     * at the two report-writing call sites it runs under
%       did2.unittest.helpers.runBatchPass, so a throw records
%       `session_anchor_fold.pass_failed` and leaves every document in pass-1
%       form INSTEAD of destroying the corpus report the run exists to produce;
%       the hard gates then assert on that field, so the failure is loud.
%     * ndi.migrate.local wraps it in its own try/catch like every sibling
%       sub-pass.
%     * the pass REFUSES rather than guesses (see below), and a corpus with no
%       `session` document therefore refuses every anchor and changes nothing --
%       which is the state the corpus is green in today.
%
%   Read tests/+did2/+unittest/testTimeReferenceCollapse.m and
%   tests/+did2/+unittest/testBatchPassWiring.m before trusting any of that;
%   neither has been run either.
%
%   TO UNWIRE IT AGAIN: remove the four calls AND add a header line whose text
%   is the token WIRING-EXEMPT followed by a colon and the reason.
%   tests/+did2/+unittest/testBatchPassWiring.m reads that marker and prints the
%   reason, so an unwired pass stays a STATED decision with a justification
%   attached rather than an omission nothing can see. (The token is deliberately
%   not written here in its triggering form -- a doc comment that armed the
%   escape hatch it was describing would silently disable the gate, which is
%   this project's whole recurring failure in miniature.)
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A BATCH PASS AND NOT A MIGRATOR CHANGE
%   ---------------------------------------------------------------------
%   The obvious fix -- make jSessionAnchor emit `relative_reference` -- CANNOT
%   WORK, and the reason is structural rather than incidental:
%
%     * `relative_reference.relative_to` is REQUIRED (team call, fork A of
%       V_eta_time_reference_model_plan.md).
%     * A pass-1 migrator holds `preBody.base.session_id`.
%     * The edge needs the session DOCUMENT's `base.id`, and those are DIFFERENT
%       values. NDI mints the document id fresh --
%         NDI-matlab +ndi/document.m:57-58
%           ndiido = ndi.ido();  document_properties.base.id = ndiido.id();
%       -- while `base.session_id` is stamped separately --
%         NDI-matlab +ndi/session.m:215
%           inputs = cat(2,varargin,{'base.session_id', ndi_session_obj.id()});
%       -- and ndi.session.dir:123 reads the session's identity back out of
%       `session_doc.document_properties.base.session_id`, not out of base.id.
%
%   Mapping one to the other means scanning the batch for the `session` document
%   that CLAIMS that session_id. That is a corpus-wide grouping; a
%   single-document migrator sees one document. Same wall as jEpochDocId,
%   distance_metadata and ontology_label.
%
%   The alternative -- emit `relative_to` empty in pass 1 -- was rejected, not
%   overlooked. `+did2/+validate/references.m:90` SKIPS empty edges, so 127,719
%   husks would validate clean and no gate would see them: the single largest
%   instance of the invented-empty-edge pattern this project has recorded (the
%   previous record holder was 11,440).
%
%   ---------------------------------------------------------------------
%   WHY THE ID IS PRESERVED
%   ---------------------------------------------------------------------
%   Every migrated `subject_interaction` / `directed_relation` points at its
%   anchor by id through `time_reference_#`. Minting a replacement document
%   would dangle every one of those edges -- the 11,448-orphan dissolution
%   failure, at ten times the size. So this is the id-preserving 1 -> 1 fold the
%   calculator family already proved on real data (Soph run #2, 0 orphans): the
%   CLASS changes, the id does not, and `must_refer` is existence-only.
%
%   ---------------------------------------------------------------------
%   WHAT IT REFUSES TO DO, AND COUNTS INSTEAD
%   ---------------------------------------------------------------------
%   A document it cannot fold HONESTLY is LEFT EXACTLY AS IT IS and counted. It
%   is never dropped, never given an empty required edge, and never guessed at:
%
%     no session_id on the anchor           -> refused_no_session_id
%     no `session` document claims that id  -> refused_no_session_document
%     two `session` documents claim it      -> refused_ambiguous_session
%     relation == 'concurrent_with'         -> refused_ambiguous_relation
%     relation not in the v1 enum           -> refused_unknown_relation
%     end < start                           -> refused_negative_extent
%     start/end in a unit it cannot read    -> refused_unreadable_extent_unit
%     start/end is not a duration cell      -> refused_malformed_extent
%     an `end` with no readable `start`     -> refused_extent_without_start
%
%   THE LAST THREE WERE ADDED 2026-08-11 AND THEY ARE A BEHAVIOUR CHANGE, so the
%   reasoning is written here rather than left in a commit message. Before them,
%   a bounded body whose `start`/`end` could not be READ still FOLDED: `cellField`
%   returned [] for three unrelated situations the caller could not tell apart
%   (field absent / not a duration cell / a unit `isSecondsUnit` refuses),
%   `value.start` was never set, `value.duration` was never computed, and NO
%   COUNTER MOVED. `refused_total` stayed 0 and the window was gone. That is the
%   same instrument shape as the 20,411-document loss recorded under `cellField`
%   below -- an absent answer wearing a green badge -- and it is the reason the
%   repair to `cellField` alone was not enough.
%
%   REFUSING RATHER THAN FOLDING-AND-COUNTING was chosen for three reasons, the
%   third being decisive:
%     1. It is what this section already says the pass does. `refused_negative_extent`
%        refuses a whole document over an extent it will not store; an extent it
%        cannot READ is the same case, not a new one.
%     2. A refused body is LEFT EXACTLY AS IT IS, so it stays a
%        `session_bounded_reference` -- visible as unmigrated in `by_class`, with
%        its window intact for a later pass. A folded-and-counted body is a
%        `relative_reference` with no window: the data is gone and only a number
%        in a report remembers it.
%     3. THE DELETION GATE. The six retiring classes may leave V_eta only when
%        `refused_total == 0` AND no session_*_reference survives in `by_class`.
%        Fold-and-count satisfies BOTH halves of that gate while dropping
%        windows, so it would silently authorise deleting the classes whose
%        documents were being damaged. Refusal holds the gate shut, which is
%        exactly what a gate is for.
%   The cost is a behaviour change that is provably empty today: the only emitter
%   of `session_bounded_reference` in this repository hard-codes the literal 's'
%   (ontology_table_row.m, `durationSeconds`), so no migrated document can reach
%   any of the three. That is what makes this cheap to do now and expensive to do
%   after a unit arrives.
%
%   WHAT IS NOT REFUSED, and must not be conflated with the above: a bounded body
%   whose `start`/`end` are simply ABSENT states no window, loses nothing by
%   folding without one, and folds -- counted `bounded_no_window_stated`. The
%   whole point of the status output on `cellField` is that "nothing was there"
%   and "something was there and I could not read it" stopped being the same [].
%
%   `concurrent_with` is refused because it is genuinely ambiguous between
%   OWL-Time's intervalEquals and intervalOverlaps -- one of the three defects
%   that put `relation` on an ontology in the first place. Picking one would be
%   inventing a fact.
%
%   THAT IS ALSO THE DELETION GATE. The six retiring reference classes may be
%   removed from V_eta (and `time_reference.is_approximate` with them) only when
%   a corpus run reports `refused_total == 0` AND zero surviving
%   session_*_reference documents in `by_class`. Until then they must stay:
%   deleting a class whose documents still exist is the epochfiles_ingested
%   regression, which cost 2,484 quarantines.
%
%   ---------------------------------------------------------------------
%   THE MAPPING
%   ---------------------------------------------------------------------
%     session_relative_reference { relation }
%        -> relative_reference   { relation: <OWL term> }              no metric
%     session_bounded_reference  { relation, start, end }
%        -> relative_reference   { relation, start, duration = end-start }
%
%   `duration` rather than `end` is CHANGE 1 of the signed walkthrough
%   (V_eta_time_reference_model_plan.md:468, TEAM-SIGN-OFF [time_reference],
%   jess@walthamdatascience.com / 2026-08-08): anchor and extent are independent
%   facts. `time_reference.is_approximate` is DROPPED (CHANGE 2) -- it was a
%   hardcoded `true` at all eleven writers, saying "we do not know exactly when",
%   which having no start and no duration already says. THE ABSENCE IS THE
%   IMPRECISION.
%
%   Options mirror the sibling passes (Validate / SchemaCache / TargetVersion).
%
%   See also: did2.convert.v1_to_v2, did2.convert.epochMint,
%   did2.convert.resolveDatasetEntities, did2.convert.resolveDeferredBaths.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% DENOMINATOR FIRST, and unconditionally. Every field is defined before a single
% document is read, so "did not run" and "ran and found nothing" are different
% readings of the same struct rather than the same reading. This is Operating
% Rule 5, and silentLoss is what happens without it.
%
% THE BOUNDED-EXTENT GROUP, added 2026-08-11, exists because Rule 5 applies to
% the three new extent refusals too. `refused_unreadable_extent_unit: 0` printed
% beside `bounded_extents_examined: 0` says NOTHING, and must be readable as
% saying nothing.
%
%   bounded_extents_examined     THE DENOMINATOR of every extent counter, and it
%                                is NOT `anchors_bounded`: an anchor refused
%                                earlier (no session id / no session document /
%                                ambiguous session / ambiguous or unknown
%                                relation) never reaches the extent read at all.
%                                The two differ by exactly those refusals.
%   bounded_with_start_field     how many carried the field AT ALL, whatever its
%   bounded_with_end_field       status -- so "no window was ever there" and "a
%                                window was there and was not carried" are
%                                separable from the report alone.
%   bounded_blank_extent_cells   A CELL COUNT, NOT A DOCUMENT COUNT. Do not sum
%                                it with the rows below. One body can contribute
%                                two.
%   bounded_window_carried       the three mutually exclusive outcomes for a body
%   bounded_start_only_carried   that was NOT refused, so "the window survived",
%   bounded_no_window_stated     "half of it survived" and "there was none to
%                                survive" are three numbers rather than one.
%                                Counted at the fold DECISION, i.e. before
%                                validation, so they are comparable with the
%                                refusals -- unlike `anchors_folded`, which is
%                                recounted after quarantine at the end.
%
% THE IDENTITY THEY SATISFY, asserted by testTimeReferenceCollapse and worth
% checking by eye in any corpus report: every examined extent lands in exactly
% one of seven buckets.
%
%   bounded_extents_examined  ==  bounded_window_carried
%                               + bounded_start_only_carried
%                               + bounded_no_window_stated
%                               + refused_negative_extent
%                               + refused_unreadable_extent_unit
%                               + refused_malformed_extent
%                               + refused_extent_without_start
report = struct( ...
    'documents_inspected',          0, ...
    'documents_unreadable',         0, ...
    'session_documents_seen',       0, ...
    'anchors_seen',                 0, ...
    'anchors_relative',             0, ...
    'anchors_bounded',              0, ...
    'anchors_folded',               0, ...
    'refused_no_session_id',        0, ...
    'refused_no_session_document',  0, ...
    'refused_ambiguous_session',    0, ...
    'refused_ambiguous_relation',   0, ...
    'refused_unknown_relation',     0, ...
    'refused_negative_extent',      0, ...
    'refused_unreadable_extent_unit', 0, ...
    'refused_malformed_extent',     0, ...
    'refused_extent_without_start', 0, ...
    'refused_total',                0, ...
    ... % --- the bounded-extent denominator (see the block above) ----------
    'bounded_extents_examined',     0, ...
    'bounded_with_start_field',     0, ...
    'bounded_with_end_field',       0, ...
    'bounded_blank_extent_cells',   0, ...
    ... % --- what the fold actually carried forward ------------------------
    'bounded_window_carried',       0, ...
    'bounded_start_only_carried',   0, ...
    'bounded_no_window_stated',     0, ...
    'fold_quarantined',             0, ...
    'ran',                          false);
result.session_anchor_fold = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % relative_reference exists only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.session_anchor_fold = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ---------------------------------------------
% A document this cannot read is COUNTED, never dropped.
bodies = cell(1, n);
anchorClass = repmat({''}, 1, n);
sessionIds = repmat({''}, 1, n);
docIds = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k} = b;
        anchorClass{k} = classNameOf(b);
        sessionIds{k} = baseField(b, 'session_id');
        docIds{k} = baseField(b, 'id');
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- index the session documents ------------------------------------------
% base.session_id -> the session document's base.id, plus a count so a session
% id claimed by two documents is REFUSED rather than guessed at.
sessionDocId = containers.Map('KeyType', 'char', 'ValueType', 'char');
sessionDocCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~strcmp(anchorClass{k}, 'session'); continue; end
    report.session_documents_seen = report.session_documents_seen + 1;
    sid = sessionIds{k};
    if isempty(sid) || isempty(docIds{k}); continue; end
    if isKey(sessionDocCount, sid)
        sessionDocCount(sid) = sessionDocCount(sid) + 1;
    else
        sessionDocCount(sid) = 1;
        sessionDocId(sid) = docIds{k};
    end
end

% --- fold every anchor we can fold honestly --------------------------------
changedIdx = [];
rebuilt = {};
for k = 1:n
    isRelative = strcmp(anchorClass{k}, 'session_relative_reference');
    isBounded  = strcmp(anchorClass{k}, 'session_bounded_reference');
    if ~isRelative && ~isBounded; continue; end
    report.anchors_seen = report.anchors_seen + 1;
    if isRelative
        report.anchors_relative = report.anchors_relative + 1;
    else
        report.anchors_bounded = report.anchors_bounded + 1;
    end

    blk = blockOf(bodies{k}, anchorClass{k});
    sid = sessionIds{k};
    if isempty(sid)
        report.refused_no_session_id = report.refused_no_session_id + 1;
        continue;
    end
    if ~isKey(sessionDocId, sid)
        report.refused_no_session_document = report.refused_no_session_document + 1;
        continue;
    end
    if sessionDocCount(sid) > 1
        report.refused_ambiguous_session = report.refused_ambiguous_session + 1;
        continue;
    end

    relationName = charField(blk, {'relation'});
    if isempty(relationName)
        % `session_bounded_reference.relation` is mustBeNonEmpty:false with
        % default 'during', so an absent one IS 'during' by the schema's own
        % declaration -- read, not assumed.
        relationName = 'during';
    end
    [term, verdict] = owlTimeTerm(relationName);
    switch verdict
        case 'ambiguous'
            report.refused_ambiguous_relation = ...
                report.refused_ambiguous_relation + 1;
            continue;
        case 'unknown'
            report.refused_unknown_relation = report.refused_unknown_relation + 1;
            continue;
    end

    value = struct('relation', term);
    if isBounded
        % THE STATUS, NOT THE EMPTINESS, DECIDES. `cellField` used to answer
        % with [] for four unrelated situations and the caller could not tell
        % them apart, so a window in a unit the fold refuses to read was
        % indistinguishable from a body that never had one -- and the second
        % reading is the one the code took, silently. It now answers with a
        % reason as well as a value.
        report.bounded_extents_examined = report.bounded_extents_examined + 1;
        [startCell, startStatus] = cellField(blk, 'start');
        [endCell,   endStatus]   = cellField(blk, 'end');
        if ~strcmp(startStatus, 'absent')
            report.bounded_with_start_field = report.bounded_with_start_field + 1;
        end
        if ~strcmp(endStatus, 'absent')
            report.bounded_with_end_field = report.bounded_with_end_field + 1;
        end
        report.bounded_blank_extent_cells = report.bounded_blank_extent_cells ...
            + double(strcmp(startStatus, 'blank')) ...
            + double(strcmp(endStatus, 'blank'));

        % REFUSAL PRECEDENCE, fixed and stated so the counters stay a partition:
        % a refused body moves EXACTLY ONE counter, which is what makes
        % `refused_total` a document count rather than a reason count. A shape
        % this does not understand at all outranks a unit it merely cannot read,
        % because the first is a stronger statement about how little is known.
        %
        % BOTH ENDS ARE TESTED TOGETHER, deliberately. The half-case -- `start`
        % readable, `end` unreadable -- must NOT fold: it would produce a
        % `relative_reference` carrying a start and no duration, which is a
        % silently TRUNCATED window that validates clean and reads, downstream,
        % as an instant that was deliberately recorded as an instant. A truncated
        % window is worse than an unmigrated one, because nothing downstream can
        % tell it happened.
        if strcmp(startStatus, 'malformed') || strcmp(endStatus, 'malformed')
            report.refused_malformed_extent = report.refused_malformed_extent + 1;
            continue;
        end
        if strcmp(startStatus, 'unreadable_unit') || strcmp(endStatus, 'unreadable_unit')
            report.refused_unreadable_extent_unit = ...
                report.refused_unreadable_extent_unit + 1;
            continue;
        end

        % Past this point every cell is 'ok', 'absent' or 'blank', and the last
        % two both mean THE SOURCE STATED NO NUMBER -- so folding without them
        % loses nothing and is not a refusal.
        haveStart = strcmp(startStatus, 'ok');
        haveEnd   = strcmp(endStatus,   'ok');
        if haveEnd && ~haveStart
            % An offset with nothing to offset FROM. `relative_reference.value`
            % has `start` + `duration` and no `end`, so the only ways to keep
            % this document's number are to invent a start of 0 (a fabricated
            % fact -- NO TIMES => NO REFERENCE) or to store the end as if it
            % were a start (a different fabricated fact). Refuse instead, and
            % leave the body carrying its real `end` for a pass that can read it.
            report.refused_extent_without_start = ...
                report.refused_extent_without_start + 1;
            continue;
        end
        if haveStart && haveEnd
            span = secondsOf(endCell) - secondsOf(startCell);
            if span < 0
                report.refused_negative_extent = report.refused_negative_extent + 1;
                continue;
            end
            value.start = startCell;
            % NO source_unit / source_value on the extent. The source wrote two
            % OFFSETS, never a span, so filling a source slot would claim a
            % provenance that does not exist -- the distance_metadata
            % assumed-shape error. `approximate` is true if EITHER end was.
            value.duration = struct('seconds', span, 'approximate', ...
                truthy(fieldOr(startCell, 'approximate', false)) || ...
                truthy(fieldOr(endCell, 'approximate', false)));
            report.bounded_window_carried = report.bounded_window_carried + 1;
        elseif haveStart
            % A start with no end stated. Not a loss -- there was nothing to
            % lose -- but it IS a bounded reference with no bound, so it is
            % counted apart from both the full window and the empty one.
            value.start = startCell;
            report.bounded_start_only_carried = ...
                report.bounded_start_only_carried + 1;
        else
            report.bounded_no_window_stated = report.bounded_no_window_stated + 1;
        end
    end

    b = bodies{k};
    b.document_class = struct( ...
        'class_name',     'relative_reference', ...
        'class_version',  '2.0.0', ...
        'superclasses',   struct('class_name', 'time_reference', ...
                                 'class_version', '4.0.0'), ...
        'schema_version', 'V_eta');
    % THE ID IS NOT TOUCHED. b.base carries the same base.id, so every
    % `time_reference_#` edge pointing here keeps resolving.
    b.depends_on = struct('name', 'relative_to', 'value', sessionDocId(sid));
    % The old class block and the deprecated root flag both go. Leaving either
    % would trip the strict-fields / undeclared-block checks
    % (+did2/+schema/cache.m:695-723) on the new class.
    if isfield(b, anchorClass{k}); b = rmfield(b, anchorClass{k}); end
    if isfield(b, 'time_reference'); b = rmfield(b, 'time_reference'); end
    b.relative_reference = struct('value', value);

    rebuilt{end+1} = b; %#ok<AGROW>
    changedIdx(end+1) = k; %#ok<AGROW>
end

report.anchors_folded = numel(changedIdx);
report.refused_total = report.refused_no_session_id ...
    + report.refused_no_session_document ...
    + report.refused_ambiguous_session ...
    + report.refused_ambiguous_relation ...
    + report.refused_unknown_relation ...
    + report.refused_negative_extent ...
    + report.refused_unreadable_extent_unit ...
    + report.refused_malformed_extent ...
    + report.refused_extent_without_start;

if isempty(changedIdx)
    result.session_anchor_fold = report;
    return;
end

% --- validate through the same door every other pass uses ------------------
% The bodies are tagged schema_version == TargetVersion, so v1_to_v2
% short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate. A body
% that cannot validate lands in `quarantine` and the ORIGINAL is kept, so a bad
% fold degrades to "not folded" rather than to a lost document.
out = did2.convert.v1_to_v2(rebuilt, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);

report.fold_quarantined = numel(out.quarantine);
if ~isempty(out.quarantine)
    if isfield(result, 'quarantine') && ~isempty(result.quarantine)
        result.quarantine = [result.quarantine, out.quarantine];
    else
        result.quarantine = out.quarantine;
    end
end

% Match on base.id, not on position: a quarantined body leaves no slot, and the
% id is the one thing this fold guarantees is unchanged.
producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(out.migrated)
    try
        producedById(char(out.migrated{k}.get('base.id'))) = k;
    catch
    end
end
folded = 0;
for j = 1:numel(changedIdx)
    id = docIds{changedIdx(j)};
    if ~isempty(id) && isKey(producedById, id)
        docs{changedIdx(j)} = out.migrated{producedById(id)};
        folded = folded + 1;
    end
end
report.anchors_folded = folded;

result.migrated = docs;
result.summary = recountSummary(result);
result.session_anchor_fold = report;
end

% ===================== vocabulary ======================================

function [term, verdict] = owlTimeTerm(relationName)
%OWLTIMETERM v1's six-value `relation` enum -> an OWL-Time interval relation.
%
%   The enum was one of the three T8 defects that put `relation` on an ontology:
%   a bare char, covering 6 of Allen's 13, with one member AMBIGUOUS. The five
%   unambiguous members map cleanly; `concurrent_with` does not, and this
%   function says so rather than choosing:
%
%     before          -> time:intervalBefore
%     after           -> time:intervalAfter
%     at_start_of     -> time:intervalStarts
%     at_end_of       -> time:intervalFinishes
%     during          -> time:intervalDuring     <- all 14 live emitter sites
%     concurrent_with -> AMBIGUOUS between intervalEquals and intervalOverlaps
%
%   The `time:` prefix resolves through CURIE_lookups_meta.json (registered with
%   increment 1: http://www.w3.org/2006/time#). OWL-Time is a W3C
%   Recommendation, so these nodes are REAL CURIEs -- unlike the did_clocktype
%   terms, nothing has to be minted and no node is staged empty.
term = struct('node', '', 'name', '');
switch char(relationName)
    case 'before';      term = struct('node', 'time:intervalBefore',   'name', 'intervalBefore');
    case 'after';       term = struct('node', 'time:intervalAfter',    'name', 'intervalAfter');
    case 'at_start_of'; term = struct('node', 'time:intervalStarts',   'name', 'intervalStarts');
    case 'at_end_of';   term = struct('node', 'time:intervalFinishes', 'name', 'intervalFinishes');
    case 'during';      term = struct('node', 'time:intervalDuring',   'name', 'intervalDuring');
    case 'concurrent_with'
        verdict = 'ambiguous';
        return;
    otherwise
        verdict = 'unknown';
        return;
end
verdict = 'ok';
end

% ===================== readers =========================================

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
    if ischar(x) || isstring(x); v = char(x); end
end
end

function blk = blockOf(b, className)
blk = struct();
if isstruct(b) && isfield(b, className) && isstruct(b.(className))
    blk = b.(className);
end
end

function v = charField(s, candidates)
v = '';
for k = 1:numel(candidates)
    if isstruct(s) && isfield(s, candidates{k})
        x = s.(candidates{k});
        if ischar(x) || isstring(x); v = char(x); return; end
    end
end
end

function [c, status] = cellField(blk, name)
%CELLFIELD One duration cell off the old block, plus WHY when there isn't one.
%   A cell that states no time is treated as ABSENT rather than as zero: NO
%   TIMES => NO REFERENCE applies inside a document as well as to whether one
%   exists, and a fabricated 0 s offset is exactly the hollow value the census
%   was built to find.
%
%   ---------------------------------------------------------------------
%   SECOND OUTPUT ADDED 2026-08-11: THE VALUE WAS NEVER THE PROBLEM. THE
%   INDISTINGUISHABILITY WAS.
%   ---------------------------------------------------------------------
%   This returned a bare [] for four situations with nothing in common but
%   their emptiness, and the caller -- which had only `isempty` to ask with --
%   treated all four as "there was no window here". One of them is that. The
%   other three are losses:
%
%     'ok'               a usable duration cell; C is it, with a canonical
%                        `seconds` derived if it was missing (see below).
%     'absent'           the block does not carry the field. NOTHING WAS LOST.
%                        This is the only status that means that, and telling it
%                        apart from the other three is the entire point.
%     'blank'            the field is a duration cell that states no readable
%                        number in either slot -- the schema's blank_value shape
%                        (`buildBlankStructure`, +did2/+schema/cache.m), or a
%                        number in a type this cannot read. Treated by the fold
%                        as stating nothing, and COUNTED so that reading is
%                        visible rather than assumed.
%     'malformed'        the field is present and is NOT a scalar struct, so it
%                        is not a duration cell at all and this cannot say what
%                        it is. Refused by the fold.
%     'unreadable_unit'  the field IS a well-formed cell carrying a real number,
%                        and `isSecondsUnit` will not read its unit. THE VALUE
%                        RETURNED IS STILL [] AND THAT IS DELIBERATE AND
%                        UNCHANGED -- guessing the unit is the distance_metadata
%                        assumed-shape error and would silently rescale real
%                        data. What changed is that the fold is now TOLD, and
%                        refuses the document instead of folding it empty.
%
%   The refusal to guess a unit is correct and stays. The silence about having
%   refused is what was fixed.
%
%   ---------------------------------------------------------------------
%   REPAIR 2026-08-11: "SAYS NOTHING" USED TO MEAN "HAS NO `seconds`", AND
%   THAT DISCARDED EVERY REAL WINDOW IN THE CORPUS.
%   ---------------------------------------------------------------------
%   This function read `seconds` and nothing else. The ONLY emitter of
%   `session_bounded_reference` in the repository does not write it:
%
%       $ sed -n '559,561p' \
%             src/did/+did2/+convert/+migrators_j/ontology_table_row.m
%       function d = durationSeconds(x)
%       d = struct('source_unit', 's', 'source_value', double(x), ...
%           'approximate', false);
%
%   So a POPULATED window -- `{source_unit: 's', source_value: 1249.72}` --
%   returned [], `value.start` was never set, `value.duration` was never
%   computed, and the `span < 0` guard below could not fire because it sits
%   behind `~isempty(startCell) && ~isempty(endCell)`. The document was counted
%   `anchors_folded`, no refusal counter moved, and nothing quarantined: the
%   encounter window vanished with every instrument reporting a clean fold.
%
%   MEASURED SIZE: the cross-corpus rollup in this file's STATUS block counted
%   20,411 `session_bounded_reference` anchors, all FOLDED, 0 REFUSED. Every one
%   of them came from that emitter, so every one lost its onset/offset. What
%   that run established is that the fold RAN and did not refuse; it never
%   established that the extents survived, and nothing was watching them.
%
%   FOUND BY tests/+did2/+unittest/testSessionAnchorEmitterContract.m, which
%   drives the real migrator. testTimeReferenceCollapse could not find it: its
%   bounded fixture is a hand copy of the emitter that ADDED a `seconds` the
%   emitter never wrote, so the fold passed against a shape production never
%   produces.
%
%   THE FIX IS A NORMALISATION, NOT A GUESS. `seconds` is the schema's
%   *"canonical duration value -- the normalised, cross-document comparable
%   number"*; `source_unit`/`source_value` are the lossless source provenance.
%   When the canonical value is absent but the source pair DECLARES seconds,
%   the canonical value is derived from it and the provenance is left untouched.
%   A unit this cannot read is NOT assumed to be seconds -- the cell stays
%   ABSENT, because assuming a unit is the distance_metadata assumed-shape error
%   and would silently rescale real data. Today every duration cell that reaches
%   here is either already canonical (jClockAlignmentBodies, jEpochClockReferences,
%   resolveValidIntervals all write `seconds`) or is `durationSeconds`'s literal
%   's', so the unreadable-unit path has no known population -- it exists so that
%   a future unit cannot be silently misread.
%
%   "NO KNOWN POPULATION" IS EXACTLY WHY IT IS NOW COUNTED, not a reason to
%   leave it uncounted. If the population is truly zero the counter costs
%   nothing and PROVES it, over a stated denominator; if it is not zero, today
%   there is no way to tell. The claim above is also read off the emitters IN
%   THIS REPOSITORY, and the corpora are a SAMPLE -- a `session_bounded_reference`
%   written by a converter for a dataset still waiting to migrate is precisely
%   what this migration is for.
c = [];
status = 'absent';
if ~isstruct(blk) || ~isfield(blk, name); return; end
x = blk.(name);
if ~isstruct(x) || ~isscalar(x)
    status = 'malformed';
    return;
end
if isfield(x, 'seconds') && isnumeric(x.seconds) && isscalar(x.seconds) ...
        && isfinite(x.seconds)
    c = x;
    status = 'ok';
    return;
end
% No canonical value. Derive one ONLY from a source pair that names seconds.
if ~isfield(x, 'source_value') || ~isnumeric(x.source_value) ...
        || ~isscalar(x.source_value) || ~isfinite(x.source_value)
    status = 'blank';
    return;
end
if ~isSecondsUnit(fieldOr(x, 'source_unit', ''))
    status = 'unreadable_unit';
    return;
end
x.seconds = double(x.source_value);
c = x;
status = 'ok';
end

function tf = isSecondsUnit(u)
%ISSECONDSUNIT Does this source unit DECLARE seconds?
%   Deliberately an explicit list and not a parser. `durationSeconds` writes the
%   literal 's' and that is the only spelling any emitter in this repository
%   produces today; the other four are accepted because they are the spellings a
%   human-entered table would plausibly use, and each is unambiguous. An empty
%   unit is NOT seconds -- it is the schema's blank_value, i.e. "no unit stated",
%   and reading a bare number as seconds is exactly the guess this refuses.
tf = false;
if ~(ischar(u) || (isstring(u) && isscalar(u))); return; end
tf = any(strcmpi(strtrim(char(u)), {'s', 'sec', 'secs', 'second', 'seconds'}));
end

function s = secondsOf(c)
s = double(c.seconds);
end

function v = fieldOr(s, name, dflt)
v = dflt;
if isstruct(s) && isfield(s, name); v = s.(name); end
end

function tf = truthy(x)
tf = false;
if islogical(x) || isnumeric(x); tf = any(logical(x(:))); end
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
