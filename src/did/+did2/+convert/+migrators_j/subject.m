function v2Body = subject(preBody)
%SUBJECT Brainstorm-J migrator: a v1 subject -> one `entity` of type
%   `organism`, id preserved, carrying `name`, `local_identifier` and
%   `description`. A
%   v1 subject's handle was optional; one that states none is carried whole as
%   v1 (carry-033).

%   did-schema #88 (V_eta_entity_composition_plan.md sec. 4, signed 2026-10-08):
%   `subject` is gone; a v1 subject becomes one `entity` with its id preserved,
%   `local_identifier` and `description` carried, and `type` 'organism' -- the
%   v1 subject class names the animal an experiment is about. That default is
%   PROPOSED, not signed: a v1 subject that is a culture or a plate takes it too
%   until a source field says otherwise.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it, with no universalRenames. Every v1 field, from NDI's
%   subject.json and base.json at the locked NDI-matlab `main` (3cb19a8), and
%   where it goes; did2.convert.roundtrip.subject rebuilds the v1 document from
%   the output and testRawV1RoundTrip compares the two:
%
%     base.id                  -> base.id (preserved)
%     base.session_id          -> the session_id edge (v1_to_v2, on the way out)
%     base.datestamp           -> base.creation_timestamp (v1_to_v2, on the way out)
%     base.name                -> entity.name when not empty, whether or not
%                                 it equals local_identifier; '' writes
%                                 nothing (jBaseName; Decided by Jess Haley,
%                                 2026-10-27 [v1 name is the entity name]).
%                                 ndi.subject's newdocument writes it equal to
%                                 local_identifier; +NDIMaker/subjectMaker
%                                 leaves the template's ''.
%     subject.local_identifier -> entity.local_identifier (empty: carry-033)
%     subject.description      -> entity.description ('' is left out)
%     document_class           -> the V2 document_class the builder writes

arguments
    preBody (1,1) struct
end

base = did2.convert.v1read.readBase(preBody);
if ~strcmp(base.source, 'base') || ~any(strcmp(base.present, 'id'))
    % as before the switch: a body with no base.id quarantines (it used to
    % fail reading preBody.base.id)
    error('did2:convert:subject:noId', ...
        'A v1 subject with no base.id cannot keep its id.');
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
    did2.convert.reportNote('carried_as_v1', 'subject', base.id, ...
        '[carry-033] unplaced: no subject.local_identifier (it would be invented)');
    v2Body = {preBody};
    return;
end
f = struct('local_identifier', li, 'name', jBaseName(preBody));
if isfield(blk, 'description') && ~isempty(blk.description)
    f.description = char(blk.description);
end
v2Body = jEntity(preBody, 'organism', f, 'Id', base.id);
end
