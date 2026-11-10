function [inEdge, outEdge, inLabel, outLabel] = syncEdgeNames()
%SYNCEDGENAMES The names a migrated sync rule is written under, as the loaded
%   schema and term registry spell them.
%
%   [INEDGE, OUTEDGE, INLABEL, OUTLABEL] = did2.unittest.helpers.syncEdgeNames()
%
%   [sync configuration edges are input and output] (Decided by Jess Haley,
%   2026-11-10, did-schema did_v2_go_forward_class_audit.md):
%   clock_alignment_configuration's `from_acquisition_system_id` /
%   `to_acquisition_system_id` become `input_id` / `output_id`, and the
%   trigger channels 'from trigger channel' / 'to trigger channel' become
%   'input trigger channel' / 'output trigger channel'. DID-matlab follows
%   before did-schema renames, so a test asks here which names to expect:
%   the edges the loaded schema declares on the class (`input_id` /
%   `output_id` once both are declared), and the term registry's names of the
%   channel nodes EMPTY:0000433 / EMPTY:0000434 (did2.convert.registeredTerm).

inEdge = 'from_acquisition_system_id';
outEdge = 'to_acquisition_system_id';
names = {};
try
    s = did2.schema.cache.shared().getClass('clock_alignment_configuration');
    deps = s.depends_on;
    if isstruct(deps); deps = num2cell(reshape(deps, 1, [])); end
    names = cellfun(@(d) char(d.name), deps, 'UniformOutput', false);
catch
end
if all(ismember({'input_id', 'output_id'}, names))
    inEdge = 'input_id';
    outEdge = 'output_id';
end
t = did2.convert.registeredTerm('EMPTY:0000433', 'from trigger channel');
inLabel = char(t.name);
t = did2.convert.registeredTerm('EMPTY:0000434', 'to trigger channel');
outLabel = char(t.name);
end
