function [v1, spec] = jrclust_clusters(bodies)
%JRCLUST_CLUSTERS Rebuild a v1 `jrclust_clusters` from what
%   did2.convert.migrators_j.jrclust_clusters emitted when it CONVERTED it: the
%   label `calculation` (the source id), its `opaque_body`, the session anchor
%   and the software entities (with their version assertions).
%
%   [V1, SPEC] = did2.convert.roundtrip.jrclust_clusters(BODIES). V1 is the
%   document in the shape NDI-matlab +ndi/+fun/+probe/+import/+jrclust/probe.m
%   writes it (jrclust_clusters.json + app.json + base.json at the locked
%   `main` 3cb19a8):
%
%     identity, `app`                   calcParts (the calculation; a software
%                                       entity named 'jrclust' with no version
%                                       and no url is the one the migrator
%                                       mints when v1 has no `app`, and writes
%                                       no app block)
%     depends_on element_id             the calculation's entity_id
%     jrclust_clusters.res_mat_MD5_checksum   the opaque body's description,
%                                       'JRCLUST results (res_mat_MD5_checksum: X)'
%     files / file                      the opaque body's, as v1 wrote them
%
%   base.name: the writer's fixed default, 'jrclust.prm', is notation and is
%   restated here (SPEC.equivalents; [jrclust default name is notation], Jess
%   Haley, 2026-10-27); a document with any other name is carried, so it never
%   reaches this inverse ([v1 name goes to the class's own name field]).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.jrclust_clusters.

arguments
    bodies cell
end

used = false(1, numel(bodies));
ob = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'opaque_body') && isempty(ob)
        ob = bodies{k};
        used(k) = true;
    end
end
[v1, leaf, ~, spec] = calcParts(bodies(~used), 'calculation', 'jrclust_clusters', 'jrclust');
if isempty(leaf)
    return;
end
v1 = rmfield(v1, 'jrclust_clusters');   % (calcParts' input_parameters block: none here)
blk = struct();
if isempty(ob)
    spec.unplaced{end+1} = 'no opaque_body was emitted';
else
    owner = edgeIds(ob, 'owner_id');
    if ~isequal(owner, {char(getIn(leaf, 'base', 'id'))})
        spec.unplaced{end+1} = 'the opaque_body is not owned by the calculation';
    end
    d = char(getIn(ob, 'data_body', 'description'));
    tok = regexp(d, '^JRCLUST results \(res_mat_MD5_checksum: (.*)\)$', 'tokens', 'once');
    if ~isempty(tok)
        blk.res_mat_MD5_checksum = tok{1};
    end
    % the v1 attachment rides on the body as v1 wrote it; a body with none
    % carries only the builder's own declaration, {file_list: body_data_0}
    for f = {'files', 'file'}
        if isfield(ob, f{1}) && ~isBuilderDefault(ob.(f{1}))
            v1.(f{1}) = ob.(f{1});
        end
    end
end
v1.jrclust_clusters = blk;
spec.equivalents(end+1) = struct('path', 'base.name', 'values', {{'jrclust.prm'}}, ...
    'why', ['the JRCLUST writer''s fixed default name ([jrclust default name is ' ...
    'notation], Jess Haley, 2026-10-27)']);
entity = edgeIds(leaf, 'entity_id');
if isscalar(entity)
    v1.depends_on = struct('name', 'element_id', 'value', entity{1});
else
    spec.unplaced{end+1} = sprintf('%d entity_id edges', numel(entity));
end
end

function tf = isBuilderDefault(f)
%ISBUILDERDEFAULT The file declaration did2.build gives a body with no v1 file.
tf = isstruct(f) && isscalar(f) && isequal(fieldnames(f), {'file_list'}) ...
    && isequal(cellstr(f.file_list), {'body_data_0'});
end
