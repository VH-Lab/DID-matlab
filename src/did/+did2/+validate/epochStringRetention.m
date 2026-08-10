function report = epochStringRetention(v1Bodies, migratedBodies)
%EPOCHSTRINGRETENTION Did any did_v1 epoch-id string DISAPPEAR in migration?
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB.
%   Nothing below has been run; the quick gate (test-migrators-quick.yml) is the
%   first thing that will have an opinion about it.
%
%   REPORT = did2.validate.epochStringRetention(V1BODIES, MIGRATEDBODIES)
%   compares the (session, epoch-string) pairs present in the did_v1 SOURCE
%   against the pairs still reachable after migration -- either because a
%   document still carries the string, or because did2.convert.epochMint turned
%   it into an `epoch` document. `pairs_dropped` is the number this instrument
%   exists for.
%
%   REPORT-ONLY. Raises nothing, gates nothing, changes no outcome.
%
%   ---------------------------------------------------------------------
%   THE HOLE THIS FILLS, STATED PRECISELY
%   ---------------------------------------------------------------------
%   Every existing instrument inspects ONE side and looks for a MALFORMED
%   result:
%
%     did2.validate.silentLoss     empty required edges, vacuous required
%                                  fields -- fields that are THERE and blank
%     did2.validate.isFragment     documents with nothing in them
%     did2.validate.sourceCensus   the v1 side alone
%     did2.convert.epochMint       the migrated side alone
%
%   A migrator that reads a source field and simply does not write it produces
%   NONE of those signatures. The output is well-formed, complete by its own
%   schema, and smaller than its input -- and no counter subtracts. That is how
%   `stimulus_response.element_epochid` came within one build of vanishing from
%   ~11,000 documents while every gate stayed green.
%
%   Comparing the two SIDES is the only shape of measurement that can see it, so
%   this function takes both.
%
%   ---------------------------------------------------------------------
%   WHY THE UNIT IS A (SESSION, STRING) PAIR, NOT A STRING
%   ---------------------------------------------------------------------
%   The same rule did2.convert.epochMint keys on, for the same measured reason:
%   an `epochid.epochid` string is REUSED ACROSS SESSIONS -- 142 of corpus B's
%   149 distinct ids (sourceCensus, corpus run 31415147934). Counting distinct
%   STRINGS would report a corpus as fully retained while an entire session's
%   worth of epochs had gone, because some other session happened to use the
%   same `t00070`.
%
%   ---------------------------------------------------------------------
%   WHAT COUNTS AS RETAINED, AND WHAT DELIBERATELY DOES NOT
%   ---------------------------------------------------------------------
%   RETAINED (either is enough -- they are two representations of one fact):
%     * a migrated document still carries the string, at any of the sources
%       did2.validate.epochStrings reads (a passthrough, or a parked string such
%       as jMethodParameters' `other.epochid`);
%     * an `epoch` document exists for the pair -- matched on
%       (base.session_id, epoch.local_identifier), which is exactly the key
%       epochMint mints on.
%
%   NOT counted as retained:
%     * a string this reader DECLINES to read on the v1 side (the
%       syncrule_mapping endpoints). Those are excluded from the DENOMINATOR
%       too, and reported separately as `v1_declined`, so they can neither
%       inflate the retention rate nor be quietly forgotten.
%     * an `epoch_id` EDGE pointing at a document not in MIGRATEDBODIES. An edge
%       whose target this instrument cannot see is not evidence of anything;
%       did2.validate.references is the orphan check, and duplicating half of it
%       here would produce a second, weaker answer to the same question.
%
%   ---------------------------------------------------------------------
%   REPORT FIELDS -- DENOMINATORS FIRST, UNCONDITIONALLY
%   ---------------------------------------------------------------------
%     ran                          false only if the function returned before
%                                  reading anything. `[]` from a caller that
%                                  wrapped this in try/catch means DID NOT RUN;
%                                  a struct with ran=true and every count 0
%                                  means ran and found nothing. They are not the
%                                  same reading and must not look the same.
%     v1_documents_inspected       handed in
%     v1_documents_unreadable      could not be parsed -- COUNTED, never dropped
%     migrated_documents_inspected
%     migrated_documents_unreadable
%     v1_documents_with_string     v1 documents carrying at least one epoch id
%     v1_strings_read              total hits (a document may carry two)
%     v1_pairs                     distinct (session, string) -- THE DENOMINATOR
%                                  every retention number below is out of
%     v1_by_source                 {source, documents, distinct_strings}
%     v1_declined                  hits at a source this reader will not read
%     v1_declined_distinct
%     retained_as_string           pairs still spelled out somewhere
%     retained_as_epoch_document   pairs that became an `epoch`
%     retained_total               the union (a pair may be both)
%     pairs_dropped                v1_pairs - retained_total
%     dropped_by_v1_class          struct: v1 class -> distinct pairs it was the
%                                  only carrier of. Names the migrator.
%     dropped_detail               up to `DetailCap` rows {session_id,
%                                  epoch_string, v1_classes} so a regression is
%                                  actionable without a corpus re-run
%     epoch_documents_seen         `epoch` documents in the migrated set
%
%   See also: did2.validate.epochStrings, did2.convert.epochMint,
%   did2.validate.silentLoss, did2.validate.sourceCensus.

arguments
    v1Bodies
    migratedBodies
end

DetailCap = 50;

% DENOMINATOR FIRST, and every field defined before a document is read.
report = struct( ...
    'ran',                           false, ...
    'v1_documents_inspected',        0, ...
    'v1_documents_unreadable',       0, ...
    'migrated_documents_inspected',  0, ...
    'migrated_documents_unreadable', 0, ...
    'v1_documents_with_string',      0, ...
    'v1_strings_read',               0, ...
    'v1_pairs',                      0, ...
    'v1_by_source', struct('source', {}, 'documents', {}, ...
                           'distinct_strings', {}), ...
    'v1_declined',                   0, ...
    'v1_declined_distinct',          0, ...
    'retained_as_string',            0, ...
    'retained_as_epoch_document',    0, ...
    'retained_total',                0, ...
    'pairs_dropped',                 0, ...
    'dropped_by_v1_class',           struct(), ...
    'dropped_detail', struct('session_id', {}, 'epoch_string', {}, ...
                             'v1_classes', {}), ...
    'epoch_documents_seen',          0);

[srcBodies, srcUnreadable] = decodeBodies(v1Bodies);
[dstBodies, dstUnreadable] = decodeBodies(migratedBodies);
report.v1_documents_inspected        = numel(srcBodies) + srcUnreadable;
report.v1_documents_unreadable       = srcUnreadable;
report.migrated_documents_inspected  = numel(dstBodies) + dstUnreadable;
report.migrated_documents_unreadable = dstUnreadable;
report.ran = true;

% ---- the v1 side: the denominator ----------------------------------------
% pairKey -> struct(session_id, epoch_string, classes cell)
srcPairs   = containers.Map('KeyType', 'char', 'ValueType', 'any');
srcOrder   = {};
declined   = {};
srcValues  = cell(1, numel(srcBodies));
srcSources = cell(1, numel(srcBodies));
for k = 1:numel(srcBodies)
    b = srcBodies{k};
    [hits, dec] = did2.validate.epochStrings(b);
    srcValues{k}  = {hits.value};
    srcSources{k} = {hits.source};
    if ~isempty(dec)
        declined = [declined, {dec.value}]; %#ok<AGROW>
    end
    if isempty(hits); continue; end
    report.v1_documents_with_string = report.v1_documents_with_string + 1;
    report.v1_strings_read = report.v1_strings_read + numel(hits);
    sid = baseField(b, 'session_id');
    cn  = classNameOf(b);
    for j = 1:numel(hits)
        key = pairKey(sid, hits(j).value);
        if isKey(srcPairs, key)
            row = srcPairs(key);
            if ~any(strcmp(row.classes, cn)); row.classes{end+1} = cn; end
            srcPairs(key) = row;
        else
            srcPairs(key) = struct('session_id', sid, ...
                'epoch_string', hits(j).value, 'classes', {{cn}});
            srcOrder{end+1} = key; %#ok<AGROW>
        end
    end
end
report.v1_pairs    = numel(srcOrder);
report.v1_by_source = perSourceCounts(srcValues, srcSources);
report.v1_declined = numel(declined);
if ~isempty(declined)
    report.v1_declined_distinct = numel(unique(declined));
end

% ---- the migrated side: what is still reachable ---------------------------
stillString = containers.Map('KeyType', 'char', 'ValueType', 'logical');
asEpochDoc  = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(dstBodies)
    b   = dstBodies{k};
    sid = baseField(b, 'session_id');
    hits = did2.validate.epochStrings(b);
    for j = 1:numel(hits)
        stillString(pairKey(sid, hits(j).value)) = true;
    end
    if strcmp(classNameOf(b), 'epoch')
        report.epoch_documents_seen = report.epoch_documents_seen + 1;
        lid = '';
        if isfield(b, 'epoch') && isstruct(b.epoch) && isscalar(b.epoch) ...
                && isfield(b.epoch, 'local_identifier')
            x = b.epoch.local_identifier;
            if ischar(x) || (isstring(x) && isscalar(x)); lid = char(x); end
        end
        if ~isempty(lid)
            asEpochDoc(pairKey(sid, lid)) = true;
        end
    end
end

% ---- the subtraction ------------------------------------------------------
droppedByClass = struct();
for k = 1:numel(srcOrder)
    key = srcOrder{k};
    hasString = isKey(stillString, key);
    hasEpoch  = isKey(asEpochDoc, key);
    if hasString; report.retained_as_string = report.retained_as_string + 1; end
    if hasEpoch
        report.retained_as_epoch_document = report.retained_as_epoch_document + 1;
    end
    if hasString || hasEpoch
        report.retained_total = report.retained_total + 1;
        continue;
    end
    report.pairs_dropped = report.pairs_dropped + 1;
    row = srcPairs(key);
    for c = 1:numel(row.classes)
        fn = matlab.lang.makeValidName(row.classes{c});
        if isfield(droppedByClass, fn)
            droppedByClass.(fn) = droppedByClass.(fn) + 1;
        else
            droppedByClass.(fn) = 1;
        end
    end
    if numel(report.dropped_detail) < DetailCap
        report.dropped_detail(end+1) = struct( ...
            'session_id',   row.session_id, ...
            'epoch_string', row.epoch_string, ...
            'v1_classes',   {row.classes});
    end
end
report.dropped_by_v1_class = droppedByClass;
end

% ===================== helpers =========================================

function k = pairKey(sessionId, epochString)
%PAIRKEY Length-prefixed so no separator can be forged -- identical rule to
%   did2.convert.epochMint/pairKey. If the two ever disagree, this instrument
%   would report drops the mint did not cause.
k = sprintf('%d:%s|%s', numel(sessionId), sessionId, epochString);
end

function [bodies, unreadable] = decodeBodies(docs)
%DECODEBODIES JSON chars, structs, or did2.document -- counted, never dropped.
%   JSON is decoded HERE rather than in private/vBodies.m because the corpus
%   harnesses hand the v1 side in as raw JSON strings off disk, and widening the
%   shared helper would change what every other instrument accepts.
bodies = {};
unreadable = 0;
if isempty(docs); return; end
if iscell(docs)
    items = docs(:)';
elseif isstruct(docs)
    items = num2cell(docs(:)');
else
    items = arrayfun(@(x) {x}, docs(:)');
end
predecoded = cell(1, numel(items));
for k = 1:numel(items)
    it = items{k};
    if ischar(it) || (isstring(it) && isscalar(it))
        try
            predecoded{k} = jsondecode(char(it));
        catch
            predecoded{k} = [];   % counted below by vBodies
        end
    else
        predecoded{k} = it;
    end
end
[bodies, unreadable] = vBodies(predecoded);
end

function cn = classNameOf(b)
cn = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isscalar(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function v = baseField(b, name)
v = '';
if ~isfield(b, 'base') || ~isstruct(b.base) || ~isscalar(b.base) ...
        || ~isfield(b.base, name)
    return;
end
x = b.base.(name);
if ischar(x) || (isstring(x) && isscalar(x)); v = char(x); end
end

function rowsOut = perSourceCounts(values, sources)
%PERSOURCECOUNTS {source, documents, distinct_strings}. Same shape as the block
%   did2.convert.epochMint reports, so the two sides can be read against each
%   other row by row.
rowsOut = struct('source', {}, 'documents', {}, 'distinct_strings', {});
docsBySource = containers.Map('KeyType', 'char', 'ValueType', 'double');
valsBySource = containers.Map('KeyType', 'char', 'ValueType', 'any');
order = {};
for k = 1:numel(sources)
    seenHere = {};
    for j = 1:numel(sources{k})
        s = sources{k}{j};
        if ~isKey(docsBySource, s)
            docsBySource(s) = 0;
            valsBySource(s) = {};
            order{end+1} = s; %#ok<AGROW>
        end
        if ~any(strcmp(seenHere, s))
            docsBySource(s) = docsBySource(s) + 1;
            seenHere{end+1} = s; %#ok<AGROW>
        end
        vv = valsBySource(s);
        vv{end+1} = values{k}{j}; %#ok<AGROW>
        valsBySource(s) = vv;
    end
end
for k = 1:numel(order)
    s = order{k};
    vv = valsBySource(s);
    rowsOut(end+1) = struct('source', s, 'documents', docsBySource(s), ...
        'distinct_strings', numel(unique(vv))); %#ok<AGROW>
end
end
