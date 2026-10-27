function v2Body = subject_group(preBody)
%SUBJECT_GROUP Brainstorm-J migrator: did_v1 subject_group -> an `entity` of
%   type `group`, id preserved (+ one member_of directed_relation per member).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Per did-schema V_eta_SPEC.md section 1, `subject` is a BARE identity card
%   (v3.0.0): is_group and is_biological are REMOVED. A group is just a
%   `subject`; its group-ness is derived from the relationship graph -- its
%   members point at it via `member_of` directed_relations -- not a flag.
%
%       subject_group  ->  subject   (bare identity, id preserved)
%                          + one directed_relation per member
%                            (child = member subject, parent = this group,
%                             relation = member_of)
%
%   did_v1 subject_group carries its members as `subject_id_1..N` dependencies.
%   Each becomes a member_of edge so the membership is preserved in the J graph
%   (dropping them would lose the group's contents; the members are real subject
%   documents in the batch, so the parent/child references resolve). A group with
%   no member dependencies is just the bare subject (1 -> 1).
%
%   The group id is preserved on the subject so inbound references (and the
%   member edges' parent) resolve to it.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it, with no universalRenames, so a member edge is read in its v1
%   spelling, {name, value} (did2.convert.v1read.readDependsOn). Every v1
%   field, from NDI's subject_group.json and base.json at the locked
%   NDI-matlab `main` (3cb19a8), and where it goes; did2.convert.roundtrip.
%   subject_group rebuilds the v1 document from the output:
%
%     base.id                  -> the group entity's base.id (preserved), and
%                                 each member_of relation's parent_id
%     base.session_id          -> the session_id edge (v1_to_v2, on the way out)
%     base.datestamp           -> base.creation_timestamp (v1_to_v2)
%     base.name                -> entity.name when not empty, whether or not
%                                 it equals the group's name; '' (the template
%                                 default, +babu/import) writes nothing
%                                 (jBaseName; Decided by Jess Haley, 2026-10-27
%                                 [v1 name is the entity name])
%     depends_on subject_id_N  -> one member_of relation each, in order (a
%                                 member edge spelled `subject_id`, with no
%                                 number, is the same edge: [member edge
%                                 number is notation], the round trip)
%     subject_group (block)    -> NDI's template block is EMPTY: a writer-shaped
%                                 group states no name and is carried whole as
%                                 v1 (carry-034, [unnamed groups named by the
%                                 map]). `group_name` / `description` are read
%                                 when a body carries them (DID-side fixtures).

arguments
    preBody (1,1) struct
end

groupName = '';
desc = '';
if isfield(preBody, 'subject_group') && isstruct(preBody.subject_group)
    sg = preBody.subject_group;
    groupName = getCharField(sg, 'group_name');
    desc = getCharField(sg, 'description');
end

base = did2.convert.v1read.readBase(preBody);
groupId = '';
if strcmp(base.source, 'base')
    groupId = base.id;
end

% did-schema #88: an `entity` of type group (members by `member_of`), id
% preserved so the member edges' parent resolves.
if isempty(strtrim(groupName))
    % [no invented values] / [generic stage is lossless] (Jess Haley,
    % 2026-10-25): a required local_identifier the source does not state is not
    % filled with the document id (jEnsureLocalId); the document is carried
    % whole as v1.
    % carry-register: carry-034
    did2.convert.reportNote('carried_as_v1', 'subject_group', char(groupId), ...
        '[carry-034] unplaced: no subject_group.group_name (a local_identifier would be invented)');
    v2Body = {preBody};
    return;
end
subjectDoc = jEntity(preBody, 'group', ...
    struct('local_identifier', groupName, 'description', desc, ...
    'name', jBaseName(preBody)), 'Id', groupId);
bodies = {subjectDoc};
for memberId = memberSubjectIds(preBody)
    bodies{end+1} = memberOfRelation(preBody, memberId{1}, groupId); %#ok<AGROW>
end
v2Body = bodies;
end

% ===================== helpers =========================================

function ids = memberSubjectIds(preBody)
%MEMBERSUBJECTIDS The non-empty member dependencies (subject_id / subject_id_N),
%   read from the raw v1 `depends_on` (did2.convert.v1read.readDependsOn).
ids = {};
deps = did2.convert.v1read.readDependsOn(preBody, 'Name', '^subject_id(_\d+)?$');
for k = 1:numel(deps)
    if ~isempty(deps(k).document_id)
        ids{end+1} = char(deps(k).document_id); %#ok<AGROW>
    end
end
end

function rel = memberOfRelation(preBody, memberId, groupId)
rel = jEntityRelation(preBody, memberId, groupId, 'member_of');
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    end
end
end
