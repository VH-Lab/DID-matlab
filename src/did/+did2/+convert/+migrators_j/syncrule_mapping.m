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
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (NDI syncrule_mapping.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+time/syncgraph.m ingest writes it), and
%   pass 1 carries it untouched (carry-036): no did_v1 document states the two
%   endpoint references. When did2.convert.epochMint re-runs this migrator with
%   the references stamped, the fold accounts for every v1 field before it
%   folds; anything it does not place keeps the mapping carried
%   (unplacedInFold below):
%
%     base.id, session_id, datestamp -> the clock_alignment
%     base.name                  -> not written; folded only when empty (the
%                                   writer's newdocument leaves it '')
%     depends_on syncgraph_id    -> clock_alignment_policy_id
%     depends_on syncrule_id     -> clock_alignment_configuration_id
%     (the edges epochMint stamps: epoch_id_1/_2, time_reference_id_1/_2)
%     files                      -> folded only when it lists no file (the
%                                   writer attaches none)
%     syncrule_mapping.cost      -> cost (a finite number)
%     syncrule_mapping.mapping   -> value.coefficients (finite numbers)
%     epochnode_a / epochnode_b  -> the two per-system references; epochMint
%                                   checked epoch_id, epoch_clock, t0_t1,
%                                   objectname, objectclass and epochprobemap
%                                   against them; epoch_session_id is folded
%                                   only when it is the document's own session
%
%   did2.convert.roundtrip.syncrule_mapping rebuilds the v1 document from the
%   fold; testRawV1RoundTripIngested compares.

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
if ~isempty(epochA) && ~isempty(epochB) && isempty(unplacedInFold(preBody, block))
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
% BRANCH 2 -- carried as v1.
% ---------------------------------------------------------------------
% [passthrough stays v1] and [generic stage is lossless] (Jess Haley,
% 2026-10-24/25), with [device clocks on one epoch] (3) (2026-10-26): a mapping
% that cannot be placed between two per-system references is carried UNTOUCHED
% as v1 -- noted `carried_as_v1`, so v1_to_v2 stamps it did_v1 and nothing reads
% it against V_eta. It replaces the #58 reshape (epoch_clock / epoch_id nested
% under a time_reference, stamped did_v2), which changed the v1 document.
% epochMint's syncrule arming reads the endpoint strings from either shape.
% carry-register: carry-036
did2.convert.reportNote('carried_as_v1', 'syncrule_mapping', ...
    sourceId(preBody), ['[carry-036] unplaced: the two ends are not per-system ' ...
    'references on the epochs ([device clocks on one epoch])']);
bodies = {preBody};
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



% ===================== the raw read ========================================

function id = sourceId(preBody)
%SOURCEID The v1 id, read through did2.convert.v1read.readBase (a legacy
%   `ndi_document` identity too); '' when there is none.
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
end

function unplaced = unplacedInFold(preBody, block)
%UNPLACEDINFOLD The v1 fields the fold would not keep, as paths ({} when it
%   keeps them all). Read off the raw v1 document (or the body the renamed path
%   gave epochMint: its depends_on read with either key, its stamp ignored).
unplaced = {};
b = did2.convert.v1read.readBase(preBody);
if ~strcmp(b.source, 'base') || ~isempty(fieldnames(b.extra)) ...
        || ~isempty(b.conflict) || ~did2.convert.isEmptyBlock(b.legacy_extra)
    % a legacy or extended identity block; an `ndi_document` beside `base` is
    % read as `base` ([ndi_document read as base], Jess Haley, 2026-10-31),
    % so only what it states that `base` cannot hold is unplaced
    unplaced{end+1} = 'base';
end
if ~isempty(b.name)
    unplaced{end+1} = 'base.name';
end
known = {'syncgraph_id', 'syncrule_id', 'epoch_id_1', 'epoch_id_2', ...
    'time_reference_id_1', 'time_reference_id_2', 'session_id'};
try
    deps = did2.convert.v1read.readDependsOn(preBody);
catch
    deps = [];
    unplaced{end+1} = 'depends_on';
end
for k = 1:numel(deps)
    if ~any(strcmp(deps(k).name, known)) && ~isempty(deps(k).document_id)
        unplaced{end+1} = sprintf('depends_on(%s)', deps(k).name); %#ok<AGROW>
    end
    if ~isempty(deps(k).version) || ~isempty(fieldnames(deps(k).other))
        unplaced{end+1} = sprintf('depends_on(%s) beyond its id', deps(k).name); %#ok<AGROW>
    end
end
top = setdiff(fieldnames(preBody), {'document_class', 'base', 'depends_on', ...
    'files', 'syncrule_mapping'});
for k = 1:numel(top)
    if ~isEmptyValue(preBody.(top{k}))
        unplaced{end+1} = top{k}; %#ok<AGROW>
    end
end
if isfield(preBody, 'files') && ~isEmptyValue(preBody.files)
    f = preBody.files;
    if ~isstruct(f) || ~isscalar(f)
        unplaced{end+1} = 'files';
    else
        fns = fieldnames(f);
        for k = 1:numel(fns)
            if ~isEmptyValue(f.(fns{k}))
                unplaced{end+1} = ['files.' fns{k}]; %#ok<AGROW>
            end
        end
    end
end
if ~isstruct(block) || ~isscalar(block)
    unplaced{end+1} = 'syncrule_mapping';
    return;
end
rest = setdiff(fieldnames(block), {'cost', 'mapping', 'epochnode_a', 'epochnode_b'});
for k = 1:numel(rest)
    unplaced{end+1} = ['syncrule_mapping.' rest{k}]; %#ok<AGROW>
end
if isfield(block, 'cost') && ~(isnumeric(block.cost) && isscalar(block.cost) ...
        && isfinite(block.cost))
    unplaced{end+1} = 'syncrule_mapping.cost';
end
nodeFields = {'epoch_id', 'epoch_session_id', 'epochprobemap', 'epoch_clock', ...
    't0_t1', 'objectname', 'objectclass'};
for nd = {'epochnode_a', 'epochnode_b'}
    if ~isfield(block, nd{1}) || ~isstruct(block.(nd{1})) || ~isscalar(block.(nd{1}))
        unplaced{end+1} = ['syncrule_mapping.' nd{1}]; %#ok<AGROW>
        continue;
    end
    node = block.(nd{1});
    extra = setdiff(fieldnames(node), nodeFields);
    for k = 1:numel(extra)
        unplaced{end+1} = sprintf('syncrule_mapping.%s.%s', nd{1}, extra{k}); %#ok<AGROW>
    end
    if isfield(node, 'epoch_session_id') && ~isEmptyValue(node.epoch_session_id) ...
            && ~isequal(char(node.epoch_session_id), char(b.session_id))
        unplaced{end+1} = sprintf('syncrule_mapping.%s.epoch_session_id', nd{1}); %#ok<AGROW>
    end
end
end

function tf = isEmptyValue(v)
%ISEMPTYVALUE Empty, or a struct whose every field is empty (the writer's
%   `files` block with no file: {file_list: [], file_info: []}).
if isempty(v)
    tf = true;
elseif isstruct(v) && isscalar(v)
    tf = all(cellfun(@(f) isEmptyValue(v.(f)), fieldnames(v)));
else
    tf = false;
end
end
