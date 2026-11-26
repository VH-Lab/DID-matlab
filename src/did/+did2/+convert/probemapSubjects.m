function subjects = probemapSubjects(action, arg)
%PROBEMAPSUBJECTS The subjectstrings the batch's epochprobemap rows name for
%   each probe, so a probe recorded from several subjects can be found before
%   it is migrated.
%
%   WHY. A v1 element names ONE subject. did2.convert.resolveEpochProbemap
%   mints one observation per probe-map row, its specimen the row's
%   subjectstring, and retires the element's `observes` relation once an
%   observation carries the pair. A probe whose rows name two or more
%   subjects (4 Dab probes) then has observations of two specimens, and its
%   v1 subject link and `direct` flag cannot be rebuilt (the whole-batch
%   round trip: "the observations this element is the instrument of name 2
%   specimens (a v1 element has one subject)"). Which subject such a probe
%   "has" is the dataset's question: [dataset-specific logic leaves the
%   generic migration] (Jess Haley, 2026-10-26) and the lossless rule, so the
%   generic stage carries the element whole as v1 (migrators_j.element) and
%   the dataset map decides (did-schema docs/V2_PLAN.md G94).
%
%   A per-document migrator cannot follow an edge, so did2.convert.v1_to_v2
%   indexes the batch before the first migrator runs (as
%   did2.convert.nTrodeElectrodeCounts).
%
%   did2.convert.probemapSubjects('reset')        forget all
%   did2.convert.probemapSubjects('load', BODIES) index the cell BODIES
%       (structs or JSON text): every v1 `element` (its session, name and
%       reference) and every epochprobemap row held by an
%       `epochfiles_ingested` (its session, name, reference and non-empty
%       subjectstring). Adds to what is held; v1_to_v2 resets first.
%   SUBJECTS = did2.convert.probemapSubjects('get', ELEMENTID): the distinct
%       non-empty subjectstrings of the rows that name the v1 element
%       ELEMENTID ({} when none). A row names its probe as
%       resolveEpochProbemap joins it: session, name and reference (the
%       reference compared as text, an integer as int2str writes it).
%   OTHERS = did2.convert.probemapSubjects('others', ELEMENTID): those of
%       SUBJECTS that are not the element's own subject, the
%       `subject.local_identifier` of the v1 `subject` its `depends_on
%       subject_id` names (the column holds a local identifier, as
%       resolveEpochProbemap joins it). {} when the element names no subject
%       or its subject is not in the batch (nothing to compare with).
%       Decided by Jess Haley, 2026-11-26 (on VH-Lab/NDI-matlab#1309: "This
%       is malformed v1", then "Yes"): such an element is malformed v1 and is
%       carried whole, citing carry-170 (migrators_j.element). In the corpora
%       (2026-11-26): Dab 6 elements, the 4 two-subject probes carry-170
%       already carried and 2 stimulators; B, 20211116, JH, Soph and PRED 0.
%
%   See also did2.convert.migrators_j.element, did2.convert.nTrodeElectrodeCounts,
%            did2.convert.resolveEpochProbemap.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'get', 'others'})}
    arg = []
end

persistent elements rowSubjects elementSubject subjectNames
if isempty(elements) || ~isa(elements, 'containers.Map')
    elements = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
if isempty(elementSubject) || ~isa(elementSubject, 'containers.Map')
    elementSubject = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
if isempty(subjectNames) || ~isa(subjectNames, 'containers.Map')
    subjectNames = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
if isempty(rowSubjects) || ~isa(rowSubjects, 'containers.Map')
    rowSubjects = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
subjects = {};
switch action
    case 'reset'
        elements = containers.Map('KeyType', 'char', 'ValueType', 'char');
        rowSubjects = containers.Map('KeyType', 'char', 'ValueType', 'any');
        elementSubject = containers.Map('KeyType', 'char', 'ValueType', 'char');
        subjectNames = containers.Map('KeyType', 'char', 'ValueType', 'char');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        for k = 1:numel(bodies)
            b = bodies{k};
            if ischar(b) || (isstring(b) && isscalar(b))
                if ~contains(b, '"element"') && ~contains(b, 'epochprobemap') ...
                        && ~contains(b, '"subject"')
                    continue;
                end
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            switch classOf(b)
                case 'element'
                    el = blockOf(b, 'element');
                    id = baseText(b, 'id');
                    if isempty(id); continue; end
                    elements(id) = rowKey(baseText(b, 'session_id'), ...
                        textOf(fieldOf(el, 'name')), refText(fieldOf(el, 'reference')));
                    sj = subjectIdOf(b);
                    if ~isempty(sj)
                        elementSubject(id) = sj;
                    end
                case 'subject'
                    id = baseText(b, 'id');
                    if isempty(id); continue; end
                    subjectNames(id) = strtrim(textOf(fieldOf(blockOf(b, 'subject'), 'local_identifier')));
                case 'epochfiles_ingested'
                    pm = textOf(fieldOf(blockOf(b, 'epochfiles_ingested'), 'epochprobemap'));
                    if isempty(pm); continue; end
                    session = baseText(b, 'session_id');
                    rows = parseRows(pm);
                    for r = 1:numel(rows)
                        if isempty(rows(r).subjectstring); continue; end
                        key = rowKey(session, rows(r).name, rows(r).reference);
                        if isKey(rowSubjects, key)
                            have = rowSubjects(key);
                            if ~any(strcmp(have, rows(r).subjectstring))
                                rowSubjects(key) = [have, {rows(r).subjectstring}];
                            end
                        else
                            rowSubjects(key) = {rows(r).subjectstring};
                        end
                    end
            end
        end
    case 'get'
        id = char(arg);
        if isempty(id) || ~isKey(elements, id); return; end
        key = elements(id);
        if isKey(rowSubjects, key)
            subjects = rowSubjects(key);
        end
    case 'others'
        id = char(arg);
        if isempty(id) || ~isKey(elements, id) || ~isKey(elementSubject, id)
            return;
        end
        sj = elementSubject(id);
        if ~isKey(subjectNames, sj) || isempty(subjectNames(sj))
            return;   % its subject is not in the batch: nothing to compare
        end
        key = elements(id);
        if isKey(rowSubjects, key)
            named = rowSubjects(key);
            subjects = named(~strcmp(named, subjectNames(sj)) & ~strcmp(named, sj));
        end
end
end

function v = subjectIdOf(b)
% the element's `depends_on subject_id` value, '' when none
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on'); return; end
d = b.depends_on;
if isstruct(d); d = num2cell(d); end
if ~iscell(d); return; end
for k = 1:numel(d)
    e = d{k};
    if isstruct(e) && isfield(e, 'name') && strcmp(char(e.name), 'subject_id') ...
            && isfield(e, 'value') && (ischar(e.value) || (isstring(e.value) && isscalar(e.value)))
        v = strtrim(char(e.value));
        return;
    end
end
end

function rows = parseRows(s)
% name / reference / subjectstring of each row of a serialized epochprobemap
% (NDI epochprobemap_daqsystem.serialize), read as resolveEpochProbemap reads
% it: with an unrecognised header every non-empty line is a row
rows = struct('name', {}, 'reference', {}, 'subjectstring', {});
tab = sprintf('\t');
lines = strsplit(char(s), sprintf('\n'), 'CollapseDelimiters', false);
lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
if isempty(lines); return; end
expected = {'name', 'reference', 'type', 'devicestring', 'subjectstring'};
h = strsplit(lines{1}, tab, 'CollapseDelimiters', false);
if numel(h) == numel(expected) && all(cellfun(@(a, b) strcmpi(strtrim(a), b), h, expected))
    lines = lines(2:end);
end
for i = 1:numel(lines)
    c = strsplit(lines{i}, tab, 'CollapseDelimiters', false);
    c(end+1:5) = {''};
    rows(end+1) = struct('name', strtrim(c{1}), 'reference', strtrim(c{2}), ...
        'subjectstring', strtrim(c{5})); %#ok<AGROW>
end
end

function k = rowKey(session, name, reference)
k = sprintf('%s\t%s\t%s', strtrim(char(session)), strtrim(char(name)), strtrim(char(reference)));
end

function s = refText(r)
% a reference as text: an integer as int2str writes it, other numbers to 17
% digits, text trimmed
s = '';
if ischar(r) || (isstring(r) && isscalar(r))
    s = strtrim(char(r));
elseif (isnumeric(r) || islogical(r)) && isscalar(r)
    if r == round(r)
        s = int2str(r);
    else
        s = num2str(r, 17);
    end
end
end

function c = classOf(b)
c = '';
if isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
        && isstruct(b.document_class) && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
end

function blk = blockOf(b, name)
blk = struct();
if isfield(b, name) && isstruct(b.(name)) && isscalar(b.(name))
    blk = b.(name);
end
end

function v = fieldOf(s, name)
v = [];
if isstruct(s) && isfield(s, name); v = s.(name); end
end

function t = textOf(v)
t = '';
if ischar(v) || (isstring(v) && isscalar(v)); t = char(v); end
end

function t = baseText(b, name)
t = textOf(fieldOf(blockOf(b, 'base'), name));
end
