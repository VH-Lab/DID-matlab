function [v1, spec] = syncgraph(bodies)
%SYNCGRAPH Rebuild a v1 `syncgraph` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.syncgraph(BODIES). V1 is the sync graph
%   in NDI's v1 shape (syncgraph.json + base.json at the locked NDI-matlab
%   `main`, 3cb19a8, as +ndi/+time/syncgraph.m newdocument writes it). BODIES
%   holds the `clock_alignment_policy` and its `software` entity:
%
%     base.id, session_id, datestamp  the policy's
%     base.name                       '' (the writer sets none)
%     syncgraph.ndi_syncgraph_class   the software entity's name
%     depends_on syncrule_id_1.._N    clock_alignment_configuration_id, in
%                                     order (add_dependency_value_n's names)
%
%   Or the pass-1 passthrough (a graph with no session), its outbound renames
%   undone.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.syncgraph.

arguments
    bodies cell
end

CLASS = 'syncgraph';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
[doc, ~, swName, spec] = daqParts(bodies, 'clock_alignment_policy', spec);
if isempty(doc)
    return;
end
spec.unplaced = [spec.unplaced, others(getIn(doc, 'clock_alignment_policy'), {}, ...
    'clock_alignment_policy')];
base = rebuildBase(doc);
rules = edgeIds(doc, 'clock_alignment_configuration_id');
names = arrayfun(@(k) sprintf('syncrule_id_%d', k), 1:numel(rules), 'UniformOutput', false);
v1.document_class = struct('class_name', CLASS);
v1.depends_on = struct('name', names, 'value', rules);
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.syncgraph = struct('ndi_syncgraph_class', swName);
end
