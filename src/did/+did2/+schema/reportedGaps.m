function [fields, problems] = reportedGaps(s)
%REPORTEDGAPS The field paths the migration report lists as gaps of a document.
%
%   [FIELDS, PROBLEMS] = did2.schema.reportedGaps(S) reads the gaps the
%   migration run held by did2.convert.migrationReport lists for S.base.id
%   (S a document struct) and returns the `field` of each as a cellstr, and
%   PROBLEMS, a cellstr naming each gap for a field S gives (a gap for a fact
%   that is present says something false). A document no held run lists, or
%   any document while no run is held, gives {} and {}.
%
%   Decided by Jess Haley, 2026-11-01 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md) [gap accepted when the report
%   lists it]: "a migrated document may lack a required field only when its
%   run's migration report lists that document and field with a reason; any
%   other missing required field fails validation", and [migration record]:
%   `base.needs_info` is dropped, so the document itself no longer says what
%   its source left out. A path is <block>.<field>, with (k) after a
%   struct-array field and . between levels:
%   'coordinate_system.reference_point',
%   'coordinate_system.axes(2).positive_direction'.
%
%   See also did2.convert.migrationReport, did2.schema.cache/validateDocument,
%            did2.build.document.

fields = {};
problems = {};
if ~isstruct(s) || ~isfield(s, 'base') || ~isstruct(s.base) || ~isfield(s.base, 'id')
    return;
end
id = s.base.id;
if ~(ischar(id) || (isstring(id) && isscalar(id))) || ~did2.convert.migrationReport('active')
    return;
end
entries = did2.convert.migrationReport('gaps', char(id));
for k = 1:numel(entries)
    f = entries(k).field;
    if did2.schema.givesField(s, f)
        problems{end+1} = sprintf(['the migration report lists "%s" of %s as a ' ...
            'gap, but the document gives it'], f, char(id)); %#ok<AGROW>
    end
    fields{end+1} = f; %#ok<AGROW>
end
end
