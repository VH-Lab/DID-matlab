function [subjectId, found] = carriedElementSubject(elementId)
%CARRIEDELEMENTSUBJECT The v1 subject a migrated element's carried field holds.
%
%   [SUBJECTID, FOUND] = did2.convert.carriedElementSubject(ELEMENTID) reads
%   the run's migration report (did2.convert.migrationReport 'carriedFields',
%   as held, or as loaded again from a stored report with 'load') for the
%   carried field `depends_on subject_id` of the element ELEMENTID, written
%   by did2.convert.carryElementSubject ([one-field carry in the migration
%   report], Jess Haley, 2026-11-19, did-schema
%   docs/plans/did_v2_standing_wiring_plan.md; carry register row carry-172).
%   SUBJECTID is its value ('' when none); FOUND is true when the report
%   lists one. A value that is not text is not a subject id: FOUND is false.
%
%   F = did2.convert.carriedElementSubject('field') is the field name the
%   entry carries, 'depends_on subject_id' (the carry register row's field).
%
%   See also did2.convert.carryElementSubject, did2.convert.migrationReport.

FIELD = 'depends_on subject_id';
if ischar(elementId) && strcmp(elementId, 'field')
    subjectId = FIELD;
    found = true;
    return;
end
subjectId = '';
found = false;
if isstring(elementId) && isscalar(elementId)
    elementId = char(elementId);
end
if ~ischar(elementId) || isempty(elementId)
    return;
end
entries = did2.convert.migrationReport('carriedFields', elementId);
for k = 1:numel(entries)
    if ~strcmp(entries(k).field, FIELD)
        continue;
    end
    v = entries(k).value;
    if isstring(v) && isscalar(v)
        v = char(v);
    end
    if ischar(v) && ~isempty(strtrim(v))
        subjectId = strtrim(v);
        found = true;
    end
    return;
end
end
