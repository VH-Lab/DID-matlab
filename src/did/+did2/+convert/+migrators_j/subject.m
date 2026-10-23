function v2Body = subject(preBody)
%SUBJECT Brainstorm-J carry-forward for a v1 subject: guarantee a non-empty
%   local_identifier. V_eta makes subject.local_identifier REQUIRED (a subject
%   must be nameable); a v1 subject's handle was optional, so an empty or missing
%   one now needs filling. Fill it from the preserved document id. Everything else
%   is unchanged -- the body is already post-universalRenames and ensureClassBlocks
%   runs after this (exactly as the mechanical path did before), so the only delta
%   is the guaranteed handle.

%   did-schema #88 (V_eta_entity_composition_plan.md sec. 4, signed 2026-10-08):
%   `subject` is gone; a v1 subject becomes one `entity` with its id preserved,
%   `local_identifier` and `description` carried, and `type` 'organism' -- the
%   v1 subject class names the animal an experiment is about. That default is
%   PROPOSED, not signed: a v1 subject that is a culture or a plate takes it too
%   until a source field says otherwise (the Haley lawn/plate subjects are typed
%   by resolveLawnPlateSubjects, not here).

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'subject') && isstruct(preBody.subject) && isscalar(preBody.subject)
    blk = preBody.subject;
end
li = '';
if isfield(blk, 'local_identifier')
    li = char(blk.local_identifier);
end
li = jEnsureLocalId(li, preBody);
f = struct('local_identifier', li);
if isfield(blk, 'description') && ~isempty(blk.description)
    f.description = char(blk.description);
end
v2Body = jEntity(preBody, 'organism', f, 'Id', char(preBody.base.id));
end
