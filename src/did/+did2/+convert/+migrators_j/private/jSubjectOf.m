function id = jSubjectOf(preBody, srcNames)
%JSUBJECTOF The id of the first non-empty depends_on edge among SRCNAMES on
%   the v1 body PREBODY (default {'subject_id'}), '' when none carries one.
%   What a migrated statement is about: its `entity_id` (did-schema #88;
%   `subject_id` before), which the caller passes to jStatement. The successor
%   of jCarrySubject, which returned the pre-#73 edge struct.

if nargin < 2 || isempty(srcNames)
    srcNames = {'subject_id'};
end
if ischar(srcNames); srcNames = {srcNames}; end
id = '';
for k = 1:numel(srcNames)
    id = jDependency(preBody, srcNames{k});
    if ~isempty(id)
        return;
    end
end
end
