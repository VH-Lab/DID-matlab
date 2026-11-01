function [v1, spec] = subject(bodies)
%SUBJECT Rebuild a v1 `subject` from what did2.convert.migrators_j.subject
%   emitted: one `entity` of type organism.
%
%   [V1, SPEC] = did2.convert.roundtrip.subject(BODIES): BODIES is a cell of
%   the emitted document structs. V1 is the subject in NDI's v1 shape
%   (subject.json + base.json at the locked NDI-matlab `main`, 3cb19a8):
%
%     base.id, base.session_id, base.datestamp   from the entity (rebuildBase)
%     base.name                  entity.name ('' when the entity has none)
%     subject.local_identifier   entity.local_identifier
%     subject.description        entity.description ('' when left out)
%
%   base.name: Decided by Jess Haley, 2026-10-27 [v1 name is the entity name]
%   (did-schema V_eta_go_forward_class_audit.md): the migrator writes a
%   non-empty v1 base.name to entity.name, so it is rebuilt from there and
%   needs no equivalence.
%
%   SPEC.unplaced lists any emitted document that is not one organism entity.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.subject.

arguments
    bodies cell
end

spec = struct('equivalents', struct('path', {}, 'values', {}, 'why', {}), ...
    'unplaced', {{}});
v1 = struct();
ent = [];
for k = 1:numel(bodies)
    b = bodies{k};
    if isEntityOfType(b, 'organism') && isempty(ent)
        ent = b;
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the one organism entity', ...
            k, classNameOf(b));
    end
end
if isempty(ent)
    spec.unplaced{end+1} = 'no organism entity was emitted';
    return;
end
[base, entity] = rebuildBase(ent);
li = fieldText(entity, 'local_identifier');
v1.document_class = struct('class_name', 'subject');
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', fieldText(entity, 'name'), 'datestamp', base.datestamp);
v1.subject = struct('local_identifier', li, ...
    'description', notesText(entity));   % `notes` ([one free-text field: notes]) or `description`
end
