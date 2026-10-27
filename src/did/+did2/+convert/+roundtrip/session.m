function [v1, spec] = session(bodies)
%SESSION Rebuild a v1 `session` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.session(BODIES). V1 is the session
%   document in NDI's v1 shape (session.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+session/dir.m writes it). BODIES holds
%   the session `entity` (type session):
%
%     base.id             the entity's base.id: on the edge shape that is the
%                         SESSION id, not the v1 document's own id, which V2
%                         does not keep (the round trip reports it lost when
%                         they differ, as they do on every writer document)
%     base.session_id     the entity's session_id (its own id)
%     base.datestamp      its creation_timestamp
%     base.name           '' (the writer sets none; V2 keeps no base.name)
%     session.reference   entity.local_identifier
%     depends_on          [] (the template's)
%
%   Any other emitted document, or an entity field other than type and
%   local_identifier, is unplaced.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.session.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
ent = [];
for k = 1:numel(bodies)
    if isempty(ent) && isEntityOfType(bodies{k}, 'session')
        ent = bodies{k};
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a session', ...
            k, classNameOf(bodies{k}));
    end
end
if isempty(ent)
    spec.unplaced{end+1} = 'no session entity was emitted';
    return;
end
[base, entity] = rebuildBase(ent);
spec.unplaced = [spec.unplaced, others(entity, {'type', 'local_identifier'}, 'entity')];
v1.document_class = struct('class_name', 'session');
v1.depends_on = [];
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.session = struct('reference', fieldText(entity, 'local_identifier'));
end
