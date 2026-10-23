function x = dropSessionEdge(x)
%DROPSESSIONEDGE A document's edges without base's own `session_id` edge.
%
%   X = did2.unittest.helpers.dropSessionEdge(X) removes the `session_id` edge
%   from X -- a depends_on struct array, a cell of depends_on entries, or a
%   cellstr of edge names -- when the loaded schema stores the session id as
%   that EDGE (did-schema V_eta_relation_inheritance_plan.md, 2026-10-20), and
%   returns X unchanged when it stores it as the base.session_id field.
%
%   For the tests that pin a migrator's EXACT edge set ("the fold emits exactly
%   subject_id + the anchor", "this class carries no edge"): on the edge shape
%   every document also carries the edge `base` declares, which says where the
%   document is stored and is not the migrator's to emit or withhold.
%
%   STATUS: NOT VERIFIED BY EXECUTION in the authoring environment (no MATLAB).

arguments
    x
end

if ~did2.schema.cache.shared().sessionIdIsEdge() || isempty(x)
    return;
end
if iscellstr(x)
    x = x(~strcmp(x, 'session_id'));
    return;
end
keep = true(1, numel(x));
for k = 1:numel(x)
    if iscell(x)
        e = x{k};
    else
        e = x(k);
    end
    keep(k) = ~(isstruct(e) && isfield(e, 'name') && strcmp(char(e.name), 'session_id'));
end
x = x(keep);
end
