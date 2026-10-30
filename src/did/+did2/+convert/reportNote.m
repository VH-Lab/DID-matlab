function out = reportNote(action, arg2, arg3, arg4)
%REPORTNOTE A note a per-document migrator leaves for the migration report.
%
%   A migrator returns documents, nothing else, so a fact about HOW it migrated
%   a document (not a failure: the document still migrates) has no other way to
%   reach the report. did2.convert.v1_to_v2 resets the notes at the start of a
%   batch, takes a mark before each source body and truncates back to it when
%   that body is quarantined (a quarantined body did not migrate, so its note
%   would count something that is not in the output), and collects the notes
%   into `summary.migration_notes` at the end.
%
%   did2.convert.reportNote(KIND, CLASSNAME, DOCID)   record one note
%   did2.convert.reportNote(KIND, CLASSNAME, DOCID, DETAIL)
%                                                     ... naming WHAT (a char)
%   did2.convert.reportNote('reset')                  forget all notes
%   N = did2.convert.reportNote('mark')               the number recorded so far
%   did2.convert.reportNote('truncate', N)            keep only the first N
%   N = did2.convert.reportNote('pending', KIND)      how many notes of KIND
%                                                     were recorded since the
%                                                     last 'mark' (v1_to_v2
%                                                     reads 'carried_as_v1' to
%                                                     know a body was carried)
%   D = did2.convert.reportNote('pendingDetails', KIND)  the DETAIL of each note
%                                                     of KIND recorded since the
%                                                     last 'mark', a cellstr
%                                                     (v1_to_v2 reads the
%                                                     `[carry-NNN]` rows a
%                                                     source's carry cites)
%   S = did2.convert.reportNote('merge', A, B)        two 'collect' summaries
%                                                     as one: counts, per-class
%                                                     counts, distinct details
%                                                     and register rows added
%                                                     (EXACT); B's sampled ids
%                                                     and details appended while
%                                                     the sample is under the
%                                                     per-class cap summed over
%                                                     the merged classes. For a
%                                                     batch pass that records
%                                                     notes after v1_to_v2
%                                                     collected its own
%                                                     (resolveDeferredBaths).
%   S = did2.convert.reportNote('collect')            the notes, summarised:
%       S.<kind>.count       how many notes of this kind were recorded (EXACT)
%       S.<kind>.by_class    a struct, class name -> note count (EXACT)
%       S.<kind>.ids         the source document ids of a SAMPLE of the notes:
%                            the first SAMPLE_CAP notes of each (kind, class),
%                            in the order they were recorded
%       S.<kind>.details     the DETAIL of each sampled note, parallel to ids
%                            ('' if none)
%       S.<kind>.sample_cap_per_class   SAMPLE_CAP (20)
%       S.<kind>.sample_kept            numel(ids)
%       S.<kind>.sampled     true when ids/details hold fewer notes than count
%       S.<kind>.distinct_details        every distinct non-empty DETAIL, in
%                            order of first appearance (EXACT, not sampled)
%       S.<kind>.distinct_detail_counts  how many notes carry each (EXACT);
%                            count - sum(distinct_detail_counts) notes had none
%     and, for S.carried_as_v1 only (practice (d) of [migration reliability
%     practices], Jess Haley, 2026-10-26: carry counts by register row in the
%     migration report), read from the `[carry-NNN]` tags of the DETAILs
%     (EXACT, from distinct_details):
%       .register_rows          every carry register row id cited, sorted
%       .register_row_counts    how many notes cite each (a note citing two
%                               rows counts once under each)
%       .notes_citing_a_row     notes whose DETAIL cites at least one row
%       .notes_citing_no_row    notes whose DETAIL cites none (count minus
%                               the line above: the denominator is .count)
%
%   WHY A SAMPLE (2026-10-22). Every note used to be kept, appended one struct
%   at a time (`notes(end+1)`) and copied again into ids/details by 'collect'.
%   jCalculation leaves one `field_dropped` note per dropped v1 field per
%   calculator, and a corpus such as Soph holds ~69k calculators, so the
%   notes grew quadratically in time and linearly in memory inside one
%   v1_to_v2 call. Counts, the per-class counts and the per-DETAIL counts stay
%   exact; only the per-note id list is a sample, and the summary says so.
%   'mark' / 'truncate' keep their meaning: notes since the last 'mark' are
%   held apart until the next 'mark' or 'collect', so truncating back to that
%   mark drops them exactly. Truncating to before the last 'mark' would need
%   notes that are no longer held; it raises
%   did2:convert:reportNote:truncateBeforeMark rather than miscount.
%
%   KINDS IN USE:
%     carried_as_v1   a v1 document the generic stage could place only in part,
%                     so it was returned UNCHANGED and is carried whole as v1
%                     (pass 1 records it as a passthrough; ndi.migrate.local
%                     stores it as its v1 source, stamped 'did_v1'). DETAIL
%                     names what could not be placed. [generic stage is
%                     lossless] and [partly placed is carried as v1] (Jess
%                     Haley, 2026-10-25, did-schema
%                     V_eta_go_forward_class_audit.md).
%                     DETAIL cites the row of did-schema
%                     schemas/V_eta_carry_register.json that covers each
%                     reason, as a `[carry-NNN]` tag before that reason: at the
%                     start when the whole note is one row's ('[carry-022]
%                     needs_mapping: ...'), before each item when its items are
%                     different rows' ([carry register], Jess Haley,
%                     2026-10-26). Each call site says which rows it cites in
%                     a `% carry-register:` comment above it, `none` for a
%                     reason with no row yet; tools/check_carry_citations.py
%                     checks both against the register and lists the `none`s.
%     carried_with_element  ONE note per global-clock `oneepoch` the
%                     migrator hands back unchanged to be carried with its
%                     output element ([global-clock oneepoch carried with its
%                     element], Jess Haley, 2026-10-30); DETAIL is the
%                     element's id. v1_to_v2 carries the source and writes its
%                     `carried_as_v1` note, citing that element's carry rows,
%                     once every source is migrated (carryOneEpochsWithElement).
%     ntrode_electrode_count  ONE note per n-trode device the element
%                     migrator converts: whether its "number of electrodes"
%                     (EMPTY:0000408) was written from the channel list of its
%                     epochprobemap `devicestring`, and if not, why
%                     ([n-trode count from the channel list], Jess Haley,
%                     2026-10-29; did2.convert.nTrodeElectrodeCounts). The
%                     count is the denominator.
%     v1_name_statement_carried  ONE note per source carried because it
%                     would become a STATEMENT and its non-empty v1 base.name
%                     has no home ([v1 name goes to the class's own name
%                     field], Jess Haley, 2026-10-27: "the number of such
%                     statements is counted in the next corpus run"); DETAIL
%                     is the name. v1_to_v2 writes it beside the carry's own
%                     `carried_as_v1` note.
%     needs_info      ONE note per `base.needs_info` entry a migrator writes
%                     on a document it emits: a fact the source never stated
%                     ([missing facts are needs info], Jess Haley, 2026-10-29,
%                     did-schema V_eta_go_forward_class_audit.md: "the
%                     migration report counts the entries"). DETAIL is the
%                     entry's field path ('coordinate_system.reference_point').
%                     Written by probe_geometry (two per converted document).
%     route_unknown   a v1 treatment (treatment / treatment_drug) that names no
%                     location, so whether it was an immersion or a dose cannot
%                     be read from it; it migrates as a dose with a NaN amount
%                     (Jess Haley, 2026-10-21, did-schema
%                     V_eta_go_forward_class_audit.md).
%     dose_amount_conflict  a v1 treatment with two rows of one amount kind
%                     (two volumes, two masses, ...) that disagree: the dose
%                     keeps the first; DETAIL names the kind and both amounts
%                     (jDoseValue; Jess Haley, 2026-10-21, "a").
%     amount_placeholder  a v1 treatment row giving an amount per body mass
%                     of a VEHICLE (Hunsberger's saline `1 mg/kg`, copied from
%                     the drug group): no active ingredient, so it is written
%                     nowhere; the dose's volume is NaN. DETAIL is
%                     'substance: number unit' (jDoseValue; Jess Haley,
%                     2026-10-21 [dose per ingredient]).
%     field_dropped   a v1 field a calculator fold (jCalculation, via
%                     jTuningCurve / jContrastSensitivityValue) has no home for
%                     on did-schema #88; DETAIL is its path in the source
%                     document ('<block>.<field>'). One note per field.
%                     NO LONGER WRITTEN since 2026-10-25: such a document is
%                     carried whole as v1 (`carried_as_v1`).
%     stimulus_control_id  ONE note per v1 stimulus response document a
%                     response migrator (stimulus_response_scalar) converts:
%                     DETAIL 'none' (the edge was empty). A response whose
%                     edge names a document is carried whole as v1 since
%                     2026-10-25 (`carried_as_v1`), so 'dropped' is no
%                     longer written. The count is the denominator (Jess Haley,
%                     2026-10-22 [covariate rules named], 6.4 "A"); v1_to_v2
%                     prints "dropped of converted".
%     tuning_response_variable  ONE note per tuning / contrast-sensitivity
%                     calculator document jCalculation folds: DETAIL 'neural
%                     firing rate' or 'dF/F' when `variable` was set from v1
%                     `response_units`; 'not stated' (source gives none) or
%                     'unrecognised: <spelling>' when it got the general term
%                     EMPTY:0000398 "neural response" (Jess Haley 2026-10-22
%                     [response variable], [dF/F as variable]; 2026-10-23
%                     [unstated response variable]).
%                     The count is the denominator; v1_to_v2 prints it first.
%     non_area_ontology_node  a migrated ontologyImage raster whose ontology
%                     node is not an anatomical (UBERON) area: kept as a
%                     condition with the label variable 'ontology node';
%                     DETAIL is the node. Counted so the real values can be
%                     seen (Jess Haley, 2026-10-22 [non-area image node,
%                     revisited], not decided).

persistent st
if isempty(st)
    st = emptyState();
end
out = [];
switch action
    case 'reset'
        st = emptyState();
    case 'mark'
        st = commitPending(st);
        out = st.total;
    case 'truncate'
        n = arg2;
        if n >= st.total + st.nPending
            return;   % nothing recorded past N
        end
        if n < st.total
            error('did2:convert:reportNote:truncateBeforeMark', ...
                ['reportNote cannot truncate to %d: %d note(s) were committed ' ...
                 'by an earlier ''mark'' and only their counts are held. ' ...
                 'Truncate only to the most recent mark.'], n, st.total);
        end
        st.nPending = n - st.total;
    case 'pending'
        out = sum(strcmp(st.pKind(1:st.nPending), char(arg2)));
    case 'pendingDetails'
        hit = strcmp(st.pKind(1:st.nPending), char(arg2));
        out = st.pDetail(find(hit)); %#ok<FNDSB> 1xN even when st.pDetail is empty
        out = reshape(out, 1, []);
    case 'merge'
        out = mergeSummaries(arg2, arg3);
    case 'collect'
        st = commitPending(st);
        out = struct();
        for k = 1:numel(st.kinds)
            K = st.kinds{k};   % read only
            byClass = struct();
            for j = 1:numel(K.classNames)
                byClass.(K.classNames{j}) = K.classCounts(j);
            end
            out.(K.name) = struct( ...
                'count', K.count, ...
                'by_class', byClass, ...
                'ids', {K.ids(1:K.nSample)}, ...
                'details', {K.details(1:K.nSample)}, ...
                'sample_cap_per_class', sampleCap(), ...
                'sample_kept', K.nSample, ...
                'sampled', K.nSample < K.count, ...
                'distinct_details', {K.detailValues}, ...
                'distinct_detail_counts', K.detailCounts);
            if strcmp(K.name, 'carried_as_v1')
                [rows, rowCounts, nCiting] = registerRowCounts( ...
                    K.detailValues, K.detailCounts);
                out.(K.name).register_rows = rows;
                out.(K.name).register_row_counts = rowCounts;
                out.(K.name).notes_citing_a_row = nCiting;
                out.(K.name).notes_citing_no_row = K.count - nCiting;
            end
        end
    otherwise
        % record: reportNote(KIND, CLASSNAME, DOCID)
        className = '';
        docId = '';
        if nargin >= 2; className = arg2; end
        if nargin >= 3; docId = arg3; end
        detail = '';
        if nargin >= 4; detail = arg4; end
        % held apart until the next 'mark' / 'collect' (see header); the buffer
        % doubles, so a long run of notes with no mark is still linear
        n = st.nPending + 1;
        if n > numel(st.pKind)
            grow = max(16, numel(st.pKind));
            st.pKind{end + grow} = '';
            st.pClass{end + grow} = '';
            st.pId{end + grow} = '';
            st.pDetail{end + grow} = '';
        end
        st.pKind{n} = char(action);
        st.pClass{n} = char(className);
        st.pId{n} = char(docId);
        st.pDetail{n} = char(detail);
        st.nPending = n;
end
end

function c = sampleCap()
%SAMPLECAP How many notes of each (kind, class) keep their id and detail.
c = 20;
end

function st = emptyState()
st = struct();
st.total = 0;              % committed notes (all kinds)
st.kinds = {};             % one struct per kind, in order of first appearance
st.kindIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
st.nPending = 0;           % notes since the last 'mark', not yet committed
st.pKind = {};
st.pClass = {};
st.pId = {};
st.pDetail = {};
end

function st = commitPending(st)
%COMMITPENDING Fold the held notes into the exact counts and the capped sample.
%   Indexes into st.kinds{ki} directly (no copy of a kind per note); the
%   containers.Map indexes are handles, so they update in place.
if st.nPending == 0
    return;
end
cap = sampleCap();
for p = 1:st.nPending
    f = matlab.lang.makeValidName(st.pKind{p});
    if isKey(st.kindIndex, f)
        ki = st.kindIndex(f);
    else
        ki = numel(st.kinds) + 1;
        st.kinds{ki} = struct('name', f, 'count', 0, ...
            'classNames', {{}}, 'classCounts', [], 'classSampled', [], ...
            'classIndex', containers.Map('KeyType', 'char', 'ValueType', 'double'), ...
            'ids', {{}}, 'details', {{}}, 'nSample', 0, ...
            'detailValues', {{}}, 'detailCounts', [], ...
            'detailIndex', containers.Map('KeyType', 'char', 'ValueType', 'double'));
        kindIndex = st.kindIndex;
        kindIndex(f) = ki; %#ok<NASGU> handle: updates st.kindIndex
    end
    st.kinds{ki}.count = st.kinds{ki}.count + 1;
    c = matlab.lang.makeValidName(st.pClass{p});
    classIndex = st.kinds{ki}.classIndex;
    if isKey(classIndex, c)
        ci = classIndex(c);
        st.kinds{ki}.classCounts(ci) = st.kinds{ki}.classCounts(ci) + 1;
    else
        ci = numel(st.kinds{ki}.classNames) + 1;
        st.kinds{ki}.classNames{ci} = c;
        st.kinds{ki}.classCounts(ci) = 1;
        st.kinds{ki}.classSampled(ci) = 0;
        classIndex(c) = ci;
    end
    if st.kinds{ki}.classSampled(ci) < cap
        % bounded by cap x classes, so growing by one is cheap here
        st.kinds{ki}.classSampled(ci) = st.kinds{ki}.classSampled(ci) + 1;
        m = st.kinds{ki}.nSample + 1;
        st.kinds{ki}.nSample = m;
        st.kinds{ki}.ids{m} = st.pId{p};
        st.kinds{ki}.details{m} = st.pDetail{p};
    end
    d = st.pDetail{p};
    if ~isempty(d)
        detailIndex = st.kinds{ki}.detailIndex;
        if isKey(detailIndex, d)
            di = detailIndex(d);
            st.kinds{ki}.detailCounts(di) = st.kinds{ki}.detailCounts(di) + 1;
        else
            di = numel(st.kinds{ki}.detailValues) + 1;
            st.kinds{ki}.detailValues{di} = d;
            st.kinds{ki}.detailCounts(di) = 1;
            detailIndex(d) = di;
        end
    end
end
st.total = st.total + st.nPending;
st.nPending = 0;
end

function a = mergeSummaries(a, b)
%MERGESUMMARIES Two 'collect' summaries as one (see 'merge' in the header).
if isempty(a); a = struct(); end
if isempty(b); return; end
kinds = fieldnames(b);
for i = 1:numel(kinds)
    f = kinds{i};
    B = b.(f);
    if ~isfield(a, f)
        a.(f) = B;
        continue;
    end
    A = a.(f);
    A.count = A.count + B.count;
    cls = fieldnames(B.by_class);
    for j = 1:numel(cls)
        if isfield(A.by_class, cls{j})
            A.by_class.(cls{j}) = A.by_class.(cls{j}) + B.by_class.(cls{j});
        else
            A.by_class.(cls{j}) = B.by_class.(cls{j});
        end
    end
    cap = sampleCap();
    room = sum(min(cellfun(@(c) A.by_class.(c), fieldnames(A.by_class)), cap));
    for j = 1:numel(B.ids)
        if numel(A.ids) >= room; break; end
        A.ids{end+1} = B.ids{j};
        A.details{end+1} = B.details{j};
    end
    A.sample_kept = numel(A.ids);
    A.sampled = A.sample_kept < A.count;
    for j = 1:numel(B.distinct_details)
        hit = find(strcmp(A.distinct_details, B.distinct_details{j}), 1);
        if isempty(hit)
            A.distinct_details{end+1} = B.distinct_details{j};
            A.distinct_detail_counts(end+1) = B.distinct_detail_counts(j);
        else
            A.distinct_detail_counts(hit) = A.distinct_detail_counts(hit) ...
                + B.distinct_detail_counts(j);
        end
    end
    if isfield(A, 'register_rows')
        [rows, rowCounts, nCiting] = registerRowCounts(A.distinct_details, ...
            A.distinct_detail_counts);
        A.register_rows = rows;
        A.register_row_counts = rowCounts;
        A.notes_citing_a_row = nCiting;
        A.notes_citing_no_row = A.count - nCiting;
    end
    a.(f) = A;
end
end

function [rows, rowCounts, nCiting] = registerRowCounts(details, counts)
%REGISTERROWCOUNTS The carry register rows the DETAILS cite ([carry register],
%   Jess Haley, 2026-10-26: a `[carry-NNN]` tag before each reason it covers),
%   each with how many notes cite it, and how many notes cite any row.
%   DETAILS are distinct, COUNTS how many notes carry each, so the counts are
%   exact. A note citing two rows counts once under each row and once in
%   NCITING.
rows = {};
rowCounts = zeros(1, 0);
nCiting = 0;
for j = 1:numel(details)
    toks = regexp(details{j}, '\[(carry-\d{3})\]', 'tokens');
    if isempty(toks); continue; end
    ids = unique(cellfun(@(t) t{1}, toks, 'UniformOutput', false));
    nCiting = nCiting + counts(j);
    for r = 1:numel(ids)
        hit = find(strcmp(rows, ids{r}), 1);
        if isempty(hit)
            rows{end+1} = ids{r}; %#ok<AGROW>
            rowCounts(end+1) = counts(j); %#ok<AGROW>
        else
            rowCounts(hit) = rowCounts(hit) + counts(j);
        end
    end
end
[rows, order] = sort(rows);
rowCounts = rowCounts(order);
end
