function tf = gapScope(action, arg)
%GAPSCOPE The fields the document being built lists as gaps in the migration report.
%
%   gapScope('-set', PATHS) sets them (a cellstr of field paths such as
%   'coordinate_system.reference_point' or
%   'coordinate_system.axes(2).positive_direction', as fillField names a
%   path); gapScope('-clear') clears them; TF = gapScope('-has',
%   PATH) asks whether PATH is one. did2.build.document sets them for the one
%   document it builds and clears them on the way out.
%
%   [gap accepted when the report lists it] (Jess Haley, 2026-11-01, did-schema
%   did_v2_go_forward_class_audit.md): a required field may be absent only when
%   the run's migration report lists it (did2.build.document 'Gaps').

persistent paths
if isempty(paths)
    paths = {};
end
tf = false;
switch action
    case '-set'
        paths = cellstr(arg);
    case '-clear'
        paths = {};
    case '-has'
        tf = any(strcmp(char(arg), paths));
    otherwise
        error('did2:build:badArgument', 'gapScope: unknown action "%s".', action);
end
end
