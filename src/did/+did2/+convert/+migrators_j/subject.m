function v2Body = subject(preBody)
%SUBJECT Brainstorm-J carry-forward for a v1 subject: guarantee a non-empty
%   local_identifier. V_eta makes subject.local_identifier REQUIRED (a subject
%   must be nameable); a v1 subject's handle was optional, so an empty or missing
%   one now needs filling. Fill it from the preserved document id. Everything else
%   is unchanged -- the body is already post-universalRenames and ensureClassBlocks
%   runs after this (exactly as the mechanical path did before), so the only delta
%   is the guaranteed handle.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
li = '';
if isfield(v2Body, 'subject') && isstruct(v2Body.subject) ...
        && isfield(v2Body.subject, 'local_identifier')
    li = char(v2Body.subject.local_identifier);
end
li = jEnsureLocalId(li, v2Body);
if ~isfield(v2Body, 'subject') || ~isstruct(v2Body.subject)
    v2Body.subject = struct();
end
v2Body.subject.local_identifier = li;
if ~isfield(v2Body.subject, 'description')
    v2Body.subject.description = '';
end
end
