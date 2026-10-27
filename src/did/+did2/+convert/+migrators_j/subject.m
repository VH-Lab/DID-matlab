function v2Body = subject(preBody)
%SUBJECT Brainstorm-J migrator: a v1 subject -> one `entity` of type
%   `organism`, id preserved, carrying `local_identifier` and `description`. A
%   v1 subject's handle was optional, so an empty or missing one is filled from
%   the preserved document id (jEnsureLocalId).

%   did-schema #88 (V_eta_entity_composition_plan.md sec. 4, signed 2026-10-08):
%   `subject` is gone; a v1 subject becomes one `entity` with its id preserved,
%   `local_identifier` and `description` carried, and `type` 'organism' -- the
%   v1 subject class names the animal an experiment is about. That default is
%   PROPOSED, not signed: a v1 subject that is a culture or a plate takes it too
%   until a source field says otherwise.

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
if isempty(strtrim(li))
    % [no invented values] / [generic stage is lossless] (Jess Haley,
    % 2026-10-25): a required local_identifier the source does not state is not
    % filled with the document id (jEnsureLocalId); the document is carried
    % whole as v1.
    % carry-register: carry-033
    did2.convert.reportNote('carried_as_v1', 'subject', char(preBody.base.id), ...
        '[carry-033] unplaced: no subject.local_identifier (it would be invented)');
    v2Body = {preBody};
    return;
end
f = struct('local_identifier', li);
if isfield(blk, 'description') && ~isempty(blk.description)
    f.description = char(blk.description);
end
v2Body = jEntity(preBody, 'organism', f, 'Id', char(preBody.base.id));
end
