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
%   STATUS: NEVER EXECUTED. WIRED 2026-08-10 INTO ALL FOUR CALL SITES.
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
    'refused_total',                0, ...
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
        startCell = cellField(blk, 'start');
        endCell   = cellField(blk, 'end');
        if ~isempty(startCell)
            value.start = startCell;
        end
        if ~isempty(startCell) && ~isempty(endCell)
            span = secondsOf(endCell) - secondsOf(startCell);
            if span < 0
                report.refused_negative_extent = report.refused_negative_extent + 1;
                continue;
            end
            % NO source_unit / source_value on the extent. The source wrote two
            % OFFSETS, never a span, so filling a source slot would claim a
            % provenance that does not exist -- the distance_metadata
            % assumed-shape error. `approximate` is true if EITHER end was.
            value.duration = struct('seconds', span, 'approximate', ...
                truthy(fieldOr(startCell, 'approximate', false)) || ...
                truthy(fieldOr(endCell, 'approximate', false)));
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
    + report.refused_negative_extent;

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

function c = cellField(blk, name)
%CELLFIELD One duration cell off the old block, or [] when it says nothing.
%   A cell with no readable `seconds` is treated as ABSENT rather than as zero:
%   NO TIMES => NO REFERENCE applies inside a document as well as to whether one
%   exists, and a fabricated 0 s offset is exactly the hollow value the census
%   was built to find.
c = [];
if ~isstruct(blk) || ~isfield(blk, name); return; end
x = blk.(name);
if ~isstruct(x) || ~isscalar(x); return; end
if ~isfield(x, 'seconds') || ~isnumeric(x.seconds) || ~isscalar(x.seconds) ...
        || ~isfinite(x.seconds)
    return;
end
c = x;
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
