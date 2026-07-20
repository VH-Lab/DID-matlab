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
%   standalone document -- the same reason syncrule_mapping.epochid is left untyped),
%   so this is an embedded-shape normalization, not a document dependency.
%   epoch_session_id / epochprobemap / objectclass carry through as node metadata.
%   cost, mapping, the depends_on (syncrule_id + epochid) and base are preserved.

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
    out.depends_on = preBody.depends_on;    % syncrule_id + epochid carry through
else
    out.depends_on = struct('name', {}, 'value', {});
end
if isfield(preBody, 'base') && isstruct(preBody.base)
    out.base = preBody.base;
end

smBlock = struct();
if isfield(block, 'cost');    smBlock.cost = block.cost;       end
if isfield(block, 'mapping'); smBlock.mapping = block.mapping; end
smBlock.epochnode_a = reshapeEpochNode(getStructField(block, 'epochnode_a'));
smBlock.epochnode_b = reshapeEpochNode(getStructField(block, 'epochnode_b'));
out.syncrule_mapping = smBlock;

v2Body = out;
end

% ===================== helpers =========================================

function node = reshapeEpochNode(src)
%RESHAPEEPOCHNODE Nest epoch_clock + epoch_id under a time_reference sub-structure
%   (epoch_bounded_reference shape); carry the node metadata through. Built with
%   exactly the four V_eta sub-fields so the reshaped node matches the schema.
tr = struct('kind', 'epoch_bounded_reference', ...
    'epoch_clock', getCharField(src, 'epoch_clock'), ...
    'epoch_id',    getCharField(src, 'epoch_id'));
node = struct( ...
    'time_reference',   tr, ...
    'epoch_session_id', getCharField(src, 'epoch_session_id'), ...
    'epochprobemap',    getStructField(src, 'epochprobemap'), ...
    'objectclass',      getCharField(src, 'objectclass'));
end

function s = getStructField(block, name)
%GETSTRUCTFIELD A scalar struct field ('empty' 1x1 struct if absent / not a struct).
s = struct();
if isstruct(block) && isfield(block, name) && isstruct(block.(name)) ...
        && isscalar(block.(name))
    s = block.(name);
end
end

function s = getCharField(block, name)
s = '';
if isstruct(block) && isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v);
    end
end
end
