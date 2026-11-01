function [v1, spec] = dataset_remote(bodies, ctx)
%DATASET_REMOTE Rebuild a v1 `dataset_remote` from what the migration made of
%   it.
%
%   [V1, SPEC] = did2.convert.roundtrip.dataset_remote(BODIES). V1 is the
%   record in NDI's v1 shape (dataset_remote.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+cloud/+internal/createRemoteDatasetDoc.m
%   writes it: no depends_on). BODIES holds the bare `dataset` entity and, when
%   the record names an organization, the `organization` entity and the
%   dataset -hosted_by-> organization relation:
%
%     base.id                        not kept (absent: the round trip reports
%                                    it lost)
%     base.session_id                the dataset entity's id
%     base.datestamp                 its creation_timestamp
%     base.name                      the dataset entity's name ('' when it
%                                    has none; the writer sets none) ([v1
%                                    name is the entity name], Jess Haley,
%                                    2026-10-27)
%     dataset_remote.dataset_id      the dataset's `ndicloud:` global identifier
%     dataset_remote.organization_id the organization entity's `ndicloud:`
%                                    global identifier ([cloud organization
%                                    id is a global identifier], Jess Haley,
%                                    2026-10-27)
%
%   Any other emitted document, or a field this inverse does not read, is
%   unplaced.
%
%   THE DATASET ENTITY IS SHARED. Every dataset-level source mints a bare
%   dataset entity on the dataset's id (private/jBareDataset), and
%   did2.convert.resolveDatasetEntities keeps one per id, the richest; it also
%   writes the dataset's own session reference into its `local_identifier`
%   ([dataset session reference], Jess Haley, 2026-10-22). So in the
%   whole-batch round trip (did2.convert.roundtrip.wholeBatch, which hands
%   CTX, the index of the final batch) the dataset entity this source names
%   holds fields other documents gave it: with CTX, its `global_identifier`,
%   `local_identifier` and `name` are not reported as this source's.
%   (Test code run 41322059537: dataset_remote failures B 1, Dab 2, JH 1, the
%   sample reporting `dataset entity.local_identifier` unplaced.)
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.dataset_remote.

arguments
    bodies cell
    ctx = []
end

spec = emptySpec();
v1 = struct();
ds = [];
org = [];
rel = [];
for k = 1:numel(bodies)
    b = bodies{k};
    if isempty(ds) && isEntityOfType(b, 'dataset')
        ds = b;
    elseif isempty(org) && isEntityOfType(b, 'organization')
        org = b;
    elseif isempty(rel) && strcmp(classNameOf(b), 'directed_relation')
        rel = b;
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a dataset_remote', ...
            k, classNameOf(b));
    end
end
if isempty(ds)
    spec.unplaced{end+1} = 'no dataset entity was emitted';
    return;
end
[base, entity] = rebuildBase(ds);
dsOwn = {'type', 'global_identifier', 'name'};
if ~isempty(ctx)
    dsOwn{end+1} = 'local_identifier';   % shared (above)
end
spec.unplaced = [spec.unplaced, others(entity, dsOwn, 'dataset entity')];
cloudId = '';
gids = asCell(getIn(ds, 'entity', 'global_identifier'));
for k = 1:numel(gids)
    g = char(gids{k});
    if startsWith(g, 'ndicloud:') && isempty(cloudId)
        cloudId = g(numel('ndicloud:')+1:end);
    else
        spec.unplaced{end+1} = sprintf('the dataset''s global identifier "%s"', g);
    end
end
orgName = '';
if ~isempty(org) || ~isempty(rel)
    if isempty(org) || isempty(rel)
        spec.unplaced{end+1} = 'an organization without its hosted_by relation, or the reverse';
    else
        [~, oe] = rebuildBase(org);
        spec.unplaced = [spec.unplaced, others(oe, {'type', 'global_identifier'}, ...
            'organization entity')];
        ogids = asCell(getIn(org, 'entity', 'global_identifier'));
        for k = 1:numel(ogids)
            g = char(ogids{k});
            if startsWith(g, 'ndicloud:') && isempty(orgName)
                orgName = g(numel('ndicloud:')+1:end);
            else
                spec.unplaced{end+1} = sprintf('the organization''s global identifier "%s"', g);
            end
        end
        rname = did2.build.vocabularyHandle('relation', getIn(rel, 'directed_relation', 'relation'));
        if ~strcmp(rname, 'hosted_by') ...
                || ~isequal(edgeIds(rel, 'child_id'), {base.id}) ...
                || ~isequal(edgeIds(rel, 'parent_id'), {char(getIn(org, 'base', 'id'))})
            spec.unplaced{end+1} = 'the relation is not dataset -hosted_by-> organization';
        end
        spec.unplaced = [spec.unplaced, others(getIn(rel, 'directed_relation'), ...
            {'relation', 'order'}, 'directed_relation')];
    end
end
v1.document_class = struct('class_name', 'dataset_remote');
v1.base = struct('session_id', base.id, 'name', fieldText(entity, 'name'), ...
    'datestamp', base.datestamp);
v1.dataset_remote = struct('dataset_id', cloudId, 'organization_id', orgName);
end
