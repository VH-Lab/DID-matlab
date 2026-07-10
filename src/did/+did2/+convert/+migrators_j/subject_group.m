function v2Body = subject_group(preBody)
%SUBJECT_GROUP Brainstorm-J migrator: did_v1 subject_group -> bare subject.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Per did-schema V_eta_SPEC.md section 1, `subject` is a BARE identity card
%   (v3.0.0): is_group and is_biological are REMOVED. A group is just a
%   `subject`; its group-ness is derived from the relationship graph (things
%   point at it via member_of directed_relations), not a flag.
%
%       subject_group  ->  subject   (local_identifier + description only)
%
%   did_v1 subject_group is an (essentially empty) marker carrying no members,
%   so nothing is synthesized here (inventing member_of edges would fabricate
%   data). 1 -> 1.

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
    'class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
v2Body.depends_on = struct('name', {}, 'value', {});
if isfield(preBody, 'base') && isstruct(preBody.base)
    v2Body.base = preBody.base;
end
% bare identity: no is_group / is_biological in V_eta
v2Body.subject = struct('local_identifier', groupName, 'description', desc);
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
