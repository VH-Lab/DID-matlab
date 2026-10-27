function [v1, spec] = subject_group(bodies)
%SUBJECT_GROUP Rebuild a v1 `subject_group` from what
%   did2.convert.migrators_j.subject_group emitted: one `entity` of type group
%   and one `member_of` directed_relation per member.
%
%   [V1, SPEC] = did2.convert.roundtrip.subject_group(BODIES): BODIES is a cell
%   of the emitted document structs. V1 is the group in NDI's v1 shape
%   (subject_group.json + base.json at the locked NDI-matlab `main`, 3cb19a8;
%   members as +babu/import writes them, add_dependency_value_n):
%
%     base.id, base.session_id, base.datestamp   from the group entity
%     base.name                    the group's name; '' is equally possible
%     depends_on                   {name 'subject_id_<n>', value <member id>},
%                                  n = 1..N in the order the relations were
%                                  emitted (the order of the v1 entries)
%     subject_group.group_name     entity.local_identifier
%     subject_group.description    entity.description ('' when left out)
%
%   NDI's template block is EMPTY, so a writer-shaped group is carried whole
%   as v1 (carry-034) and never reaches this function
%   (did2.convert.roundtrip.check compares a carried body directly).
%   `group_name` / `description` are the shape the migrator reads when a body
%   carries them.
%
%   SPEC.equivalents: `base.name` can only have been the group's name or ''
%   (the template default; +babu/import leaves it). SPEC.unplaced lists any
%   emitted document that is neither the group entity nor a member_of relation
%   whose parent is the group.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.subject_group.

arguments
    bodies cell
end

spec = struct('equivalents', struct('path', {}, 'values', {}, 'why', {}), ...
    'unplaced', {{}});
v1 = struct();
grp = [];
rels = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if isEntityOfType(b, 'group') && isempty(grp)
        grp = b;
    elseif strcmp(classNameOf(b), 'directed_relation')
        rels{end+1} = b; %#ok<AGROW>
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the group or a member edge', ...
            k, classNameOf(b));
    end
end
if isempty(grp)
    spec.unplaced{end+1} = 'no group entity was emitted';
    return;
end
[base, entity] = rebuildBase(grp);
name = fieldText(entity, 'local_identifier');

members = {};
for k = 1:numel(rels)
    r = rels{k};
    child = edgeOf(r, 'child_id');
    parent = edgeOf(r, 'parent_id');
    isMember = isfield(r, 'directed_relation') && isstruct(r.directed_relation) ...
        && isfield(r.directed_relation, 'relation') ...
        && strcmp(did2.build.vocabularyHandle('relation', r.directed_relation.relation), 'member_of');
    if isMember && strcmp(parent, base.id) && ~isempty(child)
        members{end+1} = child; %#ok<AGROW>
    else
        spec.unplaced{end+1} = sprintf( ...
            'a directed_relation (child %s, parent %s) is not a member_of edge to the group', ...
            child, parent);
    end
end

v1.document_class = struct('class_name', 'subject_group');
v1.depends_on = struct('name', {}, 'value', {});
for k = 1:numel(members)
    v1.depends_on(k) = struct('name', sprintf('subject_id_%d', k), 'value', members{k});
end
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', name, 'datestamp', base.datestamp);
v1.subject_group = struct('group_name', name, ...
    'description', fieldText(entity, 'description'));
spec.equivalents(end+1) = struct('path', 'base.name', 'values', {{name, ''}}, ...
    'why', ['the group''s name ([lossless means round trip]: a restatement) ' ...
    'or the template default '''' ([writer default is not set])']);
end

function id = edgeOf(body, name)
deps = did2.convert.v1read.readDependsOn(body, 'Name', ['^' name '$']);
id = '';
if ~isempty(deps)
    id = deps(1).document_id;
end
end
