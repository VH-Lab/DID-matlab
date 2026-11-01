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
%     base.name           entity.name ('' when the entity has none; the
%                         writer sets none) ([v1 name is the entity name],
%                         Jess Haley, 2026-10-27)
%     session.reference   entity.local_identifier
%     depends_on          [] (the template's)
%
%   Any other emitted document, or an entity field other than type and
%   local_identifier, is unplaced.
%
%   A DATASET'S OWN SESSION. NDI stores a dataset's documents under the
%   dataset's own session, whose id is the dataset's, so the session entity
%   this migrator writes shares its id with the dataset entity, and
%   did2.convert.resolveDatasetEntities drops it: its reference "becomes the
%   dataset entity's `local_identifier`" (Decided by Jess Haley, 2026-10-22
%   [dataset session reference]). So when BODIES holds no session entity but
%   a dataset entity, the reference is read from that entity's
%   local_identifier; its other fields are other sources' (the dataset
%   entity is shared, roundtrip.dataset_remote) and are not reported here.
%   Test code run 41350082866: JH's one such session lost everything ("no
%   session entity was emitted").
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.session.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
ent = [];
asDataset = false;
for k = 1:numel(bodies)
    if isempty(ent) && isEntityOfType(bodies{k}, 'session')
        ent = bodies{k};
    elseif isempty(ent) && isscalar(bodies) && isEntityOfType(bodies{k}, 'dataset')
        ent = bodies{k};         % A DATASET'S OWN SESSION (above)
        asDataset = true;
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
if ~asDataset
    spec.unplaced = [spec.unplaced, others(entity, {'type', 'local_identifier', 'name'}, 'entity')];
end
v1.document_class = struct('class_name', 'session');
v1.depends_on = [];
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', nameUnlessDataset(entity, asDataset), ...
    'datestamp', base.datestamp);
v1.session = struct('reference', fieldText(entity, 'local_identifier'));
end

function n = nameUnlessDataset(entity, asDataset)
% a dataset entity's name is the dataset's (another source's), not the session's
n = '';
if ~asDataset
    n = fieldText(entity, 'name');
end
end
