function bodies = jMembershipBodies(preBody, entries)
%JMEMBERSHIPBODIES Shared body builder for session<->dataset membership.
%   `entries` is a struct array of membership records (each carrying a member
%   `session_id`) — one element for the flat session_in_a_dataset, N for the
%   nested dataset_session_info aggregate. Emits the bare canonical dataset entity
%   plus one `session -part_of-> dataset` directed_relation per member session.
%   On a schema where `session_id` is an edge the relation is `included_in`
%   (schema:isPartOf) instead: did-schema V_eta_relation_inheritance_plan.md
%   (2026-10-20) gave records their own relation, which passes nothing, and
%   made `part_of` physical only. The same did-schema change, so one question
%   (sessionIdIsEdge) decides both.
%
%   HOW THE SESSION JOINED (Decided by Jess Haley, 2026-10-25 [session membership
%   records linked or ingested]; terms [census terms], 2026-10-26; did-schema
%   V_eta_go_forward_class_audit.md): the relation's `method.term` is EMPTY:0000399
%   "database ingestion" or EMPTY:0000400 "database linking", by `is_linked`
%   (NDI ndi.dataset add_ingested_session / add_linked_session). A LINKED
%   session's method.parameters hold its opener class (`session_creator`;
%   variable EMPTY:0000401 "software class") and its path
%   (`session_creator_input2`; variable NCIT:C47922 Pathname). An input that
%   only restates the session's reference or id is dropped as a copy.
%   An INGESTED session ([ingested session membership], Jess Haley,
%   2026-10-26): its `session_reference` is dropped when it equals the session
%   entity's local_identifier (did2.convert.sessionReferences), and its opener
%   class is a "software class" parameter of the "database ingestion" method.
%   A LINKED session's reference follows the same rule ([linked session
%   reference follows the ingested rule], Jess Haley, 2026-10-27): dropped when
%   it equals the session entity's local_identifier, else carried (carry-074).
%   THE OPENER ([session opener inputs], Jess Haley, 2026-10-27): inputs 1 and 3
%   are the copies (ndi.session.dir creator_args() is {reference, path, id});
%   a `session_creator` other than `ndi.session.dir` carries the membership
%   (carry-119), and so does any non-empty `session_creator_input4..6`, which
%   NDI-matlab +ndi/dataset.m never reads (carry-075). An UNSTATED
%   `session_creator` carries it under carry-119 too ([unstated session
%   creator carried], Jess Haley, 2026-10-29).
%   A session NOT IN THE BATCH ([linked session not in the batch], Jess Haley,
%   2026-10-29): its reference cannot be compared, so the membership is carried
%   under carry-069, ingested or linked.
%   Everything else is carried: with any part of an entry unplaced -- no
%   `is_linked`, a reference that differs (carry-060 ingested, carry-074
%   linked) or whose session is not in the batch (carry-069), another or no
%   opener, input 4..6, any other input -- the document is returned UNCHANGED,
%   carried whole as v1 ([generic stage is lossless]).
%   Shared Brainstorm-J (+migrators_j) helper.
%
%   ITS ID ([every v1 id survives], Jess Haley, 2026-10-27: "each v1
%   document's id becomes the id of the V2 document that most directly
%   replaces it"): a document holding ONE membership (session_in_a_dataset)
%   becomes one relation, which takes the v1 document's base.id. With several
%   entries no one relation replaces the document, and every relation's id is
%   minted, as before.

datasetId = jDatasetId(preBody);
bodies = {jBareDataset(preBody, datasetId)};
if ~isstruct(entries); return; end
relation = {'', 'part_of'};
if sessionIdIsEdge()
    relation = {'schema:isPartOf', 'included_in'};
end
unplaced = {};
rels = {};
relId = '';
if isscalar(entries) && isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isfield(preBody.base, 'id')
    relId = char(preBody.base.id);   % ITS ID (above)
end
for k = 1:numel(entries)
    memberSession = jGetChar(entries(k), 'session_id');
    if isempty(memberSession); continue; end
    if strcmp(memberSession, datasetId); continue; end   % the dataset's own root
    [method, params, why] = membershipMethod(entries(k), memberSession);
    if ~isempty(why)
        unplaced{end+1} = sprintf('%s: %s', memberSession, why); %#ok<AGROW>
        continue;
    end
    rels{end+1} = membershipRelation(preBody, memberSession, datasetId, ...
        relation, method, params, relId); %#ok<AGROW>
end
if ~isempty(unplaced)
    % carry-register: carry-060 carry-066 carry-068 carry-069 carry-074 carry-075
    %   carry-119; none for: an input 1..3 that is not a copy
    did2.convert.reportNote('carried_as_v1', char(preBody.document_class.class_name), ...
        char(preBody.base.id), ['unplaced: ' strjoin(unplaced, '; ')]);
    bodies = {preBody};
    return;
end
bodies = [bodies, rels];
end

function rel = membershipRelation(preBody, childId, parentId, relation, method, params, relId)
if isempty(relation{1})
    r = relation{2};
else
    r = did2.build.term(relation{1}, relation{2});
end
opts = jOpts(preBody, 'Method', method);
if ~isempty(params)
    opts = [opts, {'MethodParameters', params}];
end
if ~isempty(relId)
    opts = [opts, {'Id', relId}];
end
rel = did2.build.directedRelation(char(childId), char(parentId), r, opts{:});
end

function [method, params, why] = membershipMethod(e, memberSession)
%MEMBERSHIPMETHOD The method term and parameters of one membership entry, or
%   WHY it cannot be placed whole.
method = []; params = []; why = '';
if ~isfield(e, 'is_linked') || isempty(e.is_linked)
    why = '[carry-066] is_linked not stated';
    return;
end
linked = e.is_linked;
if ischar(linked) || isstring(linked); linked = str2double(linked); end
if ~(islogical(linked) || isnumeric(linked)) || ~isscalar(linked) || isnan(double(linked))
    why = '[carry-068] is_linked not readable';
    return;
end
linked = logical(linked);
creator = strtrim(jGetChar(e, 'session_creator'));
% [session opener inputs] (Jess Haley, 2026-10-27): "a membership whose
% `session_creator` is not `ndi.session.dir` is carried whole as v1,
% `needs_mapping`" (carry-119). [unstated session creator carried] (Jess
% Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "a session
% membership with no `session_creator` is carried whole as v1 under carry-119,
% like one whose `session_creator` is not `ndi.session.dir`". Every writer
% states one (+ndi/dataset.m sets class(ndi_session_obj)).
if isempty(creator)
    why = '[carry-119] session_creator not stated';
    return;
end
if ~strcmp(creator, 'ndi.session.dir')
    why = sprintf('[carry-119] session_creator "%s" (not ndi.session.dir)', creator);
    return;
end
% [session opener inputs]: "a non-empty `session_creator_input4..6` (never
% read by NDI-matlab `+ndi/dataset.m`) carries the membership whole as v1"
% (carry-075), a copy or not
for n = 4:6
    if ~isempty(strtrim(inputText(e, sprintf('session_creator_input%d', n))))
        why = sprintf('[carry-075] session_creator_input%d (not empty)', n);
        return;
    end
end
reference = jGetChar(e, 'session_reference');
if ~isempty(strtrim(reference))
    % [ingested session membership] (Jess Haley, 2026-10-26), and for a linked
    % session [linked session reference follows the ingested rule] (Jess
    % Haley, 2026-10-27): the reference is dropped when it equals the session
    % entity's local_identifier (recoverable from it); when it differs the
    % document is carried as v1 (carry-060 ingested, carry-074 linked). The
    % session is read from the batch (did2.convert.sessionReferences); one not
    % in the batch cannot be compared: carry-069, ingested or linked ([linked
    % session not in the batch], Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md: "a linked session's membership whose
    % session is not among the documents migrated together ... is carried
    % under carry-069").
    [li, found] = did2.convert.sessionReferences('get', memberSession);
    if ~found
        if linked
            why = ['[carry-069] session_reference of a linked session (the session is ' ...
                'not in the batch, so it was not compared with its local_identifier)'];
        else
            why = ['[carry-069] session_reference (the session is not in the batch, so it ' ...
                'was not compared with its local_identifier)'];
        end
        return;
    end
    if ~strcmp(li, reference)
        if linked
            why = sprintf(['[carry-074] session_reference "%s" of a linked session ' ...
                '(differs from the session''s local_identifier "%s")'], reference, li);
        else
            why = sprintf(['[carry-060] session_reference "%s" (differs from the ' ...
                'session''s local_identifier "%s")'], reference, li);
        end
        return;
    end
end
path = '';
for n = 1:3
    v = strtrim(inputText(e, sprintf('session_creator_input%d', n)));
    if isempty(v) || strcmp(v, memberSession) || strcmp(v, strtrim(reference))
        continue;   % absent, or a copy of the session's id / reference
    end
    if n == 2 && linked
        path = v;
    else
        why = sprintf('session_creator_input%d', n);
        return;
    end
end
if linked
    method = did2.convert.registeredTerm('EMPTY:0000400', 'database linking');
    p = {};
    if ~isempty(creator)
        p{end+1} = did2.build.parameter( ...
            did2.convert.registeredTerm('EMPTY:0000401', 'software class'), 'Text', creator);
    end
    if ~isempty(path)
        p{end+1} = did2.build.parameter( ...
            did2.convert.registeredTerm('NCIT:C47922', 'Pathname'), 'Text', path);
    end
    if ~isempty(p); params = did2.build.list(p{:}); end
else
    % [ingested session membership] (Jess Haley, 2026-10-26): the creator class
    % is a parameter of the "database ingestion" method
    method = did2.convert.registeredTerm('EMPTY:0000399', 'database ingestion');
    if ~isempty(creator)
        params = did2.build.list(did2.build.parameter( ...
            did2.convert.registeredTerm('EMPTY:0000401', 'software class'), 'Text', creator));
    end
end
end

function s = inputText(e, f)
s = '';
if ~isfield(e, f); return; end
v = e.(f);
if ischar(v); s = v;
elseif isstring(v) && isscalar(v); s = char(v);
elseif isnumeric(v) && isscalar(v); s = num2str(v);
end
end

function tf = sessionIdIsEdge()
% Does the loaded schema store the session id as an EDGE (did-schema
% V_eta_relation_inheritance_plan.md, 2026-10-20)? A migrator holds no cache
% handle, so it asks the shared one -- the cache did2.convert.v1_to_v2 also
% falls back to. False when no schema can be loaded: the historical field shape.
tf = false;
try
    tf = did2.schema.cache.shared().sessionIdIsEdge();
catch
    % no schema to ask
end
end
