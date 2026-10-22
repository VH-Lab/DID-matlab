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
%     stimulus_control_id  ONE note per v1 stimulus response document a
%                     response migrator (stimulus_response_scalar) converts:
%                     DETAIL 'dropped' when its `stimulus_control_id` edge
%                     named a document, which the V2 calculation does not
%                     carry ([control as covariate]), 'none' when the edge was
%                     empty. The count is the denominator (Jess Haley,
%                     2026-10-22 [covariate rules named], 6.4 "A"); v1_to_v2
%                     prints "dropped of converted".
%     tuning_response_variable  ONE note per tuning / contrast-sensitivity
%                     calculator document jCalculation folds: DETAIL 'neural
%                     firing rate' or 'dF/F' when `variable` was set from v1
%                     `response_units`, 'not stated' when the source gives none,
%                     'unrecognised: <spelling>' otherwise (Jess Haley
%                     2026-10-22 [response variable], [dF/F as variable]).
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
