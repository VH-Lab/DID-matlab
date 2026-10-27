function [v1, spec] = dataset_remote(bodies)
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
%     base.name                      '' (the writer sets none)
%     dataset_remote.dataset_id      the dataset's `ndicloud:` global identifier
%     dataset_remote.organization_id the organization entity's name
%
%   Any other emitted document, or a field this inverse does not read, is
%   unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.dataset_remote.

arguments
    bodies cell
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
spec.unplaced = [spec.unplaced, others(entity, {'type', 'global_identifier'}, 'dataset entity')];
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
        spec.unplaced = [spec.unplaced, others(oe, {'type', 'name'}, 'organization entity')];
        orgName = fieldText(oe, 'name');
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
v1.base = struct('session_id', base.id, 'name', '', 'datestamp', base.datestamp);
v1.dataset_remote = struct('dataset_id', cloudId, 'organization_id', orgName);
end
