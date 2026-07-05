function v2Body = subject_group(preBody)
%SUBJECT_GROUP Brainstorm-I migrator: did_v1 subject_group -> subject (is_group).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_zeta'.
%   Per did-schema V_zeta_SPEC.md, subject_group is deprecated and folds
%   into the subject tier:
%
%       subject_group  ->  subject  (is_group: true)
%
%   The legacy subject_group document is an (essentially empty) marker --
%   membership is expressed by member subjects referencing the group, not by
%   fields on the group doc. So the per-document migration is 1 -> 1: the
%   group becomes a `subject` flagged is_group. Membership edges become
%   `group_assignment` events, but those are RELATIONAL (they need the member
%   subjects that point at this group) and are assembled in the NDI layer,
%   exactly like stimulus_bath -> bath; they are not manufactured here from a
%   doc that carries no members. Identical to the Brainstorm-E fold except
%   for the schema_version tag (subject/is_group are unchanged in V_zeta).

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

v2Body = struct();
v2Body.document_class = struct( ...
    'class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_zeta');
v2Body.depends_on = struct('name', {}, 'value', {});
if isfield(preBody, 'base') && isstruct(preBody.base)
    v2Body.base = preBody.base;
end
v2Body.subject = struct( ...
    'local_identifier', groupName, ...
    'description', desc, ...
    'is_biological', false, ...
    'is_group', true);
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
