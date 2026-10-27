function [v1, spec] = sorterInverse(bodies, v1Class, sorterName, dirField)
%SORTERINVERSE Rebuild a v1 Kilosort / Kiasort cluster document from what
%   +migrators_j/private/jSorterOutput made of it.
%
%   [V1, SPEC] = sorterInverse(BODIES, V1CLASS, SORTERNAME, DIRFIELD). BODIES
%   holds the `calculation` (id preserved), its opaque_body, the session
%   anchor, the software entity (and its version assertion) and the run's
%   operating_system / interpreter entities (private/calcParts):
%
%     base.id, session_id, datestamp     the calculation's
%     base.name                          '' (the writer sets none)
%     app.*                              the software, operating system and
%                                        interpreter entities
%     depends_on element_id              the calculation's entity_id
%     <V1CLASS>.<DIRFIELD>               the opaque_body's filename
%     <V1CLASS>.curated_output_MD5_checksum   the body's content_hash
%
%   See also did2.convert.roundtrip.kilosort_clusters,
%            did2.convert.roundtrip.kiasort_clusters.

used = false(1, numel(bodies));
ob = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'opaque_body') && isempty(ob)
        ob = bodies{k};
        used(k) = true;
    end
end
[v1, leaf, ~, spec] = calcParts(bodies(~used), 'calculation', v1Class, sorterName);
if isempty(leaf)
    return;
end
blk = struct();
if isempty(ob)
    spec.unplaced{end+1} = 'no opaque_body was emitted';
else
    if ~isequal(edgeIds(ob, 'owner_id'), {char(getIn(leaf, 'base', 'id'))})
        spec.unplaced{end+1} = 'the opaque_body is not owned by the calculation';
    end
    db = getIn(ob, 'data_body');   % the block that declares filename / content_hash
    if ~isfield(db, 'content_hash') && ~isfield(db, 'filename')
        db = getIn(ob, 'opaque_body');
    end
    blk.(dirField) = fieldText(db, 'filename');
    blk.curated_output_MD5_checksum = fieldText(db, 'content_hash');
    alg = fieldText(db, 'hash_algorithm');
    if ~isempty(blk.curated_output_MD5_checksum) && ~strcmp(alg, 'MD5')
        spec.unplaced{end+1} = sprintf('the body''s hash algorithm is "%s", not MD5', alg);
    end
end
v1.(v1Class) = blk;
entity = edgeIds(leaf, 'entity_id');
if isscalar(entity)
    v1.depends_on = struct('name', 'element_id', 'value', entity{1});
else
    spec.unplaced{end+1} = sprintf('%d entity_id edges', numel(entity));
end
end
