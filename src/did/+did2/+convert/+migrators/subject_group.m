function out = subject_group(preBody)
%SUBJECT_GROUP Migrate a did_v1 subject_group to a V_epsilon subject group.
%
%   The standalone subject_group class is deprecated in favor of a
%   `subject` carrying is_group = true, with membership recorded as
%   event-sourced `group_assignment` documents, per
%   Placement_and_Group_Assignment_Proposal.md. This migration:
%
%     - rewrites the subject_group into a `subject` document with
%       is_group = true (carrying the legacy base.id forward so that
%       documents referencing the group resolve to the new subject), and
%     - when the legacy subject_group names a member via its optional
%       subject_id dependency, mints a companion `group_assignment`
%       linking that member (subject_id) to the group (group_id), so the
%       membership survives the move from identity-doc to event model.
%
%   The group_assignment's time_reference is omitted (the legacy data
%   carries no assignment time) and flagged for curator backfill.
%
%   See did-schema schemas/V_epsilon/conversions/from_did_v1/subject_group.md.

arguments
    preBody (1,1) struct
end

ic = did2.convert.interactionCommon;

base = ic.carryBase(preBody);
groupId = base.id;

subjBody = struct();
subjBody.document_class = struct('class_name', 'subject');
subjBody.base = base;
subjBody.subject = struct( ...
    'local_identifier', '', ...
    'description', '', ...
    'is_biological', false, ...
    'is_group', true);
% subject (v2.0.0) carries no depends_on; the legacy subject_id member
% link is re-expressed as a group_assignment companion below.
subjBody.depends_on = ic.dependsOn(cell(0, 2));

companions = {};
memberId = ic.depDocId(preBody, 'subject_id');
if ~isempty(memberId)
    gaBody = struct();
    gaBody.document_class = struct('class_name', 'group_assignment');
    gaBody.base = ic.newBase(ic.sessionIdOf(preBody));
    gaBody.group_assignment = struct('batch_id', '');
    gaBody.depends_on = ic.dependsOn({ ...
        'subject_id', memberId; ...
        'group_id',   groupId});
    companions{end+1} = gaBody;
end

out = [{subjBody}, companions];
end
