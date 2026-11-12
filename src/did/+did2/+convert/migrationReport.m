function out = migrationReport(action, varargin)
%MIGRATIONREPORT The migration run's report: every gap, carry and known v1 defect, by document.
%
%   Decided by Jess Haley, 2026-11-01 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md):
%     [migration record]   a migrated document no longer says what its source
%                          left out (`base.needs_info` is dropped); one
%                          `migration` document is written per run, and the
%                          run's report (every missing fact, by document and
%                          field, with the reason, plus the run's counts) is
%                          its data body.
%     [gap accepted when the report lists it]  a migrated document may lack a
%                          required field only when its run's migration report
%                          lists that document and field with a reason; any
%                          other missing required field fails validation.
%     [migration report is an attached file]   the report is a JSON file
%                          holding `gaps` (document_id, class, field, reason),
%                          `carried_as_v1` (document_id, class, carry, reason)
%                          and `counts`; each gap's reason is text.
%     [known v1 defects list]  (Jess Haley, 2026-11-12) a third list,
%                          `known_v1_defects` (document_id, class, field,
%                          reason), one entry per migrated document that
%                          carries a known defect of its v1 source, with its
%                          count in `counts`. It is separate from the gaps (a
%                          gap is a fact the source never stated; a defect is
%                          about a value the document DOES give, so a defect
%                          entry must name a field the document gives) and
%                          from the carries (the document is migrated, not
%                          carried). The validator reads only the gaps. First
%                          use: a contrastsensitivity_calc whose spatial
%                          frequencies are all one value
%                          (jRepeatedSpatialFrequency).
%     [response computed from the spike times]  (Jess Haley, 2026-11-12) "a
%                          response with no matching observation: list it in
%                          the migration report (a named, counted entry), not
%                          guessed": a fourth list, `inputs_not_found`
%                          (document_id, class, input, reason), one entry per
%                          migrated document an input it is computed from could
%                          not be found for, with its count in `counts`. First
%                          use: a stimulus response with no spike-times
%                          observation of its unit for its epoch
%                          (did2.convert.resolveResponseParameters).
%
%   This function holds the report of the run in progress. The validator
%   (did2.schema.reportedGaps) reads the gaps of a document from it, so a
%   document is accepted with a missing required field only while the run
%   that lists the gap is held (or after its report is loaded again, 'load').
%
%   did2.convert.migrationReport('begin')
%       start a run, forgetting any earlier one. A run writer
%       (did2.convert.fromV1Database, NDI's ndi.migrate.local) begins one;
%       did2.convert.v1_to_v2 begins one only when none is held, and leaves
%       it held after it returns, so a caller can still validate what it
%       migrated ([migration record writer]: NDI writes one record from the
%       reports of all its DID-matlab calls).
%   did2.convert.migrationReport('call')
%       what did2.convert.v1_to_v2 does as it starts: begin a run of its own
%       when none is held, or when the one held is a run an earlier call
%       began for itself (a 'begin' by a run writer is never replaced), and
%       count the call as open. CLEANUP closes it when deleted (v1_to_v2
%       holds it until it returns), so a call made inside another (a batch
%       pass) never replaces the run of the call around it. Two calls made one
%       after the other with no run writer are two runs: a gap of the first
%       is not read against the documents of the second, which may share its
%       (deterministic) ids.
%   did2.convert.migrationReport('end')
%       forget the run.
%   TF = did2.convert.migrationReport('active')
%       true while a run is held.
%   did2.convert.migrationReport('gap', DOCID, CLASSNAME, FIELD, REASON)
%       list one gap: document DOCID (of class CLASSNAME) lacks FIELD
%       ('<block>.<field>', with (k) after a struct-array field:
%       'coordinate_system.axes(2).positive_direction') because REASON.
%       did2.build.document's 'Gaps' option calls this. With no run held it
%       begins one first (a migrator called on its own, as a unit test
%       calls it, still lists its gaps somewhere a validator reads).
%   G = did2.convert.migrationReport('gaps', DOCID)
%       the gaps listed for DOCID, a struct array {field, reason} (0x0 when
%       none, or when no run is held).
%   did2.convert.migrationReport('defect', DOC, FIELD, REASON)
%       list one known v1 defect of the migrated document DOC (a document
%       struct or did2.document): its value at FIELD (a path as a gap names
%       one) is migrated as the source wrote it, and REASON says what is
%       wrong with it. DOC must give FIELD (did2.schema.givesField), else
%       did2:convert:badKnownDefect. Listed once per document and field (the
%       latest). Never a gap: 'gaps' and the validator do not read it. With
%       no run held it begins one first, as 'gap' does.
%   D = did2.convert.migrationReport('defects', DOCID)
%       the known v1 defects listed for DOCID, a struct array {field, reason}
%       (0x0 when none, or when no run is held).
%   did2.convert.migrationReport('inputNotFound', DOCID, CLASSNAME, INPUT, REASON)
%       list one input of the migrated document DOCID (of class CLASSNAME)
%       that the migration looked for and did not find: INPUT names it
%       ('spike times'), REASON says why ([response computed from the spike
%       times]). Listed once per document and input (the latest). With no
%       run held it begins one first, as 'gap' does.
%   N = did2.convert.migrationReport('inputsNotFound', DOCID)
%       the inputs not found listed for DOCID, a struct array {input, reason}
%       (0x0 when none, or when no run is held).
%   did2.convert.migrationReport('carried', DOCID, CLASSNAME, CARRY, REASON)
%       a document carried whole as v1: CARRY the carry register row(s) it
%       cites ('carry-064', '' when none), REASON what could not be placed.
%       A second entry for one document adds its reason to the first.
%       did2.convert.reportNote records each `carried_as_v1` note here.
%       Ignored when no run is held.
%   R = did2.convert.migrationReport('collect', DOCS)
%       the report of the documents DOCS (a cell of did2.document or document
%       structs: what the run writes), as the attached file holds it:
%         R.gaps            struct array {document_id, class, field, reason},
%                           in the order of DOCS: only gaps of a document in
%                           DOCS (a gap listed for a document that was later
%                           quarantined, discarded or replaced is not in it)
%         R.carried_as_v1   struct array {document_id, class, carry, reason}:
%                           every document of DOCS that is not a v2 document
%                           and was recorded as carried, and every document
%                           stamped 'did_v1' (the reason of one with no
%                           recorded carry says so)
%         R.known_v1_defects  struct array {document_id, class, field,
%                           reason}, in the order of DOCS: only defects of a
%                           document in DOCS that still gives the field (a
%                           document carried as v1 in the end does not)
%         R.inputs_not_found  struct array {document_id, class, input,
%                           reason}, in the order of DOCS: only entries of a
%                           document in DOCS that is a v2 document in the end
%         R.counts          documents (numel(DOCS), the denominator of what
%                           follows), gaps, documents_with_gaps,
%                           gaps_by_class {class, count}, carried_as_v1 (the
%                           denominator of the two lines after it),
%                           carried_by_register_row {row, count} (a carry
%                           citing two rows counts under each),
%                           carried_citing_a_row, carried_citing_no_row
%                           (practice (d) of [migration reliability
%                           practices], Jess Haley, 2026-10-26: carry counts by
%                           register row, with the denominator),
%                           known_v1_defects (entries listed),
%                           inputs_not_found (entries listed).
%   did2.convert.migrationReport('load', R)
%       begin a run holding R's gaps, carries, known v1 defects and inputs
%       not found (R a
%       'collect' result, or
%       the attached file's JSON decoded), so documents migrated by that run
%       can be validated again.
%
%   See also did2.convert.migrationRecord, did2.schema.reportedGaps,
%            did2.build.document, did2.convert.reportNote.

persistent st
if isempty(st)
    st = emptyState(false);
end
out = [];
switch char(action)
    case 'begin'
        st = emptyState(true);
    case 'call'
        if ~st.active || (st.own && st.depth == 0)
            st = emptyState(true);
            st.own = true;
        end
        st.depth = st.depth + 1;
        out = onCleanup(@() did2.convert.migrationReport('-leave'));
    case '-leave'
        st.depth = max(0, st.depth - 1);
    case 'end'
        st = emptyState(false);
    case 'active'
        out = st.active;
    case 'gap'
        if ~st.active
            st = emptyState(true);
        end
        [docId, cls, field, reason] = deal(text(varargin{1}), text(varargin{2}), ...
            text(varargin{3}), text(varargin{4}));
        if isempty(docId) || isempty(field) || isempty(reason)
            error('did2:convert:badGap', ...
                'A gap needs a document id, a field and a reason (got "%s", "%s", "%s").', ...
                docId, field, reason);
        end
        e = struct('class', cls, 'field', field, 'reason', reason);
        m = st.gaps;
        if isKey(m, docId)
            prev = m(docId);
            hit = find(strcmp({prev.field}, field), 1);
            if isempty(hit)
                m(docId) = [prev, e]; %#ok<NASGU> handle
            else
                prev(hit) = e;   % listed once per document and field: the latest
                m(docId) = prev; %#ok<NASGU> handle
            end
        else
            m(docId) = e; %#ok<NASGU> handle
        end
    case 'defect'
        if ~st.active
            st = emptyState(true);
        end
        s = varargin{1};
        if isa(s, 'did2.document')
            s = s.toStruct();
        end
        [field, reason] = deal(text(varargin{2}), text(varargin{3}));
        id = idOf(s);   % (docId is a variable of this function: the 'gap' case)
        if isempty(id) || isempty(field) || isempty(reason)
            error('did2:convert:badKnownDefect', ...
                'A known v1 defect needs a document with an id, a field and a reason (got "%s", "%s", "%s").', ...
                id, field, reason);
        end
        if ~did2.schema.givesField(s, field)
            error('did2:convert:badKnownDefect', ...
                ['A known v1 defect is about a value the document gives, and %s ' ...
                 'gives none at "%s".'], id, field);
        end
        e = struct('class', classOf(s), 'field', field, 'reason', reason);
        m = st.defects;
        if isKey(m, id)
            prev = m(id);
            hit = find(strcmp({prev.field}, field), 1);
            if isempty(hit)
                m(id) = [prev, e]; %#ok<NASGU> handle
            else
                prev(hit) = e;   % listed once per document and field: the latest
                m(id) = prev; %#ok<NASGU> handle
            end
        else
            m(id) = e; %#ok<NASGU> handle
        end
    case 'inputNotFound'
        if ~st.active
            st = emptyState(true);
        end
        [docId, cls, input, reason] = deal(text(varargin{1}), text(varargin{2}), ...
            text(varargin{3}), text(varargin{4}));
        if isempty(docId) || isempty(input) || isempty(reason)
            error('did2:convert:badInputNotFound', ...
                'An input not found needs a document id, an input and a reason (got "%s", "%s", "%s").', ...
                docId, input, reason);
        end
        e = struct('class', cls, 'input', input, 'reason', reason);
        m = st.inputs;
        if isKey(m, docId)
            prev = m(docId);
            hit = find(strcmp({prev.input}, input), 1);
            if isempty(hit)
                m(docId) = [prev, e]; %#ok<NASGU> handle
            else
                prev(hit) = e;   % listed once per document and input: the latest
                m(docId) = prev; %#ok<NASGU> handle
            end
        else
            m(docId) = e; %#ok<NASGU> handle
        end
    case 'inputsNotFound'
        out = struct('input', {}, 'reason', {});
        if ~st.active || st.inputs.Count == 0
            return;
        end
        docId = text(varargin{1});
        if ~isempty(docId) && isKey(st.inputs, docId)
            g = st.inputs(docId);
            out = struct('input', {g.input}, 'reason', {g.reason});
        end
    case 'defects'
        out = struct('field', {}, 'reason', {});
        if ~st.active || st.defects.Count == 0
            return;
        end
        id = text(varargin{1});
        if ~isempty(id) && isKey(st.defects, id)
            g = st.defects(id);
            out = struct('field', {g.field}, 'reason', {g.reason});
        end
    case 'gaps'
        out = struct('field', {}, 'reason', {});
        if ~st.active || st.gaps.Count == 0
            return;
        end
        docId = text(varargin{1});
        if ~isempty(docId) && isKey(st.gaps, docId)
            g = st.gaps(docId);
            out = struct('field', {g.field}, 'reason', {g.reason});
        end
    case 'carried'
        if ~st.active
            return;
        end
        [docId, cls, carry, reason] = deal(text(varargin{1}), text(varargin{2}), ...
            text(varargin{3}), text(varargin{4}));
        if isempty(docId)
            return;
        end
        m = st.carried;
        if isKey(m, docId)
            e = m(docId);
            e.carry = joinRows(e.carry, carry);
            if ~isempty(reason) && ~contains(e.reason, reason)
                if isempty(e.reason)
                    e.reason = reason;
                else
                    e.reason = [e.reason '; ' reason];
                end
            end
            m(docId) = e; %#ok<NASGU> handle
        else
            m(docId) = struct('class', cls, 'carry', joinRows('', carry), ...
                'reason', reason); %#ok<NASGU> handle
        end
    case 'collect'
        out = collect(st, varargin{1});
    case 'load'
        st = emptyState(true);
        r = varargin{1};
        if isfield(r, 'gaps')
            g = asStructs(r.gaps);
            for k = 1:numel(g)
                migrationReportAdd(st, 'gap', g(k));
            end
        end
        if isfield(r, 'carried_as_v1')
            c = asStructs(r.carried_as_v1);
            for k = 1:numel(c)
                migrationReportAdd(st, 'carried', c(k));
            end
        end
        if isfield(r, 'known_v1_defects')
            d = asStructs(r.known_v1_defects);
            for k = 1:numel(d)
                migrationReportAdd(st, 'defect', d(k));
            end
        end
        if isfield(r, 'inputs_not_found')
            d = asStructs(r.inputs_not_found);
            for k = 1:numel(d)
                migrationReportAdd(st, 'input', d(k));
            end
        end
    otherwise
        error('did2:convert:badArgument', ...
            'migrationReport: unknown action "%s".', char(action));
end
end

% =============================================================================

function st = emptyState(active)
st = struct('active', active, 'own', false, 'depth', 0, ...
    'gaps', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'carried', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'defects', containers.Map('KeyType', 'char', 'ValueType', 'any'), ...
    'inputs', containers.Map('KeyType', 'char', 'ValueType', 'any'));
end

function migrationReportAdd(st, kind, e)
% one entry of a loaded report, into the (handle) maps of ST
docId = text(fieldOr(e, 'document_id'));
if isempty(docId); return; end
switch kind
    case 'gap'
        x = struct('class', text(fieldOr(e, 'class')), 'field', ...
            text(fieldOr(e, 'field')), 'reason', text(fieldOr(e, 'reason')));
        m = st.gaps;
        if isKey(m, docId)
            m(docId) = [m(docId), x]; %#ok<NASGU> handle
        else
            m(docId) = x; %#ok<NASGU> handle
        end
    case 'defect'
        x = struct('class', text(fieldOr(e, 'class')), 'field', ...
            text(fieldOr(e, 'field')), 'reason', text(fieldOr(e, 'reason')));
        m = st.defects;
        if isKey(m, docId)
            m(docId) = [m(docId), x]; %#ok<NASGU> handle
        else
            m(docId) = x; %#ok<NASGU> handle
        end
    case 'input'
        x = struct('class', text(fieldOr(e, 'class')), 'input', ...
            text(fieldOr(e, 'input')), 'reason', text(fieldOr(e, 'reason')));
        m = st.inputs;
        if isKey(m, docId)
            m(docId) = [m(docId), x]; %#ok<NASGU> handle
        else
            m(docId) = x; %#ok<NASGU> handle
        end
    case 'carried'
        m = st.carried;
        m(docId) = struct('class', text(fieldOr(e, 'class')), 'carry', ...
            text(fieldOr(e, 'carry')), 'reason', text(fieldOr(e, 'reason'))); %#ok<NASGU>
end
end

function r = collect(st, docs)
if ~iscell(docs)
    docs = num2cell(docs);
end
gaps = struct('document_id', {}, 'class', {}, 'field', {}, 'reason', {});
carried = struct('document_id', {}, 'class', {}, 'carry', {}, 'reason', {});
defects = struct('document_id', {}, 'class', {}, 'field', {}, 'reason', {});
inputs = struct('document_id', {}, 'class', {}, 'input', {}, 'reason', {});
withGaps = 0;
for k = 1:numel(docs)
    s = docs{k};
    if isa(s, 'did2.document')
        s = s.toStruct();
    end
    id = docId(s);
    if isempty(id)
        continue;
    end
    cls = className(s);
    if st.gaps.Count > 0 && isKey(st.gaps, id)
        g = st.gaps(id);
        withGaps = withGaps + 1;
        for j = 1:numel(g)
            c = g(j).class;
            if isempty(c); c = cls; end
            gaps(end+1) = struct('document_id', id, 'class', c, ...
                'field', g(j).field, 'reason', g(j).reason); %#ok<AGROW>
        end
    end
    if st.defects.Count > 0 && isKey(st.defects, id)
        d = st.defects(id);
        for j = 1:numel(d)
            if ~did2.schema.givesField(s, d(j).field)
                continue;   % the document written does not hold that value
            end
            c = d(j).class;
            if isempty(c); c = cls; end
            defects(end+1) = struct('document_id', id, 'class', c, ...
                'field', d(j).field, 'reason', d(j).reason); %#ok<AGROW>
        end
    end
    stamp = did2.schema.stampOf(s);
    if did2.schema.isV2Stamp(stamp)
        if st.inputs.Count > 0 && isKey(st.inputs, id)
            g = st.inputs(id);
            for j = 1:numel(g)
                c = g(j).class;
                if isempty(c); c = cls; end
                inputs(end+1) = struct('document_id', id, 'class', c, ...
                    'input', g(j).input, 'reason', g(j).reason); %#ok<AGROW>
            end
        end
        continue;   % converted in the end: not a carry
    end
    if st.carried.Count > 0 && isKey(st.carried, id)
        e = st.carried(id);
        c = e.class;
        if isempty(c); c = cls; end
        carried(end+1) = struct('document_id', id, 'class', c, ...
            'carry', e.carry, 'reason', e.reason); %#ok<AGROW>
    elseif did2.schema.isV1Stamp(stamp, 'Explicit', true)
        carried(end+1) = struct('document_id', id, 'class', cls, 'carry', '', ...
            'reason', ['no migration step changed it, so it is kept as its v1 ' ...
            'source ([passthrough stays v1])']); %#ok<AGROW>
    end
end
r = struct();
r.gaps = gaps;
r.carried_as_v1 = carried;
r.known_v1_defects = defects;
r.inputs_not_found = inputs;
r.counts = counts(numel(docs), gaps, withGaps, carried, defects, inputs);
end

function c = counts(nDocs, gaps, withGaps, carried, defects, inputs)
c = struct();
c.documents = nDocs;
c.gaps = numel(gaps);
c.documents_with_gaps = withGaps;
c.gaps_by_class = tally({gaps.class}, 'class');
c.carried_as_v1 = numel(carried);
rows = {};
citing = 0;
for k = 1:numel(carried)
    r = regexp(carried(k).carry, 'carry-\d{3}', 'match');
    r = unique(r, 'stable');
    if ~isempty(r)
        citing = citing + 1;
    end
    rows = [rows, r]; %#ok<AGROW>
end
c.carried_by_register_row = tally(rows, 'row');
c.carried_citing_a_row = citing;
c.carried_citing_no_row = numel(carried) - citing;
c.known_v1_defects = numel(defects);
c.inputs_not_found = numel(inputs);
end

function t = tally(names, label)
% struct array {<label>, count}, sorted by name
t = struct(label, {}, 'count', {});
if isempty(names)
    return;
end
[u, ~, j] = unique(reshape(names, 1, []));
n = accumarray(j(:), 1);
for k = 1:numel(u)
    t(end+1) = struct(label, u{k}, 'count', n(k)); %#ok<AGROW>
end
end

function rows = joinRows(a, b)
% the carry register rows of A and B, distinct, sorted, ', '-joined
r = [regexp(char(a), 'carry-\d{3}', 'match'), regexp(char(b), 'carry-\d{3}', 'match')];
rows = '';
if ~isempty(r)
    rows = strjoin(reshape(unique(r), 1, []), ', ');
end
end

function id = idOf(s)
% the document id of S ('' when none); named apart from the main function's
% `docId` variable
id = docId(s);
end

function c = classOf(s)
c = className(s);
end

function id = docId(s)
id = '';
if isstruct(s) && isfield(s, 'base') && isstruct(s.base) && isfield(s.base, 'id')
    id = text(s.base.id);
end
end

function c = className(s)
c = '';
if isstruct(s) && isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = text(s.document_class.class_name);
end
end

function v = fieldOr(s, name)
v = '';
if isstruct(s) && isfield(s, name)
    v = s.(name);
end
end

function c = asStructs(x)
% a struct array from a struct array or a cell of structs (jsondecode gives
% either)
if iscell(x)
    c = [x{:}];
else
    c = x;
end
if isempty(c)
    c = struct([]);
end
end

function t = text(v)
if ischar(v) || (isstring(v) && isscalar(v))
    t = strtrim(char(v));
else
    t = '';
end
end
