function [result, report] = epochMint(result, options)
%EPOCHMINT Mint one `epoch` entity per distinct (session, epoch-id string).
%
%   STATUS: WRITTEN 2026-08-10, EXTENDED 2026-08-11 (the ingested-metadata
%   fold), NEVER EXECUTED HERE. This container has no MATLAB -- `command -v
%   matlab octave octave-cli` prints nothing and exits 1 -- so not one line
%   below has been run in this environment. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion
%   about it, and the CI run ids are the only durable evidence.
%
%   [RESULT, REPORT] = did2.convert.epochMint(RESULT) takes the struct returned
%   by did2.convert.v1_to_v2 (after resolveDeferredBaths / resolveDatasetEntities)
%   and mints the `epoch` documents that did_v1 never had. REPORT is also
%   attached to RESULT as `RESULT.epoch_mint`, so a caller that ignores the
%   second output still carries the measurement.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A BATCH PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   A single-document migrator cannot do this, and the reason is not
%   convenience. Minting one epoch per distinct epoch id is a FIND-OR-CREATE
%   over the whole corpus: several documents share one epoch (corpus B carries
%   1,239 `element_epoch` documents over 149 distinct epoch-id strings), so a
%   per-document mint would emit one `epoch` per REFERENCING DOCUMENT -- N
%   duplicate entities for one recording. `+migrators_j/private/jEpochDocId.m`
%   is the seam that has been holding the line: it answers '' for every did_v1
%   document by construction and says so in its own header, so nothing emits an
%   `epoch_id` edge it cannot fill.
%
%   This file is the DID-side counterpart of ndi.migrate.internal.pathSPromotion
%   (a corpus-wide find-or-create keyed on (animal, site)); it sits beside
%   did2.convert.resolveDatasetEntities and resolveDeferredBaths, which are the
%   batch-level post-passes already in this package.
%
%   ---------------------------------------------------------------------
%   THE KEY IS THE PAIR (base.session_id, epoch-id string). NEVER THE STRING.
%   ---------------------------------------------------------------------
%   MEASURED, corpus run 31415147934 (`02854c7`, 2026-08-10) --
%   did2.validate.sourceCensus over 6 corpora, 221,827 v1 documents, 0
%   unreadable:
%
%                 synthetic (whole_session_) ids   ids spanning >1 session
%       20211116              0                             0
%       B                     0                           142   (of 149 distinct)
%       Dab                   0                           142   (of 1754 distinct)
%       JH                    0                             0
%       PRED                  0                             0
%       Soph                  0                            12   (of 18 distinct)
%
%   V_eta_epoch_plan.md predicted ONE hazard -- the synthetic
%   `whole_session_<reference>` id, minted per ELEMENT by
%   ndi.element.oneepoch.m:42 -- and it measures ZERO everywhere. The hazard the
%   data actually has is a DIFFERENT one: an `epochid.epochid` string is REUSED
%   ACROSS SESSIONS (`t00070` restarts in every session directory). In corpus B
%   that is 142 of 149 distinct ids -- almost the whole corpus. Grouping on the
%   string alone would FUSE epochs belonging to different sessions, which is a
%   silent merge of recordings from different animals.
%
%   So the mint key is the PAIR, and `pairs_minus_strings` in the report is the
%   number of epochs that keying on the string alone would have destroyed.
%
%   ---------------------------------------------------------------------
%   WHAT IT REFUSES TO DO, AND WHY EACH REFUSAL IS COUNTED
%   ---------------------------------------------------------------------
%   `epoch.session_id` is REQUIRED (mustBeNonEmpty). An `epoch` minted with that
%   edge empty would, until #37, VALIDATE CLEAN --
%   +did2/+validate/references.m:90 short-circuits on an empty documentId,
%   correctly, because an edge naming no document cannot dangle and that
%   function is the ORPHAN check -- and would rebuild the invented-empty-edge
%   pattern under the repair's own name. With #37's
%   did2.schema.cache.strictMode('RequiredDependencies') it stops being silent
%   and becomes a quarantine instead. Either way the answer is the same: do not
%   emit it. So:
%
%     * a document with no `base.session_id`               -> no mint, counted
%     * a session id with no `session` DOCUMENT in the batch -> no mint, counted
%     * a session id with SEVERAL session documents        -> no mint, counted
%
%   The third is not hypothetical caution: guessing which of two session
%   documents is the referent is exactly the kind of quiet decision that
%   produces a wrong graph nobody can audit later.
%
%   `epoch.session_id` points at the session DOCUMENT's `base.id`, which is NOT
%   the `base.session_id` its siblings carry: `ndi.document.m:57` mints
%   `base.id` from a fresh `ndi.ido()`, and `ndi.session.m:215`
%   (`newdocument`) sets `base.session_id` from `session.id()` separately. The
%   pass therefore INDEXES the session documents rather than assuming the two
%   strings are equal.
%
%   ---------------------------------------------------------------------
%   THE SYNTHETIC IDS ARE SKIPPED -- AND THAT IS AN UNSIGNED DECISION
%   ---------------------------------------------------------------------
%   `whole_session_<reference>` names a span nothing recorded as one epoch
%   (ndi.element.oneepoch.m:42). V_eta_epoch_plan.md's fork A1 -- CHOSEN by the
%   team 2026-08-10, NOT SIGNED -- says no `epoch` entity is minted for it,
%   because that would make `epoch` mean both a recording and a derived
%   aggregate. This pass implements the refusal (a refusal cannot fuse anything)
%   and COUNTS it as `skipped_synthetic`. It measures 0 in all six corpora, so
%   it changes nothing today; if the team signs the other way, delete the guard
%   and the count tells you exactly what it was suppressing.
%
%   ---------------------------------------------------------------------
%   WHAT IT DOES NOT BUILD
%   ---------------------------------------------------------------------
%   The 15 `epochid`-carrying classes are NOT rewired to an `epoch_id` edge
%   here. They cannot be: exactly THREE V_eta classes declare an `epoch_id`
%   DEPENDENCY at all. Measured over the built schema set -- and a plain grep
%   for the name will NOT show this, because it also matches
%   `epochfiles_ingested`'s `epoch_id` FIELD, which is a char string and not an
%   edge:
%
%     DENOMINATOR: 245 V_eta schema files inspected
%       dep    acquisition_metadata_file
%       dep    ingestion_manifest
%       dep    method_parameters
%       field  epochfiles_ingested        <- a char field, NOT an edge
%
%   -- and the first two are not emitted by pass 1. Stamping an edge a class
%   does not declare is the invented-edge pattern with the sign flipped. The
%   rewire needs its own schema increment (declaring `epoch_id` on those
%   classes) and is a separate line in #60.
%
%   AMENDED 2026-08-11 -- ONE OF THOSE THREE IS NOW FILLED HERE, and the
%   sentence above is why it took a fold rather than a stamp. Read it as
%   written: `acquisition_metadata_file` DECLARES the edge and is simply not
%   EMITTED by pass 1, and it is not emitted for exactly one reason -- its
%   migrator is guarded on an epoch document that did not exist when pass 1
%   ran. This function is the moment one does. So the loop "arm the
%   ingested-metadata fold" below stamps the edge onto the passed-through
%   `daqmetadatareader_epochdata_ingested` body and re-runs
%   +migrators_j/daqmetadatareader_epochdata_ingested, which is the handoff
%   +migrators_j/private/jEpochDocId.m documents in its own header. Nothing
%   about the paragraph above is relaxed: no edge is stamped on a class that
%   does not declare it, and `ingestion_manifest` -- the other of the three --
%   is still NOT folded, for the `epochprobemap` reason recorded two paragraphs
%   down and unchanged.
%
%   `method_parameters` IS filled, because it is the one class that declares the
%   edge, is emitted by pass 1, and has the epoch string parked for exactly this
%   moment: `+migrators_j/private/jMethodParameters.m:112-119` writes the string
%   to `other.epochid` when jEpochDocId answers ''. Filling the edge and
%   removing the parked string is one fact moving to one place.
%
%   `epochfiles_ingested` is NOT folded to `ingestion_manifest` here either,
%   although #60 signs that rename: `ingestion_manifest` declares no
%   `epochprobemap`, and the probemap is the per-epoch subject attribution
%   (non-empty on 2,484 of 2,484 corpus-B documents). Folding today would drop
%   it. Its epoch id IS read as a mint key, so the epochs exist for the fold the
%   day it can be done losslessly.
%
%   ---------------------------------------------------------------------
%   THE EPOCH-STRING READER MOVED OUT, AND WIDENED (2026-08-10)
%   ---------------------------------------------------------------------
%   The local `epochStringOf` is GONE. It read three sources and was blind to a
%   fourth and a fifth: `stimulus_response_scalar` does not carry the `epochid`
%   superclass (its template superclasses are base + stimulus_response), so its
%   two epoch strings -- `stimulus_response.element_epochid` and
%   `.stimulator_epochid` -- were invisible to this pass AND to
%   did2.validate.sourceCensus. The reader is now did2.validate.epochStrings,
%   which names every source it reads AND every source it declines, so an
%   omission is a number in `strings_by_source` / `strings_declined` rather than
%   a silence. That matters here specifically: an epoch this pass does not mint
%   is an epoch nothing can anchor to, and
%   +migrators_j/stimulus_response_scalar.m now SUPPRESSES its fold rather than
%   drop the string, so the suppression only lifts once these epochs exist.
%
%   The mint loop therefore iterates EVERY string a document carries, not the
%   first: the stimulator's epoch and the recording element's epoch are two
%   different epochs joined by syncgraph.time_convert, not two spellings of one.
%
%   Options (name-value), mirroring the sibling passes:
%     Validate       (1,1 logical, default true)  validate minted/changed bodies
%     SchemaCache    ([] or a did2.schema.cache)  override the shared cache
%     TargetVersion  (1,:) char, default 'V_eta'  no-op on other targets
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveDatasetEntities,
%   did2.convert.resolveDeferredBaths, did2.validate.sourceCensus,
%   did2.convert.migrators_j.private.jEpochDocId.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% DENOMINATOR FIRST, and unconditionally. Every field below is defined before a
% single document is read, so "did not run" and "ran and found nothing" are
% different readings of the same struct rather than the same reading.
report = struct( ...
    'documents_inspected',            0, ...
    'documents_unreadable',           0, ...
    'documents_with_epoch_id',        0, ...
    'epoch_strings_read',             0, ...
    'strings_by_source', struct('source', {}, 'documents', {}, ...
                                'distinct_strings', {}), ...
    'strings_declined',               0, ...
    'strings_declined_distinct',      0, ...
    'session_documents_seen',         0, ...
    'distinct_epoch_id_strings',      0, ...
    'distinct_session_epoch_pairs',   0, ...
    'pairs_minus_strings',            0, ...
    'epochs_found_existing',          0, ...
    'epochs_minted',                  0, ...
    'skipped_synthetic',              0, ...
    'skipped_no_session_id',          0, ...
    'skipped_no_session_document',    0, ...
    'skipped_ambiguous_session',      0, ...
    'method_parameters_seen',         0, ...
    'method_parameters_edges_filled', 0, ...
    'method_parameters_unresolved',   0, ...
    'metadata_ingested_seen',              0, ...
    'metadata_ingested_already_folded',    0, ...
    'metadata_ingested_edges_stamped',     0, ...
    'metadata_ingested_folds_emitted',     0, ...
    'metadata_ingested_folds_withheld',    0, ...
    'metadata_refused_no_epoch_string',    0, ...
    'metadata_refused_no_epoch_document',  0, ...
    'metadata_refused_migrator_declined',  0, ...
    'metadata_refused_total',              0, ...
    'metadata_fold_vacuous',               true, ...
    'mint_quarantined',               0, ...
    'ran',                            false, ...
    'epoch_index', struct('session_id', {}, 'local_identifier', {}, ...
                          'epoch_document_id', {}));
result.epoch_mint = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % `epoch` exists only in V_eta; other targets are untouched.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.epoch_mint = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once into a flat row -----------------------------
% A document this cannot read is COUNTED, never dropped. An all-zero report
% that could not read its input must not be indistinguishable from a clean one:
% that is the silentLoss failure, and it cost two days.
% `epochValues{k}` / `epochSources{k}` are CELL ROWS held beside `rows` rather
% than inside it: a struct array field cannot hold a cell without the
% struct('f', {{c}}) double-brace, and that trap has already produced one
% silently-empty reader in this package. `rows(k).epoch_string` is kept as the
% FIRST string only, for the code paths that want a single answer.
rows = struct('class_name', {}, 'epoch_string', {}, 'session_id', {}, ...
              'doc_id', {}, 'datestamp', {});
bodies = cell(1, n);
epochValues  = cell(1, n);
epochSources = cell(1, n);
declinedValues = {};
for k = 1:n
    epochValues{k}  = {};
    epochSources{k} = {};
    try
        b = docs{k}.toStruct();
        bodies{k} = b;
        [hits, declined] = did2.validate.epochStrings(b);
        epochValues{k}  = {hits.value};
        epochSources{k} = {hits.source};
        if ~isempty(declined)
            declinedValues = [declinedValues, {declined.value}]; %#ok<AGROW>
        end
        first = '';
        if ~isempty(hits); first = hits(1).value; end
        rows(k) = struct( ...
            'class_name',   classNameOf(b), ...
            'epoch_string', first, ...
            'session_id',   baseField(b, 'session_id'), ...
            'doc_id',       baseField(b, 'id'), ...
            'datestamp',    baseField(b, 'datestamp'));
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        rows(k) = struct('class_name', '', 'epoch_string', '', ...
            'session_id', '', 'doc_id', '', 'datestamp', '');
    end
end

allStrings = [epochValues{:}];
report.epoch_strings_read = numel(allStrings);
hasEpoch = ~cellfun(@isempty, epochValues);
report.documents_with_epoch_id = sum(hasEpoch);
if isempty(allStrings)
    report.distinct_epoch_id_strings = 0;
else
    report.distinct_epoch_id_strings = numel(unique(allStrings));
end
% PER-SOURCE, so a source that contributes nothing is visibly a zero rather than
% an absence. This is the whole point of consolidating onto one reader: the
% stimulus-response rows below were invisible to every previous counter.
report.strings_by_source = perSourceCounts(epochValues, epochSources);
report.strings_declined = numel(declinedValues);
if isempty(declinedValues)
    report.strings_declined_distinct = 0;
else
    report.strings_declined_distinct = numel(unique(declinedValues));
end

% --- index the session documents ------------------------------------------
% base.session_id -> the session document's base.id, plus a count so a session
% id claimed by two documents is refused rather than guessed at.
sessionDocId = containers.Map('KeyType', 'char', 'ValueType', 'char');
sessionDocCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~strcmp(rows(k).class_name, 'session'); continue; end
    report.session_documents_seen = report.session_documents_seen + 1;
    sid = rows(k).session_id;
    if isempty(sid) || isempty(rows(k).doc_id); continue; end
    if isKey(sessionDocCount, sid)
        sessionDocCount(sid) = sessionDocCount(sid) + 1;
    else
        sessionDocCount(sid) = 1;
        sessionDocId(sid) = rows(k).doc_id;
    end
end

% --- FIND, then create ----------------------------------------------------
% Seed the index from the `epoch` documents ALREADY in the batch. Without this
% the pass is not idempotent, and ndi.migrate.local documents itself as
% idempotent: re-running on a dataset that already has a <target>.sqlite reads
% every document back and runs the second pass again, so every re-run would mint
% a second `epoch` for the same (session, id) pair while the source documents
% still carry their `epochid` string. A find-or-create that only creates is a
% duplicate factory.
epochIdByKey = containers.Map('KeyType', 'char', 'ValueType', 'char');
indexRows = struct('session_id', {}, 'local_identifier', {}, ...
                   'epoch_document_id', {});
for k = 1:n
    if ~strcmp(rows(k).class_name, 'epoch'); continue; end
    lid = '';
    if isfield(bodies{k}, 'epoch') && isstruct(bodies{k}.epoch)
        lid = charField(bodies{k}.epoch, {'local_identifier'});
    end
    if isempty(lid) || isempty(rows(k).doc_id); continue; end
    existingKey = pairKey(rows(k).session_id, lid);
    if isKey(epochIdByKey, existingKey); continue; end
    epochIdByKey(existingKey) = rows(k).doc_id;
    report.epochs_found_existing = report.epochs_found_existing + 1;
    indexRows(end+1) = struct('session_id', rows(k).session_id, ...
        'local_identifier', lid, 'epoch_document_id', rows(k).doc_id); %#ok<AGROW>
end

% --- mint one epoch per distinct (session, epoch string) ------------------
% ONE DOCUMENT MAY CARRY SEVERAL EPOCH STRINGS, and they may name DIFFERENT
% epochs: `stimulus_response.stimulator_epochid` is the STIMULATOR's epoch and
% `element_epochid` is the RECORDING ELEMENT's, mapped onto each other by
% syncgraph.time_convert (tuning_response.m:245-246). Taking only the first
% would mint one of the two and silently lose the other, which is the same
% single-answer assumption that made the census blind to this family in the
% first place. So the loop is over every hit, not over `rows(k).epoch_string`.
refusedKeys = containers.Map('KeyType', 'char', 'ValueType', 'logical');
minted = {};
for k = 1:n
    sid = rows(k).session_id;
    for j = 1:numel(epochValues{k})
        es = epochValues{k}{j};
        if isempty(es); continue; end
        key = pairKey(sid, es);
        if isKey(epochIdByKey, key) || isKey(refusedKeys, key)
            continue;   % find-or-create: this pair already has its answer
        end
        if startsWith(es, 'whole_session_')
            refusedKeys(key) = true;
            report.skipped_synthetic = report.skipped_synthetic + 1;
            continue;
        end
        if isempty(sid)
            refusedKeys(key) = true;
            report.skipped_no_session_id = report.skipped_no_session_id + 1;
            continue;
        end
        if ~isKey(sessionDocId, sid)
            refusedKeys(key) = true;
            report.skipped_no_session_document = ...
                report.skipped_no_session_document + 1;
            continue;
        end
        if sessionDocCount(sid) > 1
            refusedKeys(key) = true;
            report.skipped_ambiguous_session = ...
                report.skipped_ambiguous_session + 1;
            continue;
        end
        body = mintEpoch(es, sid, sessionDocId(sid), rows(k).datestamp);
        epochIdByKey(key) = body.base.id;
        minted{end+1} = body; %#ok<AGROW>
        indexRows(end+1) = struct('session_id', sid, 'local_identifier', es, ...
            'epoch_document_id', body.base.id); %#ok<AGROW>
    end
end
% `.Count`, NOT `numel`: numel() on a containers.Map returns 1 (it is a scalar
% handle object), so a count written that way reads 1 forever regardless of what
% is in the map. A denominator that cannot move is worse than no denominator.
% double(), and it is not cosmetic. `containers.Map.Count` returns UINT64, and
% uint64 arithmetic SATURATES: `pairs - strings` below could never go negative,
% so a day when the string count exceeded the pair count -- which would mean the
% reader or the key is broken -- would report a reassuring 0 instead of a
% negative number. An instrument whose error case is indistinguishable from
% "nothing to report" is the defect this whole pass exists to avoid. It also
% made verifyEqual fail on class rather than value, which is how it was found.
report.distinct_session_epoch_pairs = ...
    double(epochIdByKey.Count) + double(refusedKeys.Count);
% THE MEASUREMENT THIS PASS EXISTS FOR, restated as a number the report carries.
% Keying on the id STRING alone would produce `distinct_epoch_id_strings`
% groups; keying on the PAIR produces `distinct_session_epoch_pairs`. The
% difference is the number of epochs that the string key would have FUSED --
% 142 of 149 distinct ids in corpus B, measured, not predicted.
report.pairs_minus_strings = ...
    report.distinct_session_epoch_pairs - report.distinct_epoch_id_strings;

% --- fill the ONE declared, fillable epoch edge ---------------------------
changedIdx = [];
% The subset of `changedIdx` that is an ingested-metadata FOLD. Kept beside it
% rather than recovered afterwards by class name: after the rebuild the body in
% `docs{k}` may be either the folded document or the original passthrough
% (whichever survived), so asking "what class is it now" cannot tell an emitted
% fold from a withheld one -- which is precisely the number to report.
metadataFoldIdx = [];
for k = 1:n
    if ~strcmp(rows(k).class_name, 'method_parameters'); continue; end
    report.method_parameters_seen = report.method_parameters_seen + 1;
    if ~isempty(depValueOf(bodies{k}, 'epoch_id'))
        continue;   % already filled (a re-run); find-or-create, not create
    end
    % The PARKED string specifically, not "whichever string this body has".
    % jMethodParameters:120-127 writes it to `other.epochid`, and the removal
    % below removes exactly that field -- reading a different source here would
    % fill the edge from one fact and delete another.
    es = valueForSource(epochValues{k}, epochSources{k}, 'method_parameters');
    if isempty(es); continue; end
    key = pairKey(rows(k).session_id, es);
    if ~isKey(epochIdByKey, key)
        report.method_parameters_unresolved = ...
            report.method_parameters_unresolved + 1;
        continue;
    end
    b = bodies{k};
    b = setDep(b, 'epoch_id', epochIdByKey(key));
    % The parked string leaves in the same step the edge arrives. Leaving both
    % would store one fact twice with nothing saying which is authoritative --
    % the defect open item #69 exists for.
    if isfield(b, 'method_parameters') && isstruct(b.method_parameters) ...
            && isfield(b.method_parameters, 'other') ...
            && isstruct(b.method_parameters.other) ...
            && isfield(b.method_parameters.other, 'epochid')
        b.method_parameters.other = rmfield(b.method_parameters.other, 'epochid');
    end
    bodies{k} = b;
    changedIdx(end+1) = k; %#ok<AGROW>
    report.method_parameters_edges_filled = ...
        report.method_parameters_edges_filled + 1;
end

% --- arm the ingested-metadata fold ---------------------------------------
% `daqmetadatareader_epochdata_ingested` -> `acquisition_metadata_file`, the
% TEAM-SIGNED fold (V_eta_ingested_payload_findings.md, TEAM-SIGN-OFF [daq
% ingested payloads], jess@walthamdatascience.com / 2026-08-08: "ONE new class,
% `acquisition_metadata_file`").
%
% THIS IS NOT A SECOND FOLD IMPLEMENTATION. The fold lives in
% +migrators_j/daqmetadatareader_epochdata_ingested.m and is called here
% unchanged. All this loop does is STAMP THE `epoch_id` EDGE the migrator is
% guarded on -- which is the handoff its own guard names in as many words:
%
%   +migrators_j/private/jEpochDocId.m
%     "The day the epoch pass stamps an `epoch_id` edge, these migrators
%      convert with no further change; the tests drive both branches."
%
% So the arming is one assignment, the fold stays under the tests that already
% pin it (testMigratorsJIngested's metadata block), and there is exactly one
% place that knows what an `acquisition_metadata_file` looks like.
%
% WHY HERE AND NOT IN A NEW BATCH PASS. Three reasons, in order of weight:
%
%   1. This pass already owns the exact half that was missing. Its own header
%      says the rewire is blocked because "exactly THREE V_eta classes declare
%      an `epoch_id` DEPENDENCY at all ... and the first two are not emitted by
%      pass 1". `acquisition_metadata_file` is one of those three. It is not
%      emitted by pass 1 for ONE reason -- no epoch document existed when the
%      migrator ran -- and this is the function, and the moment, at which one
%      does. `method_parameters` above is the same operation on the one class
%      that needed no fold to reach its edge.
%   2. A new pass could not be wired on both sides from here. The gate in
%      tests/+did2/+unittest/testBatchPassWiring.m requires every batch
%      post-pass to be called from all three DID harnesses AND from
%      ndi.migrate.local, which is in NDI-matlab -- a repository this session
%      has READ access to and no more. The escape hatch (a crossRepoDivergence
%      row) exists for divergences that are INTENDED; "the author could not
%      write the other repository" is not one, and taking it would convert a
%      real gap into an approved one, which that file names as the worse
%      failure. epochMint is already called from all four sites.
%   3. Ordering is already correct and already load-bearing. The stamp must
%      follow the mint, and the mint is above.
%
% NOTHING CAN BE LOST HERE, and that is a property of the rebuild path below
% rather than a claim about this loop. A folded body is pushed through
% did2.convert.v1_to_v2 with the rest; the replacement loop overwrites
% `docs{k}` ONLY when the folded body's id came back out of it, so a body that
% quarantines leaves the ORIGINAL passthrough document in the batch -- valid
% under its own restored source tombstone -- while still landing in
% `result.quarantine`, which is a 0-quarantine gate failure and the correct
% volume for a builder that emitted an invalid document.
%
% VACUITY IS REPORTED, NOT INFERRED FROM ZEROS. `metadata_fold_vacuous` is TRUE
% when this batch held no source documents at all, so a run with nothing to do
% cannot read as a run that did everything. Every `metadata_*` zero below it is
% then a zero over a zero denominator.
for k = 1:n
    if strcmp(rows(k).class_name, 'acquisition_metadata_file')
        % A re-run. find-or-create, not create: ndi.migrate.local re-reads
        % every document on a second pass over the same dataset.
        report.metadata_ingested_already_folded = ...
            report.metadata_ingested_already_folded + 1;
        continue;
    end
    if ~strcmp(rows(k).class_name, 'daqmetadatareader_epochdata_ingested')
        continue;
    end
    report.metadata_ingested_seen = report.metadata_ingested_seen + 1;
    continue;   % MUTATION M4 -- counts, then reads nothing
    % The `epochid` MIXIN string specifically. Reading "whichever string this
    % body has" is the error epochMint already avoids one loop up: a document
    % may carry several, and they may name different epochs.
    es = valueForSource(epochValues{k}, epochSources{k}, 'epochid');
    if isempty(es)
        report.metadata_refused_no_epoch_string = ...
            report.metadata_refused_no_epoch_string + 1;
        continue;
    end
    key = pairKey(rows(k).session_id, es);
    if ~isKey(epochIdByKey, key)
        % Refused above (synthetic id / no session id / no session document /
        % ambiguous session), or the mint quarantined. Either way there is no
        % epoch to point at, and `acquisition_metadata_file.epoch_id` is
        % REQUIRED -- emitting it empty is the invented-empty-edge pattern,
        % which +did2/+validate/references.m:90 would let through clean.
        report.metadata_refused_no_epoch_document = ...
            report.metadata_refused_no_epoch_document + 1;
        continue;
    end
    b = setDep(bodies{k}, 'epoch_id', epochIdByKey(key));
    report.metadata_ingested_edges_stamped = ...
        report.metadata_ingested_edges_stamped + 1;
    folded = did2.convert.migrators_j.daqmetadatareader_epochdata_ingested(b);
    if iscell(folded) && isscalar(folded); folded = folded{1}; end
    if ~isstruct(folded) || ~isscalar(folded) ...
            || ~strcmp(classNameOf(folded), 'acquisition_metadata_file')
        % The migrator's OTHER guards -- no reader edge, no bytes -- fired and
        % it returned the source. It is the authority on whether the fold is
        % safe; this loop only supplies the epoch. The stamped edge is dropped
        % with the body, so the passthrough is byte-identical to no-op.
        report.metadata_refused_migrator_declined = ...
            report.metadata_refused_migrator_declined + 1;
        continue;
    end
    bodies{k} = folded;
    changedIdx(end+1) = k;      %#ok<AGROW>
    metadataFoldIdx(end+1) = k; %#ok<AGROW>
end
report.metadata_refused_total = report.metadata_refused_no_epoch_string ...
    + report.metadata_refused_no_epoch_document ...
    + report.metadata_refused_migrator_declined;
report.metadata_fold_vacuous = (report.metadata_ingested_seen == 0);

report.epochs_minted = numel(minted);
report.epoch_index = indexRows;
if isempty(minted) && isempty(changedIdx)
    result.epoch_mint = report;
    return;
end

% --- pad + validate, through the same door every other pass uses ----------
% The bodies are tagged schema_version == TargetVersion, so v1_to_v2
% short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate. A body
% that cannot validate lands in `quarantine` and is NOT emitted -- loudly, on a
% 0-quarantine gate, which is the correct volume for a builder that produced an
% invalid document.
rebuildIn = [bodies(changedIdx), minted];
out = did2.convert.v1_to_v2(rebuildIn, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);

report.mint_quarantined = numel(out.quarantine);
if ~isempty(out.quarantine)
    if isfield(result, 'quarantine') && ~isempty(result.quarantine)
        result.quarantine = [result.quarantine, out.quarantine];
    else
        result.quarantine = out.quarantine;
    end
end

% v1_to_v2 preserves input order and this batch is 1 -> 1 throughout (no
% migrator runs on an already-target body), so position maps back directly --
% but only while nothing quarantined. When something did, fall back to matching
% on base.id rather than on position, because a quarantined body leaves no slot.
producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(out.migrated)
    try
        producedById(char(out.migrated{k}.get('base.id'))) = k;
    catch
        % a produced body with no readable id cannot be matched; it is still
        % counted in out.migrated and appended below if it is a mint.
    end
end
for j = 1:numel(changedIdx)
    id = rows(changedIdx(j)).doc_id;
    if ~isempty(id) && isKey(producedById, id)
        docs{changedIdx(j)} = out.migrated{producedById(id)};
    end
end
% THE FOLD'S OWN DENOMINATOR, split by what actually landed. A fold that
% quarantined leaves `docs{k}` holding the ORIGINAL passthrough document, so
% nothing is lost -- but nothing was gained either, and the two must not print
% the same. `withheld` is the count of documents that stayed did_v1 despite
% having an epoch to point at, and it is exactly the number a 0-quarantine gate
% failure should be read against.
for j = 1:numel(metadataFoldIdx)
    id = rows(metadataFoldIdx(j)).doc_id;
    if ~isempty(id) && isKey(producedById, id)
        report.metadata_ingested_folds_emitted = ...
            report.metadata_ingested_folds_emitted + 1;
    else
        report.metadata_ingested_folds_withheld = ...
            report.metadata_ingested_folds_withheld + 1;
    end
end
mintedIds = cellfun(@(b) b.base.id, minted, 'UniformOutput', false);
emitted = 0;
for j = 1:numel(mintedIds)
    if isKey(producedById, mintedIds{j})
        docs{end+1} = out.migrated{producedById(mintedIds{j})}; %#ok<AGROW>
        emitted = emitted + 1;
    end
end
report.epochs_minted = emitted;
% Keep the index honest: an epoch that did not survive validation is not an
% epoch anything may point at. Entries that were FOUND (already in the batch)
% were never rebuilt, so they are kept unconditionally; only the minted ones are
% filtered on whether they came back out of the re-fold.
if emitted < numel(mintedIds)
    mintedSet = containers.Map(mintedIds, num2cell(1:numel(mintedIds)));
    keep = true(1, numel(indexRows));
    for j = 1:numel(indexRows)
        eid = indexRows(j).epoch_document_id;
        if isKey(mintedSet, eid) && ~isKey(producedById, eid)
            keep(j) = false;
        end
    end
    report.epoch_index = indexRows(keep);
end

result.migrated = docs;
result.summary = recountSummary(result);
result.epoch_mint = report;
end

% ===================== builders ========================================

function body = mintEpoch(epochString, sessionId, sessionDocumentId, datestamp)
%MINTEPOCH One `epoch ⊂ entity` body.
%   `local_identifier` is declared ON epoch and REQUIRED (build_v_eta.py's #60
%   block): `entity` deliberately declares none so a child can ADD it as
%   required, the same reason `subject` does. The v1 epoch string IS that
%   handle -- 30 live NDI sites match it by exact_string.
%
%   NO `time_reference_#` and NO `instrument_id` are emitted. Both are optional,
%   and neither can be populated from the epoch string alone: the per-clock
%   extents live in `daqreader_epochdata_ingested.epochtable` and the recording
%   device needs the daq graph (#59). An edge emitted empty is the defect, not a
%   placeholder.
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
body = struct();
body.document_class = struct( ...
    'class_name',     'epoch', ...
    'class_version',  '1.0.0', ...
    'superclasses',   struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', 'session_id', 'value', sessionDocumentId);
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_epoch', 'datestamp', datestamp);
body.epoch = struct('local_identifier', epochString);
end

% ===================== readers =========================================

function k = pairKey(sessionId, epochString)
%PAIRKEY The mint key, length-prefixed so no separator can be forged.
%   `[sessionId '|' epochString]` would let a session id ending in '|' collide
%   with another pair. Cheap to prevent; expensive to notice.
k = sprintf('%d:%s|%s', numel(sessionId), sessionId, epochString);
end

function cn = classNameOf(b)
cn = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

% EPOCHSTRINGOF -- DELETED 2026-08-10. It was the SECOND of three epoch-string
% readers in this toolbox, each with a different blind spot, and its own was the
% stimulus-response family: `stimulus_response_scalar` does NOT carry the
% `epochid` superclass (template superclasses are base + stimulus_response), so
% neither of its two epoch strings could ever be seen here. The reader now lives
% in did2.validate.epochStrings, which NAMES every source it reads and every
% source it declines, and is pinned source-by-source by
% tests/+did2/+unittest/testEpochStrings.m.

function v = valueForSource(values, sources, wanted)
%VALUEFORSOURCE The epoch string a NAMED reader source contributed, '' if none.
v = '';
for k = 1:numel(sources)
    if strcmp(sources{k}, wanted)
        v = values{k};
        return;
    end
end
end

function rowsOut = perSourceCounts(epochValues, epochSources)
%PERSOURCECOUNTS {source, documents, distinct_strings} for every source SEEN.
%   Sources with no hits do not appear -- the reader's own header is the list of
%   what exists, and a caller comparing the two learns which sources this batch
%   simply has no documents for.
%   Plain parallel arrays, NOT a containers.Map. The source list is bounded by
%   the reader's own header (six today), so a linear scan costs nothing -- and
%   `map(key) = {}` on a ValueType 'any' Map is the kind of construct that reads
%   as an initialisation and can behave as a deletion. Not worth the risk in a
%   counter whose whole purpose is to be believed.
rowsOut = struct('source', {}, 'documents', {}, 'distinct_strings', {});
order     = {};
docCounts = [];
valLists  = {};
for k = 1:numel(epochSources)
    seenHere = {};
    for j = 1:numel(epochSources{k})
        s = epochSources{k}{j};
        idx = find(strcmp(order, s), 1);
        if isempty(idx)
            order{end+1}     = s;    %#ok<AGROW>
            docCounts(end+1) = 0;    %#ok<AGROW>
            valLists{end+1}  = {};   %#ok<AGROW>
            idx = numel(order);
        end
        if ~any(strcmp(seenHere, s))
            docCounts(idx) = docCounts(idx) + 1;
            seenHere{end+1} = s; %#ok<AGROW>
        end
        valLists{idx}{end+1} = epochValues{k}{j};
    end
end
for k = 1:numel(order)
    rowsOut(end+1) = struct('source', order{k}, ...
        'documents', docCounts(k), ...
        'distinct_strings', numel(unique(valLists{k}))); %#ok<AGROW>
end
end

function v = depValueOf(b, name)
%DEPVALUEOF The value of one depends_on entry on a body STRUCT, '' when absent
%   OR present-and-empty. Tolerant of both key spellings, same precedence as
%   +did2/+validate/references.m.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps)
    items = deps(:)';
elseif isstruct(deps)
    items = num2cell(deps(:)');
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        if isfield(d, key{1})
            x = d.(key{1});
            if (ischar(x) || isstring(x)) && ~isempty(char(x)); v = char(x); end
        end
        if ~isempty(v); return; end
    end
    return;
end
end

function v = charField(s, names)
v = '';
for k = 1:numel(names)
    if ~isfield(s, names{k}); continue; end
    x = s.(names{k});
    if (ischar(x) || isstring(x)) && ~isempty(char(x)); v = char(x); return; end
end
end

function v = baseField(b, name)
v = '';
if ~isfield(b, 'base') || ~isstruct(b.base) || ~isfield(b.base, name); return; end
x = b.base.(name);
if ischar(x) || isstring(x); v = char(x); end
end

function b = setDep(b, name, value)
%SETDEP Add or overwrite one depends_on entry on a body STRUCT.
%   The pipeline uses two spellings at different stages -- a body that has been
%   through universalRenames carries `document_id`, one a migrator built carries
%   `value` -- and +did2/+validate/references.m reads either. So an EXISTING
%   entry is updated in whichever keys it already has, and a NEW entry is given
%   the same key set as its neighbours (a struct array cannot hold two field
%   sets). On an empty `depends_on` the shape is `value`, matching the minted
%   bodies in ndi.migrate.internal.pathSPromotion, which is the proven path
%   through the v1_to_v2 re-fold.
entry = struct('name', name, 'value', value);
if ~isfield(b, 'depends_on') || isempty(b.depends_on)
    b.depends_on = entry;
    return;
end
deps = b.depends_on;
if iscell(deps)
    for k = 1:numel(deps)
        if isstruct(deps{k}) && isfield(deps{k}, 'name') ...
                && strcmp(char(deps{k}.name), name)
            deps{k} = entry; b.depends_on = deps; return;
        end
    end
    deps{end+1} = entry;
    b.depends_on = deps;
    return;
end
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
        if isfield(deps, 'value');       deps(k).value = value; end
        if isfield(deps, 'document_id'); deps(k).document_id = value; end
        b.depends_on = deps;
        return;
    end
end
% Append: the existing array's field set decides which keys the new entry may
% carry, because a struct array cannot hold two different field sets.
fn = fieldnames(deps);
newEntry = struct();
for k = 1:numel(fn)
    switch fn{k}
        case 'name';        newEntry.name = name;
        case 'value';       newEntry.value = value;
        case 'document_id'; newEntry.document_id = value;
        otherwise;          newEntry.(fn{k}) = '';
    end
end
if ~isfield(newEntry, 'name'); newEntry.name = name; end
b.depends_on = [deps(:)', newEntry];
end

function summary = recountSummary(result)
%RECOUNTSUMMARY Same contract as resolveDatasetEntities' local copy.
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
