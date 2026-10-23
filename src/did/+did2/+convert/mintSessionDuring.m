function [bodies, refs, report] = mintSessionDuring(bodies, classes, marked, options)
%MINTSESSIONDURING Mint "during the session" time references for marked documents.
%
%   NAME = did2.convert.mintSessionDuring('marker') returns the name of the
%   TRANSIENT depends_on entry a migrator puts on a document that needs a
%   session time reference it cannot mint itself. The entry's value is the
%   document's OWN base.id, so if no pass ever runs it still names a document
%   that exists (no orphan, nothing empty).
%
%   [BODIES, REFS, REPORT] = did2.convert.mintSessionDuring(BODIES, CLASSES,
%   MARKED) takes the batch as structs (BODIES, with their class names
%   CLASSES) and the indices MARKED of the documents carrying the marker. For
%   each it finds the batch's session document, mints
%
%       did2.build.relativeTimeReference(<session document id>, ...
%           'Relation', 'intervalDuring')
%
%   (OWL-Time's interval relation, given by name as did2.build documents and
%   NDI's Haley import uses it), points the document's `time_reference_id` at
%   it, and REMOVES THE MARKER ON EVERY PATH. REFS are the minted references
%   (structs, Validate false); the caller validates and appends them.
%
%   THE DECISION. Lightsheet point 1, Jess 2026-10-14, option A: the batch
%   pass mints the session reference. jSessionAnchor and resolveSessionAnchors
%   are NOT used: their classes (session_relative_reference, relative_reference)
%   no longer exist in V_eta. Written as a helper so the later port of the 29
%   old jSessionAnchor callers can call it; they are not ported here.
%
%   THE LOOKUP is resolveSessionAnchors' (and jSessionDocId's header): a
%   document's `base.session_id` is NOT the session document's `base.id`
%   (ndi.document.m:57 mints base.id fresh; ndi.session.m:215 stamps
%   base.session_id separately), so the session DOCUMENT is found by indexing
%   the batch's session documents on their own `base.session_id`, and a
%   session id claimed by TWO documents is REFUSED rather than guessed at. A
%   session document is a `session` (the v1 class, as migrators_j.session
%   leaves it) or an `entity` whose `type` is 'session' (the V_eta form
%   ndi.setup.V2.entityDocuments writes).
%
%   NO SESSION DOCUMENT: the document keeps no time reference, the marker is
%   removed, and it is counted (`observations_without_session`). An id is
%   never invented.
%
%   REPORT fields (the caller adds them to its own report):
%     session_references_marked      documents carrying the marker
%     session_references_minted      references minted
%     observations_without_session   no session document for its session_id
%     session_references_ambiguous   two session documents claim it

arguments
    bodies % a cell of bodies, or the text 'marker'
    classes {mustBeA(classes, 'cell')} = {}
    marked {mustBeNumeric} = []
    options (1,1) struct = struct()
end

if nargin == 1 && ischar(bodies) && strcmp(bodies, 'marker')
    bodies = 'session_time_reference_pending';
    return;
end
MARKER = did2.convert.mintSessionDuring('marker');

refs = {};
report = struct( ...
    'session_references_marked',    numel(marked), ...
    'session_references_minted',    0, ...
    'observations_without_session', 0, ...
    'session_references_ambiguous', 0);
if isempty(marked)
    return;
end

% --- index the session documents (resolveSessionAnchors' rule) --------------
docOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
countOf = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    if ~isSessionDocument(bodies{k}, classes{k}); continue; end
    sid = did2.schema.cache.sessionIdOf(bodies{k});
    id = baseField(bodies{k}, 'id');
    if isempty(sid) || isempty(id); continue; end
    if isKey(countOf, sid)
        countOf(sid) = countOf(sid) + 1;
    else
        countOf(sid) = 1;
        docOf(sid) = id;
    end
end

for j = 1:numel(marked)
    k = marked(j);
    b = removeEdge(bodies{k}, MARKER);
    sid = did2.schema.cache.sessionIdOf(b);
    if isempty(sid) || ~isKey(countOf, sid)
        report.observations_without_session = report.observations_without_session + 1;
    elseif countOf(sid) > 1
        report.session_references_ambiguous = report.session_references_ambiguous + 1;
    else
        ref = did2.build.relativeTimeReference(docOf(sid), ...
            'Relation', 'intervalDuring', 'SessionId', sid, ...
            'CreationTimestamp', creationOf(b), 'Validate', false, ...
            'SchemaCache', getOr(options, 'SchemaCache', []));
        refs{end+1} = ref; %#ok<AGROW>
        b = addEdge(b, 'time_reference_id', ref.base.id);
        report.session_references_minted = report.session_references_minted + 1;
    end
    bodies{k} = b;
end
end

% ===================== helpers =============================================

function tf = isSessionDocument(b, cls)
arguments
    b % a body, or [] where it could not be read
    cls {mustBeText}
end

tf = false;
if strcmp(cls, 'session')
    tf = true;
    return;
end
if ~strcmp(cls, 'entity') || ~isstruct(b) || ~isfield(b, 'entity') ...
        || ~isstruct(b.entity) || ~isfield(b.entity, 'type')
    return;
end
t = b.entity.type;
if iscell(t) && ~isempty(t); t = t{1}; end
if isstruct(t) || ischar(t) || isstring(t)
    tf = did2.build.isVocabulary(t, 'entity_type', 'session');   % by node (L2)
end
end

function b = removeEdge(b, name)
arguments
    b struct
    name {mustBeText}
end

if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps)
    keep = cellfun(@(d) ~(isfield(d, 'name') && strcmp(d.name, name)), deps);
else
    keep = arrayfun(@(d) ~(isfield(d, 'name') && strcmp(d.name, name)), deps);
end
b.depends_on = deps(keep);
end

function b = addEdge(b, name, value)
% Shaped like the entries already there ({name, value} or {name, document_id}).
arguments
    b struct
    name {mustBeText}
    value {mustBeText}
end

if ~isfield(b, 'depends_on') || isempty(b.depends_on) || ~isstruct(b.depends_on)
    b.depends_on = struct('name', name, 'value', value);
    return;
end
e = struct();
f = fieldnames(b.depends_on);
for i = 1:numel(f); e.(f{i}) = ''; end
e.name = name;
if isfield(e, 'value'); e.value = value; else; e.document_id = value; end
b.depends_on(end+1) = e;
end

function v = baseField(b, name)
arguments
    b % a body; anything that is not a struct yields ''
    name {mustBeText}
end

v = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, name) ...
        && ~isempty(b.base.(name))
    v = char(b.base.(name));
end
end

function ts = creationOf(b)
arguments
    b % a body; anything that is not a struct yields ''
end

ts = '';
for f = {'creation_timestamp', 'datestamp'}
    v = baseField(b, f{1});
    if ~isempty(v); ts = v; return; end
end
end

function v = getOr(s, f, d)
arguments
    s % an options struct; anything that is not a struct yields D
    f {mustBeText}
    d
end

v = d;
if isstruct(s) && isfield(s, f); v = s.(f); end
end
