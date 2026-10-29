function [v1, spec] = session_in_a_dataset(bodies)
%SESSION_IN_A_DATASET Rebuild a v1 `session_in_a_dataset` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.session_in_a_dataset(BODIES). V1 is the
%   membership record in NDI's v1 shape (session_in_a_dataset.json + base.json
%   at the locked NDI-matlab `main`, 3cb19a8, as +ndi/dataset.m writes it).
%   BODIES holds the bare `dataset` entity, the session's `directed_relation`
%   to it (`included_in`, or `part_of` on the field shape), and, when the
%   batch held it, the member SESSION's entity, from which the session's
%   reference is read back ([ingested session membership]; for a linked
%   session [linked session reference follows the ingested rule], Jess Haley,
%   2026-10-27):
%
%     base.id                       the relation's id (minted: the v1 id is
%                                   not kept, so the round trip reports it lost)
%     base.session_id               the dataset entity's id (the parent)
%     base.datestamp                the relation's creation_timestamp
%     base.name                     '' (the writer sets none)
%     .session_id                   the relation's child
%     .is_linked                    1 for "database linking" (EMPTY:0000400),
%                                   0 for "database ingestion" (EMPTY:0000399)
%     .session_creator              the "software class" parameter (EMPTY:0000401)
%     .session_creator_input2       the "Pathname" parameter (NCIT:C47922) of a
%                                   linked session, else ''
%     .session_reference            the session entity's local_identifier
%                                   (when that entity is in BODIES), else ''
%     .session_creator_input1..3    '' -- a non-empty v1 input the migrator
%                                   dropped can only have been a copy of the
%                                   session's reference or id ([session
%                                   membership records linked or ingested];
%                                   [session opener inputs]): spec.equivalents
%     .session_creator_input4..6    '' -- a non-empty one carries the
%                                   membership whole ([session opener inputs],
%                                   Jess Haley, 2026-10-27; carry-075)
%
%   Any other emitted document, or a relation or entity field this inverse
%   does not read, is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.session_in_a_dataset.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
rel = [];
ds = [];
used = false(1, numel(bodies));
for k = 1:numel(bodies)
    if isempty(rel) && strcmp(classNameOf(bodies{k}), 'directed_relation')
        rel = bodies{k};
        used(k) = true;
    elseif isempty(ds) && isEntityOfType(bodies{k}, 'dataset')
        ds = bodies{k};
        used(k) = true;
    end
end
if isempty(rel) || isempty(ds)
    spec.unplaced{end+1} = 'the dataset entity and its membership relation were not both emitted';
    return;
end
child = firstId(rel, 'child_id');
parent = firstId(rel, 'parent_id');
[dsBase, dsEntity] = rebuildBase(ds);
if ~strcmp(parent, dsBase.id)
    spec.unplaced{end+1} = 'the relation''s parent is not the dataset entity';
end
spec.unplaced = [spec.unplaced, others(dsEntity, {'type'}, 'dataset entity')];
handle = did2.build.vocabularyHandle('relation', getIn(rel, 'directed_relation', 'relation'));
if ~any(strcmp(handle, {'included_in', 'part_of'}))
    spec.unplaced{end+1} = sprintf('the relation is "%s", not included_in', handle);
end
spec.unplaced = [spec.unplaced, others(getIn(rel, 'directed_relation'), ...
    {'relation', 'order', 'method'}, 'directed_relation')];
spec.unplaced = [spec.unplaced, others(getIn(rel, 'relation'), {'method'}, 'relation')];
[mterm, params] = methodOf(rel);
[mnode, ~] = termParts(mterm);
linked = [];
if sameCurie(mnode, 'EMPTY:0000400')
    linked = 1;
elseif sameCurie(mnode, 'EMPTY:0000399')
    linked = 0;
else
    spec.unplaced{end+1} = sprintf('the relation''s method "%s" is neither ingestion nor linking', mnode);
end
creator = '';
path = '';
params = asCell(params);
for k = 1:numel(params)
    [vnode, vname] = termParts(getIn(params{k}, 'variable'));
    txt = fieldText(params{k}, 'text');
    if sameCurie(vnode, 'EMPTY:0000401')
        creator = txt;
    elseif sameCurie(vnode, 'NCIT:C47922') && isequal(linked, 1)
        path = txt;
    else
        spec.unplaced{end+1} = sprintf('method parameter "%s" has no v1 field', vname);
    end
end
reference = '';
for k = find(~used)
    if isEntityOfType(bodies{k}, 'session') && strcmp(char(getIn(bodies{k}, 'base', 'id')), child)
        used(k) = true;
        if ~isempty(linked)
            [~, se] = rebuildBase(bodies{k});
            reference = fieldText(se, 'local_identifier');
        end
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a session_in_a_dataset', ...
        k, classNameOf(bodies{k}));
end
base = rebuildBase(rel);
v1.document_class = struct('class_name', 'session_in_a_dataset');
v1.depends_on = [];
v1.base = struct('id', base.id, 'session_id', parent, 'name', '', ...
    'datestamp', base.datestamp);
blk = struct('session_id', child, 'session_reference', reference, ...
    'is_linked', linked, 'session_creator', creator);
for n = 1:6
    blk.(sprintf('session_creator_input%d', n)) = '';
end
blk.session_creator_input2 = path;
v1.session_in_a_dataset = blk;
copies = {child};
if ~isempty(reference); copies{end+1} = reference; end
for n = 1:3
    if n == 2 && isequal(linked, 1)
        continue;
    end
    spec.equivalents(end+1) = struct('path', sprintf('session_in_a_dataset.session_creator_input%d', n), ...
        'values', {copies}, 'why', ['an input that restates the session''s reference or ' ...
        'id is dropped as a copy ([session membership records linked or ingested], ' ...
        'Jess Haley, 2026-10-25)']);
end
end

function id = firstId(body, name)
ids = edgeIds(body, name);
id = '';
if ~isempty(ids); id = ids{1}; end
end

function [term, params] = methodOf(rel)
% the relation's method {term, parameters}: in the `relation` block on the
% did-schema #88 shape, in the leaf block before it
term = [];
params = [];
for blk = {'relation', 'directed_relation'}
    m = getIn(rel, blk{1}, 'method');
    if isstruct(m) && isscalar(m) && (isfield(m, 'term') || isfield(m, 'parameters'))
        if isfield(m, 'term'); term = m.term; end
        if isfield(m, 'parameters'); params = m.parameters; end
        return;
    elseif ~isempty(m)
        term = m;
        params = getIn(rel, blk{1}, 'method_parameters');
        return;
    end
end
end
