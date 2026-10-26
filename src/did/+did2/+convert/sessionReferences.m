function [reference, found] = sessionReferences(action, arg)
%SESSIONREFERENCES The local_identifier each v1 session in the batch becomes.
%
%   A per-document migrator is called with one body and cannot follow an edge.
%   jMembershipBodies must compare an ingested session's `session_reference`
%   with the session entity's `local_identifier` before it may leave it
%   unwritten ([ingested session membership], Jess Haley, 2026-10-26, did-schema
%   V_eta_go_forward_class_audit.md: "dropped when it equals the session
%   entity's local_identifier"; carried as v1, carry-060, when it differs).
%   did2.convert.v1_to_v2 indexes every v1 `session` in its batch before the
%   first migrator runs, and the migrator reads it here.
%
%   did2.convert.sessionReferences('reset')          forget all
%   did2.convert.sessionReferences('load', BODIES)   index every v1 `session`
%       in the cell BODIES by its session id (the id the session entity takes,
%       migrators_j.session): its `session.reference` (or `local_identifier`),
%       the value migrators_j.session writes as local_identifier. Adds to what
%       is held; v1_to_v2 resets first.
%   [REFERENCE, FOUND] = did2.convert.sessionReferences('get', SESSIONID)
%       FOUND is false when no session of that id is in the batch, and a
%       caller then cannot compare (not a pass). Two sessions of one id that
%       state different references are held as not comparable (FOUND false).
%
%   See also: did2.convert.migrators_j.session_in_a_dataset,
%             did2.convert.stimulusPresentationSpecs.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'get'})}
    arg = []
end

persistent index
if isempty(index) || ~isa(index, 'containers.Map')
    index = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
reference = '';
found = false;
switch action
    case 'reset'
        index = containers.Map('KeyType', 'char', 'ValueType', 'any');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        for k = 1:numel(bodies)
            b = bodies{k};
            if (ischar(b) || (isstring(b) && isscalar(b))) && contains(b, '"session"')
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            [sid, ref, ok] = sessionOf(b);
            if ~ok || isempty(sid); continue; end
            if isKey(index, sid)
                held = index(sid);
                if ~isequal(held, ref)
                    index(sid) = {};   % two references for one id: not comparable
                end
            else
                index(sid) = ref;
            end
        end
    case 'get'
        sid = char(arg);
        if ~isempty(sid) && isKey(index, sid)
            v = index(sid);
            if ischar(v)
                reference = v;
                found = true;
            end
        end
end
end

function [sid, ref, ok] = sessionOf(b)
sid = ''; ref = ''; ok = false;
if ~(isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
        && isstruct(b.document_class) && isfield(b.document_class, 'class_name') ...
        && strcmp(char(b.document_class.class_name), 'session') ...
        && isfield(b, 'base') && isstruct(b.base))
    return;
end
if isfield(b.base, 'session_id') && ~isempty(b.base.session_id)
    sid = char(b.base.session_id);
elseif isfield(b.base, 'id')
    sid = char(b.base.id);
end
if isfield(b, 'session') && isstruct(b.session) && isscalar(b.session)
    for f = {'reference', 'local_identifier'}
        if isfield(b.session, f{1}) && ~isempty(b.session.(f{1}))
            ref = char(b.session.(f{1}));
            break;
        end
    end
end
ok = true;
end
