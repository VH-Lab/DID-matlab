function v2Body = syncrule_mapping(preBody)
%SYNCRULE_MAPPING Brainstorm-J migrator: route the sync epoch nodes' clock times
%   through the time_reference model (governance part 3). 1 -> 1.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   A did_v1 syncrule_mapping relates two epochs' clocks (cost + mapping matrix);
%   each endpoint (epochnode_a / epochnode_b) embedded the epoch's clock as bare
%   `epoch_clock` + `epoch_id` char fields -- a hand-rolled epoch reference that
%   duplicated the epoch_bounded_reference model. In V_eta those two fields are
%   nested under a `time_reference` sub-structure shaped as an epoch_bounded_reference
%   (kind + epoch_clock + epoch_id), so the sync layer states time in the canonical
%   model rather than loose strings. epoch_id stays a NAME (an epoch is not a
%   standalone document in pass 1), so this is an embedded-shape normalization,
%   not a document dependency.
%   epoch_session_id / epochprobemap / objectclass / objectname / t0_t1 carry
%   through as node metadata. cost, mapping, depends_on and base are preserved.
%
%   #58 -- TWO FIELDS WERE BEING DROPPED, AND ONE BROKE A LIVE NDI QUERY.
%   reshapeEpochNode built each node with exactly four sub-fields, discarding
%   `objectname` and `t0_t1`. `objectname` is read by exact_string at
%   +ndi/+time/syncgraph.m:406-407, which finds a session's saved rules with
%
%       ndi.query('','isa','syncrule_mapping') &
%       ndi.query('','depends_on','syncgraph_id', syncgraph.id()) &
%       ( ndi.query('syncrule_mapping.epochnode_a.objectname','exact_string', dq.name) |
%         ndi.query('syncrule_mapping.epochnode_b.objectname','exact_string', dq.name) )
%
%   so a migrated corpus could not answer it. Both fields are carried now, and
%   V_eta declares them.
%
%   The header used to say the depends_on carried `syncrule_id + epochid`. There is
%   no `epochid` dependency in did_v1: NDI's template AND schema both declare
%   `syncgraph_id` + `syncrule_id`, each "mustbenotempty": 1. V_eta had declared the
%   phantom instead, empty on all 5,316 corpus documents. The body always carried the
%   real pair through (depends_on is copied verbatim); it was the SCHEMA that named
%   the wrong edge, so nothing pointed the query at anything.
%
%   NOTE the `time_reference` sub-structure keeps its epoch_bounded_reference shape.
%   That class does not survive the time-reference collapse, and this whole class
%   dissolves into `clock_alignment` when that cluster is built. This is the interim
%   repair that stops the loss, not the model.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'syncrule_mapping') && isstruct(preBody.syncrule_mapping)
    block = preBody.syncrule_mapping;
end

out = struct();
out.document_class = struct('class_name', 'syncrule_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
if isfield(preBody, 'depends_on')
    out.depends_on = preBody.depends_on;    % syncgraph_id + syncrule_id carry through
else
    out.depends_on = struct('name', {}, 'value', {});
end
if isfield(preBody, 'base') && isstruct(preBody.base)
    out.base = preBody.base;
end

smBlock = struct();
if isfield(block, 'cost');    smBlock.cost = block.cost;       end
if isfield(block, 'mapping'); smBlock.mapping = block.mapping; end
smBlock.epochnode_a = reshapeEpochNode(getStructAny(block, {'epochnode_a', 'epochNodeA'}));
smBlock.epochnode_b = reshapeEpochNode(getStructAny(block, {'epochnode_b', 'epochNodeB'}));
out.syncrule_mapping = smBlock;

v2Body = out;
end

% ===================== helpers =========================================

function node = reshapeEpochNode(src)
%RESHAPEEPOCHNODE Nest epoch_clock + epoch_id under a time_reference sub-structure
%   (epoch_bounded_reference shape); carry the node metadata through. Built with
%   exactly the six V_eta sub-fields so the reshaped node matches the schema.
%   The epochnode sub-fields are NESTED, so universalRenames (which snake_cases only
%   immediate block fields) leaves their raw v1 casing untouched -- read snake-first
%   with a camelCase fallback (jGetCharAny), as the other +migrators_j migrators do,
%   so a camelCase source does not silently read empty.
tr = struct('kind', 'epoch_bounded_reference', ...
    'epoch_clock', jGetCharAny(src, {'epoch_clock', 'epochClock'}), ...
    'epoch_id',    jGetCharAny(src, {'epoch_id', 'epochId', 'epochID'}));
node = struct( ...
    'time_reference',   tr, ...
    'epoch_session_id', jGetCharAny(src, {'epoch_session_id', 'epochSessionId', 'epochSessionID'}), ...
    'epochprobemap',    getStructAny(src, {'epochprobemap', 'epochProbeMap'}), ...
    'objectclass',      jGetCharAny(src, {'objectclass', 'objectClass'}), ...
    'objectname',       jGetCharAny(src, {'objectname', 'objectName'}), ...
    't0_t1',            getMatrixAny(src, {'t0_t1', 't0t1'}));
end

function m = getMatrixAny(block, names)
%GETMATRIXANY First numeric field among candidate names ([] if none). Snake-first
%   with a camelCase fallback, like jGetCharAny.
m = [];
if ~isstruct(block); return; end
for i = 1:numel(names)
    if isfield(block, names{i}) && isnumeric(block.(names{i}))
        m = block.(names{i});
        return;
    end
end
end

function s = getStructAny(block, names)
%GETSTRUCTANY First scalar-struct field among candidate names (empty 1x1 struct if
%   none / not a struct). Snake-first with a camelCase fallback, like jGetCharAny.
s = struct();
if ~isstruct(block); return; end
for i = 1:numel(names)
    if isfield(block, names{i}) && isstruct(block.(names{i})) && isscalar(block.(names{i}))
        s = block.(names{i});
        return;
    end
end
end
