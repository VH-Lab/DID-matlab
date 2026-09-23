function v2Body = subject_group(preBody)
%SUBJECT_GROUP Brainstorm-J migrator: did_v1 subject_group -> bare subject
%   (+ member_of relations).
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

groupId = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    groupId = preBody.base.id;
end

subjectDoc = struct();
subjectDoc.document_class = struct( ...
    'class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
subjectDoc.depends_on = struct('name', {}, 'value', {});
if isfield(preBody, 'base') && isstruct(preBody.base)
    subjectDoc.base = preBody.base;   % preserve id -> member edges' parent resolves
end
% bare identity: no is_group / is_biological in V_eta
groupName = jEnsureLocalId(groupName, preBody);   % local_identifier is REQUIRED
subjectDoc.subject = struct('local_identifier', groupName, 'description', desc);

bodies = {subjectDoc};
for memberId = memberSubjectIds(preBody)
    bodies{end+1} = memberOfRelation(preBody, memberId{1}, groupId); %#ok<AGROW>
end
v2Body = bodies;
end

% ===================== helpers =========================================

function ids = memberSubjectIds(preBody)
%MEMBERSUBJECTIDS The non-empty member dependencies (subject_id / subject_id_N).
ids = {};
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
for k = 1:numel(preBody.depends_on)
    d = preBody.depends_on(k);
    if ~isfield(d, 'name') || isempty(regexp(d.name, '^subject_id(_\d+)?$', 'once'))
        continue;
    end
    val = '';
    if isfield(d, 'value') && ~isempty(d.value); val = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); val = char(d.document_id); end
    if ~isempty(val); ids{end+1} = val; end %#ok<AGROW>
end
end

function rel = memberOfRelation(preBody, memberId, groupId)
%MEMBEROFRELATION member --member_of--> group (child = member, parent = group).
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', memberId), ...   % the member
    struct('name', 'parent', 'value', groupId)];       % the group
rel.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_group_membership', 'datestamp', ds);
% `relation` (renamed from subject_relation) is abstract with no fields -> no block.
rel.directed_relation = struct('relation', struct('node', '', 'name', 'member_of'));
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
