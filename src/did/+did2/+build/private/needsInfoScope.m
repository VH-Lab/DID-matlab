function tf = needsInfoScope(action, arg)
%NEEDSINFOSCOPE The fields the document being built names in `needs_info`.
%
%   needsInfoScope('-set', PATHS) sets them (a cellstr of field paths such as
%   'coordinate_system.reference_point' or
%   'coordinate_system.axes(2).positive_direction', as fillField names a
%   path); needsInfoScope('-clear') clears them; TF = needsInfoScope('-has',
%   PATH) asks whether PATH is one. did2.build.document sets them for the one
%   document it builds and clears them on the way out.
%
%   [missing facts are needs info] (Jess Haley, 2026-10-29, did-schema
%   V_eta_go_forward_class_audit.md): a required field may be absent only when
%   the document's `needs_info` names it.

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
        error('did2:build:badArgument', 'needsInfoScope: unknown action "%s".', action);
end
end
