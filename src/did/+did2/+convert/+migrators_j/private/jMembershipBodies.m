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
%   Everything else is carried: with any part of an entry unplaced -- no
%   `is_linked`, an ingested session's reference that differs (carry-060) or
%   whose session is not in the batch, a linked session's reference, any other
%   input -- the document is returned UNCHANGED, carried whole as v1
%   ([generic stage is lossless]).
%   Shared Brainstorm-J (+migrators_j) helper.

datasetId = jDatasetId(preBody);
bodies = {jBareDataset(preBody, datasetId)};
if ~isstruct(entries); return; end
relation = {'', 'part_of'};
if sessionIdIsEdge()
    relation = {'schema:isPartOf', 'included_in'};
end
unplaced = {};
rels = {};
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
        relation, method, params); %#ok<AGROW>
end
if ~isempty(unplaced)
    % carry-register: carry-060 (an ingested session's reference that differs
    % from its local_identifier), carry-066 (is_linked not stated), carry-068
    % (is_linked not readable), carry-069 (a session not in the batch); none
    % for: a linked session's reference, or a creator input that is not a copy
    did2.convert.reportNote('carried_as_v1', char(preBody.document_class.class_name), ...
        char(preBody.base.id), ['unplaced: ' strjoin(unplaced, '; ')]);
    bodies = {preBody};
    return;
end
bodies = [bodies, rels];
end

function rel = membershipRelation(preBody, childId, parentId, relation, method, params)
if isempty(relation{1})
    r = relation{2};
else
    r = did2.build.term(relation{1}, relation{2});
end
opts = jOpts(preBody, 'Method', method);
if ~isempty(params)
    opts = [opts, {'MethodParameters', params}];
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
reference = jGetChar(e, 'session_reference');
if ~isempty(strtrim(reference))
    if linked
        why = 'session_reference of a linked session (open: no home decided)';
        return;
    end
    % [ingested session membership] (Jess Haley, 2026-10-26): an ingested
    % session's reference is dropped when it equals the session entity's
    % local_identifier (recoverable from it); when it differs the document is
    % carried as v1 (carry-060). The session is read from the batch
    % (did2.convert.sessionReferences); one not in the batch cannot be compared.
    [li, found] = did2.convert.sessionReferences('get', memberSession);
    if ~found
        why = ['[carry-069] session_reference (the session is not in the batch, so it ' ...
            'was not compared with its local_identifier)'];
        return;
    end
    if ~strcmp(li, reference)
        why = sprintf(['[carry-060] session_reference "%s" (differs from the ' ...
            'session''s local_identifier "%s")'], reference, li);
        return;
    end
end
creator = strtrim(jGetChar(e, 'session_creator'));
path = '';
for n = 1:6
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
