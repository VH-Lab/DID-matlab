function h = clockText(t)
%CLOCKTEXT The did_v1 clocktype string a V2 clock term restores ('' when absent).
%
%   H = clockText(T): T is a relative_time_reference `value.clock` or a
%   clock_alignment_configuration `clock` ({node, name}, or a name). H is the
%   v1 handle ('dev_local_time', 'utc', ...) read BY NODE first and then by
%   name (did2.build.vocabularyHandle 'clock'), so a document storing the
%   node with the old name, the node with the label ("device local time"), or
%   the old name alone restores the same v1 string. Decided by Jess Haley,
%   2026-10-26 [clock terms get nodes] (did-schema
%   V_eta_go_forward_class_audit.md): code compares clock nodes first, then
%   the stored name changes. A clock outside the four restores its name.
[node, name] = termParts(t);
h = '';
if isempty(node) && isempty(name)
    return;
end
h = did2.build.vocabularyHandle('clock', struct('node', node, 'name', name));
end
