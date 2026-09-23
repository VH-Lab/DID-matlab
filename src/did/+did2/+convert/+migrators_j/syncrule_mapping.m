function bodies = syncrule_mapping(preBody)
%SYNCRULE_MAPPING Brainstorm-J migrator: did_v1 `syncrule_mapping` -> `clock_alignment`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [sync mapping], jess@walthamdatascience.com / 2026-08-08:
%     "syncrule_mapping -> `clock_alignment` (subclass of relation, polynomial),
%      base.id PRESERVED; endpoints become from_reference / to_reference on
%      relative_reference documents; syncgraph_id RESTORED and the invented
%      required `epochid` (5,316 docs, 100% empty) REMOVED; `degree` kept and
%      CHECKED."
%
%   TWO BRANCHES, and TODAY EVERY REAL DOCUMENT TAKES THE SECOND:
%
%     1 -> 3   clock_alignment + two `relative_reference` endpoints, when both
%              epochnodes can be anchored to an `epoch` DOCUMENT.
%     1 -> 1   the #58 passthrough repair below, otherwise.
%
%   ---------------------------------------------------------------------
%   THE GATE, AND WHY IT IS CLOSED (#60, THE EPOCH PASS)
%   ---------------------------------------------------------------------
%   The signed model dissolves `epochnode_a` / `epochnode_b` into two
%   `relative_reference` documents. `relative_reference.relative_to` is REQUIRED
%   ("a relative time with no referent is not interpretable" -- team call), and
%   the plan is explicit about what it must point at and what depends on that:
%
%       "epochnode_a/_b DISSOLVED -- epoch_id, epoch_clock, epoch_session_id,
%        t0_t1, epochprobemap, objectclass all recoverable through the two
%        reference documents AND THE EPOCH THEY POINT AT. objectname is
%        recoverable ONLY VIA epoch.instrument_id"
%
%   NO MIGRATOR MINTS AN `epoch` DOCUMENT. Re-checked rather than repeated:
%
%       grep -rn "class_name', 'epoch'" --include=*.m /home/user/DID-matlab/src/did
%          -> 1 hit, and it is inside private/jEpochDocId.m's own comment
%
%   #60 records the correct shape (mint one `epoch` per distinct `epochid.epochid`
%   by GROUPING -- a second pass; a single-document migrator cannot see the
%   group). Until it lands there is nothing to anchor to, and the two ways of
%   proceeding anyway are both worse than waiting:
%
%     * leave `relative_to` blank -- a REQUIRED edge, empty, validating clean
%       because +did2/+validate/references.m:90 skips empty edges. That is the
%       exact defect this cluster's sign-off REMOVED (the invented `epochid`,
%       5,316 documents, 100% empty).
%     * anchor to `epoch_session_id` instead. It is a real, resolvable session
%       id, so it would go green -- and it would DESTROY `epoch_id`,
%       `objectclass` and `epochprobemap`, which have no home on a
%       relative_reference, while moving `objectname` off the path eight live
%       NDI sites string-match. That is #58's repair undone, silently.
%
%   So the conversion is BUILT AND GATED. The gate reads `epoch_id_1` /
%   `epoch_id_2` depends_on entries -- the `_n` idiom NDI's own
%   `add_dependency_value_n` uses -- and NO did_v1 document carries them, so
%   every corpus document today takes the passthrough branch. The tests drive
%   BOTH branches, which is the same shape private/jEpochDocId documents for the
%   ingested-payload migrators ("the day the epoch pass stamps an `epoch_id`
%   edge, these migrators convert with no further change").
%
%   IF #60 NAMES THE EDGES DIFFERENTLY, epochDocIds() BELOW IS THE ONLY THING
%   THAT CHANGES.
%
%   ---------------------------------------------------------------------
%   THE PASSTHROUGH BRANCH -- #58, UNCHANGED, AND IT IS WHAT KEEPS THE LIVE
%   NDI QUERY WORKING
%   ---------------------------------------------------------------------
%   A did_v1 syncrule_mapping relates two epochs' clocks (cost + mapping matrix);
%   each endpoint embedded the epoch's clock as bare `epoch_clock` + `epoch_id`
%   char fields -- a hand-rolled epoch reference. In V_eta those two fields are
%   nested under a `time_reference` sub-structure shaped as an
%   epoch_bounded_reference (kind + epoch_clock + epoch_id), so the sync layer
%   states time in the canonical model rather than loose strings. epoch_id stays
%   a NAME (an epoch is not a standalone document in pass 1), so this is an
%   embedded-shape normalization, not a document dependency.
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
%   V_eta declares them. commonTriggersOverlappingEpochs.m:156-160 reads the same
%   block one level further (`.epoch_id` as well as `.objectname`), and that
%   query is the short-circuit that stops the rule recomputing from raw device
%   files -- so this document is PRIMARY DATA, not a rebuildable cache.
%
%   The header used to say the depends_on carried `syncrule_id + epochid`. There
%   is no `epochid` dependency in did_v1: NDI's template AND schema both declare
%   `syncgraph_id` + `syncrule_id`, each "mustbenotempty": 1. V_eta had declared
%   the phantom instead, empty on all 5,316 corpus documents. The body always
%   carried the real pair through (depends_on is copied verbatim); it was the
%   SCHEMA that named the wrong edge, so nothing pointed the query at anything.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'syncrule_mapping') && isstruct(preBody.syncrule_mapping)
    block = preBody.syncrule_mapping;
end

% ---------------------------------------------------------------------
% BRANCH 1 -- the signed model, gated on the epoch documents existing.
% ---------------------------------------------------------------------
[epochA, epochB] = epochDocIds(preBody);
if ~isempty(epochA) && ~isempty(epochB)
    converted = jClockAlignmentBodies(preBody, block, epochA, epochB);
    if ~isempty(converted)
        bodies = converted;
        return;
    end
    % Fell through: jClockAlignmentBodies refused (no polynomial, a 'no_time'
    % clock, a non-finite extent, or a missing syncgraph_id / syncrule_id). It
    % returns {} rather than a hollow document, and the passthrough below then
    % preserves the source intact -- which is strictly more than the converted
    % form would have carried.
end

% ---------------------------------------------------------------------
% BRANCH 2 -- #58's passthrough repair.
% ---------------------------------------------------------------------
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

bodies = {out};
end

% ===================== the gate ============================================

function [idA, idB] = epochDocIds(preBody)
%EPOCHDOCIDS The two `epoch` DOCUMENT ids this mapping's endpoints anchor to.
%   Returns ('', '') for every did_v1 document, BY CONSTRUCTION -- see the
%   migrator header. This is the switch, and the only line that changes when
%   #60's epoch pass lands.
%
%   The names follow NDI's own numbered-dependency idiom
%   (did/document.m:349 -- `add_dependency_value_n` writes `<name>_1`, `<name>_2`),
%   which is what a two-endpoint document would use. A bare `epoch_id` is
%   deliberately NOT accepted: one epoch id cannot anchor two endpoints, and
%   silently reusing it for both would assert that the two devices' epochs are
%   the same epoch.
idA = jSyncDependency(preBody, 'epoch_id_1');
idB = jSyncDependency(preBody, 'epoch_id_2');
end

% ===================== #58 passthrough helpers =============================

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
    'epochprobemap',    carryProbeMap(src), ...
    'objectclass',      jGetCharAny(src, {'objectclass', 'objectClass'}), ...
    'objectname',       jGetCharAny(src, {'objectname', 'objectName'}), ...
    't0_t1',            getMatrixAny(src, {'t0_t1', 't0t1'}));
end

function v = carryProbeMap(src)
%CARRYPROBEMAP The epochprobemap, VERBATIM -- and it is a CHAR, not a struct.
%
%   THIRD FIELD THAT WAS BEING SILENTLY DROPPED, found the same way the other
%   two were (#58): by reading the writer instead of the V_eta schema.
%
%     git show origin/main:src/ndi/+ndi/+time/syncgraph.m:313-314
%        sync_mapping_struct.epochnode_a.epochprobemap = ...
%            sync_mapping_struct.epochnode_a.epochprobemap.serialize();
%     git show origin/main:src/ndi/+ndi/+epoch/epochprobemap_daqsystem.m:136-143
%        function s = serialize(...)
%           % Create a CHARACTER ARRAY representation
%           s = '';
%     git show origin/main:src/ndi/ndi_common/database_documents/ingestion/syncrule_mapping.json
%        "epochprobemap":  "",        <- line 30 and line 39, a STRING
%
%   Template and writer AGREE that this is a string, so there is no
%   writer-beats-template judgement to make. The reader was
%   `getStructAny(src, {'epochprobemap', ...})`, which requires isstruct, so on
%   EVERY real corpus document it returned an empty struct and the serialised
%   probe map -- name / reference / type / devicestring / subjectstring for
%   every probe on that epoch -- went nowhere. The unit fixture that made it
%   look correct used a struct, which no writer produces. Same shape as the
%   distance_metadata wrong-assumed-shape bug.
%
%   Carried VERBATIM (char or struct) rather than coerced: the value is opaque
%   to this migrator and the only safe transformation is none.
%
%   THE SCHEMA HALF HAS SINCE LANDED, AND THIS PARAGRAPH USED TO SAY IT HAD NOT.
%   It read: "NOTE THE SCHEMA IS THE ONE THAT IS WRONG. V_eta's syncrule_mapping
%   tombstone declares `epochnode_a.epochprobemap` as type `structure` [...] the
%   declaration should say `char`. Schema-side, out of this change's scope;
%   reported with the build." That was true when written and is not true now. It
%   is corrected here rather than deleted because, left standing, it instructs a
%   reader to go and change a schema that is ALREADY CORRECT -- and changing the
%   V_eta schema is a separate decision with its own blast radius.
%
%     DID-schema tools/build_v_eta.py:6696-6710
%        # TYPE CORRECTED 2026-08-10: it was `structure`; it is a CHAR.
%        subfield("epochprobemap", "string", ...
%     DID-schema schemas/V_eta/stable/syncrule_mapping.json
%        epochnode_a.epochprobemap: type='string'   (epochnode_b likewise)
%
%   `string` and not `char` because an absent value decodes as an empty double,
%   which `char` rejects -- the generator states that reason in its own words.
%
%   The non-quarantine half of the old paragraph is UNCHANGED and is exactly why
%   the wrong declaration survived unnoticed: schema/cache.m validateField
%   type-checks only the IMMEDIATE fields of a property block, and this sits two
%   levels down.
v = '';
if ~isstruct(src); return; end
for name = {'epochprobemap', 'epochProbeMap'}
    f = name{1};
    if isfield(src, f) && ~isempty(src.(f))
        v = src.(f);
        return;
    end
end
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
